import { nuiCall } from '@/utils/nui'
import type { Peer, RealtimeConfig, Room, Signal } from './types'

type SfuResponse = {
  sessionId?: string
  sessionDescription?: RTCSessionDescriptionInit
  requiresImmediateRenegotiation?: boolean
  tracks?: {
    mid: string
    trackName: string
    sessionId?: string
    errorCode?: string
  }[]
}
type Remote = {
  connection: RTCPeerConnection
  stream: MediaStream
  candidates: RTCIceCandidateInit[]
}
export function directions(
  room: Room,
  peer: Peer,
  kind: 'audio' | 'video',
): RTCRtpTransceiverDirection {
  const permits = (role: string) =>
    kind === 'video'
      ? role === 'host' || role === 'call'
      : role === 'host' || role === 'nearby'
  const send = peer.sends && permits(room.role)
  const receive = peer.receives && permits(peer.role)
  return send && receive
    ? 'sendrecv'
    : send
      ? 'sendonly'
      : receive
        ? 'recvonly'
        : 'inactive'
}

export class LiveConnection {
  private peers = new Map<number, Remote>()
  private closed = false
  private queue: Promise<void> = Promise.resolve()
  private sfu?: RTCPeerConnection
  private mids = new Map<string, number>()
  private subscriptions = new Map<number, string[]>()
  private streams = new Map<number, MediaStream>()
  private latest: Room
  constructor(
    private room: Room,
    private config: RealtimeConfig,
    private stream: MediaStream,
    private onStream: (id: number, stream: MediaStream | null) => void,
    private onError: (error: unknown) => void,
  ) {
    this.latest = room
  }
  private rtc(): RTCPeerConnection {
    return new RTCPeerConnection({
      iceServers: this.config.iceServers,
      iceTransportPolicy:
        this.room.transport === 'cloudflare'
          ? 'all'
          : this.config.iceTransportPolicy,
      bundlePolicy: 'max-bundle',
    })
  }
  private serial(task: () => Promise<void>): Promise<void> {
    const next = this.queue.then(async () => {
      if (!this.closed) await task()
    })
    this.queue = next.catch(this.onError)
    return next
  }
  private async request(
    operation: string,
    data: Record<string, unknown> = {},
  ): Promise<SfuResponse> {
    const response = await nuiCall<SfuResponse>('realtime:sfu', {
      id: this.room.id,
      operation,
      ...data,
    })
    if (!response.success || !response.data)
      throw new Error(response.error || 'cloudflare_failed')
    return response.data
  }
  private async limit(sender: RTCRtpSender): Promise<void> {
    if (sender.track?.kind !== 'video') return
    const parameters = sender.getParameters()
    if (!parameters.encodings?.length) parameters.encodings = [{}]
    parameters.encodings.forEach((encoding) => {
      encoding.maxBitrate = this.config.bitrate
      encoding.maxFramerate = this.config.fps
    })
    await sender.setParameters(parameters)
  }
  async start(): Promise<void> {
    if (this.room.transport === 'cloudflare') {
      this.sfu = this.rtc()
      this.sfu.ontrack = (event) => {
        const id = this.mids.get(event.transceiver.mid || '')
        if (id === undefined) return
        const stream = this.streams.get(id) ?? new MediaStream()
        if (!stream.getTracks().includes(event.track))
          stream.addTrack(event.track)
        this.streams.set(id, stream)
        this.onStream(id, stream)
      }
      this.sfu.onconnectionstatechange = () => {
        if (this.sfu?.connectionState === 'failed')
          this.onError(new Error('connection_failed'))
      }
      await this.request('create')
      if (this.closed) return
      if (this.stream.getTracks().length) {
        const transceivers = this.stream.getTracks().map((track) =>
          this.sfu!.addTransceiver(track, {
            direction: 'sendonly',
            streams: [this.stream],
          }),
        )
        await this.sfu.setLocalDescription(await this.sfu.createOffer())
        const response = await this.request('publish', {
          sessionDescription: this.sfu.localDescription?.toJSON(),
          tracks: transceivers.map((entry) => ({
            mid: entry.mid,
            trackName: entry.sender.track!.id,
            kind: entry.sender.track!.kind,
          })),
        })
        if (this.closed) return
        if (!response.sessionDescription) throw new Error('cloudflare_failed')
        await this.sfu.setRemoteDescription(response.sessionDescription)
        await Promise.all(transceivers.map((entry) => this.limit(entry.sender)))
      }
    }
    await this.update(this.latest)
  }
  update(room: Room): Promise<void> {
    this.latest = room
    return this.serial(async () => {
      this.room = room
      if (room.transport === 'cloudflare') {
        await this.updateSfu(room)
        return
      }
      for (const [id, remote] of this.peers) {
        if (!room.peers.some((peer) => peer.id === id)) {
          remote.connection.close()
          this.peers.delete(id)
          this.onStream(id, null)
        }
      }
      for (const peer of room.peers) {
        if (this.peers.has(peer.id)) continue
        const remote = this.createPeer(peer)
        if (room.self < peer.id) {
          await remote.connection.setLocalDescription(
            await remote.connection.createOffer(),
          )
          await this.send(peer.id, remote.connection.localDescription!.toJSON())
        }
      }
    })
  }
  private createPeer(peer: Peer): Remote {
    const existing = this.peers.get(peer.id)
    if (existing) return existing
    const connection = this.rtc()
    const remote: Remote = {
      connection,
      stream: new MediaStream(),
      candidates: [],
    }
    this.peers.set(peer.id, remote)
    for (const kind of this.room.self < peer.id
      ? (['video', 'audio'] as const)
      : []) {
      const direction = directions(this.room, peer, kind)
      const track = this.stream.getTracks().find((entry) => entry.kind === kind)
      connection.addTransceiver(
        track && direction.startsWith('send') ? track : kind,
        {
          direction,
          streams: track ? [this.stream] : [],
        },
      )
    }
    connection.onicecandidate = (event) => {
      if (event.candidate)
        void this.send(peer.id, {
          type: 'candidate',
          candidate: event.candidate.toJSON(),
        }).catch(this.onError)
    }
    connection.ontrack = (event) => {
      if (!remote.stream.getTracks().includes(event.track))
        remote.stream.addTrack(event.track)
      this.onStream(peer.id, remote.stream)
    }
    connection.onconnectionstatechange = () => {
      if (connection.connectionState !== 'failed') return
      if (this.room.role === 'host') {
        connection.close()
        this.peers.delete(peer.id)
        this.onStream(peer.id, null)
        void nuiCall('realtime:drop', { id: this.room.id, target: peer.id })
      } else this.onError(new Error('connection_failed'))
    }
    return remote
  }
  private async send(target: number, signal: Signal): Promise<void> {
    if (this.closed) return
    const result = await nuiCall('realtime:signal', {
      id: this.room.id,
      target,
      signal,
    })
    if (!result.success) throw new Error(result.error || 'connection_failed')
  }
  signal(from: number, signal: Signal): Promise<void> {
    return this.serial(async () => {
      const peer = this.latest.peers.find((entry) => entry.id === from)
      if (!peer || this.room.transport !== 'p2p') return
      const remote = this.createPeer(peer)
      if (signal.type === 'candidate') {
        if (remote.connection.remoteDescription)
          await remote.connection.addIceCandidate(signal.candidate)
        else remote.candidates.push(signal.candidate)
        return
      }
      await remote.connection.setRemoteDescription(signal)
      for (const candidate of remote.candidates.splice(0))
        await remote.connection.addIceCandidate(candidate)
      if (signal.type === 'offer') {
        for (const transceiver of remote.connection.getTransceivers()) {
          const kind = transceiver.receiver.track.kind as 'audio' | 'video'
          transceiver.direction = directions(this.room, peer, kind)
          const track = this.stream
            .getTracks()
            .find((entry) => entry.kind === kind)
          if (track && transceiver.direction.startsWith('send')) {
            await transceiver.sender.replaceTrack(track)
            transceiver.sender.setStreams(this.stream)
          }
        }
        await remote.connection.setLocalDescription(
          await remote.connection.createAnswer(),
        )
        await this.send(from, remote.connection.localDescription!.toJSON())
      }
      await Promise.all(
        remote.connection.getSenders().map((sender) => this.limit(sender)),
      )
    })
  }
  private async updateSfu(room: Room): Promise<void> {
    const connection = this.sfu
    if (!connection) return
    for (const [id, mids] of this.subscriptions) {
      if (room.peers.some((peer) => peer.id === id && peer.receives)) continue
      await this.request('close', { mids })
      mids.forEach((mid) => this.mids.delete(mid))
      this.subscriptions.delete(id)
      this.streams.delete(id)
      this.onStream(id, null)
    }
    for (const peer of room.peers) {
      if (
        !peer.receives ||
        !peer.tracks.length ||
        this.subscriptions.has(peer.id)
      )
        continue
      const response = await this.request('pull', { target: peer.id })
      if (this.closed) return
      const mids = (response.tracks ?? [])
        .map((track) => track.mid)
        .filter(Boolean)
      mids.forEach((mid) => this.mids.set(mid, peer.id))
      if (response.sessionDescription) {
        await connection.setRemoteDescription(response.sessionDescription)
        if (response.requiresImmediateRenegotiation) {
          await connection.setLocalDescription(await connection.createAnswer())
          await this.request('renegotiate', {
            sessionDescription: connection.localDescription!.toJSON(),
          })
        }
      }
      this.subscriptions.set(peer.id, mids)
    }
  }
  close(): void {
    this.closed = true
    this.peers.forEach((peer) => peer.connection.close())
    this.peers.clear()
    this.sfu?.close()
    this.subscriptions.clear()
    this.streams.clear()
  }
}
