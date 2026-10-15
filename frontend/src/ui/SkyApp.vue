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
    glassEffects?: boolean
    safeAreas?: boolean
  }>(),
  {
    accent: '',
    accentSoft: '',
    component: 'div',
    dark: false,
    safeAreas: true,
  },
)

provideSkyTheme({
  accent: () => props.accent,
  accentSoft: () => props.accentSoft,
  dark: () => props.dark,
  glassEffects: () => props.glassEffects,
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
    class="sky-app"
    :class="{
      dark: dark,
      'sky-app--dark': dark,
      'sky-app--no-safe-areas': !safeAreas,
      'sky-safe-areas': safeAreas,
    }"
    :style="themeStyle"
  >
    <slot />
  </component>
</template>
