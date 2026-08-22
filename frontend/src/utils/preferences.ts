import type { LaunchablePhoneAppId } from '@/types/apps'
import { cloneJsonData } from '@/utils/clone'

export const APPEARANCE_MODE_IDS = ['automatic', 'light', 'dark'] as const
export const GRAPHICS_MODE_IDS = ['performance', 'ultimate'] as const
export const PHONE_FRAME_IDS = [
  'black',
  'blue',
  'green',
  'lavender',
  'red',
  'white',
  'orange',
  'yellow',
  'lime',
  'teal',
  'cyan',
  'purple',
  'pink',
  'gold',
  'rgb',
] as const
export const RINGTONE_IDS = ['skyline', 'horizon', 'pulse'] as const
export const NOTIFICATION_SOUND_IDS = ['chime', 'signal', 'soft'] as const
export const WALLPAPER_IDS = [
  'midnight',
  'aurora',
  'ember',
  'ocean',
  'sunrise',
  'violet',
  'forest',
  'cobalt',
  'rose',
  'sand',
  'graphite',
  'prism',
] as const
export const PHONE_SCALE_MIN = 75
export const PHONE_SCALE_MAX = 150
export const PHONE_SCALE_STEP = 1
export const PHONE_SETUP_LAST_STEP = 9

export type AppearanceMode = (typeof APPEARANCE_MODE_IDS)[number]
export type GraphicsMode = (typeof GRAPHICS_MODE_IDS)[number]
export type PhoneFrameId = (typeof PHONE_FRAME_IDS)[number]
export type RingtoneId = (typeof RINGTONE_IDS)[number]
export type NotificationSoundId = (typeof NOTIFICATION_SOUND_IDS)[number]
export type BuiltInWallpaperId = (typeof WALLPAPER_IDS)[number]
export type WallpaperId = BuiltInWallpaperId | 'custom'
export type WallpaperTarget = 'home' | 'lock'
export type WallpaperHistoryEntry = {
  imageUrl: string | null
  wallpaper: WallpaperId
}
export type AppNotificationPreferences = {
  enabled: boolean
  sounds: boolean
}

export const DEFAULT_APP_NOTIFICATION_PREFERENCES: AppNotificationPreferences =
  {
    enabled: true,
    sounds: true,
  }

export type PhonePreferencesV1 = {
  settings: {
    airplaneMode: boolean
    appearanceMode: AppearanceMode
    bluetoothEnabled: boolean
    cellularEnabled: boolean
    focusMode: boolean
    frame: PhoneFrameId
    graphicsMode: GraphicsMode
    lockWallpaper: WallpaperId
    lockWallpaperImageUrl: string | null
    notificationSound: NotificationSoundId
    notificationDurationSeconds: number
    notificationVolume: number
    notifications: Record<LaunchablePhoneAppId, AppNotificationPreferences>
    phoneScale: number
    ringtone: RingtoneId
    ringtoneVolume: number
    screenBrightness: number
    setupCompleted: boolean
    setupStep: number
    streamerMode: boolean
    wallpaper: WallpaperId
    wallpaperHistory: WallpaperHistoryEntry[]
    wallpaperImageUrl: string | null
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
  flare: { enabled: true, sounds: true },
  'app-store': { enabled: true, sounds: true },
  calculator: { enabled: true, sounds: true },
  health: { enabled: true, sounds: true },
  snake: { enabled: true, sounds: true },
  memory: { enabled: true, sounds: true },
  'number-merge': { enabled: true, sounds: true },
  minesweeper: { enabled: true, sounds: true },
  'tower-stack': { enabled: true, sounds: true },
  'sky-flappy': { enabled: true, sounds: true },
  'neon-drop': { enabled: true, sounds: true },
  citymarkt: { enabled: true, sounds: true },
  citywarn: { enabled: true, sounds: true },
  companies: { enabled: true, sounds: true },
  'weazel-news': { enabled: true, sounds: true },
  'local-pages': { enabled: true, sounds: true },
  picstagram: { enabled: true, sounds: true },
  fliptok: { enabled: true, sounds: true },
  feather: { enabled: true, sounds: true },
  crewlink: { enabled: true, sounds: true },
  camera: { enabled: true, sounds: true },
  clock: { enabled: true, sounds: true },
  calendar: { enabled: true, sounds: true },
  weather: { enabled: true, sounds: true },
  banking: { enabled: true, sounds: true },
  crypto: { enabled: true, sounds: true },
  billing: { enabled: true, sounds: true },
  garage: { enabled: true, sounds: true },
  skyride: { enabled: true, sounds: true },
  house: { enabled: true, sounds: true },
  mail: { enabled: true, sounds: true },
  map: { enabled: true, sounds: true },
  notes: { enabled: true, sounds: true },
  memos: { enabled: true, sounds: true },
  radio: { enabled: true, sounds: true },
  music: { enabled: true, sounds: true },
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
    graphicsMode: 'ultimate',
    lockWallpaper: 'midnight',
    lockWallpaperImageUrl: null,
    notificationSound: 'chime',
    notificationDurationSeconds: 10,
    notificationVolume: 70,
    notifications: DEFAULT_APP_NOTIFICATIONS,
    phoneScale: 100,
    ringtone: 'skyline',
    ringtoneVolume: 80,
    screenBrightness: 100,
    setupCompleted: false,
    setupStep: 0,
    streamerMode: false,
    wallpaper: 'midnight',
    wallpaperHistory: [{ imageUrl: null, wallpaper: 'midnight' }],
    wallpaperImageUrl: null,
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

function readWallpaperImageUrl(value: unknown): string | null {
  if (typeof value !== 'string') return null
  const imageUrl = value.trim()
  return imageUrl.length > 0 && imageUrl.length <= 2_000_000 ? imageUrl : null
}

function readWallpaperHistory(value: unknown): WallpaperHistoryEntry[] {
  if (!Array.isArray(value)) return []

  const history: WallpaperHistoryEntry[] = []
  for (const rawEntry of value.slice(0, 4)) {
    if (!rawEntry || typeof rawEntry !== 'object' || Array.isArray(rawEntry)) {
      continue
    }
    const entry = rawEntry as Partial<WallpaperHistoryEntry>
    const imageUrl = readWallpaperImageUrl(entry.imageUrl)
    if (entry.wallpaper === 'custom' && imageUrl) {
      history.push({ imageUrl, wallpaper: 'custom' })
      continue
    }
    if (
      typeof entry.wallpaper === 'string' &&
      WALLPAPER_IDS.includes(entry.wallpaper as BuiltInWallpaperId)
    ) {
      history.push({
        imageUrl: null,
        wallpaper: entry.wallpaper as BuiltInWallpaperId,
      })
    }
  }
  return history
}

function readNotifications(
  value: unknown,
): Record<LaunchablePhoneAppId, AppNotificationPreferences> {
  const source: Record<string, unknown> =
    value && typeof value === 'object' ? (value as Record<string, unknown>) : {}
  const notifications = cloneJsonData(DEFAULT_APP_NOTIFICATIONS)

  for (const appId of Object.keys(source)) {
    if (!/^[a-z0-9][a-z0-9._-]{1,63}$/.test(appId)) continue
    const rawPreferences =
      source[appId] &&
      typeof source[appId] === 'object' &&
      !Array.isArray(source[appId])
        ? (source[appId] as Partial<AppNotificationPreferences>)
        : {}
    const defaults =
      DEFAULT_APP_NOTIFICATIONS[appId as LaunchablePhoneAppId] ??
      DEFAULT_APP_NOTIFICATION_PREFERENCES
    notifications[appId as LaunchablePhoneAppId] = {
      enabled: readBoolean(rawPreferences.enabled, defaults.enabled),
      sounds: readBoolean(rawPreferences.sounds, defaults.sounds),
    }
  }

  return notifications
}

export function ensureAppNotificationPreferences(
  preferences: PhonePreferencesV1,
  appIds: LaunchablePhoneAppId[],
): void {
  for (const appId of appIds) {
    preferences.settings.notifications[appId] ??= cloneJsonData(
      DEFAULT_APP_NOTIFICATION_PREFERENCES,
    )
  }
}

export function clampPhoneScale(value: number): number {
  return Math.min(PHONE_SCALE_MAX, Math.max(PHONE_SCALE_MIN, value))
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
    const wallpaperImageUrl = readWallpaperImageUrl(settings.wallpaperImageUrl)
    const wallpaper =
      settings.wallpaper === 'custom' && wallpaperImageUrl
        ? 'custom'
        : readChoice(settings.wallpaper, WALLPAPER_IDS, defaults.wallpaper)
    const requestedLockWallpaperImageUrl = readWallpaperImageUrl(
      settings.lockWallpaperImageUrl,
    )
    const lockWallpaper =
      settings.lockWallpaper === 'custom' && requestedLockWallpaperImageUrl
        ? 'custom'
        : typeof settings.lockWallpaper === 'string' &&
            WALLPAPER_IDS.includes(settings.lockWallpaper as BuiltInWallpaperId)
          ? (settings.lockWallpaper as BuiltInWallpaperId)
          : wallpaper
    const lockWallpaperImageUrl =
      lockWallpaper === 'custom'
        ? (requestedLockWallpaperImageUrl ?? wallpaperImageUrl)
        : null
    const wallpaperHistory = readWallpaperHistory(settings.wallpaperHistory)

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
        graphicsMode: readChoice(
          settings.graphicsMode,
          GRAPHICS_MODE_IDS,
          defaults.graphicsMode,
        ),
        lockWallpaper,
        lockWallpaperImageUrl,
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
        phoneScale: clampPhoneScale(
          readNumber(
            settings.phoneScale,
            defaults.phoneScale,
            Number.MIN_SAFE_INTEGER,
            Number.MAX_SAFE_INTEGER,
          ),
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
        screenBrightness: readNumber(
          settings.screenBrightness,
          defaults.screenBrightness,
          10,
          100,
        ),
        setupCompleted:
          typeof settings.setupCompleted === 'boolean'
            ? settings.setupCompleted
            : true,
        setupStep: Math.floor(
          readNumber(
            settings.setupStep,
            typeof settings.setupCompleted === 'boolean'
              ? defaults.setupStep
              : PHONE_SETUP_LAST_STEP,
            0,
            PHONE_SETUP_LAST_STEP,
          ),
        ),
        streamerMode: readBoolean(settings.streamerMode, defaults.streamerMode),
        wallpaper,
        wallpaperHistory:
          wallpaperHistory.length > 0
            ? wallpaperHistory
            : [
                {
                  imageUrl: wallpaper === 'custom' ? wallpaperImageUrl : null,
                  wallpaper,
                },
              ],
        wallpaperImageUrl: wallpaper === 'custom' ? wallpaperImageUrl : null,
        wifiEnabled: readBoolean(settings.wifiEnabled, defaults.wifiEnabled),
      },
      version: 1,
    }
  } catch {
    return cloneJsonData(DEFAULT_PHONE_PREFERENCES)
  }
}
