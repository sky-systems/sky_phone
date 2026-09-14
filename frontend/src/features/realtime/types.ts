export type LiveApp = 'picstagram' | 'fliptok'
export type Role = 'host' | 'viewer' | 'call' | 'nearby'
export type RealtimeConfig = {
  enabled: boolean
  transport: 'p2p' | 'cloudflare'
  videoCalls: boolean
  picstagram: boolean
  fliptok: boolean
  fps: number
  bitrate: number
  edge: number
  nearbyAudio: boolean
  iceServers: RTCIceServer[]
  iceTransportPolicy: RTCIceTransportPolicy
}
export type RemoteTrack = {
  sessionId: string
  trackName: string
  kind: 'video' | 'audio'
}
export type Peer = {
  id: number
  role: Role
  sends: boolean
  receives: boolean
  gain: number
  tracks: RemoteTrack[]
}
export type LiveMessage = {
  id: number
  name: string
  text: string
  host: boolean
  at: number
}
export type Room = {
  id: string
  kind: 'call' | 'live'
  app?: LiveApp
  title?: string
  description?: string
  hostName?: string
  messages?: LiveMessage[]
  self: number
  role: Role
  peers: Peer[]
  viewers: number
  transport: 'p2p' | 'cloudflare'
}
export type JoinResult = { room: Room; config: RealtimeConfig }
export type LiveEntry = {
  id: string
  title: string
  hostName: string
  viewers: number
}
export type Signal =
  | RTCSessionDescriptionInit
  | { type: 'candidate'; candidate: RTCIceCandidateInit }
