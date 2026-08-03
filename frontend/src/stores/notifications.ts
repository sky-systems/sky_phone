import { computed, ref } from 'vue'
import { defineStore } from 'pinia'

import { usePhoneStore } from '@/stores/phone'
import type { PhoneAppId } from '@/types/apps'
import { playPhoneTone, type PhoneToneId } from '@/utils/tones'

export type PhoneNotificationInput = {
  appId: PhoneAppId
  critical?: boolean
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
  const current = computed(() => queue.value[0] ?? null)
  const isPeeking = computed(() => !!current.value && !phone.isOpen)
  const requiresAttention = computed(
    () => !!current.value?.persistent && !phone.isOpen,
  )

  function activate(notification: PhoneNotification): void {
    const appPreferences =
      phone.preferences.settings.notifications[notification.appId]
    if (appPreferences.sounds || notification.critical) {
      const sound =
        notification.sound ?? phone.preferences.settings.notificationSound
      const volume = notification.critical
        ? phone.preferences.settings.ringtoneVolume
        : phone.preferences.settings.notificationVolume
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
          phone.preferences.settings.notificationDurationSeconds * 1000,
        ),
      )
    }
  }

  function dismiss(id: string): void {
    const index = queue.value.findIndex((notification) => notification.id === id)
    if (index < 0) return
    const wasCurrent = index === 0
    const timeout = timeoutHandles.get(id)
    if (timeout) clearTimeout(timeout)
    timeoutHandles.delete(id)
    stopToneHandles.get(id)?.()
    stopToneHandles.delete(id)
    queue.value.splice(index, 1)
    if (wasCurrent && current.value) activate(current.value)
  }

  function dismissCurrent(): void {
    if (current.value) dismiss(current.value.id)
  }

  function show(input: PhoneNotificationInput): string | null {
    const appPreferences = phone.preferences.settings.notifications[input.appId]
    if (!appPreferences) {
      console.error(`[Phone notifications] Unknown app: ${input.appId}`)
      return null
    }
    if (!input.critical && !appPreferences.enabled) {
      return null
    }
    if (input.critical) {
      for (const notification of [...queue.value]) dismiss(notification.id)
    }
    const notification: PhoneNotification = {
      ...input,
      id: `notification-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`,
    }
    queue.value.push(notification)
    if (queue.value.length === 1) activate(notification)
    return notification.id
  }

  return {
    current,
    dismiss,
    dismissCurrent,
    isPeeking,
    queue,
    requiresAttention,
    show,
  }
})
