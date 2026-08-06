import { describe, expect, it } from 'vitest'
import { clampPage, paginateItems } from './pages'
describe('page clamping', () => {
  it('keeps pages in range', () => {
    expect(clampPage(-4)).toBe(0)
    expect(clampPage(1)).toBe(1)
    expect(clampPage(9)).toBe(2)
  })

  it('splits overflowing app grids into additional pages', () => {
    expect(
      paginateItems(
        Array.from({ length: 21 }, (_, index) => index),
        16,
      ),
    ).toEqual([
      Array.from({ length: 16 }, (_, index) => index),
      [16, 17, 18, 19, 20],
    ])
  })
})
