import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const frame = readFileSync(
  new URL('./CustomAppFrame.vue', import.meta.url),
  'utf8',
)
const appTypes = readFileSync(
  new URL('../types/apps.ts', import.meta.url),
  'utf8',
)

describe('Custom app frame context permissions', () => {
  it('only exposes locale and theme context when their capabilities are granted', () => {
    expect(frame).toContain("capabilities.includes('theme.read')")
    expect(frame).toContain("capabilities.includes('locale.read')")
    expect(frame).toMatch(
      /capabilities\.includes\('theme\.read'\)[\s\S]*colorScheme/,
    )
    expect(frame).toMatch(
      /capabilities\.includes\('locale\.read'\)[\s\S]*language:[\s\S]*locale:/,
    )
    expect(appTypes).toContain("colorScheme?: 'dark' | 'light'")
    expect(appTypes).toContain('language?: string')
    expect(appTypes).toContain('locale?: Record<string, unknown>')
  })
})
