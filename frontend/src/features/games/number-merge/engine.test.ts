import { describe, expect, it } from 'vitest'

import {
  canMoveNumberMerge,
  continueNumberMerge,
  createNumberMergeGame,
  isNumberMergeGameState,
  moveNumberMerge,
} from './engine'
import type { NumberMergeGameState } from './types'

function gameFromGrid(grid: number[][]): NumberMergeGameState {
  let nextTileId = 1
  return {
    hasWon: false,
    keepPlaying: false,
    nextTileId: grid.flat().filter(Boolean).length + 1,
    score: 0,
    status: 'playing',
    tiles: grid.flatMap((row, rowIndex) =>
      row.flatMap((value, columnIndex) =>
        value
          ? [
              {
                column: columnIndex,
                id: nextTileId++,
                isNew: false,
                merged: false,
                row: rowIndex,
                value,
              },
            ]
          : [],
      ),
    ),
  }
}

function values(state: NumberMergeGameState): number[][] {
  return Array.from({ length: 4 }, (_, row) =>
    Array.from(
      { length: 4 },
      (_, column) =>
        state.tiles.find(
          (tile) => tile.row === row && tile.column === column,
        )?.value ?? 0,
    ),
  )
}

const spawnFirstTwo = () => 0

describe('number merge engine', () => {
  it('starts with two tiles on different cells', () => {
    const game = createNumberMergeGame(spawnFirstTwo)
    expect(game.tiles).toHaveLength(2)
    expect(game.tiles.map((tile) => tile.value)).toEqual([2, 2])
    expect(
      new Set(game.tiles.map((tile) => `${tile.row}:${tile.column}`)).size,
    ).toBe(2)
  })

  it('compresses and merges a row to the left', () => {
    const result = moveNumberMerge(
      gameFromGrid([
        [2, 0, 2, 4],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]),
      'left',
      spawnFirstTwo,
    )
    expect(values(result.state)[0].slice(0, 3)).toEqual([4, 4, 2])
    expect(result.gained).toBe(4)
  })

  it('merges each tile only once per move', () => {
    const result = moveNumberMerge(
      gameFromGrid([
        [2, 2, 2, 2],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]),
      'left',
      spawnFirstTwo,
    )
    expect(values(result.state)[0].slice(0, 3)).toEqual([4, 4, 2])
    expect(result.gained).toBe(8)
  })

  it('moves columns upward using the same merge rules', () => {
    const result = moveNumberMerge(
      gameFromGrid([
        [2, 0, 0, 0],
        [2, 0, 0, 0],
        [4, 0, 0, 0],
        [4, 0, 0, 0],
      ]),
      'up',
      spawnFirstTwo,
    )
    expect(values(result.state).map((row) => row[0])).toEqual([4, 8, 0, 0])
    expect(result.state.tiles).toHaveLength(3)
    expect(result.gained).toBe(12)
  })

  it('does not spawn a tile after an invalid move', () => {
    const game = gameFromGrid([
      [2, 4, 8, 16],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ])
    const result = moveNumberMerge(game, 'left', spawnFirstTwo)
    expect(result.changed).toBe(false)
    expect(result.state).toBe(game)
  })

  it('recognizes a board with no remaining moves', () => {
    const game = gameFromGrid([
      [2, 4, 2, 4],
      [4, 2, 4, 2],
      [2, 4, 2, 4],
      [4, 2, 4, 2],
    ])
    expect(canMoveNumberMerge(game)).toBe(false)
  })

  it('pauses at 2048 and can continue afterward', () => {
    const result = moveNumberMerge(
      gameFromGrid([
        [1024, 1024, 0, 0],
        [2, 4, 8, 16],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ]),
      'left',
      spawnFirstTwo,
    )
    expect(result.state.status).toBe('won')
    expect(result.state.hasWon).toBe(true)
    expect(continueNumberMerge(result.state).status).toBe('playing')
  })

  it('rejects malformed persisted games', () => {
    expect(isNumberMergeGameState(gameFromGrid([[2], [], [], []]))).toBe(true)
    expect(
      isNumberMergeGameState({
        ...gameFromGrid([[2], [], [], []]),
        tiles: [{ column: 8, id: 1, isNew: false, merged: false, row: 0, value: 3 }],
      }),
    ).toBe(false)
  })
})
