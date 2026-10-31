import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(
  new URL('./SkyExtensionsDemo.vue', import.meta.url),
  'utf8',
)
const demoPageSource = readFileSync(
  new URL('../SkyUiDemoPage.vue', import.meta.url),
  'utf8',
)

describe('SkyExtensionsDemo', () => {
  it('opts into the shared padded scroll contract without changing Konsta demos', () => {
    expect(demoPageSource).toContain('padded?: boolean')
    expect(demoPageSource).toContain('padded: false')
    expect(demoPageSource).toContain(':padded="padded"')
    expect(source).toContain('<SkyUiDemoPage padded title="Sky Extensions">')
  })

  it('keeps extension cards and states inside one coherent inset layout', () => {
    expect(source).toContain('class="sky-ui-demo-extension-empty"')
    expect(source).toMatch(/<SkyEmptyState[\s\S]*?\scompact[\s\S]*?>/)
    expect(source).toMatch(
      /\.sky-ui-demo-extension-status,\s*\.sky-ui-demo-extension-card,\s*\.sky-ui-demo-extension-empty\s*\{\s*margin:\s*0;/,
    )
    expect(source.match(/\sinline\s/g)).toHaveLength(3)
    expect(source.match(/:aria-pressed="loaderState ===/g)).toHaveLength(3)
    expect(source).toContain(':has-more="loaderState !== \'ready\'"')
    expect(source).toMatch(
      /\.sky-ui-demo-extension-state-actions\s*\{[\s\S]*?display:\s*flex;[\s\S]*?flex-wrap:\s*wrap;/,
    )
  })

  it('presents nested themes, widgets, and interactive Glass as bounded specimens', () => {
    expect(source).toMatch(
      /\.sky-ui-demo-extension-app\s*\{[\s\S]*?border:\s*1px solid var\(--sky-hairline\);[\s\S]*?border-radius:\s*var\(--sky-radius-card\);/,
    )
    expect(source).toMatch(
      /\.sky-ui-demo-extension-widgets\s*\{[\s\S]*?--sky-widget-label-color:\s*var\(--sky-text\);[\s\S]*?grid-template-columns:\s*repeat\(2, minmax\(0, 1fr\)\);/,
    )
    expect(source).toMatch(
      /\.sky-ui-demo-extension-widgets > :nth-child\(3\)\s*\{[\s\S]*?grid-column:\s*1 \/ -1;/,
    )
    expect(source).toMatch(
      /\.sky-ui-demo-extension-widget\s*\{[\s\S]*?height:\s*100%;[\s\S]*?min-height:\s*0;/,
    )
    expect(source).toMatch(
      /\.sky-ui-demo-extension-glass\s*\{[\s\S]*?width:\s*100%;[\s\S]*?border-radius:\s*var\(--sky-radius-pill\);/,
    )
    expect(source).toMatch(
      /\.sky-ui-demo-extension-glass:focus-visible\s*\{[\s\S]*?outline:\s*2px solid var\(--sky-app-accent\);/,
    )
  })

  it('uses icon-and-label full navigation and compact text-only variants', () => {
    expect(source).toContain("{ icon: LayoutGrid, label: 'Apps' }")
    expect(source).toContain("{ icon: Gamepad2, label: 'Games' }")
    expect(source).toContain("{ icon: Search, label: 'Search' }")
    expect(source).toContain('class="sky-ui-demo-extension-navigation-item"')
    expect(source.match(/^\s+compact\s*$/gm)).toHaveLength(4)
    expect(source).toContain(':strong="splitTab < 2"')
    expect(source).toContain(':strong="splitTab === 2"')
  })
})
