import { Check } from 'lucide-vue-next'
import { createSSRApp, h } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import SkyIcon from './SkyIcon.vue'

describe('SkyIcon', () => {
  it('preserves the HTML slot wrapper, explicit dimensions and colored badge', async () => {
    const html = await renderToString(
      createSSRApp({
        render: () =>
          h(
            SkyIcon,
            {
              badge: 5,
              badgeColors: { bg: '#ef4444', text: '#ffffff' },
              size: 28,
            },
            { default: () => h('svg') },
          ),
      }),
    )
    expect(html).toMatch(/^<i/)
    expect(html).toContain('height:28px')
    expect(html).toContain('width:28px')
    expect(html).toContain('aria-hidden="true"')
    expect(html).toContain('background:#ef4444')
    expect(html).toContain('color:#ffffff')
    expect(html).toMatch(/sky-icon__badge[\s\S]*?5[\s\S]*?<\/span>/)
  })
  it('preserves a labeled custom component and badge slot', async () => {
    const html = await renderToString(
      createSSRApp({
        render: () =>
          h(
            SkyIcon,
            {
              component: 'span',
              label: 'Inbox',
            },
            { default: () => h('svg'), badge: () => 'NEW' },
          ),
      }),
    )
    expect(html).toMatch(/^<span/)
    expect(html).toContain('aria-label="Inbox"')
    expect(html).toContain('role="img"')
    expect(html).not.toContain('aria-hidden="true"')
    expect(html).toMatch(/sky-icon__badge[\s\S]*?NEW[\s\S]*?<\/span>/)
  })
  it('renders a Lucide SVG directly and preserves its classes, stroke and decorative semantics', async () => {
    const html = await renderToString(
      createSSRApp({
        render: () =>
          h(SkyIcon, { icon: Check, class: 'action-icon', 'stroke-width': 3 }),
      }),
    )
    expect(html).toMatch(/^<svg/)
    expect(html).toContain('sky-icon')
    expect(html).toContain('action-icon')
    expect(html).toContain('stroke-width="3"')
    expect(html).toContain('aria-hidden="true"')
    expect(html).toContain('width="20"')
    expect(html).not.toContain('width:')
  })
  it('preserves accessible labeled icons and explicit sizes', async () => {
    const html = await renderToString(
      createSSRApp({
        render: () => h(SkyIcon, { icon: Check, label: 'Selected', size: 24 }),
      }),
    )
    expect(html).toContain('role="img"')
    expect(html).toContain('aria-label="Selected"')
    expect(html).toContain('width:24px')
    expect(html).not.toContain('aria-hidden="true"')
  })
  it('keeps HTML badges outside the SVG', async () => {
    const html = await renderToString(
      createSSRApp({ render: () => h(SkyIcon, { icon: Check, badge: 2 }) }),
    )
    expect(html).toMatch(/^<i/)
    expect(html).toContain('</svg>')
    expect(html.indexOf('sky-icon__badge')).toBeGreaterThan(
      html.indexOf('</svg>'),
    )
  })
  it('uses source SVG assets as a colored mask while preserving accessible labels', async () => {
    const html = await renderToString(
      createSSRApp({
        render: () =>
          h(SkyIcon, {
            src: '/assets/lock-open.svg',
            label: 'Unlocked',
            size: 14,
          }),
      }),
    )
    expect(html).toContain('sky-icon--image')
    expect(html).toContain('--sky-icon-source:url(')
    expect(html).toContain('/assets/lock-open.svg')
    expect(html).toContain('width:14px')
    expect(html).toContain('role="img"')
    expect(html).toContain('aria-label="Unlocked"')
  })
})
