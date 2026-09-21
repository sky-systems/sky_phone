import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(
  new URL('./SidePanelsDemo.vue', import.meta.url),
  'utf8',
)

describe('SidePanelsDemo Konsta parity', () => {
  it('keeps all four reference panel variants', () => {
    expect(source).toContain("id: 'left', side: 'left'")
    expect(source).toContain("id: 'right', side: 'right'")
    expect(source).toContain("id: 'leftFloating', side: 'left'")
    expect(source).toContain("id: 'rightFloating', side: 'right'")
  })

  it('carries the selected theme and accent into every nested panel page', () => {
    expect(source).toContain('<SkyAppPage')
    expect(source).toContain('component="div"')
    expect(source).toContain(':dark="demo.dark.value"')
    expect(source).toContain(':accent="demo.accent.value"')
    expect(source).toContain(':accent-soft="demo.accentSoft.value"')
    expect(source).toContain(':label="panel.title"')
  })

  it('keeps a 20px close icon, floating transparency, and 16px rhythm', () => {
    expect(source).toContain('<SkyIcon :size="20"><X /></SkyIcon>')
    expect(source).toContain('--sky-safe-area-top: 0px;')
    expect(source).toContain('--sky-safe-area-bottom: 0px;')
    expect(source).toMatch(
      /\.sky-ui-demo-panel-page--floating :deep\(\.sky-app-page__backdrop\)[\s\S]*?background:\s*transparent;/,
    )
    expect(source.match(/gap:\s*var\(--sky-space-4\);/g)).toHaveLength(2)
  })
})
