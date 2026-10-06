import { describe, expect, it } from 'vitest'
import { colorLuminance } from '@/utils/colorContrast'
import { customAppStatusBarLight } from '@/utils/customAppStatusBar'

describe('Custom app status-bar contrast', () => {
  it.each([
    ['#94171e', true],
    ['rgb(148, 23, 30)', true],
    ['rgba(148, 23, 30, 1)', true],
    ['#0d0e10', true],
    ['#000', true],
    ['#FFFFFF', false],
    ['#f4f5f7', false],
    ['#fff', false],
    ['rgb(255, 255, 0)', false],
  ])('selects readable icons over %s', (background, light) => {
    expect(customAppStatusBarLight(background)).toBe(light)
  })

  it.each([
    null,
    undefined,
    12,
    {},
    'transparent',
    'rgba(148, 23, 30, 0.4)',
    'rgb(256, 0, 0)',
    'rgb(-1, 0, 0)',
    'rgb(1.2.3, 0, 0)',
    '#12',
    '#12345678',
  ])('does not infer a background from %j', (background) => {
    expect(customAppStatusBarLight(background)).toBeNull()
  })

  it('uses the higher contrast against the actual status icon colors', () => {
    const dark = colorLuminance([17, 17, 17])
    for (let value = 0; value <= 255; value++) {
      const background = colorLuminance([value, value, value])
      const whiteContrast = 1.05 / (background + 0.05)
      const darkContrast = (background + 0.05) / (dark + 0.05)
      const light = customAppStatusBarLight(`rgb(${value}, ${value}, ${value})`)
      expect(light ? whiteContrast : darkContrast).toBeGreaterThanOrEqual(
        light ? darkContrast : whiteContrast,
      )
    }
  })
})
