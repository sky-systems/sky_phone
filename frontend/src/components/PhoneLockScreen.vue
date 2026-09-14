<script setup lang="ts">
import { kFab, kGlass } from 'konsta/vue'
import {
  Camera,
  Flashlight,
  LockKeyhole,
  ScanFace,
  Trash2,
} from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

import PhoneStatusIndicators from '@/components/PhoneStatusIndicators.vue'
import { getPhoneApp } from '@/config/apps'
import type { PhoneNotification } from '@/stores/notifications'
import { usePhoneStore } from '@/stores/phone'
import {
  clampNotificationSwipeOffset,
  NOTIFICATION_SWIPE_ACTION_WIDTH,
  resolveNotificationSwipeAxis,
  shouldRevealNotificationAction,
  type NotificationSwipeAxis,
} from '@/utils/notificationSwipe'
import { nuiCall } from '@/utils/nui'
import type { PhonePreferencesV1 } from '@/utils/preferences'

const props = defineProps<{
  notifications: PhoneNotification[]
  preferences?: PhonePreferencesV1
  preview?: boolean
}>()
const emit = defineEmits<{
  camera: []
  clearNotifications: []
  dismissNotification: [id: string]
  openNotification: [notification: PhoneNotification]
  unlock: []
}>()

const phone = usePhoneStore()
const preferences = computed(() => props.preferences ?? phone.preferences)
const now = ref(new Date())
const dragOffset = ref(0)
const dragging = ref(false)
const flashlightActive = ref(false)
const revealedNotificationId = ref<string | null>(null)
const swipingNotificationId = ref<string | null>(null)
const notificationSwipeOffset = ref(0)
const shortcutColors = {
  bgIos: 'bg-ios-light-glass dark:bg-ios-dark-glass',
  activeBgIos: 'active:bg-white/90 dark:active:bg-white/20',
  textIos: 'text-black dark:text-white',
}
let pointerStart = 0
let pointerStartedAt = 0
let clockTicker: number | undefined
let notificationPointerId: number | null = null
let notificationPointerStartX = 0
let notificationPointerStartY = 0
let notificationPointerStartedAt = 0
let notificationSwipeAxis: NotificationSwipeAxis | null = null
let suppressNotificationClickUntil = 0

const date = computed(() =>
  new Intl.DateTimeFormat(phone.lang, {
    day: 'numeric',
    month: 'long',
    weekday: 'long',
  }).format(now.value),
)
const time = computed(() =>
  new Intl.DateTimeFormat(phone.lang, {
    hour: '2-digit',
    hourCycle: 'h23',
    minute: '2-digit',
  })
    .formatToParts(now.value)
    .filter((part) => part.type !== 'dayPeriod')
    .map((part) => part.value)
    .join('')
    .trim(),
)
const dragStyle = computed<Record<string, string>>(() => {
  const imageUrl = preferences.value.settings.lockWallpaperImageUrl
  return {
    '--lock-drag': `${dragOffset.value}px`,
    ...(preferences.value.settings.lockWallpaper === 'custom' && imageUrl
      ? { '--phone-wallpaper-image': `url(${JSON.stringify(imageUrl)})` }
      : {}),
  }
})
const flashlightShortcutColors = computed(() =>
  flashlightActive.value
    ? {
        ...shortcutColors,
        bgIos: 'bg-white',
        textIos: 'text-purple-500',
      }
    : shortcutColors,
)

function onPointerDown(event: PointerEvent): void {
  if (props.preview) return
  if (
    (event.target as HTMLElement).closest('button, .lock-screen__notifications')
  )
    return
  pointerStart = event.clientY
  pointerStartedAt = Date.now()
  dragging.value = true
  ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
}

function openNotification(notification: PhoneNotification): void {
  if (performance.now() <= suppressNotificationClickUntil) return
  if (revealedNotificationId.value === notification.id) {
    closeNotificationAction()
    return
  }
  if (notification.route) emit('openNotification', notification)
}

function notificationOffset(notificationId: string): number {
  if (swipingNotificationId.value === notificationId)
    return notificationSwipeOffset.value
  return revealedNotificationId.value === notificationId
    ? -NOTIFICATION_SWIPE_ACTION_WIDTH
    : 0
}

function notificationStyle(notificationId: string): Record<string, string> {
  return {
    '--notification-swipe': `${notificationOffset(notificationId)}px`,
  }
}

function closeNotificationAction(): void {
  revealedNotificationId.value = null
  swipingNotificationId.value = null
  notificationSwipeOffset.value = 0
}

function beginNotificationSwipe(
  notificationId: string,
  event: PointerEvent,
): void {
  if (props.preview || event.button !== 0) return

  if (
    revealedNotificationId.value &&
    revealedNotificationId.value !== notificationId
  ) {
    revealedNotificationId.value = null
  }

  notificationPointerId = event.pointerId
  notificationPointerStartX = event.clientX
  notificationPointerStartY = event.clientY
  notificationPointerStartedAt = performance.now()
  notificationSwipeAxis = null
  swipingNotificationId.value = notificationId
  notificationSwipeOffset.value =
    revealedNotificationId.value === notificationId
      ? -NOTIFICATION_SWIPE_ACTION_WIDTH
      : 0
}

function moveNotificationSwipe(
  notificationId: string,
  event: PointerEvent,
): void {
  if (
    swipingNotificationId.value !== notificationId ||
    notificationPointerId !== event.pointerId
  ) {
    return
  }

  const deltaX = event.clientX - notificationPointerStartX
  const deltaY = event.clientY - notificationPointerStartY
  notificationSwipeAxis ??= resolveNotificationSwipeAxis(deltaX, deltaY)

  if (notificationSwipeAxis === 'vertical') {
    swipingNotificationId.value = null
    notificationSwipeOffset.value = 0
    return
  }
  if (notificationSwipeAxis !== 'horizontal') return

  const target = event.currentTarget as HTMLElement
  if (!target.hasPointerCapture(event.pointerId))
    target.setPointerCapture(event.pointerId)
  event.preventDefault()

  const startingOffset =
    revealedNotificationId.value === notificationId
      ? -NOTIFICATION_SWIPE_ACTION_WIDTH
      : 0
  notificationSwipeOffset.value = clampNotificationSwipeOffset(
    startingOffset + deltaX,
  )
}

function finishNotificationSwipe(
  notificationId: string,
  event: PointerEvent,
): void {
  if (
    swipingNotificationId.value !== notificationId ||
    notificationPointerId !== event.pointerId
  ) {
    return
  }

  const elapsed = Math.max(1, performance.now() - notificationPointerStartedAt)
  const velocityX = (event.clientX - notificationPointerStartX) / elapsed
  const wasHorizontal = notificationSwipeAxis === 'horizontal'
  if (wasHorizontal) {
    suppressNotificationClickUntil = performance.now() + 120
    revealedNotificationId.value = shouldRevealNotificationAction(
      notificationSwipeOffset.value,
      velocityX,
    )
      ? notificationId
      : null
  }

  swipingNotificationId.value = null
  notificationSwipeOffset.value = 0
  notificationPointerId = null
  notificationSwipeAxis = null
}

function dismissNotification(notificationId: string): void {
  closeNotificationAction()
  emit('dismissNotification', notificationId)
}

function onPointerMove(event: PointerEvent): void {
  if (!dragging.value) return
  dragOffset.value = Math.min(0, event.clientY - pointerStart)
}

function finishPointer(event: PointerEvent): void {
  if (!dragging.value) return
  const distance = event.clientY - pointerStart
  const elapsed = Math.max(1, Date.now() - pointerStartedAt)
  const velocity = Math.abs(distance) / elapsed
  dragging.value = false

  if (distance < -74 || (distance < -22 && velocity > 0.55)) {
    emit('unlock')
    return
  }

  dragOffset.value = 0
}

function unlockWithKeyboard(event: KeyboardEvent): void {
  if (props.preview) return
  if (event.key === 'Enter' || event.key === ' ') emit('unlock')
}

function unlockFromWallpaper(event: MouseEvent): void {
  if (props.preview) return
  if (
    (event.target as HTMLElement).closest(
      'button, [role="link"], .lock-screen__notifications',
    )
  )
    return
  emit('unlock')
}

async function toggleFlashlight(): Promise<void> {
  const enabled = !flashlightActive.value
  flashlightActive.value = enabled
  const response = await nuiCall('camera:setFlash', { enabled })
  if (!response.success) flashlightActive.value = !enabled
}

onMounted(() => {
  clockTicker = window.setInterval(() => {
    now.value = new Date()
  }, 15_000)
})

onBeforeUnmount(() => {
  if (clockTicker !== undefined) window.clearInterval(clockTicker)
  if (flashlightActive.value)
    void nuiCall('camera:setFlash', { enabled: false })
})
</script>

<template>
  <section
    class="lock-screen"
    :class="[
      `wallpaper--${preferences.settings.lockWallpaper}`,
      {
        'lock-screen--dragging': dragging,
        'lock-screen--preview': preview,
      },
    ]"
    :style="dragStyle"
    :aria-label="phone.t('LockScreen.label')"
    :tabindex="preview ? -1 : 0"
    @keydown="unlockWithKeyboard"
    @pointerdown="onPointerDown"
    @pointermove="onPointerMove"
    @pointerup="finishPointer"
    @pointercancel="finishPointer"
    @click="unlockFromWallpaper"
  >
    <div class="lock-screen__shade" aria-hidden="true"></div>

    <header class="lock-screen__status">
      <time class="lock-screen__status-time">{{ time }}</time>
      <PhoneStatusIndicators class="lock-screen__indicators" />
    </header>

    <component
      :is="!preview && phone.security.faceIdEnabled ? ScanFace : LockKeyhole"
      class="lock-screen__lock"
      :size="14"
      :stroke-width="1.8"
      aria-hidden="true"
    />
    <div class="lock-screen__content">
      <time class="lock-screen__date">{{ date }}</time>
      <time class="lock-screen__time">{{ time }}</time>
    </div>

    <section
      v-if="props.notifications.length"
      class="lock-screen__notifications"
      aria-live="polite"
    >
      <button
        v-if="!preview && props.notifications.length > 1"
        class="lock-screen__notifications-clear"
        type="button"
        @click.stop="emit('clearNotifications')"
      >
        {{ phone.t('Notifications.clearAll') }}
      </button>
      <div
        v-for="notification in props.notifications"
        :key="notification.id"
        class="lock-screen__notification-row"
        :class="{
          'is-revealed': revealedNotificationId === notification.id,
          'is-swiping': swipingNotificationId === notification.id,
          'is-action-visible': notificationOffset(notification.id) < -0.5,
        }"
        :style="notificationStyle(notification.id)"
      >
        <button
          class="lock-screen__notification-clear"
          type="button"
          :tabindex="revealedNotificationId === notification.id ? 0 : -1"
          :aria-hidden="revealedNotificationId !== notification.id"
          :aria-label="phone.t('Notifications.clear')"
          @click.stop="dismissNotification(notification.id)"
        >
          <Trash2 :size="18" :stroke-width="1.8" aria-hidden="true" />
          <span>{{ phone.t('Notifications.clear') }}</span>
        </button>
        <k-glass
          class="lock-screen__notification"
          :class="{ 'is-actionable': !!notification.route }"
          :highlight="false"
          :role="notification.route ? 'button' : undefined"
          :tabindex="notification.route ? 0 : undefined"
          :aria-label="
            notification.route ? phone.t('Notifications.open') : undefined
          "
          @click="openNotification(notification)"
          @keydown.enter.prevent="openNotification(notification)"
          @keydown.space.prevent="openNotification(notification)"
          @keydown.delete.prevent="dismissNotification(notification.id)"
          @pointerdown.stop="beginNotificationSwipe(notification.id, $event)"
          @pointermove.stop="moveNotificationSwipe(notification.id, $event)"
          @pointerup.stop="finishNotificationSwipe(notification.id, $event)"
          @pointercancel.stop="finishNotificationSwipe(notification.id, $event)"
        >
          <img
            v-if="getPhoneApp(notification.appId)?.iconImage"
            :src="getPhoneApp(notification.appId)?.iconImage"
            alt=""
            class="lock-screen__notification-icon"
          />
          <div class="lock-screen__notification-copy">
            <div class="lock-screen__notification-heading">
              <strong>{{ notification.title }}</strong>
              <span>{{ phone.t('Notifications.now') }}</span>
            </div>
            <small v-if="notification.subtitle">{{
              notification.subtitle
            }}</small>
            <p>{{ notification.text }}</p>
          </div>
        </k-glass>
      </div>
    </section>

    <div v-if="!preview" class="lock-screen__footer">
      <nav class="lock-screen__shortcuts">
        <k-fab
          component="button"
          type="button"
          class="lock-screen__shortcut"
          :colors="flashlightShortcutColors"
          :aria-label="phone.t('LockScreen.flashlight')"
          @click="toggleFlashlight"
        >
          <template #icon>
            <Flashlight :stroke-width="1.4" aria-hidden="true" />
          </template>
        </k-fab>
        <k-fab
          component="button"
          type="button"
          class="lock-screen__shortcut"
          :colors="shortcutColors"
          :aria-label="phone.t('LockScreen.camera')"
          @click="emit('camera')"
        >
          <template #icon>
            <Camera :stroke-width="1.4" aria-hidden="true" />
          </template>
        </k-fab>
      </nav>

      <button class="lock-screen__swipe" type="button" @click="emit('unlock')">
        <span class="lock-screen__swipe-chevron" aria-hidden="true"></span>
        {{ phone.t('LockScreen.swipeUp') }}
      </button>
    </div>
  </section>
</template>
