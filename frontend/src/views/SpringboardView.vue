<script setup lang="ts">
import { Search, X } from 'lucide-vue-next'
import { computed, ref } from 'vue'

import AppIcon from '@/components/AppIcon.vue'
import SpringboardWidgets from '@/components/SpringboardWidgets.vue'
import { PHONE_APPS } from '@/config/apps'
import { usePhoneStore } from '@/stores/phone'
import { clampPage, SPRINGBOARD_PAGE_COUNT } from '@/utils/pages'

const phone = usePhoneStore()
const searchQuery = ref('')
const searchFocused = ref(false)
const dragOffset = ref(0)
const dragging = ref(false)
let pointerStart = 0
let pointerStartedAt = 0

const gridApps = computed(() =>
  [...PHONE_APPS].sort((a, b) => a.gridOrder - b.gridOrder),
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
const appGroups = computed(() => [
  gridApps.value.slice(0, 3),
  gridApps.value.slice(3, 6),
])
const trackStyle = computed(() => ({
  '--drag-offset': `${dragOffset.value}px`,
  '--springboard-page': phone.currentPage,
}))

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
    phone.setCurrentPage(phone.currentPage + (distance < 0 ? 1 : -1))
  }
  dragging.value = false
  dragOffset.value = 0
}

function clearSearch(): void {
  searchQuery.value = ''
  searchFocused.value = false
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
        :aria-label="phone.t('Home.widgets.label')"
      >
        <SpringboardWidgets />
      </section>

      <section
        class="springboard-page springboard-page--apps"
        :aria-label="phone.t('Home.apps')"
      >
        <div class="app-grid">
          <AppIcon v-for="app in gridApps" :key="app.id" :app="app" />
        </div>
      </section>

      <section
        class="springboard-page springboard-page--library"
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
            @focus="searchFocused = true"
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

        <div v-if="searchQuery" class="app-library-results">
          <AppIcon
            v-for="app in filteredApps"
            :key="app.id"
            :app="app"
            compact
          />
          <p v-if="filteredApps.length === 0">{{ phone.t('Home.noApps') }}</p>
        </div>
        <div v-else class="app-library-groups">
          <article
            v-for="(group, index) in appGroups"
            :key="index"
            class="app-library-group"
          >
            <div>
              <AppIcon
                v-for="app in group"
                :key="app.id"
                :app="app"
                compact
                :show-label="false"
              />
            </div>
            <span>{{ phone.t(`Home.groups.${index}`) }}</span>
          </article>
        </div>
      </section>
    </div>

    <Transition name="dock">
      <nav
        v-if="phone.currentPage === 1"
        class="app-dock"
        :aria-label="phone.t('Home.dock')"
      >
        <AppIcon
          v-for="app in dockApps"
          :key="app.id"
          :app="app"
          :show-label="false"
        />
      </nav>
    </Transition>

    <nav class="page-indicator" :aria-label="phone.t('Home.pages')">
      <button
        v-for="page in SPRINGBOARD_PAGE_COUNT"
        :key="page"
        type="button"
        :class="{ active: phone.currentPage === page - 1 }"
        :aria-label="`${phone.t('Home.page')} ${page}`"
        @click="phone.setCurrentPage(clampPage(page - 1))"
      ></button>
    </nav>
  </section>
</template>
