import { defineStore } from 'pinia'

import type { AppLaunchOrigin } from '@/types/apps'
import { clampPage } from '@/utils/pages'
import {
  readPhonePreferences,
  type WallpaperId,
  writePhonePreferences,
} from '@/utils/preferences'

type LocaleTree = Record<string, unknown>

export type PhoneOpenPayload = {
  lang?: string
  locales?: LocaleTree
}

const defaultLocales: LocaleTree = {
  Apps: {
    appStore: {
      name: 'App Store',
      eyebrow: 'Discover',
      featured: 'Featured',
      heroTitle: 'Apps for every day',
      heroBody: 'Fresh ideas, built for your life in the city.',
      get: 'GET',
      open: 'OPEN',
      searchPlaceholder: 'Games, Apps, Stories and More',
      tabs: {
        today: 'Today',
        apps: 'Apps',
        games: 'Games',
        arcade: 'Arcade',
        search: 'Search',
      },
      catalog: {
        orbit: 'Plan your day',
        studio: 'Create something new',
        trail: 'Explore nearby',
        prism: 'A colorful puzzle',
      },
    },
    calculator: { name: 'Calculator' },
    camera: {
      name: 'Camera',
      shutter: 'Take photo',
      flip: 'Flip camera',
      modes: { video: 'Video', photo: 'Photo', portrait: 'Portrait' },
    },
    clock: {
      name: 'Clock',
      lap: 'Lap',
      minutes: 'Minutes',
      tabs: {
        world: 'World Clock',
        alarm: 'Alarm',
        stopwatch: 'Stopwatch',
        timer: 'Timer',
      },
      cities: {
        cupertino: 'Cupertino',
        newYork: 'New York',
        london: 'London',
        tokyo: 'Tokyo',
      },
      alarm: { weekday: 'Weekdays', weekend: 'Weekend' },
    },
    photos: {
      name: 'Photos',
      searchPlaceholder: 'Photos, people, places...',
      recents: 'Recents',
      favorites: 'Favorites',
      items: 'items',
      memories: 'Memories',
      featured: 'City colors',
      tabs: {
        library: 'Library',
        forYou: 'For You',
        albums: 'Albums',
        search: 'Search',
      },
      samples: {
        sunset: 'Sunset drive',
        ocean: 'Ocean air',
        city: 'City lights',
        desert: 'Desert road',
        capture: 'Camera capture',
      },
    },
    settings: {
      name: 'Settings',
      searchPlaceholder: 'Search',
      wifi: 'Wi-Fi',
      bluetooth: 'Bluetooth',
      airplaneMode: 'Airplane Mode',
      wallpaper: 'Wallpaper',
      toggle: {
        wifi: 'Toggle Wi-Fi',
        bluetooth: 'Toggle Bluetooth',
        airplaneMode: 'Toggle Airplane Mode',
      },
      wallpapers: {
        midnight: 'Midnight wallpaper',
        aurora: 'Aurora wallpaper',
        ember: 'Ember wallpaper',
      },
    },
  },
  Common: {
    cancel: 'Cancel',
    close: 'Close',
    home: 'Home',
    pause: 'Pause',
    phone: 'Phone',
    phoneStatus: 'Phone status',
    reset: 'Reset',
    search: 'Search',
    start: 'Start',
    stop: 'Stop',
  },
  Home: {
    appLibrary: 'App Library',
    appLibrarySearch: 'Search apps',
    apps: 'Apps',
    dock: 'Dock',
    noApps: 'No apps found',
    page: 'Page',
    pages: 'Home screen pages',
    groups: { 0: 'Productivity', 1: 'Creativity' },
    widgets: {
      label: 'Widgets',
      weather: { city: 'Los Santos', condition: 'Partly Cloudy' },
      calendar: { event: 'No more events today' },
      battery: { label: 'Phone' },
      media: {
        title: 'Night Drive',
        artist: 'Sky Radio',
        play: 'Play',
        pause: 'Pause',
      },
    },
  },
}

function getByPath(source: LocaleTree, path: string): unknown {
  return path.split('.').reduce<unknown>((current, segment) => {
    if (
      typeof current !== 'object' ||
      current === null ||
      Array.isArray(current)
    )
      return undefined
    return (current as LocaleTree)[segment]
  }, source)
}

export const usePhoneStore = defineStore('phone', {
  state: () => ({
    currentPage: 1,
    isOpen: false,
    lang: 'en',
    launchOrigin: null as AppLaunchOrigin | null,
    locales: defaultLocales,
    preferences: readPhonePreferences(),
  }),
  actions: {
    close(): void {
      this.isOpen = false
    },
    open(payload: PhoneOpenPayload = {}): void {
      this.lang = payload.lang ?? 'en'
      this.locales = payload.locales ?? defaultLocales
      this.isOpen = true
    },
    setCurrentPage(page: number): void {
      this.currentPage = clampPage(page)
    },
    setLaunchOrigin(origin: AppLaunchOrigin | null): void {
      this.launchOrigin = origin
    },
    setSetting(
      key: Exclude<keyof typeof this.preferences.settings, 'wallpaper'>,
      value: boolean,
    ): void {
      this.preferences.settings[key] = value
      writePhonePreferences(this.preferences)
    },
    setWallpaper(wallpaper: WallpaperId): void {
      this.preferences.settings.wallpaper = wallpaper
      writePhonePreferences(this.preferences)
    },
    t(path: string): string {
      const translated = getByPath(this.locales, path)
      const fallback = getByPath(defaultLocales, path)
      return typeof translated === 'string'
        ? translated
        : typeof fallback === 'string'
          ? fallback
          : path
    },
  },
})
