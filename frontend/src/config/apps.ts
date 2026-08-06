import {
  Calculator,
  Bomb,
  Blocks,
  Camera,
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
  NotebookPen,
  Phone,
  Settings,
  ShoppingBag,
  CloudSun,
  Wind,
  Tag,
  MapPinHouse,
} from 'lucide-vue-next'
import { defineAsyncComponent, markRaw } from 'vue'

import appStoreIcon from '@/assets/img/app-icons/apps.webp'
import calculatorIcon from '@/assets/img/app-icons/calculator.webp'
import cameraIcon from '@/assets/img/app-icons/camera.webp'
import clockIcon from '@/assets/img/app-icons/clock.webp'
import calendarIcon from '@/assets/img/app-icons/calendar.svg'
import mailIcon from '@/assets/img/app-icons/mail.webp'
import mapIcon from '@/assets/img/app-icons/map.webp'
import messagesIcon from '@/assets/img/app-icons/sms.webp'
import notesIcon from '@/assets/img/app-icons/notes.webp'
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
import citymarktIcon from '@/assets/img/app-icons/citymarkt.webp'
import localPagesIcon from '@/assets/img/app-icons/local-pages.webp'
import type {
  LaunchablePhoneAppDefinition,
  LaunchablePhoneAppId,
  PhoneAppDefinition,
} from '@/types/apps'

export const PHONE_APPS: PhoneAppDefinition[] = [
  {
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
]

export const PHONE_APP_IDS = PHONE_APPS.map((app) => app.id)

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

export function isLaunchablePhoneApp(
  app: PhoneAppDefinition,
): app is LaunchablePhoneAppDefinition {
  return app.component !== null && app.route !== null
}
