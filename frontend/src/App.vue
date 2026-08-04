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
import { useRoute } from 'vue-router'

import PhoneHomeIndicator from '@/components/PhoneHomeIndicator.vue'
import PhoneNotifications from '@/components/PhoneNotifications.vue'
import PhoneStatusBar from '@/components/PhoneStatusBar.vue'
import { PHONE_FRAME_IMAGES } from '@/config/appearance'
import { useClockStore } from '@/stores/clock'
import {
  useNotificationsStore,
  type PhoneNotificationInput,
} from '@/stores/notifications'
import { usePhoneStore, type PhoneOpenPayload } from '@/stores/phone'
import { nuiCall } from '@/utils/nui'
import { formatTimer } from '@/utils/clock'
import SpringboardView from '@/views/SpringboardView.vue'

type AppMessage = {
  type?: string
  data?: PhoneNotificationInput | PhoneOpenPayload
}

const REFERENCE_VIEWPORT_WIDTH = 1920
const REFERENCE_VIEWPORT_HEIGHT = 1080
const PHONE_BASE_SCALE = 0.69
const isDevelopment = import.meta.env.DEV

const phone = usePhoneStore()
const clock = useClockStore()
const notifications = useNotificationsStore()
const route = useRoute()
const isAppRoute = computed(() => route.name === 'app')
const systemColorScheme = window.matchMedia('(prefers-color-scheme: dark)')
const viewportScale = ref(getViewportScale())
const phoneResolutionStyle = computed<CSSProperties>(() => ({
  '--phone-edge-gap': `${24 * viewportScale.value}px`,
  '--phone-zoom':
    viewportScale.value *
    PHONE_BASE_SCALE *
    (phone.preferences.settings.phoneScale / 100),
}))
const phoneFrameImage = computed(
  () => PHONE_FRAME_IMAGES[phone.preferences.settings.frame],
)
let clockTicker: ReturnType<typeof setInterval> | undefined

function getViewportScale(): number {
  const heightScale = window.innerHeight / REFERENCE_VIEWPORT_HEIGHT
  if (isDevelopment) return heightScale

  return Math.min(
    window.innerWidth / REFERENCE_VIEWPORT_WIDTH,
    heightScale,
  )
}

function onMessage(event: MessageEvent<AppMessage>): void {
  if (event.data?.type === 'app:open') {
    phone.open(event.data.data as PhoneOpenPayload)
  } else if (event.data?.type === 'app:close') {
    phone.close()
  } else if (event.data?.type === 'notification:show' && event.data.data) {
    notifications.show(event.data.data as PhoneNotificationInput)
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
  if (isDevelopment) phone.open()
})

watch(
  () => notifications.requiresAttention,
  (active) => {
    void nuiCall('notification:focus', { active })
  },
)

onBeforeUnmount(() => {
  if (clockTicker) clearInterval(clockTicker)
  window.removeEventListener('message', onMessage)
  window.removeEventListener('keydown', onKeydown)
  window.removeEventListener('resize', updateViewportScale)
  systemColorScheme.removeEventListener('change', onSystemColorSchemeChange)
})
</script>

<template>
  <Transition name="phone-lift" appear>
    <main
      v-if="phone.isOpen || notifications.current"
      class="phone-stage"
      :class="{
        'phone-stage--dev': isDevelopment,
        'phone-stage--peek': notifications.isPeeking,
      }"
      :style="phoneResolutionStyle"
    >
      <div class="phone-resolution-wrapper">
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
              }"
            >
              <PhoneStatusBar />
              <SpringboardView />
              <RouterView v-slot="{ Component }">
                <Transition name="app-window">
                  <component :is="Component" v-if="isAppRoute" />
                </Transition>
              </RouterView>
              <PhoneHomeIndicator />
              <PhoneNotifications />
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
    </main>
  </Transition>
</template>
