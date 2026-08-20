<script setup lang="ts">
import { kApp } from 'konsta/vue'
import {
  computed,
  onBeforeUnmount,
  onMounted,
  ref,
  type CSSProperties,
  watch,
} from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { SkyProvider } from '@/ui'
import PhoneHomeIndicator from '@/components/PhoneHomeIndicator.vue'
import PhoneControlCenter from '@/components/PhoneControlCenter.vue'
import PhoneDynamicIsland from '@/components/PhoneDynamicIsland.vue'
import PhoneMediaCapture from '@/components/PhoneMediaCapture.vue'
import PhoneMemoRecorder from '@/components/PhoneMemoRecorder.vue'
import PhoneLockScreen from '@/components/PhoneLockScreen.vue'
import PhonePasscode from '@/components/PhonePasscode.vue'
import PhoneSetupAssistant from '@/components/PhoneSetupAssistant.vue'
import PhoneNotifications from '@/components/PhoneNotifications.vue'
import NotificationPhonePreview from '@/components/NotificationPhonePreview.vue'
import PhoneStatusBar from '@/components/PhoneStatusBar.vue'
import EasyShareSheet from '@/components/EasyShareSheet.vue'
import PayphoneOverlay from '@/components/PayphoneOverlay.vue'
import RadioHud from '@/components/RadioHud.vue'
import SimPhonePicker, {
  type SimPhoneChoice,
} from '@/components/SimPhonePicker.vue'
import { PHONE_FRAME_IMAGES } from '@/config/appearance'
import { useClockStore } from '@/stores/clock'
import { useGamesStore } from '@/features/games/store'
import { useCallsStore } from '@/stores/calls'
import { useBankingStore } from '@/stores/banking'
import { useCryptoStore } from '@/stores/crypto'
import { useBillingStore } from '@/stores/billing'
import { useCompaniesStore } from '@/stores/companies'
import { useCityWarnStore } from '@/stores/citywarn'
import { useAccountStore } from '@/stores/account'
import { useAppAuthStore } from '@/stores/app-auth'
import { useMailStore } from '@/stores/mail'
import { useMessagesStore } from '@/stores/messages'
import { useDarkChatStore } from '@/stores/darkchat'
import { useFlareStore } from '@/stores/flare'
import { useFlipTokStore } from '@/stores/fliptok'
import { usePicstagramStore } from '@/stores/picstagram'
import { useFeatherStore } from '@/stores/feather'
import { useMediaStore } from '@/stores/media'
import { useMarketplaceStore } from '@/stores/marketplace'
import { useAppCatalogStore } from '@/stores/app-catalog'
import { useAppStoreStore } from '@/stores/app-store'
import { useWidgetsStore } from '@/stores/widgets'
import { isPhoneAppId, PHONE_APPS } from '@/config/apps'
import { useNotesStore } from '@/stores/notes'
import { useMemosStore } from '@/stores/memos'
import { useWeatherStore } from '@/stores/weather'
import { useEasyShareStore } from '@/stores/easyshare'
import { useRadioStore } from '@/stores/radio'
import {
  useNotificationsStore,
  type PhoneNotification,
  type PhoneNotificationInput,
} from '@/stores/notifications'
import { usePhoneStore, type PhoneOpenPayload } from '@/stores/phone'
import type { PhoneNotificationDevicePayload } from '@/types/device'
import type { MailCounts } from '@/types/mail'
import type { MarketplaceCounts } from '@/types/marketplace'
import type {
  CompanyChangedPayload,
  CompanyUnreadCounts,
} from '@/types/companies'
import type { PhoneCall } from '@/types/phone'
import type { DynamicIslandActivity } from '@/types/dynamicIsland'
import type { EasyShareEvent } from '@/types/easyshare'
import type { CryptoMarketChangedData } from '@/types/crypto'
import type { CityWarnEventData } from '@/types/citywarn'
import { nuiCall } from '@/utils/nui'
import {
  installPhoneAudioController,
  setPhoneOutputVolume,
} from '@/utils/phoneAudio'
import { formatTimer } from '@/utils/clock'
import { parsePhonePreferences } from '@/utils/preferences'
import { getHairlinePixelStyle } from '@/utils/rendering'
import { isTextInputElement } from '@/utils/textInputFocus'
import { isTrustedRootMessageSource } from '@/utils/windowMessages'
import SpringboardView from '@/views/SpringboardView.vue'

type AppMessage = {
  openHome?: boolean
  type?: string
  data?:
    | CalendarReminderData
    | MailEventData
    | MarketplaceEventData
    | CompaniesEventData
    | CityWarnEventData
    | MessagesEventData
    | DarkChatEventData
    | FlareEventData
    | FlipTokVerificationData
    | FlipTokNotificationData
    | PicstagramVerificationData
    | PicstagramNotificationData
    | FeatherNotificationData
    | BankingChangedData
    | CryptoMarketChangedData
    | BillingNotificationData
    | EasyShareEvent
    | PhoneCall
    | PhoneNotificationInput
    | PhoneOpenPayload
    | CustomAppCatalogEventData
    | CustomAppEventData
    | NavigationEventData
}

type CustomAppCatalogEventData = {
  apps?: unknown
}

type CustomAppEventData = {
  appId?: unknown
  data?: unknown
  payload?: unknown
}

type NavigationEventData = {
  appId?: unknown
}

type SimPickerPayload = {
  choices: SimPhoneChoice[]
  number: string
}

type NotificationEventData = Omit<PhoneNotificationInput, 'device'> & {
  device?: PhoneNotificationDevicePayload
}

type MailEventData = {
  counts?: MailCounts
  device?: PhoneNotificationDevicePayload
  sender?: string
  subject?: string
  text?: string
  title?: string
}

type MessagesEventData = {
  device?: PhoneNotificationDevicePayload
  phoneNumber?: string
  sender?: string
  text?: string
  title?: string
}

type CompaniesEventData = {
  area?: CompanyChangedPayload['area']
  companyId?: string
  counts?: CompanyUnreadCounts
  device?: PhoneNotificationDevicePayload
  kind?: 'assigned' | 'newMessage' | 'newRequest' | 'requestUpdated'
  requestId?: string
  subtitle?: string
  text?: string
  title?: string
}

type DarkChatEventData = {
  conversationId?: string
  device?: PhoneNotificationDevicePayload
  notificationMode?: 'full' | 'private' | 'hidden'
  preview?: string
  sender?: string
  text?: string
  title?: string
}

type FlareEventData = {
  body?: string
  device?: PhoneNotificationDevicePayload
  matchId?: string
  sender?: string
  text?: string
  title?: string
}

type MarketplaceEventData = {
  counts?: MarketplaceCounts
  device?: PhoneNotificationDevicePayload
  inquiryId?: string
  listingId?: string
  sender?: string
  text?: string
  title?: string
}

type CalendarReminderData = {
  device?: PhoneNotificationDevicePayload
  eventId?: string
  eventTitle?: string
  startsAt?: number
  text?: string
  title?: string
}

type FlipTokVerificationData = {
  profileId: number
  verified: boolean
}

type FlipTokNotificationData = {
  actor?: string
  device?: PhoneNotificationDevicePayload
  kind?: 'like' | 'comment' | 'follow' | 'verified'
  text?: string
  title?: string
  videoId?: string
}

type PicstagramVerificationData = {
  profileId: string
  verified: boolean
}

type PicstagramNotificationData = {
  actor?: string
  device?: PhoneNotificationDevicePayload
  kind?:
    | 'like'
    | 'comment'
    | 'comment_like'
    | 'reply'
    | 'follow'
    | 'follow_request'
    | 'request_accepted'
    | 'verified'
  postId?: string
  text?: string
  title?: string
}

type FeatherNotificationData = {
  actor?: string
  device?: PhoneNotificationDevicePayload
  kind?: 'like' | 'reply' | 'follow' | 'quote'
  postId?: string
  text?: string
  title?: string
}

type BillingNotificationData = {
  amount?: number
  device?: PhoneNotificationDevicePayload
  issuer?: string
  text?: string
  title?: string
}

type BankingChangedData = {
  amount?: number
  currency?: string
  kind?: 'transfer_in'
  sender?: string
}

type CrewLinkNotificationData = {
  actor?: string
  device?: PhoneNotificationDevicePayload
  groupName?: string
  kind?: 'invite' | 'member_joined' | 'ping' | 'role' | 'removed'
  pingLabel?: string
  text?: string
  title?: string
}
const REFERENCE_VIEWPORT_WIDTH = 1920
const REFERENCE_VIEWPORT_HEIGHT = 1080
const PHONE_BASE_SCALE = 0.69 * 1.2
const PHONE_PORTRAIT_WIDTH = 390
const PHONE_PORTRAIT_HEIGHT = 844
const MIN_PRODUCTION_PHONE_ZOOM = 260 / PHONE_PORTRAIT_WIDTH
const developmentParameters = new URLSearchParams(window.location.search)
const isBrowserPreview =
  developmentParameters.has('browserPreview') &&
  (import.meta.env.DEV ||
    developmentParameters.get('apiBase')?.startsWith('/') === true)
const isDevelopment =
  import.meta.env.DEV ||
  developmentParameters.get('apiBase')?.startsWith('/') === true
const developmentLockScreenPreview =
  isDevelopment && developmentParameters.has('lockScreenPreview')
let textInputFocused = false

const phone = usePhoneStore()
const account = useAccountStore()
const appAuth = useAppAuthStore()
const clock = useClockStore()
const games = useGamesStore()
const calls = useCallsStore()
const banking = useBankingStore()
const crypto = useCryptoStore()
const billing = useBillingStore()
const companies = useCompaniesStore()
const citywarn = useCityWarnStore()
const mail = useMailStore()
const messages = useMessagesStore()
const darkchat = useDarkChatStore()
const flare = useFlareStore()
const fliptok = useFlipTokStore()
const picstagram = usePicstagramStore()
const feather = useFeatherStore()
const media = useMediaStore()
const marketplace = useMarketplaceStore()
const appCatalog = useAppCatalogStore()
const appStore = useAppStoreStore()
const widgets = useWidgetsStore()
const notes = useNotesStore()
const memos = useMemosStore()
const weather = useWeatherStore()
const easyShare = useEasyShareStore()
const radio = useRadioStore()
const notifications = useNotificationsStore()
const route = useRoute()
const router = useRouter()
const isHomeRoute = computed(() => route.name === 'home')
const isAppRoute = computed(() => route.name === 'app')
const activeAppId = computed(() =>
  typeof route.params.appId === 'string' ? route.params.appId : '',
)
const WHITE_STATUS_BAR_APP_IDS = new Set([
  'calculator',
  'camera',
  'fliptok',
  'neon-drop',
  'sky-flappy',
  'snake',
  'tower-stack',
])
const DARK_STATUS_BAR_APP_IDS = new Set([
  'memory',
  'minesweeper',
  'number-merge',
])
const isDynamicIslandGalleryRoute = computed(
  () => isDevelopment && route.name === 'development-dynamic-islands',
)
const isDevelopmentRoute = computed(
  () =>
    isDevelopment &&
    (route.name === 'development-sky-ui' || isDynamicIslandGalleryRoute.value),
)
const appTransitionName = computed(() =>
  route.query.transition === 'app-switch' ? 'app-switch' : 'app-window',
)
const isLocked = ref(false)
const springboardEditing = ref(false)
const isUnlocking = ref(false)
const passcodeBusy = ref(false)
const passcodeError = ref('')
const passcodeResetKey = ref(0)
const passcodeRetrySeconds = ref(0)
const passcodeVisible = ref(false)
const passcodeRequired = ref(false)
const previousHardwareAlertVolume = ref(75)
const hardwareVolumeHudVisible = ref(false)
const setupPreviewDismissed = ref(false)
const setupDevelopmentSkipped = ref(false)
const setupAppearanceSelected = ref(false)
const pendingUnlockRoute = ref<string | null>(null)
const openHomeRequested = ref(false)
const unlockedServicesLoaded = ref(false)
const controlCenterOpened = ref(false)
const activitySuspended = ref(false)
const dynamicIslandExpanded = ref(false)
const dynamicIslandActivity = ref<DynamicIslandActivity | null>(null)
const simPicker = ref<SimPickerPayload | null>(null)
const setupRequired = computed(
  () =>
    !(isDevelopment && setupDevelopmentSkipped.value) &&
    (!phone.preferences.settings.setupCompleted ||
      (isDevelopment &&
        developmentParameters.has('setupPreview') &&
        !setupPreviewDismissed.value)),
)
const displayedDarkMode = computed(
  () =>
    phone.isDarkMode &&
    (!setupRequired.value ||
      setupAppearanceSelected.value ||
      phone.preferences.settings.setupStep > 4),
)
const hardwareAlertVolume = computed(() =>
  Math.round(
    (phone.preferences.settings.notificationVolume +
      phone.preferences.settings.ringtoneVolume) /
      2,
  ),
)
const hardwareVolumeHudStyle = computed<CSSProperties>(
  () =>
    ({
      '--phone-hardware-volume-fill': `${hardwareAlertVolume.value}%`,
    }) as CSSProperties,
)
const systemColorScheme = window.matchMedia('(prefers-color-scheme: dark)')
const viewportScale = ref(getViewportScale())
const browserDevicePixelRatio = ref(window.devicePixelRatio || 1)
const phoneBaseZoom = computed(() => viewportScale.value * PHONE_BASE_SCALE)
const phoneZoom = computed(() => {
  const preferred =
    phoneBaseZoom.value * (phone.preferences.settings.phoneScale / 100)
  if (isDevelopment) return preferred

  const edgeGap = 24 * viewportScale.value
  const shellWidth = phone.cameraLandscape
    ? PHONE_PORTRAIT_HEIGHT
    : PHONE_PORTRAIT_WIDTH
  const shellHeight = phone.cameraLandscape
    ? PHONE_PORTRAIT_WIDTH
    : PHONE_PORTRAIT_HEIGHT
  const viewportMaximum = Math.max(
    0,
    Math.min(
      (window.innerWidth - edgeGap) / shellWidth,
      (window.innerHeight - edgeGap) / shellHeight,
    ),
  )
  return Math.min(
    viewportMaximum,
    Math.max(MIN_PRODUCTION_PHONE_ZOOM, preferred),
  )
})
const phoneResolutionStyle = computed<CSSProperties>(() => ({
  ...getHairlinePixelStyle(phoneZoom.value, browserDevicePixelRatio.value),
  '--phone-edge-gap': `${24 * viewportScale.value}px`,
  '--phone-rendered-height': `${
    (phone.cameraLandscape ? PHONE_PORTRAIT_WIDTH : PHONE_PORTRAIT_HEIGHT) *
    phoneZoom.value
  }px`,
  '--phone-rendered-width': `${
    (phone.cameraLandscape ? PHONE_PORTRAIT_HEIGHT : PHONE_PORTRAIT_WIDTH) *
    phoneZoom.value
  }px`,
  '--phone-stack-gap': `${16 * viewportScale.value}px`,
  '--phone-zoom': phoneZoom.value,
}))
const phoneStageStyle = computed<CSSProperties>(() => ({
  ...phoneResolutionStyle.value,
  '--phone-live-activity-peek-height':
    dynamicIslandActivity.value === 'music'
      ? '190px'
      : dynamicIslandActivity.value === 'recording'
        ? '132px'
        : '112px',
  visibility: activitySuspended.value ? 'hidden' : 'visible',
}))
const phoneDisplayStyle = computed<CSSProperties>(() => ({
  '--phone-display-dim': String(
    ((100 - phone.preferences.settings.screenBrightness) / 100) * 0.8,
  ),
}))
const phoneFrameImage = computed(
  () => PHONE_FRAME_IMAGES[phone.preferences.settings.frame],
)
let clockTicker: ReturnType<typeof setInterval> | undefined
let companiesChangeTimer: number | undefined
let pendingCompaniesChange: CompanyChangedPayload | null = null
let unlockTimer: number | undefined
let passcodeLockTimer: number | undefined
let hardwareVolumeHudTimer: number | undefined
let unlockedServicesIdle: number | undefined
let removePhoneAudioController: (() => void) | undefined
let phoneClosePending = false
let simPickerClosePending = false

function getViewportScale(): number {
  const heightScale = window.innerHeight / REFERENCE_VIEWPORT_HEIGHT
  if (isBrowserPreview) {
    const availableScale = Math.min(
      window.innerWidth / PHONE_PORTRAIT_WIDTH,
      window.innerHeight / PHONE_PORTRAIT_HEIGHT,
    )

    return (availableScale * 0.94) / PHONE_BASE_SCALE
  }
  if (isDevelopment) return heightScale

  return Math.min(window.innerWidth / REFERENCE_VIEWPORT_WIDTH, heightScale)
}

function hydratePhone(payload: PhoneOpenPayload): void {
  if (payload.device?.imei) {
    companies.bindDeviceScope(
      payload.device.imei,
      payload.device.sim?.id ?? null,
    )
  }
  phone.open(payload)
  phone.ensureAppNotificationPreferences(
    appCatalog.externalApps.map((app) => app.id),
  )
  if (payload.device?.imei) {
    notifications.hydrate(
      payload.device.data.notifications?.payload,
      payload.device.imei,
    )
    notifications.hideDevicePreview(payload.device.imei)
  }
  account.hydrate(payload.account ?? null)
  appAuth.hydrate(
    payload.device?.data.appAuth?.payload,
    payload.account?.email ?? '',
  )
  notes.hydrate(payload.notes ?? [])
  memos.hydrate(payload.memos ?? [])
  clock.hydrate(payload.device?.data.alarms?.payload)
  games.hydrate(payload.device?.data.games?.payload)
  media.hydrate(payload.device?.data.media?.payload)
  appStore.hydrate(
    payload.device?.data.apps?.payload,
    phone.permissions.adminPanel,
  )
  widgets.hydrate(payload.device?.data.widgets?.payload)
}

function getInstalledNavigationAppIds(): string[] {
  const installedAppIds: string[] = []
  for (const app of PHONE_APPS) {
    if (isPhoneAppId(app.id) && appStore.isInstalled(app.id)) {
      installedAppIds.push(app.id)
    }
  }
  return installedAppIds
}

function syncNavigationState(): ReturnType<typeof nuiCall> {
  return nuiCall('navigation:state', {
    currentApp: activeAppId.value || null,
    installedApps: getInstalledNavigationAppIds(),
  })
}

function cancelUnlockedPhoneDataLoad(): void {
  if (unlockedServicesIdle === undefined) return
  if (typeof window.cancelIdleCallback === 'function') {
    window.cancelIdleCallback(unlockedServicesIdle)
  } else {
    window.clearTimeout(unlockedServicesIdle)
  }
  unlockedServicesIdle = undefined
}

function queueCompaniesChange(change: CompanyChangedPayload): void {
  if (!pendingCompaniesChange) {
    pendingCompaniesChange = { ...change }
  } else {
    pendingCompaniesChange = {
      area: pendingCompaniesChange.area === change.area ? change.area : 'all',
      companyId:
        pendingCompaniesChange.companyId === change.companyId
          ? change.companyId
          : undefined,
      requestId:
        pendingCompaniesChange.requestId === change.requestId
          ? change.requestId
          : undefined,
    }
  }
  if (companiesChangeTimer !== undefined) return
  companiesChangeTimer = window.setTimeout(() => {
    companiesChangeTimer = undefined
    const queuedChange = pendingCompaniesChange
    pendingCompaniesChange = null
    if (queuedChange) void companies.applyChanged(queuedChange)
  }, 2000)
}

async function bootstrapUnlockedPhoneData(): Promise<void> {
  const tasks: Array<() => Promise<unknown> | void> = [
    () => calls.bootstrap(),
    () => messages.loadConversations(),
    () => billing.loadOverview(),
    () => mail.bootstrap(account.email),
    () => {
      if (account.email) return marketplace.loadCounts()
      marketplace.setCounts({ active: 0, unread: 0 })
    },
    () => companies.refreshUnreadCounts(),
    () => (account.email ? darkchat.bootstrap() : undefined),
  ]

  for (const task of tasks) {
    if (!phone.isOpen || isLocked.value) {
      unlockedServicesLoaded.value = false
      return
    }
    try {
      await task()
    } catch (error) {
      console.error(
        '[sky_phone] Failed to bootstrap unlocked phone data.',
        error,
      )
    }
  }
}

function loadUnlockedPhoneData(): void {
  if (unlockedServicesLoaded.value) return
  unlockedServicesLoaded.value = true

  const startBootstrap = () => {
    unlockedServicesIdle = undefined
    if (!phone.isOpen || isLocked.value) {
      unlockedServicesLoaded.value = false
      return
    }
    void bootstrapUnlockedPhoneData()
  }

  if (typeof window.requestIdleCallback === 'function') {
    unlockedServicesIdle = window.requestIdleCallback(startBootstrap, {
      timeout: 1500,
    })
  } else {
    unlockedServicesIdle = window.setTimeout(startBootstrap, 0)
  }
}

function completePhoneSetup(): void {
  const requestedRoute = pendingUnlockRoute.value
  pendingUnlockRoute.value = null
  setupPreviewDismissed.value = true
  setupAppearanceSelected.value = false
  isLocked.value = false
  isUnlocking.value = false
  passcodeVisible.value = false
  passcodeRequired.value = false
  controlCenterOpened.value = false
  void router.replace(requestedRoute ?? '/')
  loadUnlockedPhoneData()
}

function skipPhoneSetupForDevelopment(): void {
  if (!isDevelopment) return
  setupDevelopmentSkipped.value = true
  completePhoneSetup()
}

async function hydrateDevelopmentPhone(): Promise<void> {
  const response = await nuiCall<PhoneOpenPayload>('development:bootstrap')
  if (response.success && response.data) {
    hydratePhone(response.data)
    return
  }

  hydratePhone({
    account: null,
    device: {
      data: {},
      imei: '356938035643809',
      name: 'iFruit Phone',
      sim: {
        id: 'development-sim',
        number: '5551234567',
        removable: true,
        registered: true,
        type: 'registered',
      },
    },
    memos: [],
    notes: [],
    token: 'development',
  })
}

function openDevelopmentPayphonePreview(): void {
  window.dispatchEvent(
    new MessageEvent('message', {
      data: {
        data: {
          currency: '$',
          locales: {
            busy: 'LINE BUSY',
            call: 'CALL',
            callEnded: 'CALL ENDED',
            clear: 'Clear number',
            close: 'Close payphone',
            connected: 'CONNECTED',
            cost: 'COST',
            declined: 'CALL DECLINED',
            delete: 'Delete digit',
            dialing: 'DIALING',
            disconnected: 'DISCONNECTED',
            elapsed: 'TIME',
            hangup: 'HANG UP',
            insufficientFunds: 'OUT OF MONEY',
            invalidNumber: 'ENTER A VALID NUMBER',
            keypad: 'Dial pad',
            noAnswer: 'NO ANSWER',
            numberLabel: 'NUMBER TO CALL',
            numberPlaceholder: 'Enter a phone number',
            rate: '{currency}{price} / SEC',
            ready: 'READY',
            requestFailed: 'CALL COULD NOT BE STARTED',
            ringing: 'RINGING',
            subtitle: 'PUBLIC TELEPHONE',
            title: 'PAYPHONE',
            unavailable: 'NUMBER UNAVAILABLE',
            voiceUnavailable: 'VOICE SERVICE UNAVAILABLE',
          },
          maxNumberLength: 10,
          pricePerSecond: 2,
        },
        type: 'payphone:open',
      },
    }),
  )
}

function onMessage(event: MessageEvent<AppMessage>): void {
  if (!isTrustedRootMessageSource(event.source, window)) return

  if (event.data?.type === 'custom-apps:catalog') {
    appCatalog.replaceCatalog(event.data.data)
    const catalogPayload = event.data.data as
      | { apps?: unknown; debug?: unknown }
      | undefined
    if (catalogPayload?.debug === true) {
      void nuiCall('custom-app:catalog-debug', {
        acceptedCount: appCatalog.externalApps.length,
        acceptedIds: appCatalog.externalApps.map((app) => app.id),
        receivedCount: Array.isArray(catalogPayload.apps)
          ? catalogPayload.apps.length
          : -1,
      })
    }
    const activeAppId = route.params.appId
    if (typeof activeAppId === 'string' && !isPhoneAppId(activeAppId)) {
      void router.push('/')
    }
  } else if (event.data?.type === 'custom-app:message') {
    const data = event.data.data as CustomAppEventData | undefined
    if (typeof data?.appId === 'string') {
      appCatalog.queueHostMessage(data.appId, data.payload)
    } else {
      console.error('[Custom apps] Ignored a message without a valid app id.')
    }
  } else if (event.data?.type === 'custom-app:open') {
    const data = event.data.data as CustomAppEventData | undefined
    if (
      typeof data?.appId === 'string' &&
      appCatalog.requestOpen(data.appId, data.data)
    ) {
      void router.push(`/apps/${data.appId}`)
    }
  } else if (event.data?.type === 'custom-app:close') {
    const data = event.data.data as CustomAppEventData | undefined
    if (typeof data?.appId === 'string' && route.params.appId === data.appId) {
      void router.push('/')
    }
  } else if (event.data?.type === 'navigation:open-app') {
    const data = event.data.data as NavigationEventData | undefined
    if (
      typeof data?.appId === 'string' &&
      isPhoneAppId(data.appId) &&
      appStore.isInstalled(data.appId)
    ) {
      const requestedRoute = `/apps/${data.appId}`
      if (setupRequired.value || isLocked.value) {
        pendingUnlockRoute.value = requestedRoute
      } else {
        void router.push(requestedRoute)
      }
    } else {
      console.error('[Navigation] Ignored an unavailable app target.')
    }
  } else if (event.data?.type === 'navigation:close-app') {
    const data = event.data.data as NavigationEventData | undefined
    const currentApp = route.params.appId
    if (data?.appId === undefined || currentApp === data.appId) {
      void router.push('/')
    }
  } else if (event.data?.type === 'compat:open-messages') {
    const data = event.data.data as MessagesEventData | undefined
    if (typeof data?.phoneNumber === 'string') {
      void messages.openThread(data.phoneNumber).then((opened) => {
        if (opened) void router.push('/apps/messages')
      })
    }
  } else if (event.data?.type === 'app:open') {
    openHomeRequested.value = event.data.openHome === true
    hydratePhone(event.data.data as PhoneOpenPayload)
    void syncNavigationState().then(() => nuiCall('ui:opened'))
  } else if (event.data?.type === 'device:updated') {
    hydratePhone(event.data.data as PhoneOpenPayload)
  } else if (event.data?.type === 'app:close') {
    activitySuspended.value = false
    phone.endDeviceSession()
  } else if (event.data?.type === 'app:suspend') {
    activitySuspended.value = true
  } else if (event.data?.type === 'app:resume') {
    activitySuspended.value = false
  } else if (event.data?.type === 'notification:show' && event.data.data) {
    const data = event.data.data as NotificationEventData
    const { device, ...input } = data
    const notification: PhoneNotificationInput = input
    if (device && (!phone.isOpen || device.imei !== phone.device?.imei)) {
      notification.device = {
        imei: device.imei,
        name: device.name,
        preferences: parsePhonePreferences(device.settings ?? null),
      }
    }
    notifications.show(notification)
  } else if (event.data?.type === 'mail:changed' && event.data.data) {
    const data = event.data.data as MailEventData
    if (data.counts) mail.setCounts(data.counts)
  } else if (event.data?.type === 'mail:new' && event.data.data) {
    const data = event.data.data as MailEventData
    if (
      data.counts &&
      (!data.device || data.device.imei === phone.device?.imei)
    ) {
      mail.setCounts(data.counts)
    }

    const notification: PhoneNotificationInput = {
      appId: 'mail',
      subtitle: data.subject,
      text:
        data.text ??
        phone.t('Apps.mail.newMessage', { sender: data.sender ?? '' }),
      title: data.title ?? phone.t('Apps.mail.name'),
    }
    if (
      data.device &&
      (!phone.isOpen || data.device.imei !== phone.device?.imei)
    ) {
      notification.device = {
        imei: data.device.imei,
        name: data.device.name,
        preferences: parsePhonePreferences(data.device.settings ?? null),
      }
    }
    notifications.show(notification)
  } else if (event.data?.type === 'marketplace:changed' && event.data.data) {
    const data = event.data.data as MarketplaceEventData
    if (data.counts) marketplace.setCounts(data.counts)
  } else if (event.data?.type === 'companies:changed') {
    const data = event.data.data as CompaniesEventData | undefined
    if (data?.counts) companies.applyUnreadCounts(data.counts)
    if (data?.area) {
      queueCompaniesChange({
        area: data.area,
        companyId: data.companyId,
        requestId: data.requestId,
      })
    } else if (!data?.counts) queueCompaniesChange({ area: 'all' })
  } else if (event.data?.type === 'companies:notification' && event.data.data) {
    const data = event.data.data as CompaniesEventData
    if (data.counts) companies.applyUnreadCounts(data.counts)

    const notification: PhoneNotificationInput = {
      appId: 'companies',
      ...(data.requestId && data.area
        ? {
            route: `/apps/companies?requestId=${encodeURIComponent(data.requestId)}&area=${encodeURIComponent(data.area)}`,
          }
        : {}),
      persistent: !phone.isOpen && Boolean(data.requestId && data.area),
      subtitle: data.subtitle,
      text:
        data.text ??
        phone.t(
          `Apps.companies.notifications.${data.kind ?? 'requestUpdated'}`,
        ),
      title: data.title ?? phone.t('Apps.companies.name'),
    }
    if (
      data.device &&
      (!phone.isOpen || data.device.imei !== phone.device?.imei)
    ) {
      notification.device = {
        imei: data.device.imei,
        name: data.device.name,
        preferences: parsePhonePreferences(data.device.settings ?? null),
      }
    }
    notifications.show(notification)
  } else if (event.data?.type === 'citywarn:changed' && event.data.data) {
    const data = event.data.data as CityWarnEventData
    if (data.alert) citywarn.applyEvent(data)
    if (phone.isOpen && citywarn.initialized) void citywarn.refresh()

    const alert = data.alert
    if (alert && citywarn.accepts(alert)) {
      notifications.show({
        appId: 'citywarn',
        critical: alert.severity === 'danger' || alert.severity === 'extreme',
        persistent: alert.severity === 'extreme',
        route: `/apps/citywarn?alertId=${encodeURIComponent(alert.id)}`,
        subtitle: data.sourceLabel ?? alert.sourceLabel,
        text:
          data.text ??
          phone.t(`Apps.citywarn.notifications.${data.kind ?? 'update'}`),
        title: data.title ?? phone.t('Apps.citywarn.name'),
      })
    }
  } else if (
    event.data?.type === 'fliptok:verification-changed' &&
    event.data.data
  ) {
    const data = event.data.data as FlipTokVerificationData
    fliptok.applyVerification(Number(data.profileId), data.verified === true)
  } else if (event.data?.type === 'fliptok:new' && event.data.data) {
    const data = event.data.data as FlipTokNotificationData
    const notification: PhoneNotificationInput = {
      appId: 'fliptok',
      subtitle: data.actor,
      text: data.text ?? phone.t('Apps.fliptok.notifications.default'),
      title: data.title ?? phone.t('Apps.fliptok.name'),
    }
    if (
      data.device &&
      (!phone.isOpen || data.device.imei !== phone.device?.imei)
    ) {
      notification.device = {
        imei: data.device.imei,
        name: data.device.name,
        preferences: parsePhonePreferences(data.device.settings ?? null),
      }
    }
    notifications.show(notification)
    if (phone.isOpen) void fliptok.loadActivities()
  } else if (event.data?.type === 'feather:new' && event.data.data) {
    const data = event.data.data as FeatherNotificationData
    const notification: PhoneNotificationInput = {
      appId: 'feather',
      subtitle: data.actor,
      text: data.text ?? phone.t('Apps.feather.notifications.default'),
      title: data.title ?? phone.t('Apps.feather.name'),
    }
    if (
      data.device &&
      (!phone.isOpen || data.device.imei !== phone.device?.imei)
    ) {
      notification.device = {
        imei: data.device.imei,
        name: data.device.name,
        preferences: parsePhonePreferences(data.device.settings ?? null),
      }
    }
    notifications.show(notification)
    if (phone.isOpen) void feather.loadActivities()
  } else if (
    event.data?.type === 'picstagram:verification-changed' &&
    event.data.data
  ) {
    const data = event.data.data as PicstagramVerificationData
    picstagram.applyVerification(String(data.profileId), data.verified === true)
  } else if (event.data?.type === 'picstagram:new' && event.data.data) {
    const data = event.data.data as PicstagramNotificationData
    const notification: PhoneNotificationInput = {
      appId: 'picstagram',
      subtitle: data.actor,
      text: data.text ?? phone.t('Apps.picstagram.notifications.default'),
      title: data.title ?? phone.t('Apps.picstagram.name'),
    }
    if (
      data.device &&
      (!phone.isOpen || data.device.imei !== phone.device?.imei)
    ) {
      notification.device = {
        imei: data.device.imei,
        name: data.device.name,
        preferences: parsePhonePreferences(data.device.settings ?? null),
      }
    }
    notifications.show(notification)
    if (phone.isOpen) void picstagram.loadActivities()
  } else if (
    event.data?.type === 'marketplace:new-message' &&
    event.data.data
  ) {
    const data = event.data.data as MarketplaceEventData
    const notification: PhoneNotificationInput = {
      appId: 'citymarkt',
      subtitle: data.sender,
      text:
        data.text ??
        phone.t('Apps.citymarkt.newMessage', { sender: data.sender ?? '' }),
      title: data.title ?? phone.t('Apps.citymarkt.name'),
    }
    if (
      data.device &&
      (!phone.isOpen || data.device.imei !== phone.device?.imei)
    ) {
      notification.device = {
        imei: data.device.imei,
        name: data.device.name,
        preferences: parsePhonePreferences(data.device.settings ?? null),
      }
    }
    notifications.show(notification)
    void marketplace.loadCounts()
  } else if (event.data?.type === 'calendar:reminder' && event.data.data) {
    const data = event.data.data as CalendarReminderData
    const startsAt = Number(data.startsAt) || Date.now()
    const notification: PhoneNotificationInput = {
      appId: 'calendar',
      subtitle: new Intl.DateTimeFormat(phone.lang, {
        hour: '2-digit',
        hourCycle: 'h23',
        minute: '2-digit',
      }).format(startsAt),
      text:
        data.text ??
        phone.t('Apps.calendar.reminderNotification', {
          title: data.eventTitle ?? '',
        }),
      title: data.title ?? phone.t('Apps.calendar.name'),
    }
    if (
      data.device &&
      (!phone.isOpen || data.device.imei !== phone.device?.imei)
    ) {
      notification.device = {
        imei: data.device.imei,
        name: data.device.name,
        preferences: parsePhonePreferences(data.device.settings ?? null),
      }
    }
    notifications.show(notification)
  } else if (event.data?.type === 'contacts:changed') {
    void calls.loadContacts()
  } else if (event.data?.type === 'easyshare:changed' && event.data.data) {
    easyShare.applyEvent(event.data.data as EasyShareEvent)
  } else if (event.data?.type === 'messages:changed') {
    void messages.loadConversations()
    if (messages.activeNumber) void messages.openThread(messages.activeNumber)
  } else if (event.data?.type === 'messages:new' && event.data.data) {
    const data = event.data.data as MessagesEventData
    void messages.loadConversations()
    if (messages.activeNumber === data.phoneNumber) {
      void messages.openThread(messages.activeNumber)
    }

    const notification: PhoneNotificationInput = {
      appId: 'messages',
      subtitle: data.phoneNumber,
      text:
        data.text ??
        phone.t('Apps.messages.newMessage', { sender: data.sender ?? '' }),
      title: data.title ?? phone.t('Apps.messages.name'),
    }
    if (
      data.device &&
      (!phone.isOpen || data.device.imei !== phone.device?.imei)
    ) {
      notification.device = {
        imei: data.device.imei,
        name: data.device.name,
        preferences: parsePhonePreferences(data.device.settings ?? null),
      }
    }
    notifications.show(notification)
  } else if (event.data?.type === 'darkchat:changed') {
    void darkchat.refreshInbox()
    if (darkchat.activeConversation) {
      void darkchat.openThread(darkchat.activeConversation.id)
    }
  } else if (event.data?.type === 'darkchat:new' && event.data.data) {
    const data = event.data.data as DarkChatEventData
    void darkchat.refreshInbox()
    if (
      data.conversationId &&
      darkchat.activeConversation?.id === data.conversationId
    ) {
      void darkchat.openThread(data.conversationId)
    }
    if (data.notificationMode !== 'hidden') {
      const notification: PhoneNotificationInput = {
        appId: 'darkchat',
        subtitle: data.sender,
        text:
          data.text ??
          data.preview ??
          phone.t('Apps.darkchat.privateNotification'),
        title: data.title ?? phone.t('Apps.darkchat.name'),
      }
      if (
        data.device &&
        (!phone.isOpen || data.device.imei !== phone.device?.imei)
      ) {
        notification.device = {
          imei: data.device.imei,
          name: data.device.name,
          preferences: parsePhonePreferences(data.device.settings ?? null),
        }
      }
      notifications.show(notification)
    }
  } else if (
    (event.data?.type === 'flare:new-match' ||
      event.data?.type === 'flare:new-message') &&
    event.data.data
  ) {
    const data = event.data.data as FlareEventData
    void flare.bootstrap()
    if (
      data.matchId &&
      event.data.type === 'flare:new-message' &&
      flare.activeMatchId === data.matchId
    ) {
      void flare.loadThread(data.matchId)
    }
    const notification: PhoneNotificationInput = {
      appId: 'flare',
      subtitle: data.sender,
      text:
        data.text ??
        phone.t(
          event.data.type === 'flare:new-match'
            ? 'Apps.flare.newMatchNotification'
            : 'Apps.flare.newMessageNotification',
          { sender: data.sender ?? '' },
        ),
      title: data.title ?? phone.t('Apps.flare.name'),
    }
    if (
      data.device &&
      (!phone.isOpen || data.device.imei !== phone.device?.imei)
    ) {
      notification.device = {
        imei: data.device.imei,
        name: data.device.name,
        preferences: parsePhonePreferences(data.device.settings ?? null),
      }
    }
    notifications.show(notification)
  } else if (event.data?.type === 'calls:changed') {
    void calls.loadRecents()
  } else if (event.data?.type === 'banking:changed') {
    const data = event.data.data as BankingChangedData | undefined
    void banking.load(false, true)
    if (
      data?.kind === 'transfer_in' &&
      typeof data.amount === 'number' &&
      data.amount > 0
    ) {
      const formattedAmount = `${
        data.currency ?? banking.overview?.currency ?? '$'
      }${new Intl.NumberFormat(phone.lang, {
        maximumFractionDigits: 0,
        minimumFractionDigits: 0,
      }).format(data.amount)}`
      notifications.show({
        appId: 'banking',
        route: '/apps/banking',
        subtitle: data.sender,
        text: phone.t('Apps.banking.notifications.received', {
          amount: formattedAmount,
          sender: data.sender ?? '',
        }),
        title: phone.t('Apps.banking.notifications.receivedTitle'),
      })
    }
  } else if (event.data?.type === 'crypto:changed' && event.data.data) {
    const data = event.data.data as CryptoMarketChangedData
    crypto.applyMarketUpdate(data.markets)
  } else if (event.data?.type === 'crypto:account-changed') {
    if (crypto.data?.authenticated) void crypto.load()
  } else if (event.data?.type === 'billing:changed') {
    void billing.loadOverview()
  } else if (event.data?.type === 'billing:new' && event.data.data) {
    const data = event.data.data as BillingNotificationData
    void billing.loadOverview()
    const notification: PhoneNotificationInput = {
      appId: 'billing',
      subtitle: data.issuer,
      text:
        data.text ??
        phone.t('Apps.billing.notifications.newInvoice', {
          amount: String(data.amount ?? 0),
          issuer: data.issuer ?? '',
        }),
      title: data.title ?? phone.t('Apps.billing.name'),
    }
    if (
      data.device &&
      (!phone.isOpen || data.device.imei !== phone.device?.imei)
    ) {
      notification.device = {
        imei: data.device.imei,
        name: data.device.name,
        preferences: parsePhonePreferences(data.device.settings ?? null),
      }
    }
    notifications.show(notification)
  } else if (event.data?.type === 'crewlink:notification' && event.data.data) {
    const data = event.data.data as CrewLinkNotificationData
    const notification: PhoneNotificationInput = {
      appId: 'crewlink',
      subtitle: data.groupName,
      text: data.text ?? phone.t('Apps.crewlink.notifications.default'),
      title: data.title ?? phone.t('Apps.crewlink.name'),
    }
    if (
      data.device &&
      (!phone.isOpen || data.device.imei !== phone.device?.imei)
    ) {
      notification.device = {
        imei: data.device.imei,
        name: data.device.name,
        preferences: parsePhonePreferences(data.device.settings ?? null),
      }
    }
    notifications.show(notification)
  } else if (
    (event.data?.type === 'call:incoming' ||
      event.data?.type === 'call:state') &&
    event.data.data
  ) {
    calls.applyCallState(event.data.data as PhoneCall)
    controlCenterOpened.value = false
    if (!phone.security.enabled) {
      isLocked.value = false
      isUnlocking.value = false
      loadUnlockedPhoneData()
    }
  } else if (event.data?.type === 'sim:picker' && event.data.data) {
    simPicker.value = event.data.data as unknown as SimPickerPayload
  } else if (event.data?.type === 'sim:picker-close') {
    simPicker.value = null
  }
}

async function closeSimPicker(): Promise<void> {
  if (simPickerClosePending || !simPicker.value) return
  simPickerClosePending = true
  const closingPicker = simPicker.value
  try {
    const response = await nuiCall('sim:picker-close')
    if (response.success && simPicker.value === closingPicker) {
      simPicker.value = null
    }
  } finally {
    simPickerClosePending = false
  }
}

async function closePhone(): Promise<void> {
  if (phoneClosePending || !phone.isOpen) return
  phoneClosePending = true
  const closingGeneration = phone.persistenceGeneration
  const closingImei = phone.device?.imei ?? null
  const closingToken = phone.deviceSessionToken
  try {
    await phone.flushDevicePersistence()
    if (
      !phone.isOpen ||
      phone.persistenceGeneration !== closingGeneration ||
      (phone.device?.imei ?? null) !== closingImei ||
      phone.deviceSessionToken !== closingToken
    ) {
      return
    }
    const response = await nuiCall('close')
    if (
      !response.success ||
      !phone.isOpen ||
      phone.persistenceGeneration !== closingGeneration ||
      (phone.device?.imei ?? null) !== closingImei ||
      phone.deviceSessionToken !== closingToken
    ) {
      return
    }
    phone.endDeviceSession()
  } finally {
    phoneClosePending = false
  }
}

function onKeydown(event: KeyboardEvent): void {
  if (event.key !== 'Escape') return
  if (simPicker.value) {
    event.preventDefault()
    void closeSimPicker()
    return
  }

  queueMicrotask(() => {
    if (event.defaultPrevented || !phone.isOpen || activitySuspended.value)
      return
    if (controlCenterOpened.value) {
      controlCenterOpened.value = false
      return
    }
    void closePhone()
  })
}

function onSystemColorSchemeChange(event: MediaQueryListEvent): void {
  phone.setSystemDarkMode(event.matches)
}

function updateViewportScale(): void {
  viewportScale.value = getViewportScale()
  browserDevicePixelRatio.value = window.devicePixelRatio || 1
}

function completeUnlock(): void {
  if (!isUnlocking.value) return
  if (unlockTimer !== undefined) {
    window.clearTimeout(unlockTimer)
    unlockTimer = undefined
  }
  isUnlocking.value = false
  loadUnlockedPhoneData()
}

function finishUnlock(): void {
  if (!isLocked.value) return
  isUnlocking.value = true
  isLocked.value = false
  passcodeVisible.value = false
  passcodeRequired.value = false
  passcodeError.value = ''

  unlockTimer = window.setTimeout(() => {
    unlockTimer = undefined
    completeUnlock()
  }, 720)

  if (pendingUnlockRoute.value) {
    const routePath = pendingUnlockRoute.value
    pendingUnlockRoute.value = null
    window.setTimeout(() => void router.push(routePath), 0)
  }
}

function unlockPhone(): void {
  if (!isLocked.value) return
  if (phone.security.enabled && passcodeRequired.value) {
    passcodeError.value = ''
    passcodeVisible.value = true
    return
  }
  finishUnlock()
}

function openLockScreenNotification(notification: PhoneNotification): void {
  if (!notification.route) return
  pendingUnlockRoute.value = notification.route
  notifications.dismissFromLockScreen(notification.id)
  unlockPhone()
}

async function openNotificationPreview(
  notification: PhoneNotification,
): Promise<void> {
  if (!notification.route) return
  const imei = notification.device?.imei ?? phone.device?.imei
  if (!imei) return
  pendingUnlockRoute.value = notification.route
  const response = await nuiCall('device:notification-open', { imei })
  if (!response.success) {
    pendingUnlockRoute.value = null
    return
  }
  notifications.dismissFromLockScreen(notification.id, imei)
}

function cancelPasscode(): void {
  if (passcodeBusy.value) return
  passcodeVisible.value = false
  passcodeError.value = ''
  pendingUnlockRoute.value = null
}

function startPasscodeLock(seconds: number): void {
  if (passcodeLockTimer !== undefined) window.clearInterval(passcodeLockTimer)
  passcodeRetrySeconds.value = Math.max(1, Math.ceil(seconds))
  passcodeLockTimer = window.setInterval(() => {
    passcodeRetrySeconds.value = Math.max(0, passcodeRetrySeconds.value - 1)
    if (passcodeRetrySeconds.value === 0 && passcodeLockTimer !== undefined) {
      window.clearInterval(passcodeLockTimer)
      passcodeLockTimer = undefined
      passcodeError.value = ''
    }
  }, 1000)
}

async function submitUnlockPasscode(passcode: string): Promise<void> {
  if (passcodeBusy.value || passcodeRetrySeconds.value > 0) return
  passcodeBusy.value = true
  const response = await phone.unlockWithPasscode(passcode)
  passcodeBusy.value = false
  if (response.success) {
    finishUnlock()
    return
  }

  passcodeResetKey.value += 1
  if (response.error === 'passcode_locked') {
    startPasscodeLock(response.data?.retryAfter ?? 30)
    passcodeError.value = phone.t('LockScreen.passcode.locked', {
      seconds: String(response.data?.retryAfter ?? 30),
    })
    return
  }
  if (response.error === 'rate_limited') {
    passcodeError.value = phone.t('LockScreen.passcode.rateLimited')
    return
  }
  passcodeError.value = phone.t('LockScreen.passcode.incorrect')
}

function toggleControlCenter(): void {
  if (isLocked.value) return
  controlCenterOpened.value = !controlCenterOpened.value
}

function lockPhone(): void {
  if (!phone.isOpen || isLocked.value) return
  controlCenterOpened.value = false
  isUnlocking.value = false
  passcodeVisible.value = false
  passcodeBusy.value = false
  passcodeError.value = ''
  passcodeRequired.value = phone.security.enabled
  pendingUnlockRoute.value = null
  isLocked.value = true
}

function showHardwareVolumeHud(): void {
  hardwareVolumeHudVisible.value = true
  if (hardwareVolumeHudTimer !== undefined) {
    window.clearTimeout(hardwareVolumeHudTimer)
  }
  hardwareVolumeHudTimer = window.setTimeout(() => {
    hardwareVolumeHudVisible.value = false
    hardwareVolumeHudTimer = undefined
  }, 1300)
}

function toggleHardwareLock(): void {
  if (setupRequired.value) return
  if (isLocked.value) {
    unlockPhone()
    return
  }
  lockPhone()
}

function changeHardwareAlertVolume(delta: number): void {
  if (setupRequired.value) return
  const volume = Math.min(100, Math.max(0, hardwareAlertVolume.value + delta))
  if (volume > 0) previousHardwareAlertVolume.value = volume
  phone.setAlertVolumes(volume)
  showHardwareVolumeHud()
}

function toggleHardwareAlertMute(): void {
  if (setupRequired.value) return
  if (hardwareAlertVolume.value > 0) {
    previousHardwareAlertVolume.value = hardwareAlertVolume.value
    phone.setAlertVolumes(0)
    showHardwareVolumeHud()
    return
  }
  phone.setAlertVolumes(previousHardwareAlertVolume.value)
  showHardwareVolumeHud()
}

function unlockCamera(): void {
  if (phone.security.enabled) {
    pendingUnlockRoute.value = '/apps/camera'
    unlockPhone()
    return
  }
  unlockPhone()
  window.setTimeout(() => void router.push('/apps/camera'), 0)
}

function updateTextInputFocus(active: boolean): void {
  if (textInputFocused === active) return
  textInputFocused = active
  void nuiCall('ui:input-focus', { active })
}

function onFocusIn(event: FocusEvent): void {
  const target = event.target
  updateTextInputFocus(
    target instanceof HTMLElement && isTextInputElement(target),
  )
}

function onFocusOut(event: FocusEvent): void {
  const nextTarget = event.relatedTarget
  updateTextInputFocus(
    nextTarget instanceof HTMLElement && isTextInputElement(nextTarget),
  )
}

onMounted(() => {
  removePhoneAudioController = installPhoneAudioController()
  document.addEventListener('focusin', onFocusIn)
  document.addEventListener('focusout', onFocusOut)
  window.addEventListener('message', onMessage)
  window.addEventListener('keydown', onKeydown)
  window.addEventListener('resize', updateViewportScale)
  systemColorScheme.addEventListener('change', onSystemColorSchemeChange)
  phone.setSystemDarkMode(systemColorScheme.matches)
  void nuiCall('ui:ready', { protocolVersion: 1 })
  clockTicker = setInterval(() => {
    const now = Date.now()
    for (const alarm of clock.dueAlarms(now)) {
      notifications.show({
        appId: 'clock',
        critical: true,
        persistent: true,
        sound: alarm.sound,
        subtitle: alarm.time,
        text: alarm.note || phone.t('Apps.clock.alarm.ringing'),
        title: phone.t('Apps.clock.name'),
      })
    }

    const timer = clock.consumeDueTimer(now)
    if (timer) {
      notifications.show({
        appId: 'clock',
        critical: true,
        persistent: true,
        sound: timer.sound,
        subtitle: formatTimer(clock.timerDuration),
        text: timer.note || phone.t('Apps.clock.timer.ringing'),
        title: phone.t('Apps.clock.name'),
      })
    }
  }, 1000)
  if (isDevelopment) {
    const developmentHydration = hydrateDevelopmentPhone()
    if (developmentParameters.has('simPickerPreview')) {
      simPicker.value = {
        choices: [
          {
            imei: '356938035643809',
            name: 'Personal Phone',
            occupied: false,
          },
          {
            imei: '356938035643810',
            name: 'Work Phone',
            number: '5559876543',
            occupied: true,
          },
        ],
        number: '5551234567',
      }
    }
    if (developmentParameters.has('payphonePreview')) {
      openDevelopmentPayphonePreview()
    }
    if (
      developmentParameters.has('notificationPreview') ||
      developmentParameters.has('mutedNotificationPreview')
    ) {
      void developmentHydration.then(() => {
        if (developmentParameters.has('mutedNotificationPreview')) {
          phone.setAlertVolumes(0)
        }
        window.setTimeout(() => {
          notifications.show({
            appId: 'messages',
            persistent: !developmentParameters.has('mutedNotificationPreview'),
            route: '/apps/messages',
            text: 'You still got that spare alternator?',
            title: 'Tommy V',
          })
        }, 250)
      })
    }
  }
})

watch(
  () => route.params.appId,
  (appId) => {
    if (
      phone.isOpen &&
      phone.device?.imei &&
      appStore.hydrated &&
      typeof appId === 'string' &&
      isPhoneAppId(appId)
    ) {
      appStore.recordLaunch(appId)
    }
  },
)

watch(
  () => ({
    appIds: getInstalledNavigationAppIds(),
    currentApp: activeAppId.value,
    open: phone.isOpen,
  }),
  () => {
    if (phone.isOpen && appStore.hydrated) void syncNavigationState()
  },
  { deep: true },
)

watch(
  () => notifications.requiresAttention,
  (requiresAttention) => {
    void nuiCall('notification:focus', { active: requiresAttention })
  },
)

watch(
  () => Boolean(dynamicIslandActivity.value || calls.activeCall),
  (active) => {
    void nuiCall('ui:live-activity', { active })
  },
  { immediate: true },
)

watch(
  hardwareAlertVolume,
  (volume) => {
    setPhoneOutputVolume(volume / 100)
    if (radio.data.connected) void radio.setVolume(volume)
  },
  { immediate: true },
)

watch(
  () => phone.isOpen,
  (isOpen) => {
    if (unlockTimer !== undefined) window.clearTimeout(unlockTimer)
    if (!isOpen) {
      updateTextInputFocus(false)
      cancelUnlockedPhoneDataLoad()
      appStore.cancelPendingInstalls()
      activitySuspended.value = false
      weather.stop()
      controlCenterOpened.value = false
      isLocked.value = false
      isUnlocking.value = false
      passcodeVisible.value = false
      passcodeBusy.value = false
      passcodeError.value = ''
      passcodeRequired.value = false
      hardwareVolumeHudVisible.value = false
      if (hardwareVolumeHudTimer !== undefined) {
        window.clearTimeout(hardwareVolumeHudTimer)
        hardwareVolumeHudTimer = undefined
      }
      pendingUnlockRoute.value = null
      unlockedServicesLoaded.value = false
      if (passcodeLockTimer !== undefined) {
        window.clearInterval(passcodeLockTimer)
        passcodeLockTimer = undefined
      }
      return
    }
    isLocked.value = setupRequired.value
      ? false
      : developmentLockScreenPreview ||
        (!isDevelopment && phone.security.enabled)
    passcodeRequired.value = isLocked.value && phone.security.enabled
    unlockedServicesLoaded.value = false
    controlCenterOpened.value = false
    weather.start()
    isUnlocking.value = false
    passcodeVisible.value = false
    passcodeBusy.value = false
    passcodeError.value = ''
    passcodeResetKey.value += 1
    passcodeRetrySeconds.value = Math.max(
      0,
      (phone.security.lockedUntil ?? 0) - Math.floor(Date.now() / 1000),
    )
    if (passcodeRetrySeconds.value > 0) {
      startPasscodeLock(passcodeRetrySeconds.value)
    }
    phone.setLaunchOrigin(null)
    if (setupRequired.value) {
      void router.replace('/')
    } else if (openHomeRequested.value) {
      openHomeRequested.value = false
      if (isLocked.value) pendingUnlockRoute.value = '/'
      else {
        void router.replace('/')
        loadUnlockedPhoneData()
      }
    } else if (!isLocked.value) {
      loadUnlockedPhoneData()
    }
  },
)

watch(
  () => phone.cameraLandscape,
  (landscape) => {
    if (landscape) controlCenterOpened.value = false
  },
)

onBeforeUnmount(() => {
  removePhoneAudioController?.()
  updateTextInputFocus(false)
  cancelUnlockedPhoneDataLoad()
  weather.stop()
  if (clockTicker) clearInterval(clockTicker)
  if (companiesChangeTimer !== undefined) {
    window.clearTimeout(companiesChangeTimer)
  }
  if (unlockTimer !== undefined) window.clearTimeout(unlockTimer)
  if (passcodeLockTimer !== undefined) window.clearInterval(passcodeLockTimer)
  if (hardwareVolumeHudTimer !== undefined) {
    window.clearTimeout(hardwareVolumeHudTimer)
  }
  window.removeEventListener('message', onMessage)
  window.removeEventListener('keydown', onKeydown)
  window.removeEventListener('resize', updateViewportScale)
  document.removeEventListener('focusin', onFocusIn)
  document.removeEventListener('focusout', onFocusOut)
  systemColorScheme.removeEventListener('change', onSystemColorSchemeChange)
})
</script>

<template>
  <PhoneMediaCapture />
  <PhoneMemoRecorder />
  <RadioHud />
  <PayphoneOverlay />
  <SimPhonePicker
    v-if="simPicker"
    :choices="simPicker.choices"
    :number="simPicker.number"
    @close="closeSimPicker"
  />
  <Transition name="phone-lift" appear>
    <main
      v-if="
        phone.isOpen ||
        notifications.current ||
        calls.activeCall ||
        dynamicIslandActivity ||
        notifications.devicePreviews.length
      "
      class="phone-stage"
      :class="{
        'phone-stage--browser-preview': isBrowserPreview,
        'phone-stage--landscape': phone.cameraLandscape,
        'phone-stage--live-activity':
          !phone.isOpen && Boolean(dynamicIslandActivity || calls.activeCall),
        'phone-stage--peek': notifications.isPeeking,
      }"
      :style="phoneStageStyle"
    >
      <div class="phone-device-row">
        <NotificationPhonePreview
          v-for="notification in notifications.devicePreviews"
          :key="notification.device?.imei"
          :notification="notification"
          :device-pixel-ratio="browserDevicePixelRatio"
          :zoom="
            phoneBaseZoom *
            ((notification.device?.preferences.settings.phoneScale ?? 100) /
              100)
          "
          @close="notifications.dismiss(notification.id)"
          @open="openNotificationPreview"
        />
        <div
          v-if="
            phone.isOpen ||
            notifications.current ||
            calls.activeCall ||
            dynamicIslandActivity
          "
          class="phone-resolution-wrapper phone-resolution-wrapper--primary"
        >
          <div
            id="phone-home-drag-portal"
            class="phone-home-drag-portal"
            aria-hidden="true"
          ></div>
          <div class="phone-resolution-canvas phone-resolution-canvas--primary">
            <section
              class="phone-device"
              :class="{
                'phone-app--light': !displayedDarkMode,
                'phone-device--island-expanded': dynamicIslandExpanded,
                [`phone-app--${phone.preferences.settings.graphicsMode}`]: true,
              }"
              :aria-label="phone.t('Common.phone')"
            >
              <button
                type="button"
                class="phone-hardware-button phone-hardware-button--action"
                :aria-label="
                  phone.t(
                    hardwareAlertVolume > 0
                      ? 'HardwareButtons.mute'
                      : 'HardwareButtons.unmute',
                  )
                "
                :aria-pressed="hardwareAlertVolume === 0"
                :disabled="setupRequired"
                @click="toggleHardwareAlertMute"
              ></button>
              <button
                type="button"
                class="phone-hardware-button phone-hardware-button--volume-up"
                :aria-label="phone.t('HardwareButtons.volumeUp')"
                :disabled="setupRequired"
                @click="changeHardwareAlertVolume(10)"
              ></button>
              <button
                type="button"
                class="phone-hardware-button phone-hardware-button--volume-down"
                :aria-label="phone.t('HardwareButtons.volumeDown')"
                :disabled="setupRequired"
                @click="changeHardwareAlertVolume(-10)"
              ></button>
              <button
                type="button"
                class="phone-hardware-button phone-hardware-button--power"
                :aria-label="
                  phone.t(
                    isLocked
                      ? 'HardwareButtons.unlock'
                      : 'HardwareButtons.lock',
                  )
                "
                :disabled="setupRequired"
                @click="toggleHardwareLock"
              ></button>
              <div
                class="phone-screen"
                :class="{
                  'phone-screen--app': isAppRoute || isDevelopmentRoute,
                  'phone-app--light': !displayedDarkMode,
                  [`phone-app--${phone.preferences.settings.graphicsMode}`]: true,
                }"
              >
                <Transition name="phone-volume-hud">
                  <div
                    v-if="hardwareVolumeHudVisible"
                    class="phone-volume-hud"
                    :style="hardwareVolumeHudStyle"
                    role="status"
                    aria-live="polite"
                    :aria-label="
                      phone.t('HardwareButtons.volumeLevel', {
                        value: String(hardwareAlertVolume),
                      })
                    "
                  >
                    <svg
                      class="phone-volume-hud__icon"
                      aria-hidden="true"
                      viewBox="0 0 24 24"
                    >
                      <path d="M4 9v6h4l5 4V5L8 9H4Z" />
                      <path
                        v-if="hardwareAlertVolume > 0"
                        d="M16 8.2c1.1 1 1.7 2.2 1.7 3.8s-.6 2.8-1.7 3.8"
                      />
                      <path v-else d="m16.2 9.2 4.6 4.6m0-4.6-4.6 4.6" />
                    </svg>
                    <span
                      class="phone-volume-hud__level"
                      aria-hidden="true"
                    ></span>
                  </div>
                </Transition>
                <k-app
                  theme="ios"
                  :dark="displayedDarkMode"
                  safe-areas
                  class="phone-app"
                  :style="phoneDisplayStyle"
                  :class="{
                    dark: displayedDarkMode,
                    'phone-app--light': !displayedDarkMode,
                    'phone-app--messages': route.params.appId === 'messages',
                    'phone-app--status-light':
                      WHITE_STATUS_BAR_APP_IDS.has(activeAppId),
                    'phone-app--status-dark':
                      DARK_STATUS_BAR_APP_IDS.has(activeAppId),
                    'phone-app--setup': setupRequired,
                    [`phone-app--${phone.preferences.settings.graphicsMode}`]: true,
                    'phone-app--unlocking': isUnlocking,
                  }"
                >
                  <PhoneStatusBar
                    v-if="!isLocked && !(isHomeRoute && springboardEditing)"
                    :control-center-opened="controlCenterOpened"
                    :interactive="!setupRequired"
                    :lockable="!setupRequired"
                    @control-center="toggleControlCenter"
                    @lock="lockPhone"
                  />
                  <SpringboardView
                    v-if="!isDevelopmentRoute && !setupRequired"
                    @edit-mode-change="springboardEditing = $event"
                  />
                  <SkyProvider
                    class="phone-app-theme"
                    :dark="displayedDarkMode"
                    safe-areas
                  >
                    <RouterView v-slot="{ Component }">
                      <Transition :name="appTransitionName">
                        <component
                          :is="Component"
                          v-if="
                            !setupRequired && (isAppRoute || isDevelopmentRoute)
                          "
                          :key="
                            isDevelopmentRoute ? String(route.name) : route.path
                          "
                        />
                      </Transition>
                    </RouterView>
                  </SkyProvider>
                  <PhoneHomeIndicator v-if="!isLocked && !setupRequired" />
                  <PhoneControlCenter
                    v-if="!setupRequired"
                    :opened="controlCenterOpened"
                    @close="controlCenterOpened = false"
                  />
                  <Transition name="lock-screen" @after-leave="completeUnlock">
                    <PhoneLockScreen
                      v-if="isLocked && !setupRequired"
                      :notifications="notifications.lockScreenNotifications"
                      @camera="unlockCamera"
                      @clear-notifications="notifications.clearLockScreen"
                      @dismiss-notification="
                        notifications.dismissFromLockScreen
                      "
                      @open-notification="openLockScreenNotification"
                      @unlock="unlockPhone"
                    />
                  </Transition>
                  <Transition name="lock-screen">
                    <PhonePasscode
                      v-if="isLocked && passcodeVisible && !setupRequired"
                      :busy="passcodeBusy"
                      :disabled="passcodeRetrySeconds > 0"
                      :error="passcodeError"
                      :length="phone.security.length ?? 6"
                      lock-screen
                      :reset-key="passcodeResetKey"
                      :subtitle="
                        passcodeRetrySeconds > 0
                          ? phone.t('LockScreen.passcode.tryAgain', {
                              seconds: String(passcodeRetrySeconds),
                            })
                          : phone.t('LockScreen.passcode.unlockSubtitle')
                      "
                      :title="phone.t('LockScreen.passcode.enter')"
                      @cancel="cancelPasscode"
                      @complete="submitUnlockPasscode"
                    />
                  </Transition>
                  <PhoneSetupAssistant
                    v-if="setupRequired"
                    @appearance-selected="setupAppearanceSelected = $event"
                    @complete="completePhoneSetup"
                    @skip="skipPhoneSetupForDevelopment"
                  />
                  <PhoneNotifications
                    :notification="notifications.current"
                    @close="notifications.dismissCurrent()"
                    @open="openNotificationPreview"
                  />
                  <EasyShareSheet />
                  <div class="phone-display-dimmer" aria-hidden="true"></div>
                </k-app>
              </div>
              <img
                class="phone-device__frame"
                :src="phoneFrameImage"
                alt=""
                aria-hidden="true"
                draggable="false"
              />
              <PhoneDynamicIsland
                v-if="!setupRequired && !isDynamicIslandGalleryRoute"
                @expanded-change="dynamicIslandExpanded = $event"
                @live-activity-change="dynamicIslandActivity = $event"
              />
            </section>
          </div>
        </div>
      </div>
    </main>
  </Transition>
</template>
