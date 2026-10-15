import { describe, expect, it } from 'vitest'
import { getPhoneApp, getPhoneAppLabel } from '@/config/apps'
import type { PhoneNotificationInput } from '@/stores/notifications'
import { presentPhoneNotification } from './notificationPresentation'

const message: PhoneNotificationInput = {
  appId: 'messages',
  title: 'Messages',
  subtitle: 'Alex Rivera',
  text: 'Meet us at the observatory after sunset.',
}
const translate = (key: string): string => {
  const labels: Record<string, string> = {
    [getPhoneAppLabel(getPhoneApp('messages')!, (labelKey) => labelKey)]:
      'Messages',
    'Notifications.preview.message': 'Text message',
    'Notifications.preview.notification': 'Notification',
    'Notifications.preview.invoice': 'New invoice',
  }
  return labels[key] ?? key
}

describe('notification privacy and labels', () => {
  it('redacts sender, title and content while locked', () => {
    expect(presentPhoneNotification(message, true, translate)).toEqual({
      title: 'Messages',
      text: 'Text message',
    })
    expect(
      presentPhoneNotification(
        { ...message, title: 'Private sender' },
        true,
        translate,
      ),
    ).toEqual({
      title: 'Messages',
      text: 'Text message',
    })
  })

  it('shows the sender and content without a redundant app name after unlocking', () => {
    expect(presentPhoneNotification(message, false, translate)).toEqual({
      title: 'Alex Rivera',
      subtitle: undefined,
      text: message.text,
    })
  })

  it('preserves meaningful app-specific titles and subtitles', () => {
    expect(
      presentPhoneNotification(
        {
          ...message,
          title: 'Repair accepted',
          subtitle: 'Los Santos Customs',
        },
        false,
        translate,
      ),
    ).toEqual({
      title: 'Repair accepted',
      subtitle: 'Los Santos Customs',
      text: message.text,
    })
  })

  it('omits an app title when there is no sender instead of repeating it', () => {
    expect(
      presentPhoneNotification(
        { ...message, subtitle: undefined },
        false,
        translate,
      ).title,
    ).toBe('')
  })

  it('uses app-specific safe hints and a generic hint for other apps', () => {
    expect(
      presentPhoneNotification(
        { ...message, appId: 'billing' },
        true,
        translate,
      ).text,
    ).toBe('New invoice')
    expect(
      presentPhoneNotification(
        { ...message, appId: 'weather' },
        true,
        translate,
      ).text,
    ).toBe('Notification')
  })
})
