<script setup lang="ts">
import { Camera, RotateCcw } from 'lucide-vue-next'
import { ref } from 'vue'
import { useMediaStore } from '@/stores/media'
import { usePhoneStore } from '@/stores/phone'
const media = useMediaStore()
const phone = usePhoneStore()
const flash = ref(false)
const modes = ['video', 'photo', 'portrait'] as const
function capture(): void {
  flash.value = true
  media.capture()
  setTimeout(() => {
    flash.value = false
  }, 120)
}
</script>
<template>
  <main class="native-app camera-app">
    <div
      class="camera-viewfinder"
      :class="`camera-facing--${media.cameraFacing}`"
    >
      <div class="camera-flash" :class="{ active: flash }" />
      <div class="camera-grid" />
      <div class="camera-zoom">
        <button
          v-for="zoom in [0.5, 1, 2]"
          :key="zoom"
          :class="{ active: media.cameraZoom === zoom }"
          type="button"
          @click="media.cameraZoom = zoom"
        >
          {{ zoom }}×
        </button>
      </div>
    </div>
    <div class="camera-modes">
      <button
        v-for="mode in modes"
        :key="mode"
        :class="{ active: media.cameraMode === mode }"
        type="button"
        @click="media.cameraMode = mode"
      >
        {{ phone.t(`Apps.camera.modes.${mode}`) }}
      </button>
    </div>
    <div class="camera-controls">
      <span /><button
        class="shutter"
        type="button"
        :aria-label="phone.t('Apps.camera.shutter')"
        @click="capture"
      >
        <Camera :size="26" /></button
      ><button
        type="button"
        :aria-label="phone.t('Apps.camera.flip')"
        @click="
          media.cameraFacing = media.cameraFacing === 'rear' ? 'front' : 'rear'
        "
      >
        <RotateCcw :size="23" />
      </button>
    </div>
  </main>
</template>
