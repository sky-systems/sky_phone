import { readFileSync } from 'node:fs'

import { createSSRApp, h } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import SkyPanel from './SkyPanel.vue'

async function renderPanel(
  props: InstanceType<typeof SkyPanel>['$props'],
): Promise<string> {
  return renderToString(
    createSSRApp({
      render: () => h(SkyPanel, props, () => 'Panel content'),
    }),
  )
}

describe('SkyPanel', () => {
  it('renders the complete modal and floating state contract', async () => {
    const html = await renderPanel({
      ariaLabel: 'Right panel',
      floating: true,
      opened: true,
      side: 'right',
    })

    expect(html).toContain(
      'class="sky-panel sky-panel--floating sky-panel--modal"',
    )
    expect(html).toContain('class="sky-overlay-backdrop sky-panel__backdrop"')
    expect(html).toContain('aria-hidden="true"')
    expect(html).toContain('<aside')
    expect(html).toContain('sky-panel__panel--right')
    expect(html).toContain('sky-panel__panel--floating')
    expect(html).toContain('sky-glass-surface')
    expect(html).toContain('role="dialog"')
    expect(html).toContain('aria-label="Right panel"')
    expect(html).toContain('aria-modal="true"')
    expect(html).toContain('tabindex="-1"')
  })

  it('omits closed panels and optional backdrops', async () => {
    expect(await renderPanel({ opened: false })).not.toContain('sky-panel')

    const html = await renderPanel({ backdrop: false, opened: true })
    expect(html).not.toContain('sky-panel__backdrop')
    expect(html).toContain('Panel content')
  })

  it('matches the Konsta iOS surface, geometry, backdrop, and motion', () => {
    const overlays = readFileSync(
      new URL('../overlays.css', import.meta.url),
      'utf8',
    )
    const source = readFileSync(
      new URL('./SkyPanel.vue', import.meta.url),
      'utf8',
    )
    const tokens = readFileSync(
      new URL('../tokens.css', import.meta.url),
      'utf8',
    )
    const panelRule = overlays.match(
      /\n\.sky-panel__panel\s*\{(?<declarations>[^}]*)\}/,
    )?.groups?.declarations

    expect(panelRule).toBeDefined()
    expect(panelRule).toMatch(/top:\s*0;[\s\S]*bottom:\s*0;/)
    expect(panelRule).toMatch(/width:\s*288px;[\s\S]*max-width:\s*100%;/)
    expect(panelRule).toMatch(/overflow:\s*hidden;/)
    expect(overlays).toMatch(
      /\.sky-panel__panel:not\(\.sky-panel__panel--floating\)\s*\{[^}]*background:\s*var\(--sky-panel-background, var\(--sky-surface\)\);/,
    )
    expect(overlays).toMatch(
      /\.sky-panel__panel--floating\s*\{[^}]*top:\s*calc\(var\(--sky-safe-area-top, 0px\) \+ 8px\);[^}]*bottom:\s*calc\(var\(--sky-safe-area-bottom, 0px\) \+ 8px\);[^}]*border-radius:\s*32px;/s,
    )
    expect(overlays).toMatch(
      /\.sky-panel__panel--left\.sky-panel__panel--floating\s*\{[^}]*left:\s*8px;/,
    )
    expect(overlays).toMatch(
      /\.sky-panel__panel--right\.sky-panel__panel--floating\s*\{[^}]*right:\s*8px;/,
    )
    expect(overlays).toMatch(
      /\.sky-panel__backdrop\s*\{[^}]*background:\s*rgba\(0, 0, 0, 0\.5\);/,
    )
    expect(overlays).toMatch(
      /\.sky-panel-left-enter-active[\s\S]*?transition:\s*transform 400ms cubic-bezier\(0\.4, 0, 0\.2, 1\);/,
    )
    expect(overlays).toMatch(
      /\.sky-panel-left-enter-from[\s\S]*?transform:\s*translateX\(-100%\);/,
    )
    expect(overlays).toMatch(
      /\.sky-panel-right-enter-from[\s\S]*?transform:\s*translateX\(100%\);/,
    )
    expect(source).not.toContain(':duration=')
    expect(tokens).toContain('--sky-panel-background: #ffffff;')
    expect(tokens).toContain('--sky-panel-background: #000000;')
    expect(tokens).toContain('--sky-glass: rgba(248, 250, 255, 0.7);')
    expect(tokens).toContain('--sky-glass: rgba(28, 32, 40, 0.72);')
  })

  it('resets every dark Glass override at a nested light theme boundary', () => {
    const tokens = readFileSync(
      new URL('../tokens.css', import.meta.url),
      'utf8',
    )
    const lightTheme = tokens.slice(
      tokens.indexOf('.sky-ui-provider,'),
      tokens.indexOf('.sky-ui-provider--dark,'),
    )

    expect(lightTheme).toContain('--sky-shadow-glass:')
    expect(lightTheme).toContain('--sky-shadow-glass-thumb:')
    expect(lightTheme).toContain('--sky-shadow-glass-thumb-glow:')
    expect(lightTheme).toContain('--sky-glass-thumb-active-background:')
    expect(lightTheme).toContain('--sky-glass-highlight-color:')
  })
})
