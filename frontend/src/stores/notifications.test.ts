import { createPinia, setActivePinia } from 'pinia'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import {
  MAX_LOCK_SCREEN_NOTIFICATIONS,
  useNotificationsStore,
  type PhoneNotificationDevice,
} from '@/stores/notifications'
import { usePhoneStore } from '@/stores/phone'
import { getPhoneApp, replaceExternalPhoneApps } from '@/config/apps'
import { normalizeExternalPhoneApp } from '@/stores/app-catalog'
import { nuiCall } from '@/utils/nui'
import {
  DEFAULT_PHONE_PREFERENCES,
  type PhonePreferencesV1,
} from '@/utils/preferences'
import { playPhoneVibration } from '@/utils/tones'

vi.mock('@/utils/tones', () => ({
  playPhoneTone: vi.fn(() => vi.fn()),
  playPhoneVibration: vi.fn(() => vi.fn()),
}))
vi.mock('@/utils/nui', () => ({
  nuiCall: vi.fn(async () => ({ success: true, data: { revision: 1 } })),
}))

function device(
  imei: string,
  configure?: (preferences: PhonePreferencesV1) => void,
): PhoneNotificationDevice {
  const preferences = structuredClone(DEFAULT_PHONE_PREFERENCES)
  configure?.(preferences)
  return { imei, name: `Phone ${imei}`, preferences }
}

function openPhone(imei: string): void {
  usePhoneStore().open({
    device: {
      data: {},
      imei,
      name: `Phone ${imei}`,
      sim: null,
    },
  })
}

describe('notifications store', () => {
  it('retains active-app notification history while suppressing ordinary banners', () => {
    const app = normalizeExternalPhoneApp({
      id: 'external-chat',
      name: 'Chat',
      ownerResource: 'example',
      ui: 'https://cfx-nui-example/ui/index.html',
      icon: 'https://cfx-nui-example/ui/icon.png',
      store: { disableInAppNotifications: true },
    })!
    replaceExternalPhoneApps([app])
    try {
      openPhone('111')
      const phone = usePhoneStore()
      phone.activeCustomAppId = app.id
      const notifications = useNotificationsStore()
      const input = {
        appId: getPhoneApp(app.id)!.id,
        title: 'Chat',
        text: 'Message',
      }
      expect(notifications.show(input)).toBeTruthy()
      expect(notifications.current).toBeNull()
      expect(notifications.lockScreenNotifications).toHaveLength(1)
      expect(notifications.show({ ...input, critical: true })).toBeTruthy()
      expect(notifications.current?.critical).toBe(true)
    } finally {
      replaceExternalPhoneApps([])
    }
  })
  beforeEach(() => {
    vi.useFakeTimers()
    vi.stubGlobal('window', {
      matchMedia: vi.fn(() => ({ matches: false })),
    })
    setActivePinia(createPinia())
    vi.mocked(nuiCall).mockClear()
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

  it('plays a vibration alert for push notifications while globally muted', () => {
    const notifications = useNotificationsStore()
    const muted = device('111', (preferences) => {
      preferences.settings.notificationVolume = 0
      preferences.settings.ringtoneVolume = 0
    })

    notifications.show({
      appId: 'messages',
      device: muted,
      text: 'Muted message',
      title: 'Messages',
    })

    expect(playPhoneVibration).toHaveBeenCalledWith('notification', false)
  })

  it('suppresses normal notifications during Focus but keeps critical alerts', () => {
    const phone = usePhoneStore()
    const notifications = useNotificationsStore()
    phone.preferences.settings.focusMode = true

    const normalId = notifications.show({
      appId: 'mail',
      text: 'Quiet message',
      title: 'Mail',
    })
    const criticalId = notifications.show({
      appId: 'clock',
      critical: true,
      text: 'Timer finished',
      title: 'Clock',
    })

    expect(normalId).toBeNull()
    expect(criticalId).not.toBeNull()
    expect(notifications.current?.text).toBe('Timer finished')
  })

  it('persists a notification immediately while the phone is closed', async () => {
    const notifications = useNotificationsStore()

    notifications.show({
      appId: 'companies',
      device: device('111'),
      route: '/apps/companies?requestId=request-1&area=customer',
      text: 'Store while closed',
      title: 'Companies',
    })
    await Promise.resolve()
    await Promise.resolve()

    expect(nuiCall).toHaveBeenCalledWith('notifications:save', {
      imei: '111',
      payload: {
        items: [
          expect.objectContaining({
            appId: 'companies',
            route: '/apps/companies?requestId=request-1&area=customer',
            text: 'Store while closed',
            title: 'Companies',
          }),
        ],
        version: 1,
      },
    })
  })

  it('keeps notifications on the lock screen after the banner expires', () => {
    openPhone('111')
    const notifications = useNotificationsStore()

    notifications.show({
      appId: 'mail',
      text: 'Persistent lock screen message',
      title: 'Mail',
    })
    vi.advanceTimersByTime(
      DEFAULT_PHONE_PREFERENCES.settings.notificationDurationSeconds * 1000,
    )

    expect(notifications.current).toBeNull()
    expect(notifications.lockScreenNotifications[0].text).toBe(
      'Persistent lock screen message',
    )
  })

  it('hides the matching device preview when that phone opens', () => {
    const notifications = useNotificationsStore()
    notifications.show({
      appId: 'mail',
      device: device('111'),
      text: 'Move to lock screen',
      title: 'Mail',
    })

    openPhone('111')
    notifications.hideDevicePreview('111')

    expect(notifications.devicePreviews).toEqual([])
    expect(notifications.lockScreenNotifications[0].text).toBe(
      'Move to lock screen',
    )
  })

  it('dismisses a lock screen notification everywhere', () => {
    openPhone('111')
    const notifications = useNotificationsStore()
    const id = notifications.show({
      appId: 'mail',
      text: 'Dismiss me',
      title: 'Mail',
    })

    notifications.dismissFromLockScreen(id!)

    expect(notifications.current).toBeNull()
    expect(notifications.lockScreenNotifications).toEqual([])
  })

  it('hydrates persisted notifications and only removes them explicitly', () => {
    const phone = usePhoneStore()
    phone.open({
      device: {
        data: {
          notifications: {
            payload: {
              items: [
                {
                  appId: 'mail',
                  id: 'saved-notification',
                  text: 'Saved message',
                  title: 'Mail',
                },
              ],
              version: 1,
            },
            revision: 3,
          },
        },
        imei: '111',
        name: 'Phone 111',
        sim: null,
      },
    })
    const notifications = useNotificationsStore()

    notifications.hydrate(phone.device?.data.notifications?.payload, '111')
    vi.advanceTimersByTime(60_000)

    expect(notifications.lockScreenNotifications[0].text).toBe('Saved message')
    notifications.clearLockScreen()
    expect(notifications.lockScreenNotifications).toEqual([])
  })

  it('bounds persisted lock screen history to the newest notifications', () => {
    openPhone('111')
    const notifications = useNotificationsStore()
    const items = Array.from(
      { length: MAX_LOCK_SCREEN_NOTIFICATIONS + 10 },
      (_, index) => ({
        appId: 'mail' as const,
        id: `saved-${index}`,
        text: `Message ${index}`,
        title: 'Mail',
      }),
    )

    notifications.hydrate({ items, version: 1 }, '111')

    expect(notifications.lockScreenNotifications).toHaveLength(
      MAX_LOCK_SCREEN_NOTIFICATIONS,
    )
    expect(notifications.lockScreenNotifications[0]?.id).toBe('saved-59')
    expect(notifications.lockScreenNotifications.at(-1)?.id).toBe('saved-10')
  })
})
