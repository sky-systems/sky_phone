export type NumberMergeDirection = 'down' | 'left' | 'right' | 'up'
export type NumberMergeStatus = 'game-over' | 'playing' | 'won'

export type NumberMergeTile = {
  column: number
  id: number
  isNew: boolean
  merged: boolean
  row: number
  value: number
}

export type NumberMergeGameState = {
  hasWon: boolean
  keepPlaying: boolean
  nextTileId: number
  score: number
  status: NumberMergeStatus
  tiles: NumberMergeTile[]
}

export type NumberMergeMoveResult = {
  changed: boolean
  gained: number
  state: NumberMergeGameState
}
