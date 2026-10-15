import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

import { describe, expect, it } from 'vitest'

const component = readFileSync(
  fileURLToPath(new URL('./SkyDropdown.vue', import.meta.url)),
  'utf8',
)
const overlays = readFileSync(
  fileURLToPath(new URL('../overlays.css', import.meta.url)),
  'utf8',
)

describe('SkyDropdown', () => {
  it('builds the shared dropdown on the positioned SkyPopover primitive', () => {
    expect(component).toContain('<SkyPopover')
    expect(component).toContain('role="menu"')
    expect(component).toContain(':target="target"')
    expect(component).toContain("placement: 'bottom'")
  })

  it('supports checked, submenu, destructive, disabled, and divided items', () => {
    expect(component).toContain("'menuitemradio'")
    expect(component).toContain(':aria-checked=')
    expect(component).toContain("section.group ? 'group' : 'presentation'")
    expect(component).toContain('section.group ? section.label : undefined')
    expect(component).toContain('groupLabel?: string')
    expect(component).toContain(':aria-haspopup=')
    expect(component).toContain('item.destructive')
    expect(component).toContain('item.disabled')
    expect(component).toContain('item.separatorBefore')
    expect(component).toMatch(/<SkyIcon\s+:icon="Check"/)
    expect(component).toMatch(/<SkyIcon\s+:icon="ChevronRight"/)
  })

  it('keeps menu rows touch-friendly with visible interaction feedback', () => {
    expect(overlays).toMatch(
      /\.sky-dropdown__item\s*\{[^}]*min-height:\s*var\(--sky-touch-target, 44px\)/s,
    )
    expect(overlays).toMatch(/\.sky-dropdown__menu\s*\{[^}]*padding:\s*6px;/s)
    expect(overlays).toMatch(
      /\.sky-dropdown__item\s*\{[^}]*border-radius:\s*12px;/s,
    )
    expect(overlays).toContain('.sky-dropdown__item:hover')
    expect(overlays).toContain(
      'box-shadow: inset 0 0 0 1px var(--sky-hairline);',
    )
    expect(overlays).toContain('.sky-dropdown__item:focus-visible')
    expect(overlays).toContain('.sky-dropdown__item:active')
    expect(overlays).toContain('background: var(--sky-pressed);')
  })

  it('uses a readable solid fallback with progressive glass enhancement', () => {
    expect(overlays).toMatch(
      /\.sky-dropdown \.sky-popover__panel\s*\{[^}]*background:\s*var\(--sky-glass-solid, var\(--sky-surface\)\)/s,
    )
    expect(overlays).toMatch(
      /@supports[\s\S]*?\.sky-dropdown \.sky-popover__panel\s*\{[^}]*var\(--sky-glass\)[^}]*backdrop-filter:\s*blur\(16px\)/s,
    )
    expect(overlays).toContain('border: 1px solid var(--sky-hairline);')
  })
})
