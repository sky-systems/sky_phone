import type {
  TowerActiveBlock,
  TowerBlock,
  TowerGameState,
  TowerPlacement,
} from './types'

export const TOWER_FIELD_WIDTH = 100
export const TOWER_BASE_WIDTH = 68
export const TOWER_PERFECT_TOLERANCE = 1.35
export const TOWER_START_SPEED = 23
export const TOWER_MAX_SPEED = 48

function speedForLevel(level: number): number {
  return Math.min(
    TOWER_MAX_SPEED,
    TOWER_START_SPEED + Math.max(0, level - 1) * 1.65,
  )
}

function createActiveBlock(
  level: number,
  width: number,
  direction: -1 | 1,
): TowerActiveBlock {
  return {
    colorIndex: level % 6,
    direction,
    id: level,
    level,
    speed: speedForLevel(level),
    width,
    x: direction === 1 ? 0 : TOWER_FIELD_WIDTH - width,
  }
}

export function createTowerGame(): TowerGameState {
  const base: TowerBlock = {
    colorIndex: 0,
    id: 0,
    level: 0,
    width: TOWER_BASE_WIDTH,
    x: (TOWER_FIELD_WIDTH - TOWER_BASE_WIDTH) / 2,
  }

  return {
    active: createActiveBlock(1, TOWER_BASE_WIDTH, 1),
    blocks: [base],
    perfects: 0,
    score: 0,
    status: 'playing',
  }
}

export function advanceTowerBlock(
  state: TowerGameState,
  elapsedSeconds: number,
): TowerGameState {
  if (state.status !== 'playing' || !state.active || elapsedSeconds <= 0) {
    return state
  }

  const active = { ...state.active }
  let nextX = active.x + active.direction * active.speed * elapsedSeconds
  const maximumX = TOWER_FIELD_WIDTH - active.width

  while (nextX < 0 || nextX > maximumX) {
    if (nextX > maximumX) {
      nextX = maximumX - (nextX - maximumX)
      active.direction = -1
    } else {
      nextX = -nextX
      active.direction = 1
    }
  }

  active.x = nextX
  return { ...state, active }
}

export function placeTowerBlock(state: TowerGameState): TowerPlacement {
  if (state.status !== 'playing' || !state.active) {
    return { cutSide: null, cutWidth: 0, outcome: 'missed', state }
  }

  const active = state.active
  const support = state.blocks[state.blocks.length - 1]
  const overlapStart = Math.max(active.x, support.x)
  const overlapEnd = Math.min(active.x + active.width, support.x + support.width)
  const overlapWidth = overlapEnd - overlapStart

  if (overlapWidth <= 0) {
    return {
      cutSide: active.x < support.x ? 'left' : 'right',
      cutWidth: active.width,
      outcome: 'missed',
      state: { ...state, active: null, status: 'over' },
    }
  }

  const offset = active.x - support.x
  const isPerfect = Math.abs(offset) <= TOWER_PERFECT_TOLERANCE
  const placedWidth = isPerfect
    ? Math.min(TOWER_BASE_WIDTH, support.width + 0.85)
    : overlapWidth
  const placedX = isPerfect
    ? support.x - (placedWidth - support.width) / 2
    : overlapStart
  const block: TowerBlock = {
    colorIndex: active.colorIndex,
    id: active.id,
    level: active.level,
    width: placedWidth,
    x: placedX,
  }
  const nextLevel = active.level + 1
  const direction: -1 | 1 = nextLevel % 2 === 0 ? -1 : 1

  return {
    cutSide: isPerfect ? null : offset < 0 ? 'left' : 'right',
    cutWidth: isPerfect ? 0 : active.width - overlapWidth,
    outcome: isPerfect ? 'perfect' : 'placed',
    state: {
      active: createActiveBlock(nextLevel, placedWidth, direction),
      blocks: [...state.blocks, block],
      perfects: state.perfects + (isPerfect ? 1 : 0),
      score: state.score + 1 + (isPerfect ? 3 : 0),
      status: 'playing',
    },
  }
}

export function pauseTowerGame(state: TowerGameState): TowerGameState {
  return state.status === 'playing' ? { ...state, status: 'paused' } : state
}

export function resumeTowerGame(state: TowerGameState): TowerGameState {
  return state.status === 'paused' ? { ...state, status: 'playing' } : state
}
