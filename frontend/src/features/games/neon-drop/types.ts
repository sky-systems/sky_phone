export type NeonDropPieceKind = 'I' | 'J' | 'L' | 'O' | 'S' | 'T' | 'Z'
export type NeonDropCell = NeonDropPieceKind | null
export type NeonDropStatus = 'over' | 'paused' | 'playing'
export type NeonDropEvent =
  | 'clear'
  | 'drop'
  | 'game-over'
  | 'lock'
  | 'move'
  | 'none'
  | 'rotate'

export type NeonDropPoint = {
  x: number
  y: number
}

export type NeonDropPiece = {
  kind: NeonDropPieceKind
  rotation: number
  x: number
  y: number
}

export type NeonDropGameState = {
  active: NeonDropPiece
  board: NeonDropCell[][]
  level: number
  lines: number
  nextKind: NeonDropPieceKind
  queue: NeonDropPieceKind[]
  score: number
  status: NeonDropStatus
}

export type NeonDropActionResult = {
  clearedLines: number
  event: NeonDropEvent
  state: NeonDropGameState
}
