import type { LaunchablePhoneAppId } from '@/types/apps'

export const HOME_DOCK_CAPACITY = 4
export const HOME_GRID_PAGE_SIZE = 20
const MAX_HOME_GRID_PAGES = 5

export type HomeArea = 'dock' | 'grid'
export type HomeSlot = LaunchablePhoneAppId | null

export type HomeLayout = {
  dock: HomeSlot[]
  grid: HomeSlot[]
  hidden: LaunchablePhoneAppId[]
  version: 2
}

function readAppIds(
  value: unknown,
  availableIds: Set<LaunchablePhoneAppId>,
): LaunchablePhoneAppId[] {
  if (!Array.isArray(value)) return []

  const ids: LaunchablePhoneAppId[] = []
  for (const valueId of value) {
    if (
      typeof valueId === 'string' &&
      availableIds.has(valueId as LaunchablePhoneAppId) &&
      !ids.includes(valueId as LaunchablePhoneAppId)
    ) {
      ids.push(valueId as LaunchablePhoneAppId)
    }
  }
  return ids
}

function createSlots(length: number): HomeSlot[] {
  return Array.from({ length }, () => null)
}

function getGridCapacity(itemCount: number): number {
  return Math.max(
    HOME_GRID_PAGE_SIZE,
    Math.ceil(itemCount / HOME_GRID_PAGE_SIZE) * HOME_GRID_PAGE_SIZE,
  )
}

function readSlots(
  value: unknown,
  availableIds: Set<LaunchablePhoneAppId>,
  length: number,
): HomeSlot[] {
  const slots = createSlots(length)
  if (!Array.isArray(value)) return slots

  const usedIds = new Set<LaunchablePhoneAppId>()
  for (let index = 0; index < Math.min(value.length, length); index += 1) {
    const valueId = value[index]
    if (
      typeof valueId === 'string' &&
      availableIds.has(valueId as LaunchablePhoneAppId) &&
      !usedIds.has(valueId as LaunchablePhoneAppId)
    ) {
      slots[index] = valueId as LaunchablePhoneAppId
      usedIds.add(valueId as LaunchablePhoneAppId)
    }
  }
  return slots
}

function placeInFirstEmptySlot(
  slots: HomeSlot[],
  appId: LaunchablePhoneAppId,
): void {
  const emptyIndex = slots.indexOf(null)
  if (emptyIndex !== -1) {
    slots[emptyIndex] = appId
    return
  }

  slots.push(...createSlots(HOME_GRID_PAGE_SIZE))
  slots[slots.length - HOME_GRID_PAGE_SIZE] = appId
}

export function createDefaultHomeLayout(
  installedIds: LaunchablePhoneAppId[],
  defaultGridIds: LaunchablePhoneAppId[],
  defaultDockIds: LaunchablePhoneAppId[],
): HomeLayout {
  const installed = new Set(installedIds)
  const gridIds = defaultGridIds.filter((id) => installed.has(id))
  const grid = createSlots(getGridCapacity(gridIds.length))
  for (let index = 0; index < gridIds.length; index += 1) {
    grid[index] = gridIds[index]
  }

  const dock = createSlots(HOME_DOCK_CAPACITY)
  for (const [index, id] of defaultDockIds
    .filter((id) => installed.has(id))
    .slice(0, HOME_DOCK_CAPACITY)
    .entries()) {
    dock[index] = id
  }

  return { dock, grid, hidden: [], version: 2 }
}

export function parseHomeLayout(
  value: unknown,
  defaults: HomeLayout,
  installedIds: LaunchablePhoneAppId[],
): HomeLayout {
  if (!value || typeof value !== 'object') return defaults

  const source = value as Partial<Record<keyof HomeLayout, unknown>>
  const availableIds = new Set(installedIds)
  const hidden = readAppIds(source.hidden, availableIds)
  const hiddenIds = new Set(hidden)
  const persistedGridLength = Array.isArray(source.grid)
    ? Math.min(source.grid.length, HOME_GRID_PAGE_SIZE * MAX_HOME_GRID_PAGES)
    : 0
  const gridLength = Math.max(
    defaults.grid.length,
    getGridCapacity(persistedGridLength),
  )
  let grid: HomeSlot[]
  let dock: HomeSlot[]

  if (source.version === 2) {
    grid = readSlots(source.grid, availableIds, gridLength)
    dock = readSlots(source.dock, availableIds, HOME_DOCK_CAPACITY)
  } else {
    grid = createSlots(gridLength)
    for (const id of readAppIds(source.grid, availableIds)) {
      placeInFirstEmptySlot(grid, id)
    }
    dock = createSlots(HOME_DOCK_CAPACITY)
    for (const [index, id] of readAppIds(source.dock, availableIds)
      .slice(0, HOME_DOCK_CAPACITY)
      .entries()) {
      dock[index] = id
    }
  }

  grid = grid.map((id) => (id && !hiddenIds.has(id) ? id : null))
  dock = dock.map((id) => (id && !hiddenIds.has(id) ? id : null))
  const placedIds = new Set(
    [...grid, ...dock, ...hidden].filter(
      (id): id is LaunchablePhoneAppId => id !== null,
    ),
  )

  for (const id of defaults.grid) {
    if (id && !placedIds.has(id)) {
      placeInFirstEmptySlot(grid, id)
      placedIds.add(id)
    }
  }

  return { dock, grid, hidden, version: 2 }
}

export function removeHomeApp(
  layout: HomeLayout,
  appId: LaunchablePhoneAppId,
): HomeLayout {
  return {
    dock: layout.dock.map((id) => (id === appId ? null : id)),
    grid: layout.grid.map((id) => (id === appId ? null : id)),
    hidden: layout.hidden.includes(appId)
      ? [...layout.hidden]
      : [...layout.hidden, appId],
    version: 2,
  }
}

export function restoreHomeApp(
  layout: HomeLayout,
  appId: LaunchablePhoneAppId,
): HomeLayout {
  if (layout.grid.includes(appId) || layout.dock.includes(appId)) return layout
  const grid = [...layout.grid]
  placeInFirstEmptySlot(grid, appId)
  return {
    dock: [...layout.dock],
    grid,
    hidden: layout.hidden.filter((id) => id !== appId),
    version: 2,
  }
}

export function moveHomeApp(
  layout: HomeLayout,
  appId: LaunchablePhoneAppId,
  from: HomeArea,
  to: HomeArea,
  targetIndex: number,
): HomeLayout {
  const next: HomeLayout = {
    dock: [...layout.dock],
    grid: [...layout.grid],
    hidden: layout.hidden.filter((id) => id !== appId),
    version: 2,
  }
  const source = next[from]
  const sourceIndex = source.indexOf(appId)
  const target = next[to]
  if (sourceIndex === -1 || targetIndex < 0 || targetIndex >= target.length) {
    return layout
  }

  if (from === to) {
    const displacedApp = source[targetIndex]
    source[targetIndex] = appId
    source[sourceIndex] = displacedApp
    return next
  }

  const duplicateIndex = target.indexOf(appId)
  if (duplicateIndex !== -1) {
    target[duplicateIndex] = null
  }

  const displacedApp = target[targetIndex]
  source[sourceIndex] =
    displacedApp &&
    displacedApp !== appId &&
    !source.some((id, index) => id === displacedApp && index !== sourceIndex)
      ? displacedApp
      : null
  target[targetIndex] = appId
  return next
}
