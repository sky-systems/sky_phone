import type { SkyFlappyGameState, SkyFlappyObstacle } from './types'

export const FLAPPY_PLAYER_X = 23
export const FLAPPY_PLAYER_RADIUS = 3.2
export const FLAPPY_GRAVITY = 82
export const FLAPPY_IMPULSE = -34
export const FLAPPY_OBSTACLE_WIDTH = 14
export const FLAPPY_GAP_HEIGHT = 29
export const FLAPPY_MIN_GAP_TOP = 15
export const FLAPPY_MAX_GAP_TOP = 56

export function createSkyFlappyGame(): SkyFlappyGameState {
  return {
    nextObstacleId: 1,
    obstacles: [],
    playerVelocity: 0,
    playerY: 48,
    score: 0,
    status: 'ready',
  }
}

export function flapSkyGlider(state: SkyFlappyGameState): SkyFlappyGameState {
  if (state.status === 'over' || state.status === 'paused') return state
  return { ...state, playerVelocity: FLAPPY_IMPULSE, status: 'playing' }
}

function createObstacle(
  id: number,
  random: () => number,
): SkyFlappyObstacle {
  return {
    gapTop:
      FLAPPY_MIN_GAP_TOP +
      Math.max(0, Math.min(1, random())) *
        (FLAPPY_MAX_GAP_TOP - FLAPPY_MIN_GAP_TOP),
    id,
    scored: false,
    x: 108,
  }
}

function collidesWithObstacle(
  playerY: number,
  obstacle: SkyFlappyObstacle,
): boolean {
  const horizontalCollision =
    FLAPPY_PLAYER_X + FLAPPY_PLAYER_RADIUS > obstacle.x &&
    FLAPPY_PLAYER_X - FLAPPY_PLAYER_RADIUS <
      obstacle.x + FLAPPY_OBSTACLE_WIDTH
  if (!horizontalCollision) return false

  return (
    playerY - FLAPPY_PLAYER_RADIUS < obstacle.gapTop ||
    playerY + FLAPPY_PLAYER_RADIUS > obstacle.gapTop + FLAPPY_GAP_HEIGHT
  )
}

export function stepSkyFlappy(
  state: SkyFlappyGameState,
  elapsedSeconds: number,
  random: () => number = Math.random,
): SkyFlappyGameState {
  if (state.status !== 'playing' || elapsedSeconds <= 0) return state

  const speed = Math.min(33, 20.5 + state.score * 0.38)
  const playerVelocity = state.playerVelocity + FLAPPY_GRAVITY * elapsedSeconds
  const playerY = state.playerY + playerVelocity * elapsedSeconds
  let nextObstacleId = state.nextObstacleId
  let obstacles = state.obstacles
    .map((obstacle) => ({
      ...obstacle,
      x: obstacle.x - speed * elapsedSeconds,
    }))
    .filter((obstacle) => obstacle.x + FLAPPY_OBSTACLE_WIDTH > -2)

  if (obstacles.length === 0 || obstacles[obstacles.length - 1].x < 61) {
    obstacles = [...obstacles, createObstacle(nextObstacleId, random)]
    nextObstacleId += 1
  }

  let score = state.score
  obstacles = obstacles.map((obstacle) => {
    if (
      !obstacle.scored &&
      obstacle.x + FLAPPY_OBSTACLE_WIDTH < FLAPPY_PLAYER_X
    ) {
      score += 1
      return { ...obstacle, scored: true }
    }
    return obstacle
  })

  const collided =
    playerY - FLAPPY_PLAYER_RADIUS <= 0 ||
    playerY + FLAPPY_PLAYER_RADIUS >= 100 ||
    obstacles.some((obstacle) => collidesWithObstacle(playerY, obstacle))

  return {
    nextObstacleId,
    obstacles,
    playerVelocity,
    playerY,
    score,
    status: collided ? 'over' : 'playing',
  }
}

export function pauseSkyFlappy(
  state: SkyFlappyGameState,
): SkyFlappyGameState {
  return state.status === 'playing' ? { ...state, status: 'paused' } : state
}

export function resumeSkyFlappy(
  state: SkyFlappyGameState,
): SkyFlappyGameState {
  return state.status === 'paused' ? { ...state, status: 'playing' } : state
}
