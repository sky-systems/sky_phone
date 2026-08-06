import type { GalleryFilter, MediaType, PhoneMedia } from '@/types/media'

export const MEDIA_PAGE_SIZE = 30

export function isMediaType(value: unknown): value is MediaType {
  return value === 'photo' || value === 'video'
}

export function filterMedia(
  media: PhoneMedia[],
  filter: GalleryFilter,
): PhoneMedia[] {
  return filter === 'all'
    ? media
    : media.filter((entry) => entry.mediaType === filter)
}

export function mergeMedia(
  current: PhoneMedia[],
  incoming: PhoneMedia[],
): PhoneMedia[] {
  const byId = new Map(current.map((entry) => [entry.id, entry]))
  for (const entry of incoming) byId.set(entry.id, entry)
  return [...byId.values()].sort(
    (left, right) => right.createdAt - left.createdAt || right.id - left.id,
  )
}

export function hasNextMediaPage(pageLength: number): boolean {
  return pageLength === MEDIA_PAGE_SIZE
}

export function formatRecordingDuration(elapsedMs: number): string {
  const totalSeconds = Math.max(0, Math.floor(elapsedMs / 1000))
  const minutes = Math.floor(totalSeconds / 60)
  const seconds = totalSeconds % 60
  return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`
}

export function mediaErrorKey(error?: string): string {
  const known = new Set([
    'cancelled',
    'capture_failed',
    'invalid_media_type',
    'invalid_upload',
    'invalid_upload_token',
    'missing_config',
    'not_found',
    'operation_in_progress',
    'owner_changed',
    'rate_limited',
    'request_failed',
    'request_timeout',
    'unsupported',
    'upload_failed',
    'upload_timeout',
  ])
  return known.has(error ?? '') ? (error as string) : 'request_failed'
}
