import type { LaunchablePhoneAppId } from '@/types/apps'

export const HOME_DOCK_CAPACITY = 4

export type HomeArea = 'dock' | 'grid'

export type HomeLayout = {
  dock: LaunchablePhoneAppId[]
  grid: LaunchablePhoneAppId[]
  hidden: LaunchablePhoneAppId[]
}

function readAppIds(
  value: unknown,
  availableIds: Set<LaunchablePhoneAppId>,
  maximum = Number.POSITIVE_INFINITY,
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
    if (ids.length === maximum) break
  }
  return ids
}

export function createDefaultHomeLayout(
  installedIds: LaunchablePhoneAppId[],
  defaultGridIds: LaunchablePhoneAppId[],
  defaultDockIds: LaunchablePhoneAppId[],
): HomeLayout {
  const installed = new Set(installedIds)
  return {
    dock: defaultDockIds
      .filter((id) => installed.has(id))
      .slice(0, HOME_DOCK_CAPACITY),
    grid: defaultGridIds.filter((id) => installed.has(id)),
    hidden: [],
  }
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
  const dock = readAppIds(source.dock, availableIds, HOME_DOCK_CAPACITY).filter(
    (id) => !hiddenIds.has(id),
  )
  const grid = readAppIds(source.grid, availableIds).filter(
    (id) => !hiddenIds.has(id),
  )
  const placedIds = new Set([...dock, ...grid, ...hidden])

  for (const id of defaults.grid) {
    if (!placedIds.has(id)) {
      grid.push(id)
      placedIds.add(id)
    }
  }
  for (const id of defaults.dock) {
    if (!placedIds.has(id) && dock.length < HOME_DOCK_CAPACITY) {
      dock.push(id)
      placedIds.add(id)
    }
  }

  return { dock, grid, hidden }
}

export function removeHomeApp(
  layout: HomeLayout,
  appId: LaunchablePhoneAppId,
): HomeLayout {
  return {
    dock: layout.dock.filter((id) => id !== appId),
    grid: layout.grid.filter((id) => id !== appId),
    hidden: layout.hidden.includes(appId)
      ? [...layout.hidden]
      : [...layout.hidden, appId],
  }
}

export function restoreHomeApp(
  layout: HomeLayout,
  appId: LaunchablePhoneAppId,
): HomeLayout {
  if (layout.grid.includes(appId) || layout.dock.includes(appId)) return layout
  return {
    dock: [...layout.dock],
    grid: [...layout.grid, appId],
    hidden: layout.hidden.filter((id) => id !== appId),
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
  }
  const source = next[from]
  const sourceIndex = source.indexOf(appId)
  if (sourceIndex === -1) return layout

  source.splice(sourceIndex, 1)
  const target = next[to]
  const duplicateIndex = target.indexOf(appId)
  if (duplicateIndex !== -1) target.splice(duplicateIndex, 1)

  const insertionIndex = Math.max(0, Math.min(targetIndex, target.length))
  if (to === 'dock' && target.length >= HOME_DOCK_CAPACITY) {
    const displacedIndex = Math.min(insertionIndex, target.length - 1)
    const [displacedApp] = target.splice(displacedIndex, 1, appId)
    if (
      from === 'grid' &&
      displacedApp !== undefined &&
      !source.includes(displacedApp)
    ) {
      source.splice(Math.min(sourceIndex, source.length), 0, displacedApp)
    }
    return next
  }

  target.splice(insertionIndex, 0, appId)
  return next
}
