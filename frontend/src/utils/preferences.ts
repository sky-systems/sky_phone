export const PHONE_PREFERENCES_KEY = 'sky_phone.preferences.v1'

export type WallpaperId = 'midnight' | 'aurora' | 'ember'

export type PhonePreferencesV1 = {
  settings: {
    airplaneMode: boolean
    bluetooth: boolean
    cellular: boolean
    personalHotspot: boolean
    vpn: boolean
    wallpaper: WallpaperId
    wifi: boolean
  }
  version: 1
}

export const DEFAULT_PHONE_PREFERENCES: PhonePreferencesV1 = {
  settings: {
    airplaneMode: false,
    bluetooth: true,
    cellular: true,
    personalHotspot: false,
    vpn: false,
    wallpaper: 'midnight',
    wifi: true,
  },
  version: 1,
}

export const WALLPAPER_IDS: WallpaperId[] = ['midnight', 'aurora', 'ember']

export function parsePhonePreferences(raw: string | null): PhonePreferencesV1 {
  if (!raw) return structuredClone(DEFAULT_PHONE_PREFERENCES)

  try {
    const parsed = JSON.parse(raw) as Partial<PhonePreferencesV1>
    const settings = parsed.settings
    if (parsed.version !== 1 || !settings || typeof settings !== 'object') {
      return structuredClone(DEFAULT_PHONE_PREFERENCES)
    }

    const defaults = DEFAULT_PHONE_PREFERENCES.settings
    return {
      settings: {
        airplaneMode:
          typeof settings.airplaneMode === 'boolean'
            ? settings.airplaneMode
            : defaults.airplaneMode,
        bluetooth:
          typeof settings.bluetooth === 'boolean'
            ? settings.bluetooth
            : defaults.bluetooth,
        cellular:
          typeof settings.cellular === 'boolean'
            ? settings.cellular
            : defaults.cellular,
        personalHotspot:
          typeof settings.personalHotspot === 'boolean'
            ? settings.personalHotspot
            : defaults.personalHotspot,
        vpn: typeof settings.vpn === 'boolean' ? settings.vpn : defaults.vpn,
        wallpaper: WALLPAPER_IDS.includes(settings.wallpaper as WallpaperId)
          ? (settings.wallpaper as WallpaperId)
          : defaults.wallpaper,
        wifi:
          typeof settings.wifi === 'boolean' ? settings.wifi : defaults.wifi,
      },
      version: 1,
    }
  } catch {
    return structuredClone(DEFAULT_PHONE_PREFERENCES)
  }
}

export function readPhonePreferences(): PhonePreferencesV1 {
  return parsePhonePreferences(
    window.localStorage.getItem(PHONE_PREFERENCES_KEY),
  )
}

export function writePhonePreferences(preferences: PhonePreferencesV1): void {
  window.localStorage.setItem(
    PHONE_PREFERENCES_KEY,
    JSON.stringify(preferences),
  )
}
