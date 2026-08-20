<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'

import CustomAppFrame from '@/components/CustomAppFrame.vue'
import { getPhoneApp, isExternalPhoneApp } from '@/config/apps'
import { usePhoneStore } from '@/stores/phone'
import { getCustomAppFrameKey } from '@/utils/customAppLifecycle'
import AppStoreApp from '@/views/apps/AppStoreApp.vue'

const route = useRoute()
const phone = usePhoneStore()
const app = computed(() => getPhoneApp(route.params.appId))
const builtinAppComponent = computed(() =>
  app.value?.id === 'app-store' ? AppStoreApp : app.value?.component,
)
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
  <div
    v-if="app && !app.adminOnly"
    class="app-window"
    :class="{ 'app-window--citywarn': app.id === 'citywarn' }"
    :style="launchStyle"
  >
    <CustomAppFrame
      v-if="isExternalPhoneApp(app)"
      :key="getCustomAppFrameKey(app)"
      :app="app"
    />
    <Suspense v-else>
      <component :is="builtinAppComponent" />
      <template #fallback>
        <div class="app-loading">{{ phone.t('Common.loading') }}</div>
      </template>
    </Suspense>
  </div>
</template>
