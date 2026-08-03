<script setup lang="ts">
import {
  Aperture,
  Camera,
  ChevronUp,
  RotateCcw,
  Zap,
  ZapOff,
} from 'lucide-vue-next'
import { ref } from 'vue'

import { useMediaStore } from '@/stores/media'
import { usePhoneStore } from '@/stores/phone'

const media = useMediaStore()
const phone = usePhoneStore()
const flash = ref(false)
const flashEnabled = ref(false)
const modes = [
  'timelapse',
  'slowMo',
  'cinematic',
  'video',
  'photo',
  'portrait',
  'pano',
] as const

function capture(): void {
  flash.value = true
  media.capture()
  window.setTimeout(() => (flash.value = false), 120)
}
</script>

<template>
  <main class="native-app reference-camera">
    <header class="camera-topbar">
      <div>
        <button
          type="button"
          :aria-label="phone.t('Apps.camera.flash')"
          @click="flashEnabled = !flashEnabled"
        >
          <Zap v-if="flashEnabled" :size="22" />
          <ZapOff v-else :size="22" />
        </button>
        <Aperture :size="22" />
      </div>
      <button
        class="camera-chevron"
        type="button"
        :aria-label="phone.t('Apps.camera.controls')"
      >
        <ChevronUp :size="20" />
      </button>
      <Aperture :size="22" />
    </header>

    <section
      class="reference-viewfinder"
      :class="`camera-facing--${media.cameraFacing}`"
    >
      <div class="camera-flash" :class="{ active: flash }" />
      <i
        v-for="corner in ['tl', 'tr', 'bl', 'br']"
        :key="corner"
        :class="`focus-corner focus-corner--${corner}`"
      />
      <div class="camera-zoom">
        <button
          v-for="zoom in [0.5, 1]"
          :key="zoom"
          :class="{ active: media.cameraZoom === zoom }"
          type="button"
          @click="media.cameraZoom = zoom"
        >
          {{ zoom }}<small v-if="zoom === 1">x</small>
        </button>
      </div>
    </section>

    <footer class="reference-camera-footer">
      <nav class="camera-mode-strip">
        <button
          v-for="mode in modes"
          :key="mode"
          :class="{ active: media.cameraMode === mode }"
          type="button"
          @click="
            mode === 'photo' || mode === 'portrait' || mode === 'video'
              ? (media.cameraMode = mode)
              : undefined
          "
        >
          {{ phone.t(`Apps.camera.modes.${mode}`) }}
        </button>
      </nav>
      <div class="camera-shutter-row">
        <div
          class="camera-thumbnail"
          :style="{ background: media.photos[0]?.gradient }"
        />
        <button
          class="reference-shutter"
          type="button"
          :aria-label="phone.t('Apps.camera.shutter')"
          @click="capture"
        >
          <Camera :size="23" />
        </button>
        <button
          class="reference-flip"
          type="button"
          :aria-label="phone.t('Apps.camera.flip')"
          @click="
            media.cameraFacing =
              media.cameraFacing === 'rear' ? 'front' : 'rear'
          "
        >
          <RotateCcw :size="22" />
        </button>
      </div>
    </footer>
  </main>
</template>
