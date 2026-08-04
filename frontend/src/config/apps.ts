import {
  Calculator,
  Camera,
  Clock3,
  Images,
  Mail,
  NotebookPen,
  Settings,
  ShoppingBag,
} from 'lucide-vue-next'
import { defineAsyncComponent, markRaw } from 'vue'

import appStoreIcon from '@/assets/img/app-icons/apps.webp'
import calculatorIcon from '@/assets/img/app-icons/calculator.webp'
import cameraIcon from '@/assets/img/app-icons/camera.webp'
import clockIcon from '@/assets/img/app-icons/clock.webp'
import mailIcon from '@/assets/img/app-icons/mail.webp'
import notesIcon from '@/assets/img/app-icons/notes.webp'
import photosIcon from '@/assets/img/app-icons/gallery.webp'
import settingsIcon from '@/assets/img/app-icons/settings.webp'
import type { PhoneAppDefinition, PhoneAppId } from '@/types/apps'

export const PHONE_APPS: PhoneAppDefinition[] = [
  {
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/MailApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 3,
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
    gridOrder: 4,
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
    dockOrder: 1,
    gridOrder: 0,
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
    gridOrder: 1,
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
    gridOrder: 2,
    icon: markRaw(Clock3),
    iconClass: 'app-icon--clock',
    iconImage: clockIcon,
    id: 'clock',
    labelKey: 'Apps.clock.name',
    route: '/apps/clock',
  },
  {
    component: markRaw(
      defineAsyncComponent(() => import('@/views/apps/PhotosApp.vue')),
    ),
    dockOrder: null,
    gridOrder: 5,
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
    dockOrder: 0,
    gridOrder: 6,
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
    gridOrder: 7,
    icon: markRaw(Settings),
    iconClass: 'app-icon--settings',
    iconImage: settingsIcon,
    id: 'settings',
    labelKey: 'Apps.settings.name',
    route: '/apps/settings',
  },
]

export const PHONE_APP_IDS = PHONE_APPS.map((app) => app.id)

export function getPhoneApp(
  id: string | string[] | undefined,
): PhoneAppDefinition | undefined {
  const appId = Array.isArray(id) ? id[0] : id
  return PHONE_APPS.find((app) => app.id === appId)
}

export function isPhoneAppId(value: string): value is PhoneAppId {
  return PHONE_APP_IDS.includes(value as PhoneAppId)
}
