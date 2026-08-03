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
      communityTitle: 'Black Voices and Creators',
      communityBody: 'Apps and games from the community',
      playing: "What We're Playing",
      recommended: 'Recommended for You',
      selected: 'Great apps selected by our editors',
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
      card: {
        oneEyebrow: 'App of the Day',
        oneTitle: 'A universe in your pocket',
        oneBody: 'Explore something extraordinary today.',
        twoEyebrow: 'Now Trending',
        twoTitle: 'Turn up your afternoon',
        twoBody: 'Fresh sounds and stories picked for you.',
        threeEyebrow: "Editors' Choice",
        threeTitle: 'Play without limits',
        threeBody: 'A new world is waiting.',
      },
    },
    calculator: { name: 'Calculator' },
    camera: {
      name: 'Camera',
      shutter: 'Take photo',
      flip: 'Flip camera',
      flash: 'Toggle flash',
      controls: 'Camera controls',
      modes: {
        timelapse: 'Timelapse',
        slowMo: 'Slow-Mo',
        cinematic: 'Cinematic',
        video: 'Video',
        photo: 'Photo',
        portrait: 'Portrait',
        pano: 'Pano',
      },
    },
    clock: {
      name: 'Clock',
      lap: 'Lap',
      minutes: 'Minutes',
      add: 'Add clock',
      today: 'Today',
      offset: '+0HRS',
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
      dateRange: '19 Apr–7 May 2024',
      place: 'Los Santos & more',
      select: 'Select',
      count: '3,042 Photos, 125 Videos',
      years: 'Years',
      months: 'Months',
      days: 'Days',
      allPhotos: 'All Photos',
      seeAll: 'See All',
      onThisDay: 'On This Day',
      trip: 'MAR 2024 TRIP',
      featuredPhotos: 'Featured Photos',
      featuredDate: '30 Mar 2024',
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
      on: 'On',
      accountName: 'Sky Citizen',
      accountDetail: 'Apple ID, iCloud, Media & Purchases',
      mobileServices: 'Mobile Services',
      personalHotspot: 'Personal Hotspot',
      vpn: 'VPN',
      notifications: 'Notifications',
      sounds: 'Sounds & Haptics',
      focus: 'Focus',
      screenTime: 'Screen Time',
      general: 'General',
      display: 'Display & Brightness',
      homeScreen: 'Home Screen & App Library',
      accessibility: 'Accessibility',
      battery: 'Battery',
      privacy: 'Privacy & Security',
      passwords: 'Passwords',
      wallpaperPicker: 'Built-in Wallpapers',
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
    edit: 'Edit',
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
    allApps: 'All Apps',
    apps: 'Apps',
    dock: 'Dock',
    noApps: 'No apps found',
    page: 'Page',
    pages: 'Home screen pages',
    groups: { 0: 'Suggestions', 1: 'Recently Added', other: 'Other' },
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
