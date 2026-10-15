import { describe, expect, it } from 'vitest'

import {
  formatNotificationTime,
  isNotificationTimestamp,
  readNotificationTimestamp,
} from './notificationTime'

const now = Date.parse('2026-10-15T16:00:00Z')

describe('notification reception time', () => {
  it('keeps fresh notifications localised, then counts complete minutes', () => {
    expect(formatNotificationTime(now, 'de', now + 59_999, 'Jetzt')).toBe(
      'Jetzt',
    )
    expect(formatNotificationTime(now, 'de', now + 60_000, 'Jetzt')).toBe(
      'Vor 1 Min.',
    )
    expect(formatNotificationTime(now, 'de', now + 39 * 60_000, 'Jetzt')).toBe(
      'Vor 39 Min.',
    )
    expect(formatNotificationTime(now, 'en', now + 39 * 60_000, 'now')).toBe(
      '39 min. ago',
    )
    expect(
      formatNotificationTime(now, 'fr', now + 39 * 60_000, 'maintenant'),
    ).toBe('Il y a 39\u00a0min')
  })

  it('moves to hours and days without rounding up early', () => {
    expect(formatNotificationTime(now, 'de', now + 59 * 60_000, 'Jetzt')).toBe(
      'Vor 59 Min.',
    )
    expect(formatNotificationTime(now, 'de', now + 60 * 60_000, 'Jetzt')).toBe(
      'Vor 1 Std.',
    )
    expect(
      formatNotificationTime(now, 'de', now + 24 * 60 * 60_000, 'Jetzt'),
    ).toBe('Vor 1 Tag')
    expect(
      formatNotificationTime(now, 'en', now + 48 * 60 * 60_000, 'now'),
    ).toBe('2 days ago')
  })

  it('does not invent an age for old records without a known reception time', () => {
    expect(formatNotificationTime(undefined, 'de', now, 'Jetzt')).toBe('')
    expect(
      readNotificationTimestamp({ id: 'saved-notification' }),
    ).toBeUndefined()
    expect(
      readNotificationTimestamp({ id: `notification-${now}-abc1234` }),
    ).toBe(now)
    expect(
      readNotificationTimestamp({
        id: `notification-${now}-abc1234`,
        createdAt: now - 1000,
      }),
    ).toBe(now - 1000)
  })

  it.each([
    undefined,
    null,
    0,
    -1,
    NaN,
    Infinity,
    1.5,
    '1792080000000',
    8_640_000_000_000_001,
  ])('rejects an invalid date value: %s', (value) =>
    expect(isNotificationTimestamp(value)).toBe(false),
  )

  it('treats a future local timestamp as fresh after a clock correction', () => {
    expect(formatNotificationTime(now + 60_000, 'de', now, 'Jetzt')).toBe(
      'Jetzt',
    )
  })
})
