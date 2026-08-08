<script setup lang="ts">
import { Pencil, Plus, Search, Trash2, X } from 'lucide-vue-next'
import { kButton, kGlass, kList, kListItem, kSheet } from 'konsta/vue'
import { computed, nextTick, ref, watch } from 'vue'

import AppIcon from '@/components/AppIcon.vue'
import SpringboardWidgetGrid from '@/components/SpringboardWidgetGrid.vue'
import WidgetConfigSheet from '@/components/WidgetConfigSheet.vue'
import WidgetPickerSheet from '@/components/WidgetPickerSheet.vue'
import { PHONE_APPS } from '@/config/apps'
import { useAppStoreStore } from '@/stores/app-store'
import { usePhoneStore } from '@/stores/phone'
import { useWidgetsStore } from '@/stores/widgets'
import type { PhoneAppCategory, PhoneAppDefinition } from '@/types/apps'
import type { LaunchablePhoneAppId } from '@/types/apps'
import type { WidgetKind, WidgetSettings, WidgetSize } from '@/types/widgets'
import {
  deleteHomePage as previewHomePageDelete,
  HOME_GRID_PAGE_SIZE,
  MAX_HOME_GRID_PAGES,
  type HomeArea,
} from '@/utils/homeLayout'
import {
  deleteWidgetPage as previewWidgetPageDelete,
  moveWidget as previewWidgetMove,
  WIDGET_GRID_COLUMNS,
  widgetOccupiedCells,
} from '@/utils/widgetLayout'

const APP_LIBRARY_CATEGORIES: PhoneAppCategory[] = [
  'games',
  'productivity',
  'social',
  'utilities',
  'shopping',
]
const phone = usePhoneStore()
const appStore = useAppStoreStore()
const widgets = useWidgetsStore()
const searchQuery = ref('')
const searchFocused = ref(false)
const showAllApps = ref(false)
const editMode = ref(false)
const widgetPickerOpened = ref(false)
const widgetActionId = ref<string | null>(null)
const widgetConfigId = ref<string | null>(null)
const draggingWidgetId = ref<string | null>(null)
const widgetDragGrip = ref<{ x: number; y: number } | null>(null)
const widgetDragSize = ref<{ height: number; width: number } | null>(null)
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

const installedApps = computed(() =>
  PHONE_APPS.filter(
    (app) => app.category !== 'games' || appStore.claimedApps.includes(app.id),
  ),
)
const installedAppsById = computed(
  () => new Map(installedApps.value.map((app) => [app.id, app])),
)
const hiddenApps = computed(() =>
  installedApps.value.filter((app) =>
    appStore.homeLayout.hidden.includes(app.id),
  ),
)
const gridEntries = computed(() =>
  appStore.homeLayout.grid
    .map((id, sourceIndex) => ({
      app: id ? (installedAppsById.value.get(id) ?? null) : null,
      sourceIndex,
    }))
    .filter(
      (entry): entry is { app: PhoneAppDefinition; sourceIndex: number } =>
        entry.app !== null,
    ),
)
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
const appPages = computed(() => {
  const entries = [...gridEntries.value]
  const pages: Array<{
    cells: Array<{ app: PhoneAppDefinition; sourceIndex: number } | null>
    page: number
  }> = []
  const maxWidgetPage = Math.max(
    1,
    ...previewWidgetLayout.value.instances.map((instance) => instance.page),
  )
  const persistedHomePages = Math.max(
    1,
    Math.ceil(appStore.homeLayout.grid.length / HOME_GRID_PAGE_SIZE),
  )
  const lastHomePage = Math.max(maxWidgetPage, persistedHomePages)
  let page = 1
  let entryIndex = 0
  while (entryIndex < entries.length || page <= lastHomePage) {
    const occupied = widgetOccupiedCells(
      previewWidgetLayout.value.instances,
      page,
    )
    if (widgetDragPreview.value) {
      for (const cell of widgetOccupiedCells(widgets.layout.instances, page)) {
        occupied.add(cell)
      }
    }
    const cells = Array.from<{
      app: PhoneAppDefinition
      sourceIndex: number
    } | null>({ length: HOME_GRID_PAGE_SIZE }).fill(null)
    for (let cell = 0; cell < HOME_GRID_PAGE_SIZE; cell += 1) {
      if (occupied.has(cell) || entryIndex >= entries.length) continue
      cells[cell] = entries[entryIndex]
      entryIndex += 1
    }
    pages.push({ cells, page })
    page += 1
  }
  return pages.length
    ? pages
    : [{ cells: Array(HOME_GRID_PAGE_SIZE).fill(null), page: 1 }]
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
  () =>
    appStore.homeLayout.grid.length < HOME_GRID_PAGE_SIZE * MAX_HOME_GRID_PAGES,
)
const addingHomePage = ref(false)
const persistedHomePageCount = computed(() =>
  Math.max(1, Math.ceil(appStore.homeLayout.grid.length / HOME_GRID_PAGE_SIZE)),
)
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
  appStore.homeLayout.dock.map((id) =>
    id ? (installedAppsById.value.get(id) ?? null) : null,
  ),
)
const filteredApps = computed(() => {
  const query = searchQuery.value.trim().toLocaleLowerCase(phone.lang)
  if (!query) return installedApps.value
  return installedApps.value.filter((app) =>
    phone.t(app.labelKey).toLocaleLowerCase(phone.lang).includes(query),
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
    phone.t(a.labelKey).localeCompare(phone.t(b.labelKey), phone.lang),
  )) {
    const letter = phone.t(app.labelKey).charAt(0).toLocaleUpperCase(phone.lang)
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
  if (target.closest('button, input, .home-widget-shell')) {
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
  if (editMode.value) return
  dragging.value = true
  ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
  clearBackgroundHold()
  backgroundHoldTimer = window.setTimeout(() => {
    enterEditMode()
    backgroundHoldTimer = undefined
  }, 520)
}

function onPointerMove(event: PointerEvent): void {
  const distanceX = event.clientX - pointerStart
  const distanceY = event.clientY - pointerStartY
  if (Math.hypot(distanceX, distanceY) > 8) {
    clearBackgroundHold()
    blankTapCandidate = false
  }
  if (!dragging.value) return
  if (Math.abs(distanceY) > Math.abs(distanceX)) {
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
  const bounds = widget.getBoundingClientRect()
  draggingWidgetId.value = id
  widgetDragGrip.value = {
    x: event.clientX - bounds.left,
    y: event.clientY - bounds.top,
  }
  widgetDragSize.value = { height: bounds.height, width: bounds.width }
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
  const springboard = grid?.closest<HTMLElement>('.springboard')
  if (!grid || !pageElement || !springboard) return
  const renderedGridBounds = grid.getBoundingClientRect()
  const pageBounds = pageElement.getBoundingClientRect()
  const springboardBounds = springboard.getBoundingClientRect()
  const gridLeft =
    springboardBounds.left + (renderedGridBounds.left - pageBounds.left)
  const gridStyle = getComputedStyle(grid)
  const columnGap = Number.parseFloat(gridStyle.columnGap) || 0
  const rowGap = Number.parseFloat(gridStyle.rowGap) || 0
  const columnWidth =
    (renderedGridBounds.width - columnGap * (WIDGET_GRID_COLUMNS - 1)) /
    WIDGET_GRID_COLUMNS
  const rowHeight = Number.parseFloat(gridStyle.gridAutoRows)
  const column = Math.round(
    (event.clientX - grip.x - gridLeft) / (columnWidth + columnGap),
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

function queueEdgePageTurn(
  event: PointerEvent,
  dragType: 'app' | 'widget',
): void {
  const springboard = document.querySelector<HTMLElement>('.springboard')
  if (!springboard) return
  const bounds = springboard.getBoundingClientRect()
  const edgeSize = Math.min(42, bounds.width * 0.12)
  let direction = 0
  if (dragType === 'widget' && widgetDragGrip.value && widgetDragSize.value) {
    const widgetLeft = event.clientX - widgetDragGrip.value.x
    const widgetRight = widgetLeft + widgetDragSize.value.width
    const overhang = Math.min(22, widgetDragSize.value.width * 0.14)
    if (widgetLeft <= bounds.left - overhang) direction = -1
    else if (widgetRight >= bounds.right + overhang) direction = 1
  } else if (event.clientX <= bounds.left + edgeSize) direction = -1
  else if (event.clientX >= bounds.right - edgeSize) direction = 1
  const minimumPage = dragType === 'widget' ? 0 : 1
  const maximumPage = libraryPage.value - 1
  const destination = phone.currentPage + direction

  if (
    direction === 0 ||
    destination < minimumPage ||
    destination > maximumPage
  ) {
    if (edgePageTimer !== undefined) window.clearTimeout(edgePageTimer)
    edgePageTimer = undefined
    edgePageDirection = 0
    edgePageLocked = false
    return
  }
  if (edgePageLocked && edgePageDirection === direction) return
  if (edgePageLocked) edgePageLocked = false
  if (edgePageTimer !== undefined && edgePageDirection === direction) return
  if (edgePageTimer !== undefined) window.clearTimeout(edgePageTimer)
  edgePageDirection = direction
  edgePageTimer = window.setTimeout(() => {
    const targetPage = phone.currentPage + direction
    changePage(targetPage)
    if (dragType === 'widget' && lastWidgetPointer) {
      updateWidgetDragPreview(lastWidgetPointer)
    }
    edgePageTimer = undefined
    edgePageDirection = direction
    edgePageLocked = true
  }, 520)
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
  widgetDragSize.value = null
  widgetDragPreview.value = null
}

function finishWidgetDrag(event: PointerEvent): void {
  const id = draggingWidgetId.value
  if (!id) return
  lastWidgetPointer = { clientX: event.clientX, clientY: event.clientY }
  updateWidgetDragPreview(lastWidgetPointer)
  const preview = widgetDragPreview.value
  if (preview?.id === id) {
    widgets.move(id, preview.page, preview.column, preview.row)
  }
  draggingWidgetId.value = null
  clearWidgetDragPreview()
}

function stopWidgetDrag(): void {
  draggingWidgetId.value = null
  clearWidgetDragPreview()
}

function removeWidget(id: string): void {
  widgets.remove(id)
  if (widgetActionId.value === id) widgetActionId.value = null
  if (widgetConfigId.value === id) widgetConfigId.value = null
}

async function addWidget(kind: WidgetKind, size: WidgetSize): Promise<void> {
  const targetPage = isEditablePage.value ? phone.currentPage : 1
  const addedId = widgets.add(kind, size, targetPage)
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
  widgets.resize(id, size)
  widgets.updateSettings(id, settings)
  widgetConfigId.value = null
  editMode.value = true
  await nextTick()
  const configured = widgets.layout.instances.find(
    (instance) => instance.id === id,
  )
  if (configured) changePage(configured.page)
}

function targetHomeIndex(page: number, cell: number): number {
  return Math.min(
    Math.max(0, appStore.homeLayout.grid.length - 1),
    (page - 1) * HOME_GRID_PAGE_SIZE + cell,
  )
}

function startHomeDrag(area: HomeArea, index: number): void {
  draggingHomeApp.value = { area, index }
}

function moveHomeDrag(event: PointerEvent): void {
  if (draggingHomeApp.value?.area === 'grid') {
    queueEdgePageTurn(event, 'app')
  }
}

function finishHomeDrag(event: PointerEvent): void {
  clearEdgePageTurn()
  const dragged = draggingHomeApp.value
  if (!dragged) return
  const target = document
    .elementsFromPoint(event.clientX, event.clientY)
    .find(
      (element) =>
        !element.closest('.app-icon-item--dragging') &&
        (element.closest('[data-home-index]') ||
          element.closest('[data-home-area]')),
    )
  const targetArea = target?.closest<HTMLElement>('[data-home-area]')
  let targetItem = target?.closest<HTMLElement>('[data-home-index]')
  if (!targetItem && targetArea) {
    const slotItems = Array.from(
      targetArea.querySelectorAll<HTMLElement>('[data-home-index]'),
    )
    targetItem = slotItems.reduce<HTMLElement | undefined>((closest, slot) => {
      if (!closest) return slot
      const slotBounds = slot.getBoundingClientRect()
      const closestBounds = closest.getBoundingClientRect()
      const slotDistance = Math.hypot(
        event.clientX - (slotBounds.left + slotBounds.width / 2),
        event.clientY - (slotBounds.top + slotBounds.height / 2),
      )
      const closestDistance = Math.hypot(
        event.clientX - (closestBounds.left + closestBounds.width / 2),
        event.clientY - (closestBounds.top + closestBounds.height / 2),
      )
      return slotDistance < closestDistance ? slot : closest
    }, undefined)
  }
  const area = (targetItem?.dataset.homeArea ??
    targetArea?.dataset.homeArea) as HomeArea | undefined
  if ((area === 'grid' || area === 'dock') && targetItem) {
    const targetIndex = Number.parseInt(targetItem.dataset.homeIndex ?? '', 10)
    appStore.moveHomeApp(dragged.area, dragged.index, area, targetIndex)
  }
  draggingHomeApp.value = null
}

function stopHomeDrag(): void {
  clearEdgePageTurn()
  draggingHomeApp.value = null
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
</script>

<template>
  <section
    class="springboard"
    :class="[
      `wallpaper--${phone.preferences.settings.wallpaper}`,
      {
        'springboard--dragging': dragging,
        'springboard--editing': editMode,
        'springboard--widget-dragging': draggingWidgetId !== null,
      },
    ]"
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
          />
        </div>
      </section>

      <section
        v-for="page in appPages"
        :key="`apps-${page.page}`"
        class="springboard-page springboard-page--apps"
        :style="pageStyle"
        :aria-label="phone.t('Home.apps')"
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
        />
        <TransitionGroup
          :name="
            draggingWidgetId && !pageTransitioning ? 'app-reflow' : undefined
          "
          tag="div"
          class="app-grid"
          data-home-area="grid"
        >
          <template
            v-for="(cell, cellIndex) in page.cells"
            :key="cell?.app.id ?? `grid-empty-${page.page}-${cellIndex}`"
          >
            <AppIcon
              v-if="cell"
              :app="cell.app"
              data-home-area="grid"
              :data-home-index="cell.sourceIndex"
              :edit-mode="editMode"
              @dragcancel="stopHomeDrag"
              @dragend="finishHomeDrag"
              @dragmove="moveHomeDrag"
              @dragstart="startHomeDrag('grid', cell.sourceIndex)"
              @edit="enterEditMode"
              @remove="removeHomeApp(cell.app.id)"
            />
            <div
              v-else
              class="app-grid-slot"
              data-home-area="grid"
              :data-home-index="targetHomeIndex(page.page, cellIndex)"
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
                    phone.t('Home.addToHome', { app: phone.t(app.labelKey) })
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
                <span>{{ phone.t(app.labelKey) }}</span>
                <k-button
                  v-if="appStore.homeLayout.hidden.includes(app.id)"
                  small
                  rounded
                  class="app-library-row-restore"
                  :aria-label="
                    phone.t('Home.addToHome', { app: phone.t(app.labelKey) })
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

    <Transition name="edit-done">
      <k-glass
        v-if="editMode && isEditablePage"
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
        v-if="editMode && isEditablePage"
        component="button"
        class="springboard-edit-done"
        type="button"
        @click="editMode = false"
      >
        {{ phone.t('Common.done') }}
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
          v-for="(app, appIndex) in dockSlots"
          :key="app?.id ?? `dock-empty-${appIndex}`"
        >
          <AppIcon
            v-if="app"
            :app="app"
            data-home-area="dock"
            :data-home-index="appIndex"
            :edit-mode="editMode"
            :show-label="false"
            @dragcancel="stopHomeDrag"
            @dragend="finishHomeDrag"
            @dragmove="moveHomeDrag"
            @dragstart="startHomeDrag('dock', appIndex)"
            @edit="enterEditMode"
            @remove="removeHomeApp(app.id)"
          />
          <div
            v-else
            class="app-dock-slot"
            data-home-area="dock"
            :data-home-index="appIndex"
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

    <k-sheet
      :opened="widgetActionId !== null"
      class="widget-action-sheet"
      @backdropclick="widgetActionId = null"
    >
      <div class="widget-sheet-handle" />
      <h3>
        {{
          activeWidget
            ? phone.t(`Home.widgetSystem.${activeWidget.kind}.name`)
            : phone.t('Home.widgets.label')
        }}
      </h3>
      <k-list inset strong class="widget-action-list">
        <k-list-item
          link
          link-component="button"
          :title="phone.t('Home.widgetSystem.editWidget')"
          @click="openWidgetConfig"
        >
          <template #media><Pencil :size="20" /></template>
        </k-list-item>
        <k-list-item
          link
          link-component="button"
          class="widget-action-remove"
          :title="phone.t('Home.widgetSystem.removeWidget')"
          @click="activeWidget && removeWidget(activeWidget.id)"
        >
          <template #media><Trash2 :size="20" /></template>
        </k-list-item>
      </k-list>
      <k-button
        large
        rounded
        class="widget-action-cancel"
        @click="widgetActionId = null"
      >
        {{ phone.t('Common.cancel') }}
      </k-button>
    </k-sheet>

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
:global(.widget-action-sheet) {
  z-index: 105;
  padding: 9px 0 30px;
  border-radius: 25px 25px 0 0;
}

.widget-sheet-handle {
  width: 36px;
  height: 5px;
  margin: 0 auto 9px;
  border-radius: 999px;
  background: rgb(142 142 147 / 45%);
}

.widget-action-sheet h3 {
  margin: 3px 18px 9px;
  color: inherit;
  font-size: 16px;
  font-weight: 650;
  text-align: center;
}

.widget-action-list {
  margin-top: 0;
  margin-bottom: 10px;
}

.widget-action-remove :deep([class*='title']),
.widget-action-remove :deep(svg) {
  color: #ff3b30 !important;
}

.widget-action-cancel {
  width: calc(100% - 32px);
  margin: 0 16px;
}
</style>
