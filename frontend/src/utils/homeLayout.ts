import type { LaunchablePhoneAppId } from '@/types/apps'
import type { ReorderDirection } from '@/utils/keyboard'

export const HOME_DOCK_CAPACITY = 4
export const HOME_GRID_COLUMNS = 4
export const HOME_GRID_ROWS = 6
export const HOME_GRID_PAGE_SIZE = HOME_GRID_COLUMNS * HOME_GRID_ROWS
export const HOME_FOLDER_PAGE_SIZE = 9
export const HOME_FOLDER_NAME_MAX_LENGTH = 32
export const MAX_HOME_GRID_PAGES = 5
export const HOME_LAYOUT_VERSION = 6
const LEGACY_HOME_GRID_PAGE_SIZE = 20

export type HomeArea = 'dock' | 'grid'

export type HomeFolder = {
  apps: LaunchablePhoneAppId[]
  id: string
  name: string
  type: 'folder'
}

export type HomeItem = HomeFolder | LaunchablePhoneAppId
export type HomeSlot = HomeItem | null

export type HomeLayout = {
  dock: HomeSlot[]
  grid: HomeSlot[]
  hidden: LaunchablePhoneAppId[]
  pageCount: number
  version: typeof HOME_LAYOUT_VERSION
}

export type HomeGridPageCapacities = readonly number[]

export function isHomeFolder(value: unknown): value is HomeFolder {
  if (!value || typeof value !== 'object') return false
  const folder = value as Partial<HomeFolder>
  return (
    folder.type === 'folder' &&
    typeof folder.id === 'string' &&
    typeof folder.name === 'string' &&
    Array.isArray(folder.apps)
  )
}

function isPersistableAppId(value: unknown): value is LaunchablePhoneAppId {
  return typeof value === 'string' && /^[a-z0-9][a-z0-9._-]{1,63}$/.test(value)
}

function isPersistableFolderId(value: unknown): value is string {
  return typeof value === 'string' && /^folder-[a-z0-9-]{6,80}$/.test(value)
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

function cloneItem(item: HomeSlot): HomeSlot {
  return isHomeFolder(item) ? { ...item, apps: [...item.apps] } : item
}

function cloneLayout(layout: HomeLayout): HomeLayout {
  return {
    dock: layout.dock.map(cloneItem),
    grid: layout.grid.map(cloneItem),
    hidden: [...layout.hidden],
    pageCount: layout.pageCount,
    version: HOME_LAYOUT_VERSION,
  }
}

function clampPageCount(value: number): number {
  return Math.max(1, Math.min(MAX_HOME_GRID_PAGES, Math.trunc(value)))
}

function inferredPageCount(slots: readonly HomeSlot[]): number {
  return clampPageCount(Math.ceil(slots.length / HOME_GRID_PAGE_SIZE))
}

function normalizeFolder(folder: HomeFolder): HomeSlot {
  if (folder.apps.length === 0) return null
  if (folder.apps.length === 1) return folder.apps[0]
  return folder
}

function readItem(
  value: unknown,
  availableIds: Set<LaunchablePhoneAppId>,
  folderIds: Set<string>,
  allowFolders: boolean,
): HomeSlot {
  if (
    typeof value === 'string' &&
    availableIds.has(value as LaunchablePhoneAppId)
  ) {
    return value as LaunchablePhoneAppId
  }
  if (
    !allowFolders ||
    !isHomeFolder(value) ||
    !isPersistableFolderId(value.id) ||
    folderIds.has(value.id)
  ) {
    return null
  }

  const apps = readAppIds(value.apps, availableIds)
  if (apps.length === 0) return null
  if (apps.length === 1) return apps[0]
  folderIds.add(value.id)
  return {
    apps,
    id: value.id,
    name: value.name.trim().slice(0, HOME_FOLDER_NAME_MAX_LENGTH),
    type: 'folder',
  }
}

function readSlots(
  value: unknown,
  availableIds: Set<LaunchablePhoneAppId>,
  length: number,
  folderIds: Set<string>,
  allowFolders: boolean,
): HomeSlot[] {
  const slots = createSlots(length)
  if (!Array.isArray(value)) return slots

  for (let index = 0; index < Math.min(value.length, length); index += 1) {
    slots[index] = readItem(value[index], availableIds, folderIds, allowFolders)
  }
  return slots
}

function migrateLegacyGrid(
  value: unknown,
  availableIds: Set<LaunchablePhoneAppId>,
): HomeSlot[] {
  if (!Array.isArray(value)) return createSlots(HOME_GRID_PAGE_SIZE)

  const legacyLength = Math.min(
    value.length,
    LEGACY_HOME_GRID_PAGE_SIZE * MAX_HOME_GRID_PAGES,
  )
  const pageCount = Math.max(
    1,
    Math.ceil(legacyLength / LEGACY_HOME_GRID_PAGE_SIZE),
  )
  const slots = createSlots(pageCount * HOME_GRID_PAGE_SIZE)
  for (let index = 0; index < legacyLength; index += 1) {
    const valueId = value[index]
    if (
      typeof valueId !== 'string' ||
      !availableIds.has(valueId as LaunchablePhoneAppId)
    ) {
      continue
    }

    const page = Math.floor(index / LEGACY_HOME_GRID_PAGE_SIZE)
    const pageIndex = index % LEGACY_HOME_GRID_PAGE_SIZE
    slots[page * HOME_GRID_PAGE_SIZE + pageIndex] =
      valueId as LaunchablePhoneAppId
  }
  return slots
}

function placeInFirstEmptySlot(slots: HomeSlot[], item: HomeItem): void {
  const emptyIndex = slots.indexOf(null)
  if (emptyIndex !== -1) {
    slots[emptyIndex] = cloneItem(item)
    return
  }

  slots.push(...createSlots(HOME_GRID_PAGE_SIZE))
  slots[slots.length - HOME_GRID_PAGE_SIZE] = cloneItem(item)
}

function insertIntoSlot(
  slots: HomeSlot[],
  targetIndex: number,
  item: HomeItem,
): HomeSlot {
  if (slots[targetIndex] === null) {
    slots[targetIndex] = cloneItem(item)
    return null
  }

  const emptyAfter = slots.indexOf(null, targetIndex + 1)
  if (emptyAfter !== -1) {
    for (let index = emptyAfter; index > targetIndex; index -= 1) {
      slots[index] = slots[index - 1]
    }
    slots[targetIndex] = cloneItem(item)
    return null
  }

  const emptyBefore = slots.lastIndexOf(null, targetIndex - 1)
  if (emptyBefore !== -1) {
    for (let index = emptyBefore; index < targetIndex; index += 1) {
      slots[index] = slots[index + 1]
    }
    slots[targetIndex] = cloneItem(item)
    return null
  }

  const displacedItem = cloneItem(slots.at(-1) ?? null)
  for (let index = slots.length - 1; index > targetIndex; index -= 1) {
    slots[index] = slots[index - 1]
  }
  slots[targetIndex] = cloneItem(item)
  return displacedItem
}

function itemContainsApp(item: HomeSlot, appId: LaunchablePhoneAppId): boolean {
  return isHomeFolder(item) ? item.apps.includes(appId) : item === appId
}

function folderLocation(
  layout: HomeLayout,
  folderId: string,
): { area: HomeArea; index: number } | null {
  for (const area of ['grid', 'dock'] as const) {
    const index = layout[area].findIndex(
      (item) => isHomeFolder(item) && item.id === folderId,
    )
    if (index !== -1) return { area, index }
  }
  return null
}

export function getHomeFolder(
  layout: HomeLayout,
  folderId: string,
): HomeFolder | null {
  const location = folderLocation(layout, folderId)
  if (!location) return null
  const item = layout[location.area][location.index]
  return isHomeFolder(item) ? item : null
}

function readPageItems(slots: HomeSlot[], pageStart: number): HomeItem[] {
  return slots
    .slice(pageStart, pageStart + HOME_GRID_PAGE_SIZE)
    .filter((item): item is HomeItem => item !== null)
    .map((item) => cloneItem(item) as HomeItem)
}

function writePageItems(
  slots: HomeSlot[],
  pageStart: number,
  items: HomeItem[],
): void {
  for (let offset = 0; offset < HOME_GRID_PAGE_SIZE; offset += 1) {
    slots[pageStart + offset] = cloneItem(items[offset] ?? null)
  }
}

function compactGridPages(slots: HomeSlot[]): HomeSlot[] {
  const compacted = slots.map(cloneItem)
  for (
    let pageStart = 0;
    pageStart < compacted.length;
    pageStart += HOME_GRID_PAGE_SIZE
  ) {
    writePageItems(compacted, pageStart, readPageItems(compacted, pageStart))
  }
  return compacted
}

type IndexedHomeItem = {
  item: HomeItem
  sourceIndex: number
}

function gridPageCapacity(
  capacities: HomeGridPageCapacities,
  page: number,
): number {
  const capacity = capacities[page - 1]
  return Number.isFinite(capacity)
    ? Math.max(0, Math.min(HOME_GRID_PAGE_SIZE, Math.trunc(capacity)))
    : HOME_GRID_PAGE_SIZE
}

function distributeGridPages(
  slots: readonly HomeSlot[],
  capacities: HomeGridPageCapacities,
  minimumPageCount: number,
): IndexedHomeItem[][] | null {
  const persistedPageCount = Math.max(
    1,
    Math.ceil(slots.length / HOME_GRID_PAGE_SIZE),
  )
  const pages: IndexedHomeItem[][] = []
  let incoming: IndexedHomeItem[] = []
  let pageCount = Math.max(persistedPageCount, minimumPageCount)

  for (let page = 1; page <= pageCount; page += 1) {
    const pageStart = (page - 1) * HOME_GRID_PAGE_SIZE
    const persisted = slots
      .slice(pageStart, pageStart + HOME_GRID_PAGE_SIZE)
      .flatMap((item, offset) =>
        item === null
          ? []
          : [
              {
                item: cloneItem(item) as HomeItem,
                sourceIndex: pageStart + offset,
              },
            ],
      )
    const available = [...incoming, ...persisted]
    const capacity = gridPageCapacity(capacities, page)
    pages.push(available.slice(0, capacity))
    incoming = available.slice(capacity)

    if (
      page === pageCount &&
      incoming.length &&
      pageCount < MAX_HOME_GRID_PAGES
    ) {
      pageCount += 1
    }
  }

  return incoming.length ? null : pages
}

function serializeGridPages(pages: readonly IndexedHomeItem[][]): HomeSlot[] {
  const slots = createSlots(Math.max(1, pages.length) * HOME_GRID_PAGE_SIZE)
  for (const [pageIndex, entries] of pages.entries()) {
    const pageStart = pageIndex * HOME_GRID_PAGE_SIZE
    for (const [offset, entry] of entries.entries()) {
      slots[pageStart + offset] = cloneItem(entry.item)
    }
  }
  return slots
}

export function reflowHomeGridForWidgetChange(
  layout: HomeLayout,
  previousCapacities: HomeGridPageCapacities,
  nextCapacities: HomeGridPageCapacities,
): HomeLayout | null {
  const currentPages = distributeGridPages(
    layout.grid,
    previousCapacities,
    layout.pageCount,
  )
  if (!currentPages) return null

  const materializedGrid = serializeGridPages(currentPages)
  const nextPages = distributeGridPages(
    materializedGrid,
    nextCapacities,
    Math.max(layout.pageCount, currentPages.length),
  )
  if (!nextPages) return null

  const nextGrid = serializeGridPages(nextPages)
  const nextPageCount = clampPageCount(
    Math.max(layout.pageCount, nextPages.length),
  )
  if (
    nextPageCount === layout.pageCount &&
    JSON.stringify(nextGrid) === JSON.stringify(layout.grid)
  ) {
    return layout
  }

  const next = cloneLayout(layout)
  next.grid = nextGrid
  next.pageCount = nextPageCount
  return next
}

export function moveHomeAppToGridPage(
  layout: HomeLayout,
  from: HomeArea,
  sourceIndex: number,
  targetPage: number,
  targetOffset: number,
  capacities: HomeGridPageCapacities = [],
): HomeLayout {
  const sourceSlots = layout[from]
  const sourceItem = sourceSlots[sourceIndex]
  if (
    sourceItem === null ||
    sourceItem === undefined ||
    sourceIndex < 0 ||
    sourceIndex >= sourceSlots.length ||
    !Number.isInteger(targetPage) ||
    targetPage < 1 ||
    targetPage > MAX_HOME_GRID_PAGES ||
    !Number.isFinite(targetOffset) ||
    gridPageCapacity(capacities, targetPage) === 0
  ) {
    return layout
  }

  const pages = distributeGridPages(layout.grid, capacities, targetPage)
  if (!pages) return layout

  let sourcePage = -1
  if (from === 'grid') {
    for (const [pageIndex, entries] of pages.entries()) {
      const entryIndex = entries.findIndex(
        (entry) => entry.sourceIndex === sourceIndex,
      )
      if (entryIndex !== -1) {
        sourcePage = pageIndex + 1
        entries.splice(entryIndex, 1)
        break
      }
    }
    if (sourcePage === -1) return layout
  }

  while (pages.length < targetPage) pages.push([])
  const targetEntries = pages[targetPage - 1]
  const requestedOffset = Math.max(0, Math.trunc(targetOffset))
  targetEntries.splice(Math.min(requestedOffset, targetEntries.length), 0, {
    item: cloneItem(sourceItem) as HomeItem,
    sourceIndex,
  })

  for (let page = targetPage; page <= pages.length; page += 1) {
    const entries = pages[page - 1]
    const capacity = gridPageCapacity(capacities, page)
    if (entries.length <= capacity) continue
    const overflow = entries.splice(capacity)
    if (page >= MAX_HOME_GRID_PAGES) return layout
    if (!pages[page]) pages.push([])
    pages[page].unshift(...overflow)
  }

  const next = cloneLayout(layout)
  next.grid = serializeGridPages(pages)
  next.pageCount = clampPageCount(
    Math.max(layout.pageCount, targetPage, pages.length),
  )
  if (from === 'dock') next.dock[sourceIndex] = null
  if (
    JSON.stringify(next.grid) === JSON.stringify(layout.grid) &&
    JSON.stringify(next.dock) === JSON.stringify(layout.dock)
  ) {
    return layout
  }
  return next
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

  return {
    dock,
    grid,
    hidden: [],
    pageCount: inferredPageCount(grid),
    version: HOME_LAYOUT_VERSION,
  }
}

export function removeDockGridDuplicates(layout: HomeLayout): HomeLayout {
  const dockAppIds = new Set<LaunchablePhoneAppId>()
  for (const item of layout.dock) {
    if (typeof item === 'string') dockAppIds.add(item)
    if (isHomeFolder(item)) {
      for (const appId of item.apps) dockAppIds.add(appId)
    }
  }
  if (!dockAppIds.size) return layout

  let changed = false
  const grid = layout.grid.map((item): HomeSlot => {
    if (typeof item === 'string') {
      if (!dockAppIds.has(item)) return item
      changed = true
      return null
    }
    if (!isHomeFolder(item)) return null

    const apps = item.apps.filter((appId) => !dockAppIds.has(appId))
    if (apps.length === item.apps.length) return cloneItem(item)
    changed = true
    return normalizeFolder({ ...item, apps })
  })
  if (!changed) return layout

  const next = cloneLayout(layout)
  next.grid = compactGridPages(grid)
  return next
}

export function parseHomeLayout(
  value: unknown,
  defaults: HomeLayout,
  installedIds: LaunchablePhoneAppId[],
  preservePersistedIds = true,
): HomeLayout {
  if (!value || typeof value !== 'object') return defaults

  const source = value as Partial<Record<keyof HomeLayout, unknown>>
  const availableIds = new Set(installedIds)
  if (
    preservePersistedIds &&
    (source.version === 3 ||
      source.version === 4 ||
      source.version === 5 ||
      source.version === 6)
  ) {
    for (const collection of [source.dock, source.grid, source.hidden]) {
      if (!Array.isArray(collection)) continue
      for (const item of collection) {
        if (isPersistableAppId(item)) availableIds.add(item)
        if (
          (source.version === 5 || source.version === 6) &&
          isHomeFolder(item)
        ) {
          for (const appId of item.apps) {
            if (isPersistableAppId(appId)) availableIds.add(appId)
          }
        }
      }
    }
  }
  const hidden = readAppIds(source.hidden, availableIds)
  const hiddenIds = new Set(hidden)
  const isLegacyVersionedLayout = source.version === 2 || source.version === 3
  const persistedGridLength = Array.isArray(source.grid)
    ? isLegacyVersionedLayout
      ? Math.ceil(
          Math.min(
            source.grid.length,
            LEGACY_HOME_GRID_PAGE_SIZE * MAX_HOME_GRID_PAGES,
          ) / LEGACY_HOME_GRID_PAGE_SIZE,
        ) * HOME_GRID_PAGE_SIZE
      : Math.min(source.grid.length, HOME_GRID_PAGE_SIZE * MAX_HOME_GRID_PAGES)
    : 0
  const persistedPageCount =
    source.version === 6 &&
    typeof source.pageCount === 'number' &&
    Number.isInteger(source.pageCount)
      ? clampPageCount(source.pageCount)
      : clampPageCount(Math.ceil(persistedGridLength / HOME_GRID_PAGE_SIZE))
  const gridLength = Math.max(
    defaults.grid.length,
    persistedPageCount * HOME_GRID_PAGE_SIZE,
    getGridCapacity(persistedGridLength),
  )
  let grid: HomeSlot[]
  let dock: HomeSlot[]

  if (isLegacyVersionedLayout) {
    grid = migrateLegacyGrid(source.grid, availableIds)
    if (grid.length < gridLength) {
      grid.push(...createSlots(gridLength - grid.length))
    }
    dock = readSlots(
      source.dock,
      availableIds,
      HOME_DOCK_CAPACITY,
      new Set(),
      false,
    )
  } else if (
    source.version === 4 ||
    source.version === 5 ||
    source.version === 6
  ) {
    const folderIds = new Set<string>()
    const allowFolders = source.version === 5 || source.version === 6
    grid = readSlots(
      source.grid,
      availableIds,
      gridLength,
      folderIds,
      allowFolders,
    )
    dock = readSlots(
      source.dock,
      availableIds,
      HOME_DOCK_CAPACITY,
      folderIds,
      allowFolders,
    )
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

  const removeHidden = (item: HomeSlot): HomeSlot => {
    if (typeof item === 'string') return hiddenIds.has(item) ? null : item
    if (!isHomeFolder(item)) return null
    return normalizeFolder({
      ...item,
      apps: item.apps.filter((appId) => !hiddenIds.has(appId)),
    })
  }
  grid = compactGridPages(grid.map(removeHidden))
  dock = dock.map(removeHidden)

  const placedIds = new Set<LaunchablePhoneAppId>(hidden)
  for (const item of [...grid, ...dock]) {
    if (typeof item === 'string') placedIds.add(item)
    if (isHomeFolder(item)) {
      for (const appId of item.apps) placedIds.add(appId)
    }
  }

  for (const item of defaults.grid) {
    if (typeof item === 'string' && !placedIds.has(item)) {
      placeInFirstEmptySlot(grid, item)
      placedIds.add(item)
    }
  }

  return {
    dock: dock.map(cloneItem),
    grid: compactGridPages(grid),
    hidden,
    pageCount: inferredPageCount(grid),
    version: HOME_LAYOUT_VERSION,
  }
}

export function removeHomeApp(
  layout: HomeLayout,
  appId: LaunchablePhoneAppId,
): HomeLayout {
  const removeFromItem = (item: HomeSlot): HomeSlot => {
    if (item === appId) return null
    if (!isHomeFolder(item)) return cloneItem(item)
    return normalizeFolder({
      ...item,
      apps: item.apps.filter((folderAppId) => folderAppId !== appId),
    })
  }
  return {
    dock: layout.dock.map(removeFromItem),
    grid: compactGridPages(layout.grid.map(removeFromItem)),
    hidden: layout.hidden.includes(appId)
      ? [...layout.hidden]
      : [...layout.hidden, appId],
    pageCount: layout.pageCount,
    version: HOME_LAYOUT_VERSION,
  }
}

export function restoreHomeApp(
  layout: HomeLayout,
  appId: LaunchablePhoneAppId,
): HomeLayout {
  if (
    layout.grid.some((item) => itemContainsApp(item, appId)) ||
    layout.dock.some((item) => itemContainsApp(item, appId))
  ) {
    if (!layout.hidden.includes(appId)) return layout
    return {
      ...layout,
      hidden: layout.hidden.filter((id) => id !== appId),
    }
  }
  const grid = layout.grid.map(cloneItem)
  placeInFirstEmptySlot(grid, appId)
  return {
    dock: layout.dock.map(cloneItem),
    grid: compactGridPages(grid),
    hidden: layout.hidden.filter((id) => id !== appId),
    pageCount: inferredPageCount(grid),
    version: HOME_LAYOUT_VERSION,
  }
}

export function addHomePage(layout: HomeLayout): HomeLayout {
  if (layout.pageCount >= MAX_HOME_GRID_PAGES) {
    return layout
  }

  const pageCount = layout.pageCount + 1
  const requiredGridLength = pageCount * HOME_GRID_PAGE_SIZE
  return {
    dock: layout.dock.map(cloneItem),
    grid: [
      ...layout.grid.map(cloneItem),
      ...createSlots(Math.max(0, requiredGridLength - layout.grid.length)),
    ],
    hidden: [...layout.hidden],
    pageCount,
    version: HOME_LAYOUT_VERSION,
  }
}

export function deleteHomePage(layout: HomeLayout, page: number): HomeLayout {
  const pageCount = layout.pageCount
  if (pageCount <= 1 || page < 1 || page > pageCount) return layout

  const pageStart = (page - 1) * HOME_GRID_PAGE_SIZE
  const grid = layout.grid.map(cloneItem)
  const removedItems = grid
    .splice(pageStart, HOME_GRID_PAGE_SIZE)
    .filter((item): item is HomeItem => item !== null)
  if (removedItems.length > grid.filter((item) => item === null).length) {
    return layout
  }
  for (const item of removedItems) placeInFirstEmptySlot(grid, item)

  return {
    dock: layout.dock.map(cloneItem),
    grid: compactGridPages(grid),
    hidden: [...layout.hidden],
    pageCount: pageCount - 1,
    version: HOME_LAYOUT_VERSION,
  }
}

export function moveHomeApp(
  layout: HomeLayout,
  from: HomeArea,
  sourceIndex: number,
  to: HomeArea,
  targetIndex: number,
): HomeLayout {
  const sourceSlots = layout[from]
  const item = sourceSlots[sourceIndex]
  const maximumTargetIndex =
    to === 'grid'
      ? HOME_GRID_PAGE_SIZE * MAX_HOME_GRID_PAGES
      : HOME_DOCK_CAPACITY
  if (
    item === null ||
    item === undefined ||
    sourceIndex < 0 ||
    sourceIndex >= sourceSlots.length ||
    targetIndex < 0 ||
    targetIndex >= maximumTargetIndex ||
    (from === to && sourceIndex === targetIndex)
  ) {
    return layout
  }

  if (to === 'grid') {
    return moveHomeAppToGridPage(
      layout,
      from,
      sourceIndex,
      Math.floor(targetIndex / HOME_GRID_PAGE_SIZE) + 1,
      targetIndex % HOME_GRID_PAGE_SIZE,
    )
  }

  const next = cloneLayout(layout)
  const source = next[from]
  const target = next[to]

  if (from === to) {
    source[sourceIndex] = null
    insertIntoSlot(source, targetIndex, item)
    return next
  }

  source[sourceIndex] = insertIntoSlot(target, targetIndex, item)
  next.grid = compactGridPages(next.grid)
  return next
}

export function createHomeFolder(
  layout: HomeLayout,
  from: HomeArea,
  sourceIndex: number,
  to: HomeArea,
  targetIndex: number,
  folderId: string,
  name: string,
): HomeLayout {
  if (!isPersistableFolderId(folderId) || folderLocation(layout, folderId)) {
    return layout
  }
  const sourceItem = layout[from][sourceIndex]
  const targetItem = layout[to][targetIndex]
  if (
    typeof sourceItem !== 'string' ||
    typeof targetItem !== 'string' ||
    (from === to && sourceIndex === targetIndex)
  ) {
    return layout
  }

  const next = cloneLayout(layout)
  next[from][sourceIndex] = null
  next[to][targetIndex] = {
    apps: [targetItem, sourceItem],
    id: folderId,
    name: name.trim().slice(0, HOME_FOLDER_NAME_MAX_LENGTH),
    type: 'folder',
  }
  next.grid = compactGridPages(next.grid)
  return next
}

export function addHomeAppToFolder(
  layout: HomeLayout,
  from: HomeArea,
  sourceIndex: number,
  folderId: string,
): HomeLayout {
  const sourceItem = layout[from][sourceIndex]
  const location = folderLocation(layout, folderId)
  if (typeof sourceItem !== 'string' || !location) return layout
  if (location.area === from && location.index === sourceIndex) return layout

  const next = cloneLayout(layout)
  const folder = next[location.area][location.index]
  if (!isHomeFolder(folder)) return layout
  next[from][sourceIndex] = null
  folder.apps.push(sourceItem)
  next.grid = compactGridPages(next.grid)
  return next
}

export function renameHomeFolder(
  layout: HomeLayout,
  folderId: string,
  name: string,
): HomeLayout {
  const location = folderLocation(layout, folderId)
  if (!location) return layout
  const next = cloneLayout(layout)
  const folder = next[location.area][location.index]
  if (!isHomeFolder(folder)) return layout
  const nextName = name.trim().slice(0, HOME_FOLDER_NAME_MAX_LENGTH)
  if (folder.name === nextName) return layout
  folder.name = nextName
  return next
}

export function moveHomeFolderApp(
  layout: HomeLayout,
  folderId: string,
  sourceIndex: number,
  targetIndex: number,
): HomeLayout {
  const location = folderLocation(layout, folderId)
  if (!location) return layout
  const folder = layout[location.area][location.index]
  if (
    !isHomeFolder(folder) ||
    sourceIndex < 0 ||
    sourceIndex >= folder.apps.length ||
    targetIndex < 0 ||
    targetIndex >= folder.apps.length ||
    sourceIndex === targetIndex
  ) {
    return layout
  }

  const next = cloneLayout(layout)
  const nextFolder = next[location.area][location.index]
  if (!isHomeFolder(nextFolder)) return layout
  const sourceApp = nextFolder.apps[sourceIndex]
  nextFolder.apps[sourceIndex] = nextFolder.apps[targetIndex]
  nextFolder.apps[targetIndex] = sourceApp
  return next
}

export function extractHomeFolderApp(
  layout: HomeLayout,
  folderId: string,
  sourceIndex: number,
  to: HomeArea,
  targetIndex: number,
): HomeLayout {
  const location = folderLocation(layout, folderId)
  const target = layout[to][targetIndex]
  if (
    !location ||
    target !== null ||
    (location.area === to && location.index === targetIndex)
  ) {
    return layout
  }
  const folder = layout[location.area][location.index]
  if (
    !isHomeFolder(folder) ||
    sourceIndex < 0 ||
    sourceIndex >= folder.apps.length
  ) {
    return layout
  }

  const next = cloneLayout(layout)
  const nextFolder = next[location.area][location.index]
  if (!isHomeFolder(nextFolder)) return layout
  const [appId] = nextFolder.apps.splice(sourceIndex, 1)
  next[to][targetIndex] = appId
  next[location.area][location.index] = normalizeFolder(nextFolder)
  next.grid = compactGridPages(next.grid)
  return next
}

export function homeKeyboardTarget(
  layout: HomeLayout,
  area: HomeArea,
  sourceIndex: number,
  direction: ReorderDirection,
): number | null {
  const source = layout[area]
  if (!source[sourceIndex]) return null

  if (area === 'dock') {
    if (direction !== 'left' && direction !== 'right') return null
    const targetIndex = sourceIndex + (direction === 'left' ? -1 : 1)
    return targetIndex >= 0 && targetIndex < source.length ? targetIndex : null
  }

  const column = sourceIndex % HOME_GRID_COLUMNS
  if (direction === 'left' && column === 0) return null
  if (direction === 'right' && column === HOME_GRID_COLUMNS - 1) return null
  const deltas: Record<ReorderDirection, number> = {
    down: HOME_GRID_COLUMNS,
    left: -1,
    right: 1,
    up: -HOME_GRID_COLUMNS,
  }
  const targetIndex = sourceIndex + deltas[direction]
  return targetIndex >= 0 && targetIndex < source.length ? targetIndex : null
}
