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
        settings: {
          appearanceMode: 'light',
          notificationVolume: 45,
          notificationDurationSeconds: 14,
          notifications: {
            camera: { enabled: false, sounds: false },
          },
          phoneScale: 110,
          wallpaper: 'ember',
        },
      }),
    )
    expect(value.settings.appearanceMode).toBe('light')
    expect(value.settings.notificationVolume).toBe(45)
    expect(value.settings.notificationDurationSeconds).toBe(14)
    expect(value.settings.notifications.camera).toEqual({
      enabled: false,
      sounds: false,
    })
    expect(value.settings.notifications.clock.enabled).toBe(true)
    expect(value.settings.notifications.mail).toEqual({
      enabled: true,
      sounds: true,
    })
    expect(value.settings.phoneScale).toBe(110)
    expect(value.settings.wallpaper).toBe('ember')
  })

  it('clamps ranges and rejects unknown choices', () => {
    const value = parsePhonePreferences(
      JSON.stringify({
        version: 1,
        settings: {
          appearanceMode: 'neon',
          frame: 'gold',
          notificationVolume: -10,
          notificationDurationSeconds: 100,
          phoneScale: 500,
          ringtoneVolume: 120,
        },
      }),
    )

    expect(value.settings.appearanceMode).toBe('automatic')
    expect(value.settings.frame).toBe('black')
    expect(value.settings.notificationVolume).toBe(0)
    expect(value.settings.notificationDurationSeconds).toBe(30)
    expect(value.settings.phoneScale).toBe(150)
    expect(value.settings.ringtoneVolume).toBe(100)
  })
})
