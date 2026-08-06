import { computed, ref } from 'vue'
import { defineStore } from 'pinia'

import { usePhoneStore } from '@/stores/phone'
import type { LaunchablePhoneAppId } from '@/types/apps'
import type { PhonePreferencesV1 } from '@/utils/preferences'
import { playPhoneTone, type PhoneToneId } from '@/utils/tones'

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
  sound?: PhoneToneId
  subtitle?: string
  text: string
  title: string
}

export type PhoneNotification = PhoneNotificationInput & {
  id: string
}

const timeoutHandles = new Map<string, ReturnType<typeof setTimeout>>()
const stopToneHandles = new Map<string, () => void>()

export const useNotificationsStore = defineStore('notifications', () => {
  const phone = usePhoneStore()
  const queue = ref<PhoneNotification[]>([])
  const deviceQueue = ref<PhoneNotification[]>([])
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
  const requiresAttention = computed(
    () =>
      !phone.isOpen &&
      (!!current.value?.persistent ||
        devicePreviews.value.some((notification) => notification.persistent)),
  )

  function activate(notification: PhoneNotification): void {
    const preferences = notification.device?.preferences ?? phone.preferences
    const appPreferences =
      preferences.settings.notifications[notification.appId]
    if (appPreferences.sounds || notification.critical) {
      const sound = notification.sound ?? preferences.settings.notificationSound
      const volume = notification.critical
        ? preferences.settings.ringtoneVolume
        : preferences.settings.notificationVolume
      stopToneHandles.set(
        notification.id,
        playPhoneTone(sound, volume, !!notification.persistent),
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
    const timeout = timeoutHandles.get(id)
    if (timeout) clearTimeout(timeout)
    timeoutHandles.delete(id)
    stopToneHandles.get(id)?.()
    stopToneHandles.delete(id)

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

  function show(input: PhoneNotificationInput): string | null {
    const preferences = input.device?.preferences ?? phone.preferences
    const appPreferences = preferences.settings.notifications[input.appId]
    if (!appPreferences) {
      console.error(`[Phone notifications] Unknown app: ${input.appId}`)
      return null
    }
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
    devicePreviews,
    dismiss,
    dismissCurrent,
    isPeeking,
    queue,
    requiresAttention,
    show,
  }
})
