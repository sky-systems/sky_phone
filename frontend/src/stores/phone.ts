import { defineStore } from 'pinia'

import type { AppLaunchOrigin, PhoneAppId } from '@/types/apps'
import type { DeviceBootstrap, PhoneDevice } from '@/types/device'
import { clampPage } from '@/utils/pages'
import { nuiCall } from '@/utils/nui'
import {
  DEFAULT_PHONE_PREFERENCES,
  parsePhonePreferences,
  type AppNotificationPreferences,
  type PhonePreferencesV1,
  type WallpaperId,
} from '@/utils/preferences'

type LocaleTree = Record<string, unknown>

export type PhoneOpenPayload = {
  account?: DeviceBootstrap['account']
  device?: PhoneDevice
  lang?: string
  locales?: LocaleTree
  notes?: DeviceBootstrap['notes']
  token?: string
}

const namespaceQueues = new Map<string, Promise<void>>()

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
    phone: {
      name: 'Phone',
      recents: 'Recents',
      contacts: 'Contacts',
      keypad: 'Keypad',
      noSim: 'No SIM',
      noSimBody: 'Insert a SIM card in Settings to make calls.',
      noRecents: 'No Recent Calls',
      noContacts: 'No Contacts',
      searchContacts: 'Search Contacts',
      addContact: 'New Contact',
      editContact: 'Edit Contact',
      contactName: 'Name',
      phoneNumber: 'Phone Number',
      call: 'Call',
      calling: 'calling...',
      incoming: 'Incoming Call',
      incomingDirection: 'Incoming',
      outgoingDirection: 'Outgoing',
      connected: 'Connected',
      missed: 'Missed',
      declined: 'Declined',
      busy: 'Busy',
      unavailable: 'Unavailable',
      noAnswer: 'No Answer',
      cancelled: 'Cancelled',
      disconnected: 'Disconnected',
      sim_removed: 'SIM Removed',
      completed: 'Call Ended',
      answer: 'Answer',
      decline: 'Decline',
      hangup: 'End',
      addToContacts: 'Add to Contacts',
      deleteContact: 'Delete Contact',
      replaceTitle: 'Replace SIM?',
      replaceBody: 'The current SIM will be returned to your inventory.',
      choosePhone: 'Choose a Phone',
      choosePhoneBody: 'Select the phone that should receive {number}.',
      emptyPhone: 'No SIM inserted',
      errors: {
        invalid_contact: 'Enter a name and valid phone number.',
        invalid_number: 'Enter a valid phone number.',
        no_sim: 'This phone has no SIM card.',
        airplane_mode: 'Turn off Airplane Mode to make calls.',
        self_call: 'You cannot call your own number.',
        busy: 'The line is busy.',
        rate_limited: 'Too many calls. Try again in a minute.',
        voice_unavailable: 'The configured phone voice service is unavailable.',
        inventory_full: 'There is no room for the ejected SIM card.',
        operation_in_progress:
          'Another phone operation is already in progress.',
        sim_request_expired:
          'The SIM selection expired. Use the SIM card again.',
        sim_not_owned: 'That SIM card is no longer in your inventory.',
        phone_not_owned: 'That phone is no longer in your inventory.',
        metadata_unsupported:
          'The configured inventory cannot store unique SIM metadata.',
        request_failed: 'The phone request failed.',
        default: 'The phone request failed.',
      },
    },
    calculator: { name: 'Calculator' },
    snake: {
      name: 'Snake',
      backToMenu: 'Back to game menu',
      board: 'Snake game board',
      controls: 'Direction controls',
      directions: {
        down: 'Move down',
        left: 'Move left',
        right: 'Move right',
        up: 'Move up',
      },
      gameOver: 'Game Over',
      highScore: 'High Score',
      menu: 'Main Menu',
      pause: 'Pause game',
      paused: 'Paused',
      readyBody: 'Collect fruit, grow longer, and stay clear of every wall.',
      readyTitle: 'Ready to play?',
      restart: 'Play Again',
      resume: 'Resume game',
      score: 'Score',
      speed: 'Speed',
      speeds: { fast: 'Fast', normal: 'Normal', relaxed: 'Relaxed' },
      start: 'Start Game',
      swipeHint: 'Swipe, tap the controls, or use arrow keys / WASD',
    },
    memory: {
      name: 'Memory',
      backToMenu: 'Back to board selection',
      board: 'Memory card board',
      chooseBody: 'Find every matching pair with as few moves as possible.',
      chooseTitle: 'Choose a board',
      completeEyebrow: 'Board cleared',
      completeTitle: 'Great memory!',
      difficulties: { large: 'Expert', medium: 'Classic', small: 'Quick' },
      eyebrow: 'Matching game',
      hiddenCard: 'Hidden card',
      menu: 'Board Selection',
      moves: 'Moves',
      mute: 'Mute game sounds',
      noBest: 'No best score yet',
      playAgain: 'Play Again',
      restart: 'Restart',
      revealedCard: 'Revealed card',
      time: 'Time',
      unmute: 'Turn on game sounds',
    },
    numberMerge: {
      name: '2048',
      backToMenu: 'Back to game menu',
      best: 'Best',
      board: '2048 game board',
      cancel: 'Keep Current Game',
      confirmBody: 'Your current board will be replaced. This cannot be undone.',
      confirmNew: 'Start New Game',
      confirmTitle: 'Replace current game?',
      continueGame: 'Continue Game',
      controls: 'Move controls',
      directions: {
        down: 'Move tiles down',
        left: 'Move tiles left',
        right: 'Move tiles right',
        up: 'Move tiles up',
      },
      eyebrow: 'Number puzzle',
      gameOverBody: 'No empty spaces or matching neighbours remain.',
      gameOverTitle: 'No more moves',
      highest: 'Highest Tile',
      howToBody: 'Swipe to combine matching tiles. Each pair becomes one larger tile.',
      howToExample: '2 + 2 = 4  ·  4 + 4 = 8  ·  …  ·  1024 + 1024 = 2048',
      howToGoal: 'Goal: create the 2048 tile before the board has no moves left.',
      howToTitle: 'How to play',
      keepPlaying: 'Keep Playing',
      mainMenu: 'Main Menu',
      menuBody: 'Slide matching numbers together and work your way up to 2048.',
      menuTitle: 'Build the 2048 tile',
      mute: 'Mute game sounds',
      newGame: 'New Game',
      score: 'Score',
      swipeHint: 'Swipe the board, use the buttons, or press arrow keys / WASD',
      unmute: 'Turn on game sounds',
      wonBody: 'You reached the legendary tile. Continue climbing or begin again.',
      wonTitle: 'You made 2048!',
    },
    minesweeper: {
      name: 'Minesweeper',
      backToMenu: 'Back to game menu',
      board: 'Minesweeper board',
      chooseBody:
        'Reveal every safe field. Numbers show how many mines touch that field.',
      chooseTitle: 'Choose a minefield',
      difficulties: { classic: 'Classic', expert: 'Expert', quick: 'Quick' },
      emptyCell: 'Revealed empty field',
      eyebrow: 'Mine puzzle',
      flaggedCell: 'Flagged field',
      gameHint: 'Tap to reveal · Hold or right-click to flag',
      hiddenCell: 'Hidden field',
      longPressHint: 'Tap to reveal · Hold to place a flag',
      lostBody:
        'A mine was hidden there. Mark suspicious fields and try again.',
      lostTitle: 'Mine triggered',
      mainMenu: 'Main Menu',
      mineCell: 'Revealed mine',
      mines: 'Mines',
      mute: 'Mute game sounds',
      noBest: 'No best time yet',
      numberCell: 'Revealed field with {count} adjacent mines',
      playAgain: 'Play Again',
      restart: 'Restart',
      resume: 'Continue Game',
      time: 'Time',
      unmute: 'Turn on game sounds',
      wonBody: 'Minefield cleared in {time}.',
      wonTitle: 'Field cleared!',
    },
    map: {
      name: 'Map',
      controls: 'Map controls',
      currentLocation: 'Current Location',
      imageError: 'The map image could not be loaded.',
      switchStyle: 'Switch Map Type',
      styles: {
        default: 'Default Map',
        satellite: 'Satellite Map',
        atlas: 'Atlas Map',
        roads: 'Road Map',
      },
    },
    weather: {
      name: 'Weather',
      now: 'Now',
      today: 'Today',
      refresh: 'Refresh weather',
      details: 'Weather details',
      feelsLike: 'Feels Like',
      wind: 'Wind',
      humidity: 'Humidity',
      rain: 'Precipitation',
      hourly: '24-Hour Forecast',
      daily: '7-Day Forecast',
      unavailable: 'Weather is unavailable',
      stale: 'Showing the last available weather update.',
      tryAgain: 'Try Again',
      regions: {
        los_santos: 'Los Santos',
        blaine_county: 'Blaine County',
        cayo_perico: 'Cayo Perico',
      },
      conditions: {
        sunny: 'Sunny',
        clear: 'Clear',
        partly_cloudy: 'Partly Cloudy',
        cloudy: 'Cloudy',
        rain: 'Rain',
        thunder: 'Thunderstorms',
        fog: 'Foggy',
        snow: 'Snow',
      },
      summaries: {
        sunny: 'Bright skies throughout the current period.',
        clear: 'Calm and clear conditions across the region.',
        partly_cloudy: 'Sunshine mixed with passing clouds.',
        cloudy: 'Cloud cover will remain over the region.',
        rain: 'Wet conditions are moving through the area.',
        thunder: 'Stormy conditions with heavy bursts of rain.',
        fog: 'Reduced visibility in low-lying areas.',
        snow: 'Cold conditions with snow across the region.',
      },
    },
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
        world: 'Clock',
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
        sounds: {
          radar: 'Radar',
          beacon: 'Beacon',
          chimes: 'Chimes',
          apex: 'Apex',
          aurora: 'Aurora',
          circuit: 'Circuit',
          constellation: 'Constellation',
          daybreak: 'Daybreak',
          uplift: 'Uplift',
        },
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
    mail: {
      name: 'Mail',
      login: 'Sign In',
      register: 'Create Account',
      registerLink: 'Register',
      loginTitle: 'iFruit Mail',
      loginBody: 'Sign in to use your shared iFruit mailbox.',
      registerBody: 'Choose your new @ifruit.com address.',
      localPart: 'Email address',
      email: 'Email',
      password: 'Password',
      confirmPassword: 'Confirm password',
      passwordWarning:
        'Use an in-character password. Do not reuse a real-world password.',
      mailboxes: 'Mailboxes',
      inbox: 'Inbox',
      sent: 'Sent',
      drafts: 'Drafts',
      trash: 'Trash',
      compose: 'New Message',
      recipients: 'To',
      recipientHint: 'Separate up to 10 addresses with commas.',
      subject: 'Subject',
      body: 'Message',
      search: 'Search mail',
      noMail: 'No Mail',
      noMailBody: 'Messages in this mailbox will appear here.',
      noResults: 'No Results',
      noResultsBody: 'Try a different search.',
      untitled: '(no subject)',
      loadMore: 'Load More',
      logout: 'Sign Out',
      from: 'From',
      to: 'To',
      reply: 'Reply',
      replyAll: 'Reply All',
      forward: 'Forward',
      markUnread: 'Mark as Unread',
      moveToTrash: 'Move to Trash',
      restore: 'Restore',
      deleteForever: 'Delete Forever',
      emptyTrash: 'Empty Trash',
      emptyTrashTitle: 'Empty Trash?',
      emptyTrashBody: 'Every message in Trash will be permanently deleted.',
      deleteDraft: 'Delete Draft',
      sentSuccess: 'Message sent.',
      newMessage: 'New mail from {sender}',
      passwordsMismatch: 'Passwords do not match.',
      errors: {
        invalid_email: 'Choose a valid 3–32 character iFruit address.',
        invalid_password: 'Password must be 6–64 characters.',
        invalid_credentials: 'Email or password is incorrect.',
        email_taken: 'That iFruit address is already registered.',
        rate_limited: 'Too many attempts. Try again in a minute.',
        invalid_message: 'Add a valid recipient and a subject or message.',
        recipient_not_found: 'One or more recipients do not exist.',
        invalid_draft: 'This draft contains invalid content.',
        not_authenticated: 'Your mail session has ended. Sign in again.',
        request_failed: 'Mail is temporarily unavailable.',
        invalid_request: 'The mail request was invalid.',
        default: 'The mail request failed.',
      },
    },
    notes: {
      name: 'Notes',
      note: 'Note',
      back: 'Back',
      actions: 'Note actions',
      newNote: 'New Note',
      searchPlaceholder: 'Search Notes',
      title: 'Title',
      titlePlaceholder: 'Note title',
      body: 'Note',
      bodyPlaceholder: 'Start writing...',
      untitled: 'Untitled',
      noText: 'No additional text',
      emptyBadge: 'ON DEVICE',
      emptyTitle: 'No Notes',
      emptyBody: 'Create a note to keep important details close at hand.',
      noResults: 'No Results',
      noResultsBody: 'Try searching for a different word or phrase.',
      pin: 'Pin note',
      unpin: 'Unpin note',
      deleteNote: 'Delete note',
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
      accountDetail: 'Important Data & Cloud',
      accountLocalDetail: 'Not signed in',
      accountCloudDetail: 'Important data syncs through iFruit Cloud',
      accountLoginBody:
        'Sign in to keep your important data safe. Without an iFruit Account, it will be lost with the phone.',
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
      deviceInformation: 'Device Information',
      imei: 'IMEI',
      simCard: 'SIM Card',
      simNumber: 'Phone Number',
      simType: 'SIM Type',
      registeredSim: 'Registered',
      anonymousSim: 'Anonymous',
      noSim: 'No SIM',
      ejectSim: 'Eject SIM',
      ejectSimBody: 'Return this SIM card to your inventory?',
      linkedDevices: 'Linked Devices',
      thisDevice: 'This Phone',
      removeDevice: 'Remove Device',
      removeDeviceBody:
        'Enter your iFruit password to remove this device from the account.',
      signOut: 'Sign Out',
      factoryReset: 'Erase All Content and Settings',
      factoryResetBody:
        'This removes the account and all local data from this phone. Cloud data and the IMEI remain.',
      factoryResetProgress: 'Erasing iFruit Phone',
      factoryResetWarning: 'Do not turn off this phone. This takes 60 seconds.',
      accountErrors: {
        invalid_email: 'Choose a valid 3–32 character iFruit address.',
        invalid_password: 'Password must be 6–64 characters.',
        invalid_credentials: 'Email or password is incorrect.',
        email_taken: 'That iFruit address is already registered.',
        rate_limited: 'Too many attempts. Try again in a minute.',
        current_device: 'Sign out instead of removing the current phone.',
        device_not_found: 'That device is no longer linked.',
        default: 'The account request failed.',
      },
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
    back: 'Back',
    delete: 'Delete',
    done: 'Done',
    edit: 'Edit',
    home: 'Home',
    pause: 'Pause',
    phone: 'Phone',
    phoneStatus: 'Phone status',
    reset: 'Reset',
    loading: 'Loading',
    search: 'Search',
    save: 'Save',
    send: 'Send',
    start: 'Start',
    stop: 'Stop',
  },
  Notifications: { now: 'now' },
  LockScreen: {
    label: 'Lock Screen',
    flashlight: 'Flashlight',
    camera: 'Camera',
    swipeUp: 'Swipe up to open',
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
    device: null as PhoneDevice | null,
    deviceRevisions: {} as Record<string, number>,
    isOpen: false,
    lang: 'en',
    launchOrigin: null as AppLaunchOrigin | null,
    locales: defaultLocales,
    preferences: structuredClone(DEFAULT_PHONE_PREFERENCES),
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
      if (payload.device) this.hydrateDevice(payload.device)
      this.isOpen = true
    },
    hydrateDevice(device: PhoneDevice): void {
      this.device = device
      this.deviceRevisions = Object.fromEntries(
        Object.entries(device.data).map(([key, value]) => [
          key,
          value?.revision ?? 0,
        ]),
      )
      this.preferences = parsePhonePreferences(
        JSON.stringify(device.data.settings?.payload ?? null),
      )
    },
    saveDeviceNamespace(namespace: string, payload: unknown): void {
      const previous = namespaceQueues.get(namespace) ?? Promise.resolve()
      const queued = previous.then(async () => {
        const response = await nuiCall<{ revision: number }>('device:save', {
          namespace,
          payload,
          revision: this.deviceRevisions[namespace] ?? 0,
        })
        if (response.success && response.data) {
          this.deviceRevisions[namespace] = response.data.revision
        }
      })
      const tracked = queued.finally(() => {
        if (namespaceQueues.get(namespace) === tracked)
          namespaceQueues.delete(namespace)
      })
      namespaceQueues.set(namespace, tracked)
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
      this.saveDeviceNamespace('settings', this.preferences)
    },
    setPreference<K extends keyof PhonePreferencesV1['settings']>(
      key: K,
      value: PhonePreferencesV1['settings'][K],
    ): void {
      this.preferences.settings[key] = value
      this.saveDeviceNamespace('settings', this.preferences)
    },
    setSystemDarkMode(value: boolean): void {
      this.systemDarkMode = value
    },
    setWallpaper(wallpaper: WallpaperId): void {
      this.preferences.settings.wallpaper = wallpaper
      this.saveDeviceNamespace('settings', this.preferences)
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
