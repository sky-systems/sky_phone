import { describe, expect, it } from 'vitest'
import { clampPage } from './pages'
describe('page clamping', () => {
  it('keeps pages in range', () => {
    expect(clampPage(-4)).toBe(0)
    expect(clampPage(1)).toBe(1)
    expect(clampPage(9)).toBe(2)
  })
})
