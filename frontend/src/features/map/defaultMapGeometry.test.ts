import { describe, expect, it } from 'vitest'

import {
  defaultMapPercentToWorld,
  defaultMapWorldToPercent,
} from '@/features/map/defaultMapGeometry'

describe('default map geometry', () => {
  it('round-trips world coordinates through map percentages', () => {
    const world = { x: -75.2, y: -818.9 }
    const restored = defaultMapPercentToWorld(defaultMapWorldToPercent(world))

    expect(restored.x).toBeCloseTo(world.x, 6)
    expect(restored.y).toBeCloseTo(world.y, 6)
  })
})
