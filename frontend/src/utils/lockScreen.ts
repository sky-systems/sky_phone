import type { LockScreenDateFormat } from '@/utils/preferences'

export function formatLockScreenDate(
  date: Date,
  locale: string,
  format: LockScreenDateFormat,
): string {
  const formatted = new Intl.DateTimeFormat(locale, {
    day: 'numeric',
    month: format === 'short' ? 'short' : 'long',
    weekday: format === 'short' ? 'short' : 'long',
  }).format(date)
  return format === 'short' ? formatted.replace(/,\s*/g, ' ') : formatted
}
