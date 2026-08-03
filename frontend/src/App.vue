<script setup lang="ts">
import { kApp } from 'konsta/vue'
import { computed, onBeforeUnmount, onMounted, type CSSProperties } from 'vue'
import { useRoute } from 'vue-router'

import PhoneHomeIndicator from '@/components/PhoneHomeIndicator.vue'
import PhoneStatusBar from '@/components/PhoneStatusBar.vue'
import { PHONE_FRAME_IMAGES } from '@/config/appearance'
import { usePhoneStore, type PhoneOpenPayload } from '@/stores/phone'
import { nuiCall } from '@/utils/nui'
import SpringboardView from '@/views/SpringboardView.vue'

type AppMessage = {
  type?: string
  data?: PhoneOpenPayload
}

const phone = usePhoneStore()
const route = useRoute()
const isAppRoute = computed(() => route.name === 'app')
const systemColorScheme = window.matchMedia('(prefers-color-scheme: dark)')
const phoneDeviceStyle = computed<CSSProperties>(() => ({
  '--phone-scale': phone.preferences.settings.phoneScale / 100,
}))
const phoneFrameImage = computed(
  () => PHONE_FRAME_IMAGES[phone.preferences.settings.frame],
)

function onMessage(event: MessageEvent<AppMessage>): void {
  if (event.data?.type === 'app:open') {
    phone.open(event.data.data)
  } else if (event.data?.type === 'app:close') {
    phone.close()
  }
}

function onKeydown(event: KeyboardEvent): void {
  if (event.key !== 'Escape' || !phone.isOpen) return
  phone.close()
  void nuiCall('close')
}

function onSystemColorSchemeChange(event: MediaQueryListEvent): void {
  phone.setSystemDarkMode(event.matches)
}

onMounted(() => {
  window.addEventListener('message', onMessage)
  window.addEventListener('keydown', onKeydown)
  systemColorScheme.addEventListener('change', onSystemColorSchemeChange)
  phone.setSystemDarkMode(systemColorScheme.matches)
  void nuiCall('ui:ready')
  if (import.meta.env.DEV) phone.open()
})

onBeforeUnmount(() => {
  window.removeEventListener('message', onMessage)
  window.removeEventListener('keydown', onKeydown)
  systemColorScheme.removeEventListener('change', onSystemColorSchemeChange)
})
</script>

<template>
  <main v-if="phone.isOpen" class="phone-stage">
    <section
      class="phone-device"
      :style="phoneDeviceStyle"
      :aria-label="phone.t('Common.phone')"
    >
      <div class="phone-screen" :class="{ 'phone-screen--app': isAppRoute }">
        <k-app
          theme="ios"
          :dark="phone.isDarkMode"
          safe-areas
          class="phone-app"
          :class="{
            dark: phone.isDarkMode,
            'phone-app--light': !phone.isDarkMode,
          }"
        >
          <PhoneStatusBar />
          <SpringboardView />
          <RouterView v-slot="{ Component }">
            <Transition name="app-window">
              <component :is="Component" v-if="isAppRoute" />
            </Transition>
          </RouterView>
          <PhoneHomeIndicator />
        </k-app>
      </div>
      <img
        class="phone-device__frame"
        :src="phoneFrameImage"
        alt=""
        aria-hidden="true"
        draggable="false"
      />
    </section>
  </main>
</template>
