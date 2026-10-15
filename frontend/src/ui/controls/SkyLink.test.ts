import { readFileSync } from 'node:fs'

import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import SkyLink from './SkyLink.vue'

describe('SkyLink', () => {
  it('renders actions as native keyboard-operable buttons', async () => {
    const html = await renderToString(createSSRApp(SkyLink))

    expect(html).toMatch(/^<button[^>]*class="sky-link"/)
    expect(html).toContain('type="button"')
    expect(html).not.toContain('role="link"')
  })

  it('keeps intrinsic visible geometry with an invisible 44px hit target', () => {
    const controls = readFileSync(
      new URL('../controls.css', import.meta.url),
      'utf8',
    )

    expect(controls).toMatch(
      /\.sky-link\s*\{[^}]*min-width:\s*0;[^}]*min-height:\s*0;[^}]*gap:\s*var\(--sky-space-1, 4px\);[^}]*padding:\s*0;[^}]*border:[^}]*border-radius:\s*0;[^}]*background:\s*transparent;/s,
    )
    expect(controls).toMatch(
      /\.sky-link::before\s*\{[^}]*width:\s*max\(100%, var\(--sky-touch-target, 44px\)\);[^}]*height:\s*max\(100%, var\(--sky-touch-target, 44px\)\)/s,
    )
    expect(controls).toMatch(
      /\.sky-link:active:not\(:disabled\)\s*\{[^}]*opacity:\s*0\.5;/s,
    )
    expect(controls).not.toMatch(
      /\.sky-link:active:not\(:disabled\)\s*\{[^}]*background:/s,
    )
  })

  it('preserves genuine navigation links and disables them safely', async () => {
    const link = await renderToString(
      createSSRApp(SkyLink, { href: '/details' }),
    )
    const disabled = await renderToString(
      createSSRApp(SkyLink, { href: '/details', disabled: true }),
    )
    expect(link).toMatch(/^<a/)
    expect(link).toContain('href="/details"')
    expect(disabled).toContain('aria-disabled="true"')
    expect(disabled).toContain('tabindex="-1"')
    expect(disabled).not.toContain('href=')
  })
})
