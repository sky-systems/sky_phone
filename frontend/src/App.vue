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

import PhoneHomeIndicator from '@/components/PhoneHomeIndicator.vue'
import PhoneControlCenter from '@/components/PhoneControlCenter.vue'
import PhoneMediaCapture from '@/components/PhoneMediaCapture.vue'
import PhoneLockScreen from '@/components/PhoneLockScreen.vue'
import PhoneNotifications from '@/components/PhoneNotifications.vue'
import NotificationPhonePreview from '@/components/NotificationPhonePreview.vue'
import PhoneStatusBar from '@/components/PhoneStatusBar.vue'
import SimPhonePicker, {
  type SimPhoneChoice,
} from '@/components/SimPhonePicker.vue'
import { PHONE_FRAME_IMAGES } from '@/config/appearance'
import { useClockStore } from '@/stores/clock'
import { useGamesStore } from '@/features/games/store'
import { useCallsStore } from '@/stores/calls'
import { useBankingStore } from '@/stores/banking'
import { useAccountStore } from '@/stores/account'
import { useMailStore } from '@/stores/mail'
import { useMessagesStore } from '@/stores/messages'
import { useDarkChatStore } from '@/stores/darkchat'
import { useMediaStore } from '@/stores/media'
import { useMarketplaceStore } from '@/stores/marketplace'
import { useAppStoreStore } from '@/stores/app-store'
import { isPhoneAppId } from '@/config/apps'
import { useNotesStore } from '@/stores/notes'
import { useWeatherStore } from '@/stores/weather'
import {
  useNotificationsStore,
  type PhoneNotificationInput,
} from '@/stores/notifications'
import { usePhoneStore, type PhoneOpenPayload } from '@/stores/phone'
import type { PhoneNotificationDevicePayload } from '@/types/device'
import type { MailCounts } from '@/types/mail'
import type { MarketplaceCounts } from '@/types/marketplace'
import type { PhoneCall } from '@/types/phone'
import { nuiCall } from '@/utils/nui'
import { formatTimer } from '@/utils/clock'
import { parsePhonePreferences } from '@/utils/preferences'
import SpringboardView from '@/views/SpringboardView.vue'

type AppMessage = {
  type?: string
  data?:
    | CalendarReminderData
    | MailEventData
    | MarketplaceEventData
    | MessagesEventData
    | DarkChatEventData
    | PhoneCall
    | PhoneNotificationInput
    | PhoneOpenPayload
}

type SimPickerPayload = {
  choices: SimPhoneChoice[]
  number: string
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

type DarkChatEventData = {
  conversationId?: string
  device?: PhoneNotificationDevicePayload
  notificationMode?: 'full' | 'private' | 'hidden'
  preview?: string
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
const REFERENCE_VIEWPORT_WIDTH = 1920
const REFERENCE_VIEWPORT_HEIGHT = 1080
const PHONE_BASE_SCALE = 0.69
const isDevelopment = import.meta.env.DEV

const phone = usePhoneStore()
const account = useAccountStore()
const clock = useClockStore()
const games = useGamesStore()
const calls = useCallsStore()
const banking = useBankingStore()
const mail = useMailStore()
const messages = useMessagesStore()
const darkchat = useDarkChatStore()
const media = useMediaStore()
const marketplace = useMarketplaceStore()
const appStore = useAppStoreStore()
const notes = useNotesStore()
const weather = useWeatherStore()
const notifications = useNotificationsStore()
const route = useRoute()
const router = useRouter()
const isAppRoute = computed(() => route.name === 'app')
const appTransitionName = computed(() =>
  route.query.transition === 'app-switch' ? 'app-switch' : 'app-window',
)
const isLocked = ref(false)
const isUnlocking = ref(false)
const controlCenterOpened = ref(false)
const simPicker = ref<SimPickerPayload | null>(null)
const systemColorScheme = window.matchMedia('(prefers-color-scheme: dark)')
const viewportScale = ref(getViewportScale())
const phoneBaseZoom = computed(() => viewportScale.value * PHONE_BASE_SCALE)
const phoneResolutionStyle = computed<CSSProperties>(() => ({
  '--phone-edge-gap': `${24 * viewportScale.value}px`,
  '--phone-stack-gap': `${16 * viewportScale.value}px`,
  '--phone-zoom':
    phoneBaseZoom.value * (phone.preferences.settings.phoneScale / 100),
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
let unlockTimer: number | undefined

function getViewportScale(): number {
  const heightScale = window.innerHeight / REFERENCE_VIEWPORT_HEIGHT
  if (isDevelopment) return heightScale

  return Math.min(window.innerWidth / REFERENCE_VIEWPORT_WIDTH, heightScale)
}

function hydratePhone(payload: PhoneOpenPayload): void {
  phone.open(payload)
  account.hydrate(payload.account ?? null)
  notes.hydrate(payload.notes ?? [])
  clock.hydrate(payload.device?.data.alarms?.payload)
  games.hydrate(payload.device?.data.games?.payload)
  media.hydrate(payload.device?.data.media?.payload)
  appStore.hydrate(payload.device?.data.apps?.payload)
  void mail.bootstrap(payload.account?.email ?? '')
  if (payload.account?.email) void marketplace.loadCounts()
  else marketplace.setCounts({ active: 0, unread: 0 })
  void calls.bootstrap()
  void messages.loadConversations()
  if (payload.account?.email) void darkchat.bootstrap()
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
        registered: true,
        type: 'registered',
      },
    },
    notes: [],
    token: 'development',
  })
}

function onMessage(event: MessageEvent<AppMessage>): void {
  if (event.data?.type === 'app:open') {
    hydratePhone(event.data.data as PhoneOpenPayload)
    void nuiCall('ui:opened')
  } else if (event.data?.type === 'device:updated') {
    hydratePhone(event.data.data as PhoneOpenPayload)
  } else if (event.data?.type === 'app:close') {
    phone.close()
  } else if (event.data?.type === 'notification:show' && event.data.data) {
    notifications.show(event.data.data as PhoneNotificationInput)
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
  } else if (event.data?.type === 'calls:changed') {
    void calls.loadRecents()
  } else if (event.data?.type === 'banking:changed') {
    void banking.load()
  } else if (
    (event.data?.type === 'call:incoming' ||
      event.data?.type === 'call:state') &&
    event.data.data
  ) {
    calls.applyCallState(event.data.data as PhoneCall)
    controlCenterOpened.value = false
    isLocked.value = false
    isUnlocking.value = false
    window.setTimeout(() => void router.push('/apps/phone'), 0)
  } else if (event.data?.type === 'sim:picker' && event.data.data) {
    simPicker.value = event.data.data as unknown as SimPickerPayload
  } else if (event.data?.type === 'sim:picker-close') {
    simPicker.value = null
  }
}

function onKeydown(event: KeyboardEvent): void {
  if (event.key !== 'Escape' || !phone.isOpen) return
  if (controlCenterOpened.value) {
    controlCenterOpened.value = false
    return
  }
  phone.close()
  void nuiCall('close')
}

function onSystemColorSchemeChange(event: MediaQueryListEvent): void {
  phone.setSystemDarkMode(event.matches)
}

function updateViewportScale(): void {
  viewportScale.value = getViewportScale()
}

function unlockPhone(): void {
  if (!isLocked.value) return
  isUnlocking.value = true
  isLocked.value = false

  unlockTimer = window.setTimeout(() => {
    isUnlocking.value = false
  }, 720)
}

function toggleControlCenter(): void {
  if (isLocked.value) return
  controlCenterOpened.value = !controlCenterOpened.value
}

function unlockCamera(): void {
  unlockPhone()
  window.setTimeout(() => void router.push('/apps/camera'), 0)
}

onMounted(() => {
  window.addEventListener('message', onMessage)
  window.addEventListener('keydown', onKeydown)
  window.addEventListener('resize', updateViewportScale)
  systemColorScheme.addEventListener('change', onSystemColorSchemeChange)
  phone.setSystemDarkMode(systemColorScheme.matches)
  void nuiCall('ui:ready')
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
    void hydrateDevelopmentPhone()
    if (new URLSearchParams(window.location.search).has('simPickerPreview')) {
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
  }
})

watch(
  () => route.params.appId,
  (appId) => {
    if (typeof appId === 'string' && isPhoneAppId(appId)) {
      appStore.recordLaunch(appId)
    }
  },
)

watch(
  [() => notifications.requiresAttention, () => calls.activeCall],
  ([requiresAttention, activeCall]) => {
    void nuiCall('notification:focus', {
      active: requiresAttention || activeCall !== null,
    })
  },
)

watch(
  () => phone.isOpen,
  (isOpen) => {
    if (unlockTimer !== undefined) window.clearTimeout(unlockTimer)
    if (!isOpen) {
      weather.stop()
      controlCenterOpened.value = false
      isLocked.value = false
      isUnlocking.value = false
      return
    }
    isLocked.value = true
    controlCenterOpened.value = false
    weather.start()
    isUnlocking.value = false
    phone.setLaunchOrigin(null)
    void router.replace('/')
  },
)

watch(
  () => phone.cameraLandscape,
  (landscape) => {
    if (landscape) controlCenterOpened.value = false
  },
)

onBeforeUnmount(() => {
  weather.stop()
  if (clockTicker) clearInterval(clockTicker)
  if (unlockTimer !== undefined) window.clearTimeout(unlockTimer)
  window.removeEventListener('message', onMessage)
  window.removeEventListener('keydown', onKeydown)
  window.removeEventListener('resize', updateViewportScale)
  systemColorScheme.removeEventListener('change', onSystemColorSchemeChange)
})
</script>

<template>
  <PhoneMediaCapture />
  <SimPhonePicker
    v-if="simPicker"
    :choices="simPicker.choices"
    :number="simPicker.number"
    @close="simPicker = null"
  />
  <Transition name="phone-lift" appear>
    <main
      v-if="
        phone.isOpen ||
        notifications.current ||
        calls.activeCall ||
        notifications.devicePreviews.length
      "
      class="phone-stage"
      :class="{
        'phone-stage--dev': isDevelopment,
        'phone-stage--landscape': phone.cameraLandscape,
        'phone-stage--peek': notifications.isPeeking,
      }"
      :style="phoneResolutionStyle"
    >
      <div class="phone-device-row">
        <NotificationPhonePreview
          v-for="notification in notifications.devicePreviews"
          :key="notification.device?.imei"
          :notification="notification"
          :zoom="
            phoneBaseZoom *
            ((notification.device?.preferences.settings.phoneScale ?? 100) /
              100)
          "
          @close="notifications.dismiss(notification.id)"
        />
        <div
          v-if="phone.isOpen || notifications.current"
          class="phone-resolution-wrapper phone-resolution-wrapper--primary"
        >
          <section class="phone-device" :aria-label="phone.t('Common.phone')">
            <div
              class="phone-screen"
              :class="{ 'phone-screen--app': isAppRoute }"
            >
              <k-app
                theme="ios"
                :dark="phone.isDarkMode"
                safe-areas
                class="phone-app"
                :style="phoneDisplayStyle"
                :class="{
                  dark: phone.isDarkMode,
                  'phone-app--light': !phone.isDarkMode,
                  'phone-app--unlocking': isUnlocking,
                }"
              >
                <PhoneStatusBar
                  v-if="!isLocked"
                  :control-center-opened="controlCenterOpened"
                  @control-center="toggleControlCenter"
                />
                <SpringboardView />
                <RouterView v-slot="{ Component }">
                  <Transition :name="appTransitionName">
                    <component
                      :is="Component"
                      v-if="isAppRoute"
                      :key="route.path"
                    />
                  </Transition>
                </RouterView>
                <PhoneHomeIndicator v-if="!isLocked" />
                <PhoneControlCenter
                  :opened="controlCenterOpened"
                  @close="controlCenterOpened = false"
                />
                <Transition name="lock-screen">
                  <PhoneLockScreen
                    v-if="isLocked"
                    @camera="unlockCamera"
                    @unlock="unlockPhone"
                  />
                </Transition>
                <PhoneNotifications
                  :notification="notifications.current"
                  @close="notifications.dismissCurrent()"
                />
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
          </section>
        </div>
      </div>
    </main>
  </Transition>
</template>
