<script setup lang="ts">
import { Search, X } from 'lucide-vue-next'
import { computed, ref } from 'vue'

import AppIcon from '@/components/AppIcon.vue'
import SpringboardWidgets from '@/components/SpringboardWidgets.vue'
import { PHONE_APPS } from '@/config/apps'
import { usePhoneStore } from '@/stores/phone'
import type { PhoneAppDefinition } from '@/types/apps'
import { paginateItems } from '@/utils/pages'

const APPS_PER_HOME_PAGE = 16
const phone = usePhoneStore()
const searchQuery = ref('')
const searchFocused = ref(false)
const showAllApps = ref(false)
const dragOffset = ref(0)
const dragging = ref(false)
let pointerStart = 0
let pointerStartedAt = 0

const gridApps = computed(() =>
  [...PHONE_APPS].sort((a, b) => a.gridOrder - b.gridOrder),
)
const appPages = computed(() =>
  paginateItems(gridApps.value, APPS_PER_HOME_PAGE),
)
const pageCount = computed(() => appPages.value.length + 2)
const libraryPage = computed(() => pageCount.value - 1)
const isAppPage = computed(
  () => phone.currentPage > 0 && phone.currentPage < libraryPage.value,
)
const dockApps = computed(() =>
  PHONE_APPS.filter((app) => app.dockOrder !== null).sort(
    (a, b) => (a.dockOrder ?? 0) - (b.dockOrder ?? 0),
  ),
)
const filteredApps = computed(() => {
  const query = searchQuery.value.trim().toLocaleLowerCase(phone.lang)
  if (!query) return gridApps.value
  return gridApps.value.filter((app) =>
    phone.t(app.labelKey).toLocaleLowerCase(phone.lang).includes(query),
  )
})
const appGroups = computed(() => {
  const groups: PhoneAppDefinition[][] = []
  for (let index = 0; index < gridApps.value.length; index += 3) {
    groups.push(gridApps.value.slice(index, index + 3))
  }
  return groups.map((apps, index) => ({
    apps,
    moreApps: groups[(index + 1) % groups.length] ?? [],
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

function clearSearch(): void {
  searchQuery.value = ''
  searchFocused.value = false
  showAllApps.value = false
}

function openAllApps(): void {
  searchFocused.value = true
  showAllApps.value = true
}
</script>

<template>
  <section
    class="springboard"
    :class="[
      `wallpaper--${phone.preferences.settings.wallpaper}`,
      { 'springboard--dragging': dragging },
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
        <div class="app-grid">
          <AppIcon v-for="app in apps" :key="app.id" :app="app" />
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
            v-for="(group, index) in appGroups"
            :key="index"
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
            <span>{{
              phone.t(index < 2 ? `Home.groups.${index}` : 'Home.groups.other')
            }}</span>
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

    <Transition name="dock">
      <nav v-if="isAppPage" class="app-dock" :aria-label="phone.t('Home.dock')">
        <AppIcon
          v-for="app in dockApps"
          :key="app.id"
          :app="app"
          :show-label="false"
        />
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
