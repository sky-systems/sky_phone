import { beforeEach, afterEach, describe, expect, it, vi } from 'vitest'
import { LiveConnection, directions } from './connection'
import { nuiCall } from '@/utils/nui'
import type { RealtimeConfig, Room, Role } from './types'
vi.mock('@/utils/nui', () => ({ nuiCall: vi.fn() }))
class Stream {
  constructor(private tracks: { id: string; kind: string }[] = []) {}
  getTracks() {
    return this.tracks
  }
}
const video = { id: 'camera', kind: 'video' }
const sender = () => ({
  track: null as unknown,
  replaceTrack: vi.fn(async function (
    this: { track: unknown },
    track: unknown,
  ) {
    this.track = track
  }),
  setStreams: vi.fn(),
  getParameters: () => ({ encodings: [{}] }),
  setParameters: vi.fn(async () => undefined),
})
class RTC {
  static instances: RTC[] = []
  transceivers: {
    direction: string
    sender: ReturnType<typeof sender>
    receiver: { track: { kind: string } }
  }[] = []
  localDescription: unknown = null
  remoteDescription: unknown = null
  addIceCandidate = vi.fn(async () => undefined)
  close = vi.fn()
  constructor() {
    RTC.instances.push(this)
  }
  addTransceiver(track: string | typeof video, init: { direction: string }) {
    const entry = {
      direction: init.direction,
      sender: sender(),
      receiver: {
        track: { kind: typeof track === 'string' ? track : track.kind },
      },
    }
    if (typeof track !== 'string') entry.sender.track = track
    this.transceivers.push(entry)
    return entry
  }
  getTransceivers() {
    return this.transceivers
  }
  getSenders() {
    return this.transceivers.map((entry) => entry.sender)
  }
  async createOffer() {
    return { type: 'offer', sdp: 'offer' }
  }
  async createAnswer() {
    return { type: 'answer', sdp: 'answer' }
  }
  async setLocalDescription(value: object) {
    this.localDescription = { ...value, toJSON: () => value }
  }
  async setRemoteDescription(value: { type: string }) {
    this.remoteDescription = value
    if (value.type === 'offer')
      for (const kind of ['video', 'audio'])
        this.addTransceiver(kind, { direction: 'recvonly' })
  }
}
const config: RealtimeConfig = {
  enabled: true,
  transport: 'p2p',
  videoCalls: true,
  picstagram: true,
  fliptok: true,
  edge: 720,
  nearbyAudio: true,
  iceServers: [],
  iceTransportPolicy: 'all',
  bitrate: 1200000,
  fps: 24,
}
function room(self = 2, role: Role = 'call', peerRole: Role = 'call'): Room {
  return {
    id: 'room',
    kind: role === 'call' ? 'call' : 'live',
    self,
    role,
    viewers: 0,
    transport: 'p2p',
    peers: [
      {
        id: self === 1 ? 2 : 1,
        role: peerRole,
        receives:
          peerRole === 'nearby' || (role !== 'nearby' && peerRole !== 'viewer'),
        sends:
          role === 'nearby' || (peerRole !== 'nearby' && role !== 'viewer'),
        gain: 1,
        tracks: [],
      },
    ],
  }
}
describe('WebRTC directions and answer negotiation', () => {
  beforeEach(() => {
    RTC.instances = []
    vi.stubGlobal('RTCPeerConnection', RTC)
    vi.stubGlobal('MediaStream', Stream)
    vi.mocked(nuiCall).mockResolvedValue({ success: true })
  })
  afterEach(() => vi.unstubAllGlobals())
  it.each([
    ['call', 'call', 'video', 'sendrecv'],
    ['call', 'call', 'audio', 'inactive'],
    ['host', 'viewer', 'video', 'sendonly'],
    ['host', 'viewer', 'audio', 'sendonly'],
    ['viewer', 'host', 'video', 'recvonly'],
    ['viewer', 'host', 'audio', 'recvonly'],
    ['nearby', 'host', 'audio', 'sendonly'],
    ['nearby', 'host', 'video', 'inactive'],
  ] as const)('%s to %s configures %s', (role, peerRole, kind, expected) => {
    const state = room(2, role, peerRole)
    expect(directions(state, state.peers[0], kind)).toBe(expected)
  })
  it('binds the answering camera to the offered transceiver so both callers send video', async () => {
    const connection = new LiveConnection(
      room(),
      config,
      new Stream([video]) as unknown as MediaStream,
      vi.fn(),
      vi.fn(),
    )
    await connection.start()
    expect(RTC.instances[0].transceivers).toHaveLength(0)
    await connection.signal(1, {
      type: 'candidate',
      candidate: { candidate: 'candidate' },
    })
    expect(RTC.instances[0].addIceCandidate).not.toHaveBeenCalled()
    await connection.signal(1, { type: 'offer', sdp: 'offer' })
    const [camera, audio] = RTC.instances[0].transceivers
    expect(camera.direction).toBe('sendrecv')
    expect(camera.sender.replaceTrack).toHaveBeenCalledWith(video)
    expect(audio.direction).toBe('inactive')
    expect(RTC.instances[0].addIceCandidate).toHaveBeenCalledOnce()
    expect(nuiCall).toHaveBeenCalledWith(
      'realtime:signal',
      expect.objectContaining({
        target: 1,
        signal: { type: 'answer', sdp: 'answer' },
      }),
    )
    connection.close()
    expect(RTC.instances[0].close).toHaveBeenCalledOnce()
  })
})
