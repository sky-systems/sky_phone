import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

import { createSSRApp, h } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import SkyLink from './SkyLink.vue'
import SkyToolbar from './SkyToolbar.vue'
import SkyToolbarPane from './SkyToolbarPane.vue'

describe('SkyToolbar', () => {
  it('renders separate fade layers and glass panes', async () => {
    const html = await renderToString(
      createSSRApp({
        render: () =>
          h(SkyToolbar, { ariaLabel: 'Actions', component: 'nav' }, () => [
            h(SkyToolbarPane, {}, () => 'Link 1'),
            h(SkyToolbarPane, {}, () => 'Link 2'),
          ]),
      }),
    )

    expect(html).toContain('role="toolbar"')
    expect(html).toContain('aria-label="Actions"')
    expect(html).toContain('sky-toolbar__blur')
    expect(html).toContain('sky-toolbar__background')
    expect(html.match(/sky-toolbar-pane/g)).toHaveLength(2)
    expect(html.match(/sky-glass/g)?.length).toBeGreaterThanOrEqual(2)
  })

  it('matches the Konsta iOS pane and background geometry', () => {
    const uiDirectory = fileURLToPath(new URL('..', import.meta.url))
    const controls = readFileSync(`${uiDirectory}/controls.css`, 'utf8')
    const toolbarStyles = controls.slice(
      controls.indexOf('.sky-toolbar {'),
      controls.indexOf('.sky-visually-hidden'),
    )

    expect(toolbarStyles).toMatch(
      /\.sky-toolbar__inner\s*\{[\s\S]*?justify-content: space-between;[\s\S]*?gap: 16px;/,
    )
    expect(toolbarStyles).toMatch(
      /\.sky-toolbar\s*\{[\s\S]*?padding-right: calc\(var\(--sky-safe-area-right, 0px\) \+ 16px\);[\s\S]*?padding-left: calc\(var\(--sky-safe-area-left, 0px\) \+ 16px\);/,
    )
    expect(toolbarStyles).toMatch(
      /\.sky-toolbar-pane\s*\{[\s\S]*?height: 48px;[\s\S]*?border-radius: var\(--sky-radius-pill, 999px\);/,
    )
    expect(toolbarStyles).toMatch(
      /\.sky-toolbar--top \.sky-toolbar__blur,[\s\S]*?\.sky-toolbar--top \.sky-toolbar__background\s*\{\s*display: none;/,
    )
    expect(controls).toMatch(
      /\.sky-toolbar__blur\s*\{[\s\S]*?backdrop-filter: blur\(2px\);[\s\S]*?mask-image: linear-gradient/,
    )
  })

  it('inherits the iOS foreground for Toolbar links without changing generic links', async () => {
    const html = await renderToString(
      createSSRApp({
        render: () =>
          h(SkyToolbar, {}, () =>
            h(SkyToolbarPane, {}, () => h(SkyLink, {}, () => 'Link 1')),
          ),
      }),
    )
    const uiDirectory = fileURLToPath(new URL('..', import.meta.url))
    const controls = readFileSync(`${uiDirectory}/controls.css`, 'utf8')

    expect(html).toContain('class="sky-link"')
    expect(controls).toMatch(
      /\.sky-toolbar \.sky-link\s*\{\s*--sky-button-text: var\(--sky-action-glass-text, #ffffff\);\s*color: var\(--sky-button-text\);\s*background: transparent;\s*\}/,
    )
    expect(controls).toMatch(
      /\.sky-glass\s*\{[^}]*color: var\(--sky-text, #000000\);/s,
    )
    expect(controls).toMatch(/\.sky-link\s*\{[^}]*color: #ffffff;/s)
  })
})
