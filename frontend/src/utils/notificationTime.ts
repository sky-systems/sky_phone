const MAX_DATE_TIMESTAMP = 8_640_000_000_000_000
const relativeFormatters = new Map<string, Intl.RelativeTimeFormat>()

export function isNotificationTimestamp(value: unknown): value is number {
  return (
    typeof value === 'number' &&
    Number.isInteger(value) &&
    value > 0 &&
    value <= MAX_DATE_TIMESTAMP
  )
}

export function readNotificationTimestamp(notification: {
  createdAt?: number
  id: string
}): number | undefined {
  if (isNotificationTimestamp(notification.createdAt))
    return notification.createdAt

  // Previous versions already encoded the reception time in generated IDs.
  const legacyTime = /^notification-(\d+)-[a-z0-9]+$/.exec(notification.id)?.[1]
  const timestamp = legacyTime ? Number(legacyTime) : undefined
  return isNotificationTimestamp(timestamp) ? timestamp : undefined
}

export function formatNotificationTime(
  createdAt: number | undefined,
  locale: string,
  now: number,
  nowLabel: string,
): string {
  if (!isNotificationTimestamp(createdAt)) return ''
  const minutes = Math.floor(Math.max(0, now - createdAt) / 60_000)
  if (minutes < 1) return nowLabel

  let formatter = relativeFormatters.get(locale)
  if (!formatter) {
    formatter = new Intl.RelativeTimeFormat(locale, {
      numeric: 'always',
      style: 'short',
    })
    relativeFormatters.set(locale, formatter)
  }
  const unit = minutes < 60 ? 'minute' : minutes < 1_440 ? 'hour' : 'day'
  const amount =
    unit === 'minute'
      ? minutes
      : Math.floor(minutes / (unit === 'hour' ? 60 : 1_440))
  const label = formatter.format(-amount, unit)
  return label.charAt(0).toLocaleUpperCase(locale) + label.slice(1)
}
