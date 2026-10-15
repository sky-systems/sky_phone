<script setup lang="ts">
import SkyGlass from './SkyGlass.vue'

defineOptions({ inheritAttrs: false })

withDefaults(
  defineProps<{
    component?: 'div' | 'nav'
  }>(),
  {
    component: 'div',
  },
)
</script>

<template>
  <SkyGlass
    :component="component"
    material="clear"
    v-bind="$attrs"
    class="sky-toolbar-pane"
  >
    <slot />
  </SkyGlass>
</template>
