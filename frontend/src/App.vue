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
import PhoneLockScreen from '@/components/PhoneLockScreen.vue'
import PhoneNotifications from '@/components/PhoneNotifications.vue'
import NotificationPhonePreview from '@/components/NotificationPhonePreview.vue'
import PhoneStatusBar from '@/components/PhoneStatusBar.vue'
import { PHONE_FRAME_IMAGES } from '@/config/appearance'
import { useClockStore } from '@/stores/clock'
import { useAccountStore } from '@/stores/account'
import { useMailStore } from '@/stores/mail'
import { useMediaStore } from '@/stores/media'
import { useNotesStore } from '@/stores/notes'
import {
  useNotificationsStore,
  type PhoneNotificationInput,
} from '@/stores/notifications'
import { usePhoneStore, type PhoneOpenPayload } from '@/stores/phone'
import type { PhoneNotificationDevicePayload } from '@/types/device'
import type { MailCounts } from '@/types/mail'
import { nuiCall } from '@/utils/nui'
import { formatTimer } from '@/utils/clock'
import { parsePhonePreferences } from '@/utils/preferences'
import SpringboardView from '@/views/SpringboardView.vue'

type AppMessage = {
  type?: string
  data?: MailEventData | PhoneNotificationInput | PhoneOpenPayload
}

type MailEventData = {
  counts?: MailCounts
  device?: PhoneNotificationDevicePayload
  sender?: string
  subject?: string
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
const mail = useMailStore()
const media = useMediaStore()
const notes = useNotesStore()
const notifications = useNotificationsStore()
const route = useRoute()
const router = useRouter()
const isAppRoute = computed(() => route.name === 'app')
const isLocked = ref(false)
const isUnlocking = ref(false)
const systemColorScheme = window.matchMedia('(prefers-color-scheme: dark)')
const viewportScale = ref(getViewportScale())
const phoneBaseZoom = computed(() => viewportScale.value * PHONE_BASE_SCALE)
const phoneResolutionStyle = computed<CSSProperties>(() => ({
  '--phone-edge-gap': `${24 * viewportScale.value}px`,
  '--phone-stack-gap': `${16 * viewportScale.value}px`,
  '--phone-zoom':
    phoneBaseZoom.value * (phone.preferences.settings.phoneScale / 100),
}))
const phoneFrameImage = computed(
  () => PHONE_FRAME_IMAGES[phone.preferences.settings.frame],
)
let clockTicker: ReturnType<typeof setInterval> | undefined
let unlockTimer: number | undefined
let cameraTimer: number | undefined

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
  media.hydrate(payload.device?.data.media?.payload)
  void mail.bootstrap(payload.account?.email ?? '')
}

function onMessage(event: MessageEvent<AppMessage>): void {
  if (event.data?.type === 'app:open') {
    hydratePhone(event.data.data as PhoneOpenPayload)
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
  }
}

function onKeydown(event: KeyboardEvent): void {
  if (event.key !== 'Escape' || !phone.isOpen) return
  phone.close()
  void nuiCall('close')
}

function onSystemColorSchemeChange(event: MediaQueryListEvent): void {
  phone.setSystemDarkMode(event.matches)
}

function updateViewportScale(): void {
  viewportScale.value = getViewportScale()
}

function unlockPhone(destination?: 'camera'): void {
  if (!isLocked.value) return
  isUnlocking.value = true
  isLocked.value = false

  if (destination === 'camera') {
    cameraTimer = window.setTimeout(() => {
      void router.push('/apps/camera')
    }, 260)
  }

  unlockTimer = window.setTimeout(() => {
    isUnlocking.value = false
  }, 720)
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
    hydratePhone({
      account: null,
      device: {
        data: {},
        imei: '356938035643809',
        name: 'iFruit Phone',
      },
      notes: [],
      token: 'development',
    })
  }
})

watch(
  () => notifications.requiresAttention,
  (active) => {
    void nuiCall('notification:focus', { active })
  },
)

watch(
  () => phone.isOpen,
  (isOpen) => {
    if (unlockTimer !== undefined) window.clearTimeout(unlockTimer)
    if (cameraTimer !== undefined) window.clearTimeout(cameraTimer)
    if (!isOpen) {
      isLocked.value = false
      isUnlocking.value = false
      return
    }
    isLocked.value = true
    isUnlocking.value = false
    phone.setLaunchOrigin(null)
    void router.replace('/')
  },
)

onBeforeUnmount(() => {
  if (clockTicker) clearInterval(clockTicker)
  if (unlockTimer !== undefined) window.clearTimeout(unlockTimer)
  if (cameraTimer !== undefined) window.clearTimeout(cameraTimer)
  window.removeEventListener('message', onMessage)
  window.removeEventListener('keydown', onKeydown)
  window.removeEventListener('resize', updateViewportScale)
  systemColorScheme.removeEventListener('change', onSystemColorSchemeChange)
})
</script>

<template>
  <Transition name="phone-lift" appear>
    <main
      v-if="
        phone.isOpen ||
        notifications.current ||
        notifications.devicePreviews.length
      "
      class="phone-stage"
      :class="{
        'phone-stage--dev': isDevelopment,
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
                :class="{
                  dark: phone.isDarkMode,
                  'phone-app--light': !phone.isDarkMode,
                  'phone-app--unlocking': isUnlocking,
                }"
              >
                <PhoneStatusBar v-if="!isLocked" />
                <SpringboardView />
                <RouterView v-slot="{ Component }">
                  <Transition name="app-window">
                    <component :is="Component" v-if="isAppRoute" />
                  </Transition>
                </RouterView>
                <PhoneHomeIndicator v-if="!isLocked" />
                <Transition name="lock-screen">
                  <PhoneLockScreen v-if="isLocked" @unlock="unlockPhone" />
                </Transition>
                <PhoneNotifications
                  :notification="notifications.current"
                  @close="notifications.dismissCurrent()"
                />
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
