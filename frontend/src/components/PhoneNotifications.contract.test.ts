import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(
  new URL('./PhoneNotifications.vue', import.meta.url),
  'utf8',
)
const previewSource = readFileSync(
  new URL('./NotificationPhonePreview.vue', import.meta.url),
  'utf8',
)
const styles = readFileSync(
  new URL('../assets/main.css', import.meta.url),
  'utf8',
)

describe('Phone popup notification contract', () => {
  it('uses the shared Sky popup for every central phone notification', () => {
    expect(source).not.toContain("from 'konsta/vue'")
    expect(source).toContain(
      "import { SkyNotification, SkyProvider } from '@/ui'",
    )
    expect(source).toContain('<SkyProvider')
    expect(source).toContain('<SkyNotification')
    expect(source).toContain(':title="presentation?.title"')
    expect(source).toContain(':text="presentation?.text"')
    expect(source).toContain('presentPhoneNotification(')
    expect(source).toContain('props.locked !== false')
    expect(source).toContain(':title-right-text="notificationTime"')
    expect(previewSource).toContain(':dark="isDarkMode"')
  })

  it('shows the app icon and opens routed notifications accessibly', () => {
    expect(source).toContain('getPhoneApp(props.notification.appId)?.iconImage')
    expect(source).toContain('class="phone-notification__icon"')
    expect(source).toContain('class="phone-notification__open"')
    expect(source).toContain(':aria-label="phone.t(\'Notifications.open\')"')
    expect(source).toContain('@keydown.esc.stop="emit(\'close\')"')
  })

  it('supports an upward dismiss gesture without a visible close button', () => {
    expect(source).toContain('@pointerdown="beginDismissGesture"')
    expect(source).toContain('@pointermove="moveDismissGesture"')
    expect(source).toContain('pointerOffset <= -28')
    expect(source).toContain('velocityY <= -0.3')
    expect(source).not.toContain('button="close"')
    expect(source).not.toContain('<template #button>')
  })

  it('matches the compact popup placement and light/dark material', () => {
    expect(styles).toMatch(
      /\.phone-notification-provider\s*\{[^}]*--phone-notification-background:\s*rgb\(247 247 248 \/ 94%\);[^}]*position:\s*absolute;[^}]*pointer-events:\s*none;/s,
    )
    expect(styles).toMatch(
      /\.phone-notification-provider\.sky-ui-provider--dark\s*\{[^}]*--phone-notification-background:\s*rgb\(36 36 39 \/ 94%\);/s,
    )
    expect(styles).toMatch(
      /\.phone-notification\s*\{[^}]*top:\s*51px !important;[^}]*right:\s*10px !important;[^}]*left:\s*10px !important;[^}]*transform:\s*translate3d\(0, var\(--phone-notification-drag-y\), 0\);/s,
    )
    expect(styles).toMatch(
      /\.phone-notification__icon\s*\{[^}]*width:\s*38px;[^}]*height:\s*38px;[^}]*border-radius:\s*10px;/s,
    )
  })
})
