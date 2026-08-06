import { describe, expect, it } from 'vitest'

import {
  canPlaceNeonDropPiece,
  clearCompletedNeonDropLines,
  createNeonDropBoard,
  createNeonDropGame,
  getNeonDropCells,
  getNeonDropGhostPiece,
  getNeonDropInterval,
  hardDropNeonPiece,
  moveNeonDropPiece,
  NEON_DROP_COLUMNS,
  NEON_DROP_ROWS,
  rotateNeonDropPiece,
  stepNeonDrop,
} from './engine'

describe('neon drop engine', () => {
  it('starts with a valid piece and a complete seven-piece bag', () => {
    const game = createNeonDropGame(() => 0.5)
    expect(game.status).toBe('playing')
    expect(new Set([game.active.kind, ...game.queue]).size).toBe(7)
    expect(canPlaceNeonDropPiece(game.board, game.active)).toBe(true)
  })

  it('does not move through the side walls', () => {
    let game = createNeonDropGame(() => 0)
    for (let index = 0; index < NEON_DROP_COLUMNS; index += 1) {
      game = moveNeonDropPiece(game, -1).state
    }
    expect(
      Math.min(...getNeonDropCells(game.active).map((cell) => cell.x)),
    ).toBe(0)
    expect(moveNeonDropPiece(game, -1).event).toBe('none')
  })

  it('rotates pieces while keeping every cell inside the board', () => {
    const game = createNeonDropGame(() => 0.5)
    const rotated = rotateNeonDropPiece(game)
    expect(rotated.event).toBe('rotate')
    expect(
      canPlaceNeonDropPiece(rotated.state.board, rotated.state.active),
    ).toBe(true)
  })

  it('clears complete rows and moves remaining cells downward', () => {
    const board = createNeonDropBoard()
    board[NEON_DROP_ROWS - 1].fill('I')
    board[NEON_DROP_ROWS - 2][0] = 'T'
    const result = clearCompletedNeonDropLines(board)
    expect(result.clearedLines).toBe(1)
    expect(result.board[NEON_DROP_ROWS - 1][0]).toBe('T')
    expect(result.board[0].every((cell) => cell === null)).toBe(true)
  })

  it('hard drops exactly onto the ghost position and awards distance points', () => {
    const game = createNeonDropGame(() => 0.5)
    const ghost = getNeonDropGhostPiece(game)
    const distance = ghost.y - game.active.y
    const result = hardDropNeonPiece(game, () => 0.5)
    expect(result.event).toBe('lock')
    expect(result.state.score).toBe(distance * 2)
    expect(result.state.board.flat().filter(Boolean)).toHaveLength(4)
  })

  it('awards line points and advances the level after eight cleared rows', () => {
    const game = createNeonDropGame(() => 0.5)
    const board = createNeonDropBoard()
    board[NEON_DROP_ROWS - 1].fill('J')
    for (let x = 3; x <= 6; x += 1) board[NEON_DROP_ROWS - 1][x] = null
    const result = hardDropNeonPiece({
      ...game,
      active: { kind: 'I', rotation: 0, x: 3, y: NEON_DROP_ROWS - 2 },
      board,
      lines: 7,
    })
    expect(result.clearedLines).toBe(1)
    expect(result.state.score).toBe(100)
    expect(result.state.lines).toBe(8)
    expect(result.state.level).toBe(2)
  })

  it('ends the round when the next piece cannot enter the board', () => {
    const game = createNeonDropGame(() => 0.5)
    const board = createNeonDropBoard()
    board[2].fill('Z')
    const result = stepNeonDrop({
      ...game,
      active: { kind: 'O', rotation: 0, x: 3, y: 0 },
      board,
    })
    expect(result.event).toBe('game-over')
    expect(result.state.status).toBe('over')
  })

  it('increases speed each level but keeps a playable minimum interval', () => {
    expect(getNeonDropInterval(2)).toBeLessThan(getNeonDropInterval(1))
    expect(getNeonDropInterval(100)).toBe(110)
  })
})
