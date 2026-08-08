import type {
  NeonDropActionResult,
  NeonDropCell,
  NeonDropGameState,
  NeonDropPiece,
  NeonDropPieceKind,
  NeonDropPoint,
} from './types'

export const NEON_DROP_COLUMNS = 10
export const NEON_DROP_ROWS = 17
export const NEON_DROP_LINES_PER_LEVEL = 8

const PIECE_KINDS: NeonDropPieceKind[] = ['I', 'J', 'L', 'O', 'S', 'T', 'Z']
const LINE_SCORES = [0, 100, 300, 500, 800]
const SHAPES: Record<NeonDropPieceKind, NeonDropPoint[][]> = {
  I: [
    [
      { x: 0, y: 1 },
      { x: 1, y: 1 },
      { x: 2, y: 1 },
      { x: 3, y: 1 },
    ],
    [
      { x: 2, y: 0 },
      { x: 2, y: 1 },
      { x: 2, y: 2 },
      { x: 2, y: 3 },
    ],
    [
      { x: 0, y: 2 },
      { x: 1, y: 2 },
      { x: 2, y: 2 },
      { x: 3, y: 2 },
    ],
    [
      { x: 1, y: 0 },
      { x: 1, y: 1 },
      { x: 1, y: 2 },
      { x: 1, y: 3 },
    ],
  ],
  J: [
    [
      { x: 0, y: 0 },
      { x: 0, y: 1 },
      { x: 1, y: 1 },
      { x: 2, y: 1 },
    ],
    [
      { x: 1, y: 0 },
      { x: 2, y: 0 },
      { x: 1, y: 1 },
      { x: 1, y: 2 },
    ],
    [
      { x: 0, y: 1 },
      { x: 1, y: 1 },
      { x: 2, y: 1 },
      { x: 2, y: 2 },
    ],
    [
      { x: 1, y: 0 },
      { x: 1, y: 1 },
      { x: 0, y: 2 },
      { x: 1, y: 2 },
    ],
  ],
  L: [
    [
      { x: 2, y: 0 },
      { x: 0, y: 1 },
      { x: 1, y: 1 },
      { x: 2, y: 1 },
    ],
    [
      { x: 1, y: 0 },
      { x: 1, y: 1 },
      { x: 1, y: 2 },
      { x: 2, y: 2 },
    ],
    [
      { x: 0, y: 1 },
      { x: 1, y: 1 },
      { x: 2, y: 1 },
      { x: 0, y: 2 },
    ],
    [
      { x: 0, y: 0 },
      { x: 1, y: 0 },
      { x: 1, y: 1 },
      { x: 1, y: 2 },
    ],
  ],
  O: [
    [
      { x: 1, y: 0 },
      { x: 2, y: 0 },
      { x: 1, y: 1 },
      { x: 2, y: 1 },
    ],
  ],
  S: [
    [
      { x: 1, y: 0 },
      { x: 2, y: 0 },
      { x: 0, y: 1 },
      { x: 1, y: 1 },
    ],
    [
      { x: 1, y: 0 },
      { x: 1, y: 1 },
      { x: 2, y: 1 },
      { x: 2, y: 2 },
    ],
    [
      { x: 1, y: 1 },
      { x: 2, y: 1 },
      { x: 0, y: 2 },
      { x: 1, y: 2 },
    ],
    [
      { x: 0, y: 0 },
      { x: 0, y: 1 },
      { x: 1, y: 1 },
      { x: 1, y: 2 },
    ],
  ],
  T: [
    [
      { x: 1, y: 0 },
      { x: 0, y: 1 },
      { x: 1, y: 1 },
      { x: 2, y: 1 },
    ],
    [
      { x: 1, y: 0 },
      { x: 1, y: 1 },
      { x: 2, y: 1 },
      { x: 1, y: 2 },
    ],
    [
      { x: 0, y: 1 },
      { x: 1, y: 1 },
      { x: 2, y: 1 },
      { x: 1, y: 2 },
    ],
    [
      { x: 1, y: 0 },
      { x: 0, y: 1 },
      { x: 1, y: 1 },
      { x: 1, y: 2 },
    ],
  ],
  Z: [
    [
      { x: 0, y: 0 },
      { x: 1, y: 0 },
      { x: 1, y: 1 },
      { x: 2, y: 1 },
    ],
    [
      { x: 2, y: 0 },
      { x: 1, y: 1 },
      { x: 2, y: 1 },
      { x: 1, y: 2 },
    ],
    [
      { x: 0, y: 1 },
      { x: 1, y: 1 },
      { x: 1, y: 2 },
      { x: 2, y: 2 },
    ],
    [
      { x: 1, y: 0 },
      { x: 0, y: 1 },
      { x: 1, y: 1 },
      { x: 0, y: 2 },
    ],
  ],
}

export function createNeonDropBoard(): NeonDropCell[][] {
  return Array.from({ length: NEON_DROP_ROWS }, () =>
    Array<NeonDropCell>(NEON_DROP_COLUMNS).fill(null),
  )
}

function shuffleBag(random: () => number): NeonDropPieceKind[] {
  const bag = [...PIECE_KINDS]
  for (let index = bag.length - 1; index > 0; index -= 1) {
    const target = Math.floor(
      Math.max(0, Math.min(0.999999, random())) * (index + 1),
    )
    ;[bag[index], bag[target]] = [bag[target], bag[index]]
  }
  return bag
}

export function getNeonDropCells(piece: NeonDropPiece): NeonDropPoint[] {
  return SHAPES[piece.kind][piece.rotation % SHAPES[piece.kind].length].map(
    (point) => ({ x: piece.x + point.x, y: piece.y + point.y }),
  )
}

export function createNeonDropPiece(kind: NeonDropPieceKind): NeonDropPiece {
  const points = SHAPES[kind][0]
  const minX = Math.min(...points.map((point) => point.x))
  const maxX = Math.max(...points.map((point) => point.x))
  const minY = Math.min(...points.map((point) => point.y))
  return {
    kind,
    rotation: 0,
    x: Math.floor((NEON_DROP_COLUMNS - (maxX - minX + 1)) / 2) - minX,
    y: -minY,
  }
}

export function canPlaceNeonDropPiece(
  board: NeonDropCell[][],
  piece: NeonDropPiece,
): boolean {
  return getNeonDropCells(piece).every(
    ({ x, y }) =>
      x >= 0 &&
      x < NEON_DROP_COLUMNS &&
      y < NEON_DROP_ROWS &&
      (y < 0 || board[y][x] === null),
  )
}

export function createNeonDropGame(
  random: () => number = Math.random,
): NeonDropGameState {
  const queue = shuffleBag(random)
  const kind = queue.shift() as NeonDropPieceKind
  return {
    active: createNeonDropPiece(kind),
    board: createNeonDropBoard(),
    level: 1,
    lines: 0,
    nextKind: queue[0],
    queue,
    score: 0,
    status: 'playing',
  }
}

export function moveNeonDropPiece(
  state: NeonDropGameState,
  direction: -1 | 1,
): NeonDropActionResult {
  if (state.status !== 'playing')
    return { clearedLines: 0, event: 'none', state }
  const active = { ...state.active, x: state.active.x + direction }
  if (!canPlaceNeonDropPiece(state.board, active)) {
    return { clearedLines: 0, event: 'none', state }
  }
  return { clearedLines: 0, event: 'move', state: { ...state, active } }
}

export function rotateNeonDropPiece(
  state: NeonDropGameState,
): NeonDropActionResult {
  if (state.status !== 'playing')
    return { clearedLines: 0, event: 'none', state }
  const rotation =
    (state.active.rotation + 1) % SHAPES[state.active.kind].length
  for (const offset of [0, -1, 1, -2, 2]) {
    const active = { ...state.active, rotation, x: state.active.x + offset }
    if (canPlaceNeonDropPiece(state.board, active)) {
      return { clearedLines: 0, event: 'rotate', state: { ...state, active } }
    }
  }
  return { clearedLines: 0, event: 'none', state }
}

export function clearCompletedNeonDropLines(board: NeonDropCell[][]): {
  board: NeonDropCell[][]
  clearedLines: number
} {
  const remaining = board.filter((row) => row.some((cell) => cell === null))
  const clearedLines = NEON_DROP_ROWS - remaining.length
  return {
    board: [
      ...Array.from({ length: clearedLines }, () =>
        Array<NeonDropCell>(NEON_DROP_COLUMNS).fill(null),
      ),
      ...remaining.map((row) => [...row]),
    ],
    clearedLines,
  }
}

function lockNeonDropPiece(
  state: NeonDropGameState,
  random: () => number,
): NeonDropActionResult {
  const board = state.board.map((row) => [...row])
  for (const { x, y } of getNeonDropCells(state.active)) {
    if (y < 0) {
      return {
        clearedLines: 0,
        event: 'game-over',
        state: { ...state, status: 'over' },
      }
    }
    board[y][x] = state.active.kind
  }

  const cleared = clearCompletedNeonDropLines(board)
  let queue = state.queue.slice(1)
  if (queue.length === 0) queue = shuffleBag(random)
  const active = createNeonDropPiece(state.nextKind)
  const lines = state.lines + cleared.clearedLines
  const level = Math.floor(lines / NEON_DROP_LINES_PER_LEVEL) + 1
  const score = state.score + LINE_SCORES[cleared.clearedLines] * state.level
  const nextState: NeonDropGameState = {
    ...state,
    active,
    board: cleared.board,
    level,
    lines,
    nextKind: queue[0],
    queue,
    score,
  }

  if (!canPlaceNeonDropPiece(nextState.board, active)) {
    return {
      clearedLines: cleared.clearedLines,
      event: 'game-over',
      state: { ...nextState, status: 'over' },
    }
  }
  return {
    clearedLines: cleared.clearedLines,
    event: cleared.clearedLines > 0 ? 'clear' : 'lock',
    state: nextState,
  }
}

export function stepNeonDrop(
  state: NeonDropGameState,
  random: () => number = Math.random,
  manual = false,
): NeonDropActionResult {
  if (state.status !== 'playing')
    return { clearedLines: 0, event: 'none', state }
  const active = { ...state.active, y: state.active.y + 1 }
  if (canPlaceNeonDropPiece(state.board, active)) {
    return {
      clearedLines: 0,
      event: manual ? 'move' : 'none',
      state: { ...state, active, score: state.score + (manual ? 1 : 0) },
    }
  }
  return lockNeonDropPiece(state, random)
}

export function getNeonDropGhostPiece(state: NeonDropGameState): NeonDropPiece {
  let active = { ...state.active }
  while (canPlaceNeonDropPiece(state.board, { ...active, y: active.y + 1 })) {
    active = { ...active, y: active.y + 1 }
  }
  return active
}

export function hardDropNeonPiece(
  state: NeonDropGameState,
  random: () => number = Math.random,
): NeonDropActionResult {
  if (state.status !== 'playing')
    return { clearedLines: 0, event: 'none', state }
  const active = getNeonDropGhostPiece(state)
  const distance = active.y - state.active.y
  return lockNeonDropPiece(
    { ...state, active, score: state.score + distance * 2 },
    random,
  )
}

export function getNeonDropInterval(level: number): number {
  return Math.max(110, 720 - (Math.max(1, level) - 1) * 55)
}

export function pauseNeonDrop(state: NeonDropGameState): NeonDropGameState {
  return state.status === 'playing' ? { ...state, status: 'paused' } : state
}

export function resumeNeonDrop(state: NeonDropGameState): NeonDropGameState {
  return state.status === 'paused' ? { ...state, status: 'playing' } : state
}
