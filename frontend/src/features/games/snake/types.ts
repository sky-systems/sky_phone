export type SnakeDirection = 'up' | 'right' | 'down' | 'left'

export type SnakePoint = {
  x: number
  y: number
}

export type SnakeSpeed = 'relaxed' | 'normal' | 'fast'

export type SnakeGameStatus = 'playing' | 'paused' | 'game-over'

export type SnakeGameState = {
  body: SnakePoint[]
  direction: SnakeDirection
  fruit: SnakePoint
  pendingDirection: SnakeDirection
  score: number
  status: SnakeGameStatus
}
