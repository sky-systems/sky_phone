import type {
  MinesweeperActionResult,
  MinesweeperCell,
  MinesweeperDifficulty,
  MinesweeperGameState,
} from './types'

export const MINESWEEPER_DIFFICULTIES: Record<
  MinesweeperDifficulty,
  { height: number; mines: number; width: number }
> = {
  quick: { height: 8, mines: 7, width: 6 },
  classic: { height: 9, mines: 11, width: 7 },
  expert: { height: 10, mines: 16, width: 8 },
}

function neighbours(
  cell: MinesweeperCell,
  width: number,
  height: number,
): number[] {
  const ids: number[] = []
  for (let rowOffset = -1; rowOffset <= 1; rowOffset += 1) {
    for (let columnOffset = -1; columnOffset <= 1; columnOffset += 1) {
      if (rowOffset === 0 && columnOffset === 0) continue
      const row = cell.row + rowOffset
      const column = cell.column + columnOffset
      if (row >= 0 && row < height && column >= 0 && column < width) {
        ids.push(row * width + column)
      }
    }
  }
  return ids
}

function placeMines(
  state: MinesweeperGameState,
  firstCellId: number,
  random: () => number,
): MinesweeperGameState {
  const firstCell = state.cells[firstCellId]
  const protectedIds = new Set([
    firstCellId,
    ...neighbours(firstCell, state.width, state.height),
  ])
  const candidates = state.cells
    .map((cell) => cell.id)
    .filter((id) => !protectedIds.has(id))
  const mineIds = new Set<number>()

  for (let count = 0; count < state.mineCount; count += 1) {
    const candidateIndex = Math.min(
      candidates.length - 1,
      Math.floor(random() * candidates.length),
    )
    const [mineId] = candidates.splice(candidateIndex, 1)
    mineIds.add(mineId)
  }

  const cells = state.cells.map((cell) => ({
    ...cell,
    isMine: mineIds.has(cell.id),
  }))
  return {
    ...state,
    cells: cells.map((cell) => ({
      ...cell,
      adjacentMines: neighbours(cell, state.width, state.height).filter(
        (id) => mineIds.has(id),
      ).length,
    })),
    status: 'playing',
  }
}

export function createMinesweeperGame(
  difficulty: MinesweeperDifficulty,
): MinesweeperGameState {
  const config = MINESWEEPER_DIFFICULTIES[difficulty]
  return {
    cells: Array.from({ length: config.width * config.height }, (_, id) => ({
      adjacentMines: 0,
      column: id % config.width,
      id,
      isFlagged: false,
      isMine: false,
      isRevealed: false,
      row: Math.floor(id / config.width),
    })),
    difficulty,
    explodedCellId: null,
    height: config.height,
    mineCount: config.mines,
    status: 'ready',
    width: config.width,
  }
}

export function toggleMinesweeperFlag(
  state: MinesweeperGameState,
  cellId: number,
): MinesweeperActionResult {
  if (state.status === 'lost' || state.status === 'won') {
    return { changed: false, revealedCount: 0, state }
  }

  const cell = state.cells[cellId]
  if (!cell || cell.isRevealed) {
    return { changed: false, revealedCount: 0, state }
  }

  const flagCount = state.cells.filter((candidate) => candidate.isFlagged).length
  if (!cell.isFlagged && flagCount >= state.mineCount) {
    return { changed: false, revealedCount: 0, state }
  }

  return {
    changed: true,
    revealedCount: 0,
    state: {
      ...state,
      cells: state.cells.map((candidate) =>
        candidate.id === cellId
          ? { ...candidate, isFlagged: !candidate.isFlagged }
          : candidate,
      ),
    },
  }
}

export function revealMinesweeperCell(
  originalState: MinesweeperGameState,
  cellId: number,
  random: () => number = Math.random,
): MinesweeperActionResult {
  if (originalState.status === 'lost' || originalState.status === 'won') {
    return { changed: false, revealedCount: 0, state: originalState }
  }

  const originalCell = originalState.cells[cellId]
  if (!originalCell || originalCell.isFlagged || originalCell.isRevealed) {
    return { changed: false, revealedCount: 0, state: originalState }
  }

  const state =
    originalState.status === 'ready'
      ? placeMines(originalState, cellId, random)
      : originalState
  const selectedCell = state.cells[cellId]

  if (selectedCell.isMine) {
    return {
      changed: true,
      revealedCount: 0,
      state: {
        ...state,
        cells: state.cells.map((cell) =>
          cell.isMine ? { ...cell, isRevealed: true } : cell,
        ),
        explodedCellId: cellId,
        status: 'lost',
      },
    }
  }

  const cells = state.cells.map((cell) => ({ ...cell }))
  const queue = [cellId]
  const visited = new Set<number>()
  let revealedCount = 0

  while (queue.length > 0) {
    const currentId = queue.shift() as number
    if (visited.has(currentId)) continue
    visited.add(currentId)

    const cell = cells[currentId]
    if (cell.isFlagged || cell.isMine || cell.isRevealed) continue
    cell.isRevealed = true
    revealedCount += 1

    if (cell.adjacentMines === 0) {
      for (const neighbourId of neighbours(cell, state.width, state.height)) {
        if (!visited.has(neighbourId) && !cells[neighbourId].isMine) {
          queue.push(neighbourId)
        }
      }
    }
  }

  const safeCellCount = cells.length - state.mineCount
  const totalRevealed = cells.filter(
    (cell) => cell.isRevealed && !cell.isMine,
  ).length
  const won = totalRevealed === safeCellCount

  return {
    changed: true,
    revealedCount,
    state: {
      ...state,
      cells: won
        ? cells.map((cell) =>
            cell.isMine ? { ...cell, isFlagged: true } : cell,
          )
        : cells,
      status: won ? 'won' : 'playing',
    },
  }
}

export function isMinesweeperGameState(
  value: unknown,
): value is MinesweeperGameState {
  if (!value || typeof value !== 'object') return false
  const game = value as Partial<MinesweeperGameState>
  if (
    !['quick', 'classic', 'expert'].includes(game.difficulty ?? '') ||
    !['ready', 'playing', 'won', 'lost'].includes(game.status ?? '') ||
    !Number.isInteger(game.width) ||
    !Number.isInteger(game.height) ||
    !Number.isInteger(game.mineCount) ||
    !Array.isArray(game.cells) ||
    game.cells.length !== (game.width ?? 0) * (game.height ?? 0) ||
    (game.explodedCellId !== null && !Number.isInteger(game.explodedCellId))
  ) {
    return false
  }

  const config = MINESWEEPER_DIFFICULTIES[game.difficulty as MinesweeperDifficulty]
  if (
    game.width !== config.width ||
    game.height !== config.height ||
    game.mineCount !== config.mines
  ) {
    return false
  }

  for (let id = 0; id < game.cells.length; id += 1) {
    const cell = game.cells[id] as Partial<MinesweeperCell>
    if (
      !cell ||
      cell.id !== id ||
      cell.row !== Math.floor(id / config.width) ||
      cell.column !== id % config.width ||
      !Number.isInteger(cell.adjacentMines) ||
      (cell.adjacentMines ?? -1) < 0 ||
      (cell.adjacentMines ?? 9) > 8 ||
      typeof cell.isFlagged !== 'boolean' ||
      typeof cell.isMine !== 'boolean' ||
      typeof cell.isRevealed !== 'boolean'
    ) {
      return false
    }
  }

  const placedMineCount = game.cells.filter((cell) => cell.isMine).length
  return game.status === 'ready'
    ? placedMineCount === 0
    : placedMineCount === game.mineCount
}
