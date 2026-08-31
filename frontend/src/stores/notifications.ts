import { computed, ref } from 'vue'
import { defineStore } from 'pinia'

import { isPhoneAppId } from '@/config/apps'
import { usePhoneStore } from '@/stores/phone'
import type { LaunchablePhoneAppId } from '@/types/apps'
import { nuiCall } from '@/utils/nui'
import { findCustomPhoneTone, playCustomPhoneTone } from '@/utils/customTones'
import {
  DEFAULT_APP_NOTIFICATION_PREFERENCES,
  isBuiltInNotificationSoundId,
  type PhonePreferencesV1,
} from '@/utils/preferences'
import {
  playPhoneTone,
  playPhoneVibration,
  type PhoneToneId,
} from '@/utils/tones'

export type PhoneNotificationDevice = {
  imei: string
  name: string
  preferences: PhonePreferencesV1
}

export type PhoneNotificationInput = {
  appId: LaunchablePhoneAppId
  critical?: boolean
  device?: PhoneNotificationDevice
  persistent?: boolean
  route?: string
  sound?: PhoneToneId
  subtitle?: string
  text: string
  title: string
}

export type PhoneNotification = PhoneNotificationInput & {
  id: string
}

type PersistedPhoneNotification = Pick<
  PhoneNotification,
  'appId' | 'id' | 'route' | 'subtitle' | 'text' | 'title'
>

type PersistedNotificationsV1 = {
  items: PersistedPhoneNotification[]
  version: 1
}

export const MAX_LOCK_SCREEN_NOTIFICATIONS = 50

const timeoutHandles = new Map<string, ReturnType<typeof setTimeout>>()
const stopToneHandles = new Map<string, () => void>()
const persistenceQueues = new Map<string, Promise<void>>()

export const useNotificationsStore = defineStore('notifications', () => {
  const phone = usePhoneStore()
  const queue = ref<PhoneNotification[]>([])
  const deviceQueue = ref<PhoneNotification[]>([])
  const lockScreenQueues = ref<Record<string, PhoneNotification[]>>({})
  const current = computed(() => queue.value[0] ?? null)
  const devicePreviews = computed(() => {
    const devices = new Set<string>()
    return deviceQueue.value.filter((notification) => {
      const imei = notification.device?.imei
      if (!imei || devices.has(imei)) return false
      devices.add(imei)
      return true
    })
  })
  const isPeeking = computed(() => !!current.value && !phone.isOpen)
  const lockScreenNotifications = computed(() => {
    const imei = phone.device?.imei
    if (!imei) return []
    return [...(lockScreenQueues.value[imei] ?? [])].reverse()
  })
  const requiresAttention = computed(
    () =>
      !phone.isOpen &&
      (!!current.value?.persistent ||
        devicePreviews.value.some((notification) => notification.persistent)),
  )

  function persist(imei: string): void {
    const items = (lockScreenQueues.value[imei] ?? []).map(
      ({ appId, id, route, subtitle, text, title }) => ({
        appId,
        id,
        ...(route ? { route } : {}),
        ...(subtitle ? { subtitle } : {}),
        text,
        title,
      }),
    )
    const previous = persistenceQueues.get(imei) ?? Promise.resolve()
    const queued = previous.then(async () => {
      const response = await nuiCall('notifications:save', {
        imei,
        payload: { items, version: 1 },
      })
      if (!response.success) {
        console.error(
          `[Phone notifications] Could not persist notifications for ${imei}: ${response.error ?? 'request_failed'}`,
        )
      }
    })
    const tracked = queued.finally(() => {
      if (persistenceQueues.get(imei) === tracked)
        persistenceQueues.delete(imei)
    })
    persistenceQueues.set(imei, tracked)
  }

  function hydrate(payload: unknown, imei: string): void {
    const stored: PhoneNotification[] = []
    if (payload !== undefined && payload !== null) {
      if (
        typeof payload !== 'object' ||
        (payload as Partial<PersistedNotificationsV1>).version !== 1 ||
        !Array.isArray((payload as Partial<PersistedNotificationsV1>).items)
      ) {
        console.error(
          '[Phone notifications] Invalid persisted notification data.',
        )
      } else {
        for (const item of (payload as PersistedNotificationsV1).items) {
          if (
            typeof item?.id !== 'string' ||
            typeof item?.appId !== 'string' ||
            !isPhoneAppId(item.appId) ||
            typeof item?.text !== 'string' ||
            typeof item?.title !== 'string' ||
            (item.route !== undefined &&
              (typeof item.route !== 'string' ||
                (item.route !== `/apps/${item.appId}` &&
                  !item.route.startsWith(`/apps/${item.appId}?`)))) ||
            (item.subtitle !== undefined && typeof item.subtitle !== 'string')
          ) {
            console.error(
              '[Phone notifications] Ignored an invalid persisted notification.',
            )
            continue
          }
          stored.push({
            appId: item.appId,
            id: item.id,
            ...(item.route ? { route: item.route } : {}),
            ...(item.subtitle ? { subtitle: item.subtitle } : {}),
            text: item.text,
            title: item.title,
          })
        }
      }
    }

    const merged = new Map<string, PhoneNotification>()
    for (const notification of stored) merged.set(notification.id, notification)
    for (const notification of lockScreenQueues.value[imei] ?? [])
      merged.set(notification.id, notification)
    lockScreenQueues.value[imei] = [...merged.values()].slice(
      -MAX_LOCK_SCREEN_NOTIFICATIONS,
    )
    persist(imei)
  }

  function deactivate(id: string): void {
    const timeout = timeoutHandles.get(id)
    if (timeout) clearTimeout(timeout)
    timeoutHandles.delete(id)
    stopToneHandles.get(id)?.()
    stopToneHandles.delete(id)
  }

  function remember(notification: PhoneNotification): void {
    const imei = notification.device?.imei ?? phone.device?.imei
    if (!imei) return
    lockScreenQueues.value[imei] = [
      ...(lockScreenQueues.value[imei] ?? []),
      notification,
    ].slice(-MAX_LOCK_SCREEN_NOTIFICATIONS)
    persist(imei)
  }

  function activate(notification: PhoneNotification): void {
    const preferences = notification.device?.preferences ?? phone.preferences
    const appPreferences =
      preferences.settings.notifications[notification.appId] ??
      DEFAULT_APP_NOTIFICATION_PREFERENCES
    if (appPreferences.sounds || notification.critical) {
      const alertsMuted =
        preferences.settings.notificationVolume === 0 &&
        preferences.settings.ringtoneVolume === 0
      const selectedSound = preferences.settings.notificationSound
      const customSound = notification.sound
        ? undefined
        : findCustomPhoneTone(
            phone.customTones.notificationSounds,
            selectedSound,
          )
      const volume = notification.critical
        ? preferences.settings.ringtoneVolume
        : preferences.settings.notificationVolume
      stopToneHandles.set(
        notification.id,
        alertsMuted
          ? playPhoneVibration('notification', !!notification.persistent)
          : customSound
            ? playCustomPhoneTone(
                customSound,
                volume,
                !!notification.persistent,
              )
            : playPhoneTone(
                notification.sound ??
                  (isBuiltInNotificationSoundId(selectedSound)
                    ? selectedSound
                    : 'chime'),
                volume,
                !!notification.persistent,
              ),
      )
    }

    if (!notification.persistent) {
      timeoutHandles.set(
        notification.id,
        setTimeout(
          () => dismiss(notification.id),
          preferences.settings.notificationDurationSeconds * 1000,
        ),
      )
    }
  }

  function dismiss(id: string): void {
    const index = queue.value.findIndex(
      (notification) => notification.id === id,
    )
    const deviceIndex = deviceQueue.value.findIndex(
      (notification) => notification.id === id,
    )
    if (index < 0 && deviceIndex < 0) return
    deactivate(id)

    if (index >= 0) {
      const wasCurrent = index === 0
      queue.value.splice(index, 1)
      if (wasCurrent && current.value) activate(current.value)
      return
    }

    const imei = deviceQueue.value[deviceIndex].device?.imei
    const wasDeviceCurrent = !deviceQueue.value
      .slice(0, deviceIndex)
      .some((notification) => notification.device?.imei === imei)
    deviceQueue.value.splice(deviceIndex, 1)
    if (wasDeviceCurrent) {
      const next = deviceQueue.value.find(
        (notification) => notification.device?.imei === imei,
      )
      if (next) activate(next)
    }
  }

  function dismissCurrent(): void {
    if (current.value) dismiss(current.value.id)
  }

  function dismissFromLockScreen(
    id: string,
    targetImei = phone.device?.imei,
  ): void {
    dismiss(id)
    if (!targetImei) return
    const notifications = lockScreenQueues.value[targetImei]
    if (!notifications) return
    const index = notifications.findIndex(
      (notification) => notification.id === id,
    )
    if (index >= 0) notifications.splice(index, 1)
    persist(targetImei)
  }

  function clearLockScreen(): void {
    const imei = phone.device?.imei
    if (!imei) return
    for (const notification of [...(lockScreenQueues.value[imei] ?? [])])
      dismiss(notification.id)
    lockScreenQueues.value[imei] = []
    persist(imei)
  }

  function hideDevicePreview(imei: string): void {
    for (let index = deviceQueue.value.length - 1; index >= 0; index -= 1) {
      const notification = deviceQueue.value[index]
      if (notification.device?.imei !== imei) continue
      deactivate(notification.id)
      deviceQueue.value.splice(index, 1)
    }
  }

  function show(input: PhoneNotificationInput): string | null {
    if (!isPhoneAppId(input.appId)) {
      console.error(`[Phone notifications] Unknown app: ${input.appId}`)
      return null
    }
    const preferences = input.device?.preferences ?? phone.preferences
    const appPreferences =
      preferences.settings.notifications[input.appId] ??
      DEFAULT_APP_NOTIFICATION_PREFERENCES
    if (!input.critical && preferences.settings.focusMode) return null
    if (!input.critical && !appPreferences.enabled) {
      return null
    }
    if (input.critical) {
      const pending = input.device
        ? deviceQueue.value.filter(
            (notification) => notification.device?.imei === input.device?.imei,
          )
        : queue.value
      for (const notification of [...pending]) dismiss(notification.id)
    }
    const notification: PhoneNotification = {
      ...input,
      id: `notification-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`,
    }
    remember(notification)
    if (notification.device) {
      const isFirstForDevice = !deviceQueue.value.some(
        (pending) => pending.device?.imei === notification.device?.imei,
      )
      deviceQueue.value.push(notification)
      if (isFirstForDevice) activate(notification)
    } else {
      queue.value.push(notification)
      if (queue.value.length === 1) activate(notification)
    }
    return notification.id
  }

  return {
    current,
    clearLockScreen,
    devicePreviews,
    dismiss,
    dismissCurrent,
    dismissFromLockScreen,
    hideDevicePreview,
    hydrate,
    isPeeking,
    lockScreenNotifications,
    queue,
    requiresAttention,
    show,
  }
})
