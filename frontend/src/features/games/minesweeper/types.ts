export type MinesweeperDifficulty = 'classic' | 'expert' | 'quick'
export type MinesweeperStatus = 'lost' | 'playing' | 'ready' | 'won'

export type MinesweeperCell = {
  adjacentMines: number
  column: number
  id: number
  isFlagged: boolean
  isMine: boolean
  isRevealed: boolean
  row: number
}

export type MinesweeperGameState = {
  cells: MinesweeperCell[]
  difficulty: MinesweeperDifficulty
  explodedCellId: number | null
  height: number
  mineCount: number
  status: MinesweeperStatus
  width: number
}

export type MinesweeperBest = {
  timeMs: number
}

export type MinesweeperActionResult = {
  changed: boolean
  revealedCount: number
  state: MinesweeperGameState
}
