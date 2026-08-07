import type {
  SnakeDirection,
  SnakeGameState,
  SnakePoint,
} from './types'

export const SNAKE_BOARD_WIDTH = 16
export const SNAKE_BOARD_HEIGHT = 34

const DIRECTION_VECTORS: Record<SnakeDirection, SnakePoint> = {
  up: { x: 0, y: -1 },
  right: { x: 1, y: 0 },
  down: { x: 0, y: 1 },
  left: { x: -1, y: 0 },
}

const OPPOSITE_DIRECTIONS: Record<SnakeDirection, SnakeDirection> = {
  up: 'down',
  right: 'left',
  down: 'up',
  left: 'right',
}

function pointsMatch(first: SnakePoint, second: SnakePoint): boolean {
  return first.x === second.x && first.y === second.y
}

function placeFruit(
  body: SnakePoint[],
  random: () => number,
): SnakePoint {
  const openCells: SnakePoint[] = []

  for (let y = 0; y < SNAKE_BOARD_HEIGHT; y += 1) {
    for (let x = 0; x < SNAKE_BOARD_WIDTH; x += 1) {
      const point = { x, y }
      if (!body.some((segment) => pointsMatch(segment, point))) {
        openCells.push(point)
      }
    }
  }

  const index = Math.min(
    openCells.length - 1,
    Math.floor(Math.max(0, random()) * openCells.length),
  )
  return openCells[index] ?? body[0]
}

export function createSnakeGame(random: () => number = Math.random): SnakeGameState {
  const centerX = Math.floor(SNAKE_BOARD_WIDTH / 2)
  const centerY = Math.floor(SNAKE_BOARD_HEIGHT / 2)
  const body = [
    { x: centerX, y: centerY },
    { x: centerX - 1, y: centerY },
    { x: centerX - 2, y: centerY },
  ]

  return {
    body,
    direction: 'right',
    fruit: placeFruit(body, random),
    pendingDirection: 'right',
    score: 0,
    status: 'playing',
  }
}

export function turnSnake(
  state: SnakeGameState,
  direction: SnakeDirection,
): SnakeGameState {
  if (
    state.status !== 'playing' ||
    direction === OPPOSITE_DIRECTIONS[state.direction]
  ) {
    return state
  }

  return { ...state, pendingDirection: direction }
}

export function stepSnake(
  state: SnakeGameState,
  random: () => number = Math.random,
): SnakeGameState {
  if (state.status !== 'playing') return state

  const direction = state.pendingDirection
  const vector = DIRECTION_VECTORS[direction]
  const head = state.body[0]
  const nextHead = { x: head.x + vector.x, y: head.y + vector.y }
  const ateFruit = pointsMatch(nextHead, state.fruit)
  const collisionBody = ateFruit ? state.body : state.body.slice(0, -1)
  const hitWall =
    nextHead.x < 0 ||
    nextHead.x >= SNAKE_BOARD_WIDTH ||
    nextHead.y < 0 ||
    nextHead.y >= SNAKE_BOARD_HEIGHT
  const hitBody = collisionBody.some((segment) =>
    pointsMatch(segment, nextHead),
  )

  if (hitWall || hitBody) {
    return { ...state, direction, status: 'game-over' }
  }

  const body = [nextHead, ...state.body]
  if (!ateFruit) body.pop()

  return {
    ...state,
    body,
    direction,
    fruit: ateFruit ? placeFruit(body, random) : state.fruit,
    score: state.score + (ateFruit ? 1 : 0),
  }
}
