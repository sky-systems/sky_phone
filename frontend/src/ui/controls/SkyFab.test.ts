import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

import { createSSRApp, h } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import SkyFab from './SkyFab.vue'

describe('SkyFab', () => {
  it('composes the iOS glass layers with native button semantics', async () => {
    const html = await renderToString(
      createSSRApp({
        render: () =>
          h(
            SkyFab,
            { ariaLabel: 'Create', text: 'Create' },
            { icon: () => '+' },
          ),
      }),
    )

    expect(html).toContain('<button')
    expect(html).toContain('type="button"')
    expect(html).toContain('aria-label="Create"')
    expect(html).toContain('sky-glass')
    expect(html).toContain('sky-fab__accent-layer')
    expect(html).toContain('sky-fab__dark-accent-layer')
    expect(html).toContain('sky-fab__surface-layer')
    expect(html).toContain('Create')
  })

  it('keeps every FAB shadow layer on the contextual accent', () => {
    const uiDirectory = fileURLToPath(new URL('..', import.meta.url))
    const controls = readFileSync(`${uiDirectory}/controls.css`, 'utf8')
    const tokens = readFileSync(`${uiDirectory}/tokens.css`, 'utf8')
    const fabStyles = controls.slice(
      controls.indexOf('.sky-glass.sky-fab {'),
      controls.indexOf('.sky-glass {'),
    )
    const fabTokens = tokens.slice(
      tokens.indexOf('--sky-shadow-glass-fab:'),
      tokens.indexOf('--sky-shadow-glass-thumb:'),
    )

    expect(fabStyles).toContain('background: var(--sky-app-accent, #007aff)')
    expect(fabStyles).toMatch(
      /\.sky-fab__surface-layer\s*\{[\s\S]*?var\(--sky-fab-accent-inset-start\) var\(--sky-app-accent, #007aff\)/,
    )
    expect(fabStyles).toMatch(
      /\.sky-fab__dark-accent-layer\s*\{[\s\S]*?inset 0 -5px 5px var\(--sky-app-accent, #007aff\)/,
    )
    expect(fabStyles).not.toContain('--sky-app-accent-shade')
    expect(fabStyles).not.toContain('scale(0.96)')
    expect(fabTokens).toContain('--sky-fab-accent-inset-start')
    expect(fabTokens).not.toContain('rgba(10, 132, 255, 0.25)')
  })

  it('offers a neutral glass variant without accent layers', async () => {
    const html = await renderToString(
      createSSRApp({
        render: () => h(SkyFab, { ariaLabel: 'Create', variant: 'neutral' }),
      }),
    )

    expect(html).toContain('sky-fab--neutral')

    const controls = readFileSync(
      fileURLToPath(new URL('../controls.css', import.meta.url)),
      'utf8',
    )
    expect(controls).toMatch(
      /\.sky-glass\.sky-fab--neutral\s*\{[^}]*background:\s*var\(--sky-glass-solid/s,
    )
  })

  it('offers a translucent glass variant for adjacent floating controls', async () => {
    const html = await renderToString(
      createSSRApp({
        render: () => h(SkyFab, { ariaLabel: 'Create', variant: 'glass' }),
      }),
    )

    expect(html).toContain('sky-fab--glass')

    const controls = readFileSync(
      fileURLToPath(new URL('../controls.css', import.meta.url)),
      'utf8',
    )
    expect(controls).toMatch(
      /\.sky-glass\.sky-fab--glass\s*\{[^}]*border:\s*1px solid var\(--sky-hairline[^}]*background:\s*var\(--sky-glass[^}]*box-shadow:\s*var\(--sky-shadow-glass\)/s,
    )
  })

  it('keeps icon-only fabs perfectly square inside stretching toolbars', () => {
    const controls = readFileSync(
      fileURLToPath(new URL('../controls.css', import.meta.url)),
      'utf8',
    )

    expect(controls).toMatch(
      /\.sky-fab--icon-only\s*\{[^}]*width:\s*var\(--sky-touch-target, 44px\);[^}]*height:\s*var\(--sky-touch-target, 44px\);[^}]*flex:\s*none;[^}]*align-self:\s*center;/s,
    )
  })
})
