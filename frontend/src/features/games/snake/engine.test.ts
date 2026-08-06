import { describe, expect, it } from 'vitest'

import {
  createSnakeGame,
  SNAKE_BOARD_WIDTH,
  stepSnake,
  turnSnake,
} from './engine'
import type { SnakeGameState } from './types'

describe('Snake engine', () => {
  it('moves one cell without changing its length', () => {
    const game = createSnakeGame(() => 0)
    const next = stepSnake(game, () => 0)

    expect(next.body[0]).toEqual({ x: game.body[0].x + 1, y: game.body[0].y })
    expect(next.body).toHaveLength(game.body.length)
  })

  it('grows, scores, and places fruit outside the body', () => {
    const game = createSnakeGame(() => 0)
    game.fruit = { x: game.body[0].x + 1, y: game.body[0].y }
    const next = stepSnake(game, () => 0)

    expect(next.score).toBe(1)
    expect(next.body).toHaveLength(game.body.length + 1)
    expect(next.body).not.toContainEqual(next.fruit)
  })

  it('ignores an immediate reverse direction', () => {
    const game = createSnakeGame(() => 0)

    expect(turnSnake(game, 'left')).toBe(game)
    expect(turnSnake(game, 'up').pendingDirection).toBe('up')
  })

  it('ends the game on wall collision', () => {
    const game: SnakeGameState = {
      ...createSnakeGame(() => 0),
      body: [
        { x: SNAKE_BOARD_WIDTH - 1, y: 4 },
        { x: SNAKE_BOARD_WIDTH - 2, y: 4 },
      ],
    }

    expect(stepSnake(game).status).toBe('game-over')
  })

  it('ends the game on body collision', () => {
    const game: SnakeGameState = {
      body: [
        { x: 4, y: 4 },
        { x: 4, y: 3 },
        { x: 3, y: 3 },
        { x: 3, y: 4 },
        { x: 3, y: 5 },
      ],
      direction: 'up',
      fruit: { x: 10, y: 10 },
      pendingDirection: 'left',
      score: 0,
      status: 'playing',
    }

    expect(stepSnake(game).status).toBe('game-over')
  })

  it('does not advance a paused game', () => {
    const game: SnakeGameState = {
      ...createSnakeGame(() => 0),
      status: 'paused',
    }

    expect(stepSnake(game)).toBe(game)
  })
})
