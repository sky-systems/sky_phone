<script setup lang="ts">
import { Check, Pencil, Plus, Search, Trash2, X } from 'lucide-vue-next'
import { kButton, kGlass } from 'konsta/vue'
import { computed, nextTick, onBeforeUnmount, ref, watch } from 'vue'

import AppIcon from '@/components/AppIcon.vue'
import HomeFolderIcon from '@/components/HomeFolderIcon.vue'
import HomeFolderOverlay from '@/components/HomeFolderOverlay.vue'
import SpringboardWidgetGrid from '@/components/SpringboardWidgetGrid.vue'
import WidgetConfigSheet from '@/components/WidgetConfigSheet.vue'
import WidgetPickerSheet from '@/components/WidgetPickerSheet.vue'
import { getPhoneAppLabel, PHONE_APPS } from '@/config/apps'
import { useAppStoreStore } from '@/stores/app-store'
import { usePhoneStore } from '@/stores/phone'
import { useWidgetsStore } from '@/stores/widgets'
import type { PhoneAppCategory, PhoneAppDefinition } from '@/types/apps'
import type { LaunchablePhoneAppId } from '@/types/apps'
import type {
  WidgetKind,
  WidgetLayout,
  WidgetSettings,
  WidgetSize,
} from '@/types/widgets'
import {
  SkyActionButton,
  SkyActionGroup,
  SkyActionSheet,
  SkyActionsLabel,
  SkyProvider,
} from '@/ui'
import {
  deleteHomePage as previewHomePageDelete,
  getHomeFolder,
  HOME_GRID_PAGE_SIZE,
  HOME_GRID_ROWS,
  homeKeyboardTarget,
  isHomeFolder,
  MAX_HOME_GRID_PAGES,
  type HomeArea,
  type HomeFolder,
  type HomeItem,
} from '@/utils/homeLayout'
import type { ReorderDirection } from '@/utils/keyboard'
import {
  readPhoneViewportGeometry,
  type PhoneViewportGeometry,
  type PhoneViewportRect,
} from '@/utils/phoneViewportGeometry'
import { layoutSpringboardHomePages } from '@/utils/springboardLayout'
import {
  maximumRenderedWidgetPage,
  nearestSpringboardRectIndex,
  resolveSpringboardEdgeTurn,
  resolveSpringboardHomeEdgeTurn,
  springboardSwipeIntent,
  springboardViewportDeltaToLocal,
} from '@/utils/springboardDrag'
import {
  addWidget as previewWidgetAdd,
  deleteWidgetPage as previewWidgetPageDelete,
  moveWidget as previewWidgetMove,
  removeWidget as previewWidgetRemove,
  resizeWidget as previewWidgetResize,
  WIDGET_GRID_COLUMNS,
  widgetKeyboardTarget,
  widgetOccupiedCells,
} from '@/utils/widgetLayout'

const APP_LIBRARY_CATEGORIES: PhoneAppCategory[] = [
  'games',
  'productivity',
  'social',
  'utilities',
  'shopping',
]
const HOME_FOLDER_HOVER_DURATION = 900
const HOME_EDGE_PAGE_TURN_DELAY = 420
const emit = defineEmits<{
  editModeChange: [editing: boolean]
}>()
const phone = usePhoneStore()
const appStore = useAppStoreStore()
const widgets = useWidgetsStore()
const wallpaperStyle = computed<Record<string, string>>(() => {
  const style: Record<string, string> = {}
  const imageUrl = phone.preferences.settings.wallpaperImageUrl
  if (phone.preferences.settings.wallpaper === 'custom' && imageUrl) {
    style['--phone-wallpaper-image'] = `url(${JSON.stringify(imageUrl)})`
  }
  return style
})
const searchQuery = ref('')
const searchFocused = ref(false)
const showAllApps = ref(false)
const editMode = ref(false)
const widgetPickerOpened = ref(false)
const widgetActionId = ref<string | null>(null)
const widgetConfigId = ref<string | null>(null)
const draggingWidgetId = ref<string | null>(null)
const widgetDragGrip = ref<{ x: number; y: number } | null>(null)
const widgetDragPreview = ref<{
  column: number
  id: string
  page: number
  row: number
} | null>(null)
const dragOffset = ref(0)
const dragging = ref(false)
const pageTransitioning = ref(false)
const draggingHomeApp = ref<{
  area: HomeArea
  index: number
} | null>(null)
const homeDragLayer = ref<HTMLElement | null>(null)
const homeDragVisualActive = ref(false)
const temporaryHomePage = ref<number | null>(null)
const openedFolderId = ref<string | null>(null)
const folderDraggingOutside = ref(false)
const renameFolderOnOpenId = ref<string | null>(null)
const folderHoverTarget = ref('')
let pointerStart = 0
let pointerStartY = 0
let pointerStartedAt = 0
let pointerPageStart = 0
let backgroundHoldTimer: number | undefined
let blankTapCandidate = false
let widgetPreviewTimer: number | undefined
let pendingWidgetPointer: { clientX: number; clientY: number } | null = null
let lastWidgetPointer: { clientX: number; clientY: number } | null = null
let edgePageTimer: number | undefined
let edgePageDirection = 0
let edgePageLocked = false
let folderHoverTimer: number | undefined
let lastHomePointer: { clientX: number; clientY: number } | null = null
let homeDragGhost: HTMLElement | null = null
let homeDragGrip: { x: number; y: number } | null = null
let homeDragGeometry: PhoneViewportGeometry | null = null
let homeDragClipBounds: PhoneViewportRect | null = null
let homeDragPreviewBounds: PhoneViewportRect | null = null

const installedApps = computed(() =>
  PHONE_APPS.filter((app) => appStore.isInstalled(app.id)),
)
const installedAppsById = computed(
  () => new Map(installedApps.value.map((app) => [app.id, app])),
)
const hiddenApps = computed(() =>
  installedApps.value.filter((app) =>
    appStore.homeLayout.hidden.includes(app.id),
  ),
)

function homeGridCapacitiesFor(layout: WidgetLayout): number[] {
  return Array.from({ length: MAX_HOME_GRID_PAGES }, (_, pageIndex) =>
    Math.max(
      0,
      HOME_GRID_PAGE_SIZE -
        widgetOccupiedCells(layout.instances, pageIndex + 1).size,
    ),
  )
}

const previewWidgetLayout = computed(() => {
  const preview = widgetDragPreview.value
  return preview
    ? previewWidgetMove(
        widgets.layout,
        preview.id,
        preview.page,
        preview.column,
        preview.row,
      )
    : widgets.layout
})
const homeGridCapacities = computed(() => homeGridCapacitiesFor(widgets.layout))
const appPages = computed(() => {
  const maxWidgetPage = maximumRenderedWidgetPage(
    widgets.layout.instances.map((instance) => instance.page),
    previewWidgetLayout.value.instances.map((instance) => instance.page),
  )
  const persistedHomePages = appStore.homeLayout.pageCount
  const lastHomePage = Math.max(
    maxWidgetPage,
    persistedHomePages,
    temporaryHomePage.value ?? 1,
  )
  const occupiedByPage = new Map<number, Set<number>>()
  for (let page = 1; page <= lastHomePage; page += 1) {
    const occupied = widgetOccupiedCells(
      previewWidgetLayout.value.instances,
      page,
    )
    if (widgetDragPreview.value) {
      for (const cell of widgetOccupiedCells(widgets.layout.instances, page)) {
        occupied.add(cell)
      }
    }
    occupiedByPage.set(page, occupied)
  }
  return layoutSpringboardHomePages(
    appStore.homeLayout.grid,
    occupiedByPage,
    lastHomePage,
    (item) => isHomeFolder(item) || installedAppsById.value.has(item),
  ).map((page) => ({
    ...page,
    cells: page.cells.map((cell, cellIndex) => {
      if (!cell) {
        return {
          app: null,
          folder: null,
          renderKey: `grid-occupied-${page.page}-${cellIndex}`,
          sourceIndex: null,
          targetOffset: null,
          targetPage: page.page,
        }
      }
      return {
        app:
          typeof cell.item === 'string'
            ? (installedAppsById.value.get(cell.item) ?? null)
            : null,
        folder: isHomeFolder(cell.item) ? cell.item : null,
        renderKey: cell.renderKey,
        sourceIndex: cell.sourceIndex,
        targetOffset: cell.targetOffset,
        targetPage: cell.targetPage,
      }
    }),
  }))
})
const pageCount = computed(() => appPages.value.length + 2)
const libraryPage = computed(() => pageCount.value - 1)
const isAppPage = computed(
  () => phone.currentPage > 0 && phone.currentPage < libraryPage.value,
)
const isEditablePage = computed(
  () => phone.currentPage >= 0 && phone.currentPage < libraryPage.value,
)
const canAddHomePage = computed(
  () => appStore.homeLayout.pageCount < MAX_HOME_GRID_PAGES,
)
const addingHomePage = ref(false)
const persistedHomePageCount = computed(() => appStore.homeLayout.pageCount)
const canDeleteCurrentPage = computed(() => {
  if (phone.currentPage < 1 || persistedHomePageCount.value <= 1) return false
  const remainingPages = persistedHomePageCount.value - 1
  return (
    previewHomePageDelete(appStore.homeLayout, phone.currentPage) !==
      appStore.homeLayout &&
    previewWidgetPageDelete(
      widgets.layout,
      phone.currentPage,
      remainingPages,
    ) !== widgets.layout
  )
})
const dockSlots = computed(() =>
  appStore.homeLayout.dock.map((item, index) => ({
    app:
      typeof item === 'string'
        ? (installedAppsById.value.get(item) ?? null)
        : null,
    folder: isHomeFolder(item) ? item : null,
    index,
  })),
)
const openedFolder = computed(() =>
  openedFolderId.value
    ? getHomeFolder(appStore.homeLayout, openedFolderId.value)
    : null,
)
const folderOverlayVisible = computed(
  () => openedFolder.value !== null && !folderDraggingOutside.value,
)
const openedFolderApps = computed(() =>
  openedFolder.value
    ? openedFolder.value.apps.flatMap((appId, index) => {
        const app = installedAppsById.value.get(appId)
        return app ? [{ app, index }] : []
      })
    : [],
)
const filteredApps = computed(() => {
  const query = searchQuery.value.trim().toLocaleLowerCase(phone.lang)
  if (!query) return installedApps.value
  return installedApps.value.filter((app) =>
    getPhoneAppLabel(app, phone.t)
      .toLocaleLowerCase(phone.lang)
      .includes(query),
  )
})
const appGroups = computed(() => {
  const suggestions = [...installedApps.value]
    .sort(
      (a, b) =>
        (appStore.launchCounts[b.id] ?? 0) -
          (appStore.launchCounts[a.id] ?? 0) || a.gridOrder - b.gridOrder,
    )
    .slice(0, 7)
  const recentlyAdded = [...installedApps.value]
    .sort((a, b) => b.gridOrder - a.gridOrder)
    .slice(0, 7)
  const groups = [
    { apps: suggestions, key: 'suggestions' },
    { apps: recentlyAdded, key: 'recentlyAdded' },
    ...APP_LIBRARY_CATEGORIES.map((category) => ({
      apps: installedApps.value.filter((app) => app.category === category),
      key: category,
    })),
  ]
  return groups
    .filter((group) => group.apps.length > 0)
    .map((group) => ({
      ...group,
      apps: group.apps.slice(0, 3),
      moreApps: group.apps.slice(3),
    }))
})
const alphabeticalGroups = computed(() => {
  const groups: Array<{ apps: PhoneAppDefinition[]; letter: string }> = []
  for (const app of [...filteredApps.value].sort((a, b) =>
    getPhoneAppLabel(a, phone.t).localeCompare(
      getPhoneAppLabel(b, phone.t),
      phone.lang,
    ),
  )) {
    const letter = getPhoneAppLabel(app, phone.t)
      .charAt(0)
      .toLocaleUpperCase(phone.lang)
    const group = groups.find((candidate) => candidate.letter === letter)
    if (group) group.apps.push(app)
    else groups.push({ apps: [app], letter })
  }
  return groups
})
const trackStyle = computed(() => ({
  '--drag-offset': `${dragOffset.value}px`,
  '--springboard-offset': `${(-phone.currentPage * 100) / pageCount.value}%`,
  width: `${pageCount.value * 100}%`,
}))
const pageStyle = computed(() => ({ width: `${100 / pageCount.value}%` }))
const activeWidget = computed(() =>
  widgets.layout.instances.find(
    (instance) => instance.id === widgetActionId.value,
  ),
)
const configuredWidget = computed(
  () =>
    widgets.layout.instances.find(
      (instance) => instance.id === widgetConfigId.value,
    ) ?? null,
)

function clearBackgroundHold(): void {
  if (backgroundHoldTimer !== undefined)
    window.clearTimeout(backgroundHoldTimer)
  backgroundHoldTimer = undefined
}

function changePage(page: number): void {
  const targetPage = Math.max(0, Math.min(page, pageCount.value - 1))
  if (targetPage === phone.currentPage) {
    pageTransitioning.value = false
    return
  }
  pageTransitioning.value = true
  phone.setCurrentPage(targetPage, pageCount.value)
}

function finishPageTransition(event: TransitionEvent): void {
  if (event.propertyName !== 'transform') return
  pageTransitioning.value = false
}

function onPointerDown(event: PointerEvent): void {
  const target = event.target as HTMLElement
  const pageSwipeSurface = target.closest(
    '.springboard-page--apps .app-icon-button, .home-widget',
  )
  const blockedControl =
    target.closest('input, textarea, select, [data-widget-control]') ||
    (target.closest('button, a') && !pageSwipeSurface)
  if (blockedControl || (editMode.value && pageSwipeSurface)) {
    clearBackgroundHold()
    dragging.value = false
    dragOffset.value = 0
    blankTapCandidate = false
    return
  }
  pointerStart = event.clientX
  pointerStartY = event.clientY
  pointerStartedAt = Date.now()
  pointerPageStart = phone.currentPage
  blankTapCandidate = editMode.value
  dragging.value = true
  if (!pageSwipeSurface) {
    ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
  }
  clearBackgroundHold()
  if (editMode.value || pageSwipeSurface) return
  backgroundHoldTimer = window.setTimeout(() => {
    enterEditMode()
    backgroundHoldTimer = undefined
  }, 520)
}

function onPointerMove(event: PointerEvent): void {
  const distanceX = event.clientX - pointerStart
  const distanceY = event.clientY - pointerStartY
  const intent = springboardSwipeIntent(distanceX, distanceY)
  if (intent === 'pending') return
  clearBackgroundHold()
  blankTapCandidate = false
  if (!dragging.value) return
  if (intent === 'vertical') {
    dragging.value = false
    dragOffset.value = 0
    return
  }
  const atFirstPage = pointerPageStart === 0 && distanceX > 0
  const atLastPage = pointerPageStart === pageCount.value - 1 && distanceX < 0
  dragOffset.value = atFirstPage || atLastPage ? distanceX * 0.28 : distanceX
}

function finishPointer(event: PointerEvent): void {
  clearBackgroundHold()
  if (editMode.value && blankTapCandidate) {
    blankTapCandidate = false
    editMode.value = false
    return
  }
  if (!dragging.value) return
  const distance = event.clientX - pointerStart
  const elapsed = Math.max(1, Date.now() - pointerStartedAt)
  const velocity = Math.abs(distance) / elapsed
  if (Math.abs(distance) > 48 || velocity > 0.45) {
    changePage(pointerPageStart + (distance < 0 ? 1 : -1))
  }
  dragging.value = false
  dragOffset.value = 0
}

function cancelPointer(): void {
  clearBackgroundHold()
  blankTapCandidate = false
  dragging.value = false
  dragOffset.value = 0
}

function enterEditMode(): void {
  editMode.value = true
  dragging.value = false
  dragOffset.value = 0
}

function openWidgetMenu(id: string): void {
  enterEditMode()
  widgetActionId.value = id
}

function startWidgetDrag(id: string, event: PointerEvent): void {
  const widget = Array.from(
    document.querySelectorAll<HTMLElement>('[data-widget-id]'),
  ).find((candidate) => candidate.dataset.widgetId === id)
  if (!widget) return
  pageTransitioning.value = false
  const bounds = homeDragViewportRect(widget)
  draggingWidgetId.value = id
  widgetDragGrip.value = {
    x: event.clientX - bounds.left,
    y: event.clientY - bounds.top,
  }
}

function updateWidgetDragPreview(event: {
  clientX: number
  clientY: number
}): void {
  const id = draggingWidgetId.value
  const grip = widgetDragGrip.value
  if (!id || !grip) return
  const page = phone.currentPage
  const grid = document.querySelector<HTMLElement>(
    `[data-widget-page="${page}"]`,
  )
  const pageElement = grid?.closest<HTMLElement>('.springboard-page')
  if (!grid || !pageElement) return
  const renderedGridBounds = homeDragViewportRect(grid)
  const gridStyle = getComputedStyle(grid)
  const scaleX =
    grid.offsetWidth > 0 ? renderedGridBounds.width / grid.offsetWidth : 1
  const scaleY =
    grid.offsetHeight > 0 ? renderedGridBounds.height / grid.offsetHeight : 1
  const columnGap = (Number.parseFloat(gridStyle.columnGap) || 0) * scaleX
  const rowGap = (Number.parseFloat(gridStyle.rowGap) || 0) * scaleY
  const columnWidth =
    (renderedGridBounds.width - columnGap * (WIDGET_GRID_COLUMNS - 1)) /
    WIDGET_GRID_COLUMNS
  const rowHeight = Number.parseFloat(gridStyle.gridAutoRows) * scaleY
  const column = Math.round(
    (event.clientX - grip.x - renderedGridBounds.left) /
      (columnWidth + columnGap),
  )
  const row = Math.round(
    (event.clientY - grip.y - renderedGridBounds.top) / (rowHeight + rowGap),
  )
  if (Number.isFinite(rowHeight)) {
    const current = widgetDragPreview.value
    if (
      !current ||
      current.id !== id ||
      current.page !== page ||
      current.column !== column ||
      current.row !== row
    ) {
      widgetDragPreview.value = { column, id, page, row }
    }
  }
}

function clearEdgePageTurn(): void {
  if (edgePageTimer !== undefined) window.clearTimeout(edgePageTimer)
  edgePageTimer = undefined
  edgePageDirection = 0
  edgePageLocked = false
}

function clearTemporaryHomePage(keepCurrentPage = false): void {
  if (temporaryHomePage.value === null) return
  temporaryHomePage.value = null
  if (keepCurrentPage) return
  const lastPage = Math.max(
    1,
    appStore.homeLayout.pageCount,
    ...widgets.layout.instances.map((instance) => instance.page),
  )
  if (phone.currentPage > lastPage) changePage(lastPage)
}

function resolveHomeEdgeTurn(event: { clientX: number }) {
  const springboard = document.querySelector<HTMLElement>('.springboard')
  if (!springboard) return null
  const bounds = homeDragViewportRect(springboard)
  const renderedLastPage = appPages.value.length
  return resolveSpringboardHomeEdgeTurn(
    event.clientX,
    bounds.left,
    bounds.right,
    phone.currentPage,
    renderedLastPage,
    MAX_HOME_GRID_PAGES,
    temporaryHomePage.value !== null,
  )
}

function queueEdgePageTurn(
  event: { clientX: number; clientY: number },
  dragType: 'app' | 'widget',
): void {
  const springboard = document.querySelector<HTMLElement>('.springboard')
  if (!springboard) return
  const bounds = homeDragViewportRect(springboard)
  const turn =
    dragType === 'app'
      ? resolveHomeEdgeTurn(event)
      : resolveSpringboardEdgeTurn(
          event.clientX,
          bounds.left,
          bounds.right,
          phone.currentPage,
          0,
          libraryPage.value - 1,
        )

  if (!turn) {
    if (edgePageTimer !== undefined) window.clearTimeout(edgePageTimer)
    edgePageTimer = undefined
    edgePageDirection = 0
    edgePageLocked = false
    return
  }
  const { destination, direction } = turn
  if (edgePageLocked && edgePageDirection === direction) return
  if (edgePageLocked) edgePageLocked = false
  if (edgePageTimer !== undefined && edgePageDirection === direction) return
  if (edgePageTimer !== undefined) window.clearTimeout(edgePageTimer)
  edgePageDirection = direction
  edgePageTimer = window.setTimeout(() => {
    const liveTurn =
      dragType === 'app' && lastHomePointer
        ? resolveHomeEdgeTurn(lastHomePointer)
        : { destination, direction }
    if (!liveTurn || liveTurn.direction !== direction) {
      clearEdgePageTurn()
      return
    }
    clearFolderHover()
    if (
      dragType === 'app' &&
      'previewsPage' in liveTurn &&
      liveTurn.previewsPage
    ) {
      temporaryHomePage.value = liveTurn.destination
    }
    changePage(liveTurn.destination)
    if (dragType === 'widget' && lastWidgetPointer) {
      updateWidgetDragPreview(lastWidgetPointer)
    }
    edgePageTimer = undefined
    edgePageDirection = direction
    edgePageLocked = dragType === 'widget'
    if (dragType === 'app' && lastHomePointer && draggingHomeApp.value) {
      queueEdgePageTurn(lastHomePointer, 'app')
    }
  }, HOME_EDGE_PAGE_TURN_DELAY)
}

function queueWidgetDragPreview(event: PointerEvent): void {
  queueEdgePageTurn(event, 'widget')
  lastWidgetPointer = {
    clientX: event.clientX,
    clientY: event.clientY,
  }
  pendingWidgetPointer = lastWidgetPointer
  if (widgetPreviewTimer !== undefined) return
  widgetPreviewTimer = window.setTimeout(() => {
    if (pendingWidgetPointer) updateWidgetDragPreview(pendingWidgetPointer)
    pendingWidgetPointer = null
    widgetPreviewTimer = undefined
  }, 110)
}

function clearWidgetDragPreview(): void {
  clearEdgePageTurn()
  if (widgetPreviewTimer !== undefined) window.clearTimeout(widgetPreviewTimer)
  widgetPreviewTimer = undefined
  pendingWidgetPointer = null
  lastWidgetPointer = null
  widgetDragGrip.value = null
  widgetDragPreview.value = null
}

function applyWidgetLayout(nextLayout: WidgetLayout): boolean {
  if (nextLayout === widgets.layout) return true
  if (
    !appStore.applyWidgetGridCapacities(
      homeGridCapacitiesFor(widgets.layout),
      homeGridCapacitiesFor(nextLayout),
    )
  ) {
    return false
  }
  return widgets.applyLayout(nextLayout)
}

function finishWidgetDrag(event: PointerEvent): void {
  const id = draggingWidgetId.value
  if (!id) return
  lastWidgetPointer = { clientX: event.clientX, clientY: event.clientY }
  updateWidgetDragPreview(lastWidgetPointer)
  const preview = widgetDragPreview.value
  if (preview?.id === id) {
    applyWidgetLayout(
      previewWidgetMove(
        widgets.layout,
        id,
        preview.page,
        preview.column,
        preview.row,
      ),
    )
  }
  draggingWidgetId.value = null
  clearWidgetDragPreview()
}

function stopWidgetDrag(): void {
  draggingWidgetId.value = null
  clearWidgetDragPreview()
}

function reorderWidget(id: string, direction: ReorderDirection): void {
  const instance = widgets.layout.instances.find((widget) => widget.id === id)
  if (!instance) return
  const target = widgetKeyboardTarget(instance, direction)
  if (!target) return
  applyWidgetLayout(
    previewWidgetMove(
      widgets.layout,
      id,
      instance.page,
      target.column,
      target.row,
    ),
  )
}

function removeWidget(id: string): void {
  if (!applyWidgetLayout(previewWidgetRemove(widgets.layout, id))) return
  if (widgetActionId.value === id) widgetActionId.value = null
  if (widgetConfigId.value === id) widgetConfigId.value = null
}

async function addWidget(kind: WidgetKind, size: WidgetSize): Promise<void> {
  const targetPage = isEditablePage.value ? phone.currentPage : 1
  const previousIds = new Set(
    widgets.layout.instances.map((instance) => instance.id),
  )
  const nextLayout = previewWidgetAdd(widgets.layout, kind, size, targetPage)
  if (nextLayout === widgets.layout || !applyWidgetLayout(nextLayout)) return
  const addedId = widgets.layout.instances.find(
    (instance) => !previousIds.has(instance.id),
  )?.id
  if (!addedId) return
  widgetPickerOpened.value = false
  editMode.value = true
  await nextTick()
  const added = widgets.layout.instances.find(
    (instance) => instance.id === addedId,
  )
  if (added) changePage(added.page)
}

function openWidgetConfig(): void {
  widgetConfigId.value = widgetActionId.value
  widgetActionId.value = null
}

async function saveWidgetConfig(
  size: WidgetSize,
  settings: WidgetSettings,
): Promise<void> {
  if (!widgetConfigId.value) return
  const id = widgetConfigId.value
  const resized = previewWidgetResize(widgets.layout, id, size)
  if (!applyWidgetLayout(resized)) return
  widgets.updateSettings(id, settings)
  widgetConfigId.value = null
  editMode.value = true
  await nextTick()
  const configured = widgets.layout.instances.find(
    (instance) => instance.id === id,
  )
  if (configured) changePage(configured.page)
}

function homeDragViewportRect(
  element: Element,
  geometry = homeDragGeometry ?? readPhoneViewportGeometry(element),
): PhoneViewportRect {
  if (geometry) return geometry.rect(element)
  const bounds = element.getBoundingClientRect()
  return {
    bottom: bounds.bottom,
    height: bounds.height,
    left: bounds.left,
    right: bounds.right,
    top: bounds.top,
    width: bounds.width,
  }
}

function viewportRectAt(
  left: number,
  top: number,
  width: number,
  height: number,
): PhoneViewportRect {
  return {
    bottom: top + height,
    height,
    left,
    right: left + width,
    top,
    width,
  }
}

function clearHomeDragGhost(expectedGhost?: HTMLElement | null): void {
  if (expectedGhost && homeDragGhost !== expectedGhost) return
  homeDragGhost?.remove()
  homeDragGhost = null
  homeDragGrip = null
  homeDragGeometry = null
  homeDragClipBounds = null
  homeDragPreviewBounds = null
  homeDragVisualActive.value = false
  const layer = homeDragLayer.value
  layer?.style.removeProperty('left')
  layer?.style.removeProperty('top')
  layer?.style.removeProperty('width')
  layer?.style.removeProperty('height')
}

function updateHomeDragGhost(event: {
  clientX: number
  clientY: number
}): void {
  const ghost = homeDragGhost
  const grip = homeDragGrip
  const clipBounds = homeDragClipBounds
  const previewBounds = homeDragPreviewBounds
  if (!ghost || !grip || !clipBounds || !previewBounds) return

  const left = event.clientX - grip.x
  const top = event.clientY - grip.y
  ghost.style.transform = `translate3d(${left - clipBounds.left}px, ${top - clipBounds.top}px, 0)`
  homeDragPreviewBounds = viewportRectAt(
    left,
    top,
    previewBounds.width,
    previewBounds.height,
  )
}

function createHomeDragGhost(event: PointerEvent): void {
  clearHomeDragGhost()
  const eventTarget =
    event.currentTarget instanceof Element
      ? event.currentTarget
      : event.target instanceof Element
        ? event.target
        : null
  const source = eventTarget?.closest<HTMLElement>('.app-icon-item')
  const layer = homeDragLayer.value
  const springboard = source?.closest<HTMLElement>('.springboard')
  const portal = layer?.closest<HTMLElement>('.phone-home-drag-portal')
  const geometry = readPhoneViewportGeometry(source ?? null)
  if (!source || !layer || !springboard || !portal || !geometry) return

  const portalBounds = portal.getBoundingClientRect()
  const clipBounds = geometry.rect(springboard)
  const sourceBounds = geometry.rect(source)
  if (
    clipBounds.width <= 0 ||
    clipBounds.height <= 0 ||
    sourceBounds.width <= 0 ||
    sourceBounds.height <= 0
  ) {
    return
  }

  layer.style.left = `${clipBounds.left - portalBounds.left}px`
  layer.style.top = `${clipBounds.top - portalBounds.top}px`
  layer.style.width = `${clipBounds.width}px`
  layer.style.height = `${clipBounds.height}px`

  const ghost = source.cloneNode(true) as HTMLElement
  ghost.classList.remove(
    'app-icon-item--dragging',
    'app-icon-item--editing',
    'app-icon-item--drag-source',
    'app-icon-item--drop-settling',
    'home-folder-item--dragging',
    'home-item--folder-hover',
  )
  ghost.classList.add('home-drag-ghost')
  ghost.removeAttribute('style')
  ghost
    .querySelector<HTMLElement>('.app-icon-button')
    ?.style.removeProperty('transform')
  ghost.setAttribute('aria-hidden', 'true')
  ghost.querySelector('.app-icon-remove')?.remove()
  for (const element of [ghost, ...Array.from(ghost.querySelectorAll('*'))]) {
    element.removeAttribute('id')
    for (const attribute of element.getAttributeNames()) {
      if (attribute.startsWith('data-home-')) element.removeAttribute(attribute)
    }
  }
  for (const control of ghost.querySelectorAll<HTMLElement>(
    'a, button, input, select, textarea, [tabindex]',
  )) {
    control.tabIndex = -1
  }

  const position = document.createElement('div')
  position.className = 'home-drag-position'
  position.style.width = `${sourceBounds.width}px`
  position.style.height = `${sourceBounds.height}px`
  ghost.style.width = `${source.offsetWidth}px`
  ghost.style.height = `${source.offsetHeight}px`
  ghost.style.transform = `scale(${geometry.scaleX}, ${geometry.scaleY})`
  position.appendChild(ghost)

  homeDragGhost = position
  homeDragGrip = {
    x: event.clientX - sourceBounds.left,
    y: event.clientY - sourceBounds.top,
  }
  homeDragGeometry = geometry
  homeDragClipBounds = clipBounds
  homeDragPreviewBounds = sourceBounds
  layer.appendChild(position)
  homeDragVisualActive.value = true
  updateHomeDragGhost(event)
}

function startHomeDrag(
  area: HomeArea,
  index: number,
  event: PointerEvent,
): void {
  clearTemporaryHomePage()
  lastHomePointer = null
  draggingHomeApp.value = { area, index }
  createHomeDragGhost(event)
}

function clearFolderHover(): void {
  if (folderHoverTimer !== undefined) window.clearTimeout(folderHoverTimer)
  folderHoverTimer = undefined
  folderHoverTarget.value = ''
}

function queueFolderHover(event: PointerEvent): void {
  const dragged = draggingHomeApp.value
  if (!dragged) return
  const sourceItem = appStore.homeLayout[dragged.area][dragged.index]
  if (typeof sourceItem !== 'string') {
    clearFolderHover()
    return
  }

  const targetElement = Array.from(
    document.querySelectorAll<HTMLElement>('[data-home-area][data-home-index]'),
  )
    .filter((element) => {
      const area = element.dataset.homeArea as HomeArea | undefined
      const index = Number(element.dataset.homeIndex)
      if (
        (area !== 'grid' && area !== 'dock') ||
        !Number.isInteger(index) ||
        (area === dragged.area && index === dragged.index)
      ) {
        return false
      }
      if (
        area === 'grid' &&
        Number(
          element.closest<HTMLElement>('[data-home-page]')?.dataset.homePage,
        ) !== phone.currentPage
      ) {
        return false
      }
      const bounds = homeDragViewportRect(element)
      return (
        event.clientX >= bounds.left &&
        event.clientX <= bounds.right &&
        event.clientY >= bounds.top &&
        event.clientY <= bounds.bottom
      )
    })
    .sort((left, right) => {
      const leftIsDock = left.dataset.homeArea === 'dock'
      const rightIsDock = right.dataset.homeArea === 'dock'
      return Number(rightIsDock) - Number(leftIsDock)
    })[0]
  const area = targetElement?.dataset.homeArea as HomeArea | undefined
  const targetIndex = Number(targetElement?.dataset.homeIndex)
  if (
    (area !== 'grid' && area !== 'dock') ||
    !Number.isInteger(targetIndex) ||
    (area === dragged.area && targetIndex === dragged.index)
  ) {
    clearFolderHover()
    return
  }

  if (
    area === 'grid' &&
    Number(
      targetElement?.closest<HTMLElement>('[data-home-page]')?.dataset.homePage,
    ) !== phone.currentPage
  ) {
    clearFolderHover()
    return
  }
  const targetItem = appStore.homeLayout[area][targetIndex]
  if (typeof targetItem !== 'string' && !isHomeFolder(targetItem)) {
    clearFolderHover()
    return
  }

  const targetKey = `${area}:${targetIndex}`
  if (folderHoverTarget.value === targetKey) {
    clearEdgePageTurn()
    return
  }
  clearEdgePageTurn()
  clearFolderHover()
  folderHoverTarget.value = targetKey
  folderHoverTimer = window.setTimeout(() => {
    const currentDrag = draggingHomeApp.value
    if (!currentDrag || folderHoverTarget.value !== targetKey) return
    const currentSource =
      appStore.homeLayout[currentDrag.area][currentDrag.index]
    const currentTarget = appStore.homeLayout[area][targetIndex]
    if (typeof currentSource !== 'string') return

    let folderId: string | null = null
    if (typeof currentTarget === 'string') {
      folderId = appStore.createHomeFolder(
        currentDrag.area,
        currentDrag.index,
        area,
        targetIndex,
        phone.t('Home.folders.defaultName'),
      )
      if (folderId) renameFolderOnOpenId.value = folderId
    } else if (isHomeFolder(currentTarget)) {
      folderId = appStore.addHomeAppToFolder(
        currentDrag.area,
        currentDrag.index,
        currentTarget.id,
      )
        ? currentTarget.id
        : null
    }
    if (folderId) {
      draggingHomeApp.value = null
      lastHomePointer = null
      clearHomeDragGhost()
      clearTemporaryHomePage()
      openedFolderId.value = folderId
    }
    clearFolderHover()
  }, HOME_FOLDER_HOVER_DURATION)
}

function moveHomeDrag(event: PointerEvent): void {
  if (!draggingHomeApp.value) return
  lastHomePointer = { clientX: event.clientX, clientY: event.clientY }
  updateHomeDragGhost(event)
  if (resolveHomeEdgeTurn(event)) {
    clearFolderHover()
    queueEdgePageTurn(event, 'app')
    return
  }
  clearEdgePageTurn()
  queueFolderHover(event)
}

async function animateHomeItemDrop(
  item: HomeItem,
  area: HomeArea,
  index: number,
  from: PhoneViewportRect,
): Promise<void> {
  await nextTick()
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return

  const appElement = Array.from(
    document.querySelectorAll<HTMLElement>('[data-home-item-key]'),
  ).find(
    (element) =>
      element.dataset.homeItemKey ===
        (isHomeFolder(item) ? item.id : `app-${item}`) &&
      element.dataset.homeArea === area &&
      Number(element.dataset.homeIndex) === index,
  )
  if (!appElement) return

  const target = homeDragViewportRect(
    appElement,
    readPhoneViewportGeometry(appElement),
  )
  const { x: offsetX, y: offsetY } = springboardViewportDeltaToLocal(
    from.left - target.left,
    from.top - target.top,
    target.width,
    target.height,
    appElement.offsetWidth,
    appElement.offsetHeight,
  )
  if (Math.hypot(offsetX, offsetY) < 1) return

  appElement.style.setProperty('--home-app-drop-x', `${offsetX}px`)
  appElement.style.setProperty('--home-app-drop-y', `${offsetY}px`)
  let cleanedUp = false
  const cleanUpAnimation = (event: AnimationEvent): void => {
    if (
      event.target !== appElement ||
      event.animationName !== 'home-app-drop-settle'
    ) {
      return
    }
    if (cleanedUp) return
    cleanedUp = true
    appElement.classList.remove('app-icon-item--drop-settling')
    appElement.style.removeProperty('--home-app-drop-x')
    appElement.style.removeProperty('--home-app-drop-y')
    appElement.removeEventListener('animationend', cleanUpAnimation)
    appElement.removeEventListener('animationcancel', cleanUpAnimation)
  }
  appElement.addEventListener('animationend', cleanUpAnimation)
  appElement.addEventListener('animationcancel', cleanUpAnimation)
  appElement.classList.add('app-icon-item--drop-settling')
}

function findHomeItemIndex(
  item: HomeItem,
  area: HomeArea,
  preferredIndex: number,
): number | null {
  const matches = appStore.homeLayout[area].flatMap((candidate, index) => {
    const matchesItem = isHomeFolder(item)
      ? isHomeFolder(candidate) && candidate.id === item.id
      : candidate === item
    return matchesItem ? [index] : []
  })
  if (!matches.length) return null
  return matches.reduce((closest, index) =>
    Math.abs(index - preferredIndex) < Math.abs(closest - preferredIndex)
      ? index
      : closest,
  )
}

function nearestGridDropTarget(event: {
  clientX: number
  clientY: number
}): { page: number; targetOffset: number } | null {
  const page = phone.currentPage
  if (page < 1 || page > appPages.value.length) return null
  const grid = document.querySelector<HTMLElement>(
    `.springboard-page--apps[data-home-page="${page}"] .app-grid`,
  )
  const pageElement = grid?.closest<HTMLElement>('.springboard-page')
  const springboard = grid?.closest<HTMLElement>('.springboard')
  if (!grid || !pageElement || !springboard) return null
  const geometry = homeDragGeometry ?? readPhoneViewportGeometry(springboard)
  const pageBounds = homeDragViewportRect(pageElement, geometry)
  const springboardBounds = homeDragViewportRect(springboard, geometry)
  if (
    event.clientX < springboardBounds.left ||
    event.clientX > springboardBounds.right ||
    event.clientY < springboardBounds.top ||
    event.clientY > springboardBounds.bottom
  ) {
    return null
  }
  const slots = Array.from(
    grid.querySelectorAll<HTMLElement>('[data-home-target-offset]'),
  )
  const closestIndex = nearestSpringboardRectIndex(
    event.clientX,
    event.clientY,
    slots.map((slot) => {
      const bounds = homeDragViewportRect(slot, geometry)
      return {
        height: bounds.height,
        left: springboardBounds.left + (bounds.left - pageBounds.left),
        top: springboardBounds.top + (bounds.top - pageBounds.top),
        width: bounds.width,
      }
    }),
  )
  const closest = closestIndex === null ? null : slots[closestIndex]
  const targetOffset = Number(closest?.dataset.homeTargetOffset)
  return Number.isInteger(targetOffset) ? { page, targetOffset } : null
}

function nearestDockDropTarget(event: {
  clientX: number
  clientY: number
}): HTMLElement | null {
  const dock = document.querySelector<HTMLElement>('.app-dock')
  if (!dock) return null
  const geometry = homeDragGeometry ?? readPhoneViewportGeometry(dock)
  const dockBounds = homeDragViewportRect(dock, geometry)
  if (
    event.clientX < dockBounds.left ||
    event.clientX > dockBounds.right ||
    event.clientY < dockBounds.top ||
    event.clientY > dockBounds.bottom
  ) {
    return null
  }
  const slots = Array.from(
    dock.querySelectorAll<HTMLElement>(
      '[data-home-area="dock"][data-home-index]',
    ),
  )
  const closestIndex = nearestSpringboardRectIndex(
    event.clientX,
    event.clientY,
    slots.map((slot) => homeDragViewportRect(slot, geometry)),
  )
  return closestIndex === null ? null : slots[closestIndex]
}

function finishHomeDrag(event: PointerEvent): void {
  clearEdgePageTurn()
  clearFolderHover()
  const dragged = draggingHomeApp.value
  if (!dragged) {
    clearHomeDragGhost()
    return
  }
  updateHomeDragGhost(event)
  const draggedItem = appStore.homeLayout[dragged.area][dragged.index]
  const dropGhost = homeDragGhost
  const dropOrigin = homeDragPreviewBounds ? { ...homeDragPreviewBounds } : null
  const dockTarget = nearestDockDropTarget(event)
  const gridTarget = dockTarget ? null : nearestGridDropTarget(event)
  let dropArea = dragged.area
  let dropIndex = dragged.index
  let moved = false
  if (dockTarget) {
    const targetIndex = Number.parseInt(dockTarget.dataset.homeIndex ?? '', 10)
    moved = appStore.moveHomeApp(
      dragged.area,
      dragged.index,
      'dock',
      targetIndex,
    )
    dropArea = 'dock'
    dropIndex = draggedItem
      ? (findHomeItemIndex(draggedItem, 'dock', targetIndex) ?? targetIndex)
      : targetIndex
  } else if (gridTarget) {
    moved = appStore.moveHomeAppToGridPage(
      dragged.area,
      dragged.index,
      gridTarget.page,
      gridTarget.targetOffset,
      homeGridCapacities.value,
    )
    dropArea = 'grid'
    const preferredIndex =
      (gridTarget.page - 1) * HOME_GRID_PAGE_SIZE + gridTarget.targetOffset
    dropIndex = draggedItem
      ? (findHomeItemIndex(draggedItem, 'grid', preferredIndex) ??
        preferredIndex)
      : preferredIndex
  }
  draggingHomeApp.value = null
  lastHomePointer = null
  clearTemporaryHomePage(moved && gridTarget !== null)
  if (moved && draggedItem && dropOrigin) {
    void animateHomeItemDrop(
      draggedItem,
      dropArea,
      dropIndex,
      dropOrigin,
    ).finally(() => clearHomeDragGhost(dropGhost))
  } else {
    clearHomeDragGhost()
  }
}

function stopHomeDrag(): void {
  clearEdgePageTurn()
  clearFolderHover()
  draggingHomeApp.value = null
  lastHomePointer = null
  clearHomeDragGhost()
  clearTemporaryHomePage()
}

function reorderHomeApp(
  area: HomeArea,
  sourceIndex: number,
  direction: ReorderDirection,
): void {
  const item = appStore.homeLayout[area][sourceIndex]
  const appElement = document.querySelector<HTMLElement>(
    `[data-home-area="${area}"][data-home-index="${sourceIndex}"]`,
  )
  const moveOrigin = appElement
    ? homeDragViewportRect(appElement, readPhoneViewportGeometry(appElement))
    : null
  const targetIndex = homeKeyboardTarget(
    appStore.homeLayout,
    area,
    sourceIndex,
    direction,
  )
  if (targetIndex === null) return
  appStore.moveHomeApp(area, sourceIndex, area, targetIndex)
  if (item && moveOrigin) {
    const movedIndex = findHomeItemIndex(item, area, targetIndex) ?? targetIndex
    void animateHomeItemDrop(item, area, movedIndex, moveOrigin)
  }
}

async function addHomePage(): Promise<void> {
  if (addingHomePage.value) return
  addingHomePage.value = true
  try {
    if (!appStore.addHomePage()) return
    await nextTick()
    changePage(appPages.value.length)
  } finally {
    addingHomePage.value = false
  }
}

async function deleteCurrentPage(): Promise<void> {
  if (!canDeleteCurrentPage.value) return
  const deletedPage = phone.currentPage
  const remainingPages = persistedHomePageCount.value - 1
  widgets.deletePage(deletedPage, remainingPages)
  appStore.deleteHomePage(deletedPage)
  await nextTick()
  changePage(Math.min(deletedPage, appPages.value.length))
}

function removeHomeApp(appId: LaunchablePhoneAppId): void {
  appStore.removeHomeApp(appId)
}

function restoreHomeApp(appId: LaunchablePhoneAppId): void {
  appStore.restoreHomeApp(appId)
}

function folderPreviewApps(folder: HomeFolder): PhoneAppDefinition[] {
  const apps: PhoneAppDefinition[] = []
  for (const appId of folder.apps) {
    const app = installedAppsById.value.get(appId)
    if (app) apps.push(app)
  }
  return apps
}

function openFolder(folderId: string): void {
  pageTransitioning.value = false
  folderDraggingOutside.value = false
  openedFolderId.value = folderId
}

function closeFolder(): void {
  folderDraggingOutside.value = false
  openedFolderId.value = null
  renameFolderOnOpenId.value = null
}

function renameOpenedFolder(name: string): void {
  if (!openedFolderId.value) return
  appStore.renameHomeFolder(openedFolderId.value, name)
}

function moveOpenedFolderApp(sourceIndex: number, targetIndex: number): void {
  if (!openedFolderId.value) return
  appStore.moveHomeFolderApp(openedFolderId.value, sourceIndex, targetIndex)
}

function extractOpenedFolderApp(
  sourceIndex: number,
  event: PointerEvent,
): void {
  const folder = openedFolder.value
  if (!folder) return
  const appId = folder.apps[sourceIndex]
  const sourceElement = document
    .querySelector<HTMLElement>(
      `.home-folder-panel [data-folder-app-index="${sourceIndex}"]`,
    )
    ?.closest<HTMLElement>('.app-icon-item')
  const geometry = readPhoneViewportGeometry(sourceElement ?? null)
  const sourceBounds = sourceElement
    ? homeDragViewportRect(sourceElement, geometry)
    : null
  const candidates = Array.from(
    document.querySelectorAll<HTMLElement>('[data-home-index][data-home-area]'),
  ).filter((element) => {
    const area = element.dataset.homeArea as HomeArea
    const index = Number(element.dataset.homeIndex)
    return (
      (area === 'grid' || area === 'dock') &&
      Number.isInteger(index) &&
      appStore.homeLayout[area][index] === null
    )
  })
  const target = candidates.reduce<HTMLElement | null>((closest, candidate) => {
    if (!closest) return candidate
    const bounds = homeDragViewportRect(candidate, geometry)
    const closestBounds = homeDragViewportRect(closest, geometry)
    const distance = Math.hypot(
      event.clientX - (bounds.left + bounds.width / 2),
      event.clientY - (bounds.top + bounds.height / 2),
    )
    const closestDistance = Math.hypot(
      event.clientX - (closestBounds.left + closestBounds.width / 2),
      event.clientY - (closestBounds.top + closestBounds.height / 2),
    )
    return distance < closestDistance ? candidate : closest
  }, null)
  if (!target) {
    closeFolder()
    return
  }

  const area = target.dataset.homeArea as HomeArea
  const targetIndex = Number(target.dataset.homeIndex)
  if (
    !appStore.extractHomeFolderApp(folder.id, sourceIndex, area, targetIndex)
  ) {
    closeFolder()
    return
  }
  closeFolder()
  if (sourceBounds) {
    const extractedIndex = findHomeItemIndex(appId, area, targetIndex)
    if (extractedIndex !== null) {
      void animateHomeItemDrop(appId, area, extractedIndex, sourceBounds)
    }
  }
}

function clearSearch(): void {
  searchQuery.value = ''
  searchFocused.value = false
  showAllApps.value = false
}

function openAllApps(): void {
  searchFocused.value = true
  showAllApps.value = true
}

watch(isEditablePage, (visible) => {
  if (!visible) editMode.value = false
})
watch(editMode, (editing) => {
  emit('editModeChange', editing)
  if (editing) return
  stopHomeDrag()
  stopWidgetDrag()
})
watch(openedFolder, (folder) => {
  if (!folder) closeFolder()
})
onBeforeUnmount(() => {
  emit('editModeChange', false)
  clearBackgroundHold()
  clearEdgePageTurn()
  clearFolderHover()
  if (widgetPreviewTimer !== undefined) window.clearTimeout(widgetPreviewTimer)
  widgetPreviewTimer = undefined
  pendingWidgetPointer = null
  lastWidgetPointer = null
  lastHomePointer = null
  clearHomeDragGhost()
  temporaryHomePage.value = null
  draggingHomeApp.value = null
  draggingWidgetId.value = null
})
</script>

<template>
  <section
    class="springboard"
    :class="[
      `wallpaper--${phone.preferences.settings.wallpaper}`,
      {
        'springboard--dragging': dragging,
        'springboard--editing': editMode,
        'springboard--folder-open': folderOverlayVisible,
        'springboard--widget-dragging': draggingWidgetId !== null,
      },
    ]"
    :style="wallpaperStyle"
  >
    <div
      class="springboard-track"
      :style="trackStyle"
      @pointerdown="onPointerDown"
      @pointermove="onPointerMove"
      @pointerup="finishPointer"
      @pointercancel="cancelPointer"
      @transitionend.self="finishPageTransition"
      @transitioncancel.self="finishPageTransition"
    >
      <section
        class="springboard-page springboard-page--widgets"
        :style="pageStyle"
        :aria-label="phone.t('Home.widgets.label')"
      >
        <div class="springboard-widget-page-scroll">
          <SpringboardWidgetGrid
            :page="0"
            :dragging-widget-id="draggingWidgetId"
            :edit-mode="editMode"
            @dragcancel="stopWidgetDrag"
            @dragend="finishWidgetDrag"
            @dragmove="queueWidgetDragPreview"
            @dragstart="startWidgetDrag"
            @menu="openWidgetMenu"
            @remove="removeWidget"
            @reorder="reorderWidget"
          />
        </div>
      </section>

      <section
        v-for="page in appPages"
        :key="`apps-${page.page}`"
        class="springboard-page springboard-page--apps"
        :style="pageStyle"
        :aria-label="phone.t('Home.apps')"
        :data-home-page="page.page"
      >
        <SpringboardWidgetGrid
          :page="page.page"
          :dragging-widget-id="draggingWidgetId"
          :edit-mode="editMode"
          @dragcancel="stopWidgetDrag"
          @dragend="finishWidgetDrag"
          @dragmove="queueWidgetDragPreview"
          @dragstart="startWidgetDrag"
          @menu="openWidgetMenu"
          @remove="removeWidget"
          @reorder="reorderWidget"
        />
        <TransitionGroup
          :name="
            draggingWidgetId && !pageTransitioning ? 'app-reflow' : undefined
          "
          tag="div"
          class="app-grid"
          :style="{ '--home-grid-rows': HOME_GRID_ROWS }"
          data-home-area="grid"
        >
          <template v-for="cell in page.cells" :key="cell.renderKey">
            <AppIcon
              v-if="cell.app && cell.sourceIndex !== null"
              :app="cell.app"
              data-home-area="grid"
              :data-home-app-id="cell.app.id"
              :data-home-item-key="`app-${cell.app.id}`"
              :data-home-index="cell.sourceIndex"
              :data-home-target-offset="cell.targetOffset"
              :edit-mode="editMode"
              :external-drag-visual="homeDragVisualActive"
              :class="{
                'home-item--folder-hover':
                  folderHoverTarget === `grid:${cell.sourceIndex}`,
              }"
              @dragcancel="stopHomeDrag"
              @dragend="finishHomeDrag"
              @dragmove="moveHomeDrag"
              @dragstart="startHomeDrag('grid', cell.sourceIndex, $event)"
              @edit="enterEditMode"
              @remove="removeHomeApp(cell.app.id)"
              @reorder="reorderHomeApp('grid', cell.sourceIndex, $event)"
            />
            <HomeFolderIcon
              v-else-if="cell.folder && cell.sourceIndex !== null"
              :apps="folderPreviewApps(cell.folder)"
              :default-name="phone.t('Home.folders.defaultName')"
              data-home-area="grid"
              :data-home-folder-id="cell.folder.id"
              :data-home-item-key="cell.folder.id"
              :data-home-index="cell.sourceIndex"
              :data-home-target-offset="cell.targetOffset"
              :edit-mode="editMode"
              :external-drag-visual="homeDragVisualActive"
              :folder="cell.folder"
              :class="{
                'home-item--folder-hover':
                  folderHoverTarget === `grid:${cell.sourceIndex}`,
              }"
              @dragcancel="stopHomeDrag"
              @dragend="finishHomeDrag"
              @dragmove="moveHomeDrag"
              @dragstart="startHomeDrag('grid', cell.sourceIndex, $event)"
              @edit="enterEditMode"
              @open="openFolder(cell.folder.id)"
              @reorder="reorderHomeApp('grid', cell.sourceIndex, $event)"
            />
            <div
              v-else
              class="app-grid-slot"
              :data-home-area="cell.sourceIndex === null ? undefined : 'grid'"
              :data-home-index="cell.sourceIndex ?? undefined"
              :data-home-target-offset="cell.targetOffset"
              aria-hidden="true"
            ></div>
          </template>
        </TransitionGroup>
      </section>

      <section
        class="springboard-page springboard-page--library"
        :style="pageStyle"
        :aria-label="phone.t('Home.appLibrary')"
      >
        <div
          class="app-library-search"
          :class="{ 'app-library-search--focused': searchFocused }"
        >
          <Search :size="16" aria-hidden="true" />
          <input
            v-model="searchQuery"
            type="search"
            :placeholder="phone.t('Home.appLibrarySearch')"
            @focus="openAllApps"
          />
          <button
            v-if="searchQuery || searchFocused"
            type="button"
            :aria-label="phone.t('Common.cancel')"
            @click="clearSearch"
          >
            <X :size="15" />
          </button>
        </div>

        <div
          class="app-library-groups"
          :class="{ 'app-library-groups--behind': showAllApps }"
        >
          <article
            v-if="hiddenApps.length"
            class="app-library-group app-library-group--removed"
          >
            <div class="app-library-group__icons">
              <div
                v-for="app in hiddenApps.slice(0, 4)"
                :key="app.id"
                class="app-library-restore-item"
              >
                <AppIcon :app="app" compact :show-label="false" />
                <k-button
                  small
                  rounded
                  class="app-library-restore-button"
                  :aria-label="
                    phone.t('Home.addToHome', {
                      app: getPhoneAppLabel(app, phone.t),
                    })
                  "
                  @click.stop="restoreHomeApp(app.id)"
                >
                  <Plus :size="13" :stroke-width="3" />
                </k-button>
              </div>
            </div>
            <span>{{ phone.t('Home.removedFromHome') }}</span>
          </article>
          <article
            v-for="group in appGroups"
            :key="group.key"
            class="app-library-group"
          >
            <div class="app-library-group__icons">
              <AppIcon
                v-for="app in group.apps"
                :key="app.id"
                :app="app"
                compact
                :show-label="false"
              />
              <button
                v-if="group.moreApps.length"
                class="app-library-more"
                type="button"
                :aria-label="phone.t('Home.allApps')"
                @click="openAllApps"
              >
                <img
                  v-for="app in group.moreApps.slice(0, 4)"
                  :key="app.id"
                  :src="app.iconImage"
                  alt=""
                  draggable="false"
                />
              </button>
            </div>
            <span>{{ phone.t(`Home.groups.${group.key}`) }}</span>
          </article>
        </div>

        <Transition name="app-library-all">
          <section
            v-if="showAllApps"
            class="app-library-all"
            :aria-label="phone.t('Home.allApps')"
          >
            <div
              v-for="group in alphabeticalGroups"
              :key="group.letter"
              class="app-library-letter"
            >
              <h2>{{ group.letter }}</h2>
              <div
                v-for="app in group.apps"
                :key="app.id"
                class="app-library-row"
              >
                <AppIcon :app="app" compact :show-label="false" />
                <span>{{ getPhoneAppLabel(app, phone.t) }}</span>
                <k-button
                  v-if="appStore.homeLayout.hidden.includes(app.id)"
                  small
                  rounded
                  class="app-library-row-restore"
                  :aria-label="
                    phone.t('Home.addToHome', {
                      app: getPhoneAppLabel(app, phone.t),
                    })
                  "
                  @click.stop="restoreHomeApp(app.id)"
                >
                  <Plus :size="14" :stroke-width="3" />
                </k-button>
              </div>
            </div>
            <p v-if="filteredApps.length === 0" class="app-library-empty">
              {{ phone.t('Home.noApps') }}
            </p>
          </section>
        </Transition>
      </section>
    </div>

    <Teleport defer to="#phone-home-drag-portal">
      <div ref="homeDragLayer" class="home-drag-layer" aria-hidden="true"></div>
    </Teleport>

    <Transition name="edit-done">
      <k-glass
        v-if="editMode && isEditablePage && !folderOverlayVisible"
        component="button"
        class="springboard-edit-add"
        type="button"
        :aria-label="phone.t('Home.widgetSystem.add')"
        @click="widgetPickerOpened = true"
      >
        <Plus :size="20" :stroke-width="2.5" />
      </k-glass>
    </Transition>

    <Transition name="edit-done">
      <k-glass
        v-if="editMode && isEditablePage && !folderOverlayVisible"
        component="button"
        class="springboard-edit-done"
        type="button"
        :aria-label="phone.t('Common.done')"
        @click="editMode = false"
      >
        <Check :size="20" :stroke-width="3" aria-hidden="true" />
      </k-glass>
    </Transition>

    <Transition name="dock">
      <nav
        v-if="isAppPage"
        class="app-dock"
        :class="{ 'app-dock--editing': editMode }"
        :aria-label="phone.t('Home.dock')"
        data-home-area="dock"
      >
        <template
          v-for="slot in dockSlots"
          :key="slot.folder?.id ?? slot.app?.id ?? `dock-empty-${slot.index}`"
        >
          <AppIcon
            v-if="slot.app"
            :app="slot.app"
            data-home-area="dock"
            :data-home-app-id="slot.app.id"
            :data-home-item-key="`app-${slot.app.id}`"
            :data-home-index="slot.index"
            :edit-mode="editMode"
            :external-drag-visual="homeDragVisualActive"
            :show-label="false"
            :class="{
              'home-item--folder-hover':
                folderHoverTarget === `dock:${slot.index}`,
            }"
            @dragcancel="stopHomeDrag"
            @dragend="finishHomeDrag"
            @dragmove="moveHomeDrag"
            @dragstart="startHomeDrag('dock', slot.index, $event)"
            @edit="enterEditMode"
            @remove="removeHomeApp(slot.app.id)"
            @reorder="reorderHomeApp('dock', slot.index, $event)"
          />
          <HomeFolderIcon
            v-else-if="slot.folder"
            :apps="folderPreviewApps(slot.folder)"
            :default-name="phone.t('Home.folders.defaultName')"
            data-home-area="dock"
            :data-home-folder-id="slot.folder.id"
            :data-home-item-key="slot.folder.id"
            :data-home-index="slot.index"
            :edit-mode="editMode"
            :external-drag-visual="homeDragVisualActive"
            :folder="slot.folder"
            :show-label="false"
            :class="{
              'home-item--folder-hover':
                folderHoverTarget === `dock:${slot.index}`,
            }"
            @dragcancel="stopHomeDrag"
            @dragend="finishHomeDrag"
            @dragmove="moveHomeDrag"
            @dragstart="startHomeDrag('dock', slot.index, $event)"
            @edit="enterEditMode"
            @open="openFolder(slot.folder.id)"
            @reorder="reorderHomeApp('dock', slot.index, $event)"
          />
          <div
            v-else
            class="app-dock-slot"
            data-home-area="dock"
            :data-home-index="slot.index"
            aria-hidden="true"
          ></div>
        </template>
      </nav>
    </Transition>

    <nav
      v-if="phone.currentPage < libraryPage"
      class="page-indicator"
      :class="{ 'page-indicator--without-dock': phone.currentPage === 0 }"
      :aria-label="phone.t('Home.pages')"
    >
      <button
        v-for="pageIndex in appPages.length + 1"
        :key="pageIndex - 1"
        type="button"
        :class="{ active: phone.currentPage === pageIndex - 1 }"
        :aria-label="`${phone.t('Home.page')} ${pageIndex}`"
        @click="changePage(pageIndex - 1)"
      ></button>
      <k-button
        v-if="editMode && canAddHomePage"
        small
        rounded
        class="springboard-page-add"
        type="button"
        :aria-label="phone.t('Home.addPage')"
        @click="addHomePage"
      >
        <Plus :size="12" :stroke-width="2.8" />
      </k-button>
      <k-button
        v-if="editMode && canDeleteCurrentPage"
        small
        rounded
        class="springboard-page-delete"
        type="button"
        :aria-label="phone.t('Home.deletePage')"
        @click="deleteCurrentPage"
      >
        <Trash2 :size="12" :stroke-width="2.4" />
      </k-button>
    </nav>

    <Transition name="home-folder">
      <HomeFolderOverlay
        v-if="openedFolder"
        :apps="openedFolderApps"
        :edit-mode="editMode"
        :folder="openedFolder"
        :rename-on-open="renameFolderOnOpenId === openedFolder.id"
        @close="closeFolder"
        @drag-outside-change="folderDraggingOutside = $event"
        @edit="enterEditMode"
        @extract="extractOpenedFolderApp"
        @move="moveOpenedFolderApp"
        @rename="renameOpenedFolder"
        @rename-opened="renameFolderOnOpenId = null"
      />
    </Transition>

    <SkyProvider
      class="widget-action-provider"
      :dark="phone.isDarkMode"
      safe-areas
    >
      <SkyActionSheet
        class="widget-action-sheet"
        :opened="widgetActionId !== null"
        :aria-label="
          activeWidget
            ? phone.t(`Home.widgetSystem.${activeWidget.kind}.name`)
            : phone.t('Home.widgets.label')
        "
        @backdropclick="widgetActionId = null"
        @escape="widgetActionId = null"
      >
        <SkyActionGroup>
          <SkyActionsLabel>
            {{
              activeWidget
                ? phone.t(`Home.widgetSystem.${activeWidget.kind}.name`)
                : phone.t('Home.widgets.label')
            }}
          </SkyActionsLabel>
          <SkyActionButton
            class="widget-action-button"
            @click="openWidgetConfig"
          >
            <Pencil :size="20" />
            <span>{{ phone.t('Home.widgetSystem.editWidget') }}</span>
          </SkyActionButton>
          <SkyActionButton
            class="widget-action-button widget-action-remove"
            @click="activeWidget && removeWidget(activeWidget.id)"
          >
            <Trash2 :size="20" />
            <span>{{ phone.t('Home.widgetSystem.removeWidget') }}</span>
          </SkyActionButton>
        </SkyActionGroup>
        <SkyActionGroup>
          <SkyActionButton
            bold
            class="widget-action-cancel"
            @click="widgetActionId = null"
          >
            {{ phone.t('Common.cancel') }}
          </SkyActionButton>
        </SkyActionGroup>
      </SkyActionSheet>
    </SkyProvider>

    <WidgetPickerSheet
      :opened="widgetPickerOpened"
      @add="addWidget"
      @close="widgetPickerOpened = false"
    />
    <WidgetConfigSheet
      :instance="configuredWidget"
      :opened="widgetConfigId !== null"
      @close="widgetConfigId = null"
      @save="saveWidgetConfig"
    />
  </section>
</template>

<style scoped>
.widget-action-provider {
  position: absolute;
  z-index: 105;
  inset: 0;
  pointer-events: none;
}

.widget-action-sheet {
  --sky-overlay-layer: 105;
}

.widget-action-sheet :deep(.sky-overlay-backdrop) {
  background: rgb(0 0 0 / 58%);
}

.widget-action-sheet :deep(.sky-action-sheet__panel) {
  max-width: 100%;
}

.widget-action-sheet :deep(.sky-action-group) {
  border-radius: var(--sky-radius-card);
  background: var(--sky-surface);
}

.widget-action-sheet :deep(.sky-actions-label) {
  color: var(--sky-muted);
  background: transparent;
  font-size: 14px;
  font-weight: 600;
}

.widget-action-sheet :deep(.sky-action-button) {
  color: #fff;
  font-size: 17px;
}

.widget-action-sheet :deep(.widget-action-button) {
  justify-content: flex-start;
  gap: var(--sky-space-3);
  text-align: left;
}

.widget-action-sheet :deep(.widget-action-button svg) {
  width: 24px;
  flex: none;
}

.widget-action-sheet :deep(.widget-action-remove) {
  color: var(--sky-danger);
}
</style>
