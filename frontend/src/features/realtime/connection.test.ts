import { beforeEach, afterEach, describe, expect, it, vi } from 'vitest'
import { createPinia, disposePinia, setActivePinia } from 'pinia'
import { useRealtimeStore } from './store'
import { LiveConnection, directions } from './connection'
import { nuiCall } from '@/utils/nui'
import type { RealtimeConfig, Room, Role } from './types'
vi.mock('@/utils/nui', () => ({ nuiCall: vi.fn() }))
vi.mock('./media', () => ({
  LiveMedia: class {
    stream = new MediaStream([video as MediaStreamTrack])
    async start() {}
    dispose() {}
    volume() {}
    unmix() {}
  },
  setVoiceTalking: vi.fn(),
}))
class Stream {
  constructor(private tracks: { id: string; kind: string }[] = []) {}
  getTracks() {
    return this.tracks
  }
  addTrack(track: { id: string; kind: string }) {
    this.tracks.push(track)
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
  ontrack?: (event: { track: typeof video }) => void
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
  afterEach(() => {
    vi.clearAllMocks()
    vi.unstubAllGlobals()
  })
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
  it('retains an offer and ICE that arrive before the peer roster', async () => {
    const state = room()
    const connection = new LiveConnection(
      { ...state, peers: [] },
      config,
      new Stream([video]) as unknown as MediaStream,
      vi.fn(),
      vi.fn(),
    )
    await connection.start()
    await connection.signal(1, {
      type: 'candidate',
      candidate: { candidate: 'early' },
    })
    await connection.signal(1, { type: 'offer', sdp: 'early-offer' })
    expect(RTC.instances).toHaveLength(0)
    await connection.update(state)
    expect(RTC.instances[0].remoteDescription).toEqual({
      type: 'offer',
      sdp: 'early-offer',
    })
    expect(RTC.instances[0].addIceCandidate).toHaveBeenCalledWith({
      candidate: 'early',
    })
    expect(nuiCall).toHaveBeenCalledWith(
      'realtime:signal',
      expect.objectContaining({
        target: 1,
        signal: { type: 'answer', sdp: 'answer' },
      }),
    )
    connection.close()
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

describe('direct FaceTime acceptance', () => {
  let pinia: ReturnType<typeof createPinia>
  beforeEach(() => {
    RTC.instances = []
    vi.useFakeTimers()
    vi.stubGlobal('RTCPeerConnection', RTC)
    vi.stubGlobal('MediaStream', Stream)
    vi.stubGlobal('window', Object.assign(new EventTarget(), { setInterval }))
    pinia = createPinia()
    setActivePinia(pinia)
  })
  afterEach(() => {
    useRealtimeStore().dispose()
    disposePinia(pinia)
    vi.clearAllMocks()
    vi.clearAllTimers()
    vi.useRealTimers()
    vi.unstubAllGlobals()
  })
  it.each([1, 2])(
    'negotiates as player %s when the ready reply arrives after the peer broadcast',
    async (self) => {
      const state = { ...room(self), revision: 2 }
      const initial = { ...state, revision: 1, peers: [] }
      let resolveReady!: (value: { success: boolean; data: Room }) => void
      const ready = new Promise<{ success: boolean; data: Room }>((resolve) => {
        resolveReady = resolve
      })
      vi.mocked(nuiCall).mockImplementation(async (name) => {
        if (name === 'realtime:create')
          return { success: true, data: { room: initial, config } }
        if (name === 'realtime:ready') return ready
        return { success: true }
      })
      const store = useRealtimeStore()
      store.initialize()
      const joining = store.syncCall('direct-call')
      await vi.waitFor(() =>
        expect(nuiCall).toHaveBeenCalledWith('realtime:ready', {
          id: state.id,
        }),
      )
      const message = (type: string, data: unknown) =>
        window.dispatchEvent(
          new MessageEvent('message', { data: { type, data } }),
        )
      message('realtime:room', state)
      if (self === 2)
        message('realtime:signal', {
          id: state.id,
          from: 1,
          signal: { type: 'offer', sdp: 'direct-offer' },
        })
      resolveReady({ success: true, data: initial })
      await joining
      expect(store.room?.peers).toEqual(state.peers)
      expect(nuiCall).toHaveBeenCalledWith(
        'realtime:signal',
        expect.objectContaining({
          target: self === 1 ? 2 : 1,
          signal: expect.objectContaining({
            type: self === 1 ? 'offer' : 'answer',
          }),
        }),
      )
      expect(RTC.instances).toHaveLength(1)
      expect(RTC.instances[0].transceivers[0].sender.track).toEqual(video)
      RTC.instances[0].ontrack?.({
        track: { id: 'remote-camera', kind: 'video' },
      })
      expect(store.streams.get(self === 1 ? 2 : 1)?.getTracks()).toHaveLength(1)
      message('realtime:room', initial)
      await Promise.resolve()
      expect(store.room?.peers).toEqual(state.peers)
      expect(RTC.instances[0].close).not.toHaveBeenCalled()
      message('realtime:room', { ...initial, revision: 3 })
      await vi.waitFor(() =>
        expect(RTC.instances[0].close).toHaveBeenCalledOnce(),
      )
      expect(store.room?.peers).toEqual([])
      expect(store.error).toBe('')
    },
  )
})
