import { describe, expect, it } from 'vitest'

import { gameViewGeometry } from '@/utils/gameView'

describe('gameViewGeometry', () => {
  it('center-crops a widescreen game view for 3:4 portrait output', () => {
    const geometry = gameViewGeometry(1920, 1080, 540, 720)
    expect(Array.from(geometry.textureCoordinates)).toEqual([
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
    const geometry = gameViewGeometry(1920, 1080, 720, 405)
    expect(Array.from(geometry.textureCoordinates)).toEqual([
      0, 0, 1, 0, 0, 1, 1, 1,
    ])
  })

  it('keeps the full texture when both aspect ratios match', () => {
    const geometry = gameViewGeometry(1600, 900, 800, 450)
    expect(Array.from(geometry.textureCoordinates)).toEqual([
      0, 0, 1, 0, 0, 1, 1, 1,
    ])
  })

  it('keeps 0.5x full-frame while higher zoom levels crop around the center', () => {
    const wideGeometry = gameViewGeometry(1920, 1080, 540, 720, 0.5)
    expect(Array.from(wideGeometry.textureCoordinates)).toEqual([
      expect.closeTo(0.29, 2),
      0,
      expect.closeTo(0.71, 2),
      0,
      expect.closeTo(0.29, 2),
      1,
      expect.closeTo(0.71, 2),
      1,
    ])
    expect(Array.from(wideGeometry.positions)).toEqual([
      -1, -1, 1, -1, -1, 1, 1, 1,
    ])

    const zoomedGeometry = gameViewGeometry(1920, 1080, 540, 720, 2)
    expect(Array.from(zoomedGeometry.textureCoordinates)).toEqual([
      expect.closeTo(0.39, 2),
      0.25,
      expect.closeTo(0.61, 2),
      0.25,
      expect.closeTo(0.39, 2),
      0.75,
      expect.closeTo(0.61, 2),
      0.75,
    ])
  })
})
