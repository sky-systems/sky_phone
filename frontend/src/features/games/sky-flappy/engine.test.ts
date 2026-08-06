import { describe, expect, it } from 'vitest'

import {
  createSkyFlappyGame,
  FLAPPY_GAP_HEIGHT,
  FLAPPY_MAX_SPEED,
  FLAPPY_MAX_GAP_TOP,
  FLAPPY_MIN_GAP_HEIGHT,
  FLAPPY_MIN_GAP_TOP,
  flapSkyGlider,
  getSkyFlappyDifficulty,
  stepSkyFlappy,
} from './engine'

describe('sky flappy engine', () => {
  it('starts in a ready state', () => {
    expect(createSkyFlappyGame()).toMatchObject({ playerY: 48, score: 0, status: 'ready' })
  })

  it('starts and applies an upward impulse on flap', () => {
    const state = flapSkyGlider(createSkyFlappyGame())
    expect(state.status).toBe('playing')
    expect(state.playerVelocity).toBeLessThan(0)
  })

  it('applies deterministic time-based physics', () => {
    const state = flapSkyGlider(createSkyFlappyGame())
    expect(stepSkyFlappy(state, 0.1, () => 0.5)).toEqual(
      stepSkyFlappy(state, 0.1, () => 0.5),
    )
  })

  it('keeps generated gaps inside playable bounds', () => {
    const state = flapSkyGlider(createSkyFlappyGame())
    const low = stepSkyFlappy(state, 0.01, () => 0)
    const high = stepSkyFlappy(state, 0.01, () => 1)
    expect(low.obstacles[0].gapTop).toBe(FLAPPY_MIN_GAP_TOP)
    expect(high.obstacles[0].gapTop).toBe(FLAPPY_MAX_GAP_TOP)
    expect(high.obstacles[0].gapTop + FLAPPY_GAP_HEIGHT).toBeLessThan(100)
  })

  it('increases speed and narrows the gap as the score rises', () => {
    const start = getSkyFlappyDifficulty(0)
    const advanced = getSkyFlappyDifficulty(20)
    const maximum = getSkyFlappyDifficulty(100)

    expect(advanced.speed).toBeGreaterThan(start.speed)
    expect(advanced.gapHeight).toBeLessThan(start.gapHeight)
    expect(maximum.speed).toBe(FLAPPY_MAX_SPEED)
    expect(maximum.gapHeight).toBe(FLAPPY_MIN_GAP_HEIGHT)
  })

  it('scores an obstacle only once', () => {
    const state = {
      ...flapSkyGlider(createSkyFlappyGame()),
      obstacles: [{ gapHeight: FLAPPY_GAP_HEIGHT, gapTop: 30, id: 1, scored: false, x: 7 }],
    }
    const scored = stepSkyFlappy(state, 0.01, () => 0.5)
    expect(scored.score).toBe(1)
    expect(stepSkyFlappy(scored, 0.01, () => 0.5).score).toBe(1)
  })

  it('detects collision using the player edges', () => {
    const state = {
      ...flapSkyGlider(createSkyFlappyGame()),
      obstacles: [{ gapHeight: FLAPPY_GAP_HEIGHT, gapTop: 40, id: 1, scored: false, x: 22 }],
      playerY: 41,
      playerVelocity: 0,
    }
    expect(stepSkyFlappy(state, 0.01).status).toBe('over')
  })

  it('ends at the upper and lower boundaries', () => {
    const upper = { ...flapSkyGlider(createSkyFlappyGame()), playerY: 1 }
    const lower = { ...flapSkyGlider(createSkyFlappyGame()), playerY: 99 }
    expect(stepSkyFlappy(upper, 0.01).status).toBe('over')
    expect(stepSkyFlappy(lower, 0.01).status).toBe('over')
  })
})
