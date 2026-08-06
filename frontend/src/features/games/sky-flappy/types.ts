export type SkyFlappyStatus = 'over' | 'paused' | 'playing' | 'ready'
export type SkyFlappyDesign = 'dawn' | 'neon' | 'storm'

export type SkyFlappyObstacle = {
  gapTop: number
  id: number
  scored: boolean
  x: number
}

export type SkyFlappyGameState = {
  nextObstacleId: number
  obstacles: SkyFlappyObstacle[]
  playerVelocity: number
  playerY: number
  score: number
  status: SkyFlappyStatus
}
