<script setup lang="ts">
import { ScanFace } from 'lucide-vue-next'
import { computed } from 'vue'

import PhoneStatusBar from '@/components/PhoneStatusBar.vue'
import { usePhoneStore } from '@/stores/phone'
import { SkyButton } from '@/ui'

defineProps<{ busy: boolean; error: string }>()
const emit = defineEmits<{ retry: []; passcode: [] }>()
const phone = usePhoneStore()
const wallpaperStyle = computed(() => {
  const settings = phone.preferences.settings
  return settings.lockWallpaper === 'custom' && settings.lockWallpaperImageUrl
    ? {
        '--phone-wallpaper-image': `url(${JSON.stringify(settings.lockWallpaperImageUrl)})`,
      }
    : {}
})
</script>

<template>
  <section
    class="face-id-screen"
    :class="`wallpaper--${phone.preferences.settings.lockWallpaper}`"
    :style="wallpaperStyle"
    :aria-label="phone.t('FaceId.title')"
    :aria-busy="busy"
  >
    <PhoneStatusBar :interactive="false" />
    <div class="face-id-screen__content">
      <ScanFace
        class="face-id-screen__icon"
        :class="{ 'face-id-screen__icon--scanning': busy }"
        :size="76"
        :stroke-width="1.3"
        aria-hidden="true"
      />
      <h1>{{ phone.t('FaceId.title') }}</h1>
      <p role="status">{{ busy ? phone.t('FaceId.scanning') : error }}</p>
      <SkyButton v-if="!busy" glass rounded @click="emit('retry')">{{
        phone.t('FaceId.retry')
      }}</SkyButton>
      <button
        type="button"
        class="face-id-screen__passcode"
        @click="emit('passcode')"
      >
        {{ phone.t('FaceId.usePin') }}
      </button>
    </div>
  </section>
</template>

<style scoped>
.face-id-screen {
  position: absolute;
  inset: 0;
  z-index: 91;
  color: #fff;
  background-color: #090a0d;
  background-position: center;
  background-size: cover;
  font-family: var(--sky-font-family);
}
.face-id-screen::before {
  content: '';
  position: absolute;
  inset: 0;
  background: rgb(0 0 0 / 50%);
  backdrop-filter: blur(18px);
}
.face-id-screen :deep(.phone-status-bar) {
  color: #fff;
}
.face-id-screen__content {
  position: relative;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 20px;
  padding: 72px 30px;
  text-align: center;
}
.face-id-screen__content h1 {
  margin: 0;
  font-size: 26px;
}
.face-id-screen__content p {
  min-height: 44px;
  margin: 0;
  color: rgb(255 255 255 / 78%);
}
.face-id-screen__icon {
  color: #a8e6bd;
}
.face-id-screen__icon--scanning {
  animation: face-id-scan 1.2s ease-in-out infinite;
}
.face-id-screen__passcode {
  min-height: 44px;
  padding: 10px 20px;
  border: 0;
  background: transparent;
  color: inherit;
  font: inherit;
}
@keyframes face-id-scan {
  50% {
    opacity: 0.45;
    transform: scale(0.96);
  }
}
@media (prefers-reduced-motion: reduce) {
  .face-id-screen__icon--scanning {
    animation: none;
  }
}
</style>
