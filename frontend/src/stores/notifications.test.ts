import { createPinia, setActivePinia } from 'pinia'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import {
  useNotificationsStore,
  type PhoneNotificationDevice,
} from '@/stores/notifications'
import {
  DEFAULT_PHONE_PREFERENCES,
  type PhonePreferencesV1,
} from '@/utils/preferences'

vi.mock('@/utils/tones', () => ({
  playPhoneTone: vi.fn(() => vi.fn()),
}))
vi.mock('@/utils/nui', () => ({
  nuiCall: vi.fn(),
}))

function device(
  imei: string,
  configure?: (preferences: PhonePreferencesV1) => void,
): PhoneNotificationDevice {
  const preferences = structuredClone(DEFAULT_PHONE_PREFERENCES)
  configure?.(preferences)
  return { imei, name: `Phone ${imei}`, preferences }
}

describe('notifications store', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    vi.stubGlobal('window', {
      matchMedia: vi.fn(() => ({ matches: false })),
    })
    setActivePinia(createPinia())
  })

  afterEach(() => {
    vi.clearAllTimers()
    vi.useRealTimers()
    vi.unstubAllGlobals()
  })

  it('shows one simultaneous preview per notifying phone', () => {
    const notifications = useNotificationsStore()

    notifications.show({
      appId: 'mail',
      device: device('111'),
      text: 'First phone',
      title: 'Mail',
    })
    notifications.show({
      appId: 'mail',
      device: device('222'),
      text: 'Second phone',
      title: 'Mail',
    })

    expect(
      notifications.devicePreviews.map(
        (notification) => notification.device?.imei,
      ),
    ).toEqual(['111', '222'])
  })

  it('queues mail independently for each phone', () => {
    const notifications = useNotificationsStore()
    const target = device('111')
    const firstId = notifications.show({
      appId: 'mail',
      device: target,
      text: 'First message',
      title: 'Mail',
    })
    notifications.show({
      appId: 'mail',
      device: target,
      text: 'Second message',
      title: 'Mail',
    })

    expect(notifications.devicePreviews).toHaveLength(1)
    expect(notifications.devicePreviews[0].text).toBe('First message')

    notifications.dismiss(firstId!)

    expect(notifications.devicePreviews[0].text).toBe('Second message')
  })

  it('uses the target phone notification preferences', () => {
    const notifications = useNotificationsStore()
    const muted = device('111', (preferences) => {
      preferences.settings.notifications.mail.enabled = false
    })

    const id = notifications.show({
      appId: 'mail',
      device: muted,
      text: 'Hidden message',
      title: 'Mail',
    })

    expect(id).toBeNull()
    expect(notifications.devicePreviews).toEqual([])
  })
})
