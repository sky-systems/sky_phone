import { describe, expect, it } from 'vitest'
import { formatLockScreenDate } from './lockScreen'
import { parsePhonePreferences } from './preferences'

describe('Lock Screen date preference', () => {
  const date = new Date(2026, 9, 15, 12)

  it('formats the abbreviated German date without a comma', () => {
    expect(formatLockScreenDate(date, 'de-DE', 'short')).toBe('Do. 15. Okt.')
    expect(formatLockScreenDate(date, 'de-DE', 'long')).toBe(
      'Donnerstag, 15. Oktober',
    )
  })

  it('uses the selected locale for full dates', () => {
    expect(formatLockScreenDate(date, 'en-US', 'long')).toBe(
      'Thursday, October 15',
    )
    expect(formatLockScreenDate(date, 'ja-JP', 'short')).toContain('15')
  })

  it('roundtrips both formats and handles existing or invalid preferences', () => {
    for (const lockScreenDateFormat of ['short', 'long']) {
      const preferences = parsePhonePreferences(
        JSON.stringify({
          version: 1,
          settings: { lockScreenDateFormat },
        }),
      )
      expect(
        parsePhonePreferences(JSON.stringify(preferences)).settings
          .lockScreenDateFormat,
      ).toBe(lockScreenDateFormat)
    }
    for (const lockScreenDateFormat of [
      undefined,
      null,
      '',
      'unsupported',
      1,
    ]) {
      expect(
        parsePhonePreferences(
          JSON.stringify({
            version: 1,
            settings: { lockScreenDateFormat },
          }),
        ).settings.lockScreenDateFormat,
      ).toBe('short')
    }
  })
})
