import { getPhoneApp, getPhoneAppLabel } from '@/config/apps'
import type { PhoneNotificationInput } from '@/stores/notifications'

const LOCKED_PREVIEW_TYPES: Record<string, string> = {
  messages: 'message',
  darkchat: 'message',
  mail: 'mail',
  phone: 'call',
  billing: 'invoice',
  companies: 'company',
  calendar: 'event',
}

export function presentPhoneNotification(
  notification: PhoneNotificationInput,
  locked: boolean,
  translate: (key: string) => string,
): { title: string; subtitle?: string; text: string } {
  const app = getPhoneApp(notification.appId)
  const appName = app ? getPhoneAppLabel(app, translate) : ''
  if (locked) {
    return {
      title: appName,
      text: translate(
        `Notifications.preview.${LOCKED_PREVIEW_TYPES[notification.appId] ?? 'notification'}`,
      ),
    }
  }

  const isAppName = (text: string | undefined): boolean => {
    const normalized = text?.trim().toLocaleLowerCase()
    return (
      !!normalized &&
      (normalized === appName.toLocaleLowerCase() ||
        normalized === notification.appId.toLocaleLowerCase())
    )
  }
  const title = isAppName(notification.title)
    ? (notification.subtitle ?? '')
    : notification.title
  const subtitle =
    notification.subtitle !== title && !isAppName(notification.subtitle)
      ? notification.subtitle
      : undefined
  return { title, subtitle, text: notification.text }
}
