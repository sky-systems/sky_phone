import { describe, expect, it } from 'vitest'

import {
  advanceTowerBlock,
  createTowerGame,
  placeTowerBlock,
  TOWER_BASE_WIDTH,
  TOWER_MAX_SPEED,
  TOWER_PERFECT_TOLERANCE,
} from './engine'

describe('tower stack engine', () => {
  it('creates a centered foundation and moving block', () => {
    const state = createTowerGame()
    expect(state.blocks).toHaveLength(1)
    expect(state.blocks[0].width).toBe(TOWER_BASE_WIDTH)
    expect(state.active?.x).toBe(0)
    expect(state.status).toBe('playing')
  })

  it('moves the active block using elapsed time', () => {
    const state = createTowerGame()
    const moved = advanceTowerBlock(state, 0.5)
    expect(moved.active?.x).toBeCloseTo(11.5)
  })

  it('reflects a moving block at the field edge', () => {
    const state = createTowerGame()
    const moved = advanceTowerBlock(state, 2)
    expect(moved.active?.direction).toBe(-1)
    expect(moved.active?.x).toBeGreaterThanOrEqual(0)
  })

  it('keeps only the overlapping part', () => {
    const state = createTowerGame()
    state.active = { ...state.active!, x: 25 }
    const result = placeTowerBlock(state)
    expect(result.outcome).toBe('placed')
    expect(result.state.blocks.at(-1)?.width).toBeCloseTo(59)
    expect(result.cutWidth).toBeCloseTo(9)
  })

  it('rewards a perfect placement within tolerance', () => {
    const state = createTowerGame()
    state.active = {
      ...state.active!,
      x: state.blocks[0].x + TOWER_PERFECT_TOLERANCE / 2,
    }
    const result = placeTowerBlock(state)
    expect(result.outcome).toBe('perfect')
    expect(result.state.perfects).toBe(1)
    expect(result.state.score).toBe(4)
  })

  it('ends the round on a complete miss', () => {
    const state = createTowerGame()
    state.active = { ...state.active!, width: 8, x: 0 }
    const result = placeTowerBlock(state)
    expect(result.outcome).toBe('missed')
    expect(result.state.status).toBe('over')
    expect(result.state.active).toBeNull()
  })

  it('alternates movement direction for each level', () => {
    const state = createTowerGame()
    state.active = { ...state.active!, x: state.blocks[0].x }
    const result = placeTowerBlock(state)
    expect(result.state.active?.direction).toBe(-1)
  })

  it('caps speed at the configured maximum', () => {
    let state = createTowerGame()
    for (let level = 0; level < 30; level += 1) {
      state.active = { ...state.active!, x: state.blocks.at(-1)!.x }
      state = placeTowerBlock(state).state
    }
    expect(state.active?.speed).toBe(TOWER_MAX_SPEED)
  })
})
