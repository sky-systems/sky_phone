import { defineStore } from 'pinia'

import type { AppLaunchOrigin, PhoneAppId } from '@/types/apps'
import { clampPage } from '@/utils/pages'
import {
  readPhonePreferences,
  type AppNotificationPreferences,
  type PhonePreferencesV1,
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
      add: 'Add alarm',
      location: 'Los Santos',
      tabs: {
        world: 'World Clock',
        alarm: 'Alarm',
        stopwatch: 'Stopwatch',
        timer: 'Timer',
      },
      alarm: {
        add: 'Add Alarm',
        edit: 'Edit Alarm',
        ringing: 'Alarm',
        time: 'Time',
        hours: 'Hours',
        repeat: 'Repeat',
        note: 'Note',
        notePlaceholder: 'Alarm',
        sound: 'Sound',
        delete: 'Delete Alarm',
        never: 'Never',
        everyDay: 'Every Day',
        weekdays: 'Weekdays',
        weekends: 'Weekends',
        days: {
          sunday: 'Sunday',
          monday: 'Monday',
          tuesday: 'Tuesday',
          wednesday: 'Wednesday',
          thursday: 'Thursday',
          friday: 'Friday',
          saturday: 'Saturday',
        },
        daysShort: {
          sunday: 'Sun',
          monday: 'Mon',
          tuesday: 'Tue',
          wednesday: 'Wed',
          thursday: 'Thu',
          friday: 'Fri',
          saturday: 'Sat',
        },
        sounds: { radar: 'Radar', beacon: 'Beacon', chimes: 'Chimes' },
      },
      timer: {
        time: 'Timer duration',
        hours: 'Hours',
        hoursShort: 'hr',
        minutes: 'Minutes',
        minutesShort: 'min',
        seconds: 'Seconds',
        secondsShort: 'sec',
        note: 'Note',
        notePlaceholder: 'Timer',
        sound: 'Sound',
        ringing: 'Timer',
      },
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
      airplaneMode: 'Airplane Mode',
      streamerMode: 'Streamer Mode',
      wallpaper: 'Wallpaper',
      on: 'On',
      off: 'Off',
      accountName: 'iFruit Account',
      accountDetail: 'Cloud, Media & Purchases',
      accountLocalDetail: 'Local account for this phone',
      accountInformation: 'Account Information',
      accountStatus: 'Account Status',
      accountStatusValue: 'Active',
      accountStorage: 'Cloud Storage',
      accountStorageValue: 'On Device',
      accountPurchases: 'Media & Purchases',
      accountPurchasesValue: 'Available',
      notifications: 'Notifications',
      sounds: 'Sounds & Haptics',
      general: 'General Settings',
      appearance: 'Appearance',
      allowNotifications: 'Allow Notifications',
      notificationSounds: 'Sounds',
      notificationDuration: 'Notification Duration',
      seconds: '{seconds} seconds',
      ringtoneVolume: 'Ringtone Volume',
      notificationVolume: 'Notification Volume',
      ringtone: 'Ringtone',
      notificationSound: 'Notification Sound',
      appearanceMode: 'Appearance Mode',
      automatic: 'Automatic',
      light: 'Light',
      dark: 'Dark',
      phoneScale: 'Phone Scale',
      phoneFrame: 'Phone Frame',
      about: 'About',
      deviceName: 'Device Name',
      deviceNameValue: 'Sky Phone',
      softwareVersion: 'Software Version',
      language: 'Language',
      languageValue: 'English',
      localStorage: 'Local Storage',
      localStorageValue: 'On Device',
      back: 'Settings',
      wallpaperPicker: 'Built-in Wallpapers',
      toggle: {
        airplaneMode: 'Toggle Airplane Mode',
        streamerMode: 'Toggle Streamer Mode',
        notifications: 'Toggle notifications for {app}',
        notificationSounds: 'Toggle notification sounds for {app}',
      },
      frames: {
        black: 'Black',
        blue: 'Blue',
        green: 'Green',
        lavender: 'Lavender',
        white: 'White',
      },
      ringtones: {
        skyline: 'Skyline',
        horizon: 'Horizon',
        pulse: 'Pulse',
      },
      notificationSoundsList: {
        chime: 'Chime',
        signal: 'Signal',
        soft: 'Soft',
      },
      wallpapers: {
        midnight: 'Midnight wallpaper',
        aurora: 'Aurora wallpaper',
        ember: 'Ember wallpaper',
      },
    },
  },
  Common: {
    add: 'Add',
    cancel: 'Cancel',
    close: 'Close',
    delete: 'Delete',
    done: 'Done',
    edit: 'Edit',
    home: 'Home',
    pause: 'Pause',
    phone: 'Phone',
    phoneStatus: 'Phone status',
    reset: 'Reset',
    search: 'Search',
    save: 'Save',
    start: 'Start',
    stop: 'Stop',
  },
  Notifications: { now: 'now' },
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
    systemDarkMode: window.matchMedia('(prefers-color-scheme: dark)').matches,
  }),
  getters: {
    isDarkMode(state): boolean {
      if (state.preferences.settings.appearanceMode === 'dark') return true
      if (state.preferences.settings.appearanceMode === 'light') return false
      return state.systemDarkMode
    },
  },
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
    setAppNotification(
      appId: PhoneAppId,
      key: keyof AppNotificationPreferences,
      value: boolean,
    ): void {
      this.preferences.settings.notifications[appId][key] = value
      writePhonePreferences(this.preferences)
    },
    setPreference<K extends keyof PhonePreferencesV1['settings']>(
      key: K,
      value: PhonePreferencesV1['settings'][K],
    ): void {
      this.preferences.settings[key] = value
      writePhonePreferences(this.preferences)
    },
    setSystemDarkMode(value: boolean): void {
      this.systemDarkMode = value
    },
    setWallpaper(wallpaper: WallpaperId): void {
      this.preferences.settings.wallpaper = wallpaper
      writePhonePreferences(this.preferences)
    },
    t(path: string, replacements: Record<string, string> = {}): string {
      const translated = getByPath(this.locales, path)
      const fallback = getByPath(defaultLocales, path)
      const value =
        typeof translated === 'string'
          ? translated
          : typeof fallback === 'string'
            ? fallback
            : path
      return Object.entries(replacements).reduce(
        (result, [key, replacement]) =>
          result.split(`{${key}}`).join(replacement),
        value,
      )
    },
  },
})
