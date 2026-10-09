<script setup lang="ts">
import { computed, type CSSProperties } from 'vue'

import { provideSkyTheme } from './theme'

defineOptions({ inheritAttrs: false })

const props = withDefaults(
  defineProps<{
    accent?: string
    accentSoft?: string
    component?: string
    dark?: boolean
    density?: 'compact' | 'regular'
    safeAreas?: boolean
  }>(),
  {
    accent: '',
    accentSoft: '',
    component: 'div',
    dark: false,
    density: 'regular',
    safeAreas: true,
  },
)

provideSkyTheme({
  accent: () => props.accent,
  accentSoft: () => props.accentSoft,
  dark: () => props.dark,
  safeAreas: () => props.safeAreas,
})

const themeStyle = computed<CSSProperties | undefined>(() => {
  if (!props.accent && !props.accentSoft) return undefined

  return {
    ...(props.accent ? { '--sky-app-accent': props.accent } : {}),
    ...(props.accentSoft ? { '--sky-app-accent-soft': props.accentSoft } : {}),
  }
})
</script>

<template>
  <component
    :is="component"
    v-bind="$attrs"
    class="sky-ui-provider"
    :class="{
      'sky-ui-provider--dark': dark,
      'sky-ui-provider--compact': density === 'compact',
      'sky-ui-provider--no-safe-areas': !safeAreas,
      'sky-safe-areas': safeAreas,
    }"
    :style="themeStyle"
  >
    <slot />
  </component>
</template>
