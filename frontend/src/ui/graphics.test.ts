import { describe, expect, it } from 'vitest'

import { supportsSkyBackdrop, supportsSkyRefraction } from './graphics'

describe('Sky backdrop capability and Cfx compositor boundary', () => {
  it.each([103, 143])(
    'keeps Cfx Chrome %i on the filter-free path even when CSS parses blur',
    (major) => {
      expect(
        supportsSkyBackdrop({
          nui: true,
          supports: () => true,
          userAgent: `Mozilla/5.0 Chrome/${major}.0 Safari/537.36`,
        }),
      ).toBe(false)
    },
  )
  it('enables the tested Cfx 144 path when backdrop-filter is supported', () => {
    expect(
      supportsSkyBackdrop({
        nui: true,
        supports: () => true,
        userAgent: 'Mozilla/5.0 Chrome/144.0.7559.264 Safari/537.36',
      }),
    ).toBe(true)
  })
  it('keeps an unknown Cfx compositor on the safe path', () => {
    expect(
      supportsSkyBackdrop({
        nui: true,
        supports: () => true,
        userAgent: 'Unknown',
      }),
    ).toBe(false)
  })
  it('does not enable effects merely because the browser version is new', () => {
    expect(
      supportsSkyBackdrop({
        nui: true,
        supports: () => false,
        userAgent: 'Chrome/144.0',
      }),
    ).toBe(false)
  })
  it('accepts prefixed CSS support in the browser preview', () => {
    expect(
      supportsSkyBackdrop({
        nui: false,
        supports: (property) => property === '-webkit-backdrop-filter',
        userAgent: 'Browser preview',
      }),
    ).toBe(true)
  })
})

describe('Sky refraction browser boundary', () => {
  it.each(['Chrome/144.0.7559.264', 'HeadlessChrome/149.0'])(
    'recognizes %s for backdrop refraction',
    (userAgent) => {
      expect(
        supportsSkyRefraction({ nui: false, supports: () => true, userAgent }),
      ).toBe(true)
    },
  )
  it.each(['Firefox/144.0', 'Safari/605.1', 'Unknown'])(
    'does not mistake parsed SVG syntax for renderer support in %s',
    (userAgent) => {
      expect(
        supportsSkyRefraction({ nui: false, supports: () => true, userAgent }),
      ).toBe(false)
    },
  )
  it('preserves the Cfx 103 filter-free floor', () => {
    expect(
      supportsSkyRefraction({
        nui: true,
        supports: () => true,
        userAgent: 'Chrome/103.0',
      }),
    ).toBe(false)
  })
})
