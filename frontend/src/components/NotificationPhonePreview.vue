<script setup lang="ts">
import { kApp } from 'konsta/vue'
import { computed, type CSSProperties } from 'vue'

import PhoneNotifications from '@/components/PhoneNotifications.vue'
import PhoneStatusBar from '@/components/PhoneStatusBar.vue'
import { PHONE_FRAME_IMAGES } from '@/config/appearance'
import type { PhoneNotification } from '@/stores/notifications'
import { usePhoneStore } from '@/stores/phone'

const props = defineProps<{
  notification: PhoneNotification
  zoom: number
}>()
const emit = defineEmits<{
  close: []
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
const wrapperStyle = computed<CSSProperties>(() => ({ zoom: props.zoom }))
</script>

<template>
  <div
    class="phone-resolution-wrapper phone-resolution-wrapper--notification"
    :style="wrapperStyle"
  >
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
        <k-app
          theme="ios"
          :dark="isDarkMode"
          safe-areas
          class="phone-app"
          :class="{
            dark: isDarkMode,
            'phone-app--light': !isDarkMode,
            [`phone-app--${preferences.settings.graphicsMode}`]: true,
          }"
        >
          <div
            class="notification-phone-background"
            :class="`wallpaper--${preferences.settings.wallpaper}`"
          ></div>
          <PhoneStatusBar />
          <PhoneNotifications
            :notification="notification"
            @close="emit('close')"
          />
        </k-app>
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
</template>
