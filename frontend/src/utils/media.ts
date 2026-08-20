import type {
  GalleryFilter,
  GallerySortOrder,
  MediaType,
  PhoneMedia,
} from '@/types/media'

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

export function orderMediaOldestFirst(media: PhoneMedia[]): PhoneMedia[] {
  return [...media].sort(
    (left, right) => left.createdAt - right.createdAt || left.id - right.id,
  )
}

export function orderMedia(
  media: PhoneMedia[],
  sortOrder: GallerySortOrder,
): PhoneMedia[] {
  return sortOrder === 'oldest'
    ? orderMediaOldestFirst(media)
    : [...media].sort(
        (left, right) => right.createdAt - left.createdAt || right.id - left.id,
      )
}

export function bottomRightGridPosition(
  itemIndex: number,
  itemCount: number,
  columnCount = 3,
): { column: number; row: number } {
  const count = Math.max(1, itemCount)
  const index = Math.max(0, Math.min(itemIndex, count - 1))
  return {
    column: columnCount - (index % columnCount),
    row: Math.ceil(count / columnCount) - Math.floor(index / columnCount),
  }
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

export function formatMediaSize(bytes: number, locale: string): string {
  const safeBytes = Math.max(0, bytes)
  if (safeBytes < 1024) return `${safeBytes} B`
  const units = ['KB', 'MB', 'GB']
  let value = safeBytes / 1024
  let unit = units[0]
  for (let index = 1; index < units.length && value >= 1024; index += 1) {
    value /= 1024
    unit = units[index]
  }
  return `${new Intl.NumberFormat(locale, { maximumFractionDigits: 1 }).format(value)} ${unit}`
}

export function mediaErrorKey(error?: string): string {
  const known = new Set([
    'cancelled',
    'capture_failed',
    'invalid_media_type',
    'invalid_import_request',
    'invalid_import_media',
    'invalid_import_url',
    'invalid_upload',
    'invalid_upload_token',
    'media_provider_failed',
    'media_provider_rate_limited',
    'media_provider_unauthorized',
    'missing_config',
    'import_media_not_allowed',
    'import_media_too_large',
    'import_media_unavailable',
    'import_provider_failed',
    'import_provider_unauthorized',
    'import_source_not_found',
    'import_source_unavailable',
    'import_url_not_allowed',
    'import_url_unavailable',
    'import_size_unavailable',
    'not_found',
    'operation_in_progress',
    'owner_changed',
    'profile_photo_required',
    'rate_limited',
    'request_failed',
    'request_timeout',
    'unsupported',
    'upload_failed',
    'upload_timeout',
  ])
  return known.has(error ?? '') ? (error as string) : 'request_failed'
}
