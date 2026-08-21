import {
  AudioLines,
  Calculator,
  Bomb,
  Blocks,
  Camera,
  CarFront,
  CarTaxiFront,
  CalendarDays,
  Clock3,
  Gamepad2,
  Grid2X2,
  Brain,
  Images,
  Layers3,
  Mail,
  MapPinned,
  MessageCircle,
  ShieldCheck,
  NotebookPen,
  Phone,
  RadioTower,
  Settings,
  ShoppingBag,
  CloudSun,
  Landmark,
  Wind,
  Tag,
  MapPinHouse,
  Flame,
  House,
  Music2,
  Feather,
  ReceiptText,
  UsersRound,
  Building2,
  Newspaper,
  Siren,
  HeartPulse,
  ChartCandlestick,
} from 'lucide-vue-next'
import { defineAsyncComponent, markRaw, shallowReactive } from 'vue'

import appStoreIcon from '@/assets/img/app-icons/apps.webp'
import calculatorIcon from '@/assets/img/app-icons/calculator.webp'
import cameraIcon from '@/assets/img/app-icons/camera.webp'
import clockIcon from '@/assets/img/app-icons/clock.webp'
import calendarIcon from '@/assets/img/app-icons/calendar.webp'
import mailIcon from '@/assets/img/app-icons/mail.webp'
import mapIcon from '@/assets/img/app-icons/map.webp'
import messagesIcon from '@/assets/img/app-icons/sms.webp'
import darkChatIcon from '@/assets/img/app-icons/darkchat.webp'
import notesIcon from '@/assets/img/app-icons/notes.webp'
import radioIcon from '@/assets/img/app-icons/radio.webp'
import memosIcon from '@/assets/img/app-icons/memos.webp'
import photosIcon from '@/assets/img/app-icons/gallery.webp'
import phoneIcon from '@/assets/img/app-icons/phone.webp'
import settingsIcon from '@/assets/img/app-icons/settings.webp'
import snakeIcon from '@/assets/img/app-icons/snake.webp'
import memoryIcon from '@/assets/img/app-icons/memory.webp'
import numberMergeIcon from '@/assets/img/app-icons/number-merge.webp'
import minesweeperIcon from '@/assets/img/app-icons/minesweeper.webp'
import towerStackIcon from '@/assets/img/app-icons/tower-stack.webp'
import skyFlappyIcon from '@/assets/img/app-icons/sky-flappy.webp'
import neonDropIcon from '@/assets/img/app-icons/neon-drop.webp'
import weatherIcon from '@/assets/img/app-icons/weather.webp'
import healthIcon from '@/assets/img/app-icons/health.webp'
import bankingIcon from '@/assets/img/app-icons/banking.webp'
import cryptoIcon from '@/assets/img/app-icons/crypto.webp'
import billingIcon from '@/assets/img/app-icons/billing.webp'
import garageIcon from '@/assets/img/app-icons/garage.webp'
import houseIcon from '@/assets/img/app-icons/house.webp'
import citymarktIcon from '@/assets/img/app-icons/citymarkt.webp'
import localPagesIcon from '@/assets/img/app-icons/local-pages.webp'
import flareIcon from '@/assets/img/app-icons/flare.webp'
import flipTokIcon from '@/assets/img/app-icons/fliptok.webp'
import picstagramIcon from '@/assets/img/app-icons/picstagram.webp'
import skyPicIcon from '@/assets/img/app-icons/skypic-v2.jpg'
import skyRideIcon from '@/assets/img/app-icons/skyride.webp'
import musicIcon from '@/assets/img/app-icons/music.webp'
import featherIcon from '@/assets/img/app-icons/feather.webp'
import crewLinkIcon from '@/assets/img/app-icons/crewlink.webp'
import companiesIcon from '@/assets/img/app-icons/companies.webp'
import weazelNewsIcon from '@/assets/img/app-icons/weazel-news.webp'
import cityWarnIcon from '@/assets/img/app-icons/citywarn.webp'
import type {
  BuiltinPhoneAppDefinition,
  BuiltinPhoneAppId,
  ExternalPhoneAppDefinition,
  ExternalPhoneAppId,
  LaunchablePhoneAppDefinition,
  LaunchablePhoneAppId,
  PhoneAppDefinition,
} from '@/types/apps'

export const PHONE_APPS = shallowReactive<PhoneAppDefinition[]>([
  {
    category: 'utilities',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/CityWarnApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 30,
    icon: markRaw(Siren),
    iconClass: 'app-icon--citywarn',
    iconImage: cityWarnIcon,
    id: 'citywarn',
    labelKey: 'Apps.citywarn.name',
    route: '/apps/citywarn',
  },
  {
    category: 'utilities',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/CryptoApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 7,
    icon: markRaw(ChartCandlestick),
    iconClass: 'app-icon--crypto',
    iconImage: cryptoIcon,
    id: 'crypto',
    labelKey: 'Apps.crypto.name',
    route: '/apps/crypto',
  },
  {
    category: 'utilities',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/HealthApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 11,
    icon: markRaw(HeartPulse),
    iconClass: 'app-icon--health',
    iconImage: healthIcon,
    id: 'health',
    labelKey: 'Apps.health.name',
    route: '/apps/health',
  },
  {
    category: 'social',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/WeazelNewsApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 29,
    icon: markRaw(Newspaper),
    iconClass: 'app-icon--weazel-news',
    iconImage: weazelNewsIcon,
    id: 'weazel-news',
    labelKey: 'Apps.weazelNews.name',
    route: '/apps/weazel-news',
  },
  {
    category: 'utilities',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/CompaniesApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 28,
    icon: markRaw(Building2),
    iconClass: 'app-icon--companies',
    iconImage: companiesIcon,
    id: 'companies',
    labelKey: 'Apps.companies.name',
    route: '/apps/companies',
  },
  {
    category: 'utilities',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/MusicApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 26,
    icon: markRaw(Music2),
    iconClass: 'app-icon--music',
    iconImage: musicIcon,
    id: 'music',
    labelKey: 'Apps.music.name',
    route: '/apps/music',
  },
  {
    category: 'social',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/PicstagramApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 23,
    icon: markRaw(Camera),
    iconClass: 'app-icon--picstagram',
    iconImage: picstagramIcon,
    id: 'picstagram',
    labelKey: 'Apps.picstagram.name',
    route: '/apps/picstagram',
  },
  {
    category: 'social',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/SkyPicApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 31,
    icon: markRaw(Camera),
    iconClass: 'app-icon--skypic',
    iconImage: skyPicIcon,
    id: 'skypic',
    labelKey: 'Apps.skypic.name',
    route: '/apps/skypic',
  },
  {
    category: 'social',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/FeatherApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 25,
    icon: markRaw(Feather),
    iconClass: 'app-icon--feather',
    iconImage: featherIcon,
    id: 'feather',
    labelKey: 'Apps.feather.name',
    route: '/apps/feather',
  },
  {
    category: 'social',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/FlipTokApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 22,
    icon: markRaw(Blocks),
    iconClass: 'app-icon--fliptok',
    iconImage: flipTokIcon,
    id: 'fliptok',
    labelKey: 'Apps.fliptok.name',
    route: '/apps/fliptok',
  },
  {
    category: 'social',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/FlareApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 24,
    icon: markRaw(Flame),
    iconClass: 'app-icon--flare',
    iconImage: flareIcon,
    id: 'flare',
    labelKey: 'Apps.flare.name',
    route: '/apps/flare',
  },
  {
    category: 'productivity',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/CalendarApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 21,
    icon: markRaw(CalendarDays),
    iconClass: 'app-icon--calendar',
    iconImage: calendarIcon,
    id: 'calendar',
    labelKey: 'Apps.calendar.name',
    route: '/apps/calendar',
  },
  {
    category: 'social',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/RadioApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 21,
    icon: markRaw(RadioTower),
    iconClass: 'app-icon--radio',
    iconImage: radioIcon,
    id: 'radio',
    labelKey: 'Apps.radio.name',
    route: '/apps/radio',
  },
  {
    category: 'social',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/LocalPagesApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 20,
    icon: markRaw(MapPinHouse),
    iconClass: 'app-icon--local-pages',
    iconImage: localPagesIcon,
    id: 'local-pages',
    labelKey: 'Apps.localPages.name',
    route: '/apps/local-pages',
  },
  {
    category: 'social',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/CrewLinkApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 27,
    icon: markRaw(UsersRound),
    iconClass: 'app-icon--crewlink',
    iconImage: crewLinkIcon,
    id: 'crewlink',
    labelKey: 'Apps.crewlink.name',
    route: '/apps/crewlink',
  },
  {
    category: 'social',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/PhoneApp.vue')),
    ),
    dockOrder: 0,
    gridOrder: 0,
    icon: markRaw(Phone),
    iconClass: '',
    iconImage: phoneIcon,
    id: 'phone',
    labelKey: 'Apps.phone.name',
    route: '/apps/phone',
  },
  {
    category: 'utilities',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/MessagesApp.vue')),
    ),
    dockOrder: 1,
    gridOrder: 1,
    icon: markRaw(MessageCircle),
    iconClass: '',
    iconImage: messagesIcon,
    id: 'messages',
    labelKey: 'Apps.messages.name',
    route: '/apps/messages',
  },
  {
    category: 'social',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/DarkChatApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 22,
    icon: markRaw(ShieldCheck),
    iconClass: 'app-icon--darkchat',
    iconImage: darkChatIcon,
    id: 'darkchat',
    labelKey: 'Apps.darkchat.name',
    route: '/apps/darkchat',
  },
  {
    category: 'utilities',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/GarageApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 23,
    icon: markRaw(CarFront),
    iconClass: 'app-icon--garage',
    iconImage: garageIcon,
    id: 'garage',
    labelKey: 'Apps.garage.name',
    route: '/apps/garage',
  },
  {
    category: 'utilities',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/HouseApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 25,
    icon: markRaw(House),
    iconClass: 'app-icon--house',
    iconImage: houseIcon,
    id: 'house',
    labelKey: 'Apps.house.name',
    route: '/apps/house',
  },
  {
    category: 'utilities',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/MapApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 11,
    icon: markRaw(MapPinned),
    iconClass: '',
    iconImage: mapIcon,
    id: 'map',
    labelKey: 'Apps.map.name',
    route: '/apps/map',
  },
  {
    category: 'utilities',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/SkyRideApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 25,
    icon: markRaw(CarTaxiFront),
    iconClass: 'app-icon--skyride',
    iconImage: skyRideIcon,
    id: 'skyride',
    labelKey: 'Apps.skyride.name',
    route: '/apps/skyride',
  },
  {
    category: 'social',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/BankingApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 5,
    icon: markRaw(Landmark),
    iconClass: 'app-icon--banking',
    iconImage: bankingIcon,
    id: 'banking',
    labelKey: 'Apps.banking.name',
    route: '/apps/banking',
  },
  {
    category: 'utilities',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/BillingApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 6,
    icon: markRaw(ReceiptText),
    iconClass: 'app-icon--billing',
    iconImage: billingIcon,
    id: 'billing',
    labelKey: 'Apps.billing.name',
    route: '/apps/billing',
  },
  {
    category: 'social',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/MailApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 6,
    icon: markRaw(Mail),
    iconClass: '',
    iconImage: mailIcon,
    id: 'mail',
    labelKey: 'Apps.mail.name',
    route: '/apps/mail',
  },
  {
    category: 'productivity',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/NotesApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 7,
    icon: markRaw(NotebookPen),
    iconClass: '',
    iconImage: notesIcon,
    id: 'notes',
    labelKey: 'Apps.notes.name',
    route: '/apps/notes',
  },
  {
    category: 'productivity',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/MemosApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 8,
    icon: markRaw(AudioLines),
    iconClass: '',
    iconImage: memosIcon,
    id: 'memos',
    labelKey: 'Apps.memos.name',
    route: '/apps/memos',
  },
  {
    category: 'productivity',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/CalculatorApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 2,
    icon: markRaw(Calculator),
    iconClass: 'app-icon--calculator',
    iconImage: calculatorIcon,
    id: 'calculator',
    labelKey: 'Apps.calculator.name',
    route: '/apps/calculator',
  },
  {
    category: 'utilities',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/CameraApp.vue')),
    ),
    dockOrder: 2,
    gridOrder: 3,
    icon: markRaw(Camera),
    iconClass: 'app-icon--camera',
    iconImage: cameraIcon,
    id: 'camera',
    labelKey: 'Apps.camera.name',
    route: '/apps/camera',
  },
  {
    category: 'productivity',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/ClockApp.vue')),
    ),
    dockOrder: 3,
    gridOrder: 4,
    icon: markRaw(Clock3),
    iconClass: 'app-icon--clock',
    iconImage: clockIcon,
    id: 'clock',
    labelKey: 'Apps.clock.name',
    route: '/apps/clock',
  },
  {
    category: 'utilities',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/WeatherApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 5,
    icon: markRaw(CloudSun),
    iconClass: 'app-icon--weather',
    iconImage: weatherIcon,
    id: 'weather',
    labelKey: 'Apps.weather.name',
    route: '/apps/weather',
  },
  {
    category: 'utilities',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/GalleryApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 8,
    icon: markRaw(Images),
    iconClass: 'app-icon--photos',
    iconImage: photosIcon,
    id: 'photos',
    labelKey: 'Apps.photos.name',
    route: '/apps/photos',
  },
  {
    category: 'utilities',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/AppStoreApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 9,
    icon: markRaw(ShoppingBag),
    iconClass: 'app-icon--store',
    iconImage: appStoreIcon,
    id: 'app-store',
    labelKey: 'Apps.appStore.name',
    route: '/apps/app-store',
  },
  {
    category: 'utilities',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/SettingsApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 10,
    icon: markRaw(Settings),
    iconClass: 'app-icon--settings',
    iconImage: settingsIcon,
    id: 'settings',
    labelKey: 'Apps.settings.name',
    route: '/apps/settings',
  },
  {
    category: 'games',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/SnakeApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 12,
    icon: markRaw(Gamepad2),
    iconClass: 'app-icon--snake',
    iconImage: snakeIcon,
    id: 'snake',
    labelKey: 'Apps.snake.name',
    route: '/apps/snake',
  },
  {
    category: 'games',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/MemoryApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 13,
    icon: markRaw(Brain),
    iconClass: 'app-icon--memory',
    iconImage: memoryIcon,
    id: 'memory',
    labelKey: 'Apps.memory.name',
    route: '/apps/memory',
  },
  {
    category: 'games',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/NumberMergeApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 14,
    icon: markRaw(Grid2X2),
    iconClass: 'app-icon--number-merge',
    iconImage: numberMergeIcon,
    id: 'number-merge',
    labelKey: 'Apps.numberMerge.name',
    route: '/apps/number-merge',
  },
  {
    category: 'games',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/MinesweeperApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 15,
    icon: markRaw(Bomb),
    iconClass: 'app-icon--minesweeper',
    iconImage: minesweeperIcon,
    id: 'minesweeper',
    labelKey: 'Apps.minesweeper.name',
    route: '/apps/minesweeper',
  },
  {
    category: 'games',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/TowerStackApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 16,
    icon: markRaw(Layers3),
    iconClass: 'app-icon--tower-stack',
    iconImage: towerStackIcon,
    id: 'tower-stack',
    labelKey: 'Apps.towerStack.name',
    route: '/apps/tower-stack',
  },
  {
    category: 'games',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/SkyFlappyApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 17,
    icon: markRaw(Wind),
    iconClass: 'app-icon--sky-flappy',
    iconImage: skyFlappyIcon,
    id: 'sky-flappy',
    labelKey: 'Apps.skyFlappy.name',
    route: '/apps/sky-flappy',
  },
  {
    category: 'shopping',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/CityMarktApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 19,
    icon: markRaw(Tag),
    iconClass: 'app-icon--citymarkt',
    iconImage: citymarktIcon,
    id: 'citymarkt',
    labelKey: 'Apps.citymarkt.name',
    route: '/apps/citymarkt',
  },
  {
    category: 'games',
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/NeonDropApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 18,
    icon: markRaw(Blocks),
    iconClass: 'app-icon--neon-drop',
    iconImage: neonDropIcon,
    id: 'neon-drop',
    labelKey: 'Apps.neonDrop.name',
    route: '/apps/neon-drop',
  },
])

const BUILTIN_PHONE_APPS = [...PHONE_APPS] as BuiltinPhoneAppDefinition[]

export const BUILTIN_PHONE_APP_IDS: ReadonlySet<BuiltinPhoneAppId> = new Set(
  BUILTIN_PHONE_APPS.map((app) => app.id),
)

export const DEFAULT_INSTALLED_PHONE_APP_IDS: ReadonlySet<BuiltinPhoneAppId> =
  new Set([
    'phone',
    'messages',
    'calculator',
    'camera',
    'clock',
    'weather',
    'mail',
    'notes',
    'memos',
    'photos',
    'app-store',
    'settings',
    'map',
    'calendar',
    'health',
    'citywarn',
  ])

export const NON_REMOVABLE_PHONE_APP_IDS: ReadonlySet<LaunchablePhoneAppId> =
  new Set([
    'app-store',
    'settings',
    'camera',
    'photos',
    'phone',
    'messages',
    'mail',
    'health',
    'citywarn',
  ])

export const PHONE_APP_IDS = PHONE_APPS.map((app) => app.id)

export function replaceExternalPhoneApps(
  apps: ExternalPhoneAppDefinition[],
): void {
  PHONE_APPS.splice(0, PHONE_APPS.length, ...BUILTIN_PHONE_APPS, ...apps)
}

export function getPhoneApp(
  id: string | string[] | undefined,
): PhoneAppDefinition | undefined {
  const appId = Array.isArray(id) ? id[0] : id
  return PHONE_APPS.find((app) => app.id === appId)
}

export function isPhoneAppId(value: string): value is LaunchablePhoneAppId {
  const app = getPhoneApp(value)
  return !!app && isLaunchablePhoneApp(app)
}

export function isExternalPhoneApp(
  app: PhoneAppDefinition | undefined,
): app is ExternalPhoneAppDefinition {
  return app?.kind === 'external'
}

export function isValidExternalPhoneAppId(
  value: string,
): value is ExternalPhoneAppId {
  return /^[a-z0-9][a-z0-9._-]{1,63}$/.test(value)
}

export function getPhoneAppLabel(
  app: PhoneAppDefinition,
  translate: (key: string) => string,
): string {
  return app.kind === 'external' ? app.name : translate(app.labelKey)
}

export function isPhoneAppRemovable(app: PhoneAppDefinition): boolean {
  return app.kind === 'external'
    ? app.removable && !app.defaultInstalled
    : !DEFAULT_INSTALLED_PHONE_APP_IDS.has(app.id) &&
        !NON_REMOVABLE_PHONE_APP_IDS.has(app.id)
}

export function isLaunchablePhoneApp(
  app: PhoneAppDefinition,
): app is LaunchablePhoneAppDefinition {
  return app.kind === 'external' || app.component !== null
}
