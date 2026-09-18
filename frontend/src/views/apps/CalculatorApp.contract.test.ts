import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

import { describe, expect, it } from 'vitest'

const source = readFileSync(
  fileURLToPath(new URL('./CalculatorApp.vue', import.meta.url)),
  'utf8',
)

describe('CalculatorApp layout contract', () => {
  it('opens in standard mode with circular equal-sized keys', () => {
    expect(source).toContain('const scientificOpened = ref(false)')
    expect(source).toContain('aspect-ratio: 1;')
    expect(source).toContain('border-radius: 50%;')
  })

  it('keeps the compact advanced keys fully rounded', () => {
    expect(source).toMatch(
      /\.calculator-key--scientific\s*{[^}]*border-radius: 999px;/s,
    )
    expect(source).toMatch(
      /\.calculator-key--basic\s*{[^}]*border-radius: 999px;/s,
    )
  })

  it('keeps selected orange operator keys orange instead of white', () => {
    expect(source).toMatch(
      /\.calculator-key--operator\.calculator-key--selected\s*{[^}]*background: linear-gradient\(180deg, #e98700, #c96800\);[^}]*color: #fff;/s,
    )
  })

  it('renders centered icons for every orange operator key', () => {
    for (const icon of ['Divide', 'X', 'Minus', 'Plus', 'Equal']) {
      expect(source).toContain(`icon: ${icon}`)
    }
    expect(source).toContain('class="calculator-key__operator-icon"')
    expect(source).toContain(':aria-label="key.icon ? key.label : undefined"')
    expect(source).toMatch(
      /\.calculator-key__operator-icon\s*{[^}]*width: 24px;[^}]*height: 24px;[^}]*display: block;[^}]*margin: 0;/s,
    )
  })

  it('uses the shared navigation controls in calculation history', () => {
    expect(source).toContain('SkyButton, SkyNavbar, SkySheet')
    expect(source).toContain(
      'calculator-history sky-ui-provider sky-ui-provider--dark',
    )
    expect(source).toContain('class="calculator-history__navbar"')
    expect(source).toContain(
      'grid-template-columns: 106px minmax(0, 1fr) 44px;',
    )
    expect(source).toContain('calculator-history__nav-button--edit')
    expect(source).toContain('calculator-history__nav-button--close')
    expect(source.match(/<SkyButton\s+glass/g)).toHaveLength(2)
    expect(source).toContain('--sky-glass: rgb(44 44 46 / 62%);')
    expect(source).toContain('-webkit-backdrop-filter: none;')
    expect(source).toContain('backdrop-filter: none;')
    expect(source).toContain('min-width: 106px;')
    expect(source).toContain('class="calculator-history__edit-label"')
    expect(source).toContain('position: absolute;')
    expect(source).toContain('inset: 0;')
    expect(source).toContain('place-items: center;')
    expect(source).toContain('padding: 0;')
    expect(source).toMatch(
      /\.calculator-history__nav-button:hover:not\(:disabled\)[^}]*transform: none;[^}]*filter: brightness\(1\.08\);/s,
    )
    expect(source).not.toContain('class="calculator-history__edit"')
    expect(source).not.toContain('class="calculator-history__close"')
  })
})
