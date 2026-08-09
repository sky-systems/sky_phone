<script setup lang="ts">
import {
  CalendarDays,
  Check,
  Clock3,
  CloudSun,
  Music,
  ReceiptText,
  Users,
  WalletCards,
} from 'lucide-vue-next'
import {
  kButton,
  kLink,
  kList,
  kListItem,
  kNavbar,
  kPage,
  kSearchbar,
  kSegmented,
  kSegmentedButton,
  kSheet,
} from 'konsta/vue'
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

const props = defineProps<{ opened: boolean }>()
const emit = defineEmits<{
  add: [kind: WidgetKind, size: WidgetSize]
  close: []
}>()
const phone = usePhoneStore()
const query = ref('')
const selectedKind = ref<WidgetKind>('clock')
const selectedSize = ref<WidgetSize>('small')

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
const sheetColors = {
  bgIos: 'bg-[#f2f2f7] dark:bg-black',
}

function inputValue(event: Event): string {
  return (event.target as HTMLInputElement).value
}

function selectWidget(definition: WidgetDefinition): void {
  selectedKind.value = definition.kind
  if (!definition.supportedSizes.includes(selectedSize.value))
    selectedSize.value = definition.defaultSize
}

function addWidget(): void {
  emit('add', selectedKind.value, selectedSize.value)
}

watch(
  () => props.opened,
  (opened) => {
    if (!opened) query.value = ''
  },
)
</script>

<template>
  <k-sheet
    :opened="opened"
    class="widget-picker-sheet"
    :colors="sheetColors"
    @backdropclick="emit('close')"
  >
    <k-page
      class="widget-picker-page"
      :class="{ 'widget-picker-page--dark': phone.isDarkMode }"
    >
      <k-navbar :title="phone.t('Home.widgetSystem.galleryTitle')">
        <template #right>
          <k-link component="button" type="button" @click="emit('close')">
            {{ phone.t('Common.done') }}
          </k-link>
        </template>
      </k-navbar>

      <div class="widget-picker-scroll">
        <k-searchbar
          :value="query"
          :placeholder="phone.t('Home.widgetSystem.search')"
          @input="query = inputValue($event)"
          @clear="query = ''"
        />

        <section class="widget-picker-preview">
          <SpringboardWidget
            :instance="previewInstance"
            preview
            :interactive="false"
          />
          <h2>{{ phone.t(selectedDefinition.labelKey) }}</h2>
          <p>{{ phone.t(selectedDefinition.descriptionKey) }}</p>
        </section>

        <section class="widget-picker-size">
          <span>{{ phone.t('Home.widgetSystem.size') }}</span>
          <k-segmented raised>
            <k-segmented-button
              v-for="size in selectedDefinition.supportedSizes"
              :key="size"
              :active="selectedSize === size"
              @click="selectedSize = size"
            >
              {{ phone.t(`Home.widgetSystem.sizes.${size}`) }}
            </k-segmented-button>
          </k-segmented>
        </section>

        <k-button large rounded class="widget-picker-add" @click="addWidget">
          {{ phone.t('Home.widgetSystem.addWidget') }}
        </k-button>

        <section
          v-for="category in categories"
          :key="category.key"
          class="widget-picker-category"
        >
          <h3>{{ phone.t(category.key) }}</h3>
          <k-list inset strong>
            <k-list-item
              v-for="definition in category.widgets"
              :key="definition.kind"
              link
              link-component="button"
              content-class="w-full"
              :chevron="false"
              :title="phone.t(definition.labelKey)"
              :subtitle="phone.t(definition.descriptionKey)"
              @click="selectWidget(definition)"
            >
              <template #media>
                <span class="widget-picker-icon">
                  <component :is="icons[definition.kind]" :size="21" />
                </span>
              </template>
              <template v-if="selectedKind === definition.kind" #after>
                <Check :size="20" class="widget-picker-check" />
              </template>
            </k-list-item>
          </k-list>
        </section>

        <p v-if="filteredWidgets.length === 0" class="widget-picker-empty">
          {{ phone.t('Home.widgetSystem.noResults') }}
        </p>
      </div>
    </k-page>
  </k-sheet>
</template>

<style scoped>
:global(.widget-picker-sheet) {
  z-index: 110;
  height: calc(100% - 22px);
  overflow: hidden;
  border-radius: 28px 28px 0 0;
}

.widget-picker-page {
  height: 100%;
  color: #111;
  background: #f2f2f7;
}

.widget-picker-page--dark {
  color: #fff;
  background: #000;
}

.widget-picker-scroll {
  height: calc(100% - 54px);
  padding: 8px 13px 42px;
  overflow-y: auto;
  scrollbar-width: none;
}

.widget-picker-scroll::-webkit-scrollbar {
  display: none;
}

.widget-picker-preview {
  display: flex;
  min-height: 235px;
  padding: 22px 14px 14px;
  align-items: center;
  flex-direction: column;
  justify-content: center;
}

.widget-picker-preview :deep(.home-widget-shell) {
  max-height: 188px;
}

.widget-picker-preview h2 {
  margin: 14px 0 3px;
  font-size: 20px;
  letter-spacing: -0.4px;
}

.widget-picker-preview p {
  max-width: 285px;
  margin: 0;
  color: #6e6e73;
  font-size: 13px;
  line-height: 1.35;
  text-align: center;
}

.widget-picker-page--dark .widget-picker-preview p {
  color: #98989d;
}

.widget-picker-size {
  display: grid;
  margin: 0 4px 14px;
  grid-template-columns: auto 1fr;
  align-items: center;
  gap: 12px;
}

.widget-picker-size > span {
  font-size: 13px;
  font-weight: 600;
}

.widget-picker-add {
  margin-bottom: 22px;
}

.widget-picker-category h3 {
  margin: 18px 12px 7px;
  color: #6e6e73;
  font-size: 13px;
  font-weight: 500;
}

.widget-picker-category :deep([class*='title']) {
  color: inherit;
}

.widget-picker-icon {
  display: grid;
  width: 38px;
  height: 38px;
  place-items: center;
  border-radius: 10px;
  color: #fff;
  background: #2c2c2e;
}

.widget-picker-check {
  color: #0a84ff;
}

.widget-picker-empty {
  padding: 40px 20px;
  color: #8e8e93;
  text-align: center;
}
</style>
