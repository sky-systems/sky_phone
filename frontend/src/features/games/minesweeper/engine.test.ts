import { describe, expect, it } from 'vitest'

import {
  createMinesweeperGame,
  isMinesweeperGameState,
  revealMinesweeperCell,
  toggleMinesweeperFlag,
} from './engine'
import type { MinesweeperGameState } from './types'

const chooseFirst = () => 0

function preparedGame(
  width: number,
  height: number,
  mines: number[],
): MinesweeperGameState {
  const state = createMinesweeperGame('quick')
  const mineSet = new Set(mines)
  return {
    ...state,
    cells: state.cells.map((cell) => ({
      ...cell,
      adjacentMines: state.cells.filter(
        (candidate) =>
          mineSet.has(candidate.id) &&
          Math.abs(candidate.row - cell.row) <= 1 &&
          Math.abs(candidate.column - cell.column) <= 1 &&
          candidate.id !== cell.id,
      ).length,
      isMine: mineSet.has(cell.id),
    })),
    height,
    mineCount: mines.length,
    status: 'playing',
    width,
  }
}

describe('minesweeper engine', () => {
  it('creates the configured phone boards', () => {
    const game = createMinesweeperGame('classic')
    expect(game.width).toBe(7)
    expect(game.height).toBe(9)
    expect(game.mineCount).toBe(11)
    expect(game.cells).toHaveLength(63)
  })

  it('places the exact mine count outside the protected first area', () => {
    const original = createMinesweeperGame('quick')
    const result = revealMinesweeperCell(original, 14, chooseFirst)
    const protectedIds = [7, 8, 9, 13, 14, 15, 19, 20, 21]
    expect(result.state.cells.filter((cell) => cell.isMine)).toHaveLength(7)
    expect(
      result.state.cells
        .filter((cell) => protectedIds.includes(cell.id))
        .every((cell) => !cell.isMine),
    ).toBe(true)
  })

  it('calculates neighbour counts from the placed mines', () => {
    const result = revealMinesweeperCell(
      createMinesweeperGame('quick'),
      0,
      chooseFirst,
    )
    for (const cell of result.state.cells) {
      const actual = result.state.cells.filter(
        (candidate) =>
          candidate.isMine &&
          Math.abs(candidate.row - cell.row) <= 1 &&
          Math.abs(candidate.column - cell.column) <= 1 &&
          candidate.id !== cell.id,
      ).length
      expect(cell.adjacentMines).toBe(actual)
    }
  })

  it('reveals an empty area and its numbered boundary but no mine', () => {
    const game = preparedGame(6, 8, [0, 5, 42, 47, 43, 44, 45])
    const result = revealMinesweeperCell(game, 20)
    expect(result.revealedCount).toBeGreaterThan(1)
    expect(result.state.cells.some((cell) => cell.isMine && cell.isRevealed)).toBe(false)
    expect(
      result.state.cells.some(
        (cell) => cell.isRevealed && cell.adjacentMines > 0,
      ),
    ).toBe(true)
  })

  it('does not reveal a flagged cell', () => {
    const game = preparedGame(6, 8, [47])
    const flagged = toggleMinesweeperFlag(game, 10).state
    const result = revealMinesweeperCell(flagged, 10)
    expect(result.changed).toBe(false)
    expect(result.state.cells[10].isRevealed).toBe(false)
  })

  it('reveals all mines and records the exploded cell on loss', () => {
    const game = preparedGame(6, 8, [1, 47])
    const result = revealMinesweeperCell(game, 1)
    expect(result.state.status).toBe('lost')
    expect(result.state.explodedCellId).toBe(1)
    expect(result.state.cells.filter((cell) => cell.isMine).every((cell) => cell.isRevealed)).toBe(true)
  })

  it('wins when every safe field is revealed', () => {
    let game = preparedGame(6, 8, [47])
    for (const cell of game.cells) {
      if (!cell.isMine && !game.cells[cell.id].isRevealed) {
        game = revealMinesweeperCell(game, cell.id).state
      }
    }
    expect(game.status).toBe('won')
    expect(game.cells[47].isFlagged).toBe(true)
  })

  it('validates persisted games', () => {
    const game = createMinesweeperGame('expert')
    expect(isMinesweeperGameState(game)).toBe(true)
    expect(isMinesweeperGameState({ ...game, mineCount: 99 })).toBe(false)
  })
})
