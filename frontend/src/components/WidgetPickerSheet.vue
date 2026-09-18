<script setup lang="ts">
import {
  CalendarDays,
  ChevronLeft,
  Clock3,
  CloudSun,
  Music,
  ReceiptText,
  Users,
  WalletCards,
} from 'lucide-vue-next'
import { computed, ref, watch, type Component } from 'vue'

import SpringboardWidget from '@/components/SpringboardWidget.vue'
import { WIDGET_REGISTRY } from '@/config/widgets'
import { usePhoneStore } from '@/stores/phone'
import type {
  WidgetDefinition,
  WidgetInstance,
  WidgetKind,
  WidgetSize,
} from '@/types/widgets'
import {
  SkyButton,
  SkyEmptyState,
  SkyList,
  SkyListItem,
  SkyProvider,
  SkyScrollArea,
  SkySearchbar,
  SkySheet,
} from '@/ui'

const props = defineProps<{ opened: boolean }>()
const emit = defineEmits<{
  add: [kind: WidgetKind, size: WidgetSize]
  close: []
}>()
const phone = usePhoneStore()
const query = ref('')
const pickerView = ref<'gallery' | 'preview'>('gallery')
const selectedKind = ref<WidgetKind>('clock')
const selectedSize = ref<WidgetSize>('small')
let previewPointerStartX: number | null = null

const icons: Record<WidgetKind, Component> = {
  clock: Clock3,
  date: CalendarDays,
  weather: CloudSun,
  music: Music,
  wallet: WalletCards,
  transactions: ReceiptText,
  contacts: Users,
}
const filteredWidgets = computed(() => {
  const search = query.value.trim().toLocaleLowerCase(phone.lang)
  if (!search) return WIDGET_REGISTRY
  return WIDGET_REGISTRY.filter((definition) =>
    `${phone.t(definition.labelKey)} ${phone.t(definition.descriptionKey)}`
      .toLocaleLowerCase(phone.lang)
      .includes(search),
  )
})
const categories = computed(() => {
  const groups = new Map<string, WidgetDefinition[]>()
  for (const definition of filteredWidgets.value) {
    const group = groups.get(definition.categoryKey) ?? []
    group.push(definition)
    groups.set(definition.categoryKey, group)
  }
  return [...groups.entries()].map(([key, widgets]) => ({ key, widgets }))
})
const selectedDefinition = computed(
  () =>
    WIDGET_REGISTRY.find(
      (definition) => definition.kind === selectedKind.value,
    ) ?? WIDGET_REGISTRY[0],
)
const previewInstance = computed<WidgetInstance>(() => ({
  column: 0,
  id: 'widget-preview',
  kind: selectedDefinition.value.kind,
  page: 0,
  row: 0,
  settings: {
    ...(selectedDefinition.value.kind === 'clock' ? { showDate: true } : {}),
    ...(selectedDefinition.value.kind === 'wallet'
      ? { balanceSource: 'bank' as const }
      : {}),
  },
  size: selectedSize.value,
}))
const selectedSizeIndex = computed(() =>
  selectedDefinition.value.supportedSizes.indexOf(selectedSize.value),
)

function selectWidget(definition: WidgetDefinition): void {
  selectedKind.value = definition.kind
  selectedSize.value = definition.defaultSize
  pickerView.value = 'preview'
}

function addWidget(): void {
  emit('add', selectedKind.value, selectedSize.value)
}

function closePicker(): void {
  emit('close')
}

function showGallery(): void {
  pickerView.value = 'gallery'
}

function changeSize(offset: number): void {
  const sizes = selectedDefinition.value.supportedSizes
  const currentIndex = Math.max(0, sizes.indexOf(selectedSize.value))
  const nextIndex = Math.max(
    0,
    Math.min(sizes.length - 1, currentIndex + offset),
  )
  selectedSize.value = sizes[nextIndex] ?? selectedSize.value
}

function startPreviewSwipe(event: PointerEvent): void {
  if (
    !event.isPrimary ||
    (event.pointerType === 'mouse' && event.button !== 0)
  ) {
    return
  }

  previewPointerStartX = event.clientX
  const target = event.currentTarget as HTMLElement
  target.setPointerCapture(event.pointerId)
}

function finishPreviewSwipe(event: PointerEvent): void {
  if (previewPointerStartX === null) return

  const deltaX = event.clientX - previewPointerStartX
  previewPointerStartX = null
  const target = event.currentTarget as HTMLElement
  if (target.hasPointerCapture(event.pointerId)) {
    target.releasePointerCapture(event.pointerId)
  }
  if (Math.abs(deltaX) < 36) return
  changeSize(deltaX < 0 ? 1 : -1)
}

function cancelPreviewSwipe(): void {
  previewPointerStartX = null
}

watch(
  () => props.opened,
  (opened) => {
    if (opened) return
    query.value = ''
    pickerView.value = 'gallery'
    previewPointerStartX = null
  },
)
</script>

<template>
  <SkyProvider
    class="widget-picker-provider"
    :dark="phone.isDarkMode"
    safe-areas
  >
    <SkySheet
      class="widget-picker-sheet"
      :opened="opened"
      :aria-label="phone.t('Home.widgetSystem.galleryTitle')"
      grabber-clickable
      :grabber-label="phone.t('Common.close')"
      swipe-to-close
      @backdropclick="closePicker"
      @escape="closePicker"
      @grabberclick="closePicker"
      @swipeclose="closePicker"
    >
      <section class="widget-picker-surface">
        <header class="widget-picker-navbar">
          <SkyButton
            v-if="pickerView === 'preview'"
            class="widget-picker-nav-button widget-picker-nav-button--icon"
            icon-only
            inline
            rounded
            type="button"
            variant="secondary"
            :aria-label="phone.t('Common.back')"
            @click="showGallery"
          >
            <ChevronLeft :size="21" :stroke-width="2.4" />
          </SkyButton>
          <span v-else aria-hidden="true"></span>

          <h2>
            {{
              pickerView === 'gallery'
                ? phone.t('Home.widgetSystem.galleryTitle')
                : phone.t(selectedDefinition.labelKey)
            }}
          </h2>

          <SkyButton
            class="widget-picker-nav-button widget-picker-done"
            inline
            rounded
            type="button"
            variant="secondary"
            @click="closePicker"
          >
            {{ phone.t('Common.done') }}
          </SkyButton>
        </header>

        <SkyScrollArea class="widget-picker-scroll">
          <template v-if="pickerView === 'gallery'">
            <SkySearchbar
              v-model="query"
              class="widget-picker-search"
              :clear-label="phone.t('Common.clear')"
              :label="phone.t('Home.widgetSystem.search')"
              :placeholder="phone.t('Home.widgetSystem.search')"
            />

            <section
              v-for="category in categories"
              :key="category.key"
              class="widget-picker-category"
            >
              <h3>{{ phone.t(category.key) }}</h3>
              <SkyList flush strong class="widget-picker-list">
                <SkyListItem
                  v-for="definition in category.widgets"
                  :key="definition.kind"
                  chevron
                  link
                  link-component="button"
                  :text="phone.t(definition.descriptionKey)"
                  :title="phone.t(definition.labelKey)"
                  @click="selectWidget(definition)"
                >
                  <template #media>
                    <span
                      class="widget-picker-icon"
                      :class="`widget-picker-icon--${definition.kind}`"
                    >
                      <component :is="icons[definition.kind]" :size="21" />
                    </span>
                  </template>
                </SkyListItem>
              </SkyList>
            </section>

            <SkyEmptyState
              v-if="filteredWidgets.length === 0"
              compact
              class="widget-picker-empty"
              :title="phone.t('Home.widgetSystem.noResults')"
            />
          </template>

          <section v-else class="widget-picker-preview">
            <div
              class="widget-picker-preview-stage"
              role="group"
              tabindex="0"
              :aria-label="`${phone.t('Home.widgetSystem.size')}: ${phone.t(`Home.widgetSystem.sizes.${selectedSize}`)}`"
              @keydown.left.prevent="changeSize(-1)"
              @keydown.right.prevent="changeSize(1)"
              @lostpointercapture="cancelPreviewSwipe"
              @pointercancel="cancelPreviewSwipe"
              @pointerdown="startPreviewSwipe"
              @pointerup="finishPreviewSwipe"
            >
              <SpringboardWidget
                :instance="previewInstance"
                preview
                :interactive="false"
              />
            </div>

            <div class="widget-picker-size-copy" aria-live="polite">
              <strong>{{
                phone.t(`Home.widgetSystem.sizes.${selectedSize}`)
              }}</strong>
              <span>{{ phone.t('Home.widgetSystem.size') }}</span>
            </div>

            <div
              class="widget-picker-size-dots"
              :aria-label="phone.t('Home.widgetSystem.size')"
              role="group"
            >
              <button
                v-for="(size, index) in selectedDefinition.supportedSizes"
                :key="size"
                type="button"
                :class="{
                  'widget-picker-size-dot--active': index === selectedSizeIndex,
                }"
                :aria-label="phone.t(`Home.widgetSystem.sizes.${size}`)"
                :aria-pressed="index === selectedSizeIndex"
                @click="selectedSize = size"
              ></button>
            </div>

            <h3>{{ phone.t(selectedDefinition.labelKey) }}</h3>
            <p>{{ phone.t(selectedDefinition.descriptionKey) }}</p>

            <SkyButton
              block
              large
              rounded
              class="widget-picker-add"
              @click="addWidget"
            >
              {{ phone.t('Home.widgetSystem.addWidget') }}
            </SkyButton>
          </section>
        </SkyScrollArea>
      </section>
    </SkySheet>
  </SkyProvider>
</template>

<style scoped>
.widget-picker-provider {
  position: absolute;
  z-index: 110;
  inset: 0;
  pointer-events: none;
}

.widget-picker-sheet {
  --sky-overlay-layer: 110;
}

.widget-picker-sheet :deep(.sky-overlay-backdrop) {
  background: rgb(0 0 0 / 58%);
}

.widget-picker-sheet :deep(.sky-sheet__panel) {
  height: calc(100% - var(--sky-space-3));
  max-height: calc(100% - var(--sky-space-3));
  overflow: hidden;
  background: var(--sky-bg);
}

.widget-picker-surface {
  height: calc(100% - 32px);
  min-height: 0;
  display: flex;
  flex-direction: column;
  background: var(--sky-bg);
  color: var(--sky-text);
}

.widget-picker-navbar {
  min-height: 56px;
  display: grid;
  grid-template-columns: minmax(72px, 1fr) minmax(0, 2fr) minmax(72px, 1fr);
  align-items: center;
  gap: var(--sky-space-2);
  padding: 0 var(--sky-space-3);
  border-bottom: 1px solid var(--sky-hairline);
}

.widget-picker-navbar h2 {
  overflow: hidden;
  margin: 0;
  color: var(--sky-text);
  font-size: var(--sky-font-title);
  font-weight: 650;
  text-align: center;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.widget-picker-navbar > :first-child {
  justify-self: start;
}

.widget-picker-navbar > :last-child {
  justify-self: end;
}

.widget-picker-navbar :deep(.widget-picker-nav-button.sky-button) {
  min-height: var(--sky-touch-target);
  padding: 0 var(--sky-space-4);
  border: 1px solid var(--sky-action-border);
  background: var(--sky-action-surface);
  color: #fff;
  font-size: 15px;
  font-weight: 600;
}

.widget-picker-navbar :deep(.widget-picker-nav-button.sky-button:active) {
  background: var(--sky-action-pressed);
}

.widget-picker-navbar :deep(.widget-picker-nav-button--icon.sky-button) {
  width: var(--sky-touch-target);
  min-width: var(--sky-touch-target);
  padding: 0;
}

.widget-picker-scroll {
  min-height: 0;
  flex: 1;
  overflow-y: auto;
  padding: var(--sky-space-3) var(--sky-page-gutter)
    calc(var(--sky-space-6) + var(--sky-safe-area-bottom));
}

.widget-picker-search {
  margin-bottom: var(--sky-space-5);
}

.widget-picker-preview {
  display: flex;
  min-height: 100%;
  padding: var(--sky-space-4) 0 0;
  align-items: center;
  flex-direction: column;
  text-align: center;
}

.widget-picker-preview-stage {
  width: 100%;
  min-height: 310px;
  display: flex;
  align-items: center;
  justify-content: center;
  outline: 0;
  touch-action: pan-y;
  user-select: none;
}

.widget-picker-preview-stage:focus-visible {
  border-radius: var(--sky-radius-card);
  box-shadow: inset 0 0 0 2px var(--sky-app-accent);
}

.widget-picker-size-copy {
  display: flex;
  align-items: baseline;
  justify-content: center;
  gap: var(--sky-space-2);
  color: var(--sky-muted);
  font-size: var(--sky-font-caption);
}

.widget-picker-size-copy strong {
  color: var(--sky-text);
  font-size: 14px;
  font-weight: 600;
}

.widget-picker-size-dots {
  min-height: var(--sky-touch-target);
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--sky-space-2);
}

.widget-picker-size-dots button {
  position: relative;
  width: 8px;
  height: 8px;
  padding: 0;
  border: 0;
  border-radius: 50%;
  background: var(--sky-subtle);
  transition: background-color var(--sky-transition-fast) ease;
}

.widget-picker-size-dots button::before {
  position: absolute;
  inset: -18px -8px;
  content: '';
}

.widget-picker-size-dots .widget-picker-size-dot--active {
  background: var(--sky-text);
}

.widget-picker-preview h3 {
  margin: 0;
  color: var(--sky-text);
  font-size: 21px;
  font-weight: 650;
  letter-spacing: -0.35px;
}

.widget-picker-preview p {
  max-width: 290px;
  margin: var(--sky-space-1) 0 var(--sky-space-5);
  color: var(--sky-muted);
  font-size: 14px;
  line-height: 19px;
}

.widget-picker-add {
  margin-top: auto;
}

.widget-picker-category h3 {
  margin: var(--sky-space-5) var(--sky-space-3) var(--sky-space-2);
  color: var(--sky-muted);
  font-size: var(--sky-font-caption);
  font-weight: 600;
  text-transform: uppercase;
}

.widget-picker-category:first-of-type h3 {
  margin-top: 0;
}

.widget-picker-list {
  overflow: hidden;
  margin: 0;
  border-radius: var(--sky-radius-card);
}

.widget-picker-list :deep(.sky-list-item__content) {
  min-height: 58px;
}

.widget-picker-list :deep(.sky-list-item__text) {
  color: var(--sky-muted);
}

.widget-picker-icon {
  display: grid;
  width: 38px;
  height: 38px;
  place-items: center;
  border-radius: 11px;
  color: #fff;
  background: #2c2c2e;
}

.widget-picker-icon--date {
  background: #ff453a;
}

.widget-picker-icon--weather {
  background: #0a84ff;
}

.widget-picker-icon--music {
  background: #ff375f;
}

.widget-picker-icon--wallet {
  background: #5856d6;
}

.widget-picker-icon--transactions {
  background: #30b35a;
}

.widget-picker-icon--contacts {
  background: #ff9f0a;
}

.widget-picker-empty {
  min-height: 220px;
}

@media (max-height: 700px) {
  .widget-picker-preview-stage {
    min-height: 260px;
  }
}

@media (prefers-reduced-motion: reduce) {
  .widget-picker-size-dots button {
    transition: none;
  }
}
</style>
