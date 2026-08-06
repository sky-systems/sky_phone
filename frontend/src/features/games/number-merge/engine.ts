import type {
  NumberMergeDirection,
  NumberMergeGameState,
  NumberMergeMoveResult,
  NumberMergeTile,
} from './types'

export const NUMBER_MERGE_BOARD_SIZE = 4
export const NUMBER_MERGE_WIN_VALUE = 2048

type Point = {
  column: number
  row: number
}

function pointKey(point: Point): string {
  return `${point.row}:${point.column}`
}

function linePoints(direction: NumberMergeDirection, line: number): Point[] {
  return Array.from({ length: NUMBER_MERGE_BOARD_SIZE }, (_, offset) => {
    if (direction === 'left') return { column: offset, row: line }
    if (direction === 'right') {
      return { column: NUMBER_MERGE_BOARD_SIZE - 1 - offset, row: line }
    }
    if (direction === 'up') return { column: line, row: offset }
    return { column: line, row: NUMBER_MERGE_BOARD_SIZE - 1 - offset }
  })
}

function availablePoints(tiles: NumberMergeTile[]): Point[] {
  const occupied = new Set(tiles.map(pointKey))
  const points: Point[] = []

  for (let row = 0; row < NUMBER_MERGE_BOARD_SIZE; row += 1) {
    for (let column = 0; column < NUMBER_MERGE_BOARD_SIZE; column += 1) {
      const point = { column, row }
      if (!occupied.has(pointKey(point))) points.push(point)
    }
  }

  return points
}

function isPowerOfTwo(value: number): boolean {
  return value >= 2 && Number.isInteger(Math.log2(value))
}

export function spawnNumberMergeTile(
  state: NumberMergeGameState,
  random: () => number = Math.random,
): NumberMergeGameState {
  const points = availablePoints(state.tiles)
  if (points.length === 0) return state

  const pointIndex = Math.min(
    points.length - 1,
    Math.floor(random() * points.length),
  )
  const point = points[pointIndex]
  const tile: NumberMergeTile = {
    ...point,
    id: state.nextTileId,
    isNew: true,
    merged: false,
    value: random() < 0.9 ? 2 : 4,
  }

  return {
    ...state,
    nextTileId: state.nextTileId + 1,
    tiles: [...state.tiles, tile],
  }
}

export function canMoveNumberMerge(state: NumberMergeGameState): boolean {
  if (state.tiles.length < NUMBER_MERGE_BOARD_SIZE ** 2) return true

  const values = new Map(state.tiles.map((tile) => [pointKey(tile), tile.value]))
  for (const tile of state.tiles) {
    const right = values.get(pointKey({ column: tile.column + 1, row: tile.row }))
    const down = values.get(pointKey({ column: tile.column, row: tile.row + 1 }))
    if (right === tile.value || down === tile.value) return true
  }

  return false
}

export function createNumberMergeGame(
  random: () => number = Math.random,
): NumberMergeGameState {
  const empty: NumberMergeGameState = {
    hasWon: false,
    keepPlaying: false,
    nextTileId: 1,
    score: 0,
    status: 'playing',
    tiles: [],
  }
  return spawnNumberMergeTile(spawnNumberMergeTile(empty, random), random)
}

export function moveNumberMerge(
  state: NumberMergeGameState,
  direction: NumberMergeDirection,
  random: () => number = Math.random,
): NumberMergeMoveResult {
  if (state.status !== 'playing') {
    return { changed: false, gained: 0, state }
  }

  const tileByPoint = new Map(state.tiles.map((tile) => [pointKey(tile), tile]))
  const nextTiles: NumberMergeTile[] = []
  let gained = 0

  for (let line = 0; line < NUMBER_MERGE_BOARD_SIZE; line += 1) {
    const points = linePoints(direction, line)
    const tiles = points
      .map((point) => tileByPoint.get(pointKey(point)))
      .filter((tile): tile is NumberMergeTile => tile !== undefined)

    let sourceIndex = 0
    let targetIndex = 0
    while (sourceIndex < tiles.length) {
      const tile = tiles[sourceIndex]
      const nextTile = tiles[sourceIndex + 1]
      const target = points[targetIndex]

      if (nextTile?.value === tile.value) {
        const value = tile.value * 2
        nextTiles.push({
          ...tile,
          ...target,
          isNew: false,
          merged: true,
          value,
        })
        gained += value
        sourceIndex += 2
      } else {
        nextTiles.push({
          ...tile,
          ...target,
          isNew: false,
          merged: false,
        })
        sourceIndex += 1
      }
      targetIndex += 1
    }
  }

  const changed =
    nextTiles.length !== state.tiles.length ||
    nextTiles.some((tile) => {
      const previous = state.tiles.find((candidate) => candidate.id === tile.id)
      return (
        !previous ||
        previous.column !== tile.column ||
        previous.row !== tile.row ||
        previous.value !== tile.value
      )
    })

  if (!changed) return { changed: false, gained: 0, state }

  let nextState = spawnNumberMergeTile(
    {
      ...state,
      score: state.score + gained,
      tiles: nextTiles,
    },
    random,
  )
  const reachedWin = nextState.tiles.some(
    (tile) => tile.value >= NUMBER_MERGE_WIN_VALUE,
  )
  const firstWin = reachedWin && !state.hasWon
  nextState = {
    ...nextState,
    hasWon: state.hasWon || reachedWin,
    status: firstWin
      ? 'won'
      : canMoveNumberMerge(nextState)
        ? 'playing'
        : 'game-over',
  }

  return { changed: true, gained, state: nextState }
}

export function continueNumberMerge(
  state: NumberMergeGameState,
): NumberMergeGameState {
  if (state.status !== 'won') return state
  return {
    ...state,
    keepPlaying: true,
    status: canMoveNumberMerge(state) ? 'playing' : 'game-over',
  }
}

export function isNumberMergeGameState(
  value: unknown,
): value is NumberMergeGameState {
  if (!value || typeof value !== 'object') return false
  const game = value as Partial<NumberMergeGameState>
  if (
    typeof game.hasWon !== 'boolean' ||
    typeof game.keepPlaying !== 'boolean' ||
    !Number.isInteger(game.nextTileId) ||
    (game.nextTileId ?? 0) < 1 ||
    !Number.isInteger(game.score) ||
    (game.score ?? -1) < 0 ||
    !['game-over', 'playing', 'won'].includes(game.status ?? '') ||
    !Array.isArray(game.tiles) ||
    game.tiles.length > NUMBER_MERGE_BOARD_SIZE ** 2
  ) {
    return false
  }

  const ids = new Set<number>()
  const points = new Set<string>()
  for (const candidate of game.tiles) {
    if (!candidate || typeof candidate !== 'object') return false
    const tile = candidate as Partial<NumberMergeTile>
    if (
      !Number.isInteger(tile.id) ||
      (tile.id ?? 0) < 1 ||
      !Number.isInteger(tile.column) ||
      (tile.column ?? -1) < 0 ||
      (tile.column ?? NUMBER_MERGE_BOARD_SIZE) >= NUMBER_MERGE_BOARD_SIZE ||
      !Number.isInteger(tile.row) ||
      (tile.row ?? -1) < 0 ||
      (tile.row ?? NUMBER_MERGE_BOARD_SIZE) >= NUMBER_MERGE_BOARD_SIZE ||
      typeof tile.value !== 'number' ||
      !isPowerOfTwo(tile.value) ||
      typeof tile.isNew !== 'boolean' ||
      typeof tile.merged !== 'boolean'
    ) {
      return false
    }

    const position = pointKey(tile as Point)
    if (ids.has(tile.id as number) || points.has(position)) return false
    ids.add(tile.id as number)
    points.add(position)
  }

  return Math.max(0, ...ids) < (game.nextTileId as number)
}
