import { describe, expect, it } from 'vitest'

import { coverTextureCoordinates } from '@/utils/gameView'

describe('coverTextureCoordinates', () => {
  it('center-crops a widescreen game view for 3:4 portrait output', () => {
    expect(Array.from(coverTextureCoordinates(1920, 1080, 540, 720))).toEqual([
      expect.closeTo(0.29, 2),
      0,
      expect.closeTo(0.71, 2),
      0,
      expect.closeTo(0.29, 2),
      1,
      expect.closeTo(0.71, 2),
      1,
    ])
  })

  it('keeps the full game view for 16:9 landscape output', () => {
    expect(Array.from(coverTextureCoordinates(1920, 1080, 720, 405))).toEqual([
      0, 0, 1, 0, 0, 1, 1, 1,
    ])
  })

  it('keeps the full texture when both aspect ratios match', () => {
    expect(Array.from(coverTextureCoordinates(1600, 900, 800, 450))).toEqual([
      0, 0, 1, 0, 0, 1, 1, 1,
    ])
  })
})
