import { describe, expect, it } from 'vitest'
import type { LaunchablePhoneAppId } from '@/types/apps'
import {
  DEFAULT_PHONE_PREFERENCES,
  PHONE_SETUP_LAST_STEP,
  parsePhonePreferences,
  WALLPAPER_IDS,
} from './preferences'
describe('preferences', () => {
  it('starts Setup Assistant for a phone without saved settings', () => {
    const value = parsePhonePreferences(null)

    expect(value.settings.setupCompleted).toBe(false)
    expect(value.settings.setupStep).toBe(0)
  })

  it('migrates existing phones past Setup Assistant', () => {
    const value = parsePhonePreferences(
      JSON.stringify({ version: 1, settings: { wallpaper: 'aurora' } }),
    )

    expect(value.settings.setupCompleted).toBe(true)
    expect(value.settings.setupStep).toBe(PHONE_SETUP_LAST_STEP)
  })

  it('restores an interrupted Setup Assistant step', () => {
    const value = parsePhonePreferences(
      JSON.stringify({
        version: 1,
        settings: { setupCompleted: false, setupStep: 5 },
      }),
    )

    expect(value.settings.setupCompleted).toBe(false)
    expect(value.settings.setupStep).toBe(5)
  })

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
    expect(value.settings.notifications.skypic).toEqual({
      enabled: true,
      sounds: true,
    })
    expect(value.settings.phoneScale).toBe(110)
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
    expect(value.settings.graphicsMode).toBe('ultimate')
    expect(value.settings.notificationVolume).toBe(0)
    expect(value.settings.notificationDurationSeconds).toBe(30)
    expect(value.settings.phoneScale).toBe(150)
    expect(value.settings.ringtoneVolume).toBe(100)
    expect(value.settings.screenBrightness).toBe(10)
  })

  it('keeps the phone above the minimum usable scale', () => {
    const value = parsePhonePreferences(
      JSON.stringify({
        version: 1,
        settings: { phoneScale: 50 },
      }),
    )

    expect(value.settings.phoneScale).toBe(75)
  })

  it('preserves safe notification preferences for custom apps', () => {
    const appId = 'example-app' as LaunchablePhoneAppId
    const value = parsePhonePreferences(
      JSON.stringify({
        version: 1,
        settings: {
          notifications: {
            [appId]: { enabled: false, sounds: true },
            '../unsafe': { enabled: false, sounds: false },
          },
        },
      }),
    )

    expect(value.settings.notifications[appId]).toEqual({
      enabled: false,
      sounds: true,
    })
    expect(value.settings.notifications).not.toHaveProperty('../unsafe')
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
      graphicsMode: 'ultimate',
      screenBrightness: 100,
      wifiEnabled: true,
    })
  })

  it('provides twelve built-in wallpapers', () => {
    expect(WALLPAPER_IDS).toHaveLength(12)
    expect(new Set(WALLPAPER_IDS).size).toBe(12)
  })

  it('restores custom photo wallpapers and only the latest four history entries', () => {
    const value = parsePhonePreferences(
      JSON.stringify({
        version: 1,
        settings: {
          wallpaper: 'custom',
          wallpaperImageUrl: 'https://media.example/current.jpg',
          wallpaperHistory: [
            {
              wallpaper: 'custom',
              imageUrl: 'https://media.example/current.jpg',
            },
            { wallpaper: 'prism', imageUrl: null },
            { wallpaper: 'ocean', imageUrl: null },
            { wallpaper: 'rose', imageUrl: null },
            { wallpaper: 'sand', imageUrl: null },
          ],
        },
      }),
    )

    expect(value.settings.wallpaper).toBe('custom')
    expect(value.settings.wallpaperImageUrl).toBe(
      'https://media.example/current.jpg',
    )
    expect(value.settings.lockWallpaper).toBe('custom')
    expect(value.settings.lockWallpaperImageUrl).toBe(
      'https://media.example/current.jpg',
    )
    expect(value.settings.wallpaperHistory).toHaveLength(4)
    expect(
      value.settings.wallpaperHistory.map((entry) => entry.wallpaper),
    ).toEqual(['custom', 'prism', 'ocean', 'rose'])
  })

  it('rejects a custom wallpaper without a photo URL', () => {
    const value = parsePhonePreferences(
      JSON.stringify({
        version: 1,
        settings: { wallpaper: 'custom', wallpaperImageUrl: '' },
      }),
    )

    expect(value.settings.wallpaper).toBe('midnight')
    expect(value.settings.wallpaperImageUrl).toBeNull()
  })

  it('restores independent Home Screen and Lock Screen wallpapers', () => {
    const value = parsePhonePreferences(
      JSON.stringify({
        version: 1,
        settings: {
          wallpaper: 'ocean',
          lockWallpaper: 'custom',
          lockWallpaperImageUrl: 'https://media.example/lock.jpg',
        },
      }),
    )

    expect(value.settings.wallpaper).toBe('ocean')
    expect(value.settings.wallpaperImageUrl).toBeNull()
    expect(value.settings.lockWallpaper).toBe('custom')
    expect(value.settings.lockWallpaperImageUrl).toBe(
      'https://media.example/lock.jpg',
    )
  })
})
