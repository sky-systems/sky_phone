<script setup lang="ts">
import { Search, X } from 'lucide-vue-next'
import { kGlass } from 'konsta/vue'
import { computed, ref, watch } from 'vue'

import AppIcon from '@/components/AppIcon.vue'
import SpringboardWidgets from '@/components/SpringboardWidgets.vue'
import { PHONE_APPS } from '@/config/apps'
import { useAppStoreStore } from '@/stores/app-store'
import { usePhoneStore } from '@/stores/phone'
import type { PhoneAppCategory, PhoneAppDefinition } from '@/types/apps'
import type { LaunchablePhoneAppId } from '@/types/apps'
import { HOME_GRID_PAGE_SIZE, type HomeArea } from '@/utils/homeLayout'
import { paginateItems } from '@/utils/pages'

const APP_LIBRARY_CATEGORIES: PhoneAppCategory[] = [
  'games',
  'productivity',
  'social',
  'utilities',
  'shopping',
]
const phone = usePhoneStore()
const appStore = useAppStoreStore()
const searchQuery = ref('')
const searchFocused = ref(false)
const showAllApps = ref(false)
const editMode = ref(false)
const dragOffset = ref(0)
const dragging = ref(false)
const draggingHomeApp = ref<{
  appId: LaunchablePhoneAppId
  area: HomeArea
} | null>(null)
let pointerStart = 0
let pointerStartedAt = 0

const installedApps = computed(() =>
  PHONE_APPS.filter(
    (app) => app.category !== 'games' || appStore.claimedApps.includes(app.id),
  ),
)
const installedAppsById = computed(
  () => new Map(installedApps.value.map((app) => [app.id, app])),
)
const gridSlots = computed(() =>
  appStore.homeLayout.grid.map((id) =>
    id ? (installedAppsById.value.get(id) ?? null) : null,
  ),
)
const appPages = computed(() =>
  paginateItems(gridSlots.value, HOME_GRID_PAGE_SIZE),
)
const pageCount = computed(() => appPages.value.length + 2)
const libraryPage = computed(() => pageCount.value - 1)
const isAppPage = computed(
  () => phone.currentPage > 0 && phone.currentPage < libraryPage.value,
)
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

function onPointerDown(event: PointerEvent): void {
  if (editMode.value) return
  const target = event.target as HTMLElement
  if (target.closest('button, input')) return
  pointerStart = event.clientX
  pointerStartedAt = Date.now()
  dragging.value = true
  ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
}

function onPointerMove(event: PointerEvent): void {
  if (!dragging.value) return
  dragOffset.value = event.clientX - pointerStart
}

function finishPointer(event: PointerEvent): void {
  if (!dragging.value) return
  const distance = event.clientX - pointerStart
  const elapsed = Math.max(1, Date.now() - pointerStartedAt)
  const velocity = Math.abs(distance) / elapsed
  if (Math.abs(distance) > 48 || velocity > 0.45) {
    phone.setCurrentPage(
      phone.currentPage + (distance < 0 ? 1 : -1),
      pageCount.value,
    )
  }
  dragging.value = false
  dragOffset.value = 0
}

function enterEditMode(): void {
  editMode.value = true
  dragging.value = false
  dragOffset.value = 0
}

function startHomeDrag(appId: LaunchablePhoneAppId, area: HomeArea): void {
  draggingHomeApp.value = { appId, area }
}

function finishHomeDrag(event: PointerEvent): void {
  const dragged = draggingHomeApp.value
  if (!dragged) return
  const target = document
    .elementsFromPoint(event.clientX, event.clientY)
    .find((element) => !element.closest('.app-icon-item--dragging'))
  const targetItem = target?.closest<HTMLElement>('[data-home-index]')
  const targetArea = target?.closest<HTMLElement>('[data-home-area]')
  const area = (targetItem?.dataset.homeArea ??
    targetArea?.dataset.homeArea) as HomeArea | undefined
  if (area === 'grid' || area === 'dock') {
    const fallbackIndex =
      area === 'dock'
        ? appStore.homeLayout.dock.length
        : appStore.homeLayout.grid.length
    const targetIndex = Number.parseInt(
      targetItem?.dataset.homeIndex ?? `${fallbackIndex}`,
      10,
    )
    appStore.moveHomeApp(dragged.appId, dragged.area, area, targetIndex)
  }
  draggingHomeApp.value = null
}

function stopHomeDrag(): void {
  draggingHomeApp.value = null
}

function removeHomeApp(appId: LaunchablePhoneAppId): void {
  appStore.removeHomeApp(appId)
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

watch(isAppPage, (visible) => {
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
      },
    ]"
  >
    <div
      class="springboard-track"
      :style="trackStyle"
      @pointerdown="onPointerDown"
      @pointermove="onPointerMove"
      @pointerup="finishPointer"
      @pointercancel="finishPointer"
    >
      <section
        class="springboard-page springboard-page--widgets"
        :style="pageStyle"
        :aria-label="phone.t('Home.widgets.label')"
      >
        <SpringboardWidgets />
      </section>

      <section
        v-for="(apps, pageIndex) in appPages"
        :key="`apps-${pageIndex}`"
        class="springboard-page springboard-page--apps"
        :style="pageStyle"
        :aria-label="phone.t('Home.apps')"
      >
        <div class="app-grid" data-home-area="grid">
          <template
            v-for="(app, appIndex) in apps"
            :key="
              app?.id ??
              `grid-empty-${pageIndex * HOME_GRID_PAGE_SIZE + appIndex}`
            "
          >
            <AppIcon
              v-if="app"
              :app="app"
              data-home-area="grid"
              :data-home-index="pageIndex * HOME_GRID_PAGE_SIZE + appIndex"
              :edit-mode="editMode"
              @dragcancel="stopHomeDrag"
              @dragend="finishHomeDrag"
              @dragstart="startHomeDrag(app.id, 'grid')"
              @edit="enterEditMode"
              @remove="removeHomeApp(app.id)"
            />
            <div
              v-else
              class="app-grid-slot"
              data-home-area="grid"
              :data-home-index="pageIndex * HOME_GRID_PAGE_SIZE + appIndex"
              aria-hidden="true"
            ></div>
          </template>
        </div>
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
        v-if="editMode && isAppPage"
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
            @dragstart="startHomeDrag(app.id, 'dock')"
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
      v-if="isAppPage && appPages.length > 1"
      class="page-indicator"
      :aria-label="phone.t('Home.pages')"
    >
      <button
        v-for="(_, pageIndex) in appPages"
        :key="pageIndex"
        type="button"
        :class="{ active: phone.currentPage === pageIndex + 1 }"
        :aria-label="`${phone.t('Home.page')} ${pageIndex + 1}`"
        @click="phone.setCurrentPage(pageIndex + 1, pageCount)"
      ></button>
    </nav>
  </section>
</template>
