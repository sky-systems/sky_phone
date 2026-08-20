<script setup lang="ts">
import { Check, Pencil, X } from 'lucide-vue-next'
import { computed, nextTick, ref, watch } from 'vue'

import AppIcon from '@/components/AppIcon.vue'
import { usePhoneStore } from '@/stores/phone'
import type { PhoneAppDefinition } from '@/types/apps'
import { SkyField, SkyLink } from '@/ui'
import {
  HOME_FOLDER_NAME_MAX_LENGTH,
  HOME_FOLDER_PAGE_SIZE,
  type HomeFolder,
} from '@/utils/homeLayout'

type FolderAppEntry = {
  app: PhoneAppDefinition
  index: number
}

const props = defineProps<{
  apps: FolderAppEntry[]
  editMode: boolean
  folder: HomeFolder
  renameOnOpen: boolean
}>()
const emit = defineEmits<{
  close: []
  'drag-outside-change': [outside: boolean]
  edit: []
  extract: [index: number, event: PointerEvent]
  move: [sourceIndex: number, targetIndex: number]
  rename: [name: string]
  'rename-opened': []
}>()

const phone = usePhoneStore()
const currentPage = ref(0)
const pageTransitionDirection = ref<'backward' | 'forward'>('forward')
const draggingIndex = ref<number | null>(null)
const draggingOutside = ref(false)
const panelElement = ref<HTMLElement | null>(null)
const renameOpened = ref(false)
const renameDraft = ref('')
let pagePointerStart = 0
let pagePointerId: number | null = null

const folderName = computed(
  () => props.folder.name || phone.t('Home.folders.defaultName'),
)
const pageCount = computed(() =>
  Math.max(1, Math.ceil(props.folder.apps.length / HOME_FOLDER_PAGE_SIZE)),
)
const pageTransitionName = computed(
  () => `home-folder-page-${pageTransitionDirection.value}`,
)
const visibleApps = computed(() => {
  const start = currentPage.value * HOME_FOLDER_PAGE_SIZE
  return props.apps.filter(
    (entry) =>
      entry.index >= start && entry.index < start + HOME_FOLDER_PAGE_SIZE,
  )
})

watch(pageCount, (count) => {
  const nextPage = Math.min(currentPage.value, count - 1)
  if (nextPage === currentPage.value) return
  pageTransitionDirection.value = 'backward'
  currentPage.value = nextPage
})

watch(
  () => props.folder.name,
  (name) => {
    if (!renameOpened.value) renameDraft.value = name || folderName.value
  },
  { immediate: true },
)

watch(
  () => props.renameOnOpen,
  async (shouldOpen) => {
    if (!shouldOpen) return
    renameDraft.value = props.folder.name || folderName.value
    renameOpened.value = true
    emit('rename-opened')
    await nextTick()
    document
      .querySelector<HTMLInputElement>(
        '.home-folder-rename-field .sky-field__input',
      )
      ?.select()
  },
  { immediate: true },
)

function openRename(): void {
  renameDraft.value = props.folder.name || folderName.value
  renameOpened.value = true
  void nextTick(() => {
    document
      .querySelector<HTMLInputElement>(
        '.home-folder-rename-field .sky-field__input',
      )
      ?.select()
  })
}

function saveRename(): void {
  emit(
    'rename',
    renameDraft.value.trim() || phone.t('Home.folders.defaultName'),
  )
  renameOpened.value = false
}

function startFolderAppDrag(index: number): void {
  draggingIndex.value = index
  setDraggingOutside(false)
}

function isPointerInsidePanel(event: PointerEvent): boolean {
  const panelBounds = panelElement.value?.getBoundingClientRect()
  if (!panelBounds) return false
  return (
    event.clientX >= panelBounds.left &&
    event.clientX <= panelBounds.right &&
    event.clientY >= panelBounds.top &&
    event.clientY <= panelBounds.bottom
  )
}

function moveFolderAppDrag(event: PointerEvent): void {
  if (draggingIndex.value === null || draggingOutside.value) return
  if (!isPointerInsidePanel(event)) setDraggingOutside(true)
}

function setDraggingOutside(outside: boolean): void {
  if (draggingOutside.value === outside) return
  draggingOutside.value = outside
  emit('drag-outside-change', outside)
}

function finishFolderAppDrag(event: PointerEvent): void {
  const sourceIndex = draggingIndex.value
  const shouldExtract = draggingOutside.value || !isPointerInsidePanel(event)
  draggingIndex.value = null
  if (sourceIndex === null) {
    setDraggingOutside(false)
    return
  }
  if (shouldExtract) {
    emit('extract', sourceIndex, event)
    setDraggingOutside(false)
    return
  }
  setDraggingOutside(false)

  const target = document
    .elementsFromPoint(event.clientX, event.clientY)
    .map((element) => element.closest<HTMLElement>('[data-folder-app-index]'))
    .find(
      (element) =>
        element && Number(element.dataset.folderAppIndex) !== sourceIndex,
    )
  if (!target) return
  const targetIndex = Number(target.dataset.folderAppIndex)
  if (Number.isInteger(targetIndex)) emit('move', sourceIndex, targetIndex)
}

function stopFolderAppDrag(): void {
  draggingIndex.value = null
  setDraggingOutside(false)
}

function goToPage(page: number): void {
  const nextPage = Math.max(0, Math.min(pageCount.value - 1, page))
  if (nextPage === currentPage.value) return
  pageTransitionDirection.value =
    nextPage > currentPage.value ? 'forward' : 'backward'
  currentPage.value = nextPage
}

function startPageSwipe(event: PointerEvent): void {
  if ((event.target as HTMLElement).closest('button, input')) return
  pagePointerStart = event.clientX
  pagePointerId = event.pointerId
  ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
}

function finishPageSwipe(event: PointerEvent): void {
  if (pagePointerId !== event.pointerId) return
  const distance = event.clientX - pagePointerStart
  if (Math.abs(distance) > 42) {
    goToPage(currentPage.value + (distance < 0 ? 1 : -1))
  }
  pagePointerId = null
}
</script>

<template>
  <div
    class="home-folder-layer"
    :class="{ 'home-folder-layer--dragging-out': draggingOutside }"
  >
    <button
      class="home-folder-backdrop"
      type="button"
      :aria-label="phone.t('Home.folders.close')"
      @click="emit('close')"
    ></button>
    <section
      class="home-folder-dialog"
      role="dialog"
      aria-modal="true"
      :aria-label="folderName"
      @pointerdown.stop
    >
      <div v-if="!renameOpened" class="home-folder-heading">
        <button
          class="home-folder-title"
          type="button"
          :aria-label="phone.t('Home.folders.rename')"
          @click="openRename"
        >
          {{ folderName }}
        </button>
        <SkyLink
          class="home-folder-edit"
          component="button"
          icon-only
          :aria-label="phone.t('Home.folders.rename')"
          type="button"
          @click="openRename"
        >
          <Pencil :size="18" :stroke-width="2.2" />
        </SkyLink>
      </div>
      <form
        v-else
        class="home-folder-heading home-folder-heading--editing"
        @keydown.esc.prevent="renameOpened = false"
        @submit.prevent="saveRename"
      >
        <SkyLink
          class="home-folder-rename-action"
          component="button"
          icon-only
          :aria-label="phone.t('Common.cancel')"
          type="button"
          @click="renameOpened = false"
        >
          <X :size="19" :stroke-width="2.3" />
        </SkyLink>
        <SkyField
          v-model="renameDraft"
          class="home-folder-rename-field"
          :aria-label="phone.t('Home.folders.name')"
          autocomplete="off"
          autofocus
          clear-button
          :clear-label="phone.t('Common.clear')"
          component="div"
          :maxlength="HOME_FOLDER_NAME_MAX_LENGTH"
          :placeholder="phone.t('Home.folders.defaultName')"
        />
        <SkyLink
          class="home-folder-rename-action"
          component="button"
          icon-only
          :aria-label="phone.t('Common.save')"
          type="submit"
        >
          <Check :size="20" :stroke-width="2.5" />
        </SkyLink>
      </form>
      <div
        ref="panelElement"
        class="home-folder-panel"
        :class="{ 'home-folder-panel--dragging': draggingIndex !== null }"
        @pointerdown="startPageSwipe"
        @pointerup="finishPageSwipe"
        @pointercancel="pagePointerId = null"
      >
        <div class="home-folder-page-viewport">
          <Transition :name="pageTransitionName">
            <div :key="currentPage" class="home-folder-page-grid">
              <AppIcon
                v-for="entry in visibleApps"
                :key="entry.app.id"
                :app="entry.app"
                :data-folder-app-index="entry.index"
                :edit-mode="editMode"
                @dragcancel="stopFolderAppDrag"
                @dragend="finishFolderAppDrag"
                @dragmove="moveFolderAppDrag"
                @dragstart="startFolderAppDrag(entry.index)"
                @edit="emit('edit')"
              />
            </div>
          </Transition>
        </div>
        <nav
          v-if="pageCount > 1"
          class="home-folder-pages"
          :aria-label="phone.t('Home.folders.pages')"
        >
          <button
            v-for="page in pageCount"
            :key="page"
            type="button"
            :class="{ active: currentPage === page - 1 }"
            :aria-label="`${phone.t('Home.page')} ${page}`"
            @click="goToPage(page - 1)"
          ></button>
        </nav>
      </div>
    </section>
  </div>
</template>

<style scoped>
.home-folder-layer {
  --sky-app-accent: #0a84ff;
  --sky-bg: #08080a;
  --sky-surface: #1c1c1e;
  --sky-surface-muted: #2c2c2e;
  --sky-text: #f5f5f7;
  --sky-muted: #98989f;
  --sky-hairline: rgb(255 255 255 / 12%);
  position: absolute;
  z-index: 70;
  inset: 0;
  color: #fff;
  font-family: var(--sky-font-family);
}

.home-folder-backdrop {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  padding: 0;
  border: 0;
  background: rgb(8 12 24 / 38%);
}

.home-folder-dialog {
  position: absolute;
  top: 118px;
  right: 30px;
  left: 30px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 14px;
}

.home-folder-heading {
  width: 100%;
  max-width: 100%;
  min-height: 44px;
  display: flex;
  align-items: center;
  justify-content: flex-start;
  gap: 5px;
}

.home-folder-title {
  min-width: 0;
  max-width: calc(100% - 49px);
  min-height: 44px;
  flex: 1 1 auto;
  margin: 0;
  padding: 2px 8px;
  overflow: hidden;
  border: 0;
  border-radius: 12px;
  color: #fff;
  background: transparent;
  font: inherit;
  font-size: 28px;
  font-weight: 650;
  letter-spacing: -0.8px;
  line-height: 36px;
  text-align: left;
  text-overflow: ellipsis;
  text-shadow: 0 2px 8px rgb(0 0 0 / 38%);
  white-space: nowrap;
}

.home-folder-title:focus-visible,
.home-folder-edit:focus-visible {
  outline: 2px solid #fff;
  outline-offset: 2px;
}

.home-folder-edit {
  width: 44px;
  height: 44px;
  flex: 0 0 44px;
  border: 0;
  border-radius: 50%;
  color: #fff;
  background: rgb(255 255 255 / 13%);
  box-shadow: inset 0 1px 0 rgb(255 255 255 / 12%);
  text-shadow: 0 2px 8px rgb(0 0 0 / 38%);
}

.home-folder-edit:active {
  background: rgb(255 255 255 / 22%);
  transform: scale(0.94);
}

.home-folder-panel {
  box-sizing: border-box;
  width: 100%;
  min-height: 324px;
  padding: 22px 16px 14px;
  overflow: hidden;
  border: 1px solid rgb(255 255 255 / 25%);
  border-radius: 26px;
  background: rgb(115 135 176 / 72%);
  box-shadow:
    inset 0 1px 0 rgb(255 255 255 / 18%),
    0 18px 50px rgb(0 0 0 / 26%);
  touch-action: none;
}

.home-folder-panel--dragging {
  overflow: visible;
}

.home-folder-page-viewport {
  position: relative;
  min-height: 270px;
  margin-top: -6px;
  overflow: hidden;
}

.home-folder-panel--dragging .home-folder-page-viewport {
  overflow: visible;
}

.home-folder-page-grid {
  position: absolute;
  inset: 0;
  top: 6px;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  grid-template-rows: repeat(3, 79px);
  gap: 10px 14px;
  align-items: start;
}

.home-folder-page-forward-enter-active,
.home-folder-page-forward-leave-active,
.home-folder-page-backward-enter-active,
.home-folder-page-backward-leave-active {
  pointer-events: none;
  transition:
    opacity 190ms ease,
    transform 290ms cubic-bezier(0.22, 1, 0.36, 1);
  will-change: opacity, transform;
}

.home-folder-page-forward-enter-from {
  opacity: 0;
  transform: translateX(48px) scale(0.985);
}

.home-folder-page-forward-leave-to {
  opacity: 0;
  transform: translateX(-48px) scale(0.985);
}

.home-folder-page-backward-enter-from {
  opacity: 0;
  transform: translateX(-48px) scale(0.985);
}

.home-folder-page-backward-leave-to {
  opacity: 0;
  transform: translateX(48px) scale(0.985);
}

.home-folder-page-grid :deep(.app-icon-item) {
  width: 100%;
}

.home-folder-page-grid :deep(.app-icon-item--dragging) {
  z-index: 80;
}

.home-folder-backdrop,
.home-folder-heading,
.home-folder-panel,
.home-folder-page-grid :deep(.app-icon-item),
.home-folder-pages {
  transition:
    opacity 160ms ease,
    background-color 160ms ease,
    border-color 160ms ease,
    box-shadow 160ms ease;
}

.home-folder-layer--dragging-out .home-folder-backdrop {
  background: transparent;
}

.home-folder-layer--dragging-out .home-folder-heading,
.home-folder-layer--dragging-out .home-folder-pages,
.home-folder-layer--dragging-out
  .home-folder-page-grid
  :deep(.app-icon-item:not(.app-icon-item--dragging)) {
  opacity: 0;
}

.home-folder-layer--dragging-out .home-folder-panel {
  border-color: transparent;
  background: transparent;
  box-shadow: none;
}

.home-folder-pages {
  min-height: 20px;
  margin-top: 5px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
}

.home-folder-pages button {
  width: 8px;
  height: 8px;
  padding: 0;
  border: 0;
  border-radius: 50%;
  background: rgb(255 255 255 / 38%);
  transition:
    background-color 180ms ease,
    transform 220ms cubic-bezier(0.22, 1, 0.36, 1);
}

.home-folder-pages button.active {
  background: #fff;
  transform: scale(1.18);
}

.home-folder-heading--editing {
  min-height: 52px;
  gap: 8px;
}

.home-folder-rename-field {
  min-width: 0;
  flex: 1 1 auto;
  overflow: hidden;
  padding: 0;
  border: 1px solid rgb(255 255 255 / 26%);
  border-radius: 14px;
  background: rgb(28 28 30 / 78%);
  box-shadow: inset 0 1px 0 rgb(255 255 255 / 12%);
}

.home-folder-rename-field :deep(.sky-field__inner) {
  padding: 2px 12px;
}

.home-folder-rename-field :deep(.sky-field__input) {
  height: 46px;
  min-height: 46px;
  color: #fff;
  font-size: 18px;
  font-weight: 600;
  text-align: center;
}

.home-folder-rename-field :deep(.sky-field__input::placeholder) {
  color: rgb(255 255 255 / 48%);
}

.home-folder-rename-field :deep(.sky-field__clear) {
  color: #fff;
}

.home-folder-rename-action {
  width: 44px;
  height: 44px;
  flex: 0 0 44px;
  border: 0;
  border-radius: 50%;
  color: #fff;
  background: rgb(255 255 255 / 13%);
  box-shadow: inset 0 1px 0 rgb(255 255 255 / 12%);
}

.home-folder-rename-action:active {
  background: rgb(255 255 255 / 22%);
  transform: scale(0.94);
}

@media (prefers-reduced-motion: reduce) {
  .home-folder-layer *,
  .home-folder-layer *::before,
  .home-folder-layer *::after {
    transition-duration: 0.01ms !important;
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
  }
}
</style>
