import { readFileSync } from 'node:fs'

import { createSSRApp, h } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import SkyNotification from './SkyNotification.vue'

async function renderNotification(
  props: InstanceType<typeof SkyNotification>['$props'],
): Promise<string> {
  return renderToString(
    createSSRApp({
      render: () =>
        h(SkyNotification, props, {
          button: () => [],
          icon: () => h('img', { alt: '', src: '/demo-icon.png' }),
        }),
    }),
  )
}

describe('SkyNotification', () => {
  it('renders the complete Sky popup notification structure', async () => {
    const html = await renderNotification({
      button: 'Close notification',
      opened: true,
      subtitle: 'Notification with close button',
      text: 'Click (x) button to close me',
      title: 'Sky Phone',
      titleRightText: 'now',
    })

    expect(html).toContain('<section')
    expect(html).toMatch(
      /class="sky-notification sky-glass-surface(?: sky-glass)?"/,
    )
    expect(html).toContain('role="status"')
    expect(html).toContain('aria-live="polite"')
    expect(html).toContain('sky-notification__header--with-close')
    expect(html).toContain('sky-notification__close-icon')
    expect(html).toContain('viewbox="0 0 28 28"')
    expect(html).toContain('aria-label="Close notification"')
    expect(html).not.toContain('>Close notification<')
    expect(html).not.toContain('&times;')
  })

  it('keeps closed notifications out of the accessibility tree', async () => {
    const html = await renderNotification({ opened: false, title: 'Hidden' })

    expect(html).not.toContain('sky-notification')
    expect(html).not.toContain('Hidden')
  })

  it('locks the compact popup glass, typography, and close geometry', () => {
    const overlays = readFileSync(
      new URL('../overlays.css', import.meta.url),
      'utf8',
    )
    const tokens = readFileSync(
      new URL('../tokens.css', import.meta.url),
      'utf8',
    )
    const notificationRule = overlays.match(
      /\.sky-notification\s*\{([^}]*)\}/,
    )?.[1]

    expect(notificationRule).toBeDefined()
    expect(notificationRule).toMatch(/z-index:\s*50;/)
    expect(notificationRule).toMatch(
      /top:\s*calc\(var\(--sky-safe-area-top, 0px\) \+ 6px\);/,
    )
    expect(notificationRule).toMatch(/right:\s*10px;[\s\S]*left:\s*10px;/)
    expect(notificationRule).toMatch(/min-height:\s*72px;/)
    expect(notificationRule).toMatch(/gap:\s*10px;[\s\S]*padding:\s*10px 12px;/)
    expect(notificationRule).toMatch(
      /border:\s*1px solid var\(--sky-hairline\);[\s\S]*border-radius:\s*18px;/,
    )
    expect(notificationRule).not.toMatch(/background:/)
    expect(overlays).toMatch(
      /\.sky-notification__title,[\s\S]*?font-size:\s*12px;[\s\S]*?line-height:\s*16px;/,
    )
    expect(overlays).toMatch(
      /\.sky-notification__title\s*\{[\s\S]*?font-size:\s*13px;[\s\S]*?text-overflow:\s*ellipsis;/,
    )
    expect(overlays).toMatch(
      /\.sky-notification__time\s*\{[\s\S]*?margin-inline-start:\s*auto;[\s\S]*?margin-inline-end:\s*0;[\s\S]*?color:\s*var\(--sky-notification-meta\);/,
    )
    expect(overlays).toMatch(
      /\.sky-notification__close\s*\{[\s\S]*?width:\s*var\(--sky-touch-target, 44px\);[\s\S]*?height:\s*var\(--sky-touch-target, 44px\);[\s\S]*?position:\s*absolute;[\s\S]*?right:\s*-8px;/,
    )
    expect(overlays).toMatch(
      /\.sky-notification__close-icon\s*\{\s*width:\s*20px;\s*height:\s*20px;/,
    )
    expect(overlays).toMatch(
      /\.sky-notification-slide-enter-from,[\s\S]*?transform:\s*translateY\(-32px\) scale\(0\.97\);/,
    )
    expect(tokens).toContain('--sky-notification-meta: rgba(0, 0, 0, 0.45)')
    expect(tokens).toContain(
      '--sky-notification-meta: rgba(255, 255, 255, 0.45)',
    )
    expect(tokens).toContain('--sky-notification-close: #a8a29e')
    expect(tokens).toContain('--sky-notification-close-active: #e7e5e4')
    expect(tokens).toContain('--sky-notification-close: #78716c')
    expect(tokens).toContain('--sky-notification-close-active: #44403c')
  })
})
