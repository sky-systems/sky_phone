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
          bluetoothEnabled: false,
          cellularEnabled: false,
          focusMode: true,
          frame: 'rgb',
          graphicsMode: 'ultimate',
          notificationVolume: 45,
          notificationDurationSeconds: 14,
          notifications: {
            messages: { enabled: false, sounds: false },
            clock: { enabled: false, sounds: false },
          },
          phoneScale: 110,
          rotationLocked: true,
          screenBrightness: 64,
          wallpaper: 'ember',
          wifiEnabled: false,
        },
      }),
    )
    expect(value.settings.appearanceMode).toBe('light')
    expect(value.settings.bluetoothEnabled).toBe(false)
    expect(value.settings.cellularEnabled).toBe(false)
    expect(value.settings.focusMode).toBe(true)
    expect(value.settings.frame).toBe('rgb')
    expect(value.settings.graphicsMode).toBe('ultimate')
    expect(value.settings.notificationVolume).toBe(45)
    expect(value.settings.notificationDurationSeconds).toBe(14)
    expect(value.settings.notifications.messages).toEqual({
      enabled: false,
      sounds: false,
    })
    expect(value.settings.notifications.clock).toEqual({
      enabled: false,
      sounds: false,
    })
    expect(value.settings.notifications.mail).toEqual({
      enabled: true,
      sounds: true,
    })
    expect(value.settings.phoneScale).toBe(110)
    expect(value.settings.rotationLocked).toBe(true)
    expect(value.settings.screenBrightness).toBe(64)
    expect(value.settings.wallpaper).toBe('ember')
    expect(value.settings.wifiEnabled).toBe(false)
  })

  it('clamps ranges and rejects unknown choices', () => {
    const value = parsePhonePreferences(
      JSON.stringify({
        version: 1,
        settings: {
          appearanceMode: 'neon',
          frame: 'bronze',
          graphicsMode: 'cinematic',
          notificationVolume: -10,
          notificationDurationSeconds: 100,
          phoneScale: 500,
          ringtoneVolume: 120,
          screenBrightness: -20,
        },
      }),
    )

    expect(value.settings.appearanceMode).toBe('automatic')
    expect(value.settings.frame).toBe('black')
    expect(value.settings.graphicsMode).toBe('performance')
    expect(value.settings.notificationVolume).toBe(0)
    expect(value.settings.notificationDurationSeconds).toBe(30)
    expect(value.settings.phoneScale).toBe(150)
    expect(value.settings.ringtoneVolume).toBe(100)
    expect(value.settings.screenBrightness).toBe(10)
  })

  it('adds safe control center defaults to legacy version one preferences', () => {
    const value = parsePhonePreferences(
      JSON.stringify({ version: 1, settings: { airplaneMode: true } }),
    )

    expect(value.settings).toMatchObject({
      airplaneMode: true,
      bluetoothEnabled: true,
      cellularEnabled: true,
      focusMode: false,
      graphicsMode: 'performance',
      rotationLocked: false,
      screenBrightness: 100,
      wifiEnabled: true,
    })
  })
})
