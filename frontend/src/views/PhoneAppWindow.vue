<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'

import { getPhoneApp } from '@/config/apps'
import { usePhoneStore } from '@/stores/phone'

const route = useRoute()
const phone = usePhoneStore()
const app = computed(() => getPhoneApp(route.params.appId))
const launchStyle = computed(() => {
  const origin = phone.launchOrigin
  return {
    '--launch-radius': `${origin?.borderRadius ?? 72}px`,
    '--launch-scale-x': origin?.scaleX ?? 0.82,
    '--launch-scale-y': origin?.scaleY ?? 0.82,
    '--launch-x': `${origin?.x ?? 35}px`,
    '--launch-y': `${origin?.y ?? 70}px`,
  }
})
</script>

<template>
  <div v-if="app?.component" class="app-window" :style="launchStyle">
    <Suspense>
      <component :is="app.component" />
      <template #fallback>
        <div class="app-loading">{{ phone.t('Common.loading') }}</div>
      </template>
    </Suspense>
  </div>
</template>
