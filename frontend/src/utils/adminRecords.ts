import { parseDatabaseDate } from '@/utils/date'

export function adminMediaUrl(value: string): string | undefined {
  try {
    const url = new URL(value)
    if (
      (url.protocol === 'https:' || url.protocol === 'http:') &&
      !url.username &&
      !url.password
    )
      return url.href
  } catch {
    // A damaged media attachment must not break the rest of a moderation page.
  }
  return undefined
}

export function formatAdminTimestamp(
  value: string | number | null | undefined,
  locale: string,
): string {
  if (value === null || value === undefined || value === '') return '—'
  const input =
    typeof value === 'string' && /^\d+$/.test(value.trim())
      ? Number(value)
      : value
  const date = parseDatabaseDate(input)
  if (!Number.isFinite(date.getTime())) return '—'
  return new Intl.DateTimeFormat(locale, {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  }).format(date)
}

export function adminActivityPreview(details: Record<string, unknown>): string {
  const request = details.request
  if (!request || typeof request !== 'object' || Array.isArray(request))
    return ''
  for (const key of [
    'body',
    'caption',
    'title',
    'subject',
    'note',
    'description',
  ]) {
    const value = (request as Record<string, unknown>)[key]
    if (typeof value === 'string' && value.trim()) return value
  }
  return ''
}

export function adminErrorText(
  error: string,
  translate: (key: string) => string,
): string {
  const key = `AdminPanel.errors.${error}`
  const text = translate(key)
  return text === key ? translate('AdminPanel.errors.request_failed') : text
}
