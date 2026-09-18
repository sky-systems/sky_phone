<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRoute } from 'vue-router'

import EasyShareContentPreview from '@/components/EasyShareContentPreview.vue'
import CustomAppFrame from '@/components/CustomAppFrame.vue'
import { getPhoneApp, isExternalPhoneApp } from '@/config/apps'
import { usePhoneStore } from '@/stores/phone'
import { getCustomAppFrameKey } from '@/utils/customAppLifecycle'
import AppStoreApp from '@/views/apps/AppStoreApp.vue'

const route = useRoute()
const phone = usePhoneStore()
const shareLaunch = ref('')
watch(
  () => route.query.easyShareLaunch,
  (value) => {
    if (typeof value === 'string' && value) shareLaunch.value = value
  },
  { immediate: true },
)
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
    :data-app-id="app.id"
    :class="{
      'app-window--camera-landscape':
        app.id === 'camera' && phone.cameraLandscape,
      'app-window--citywarn': app.id === 'citywarn',
    }"
    :style="launchStyle"
  >
    <CustomAppFrame
      v-if="isExternalPhoneApp(app)"
      :key="getCustomAppFrameKey(app)"
      :app="app"
    />
    <Suspense v-else :key="app.id">
      <component :is="builtinAppComponent" :key="shareLaunch" />
      <template #fallback>
        <div class="app-loading">{{ phone.t('Common.loading') }}</div>
      </template>
    </Suspense>
    <EasyShareContentPreview />
  </div>
</template>
