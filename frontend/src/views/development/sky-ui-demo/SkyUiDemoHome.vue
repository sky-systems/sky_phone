<script setup lang="ts">
import { SkyIcon } from '@/ui'

import { Palette } from 'lucide-vue-next'
import { onBeforeUnmount, onMounted, ref } from 'vue'

import {
  SkyAppPage,
  SkyBlockTitle,
  SkyList,
  SkyListItem,
  SkyNavbar,
  SkyPopover,
  SkyRadio,
  SkyScrollArea,
  SkyToggle,
} from '@/ui'

import demoIcon from './assets/demo-icon.png'
import { SKY_UI_DEMO_CATALOG, SKY_UI_EXTENSION_CATALOG } from './catalog'
import { useSkyUiDemoContext, type SkyUiDemoAccent } from './context'

const demo = useSkyUiDemoContext()
const colorPickerOpened = ref(false)
const colorPickerTarget = ref<HTMLElement | null>(null)

const accents: SkyUiDemoAccent[] = [
  { color: '#007aff', name: 'Blue', soft: 'rgba(0, 122, 255, 0.16)' },
  { color: '#ff3b30', name: 'Red', soft: 'rgba(255, 59, 48, 0.16)' },
  { color: '#4cd964', name: 'Green', soft: 'rgba(76, 217, 100, 0.16)' },
  { color: '#ffcc00', name: 'Yellow', soft: 'rgba(255, 204, 0, 0.18)' },
  { color: '#9c27b0', name: 'Purple', soft: 'rgba(156, 39, 176, 0.16)' },
]

function chooseAccent(accent: SkyUiDemoAccent): void {
  demo.accentChoice.value = accent
  colorPickerOpened.value = false
}

function syncColorPickerTarget(): void {
  colorPickerTarget.value = document.querySelector<HTMLElement>(
    '#sky-ui-demo-color-anchor',
  )
}

function handleDarkModeRowClick(event: MouseEvent): void {
  const target = event.target
  if (target instanceof Element && target.closest('.sky-toggle')) return
  demo.dark.value = !demo.dark.value
}

onMounted(() => {
  syncColorPickerTarget()
})

onBeforeUnmount(() => {
  colorPickerTarget.value = null
})
</script>

<template>
  <SkyAppPage
    class="sky-ui-demo-home"
    :accent="demo.accent.value"
    :accent-soft="demo.accentSoft.value"
    :dark="demo.dark.value"
    label="Sky UI Kitchen Sink"
  >
    <SkyNavbar
      back-label="Back to Settings"
      show-back
      title="Sky UI"
      transparent
      variant="large"
      @back="demo.exit"
    />

    <SkyScrollArea class="sky-ui-demo-home__scroll">
      <SkyBlockTitle>Theme</SkyBlockTitle>
      <SkyList inset strong>
        <SkyListItem label title="iOS Theme">
          <template #media>
            <SkyRadio aria-label="iOS Theme" checked value="ios" />
          </template>
        </SkyListItem>
        <SkyListItem
          disabled
          label
          subtitle="Sky UI currently follows the Konsta iOS reference."
          title="Material Theme"
        >
          <template #media>
            <SkyRadio
              aria-label="Material Theme (not available)"
              disabled
              value="material"
            />
          </template>
        </SkyListItem>
      </SkyList>

      <SkyList inset strong>
        <SkyListItem
          class="sky-ui-demo-home__control-row"
          title="Dark Mode"
          @click="handleDarkModeRowClick"
        >
          <template #after>
            <SkyToggle
              v-model="demo.dark.value"
              aria-label="Dark Mode"
              component="div"
            />
          </template>
        </SkyListItem>
        <SkyListItem
          id="sky-ui-demo-color-anchor"
          link
          title="Color Theme"
          @click="colorPickerOpened = true"
        >
          <template #after>
            <span
              class="sky-ui-demo-home__current-color"
              :style="{ backgroundColor: demo.accent.value }"
              :title="demo.accentChoice.value.name"
            />
          </template>
        </SkyListItem>
      </SkyList>

      <SkyBlockTitle>Components</SkyBlockTitle>
      <SkyList inset strong>
        <SkyListItem
          v-for="entry in SKY_UI_DEMO_CATALOG"
          :key="entry.id"
          link
          :title="entry.title"
          @click="demo.navigate(entry.id)"
        >
          <template #media>
            <img
              class="sky-ui-demo-home__component-icon"
              :src="demoIcon"
              alt=""
            />
          </template>
        </SkyListItem>
      </SkyList>

      <SkyBlockTitle>Sky Extensions</SkyBlockTitle>
      <SkyList inset strong>
        <SkyListItem
          v-for="entry in SKY_UI_EXTENSION_CATALOG"
          :key="entry.id"
          link
          :title="entry.title"
          @click="demo.navigate(entry.id)"
        >
          <template #media>
            <SkyIcon
              :icon="Palette"
              :size="28"
              :stroke-width="1.8"
              aria-hidden="true"
            />
          </template>
        </SkyListItem>
      </SkyList>
    </SkyScrollArea>

    <SkyPopover
      aria-label="Choose color theme"
      :opened="colorPickerOpened"
      :target="colorPickerTarget"
      @backdropclick="colorPickerOpened = false"
      @escape="colorPickerOpened = false"
    >
      <div class="sky-ui-demo-home__palette">
        <button
          v-for="accent in accents"
          :key="accent.name"
          class="sky-ui-demo-home__color-button"
          type="button"
          :aria-label="`${accent.name} color theme`"
          :aria-pressed="accent.color === demo.accent.value"
          @click="chooseAccent(accent)"
        >
          <span
            class="sky-ui-demo-home__color-swatch"
            :style="{ backgroundColor: accent.color }"
            aria-hidden="true"
          />
        </button>
      </div>
    </SkyPopover>
  </SkyAppPage>
</template>

<style scoped>
.sky-ui-demo-home__scroll {
  padding-top: 0;
}

.sky-ui-demo-home__current-color {
  width: 24px;
  height: 24px;
  display: block;
  border: 1px solid rgb(255 255 255 / 20%);
  border-radius: 50%;
}

.sky-ui-demo-home__component-icon {
  width: 28px;
  height: 28px;
  display: block;
}

.sky-ui-demo-home__control-row :deep(.sky-list-item__row) {
  cursor: pointer;
}

.sky-ui-demo-home__palette {
  display: grid;
  grid-template-columns: repeat(3, 48px);
  padding: 8px;
}

.sky-ui-demo-home__color-button {
  width: 48px;
  height: 48px;
  display: grid;
  place-items: center;
  border: 0;
  border-radius: 12px;
  background: transparent;
}

.sky-ui-demo-home__color-button:focus-visible {
  outline: 2px solid var(--sky-app-accent);
  outline-offset: -2px;
}

.sky-ui-demo-home__color-swatch {
  width: 24px;
  height: 24px;
  display: block;
  border-radius: 50%;
}

.sky-ui-demo-home__color-button[aria-pressed='true'] {
  background: var(--sky-pressed);
}
</style>
