<script setup lang="ts">
import { SkyApp } from '@/ui'

import { computed, type CSSProperties } from 'vue'

import PhoneLockScreen from '@/components/PhoneLockScreen.vue'
import PhoneNotifications from '@/components/PhoneNotifications.vue'
import { PHONE_FRAME_IMAGES } from '@/config/appearance'
import type { PhoneNotification } from '@/stores/notifications'
import { usePhoneStore } from '@/stores/phone'
import { getHairlinePixelStyle } from '@/utils/rendering'

const props = defineProps<{
  devicePixelRatio: number
  notification: PhoneNotification
  zoom: number
}>()
const emit = defineEmits<{
  close: []
  open: [notification: PhoneNotification]
}>()
const phone = usePhoneStore()
const device = computed(() => props.notification.device!)
const preferences = computed(() => device.value.preferences)
const isDarkMode = computed(() => {
  const appearance = preferences.value.settings.appearanceMode
  if (appearance === 'dark') return true
  if (appearance === 'light') return false
  return phone.systemDarkMode
})
const frameImage = computed(
  () => PHONE_FRAME_IMAGES[preferences.value.settings.frame],
)
const wrapperStyle = computed<CSSProperties>(() => ({
  ...getHairlinePixelStyle(props.zoom, props.devicePixelRatio),
  '--phone-rendered-height': `${844 * props.zoom}px`,
  '--phone-rendered-width': `${390 * props.zoom}px`,
  '--phone-zoom': props.zoom,
}))
</script>

<template>
  <div
    class="phone-resolution-wrapper phone-resolution-wrapper--notification"
    :style="wrapperStyle"
  >
    <div class="phone-resolution-canvas">
      <section
        class="phone-device phone-device--notification"
        :class="{
          'phone-app--light': !isDarkMode,
          [`phone-app--${preferences.settings.graphicsMode}`]: true,
        }"
        :aria-label="device.name"
      >
        <div
          class="phone-screen"
          :class="{
            'phone-app--light': !isDarkMode,
            [`phone-app--${preferences.settings.graphicsMode}`]: true,
          }"
        >
          <SkyApp
            :dark="isDarkMode"
            safe-areas
            class="phone-app"
            :class="{
              dark: isDarkMode,
              'phone-app--light': !isDarkMode,
              [`phone-app--${preferences.settings.graphicsMode}`]: true,
            }"
          >
            <PhoneLockScreen
              :notifications="[]"
              :preferences="preferences"
              preview
            />
            <PhoneNotifications
              :dark="isDarkMode"
              :notification="notification"
              @close="emit('close')"
              @open="emit('open', $event)"
            />
          </SkyApp>
        </div>
        <img
          class="phone-device__frame"
          :src="frameImage"
          alt=""
          aria-hidden="true"
          draggable="false"
        />
      </section>
    </div>
  </div>
</template>
