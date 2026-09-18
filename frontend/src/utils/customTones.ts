import { nuiCall } from '@/utils/nui'
import { playPhoneMediaTone } from '@/utils/tones'

export type CustomTonePreferenceId = `custom:${string}`
export type CustomToneType = 'notification' | 'ringtone'

export type CustomPhoneTone = {
  byteSize: number
  createdAt: string
  durationMs: number
  id: CustomTonePreferenceId
  label: string
  mimeType: string
  source: 'config' | 'database'
  toneType: CustomToneType
}

export type CustomPhoneToneCatalog = {
  notificationSounds: CustomPhoneTone[]
  ringtones: CustomPhoneTone[]
}

type CustomToneAudio = {
  id: string
  mimeType: string
  payload: string
}

export const EMPTY_CUSTOM_PHONE_TONES: CustomPhoneToneCatalog = {
  notificationSounds: [],
  ringtones: [],
}

export const MAX_CUSTOM_TONE_BYTES = 2_000_000
export const MAX_CUSTOM_TONE_PAYLOAD_CHARS = 2_666_668
export const CUSTOM_TONE_CHUNK_CHARS = 8_000

const CUSTOM_TONE_ID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const CONFIG_TONE_ID_PATTERN =
  /^config:(ringtone|notification):[a-z0-9][a-z0-9_-]{0,47}$/
const MAX_CUSTOM_TONES_PER_TYPE = 32
const MAX_CACHED_TONES = 2
const ALLOWED_MIME_TYPES = new Set([
  'audio/mpeg',
  'audio/ogg',
  'audio/wav',
  'audio/webm',
])
const cachedSources = new Map<string, string>()

export function isCustomTonePreferenceId(
  value: unknown,
): value is CustomTonePreferenceId {
  return (
    typeof value === 'string' &&
    value.startsWith('custom:') &&
    (CUSTOM_TONE_ID_PATTERN.test(value.slice('custom:'.length)) ||
      CONFIG_TONE_ID_PATTERN.test(value.slice('custom:'.length)))
  )
}

function parseToneList(
  value: unknown,
  expectedType: CustomToneType,
): CustomPhoneTone[] {
  if (!Array.isArray(value)) return []

  const tones: CustomPhoneTone[] = []
  const acceptedIds = new Set<string>()
  for (const entry of value.slice(0, MAX_CUSTOM_TONES_PER_TYPE)) {
    if (!entry || typeof entry !== 'object' || Array.isArray(entry)) continue
    const candidate = entry as Record<string, unknown>
    const source = candidate.source === 'config' ? 'config' : 'database'
    const validId =
      typeof candidate.id === 'string' &&
      (source === 'config'
        ? CONFIG_TONE_ID_PATTERN.test(candidate.id) &&
          candidate.id.startsWith(`config:${expectedType}:`)
        : CUSTOM_TONE_ID_PATTERN.test(candidate.id))
    if (
      !validId ||
      typeof candidate.id !== 'string' ||
      acceptedIds.has(candidate.id) ||
      typeof candidate.label !== 'string' ||
      candidate.label.length < 1 ||
      candidate.label.length > 64 ||
      candidate.label.trim().length < 1 ||
      candidate.toneType !== expectedType ||
      typeof candidate.mimeType !== 'string' ||
      !ALLOWED_MIME_TYPES.has(candidate.mimeType) ||
      typeof candidate.durationMs !== 'number' ||
      !Number.isInteger(candidate.durationMs) ||
      candidate.durationMs < 250 ||
      candidate.durationMs > 30_000 ||
      typeof candidate.byteSize !== 'number' ||
      !Number.isInteger(candidate.byteSize) ||
      candidate.byteSize < 1 ||
      candidate.byteSize > MAX_CUSTOM_TONE_BYTES ||
      typeof candidate.createdAt !== 'string'
    ) {
      continue
    }

    acceptedIds.add(candidate.id)
    tones.push({
      byteSize: candidate.byteSize,
      createdAt: candidate.createdAt,
      durationMs: candidate.durationMs,
      id: `custom:${candidate.id}`,
      label: candidate.label,
      mimeType: candidate.mimeType,
      source,
      toneType: expectedType,
    })
  }
  return tones
}

export function parseCustomPhoneToneCatalog(
  value: unknown,
): CustomPhoneToneCatalog {
  const source =
    value && typeof value === 'object' && !Array.isArray(value)
      ? (value as Record<string, unknown>)
      : {}
  return {
    notificationSounds: parseToneList(
      source.notificationSounds,
      'notification',
    ),
    ringtones: parseToneList(source.ringtones, 'ringtone'),
  }
}

export function findCustomPhoneTone(
  tones: CustomPhoneTone[],
  id: string,
): CustomPhoneTone | undefined {
  return isCustomTonePreferenceId(id)
    ? tones.find((tone) => tone.id === id)
    : undefined
}

function cacheSource(id: string, source: string): void {
  cachedSources.delete(id)
  cachedSources.set(id, source)
  while (cachedSources.size > MAX_CACHED_TONES) {
    const oldest = cachedSources.keys().next().value
    if (typeof oldest !== 'string') break
    cachedSources.delete(oldest)
  }
}

export function cacheCustomPhoneTonePayload(
  id: CustomTonePreferenceId,
  mimeType: string,
  payload: string,
): boolean {
  if (
    !isCustomTonePreferenceId(id) ||
    !ALLOWED_MIME_TYPES.has(mimeType) ||
    payload.length < 1 ||
    payload.length > MAX_CUSTOM_TONE_PAYLOAD_CHARS ||
    payload.length % 4 !== 0 ||
    !/^[A-Za-z0-9+/]*={0,2}$/.test(payload)
  ) {
    return false
  }

  cacheSource(id.slice('custom:'.length), `data:${mimeType};base64,${payload}`)
  return true
}

async function loadToneSource(tone: CustomPhoneTone): Promise<string> {
  const rawId = tone.id.slice('custom:'.length)
  const cached = cachedSources.get(rawId)
  if (cached) {
    cacheSource(rawId, cached)
    return cached
  }

  const response = await nuiCall<CustomToneAudio>('tones:audio', {
    id: rawId,
  })
  const audio = response.data
  if (
    !response.success ||
    !audio ||
    audio.id !== rawId ||
    !ALLOWED_MIME_TYPES.has(audio.mimeType) ||
    typeof audio.payload !== 'string' ||
    audio.payload.length < 1 ||
    audio.payload.length > MAX_CUSTOM_TONE_PAYLOAD_CHARS ||
    audio.payload.length % 4 !== 0 ||
    !/^[A-Za-z0-9+/]*={0,2}$/.test(audio.payload)
  ) {
    throw new Error(response.error ?? 'invalid_custom_tone')
  }

  const source = `data:${audio.mimeType};base64,${audio.payload}`
  cacheSource(rawId, source)
  return source
}

export function playCustomPhoneTone(
  tone: CustomPhoneTone,
  volumePercent: number,
  loop: boolean,
  callbacks: {
    onError?: (error: unknown) => void
    onStarted?: () => void
  } = {},
): () => void {
  let stopped = false
  let stopPlayback: (() => void) | null = null
  void loadToneSource(tone)
    .then((source) => {
      if (!stopped) {
        stopPlayback = playPhoneMediaTone(
          source,
          volumePercent,
          loop,
          callbacks,
        )
      }
    })
    .catch((error: unknown) => {
      if (!stopped) {
        console.error('[Phone audio] Failed to load custom tone', error)
        callbacks.onError?.(error)
      }
    })

  return () => {
    stopped = true
    stopPlayback?.()
    stopPlayback = null
  }
}
