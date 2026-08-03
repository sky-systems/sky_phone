import { describe, expect, it } from 'vitest'
import { DEFAULT_PHONE_PREFERENCES, parsePhonePreferences } from './preferences'
describe('preferences', () => {
  it('falls back for malformed and obsolete records', () => {
    expect(parsePhonePreferences('{')).toEqual(DEFAULT_PHONE_PREFERENCES)
    expect(parsePhonePreferences('{"version":2}')).toEqual(
      DEFAULT_PHONE_PREFERENCES,
    )
  })
  it('keeps valid harmless preferences', () => {
    const value = parsePhonePreferences(
      JSON.stringify({
        version: 1,
        settings: { wifi: false, wallpaper: 'ember' },
      }),
    )
    expect(value.settings.wifi).toBe(false)
    expect(value.settings.wallpaper).toBe('ember')
  })
})
