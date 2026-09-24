import { defineStore } from 'pinia'
import { ref, shallowRef } from 'vue'
import { nuiCall } from '@/utils/nui'
import { isTrustedRootMessageSource } from '@/utils/windowMessages'
import { LiveConnection } from './connection'
import { LiveMedia, setVoiceTalking } from './media'
import type {
  JoinResult,
  LiveApp,
  LiveEntry,
  RealtimeConfig,
  Room,
  Signal,
} from './types'

type Session = {
  room: Room
  media: LiveMedia
  connection: LiveConnection
  ready: boolean
  heartbeat?: number
  signals: { from: number; signal: Signal }[]
}
export const useRealtimeStore = defineStore('realtime', () => {
  const config = shallowRef<RealtimeConfig | null>(null)
  const room = shallowRef<Room | null>(null)
  const localStream = shallowRef<MediaStream | null>(null)
  const streams = shallowRef(new Map<number, MediaStream>())
  const nearbyCount = ref(0)
  const error = ref('')
  const busy = ref(false)
  const muted = ref(false)
  const front = ref(true)
  const sessions = new Map<string, Session>()
  const denied = new Set<string>()
  let initialized = false
  let generation = 0
  let lifecycle = 0
  const joiningNearby = new Set<string>()
  let requestedCall: string | null = null
  const errorCode = (value: unknown) =>
    value instanceof Error ? value.message : 'connection_failed'

  async function refreshConfig(): Promise<void> {
    const response = await nuiCall<RealtimeConfig>('realtime:config')
    if (response.success && response.data) config.value = response.data
  }
  function refreshNearby(): void {
    nearbyCount.value = [...sessions.values()].filter(
      (entry) => entry.room.role === 'nearby',
    ).length
  }
  function closeSession(id: string, notify = true): void {
    const current = sessions.get(id)
    if (!current) return
    sessions.delete(id)
    clearInterval(current.heartbeat)
    current.connection.close()
    current.media.dispose()
    if (room.value?.id === id) {
      room.value = null
      localStream.value = null
      streams.value = new Map()
    }
    refreshNearby()
    if (notify) void nuiCall('realtime:leave', { id })
  }
  function fail(id: string, value: unknown): void {
    console.warn('[sky_phone] Realtime session failed:', errorCode(value))
    if (sessions.get(id)?.room.role !== 'nearby') error.value = errorCode(value)
    denied.add(id)
    closeSession(id)
  }
  async function attach(
    result: JoinResult,
    background: boolean,
    expected: number,
  ): Promise<void> {
    const initial = result.room
    if (sessions.has(initial.id)) return
    if (expected !== (background ? lifecycle : generation)) {
      void nuiCall('realtime:leave', { id: initial.id })
      return
    }
    const media = new LiveMedia()
    const connection = new LiveConnection(
      initial,
      result.config,
      media.stream,
      (id, stream) => {
        const session = sessions.get(initial.id)
        if (!session) return
        if (!stream) media.unmix(id)
        const peer = session.room.peers.find((entry) => entry.id === id)
        if (peer?.role === 'nearby' && initial.role === 'host') {
          if (stream) media.mix(id, stream, peer.gain)
          else media.unmix(id)
          return
        }
        if (room.value?.id !== initial.id) return
        const next = new Map(streams.value)
        if (stream) next.set(id, stream)
        else next.delete(id)
        streams.value = next
      },
      (value) => fail(initial.id, value),
    )
    const session: Session = {
      room: initial,
      media,
      connection,
      ready: false,
      signals: [],
    }
    sessions.set(initial.id, session)
    if (!background) {
      room.value = initial
      muted.value = false
      front.value = true
    }
    refreshNearby()
    try {
      await media.start(initial.role, result.config)
      if (!sessions.has(initial.id)) return
      if (!background) localStream.value = media.stream
      const ready = await nuiCall<Room>('realtime:ready', { id: initial.id })
      if (!sessions.has(initial.id)) return
      if (!ready.success || !ready.data) throw new Error(ready.error || 'ended')
      updateRoom(ready.data)
      await connection.start(session.room)
      if (!sessions.has(initial.id)) return
      session.ready = true
      await connection.update(session.room)
      for (const signal of session.signals.splice(0))
        await connection.signal(signal.from, signal.signal)
      session.heartbeat = window.setInterval(async () => {
        const response = await nuiCall<Room>('realtime:heartbeat', {
          id: initial.id,
        })
        if (!sessions.has(initial.id)) return
        if (!response.success || !response.data) {
          fail(initial.id, new Error(response.error || 'ended'))
          return
        }
        updateRoom(response.data)
      }, 8000)
    } catch (value) {
      fail(initial.id, value)
    }
  }
  function updateRoom(next: Room): void {
    const session = sessions.get(next.id)
    if (!session) return
    // A ready/heartbeat reply may predate a room event already received by NUI.
    if ((next.revision ?? 0) < (session.room.revision ?? 0)) return
    session.room = next
    if (room.value?.id === next.id) room.value = next
    for (const peer of next.peers)
      if (peer.role === 'nearby') session.media.volume(peer.id, peer.gain)
    if (session.ready)
      void session.connection
        .update(next)
        .catch((value) => fail(next.id, value))
  }
  async function enter(
    endpoint: string,
    data: Record<string, unknown>,
  ): Promise<void> {
    if (busy.value) return
    const expected = ++generation
    if (room.value) closeSession(room.value.id)
    busy.value = true
    error.value = ''
    try {
      const response = await nuiCall<JoinResult>(endpoint, data)
      if (!response.success || !response.data) {
        error.value = response.error || 'request_failed'
        return
      }
      if (expected !== generation) {
        void nuiCall('realtime:leave', { id: response.data.room.id })
        return
      }
      await attach(response.data, false, expected)
    } finally {
      if (generation === expected) busy.value = false
    }
  }
  async function startLive(
    app: LiveApp,
    title: string,
    description = '',
  ): Promise<void> {
    await enter('realtime:create', { kind: 'live', app, title, description })
  }
  async function watchLive(id: string): Promise<void> {
    await enter('realtime:join', { id })
  }
  async function list(app: LiveApp): Promise<LiveEntry[]> {
    const response = await nuiCall<LiveEntry[]>('realtime:list', { app })
    if (!response.success) error.value = response.error || 'request_failed'
    return response.data ?? []
  }
  async function chat(text: string): Promise<boolean> {
    if (!room.value) return false
    const response = await nuiCall('realtime:chat', { id: room.value.id, text })
    if (!response.success) error.value = response.error || 'request_failed'
    return response.success
  }
  function stop(): void {
    generation += 1
    busy.value = false
    if (room.value) closeSession(room.value.id)
  }
  async function syncCall(id: string | null): Promise<void> {
    if (requestedCall === id) return
    requestedCall = id
    if (room.value?.kind === 'call') stop()
    if (id) {
      if (busy.value) stop()
      await enter('realtime:create', { kind: 'call', id })
    }
  }
  function setMuted(value: boolean): void {
    muted.value = value
    if (room.value) sessions.get(room.value.id)?.media.setMuted(value)
  }
  async function flip(): Promise<void> {
    if (!room.value) return
    try {
      await sessions.get(room.value.id)?.media.flip(!front.value)
      front.value = !front.value
    } catch (value) {
      error.value = errorCode(value)
    }
  }
  async function onMessage(event: MessageEvent): Promise<void> {
    if (!isTrustedRootMessageSource(event.source, window)) return
    const type = event.data?.type,
      data = event.data?.data
    if (type === 'realtime:room' && data) updateRoom(data)
    else if (type === 'realtime:signal' && data) {
      const session = sessions.get(data.id)
      if (!session) return
      if (!session.ready) {
        if (session.signals.length < 128) session.signals.push(data)
        return
      }
      void session.connection
        .signal(data.from, data.signal)
        .catch((value) => fail(data.id, value))
    } else if (type === 'realtime:voice')
      setVoiceTalking(data?.talking === true)
    else if (type === 'realtime:ended' && data) {
      if (room.value?.id === data.id && data.reason !== 'ended')
        error.value = data.reason
      closeSession(data.id, false)
    } else if (type === 'realtime:nearby' && data?.id && !denied.has(data.id)) {
      if (
        sessions.has(data.id) ||
        joiningNearby.has(data.id) ||
        [...sessions.values()].filter((entry) => entry.room.role === 'nearby')
          .length >= 2
      )
        return
      const expected = lifecycle
      joiningNearby.add(data.id)
      try {
        const response = await nuiCall<JoinResult>('realtime:join', {
          id: data.id,
        })
        if (response.success && response.data?.room.role === 'nearby')
          await attach(response.data, true, expected)
      } finally {
        joiningNearby.delete(data.id)
      }
    } else if (type === 'realtime:reset') reset()
  }
  function initialize(): void {
    if (initialized) return
    initialized = true
    window.addEventListener('message', onMessage)
  }
  function reset(): void {
    lifecycle += 1
    joiningNearby.clear()
    generation += 1
    busy.value = false
    requestedCall = null
    sessions.forEach((_, id) => closeSession(id))
    denied.clear()
  }
  function dispose(): void {
    reset()
    window.removeEventListener('message', onMessage)
    initialized = false
  }
  return {
    config,
    room,
    localStream,
    streams,
    nearbyCount,
    error,
    busy,
    muted,
    front,
    initialize,
    dispose,
    refreshConfig,
    startLive,
    watchLive,
    list,
    chat,
    stop,
    syncCall,
    setMuted,
    flip,
  }
})
