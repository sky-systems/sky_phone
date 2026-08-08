import type { LaunchablePhoneAppId } from '@/types/apps'
import { cloneJsonData } from '@/utils/clone'

export const APPEARANCE_MODE_IDS = ['automatic', 'light', 'dark'] as const
export const PHONE_FRAME_IDS = [
  'black',
  'blue',
  'green',
  'lavender',
  'white',
] as const
export const RINGTONE_IDS = ['skyline', 'horizon', 'pulse'] as const
export const NOTIFICATION_SOUND_IDS = ['chime', 'signal', 'soft'] as const
export const WALLPAPER_IDS = ['midnight', 'aurora', 'ember'] as const
export const PHONE_SCALE_MIN = 50
export const PHONE_SCALE_MAX = 150
export const PHONE_SCALE_STEP = 5

export type AppearanceMode = (typeof APPEARANCE_MODE_IDS)[number]
export type PhoneFrameId = (typeof PHONE_FRAME_IDS)[number]
export type RingtoneId = (typeof RINGTONE_IDS)[number]
export type NotificationSoundId = (typeof NOTIFICATION_SOUND_IDS)[number]
export type WallpaperId = (typeof WALLPAPER_IDS)[number]
export type AppNotificationPreferences = {
  enabled: boolean
  sounds: boolean
}

export type PhonePreferencesV1 = {
  settings: {
    airplaneMode: boolean
    appearanceMode: AppearanceMode
    bluetoothEnabled: boolean
    cellularEnabled: boolean
    focusMode: boolean
    frame: PhoneFrameId
    notificationSound: NotificationSoundId
    notificationDurationSeconds: number
    notificationVolume: number
    notifications: Record<LaunchablePhoneAppId, AppNotificationPreferences>
    phoneScale: number
    ringtone: RingtoneId
    ringtoneVolume: number
    rotationLocked: boolean
    screenBrightness: number
    streamerMode: boolean
    wallpaper: WallpaperId
    wifiEnabled: boolean
  }
  version: 1
}

const DEFAULT_APP_NOTIFICATIONS: Record<
  LaunchablePhoneAppId,
  AppNotificationPreferences
> = {
  phone: { enabled: true, sounds: true },
  messages: { enabled: true, sounds: true },
  darkchat: { enabled: true, sounds: true },
  'app-store': { enabled: true, sounds: true },
  calculator: { enabled: true, sounds: true },
  snake: { enabled: true, sounds: true },
  memory: { enabled: true, sounds: true },
  'number-merge': { enabled: true, sounds: true },
  minesweeper: { enabled: true, sounds: true },
  'tower-stack': { enabled: true, sounds: true },
  'sky-flappy': { enabled: true, sounds: true },
  'neon-drop': { enabled: true, sounds: true },
  citymarkt: { enabled: true, sounds: true },
  'local-pages': { enabled: true, sounds: true },
  camera: { enabled: true, sounds: true },
  clock: { enabled: true, sounds: true },
  calendar: { enabled: true, sounds: true },
  weather: { enabled: true, sounds: true },
  banking: { enabled: true, sounds: true },
  garage: { enabled: true, sounds: true },
  mail: { enabled: true, sounds: true },
  map: { enabled: true, sounds: true },
  notes: { enabled: true, sounds: true },
  radio: { enabled: true, sounds: true },
  photos: { enabled: true, sounds: true },
  settings: { enabled: true, sounds: true },
}

export const DEFAULT_PHONE_PREFERENCES: PhonePreferencesV1 = {
  settings: {
    airplaneMode: false,
    appearanceMode: 'automatic',
    bluetoothEnabled: true,
    cellularEnabled: true,
    focusMode: false,
    frame: 'black',
    notificationSound: 'chime',
    notificationDurationSeconds: 10,
    notificationVolume: 70,
    notifications: DEFAULT_APP_NOTIFICATIONS,
    phoneScale: 100,
    ringtone: 'skyline',
    ringtoneVolume: 80,
    rotationLocked: false,
    screenBrightness: 100,
    streamerMode: false,
    wallpaper: 'midnight',
    wifiEnabled: true,
  },
  version: 1,
}

function readBoolean(value: unknown, fallback: boolean): boolean {
  return typeof value === 'boolean' ? value : fallback
}

function readNumber(
  value: unknown,
  fallback: number,
  minimum: number,
  maximum: number,
): number {
  return typeof value === 'number' && Number.isFinite(value)
    ? Math.min(maximum, Math.max(minimum, value))
    : fallback
}

function readChoice<T extends string>(
  value: unknown,
  choices: readonly T[],
  fallback: T,
): T {
  return typeof value === 'string' && choices.includes(value as T)
    ? (value as T)
    : fallback
}

function readNotifications(
  value: unknown,
): Record<LaunchablePhoneAppId, AppNotificationPreferences> {
  const source =
    value && typeof value === 'object'
      ? (value as Partial<
          Record<LaunchablePhoneAppId, Partial<AppNotificationPreferences>>
        >)
      : {}
  const notifications = cloneJsonData(DEFAULT_APP_NOTIFICATIONS)

  for (const appId of Object.keys(notifications) as LaunchablePhoneAppId[]) {
    notifications[appId] = {
      enabled: readBoolean(
        source[appId]?.enabled,
        DEFAULT_APP_NOTIFICATIONS[appId].enabled,
      ),
      sounds: readBoolean(
        source[appId]?.sounds,
        DEFAULT_APP_NOTIFICATIONS[appId].sounds,
      ),
    }
  }

  return notifications
}

export function parsePhonePreferences(raw: string | null): PhonePreferencesV1 {
  if (!raw) return cloneJsonData(DEFAULT_PHONE_PREFERENCES)

  try {
    const parsed = JSON.parse(raw) as Partial<PhonePreferencesV1>
    const settings = parsed.settings
    if (parsed.version !== 1 || !settings || typeof settings !== 'object') {
      return cloneJsonData(DEFAULT_PHONE_PREFERENCES)
    }

    const defaults = DEFAULT_PHONE_PREFERENCES.settings
    return {
      settings: {
        airplaneMode: readBoolean(settings.airplaneMode, defaults.airplaneMode),
        appearanceMode: readChoice(
          settings.appearanceMode,
          APPEARANCE_MODE_IDS,
          defaults.appearanceMode,
        ),
        bluetoothEnabled: readBoolean(
          settings.bluetoothEnabled,
          defaults.bluetoothEnabled,
        ),
        cellularEnabled: readBoolean(
          settings.cellularEnabled,
          defaults.cellularEnabled,
        ),
        focusMode: readBoolean(settings.focusMode, defaults.focusMode),
        frame: readChoice(settings.frame, PHONE_FRAME_IDS, defaults.frame),
        notificationSound: readChoice(
          settings.notificationSound,
          NOTIFICATION_SOUND_IDS,
          defaults.notificationSound,
        ),
        notificationDurationSeconds: readNumber(
          settings.notificationDurationSeconds,
          defaults.notificationDurationSeconds,
          3,
          30,
        ),
        notificationVolume: readNumber(
          settings.notificationVolume,
          defaults.notificationVolume,
          0,
          100,
        ),
        notifications: readNotifications(settings.notifications),
        phoneScale: readNumber(
          settings.phoneScale,
          defaults.phoneScale,
          PHONE_SCALE_MIN,
          PHONE_SCALE_MAX,
        ),
        ringtone: readChoice(
          settings.ringtone,
          RINGTONE_IDS,
          defaults.ringtone,
        ),
        ringtoneVolume: readNumber(
          settings.ringtoneVolume,
          defaults.ringtoneVolume,
          0,
          100,
        ),
        rotationLocked: readBoolean(
          settings.rotationLocked,
          defaults.rotationLocked,
        ),
        screenBrightness: readNumber(
          settings.screenBrightness,
          defaults.screenBrightness,
          10,
          100,
        ),
        streamerMode: readBoolean(settings.streamerMode, defaults.streamerMode),
        wallpaper: readChoice(
          settings.wallpaper,
          WALLPAPER_IDS,
          defaults.wallpaper,
        ),
        wifiEnabled: readBoolean(settings.wifiEnabled, defaults.wifiEnabled),
      },
      version: 1,
    }
  } catch {
    return cloneJsonData(DEFAULT_PHONE_PREFERENCES)
  }
}
