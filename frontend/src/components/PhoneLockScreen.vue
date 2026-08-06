<script setup lang="ts">
import { kLink, kNavbar } from 'konsta/vue'
import {
  BatteryMedium,
  Camera,
  Flashlight,
  LockKeyhole,
  Signal,
  Wifi,
} from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

import { usePhoneStore } from '@/stores/phone'

const emit = defineEmits<{
  unlock: []
}>()

const phone = usePhoneStore()
const now = ref(new Date())
const dragOffset = ref(0)
const dragging = ref(false)
const flashlightActive = ref(false)
const lockNavbarColors = { bgIos: 'bg-transparent' }
const neutralGlassClass =
  '!bg-white/10 !shadow-none ring-1 ring-inset ring-white/15 backdrop-saturate-150'
const activeFlashlightGlassClass =
  '!bg-white !shadow-none ring-1 ring-inset ring-white/60 backdrop-saturate-150'
const whiteNavbarLinkColors = { navbarTextIos: 'text-white' }
let pointerStart = 0
let pointerStartedAt = 0
let clockTicker: number | undefined

const date = computed(() =>
  new Intl.DateTimeFormat(phone.lang, {
    day: 'numeric',
    month: 'long',
    weekday: 'long',
  }).format(now.value),
)
const time = computed(() =>
  new Intl.DateTimeFormat(phone.lang, {
    hour: 'numeric',
    minute: '2-digit',
  })
    .formatToParts(now.value)
    .filter((part) => part.type !== 'dayPeriod')
    .map((part) => part.value)
    .join('')
    .trim(),
)
const dragStyle = computed(() => ({
  '--lock-drag': `${dragOffset.value}px`,
}))
const flashlightGlassClass = computed(() =>
  flashlightActive.value ? activeFlashlightGlassClass : neutralGlassClass,
)
const flashlightLinkColors = computed(() => ({
  navbarTextIos: flashlightActive.value ? 'text-purple-500' : 'text-white',
}))

function onPointerDown(event: PointerEvent): void {
  if ((event.target as HTMLElement).closest('button')) return
  pointerStart = event.clientY
  pointerStartedAt = Date.now()
  dragging.value = true
  ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
}

function onPointerMove(event: PointerEvent): void {
  if (!dragging.value) return
  dragOffset.value = Math.min(0, event.clientY - pointerStart)
}

function finishPointer(event: PointerEvent): void {
  if (!dragging.value) return
  const distance = event.clientY - pointerStart
  const elapsed = Math.max(1, Date.now() - pointerStartedAt)
  const velocity = Math.abs(distance) / elapsed
  dragging.value = false

  if (distance < -74 || (distance < -22 && velocity > 0.55)) {
    emit('unlock')
    return
  }

  dragOffset.value = 0
}

function unlockWithKeyboard(event: KeyboardEvent): void {
  if (event.key === 'Enter' || event.key === ' ') emit('unlock')
}

function unlockFromWallpaper(event: MouseEvent): void {
  if ((event.target as HTMLElement).closest('button, [role="link"]')) return
  emit('unlock')
}

onMounted(() => {
  clockTicker = window.setInterval(() => {
    now.value = new Date()
  }, 15_000)
})

onBeforeUnmount(() => {
  if (clockTicker !== undefined) window.clearInterval(clockTicker)
})
</script>

<template>
  <section
    class="lock-screen"
    :class="[
      `wallpaper--${phone.preferences.settings.wallpaper}`,
      { 'lock-screen--dragging': dragging },
    ]"
    :style="dragStyle"
    :aria-label="phone.t('LockScreen.label')"
    tabindex="0"
    @keydown="unlockWithKeyboard"
    @pointerdown="onPointerDown"
    @pointermove="onPointerMove"
    @pointerup="finishPointer"
    @pointercancel="finishPointer"
    @click="unlockFromWallpaper"
  >
    <div class="lock-screen__shade" aria-hidden="true"></div>

    <header class="lock-screen__status">
      <div class="lock-screen__indicators" aria-hidden="true">
        <Signal :size="12" :stroke-width="2.5" />
        <Wifi :size="13" :stroke-width="2.5" />
        <BatteryMedium :size="17" :stroke-width="2.4" />
      </div>
    </header>
    <LockKeyhole
      class="lock-screen__lock"
      :size="14"
      :stroke-width="1.8"
      aria-hidden="true"
    />

    <div class="lock-screen__content">
      <time class="lock-screen__date">{{ date }}</time>
      <time class="lock-screen__time">{{ time }}</time>
    </div>

    <div class="lock-screen__footer">
      <k-navbar
        transparent
        :colors="lockNavbarColors"
        inner-class="!px-12"
        :left-class="flashlightGlassClass"
        :right-class="neutralGlassClass"
      >
        <template #left>
          <k-link
            component="button"
            icon-only
            :colors="flashlightLinkColors"
            :link-props="{ type: 'button' }"
            :aria-label="phone.t('LockScreen.flashlight')"
            @click="flashlightActive = !flashlightActive"
          >
            <Flashlight :stroke-width="1.4" aria-hidden="true" />
          </k-link>
        </template>
        <template #right>
          <k-link
            component="button"
            icon-only
            :colors="whiteNavbarLinkColors"
            :link-props="{ type: 'button' }"
            :aria-label="phone.t('LockScreen.camera')"
          >
            <Camera :stroke-width="1.4" aria-hidden="true" />
          </k-link>
        </template>
      </k-navbar>

      <button class="lock-screen__swipe" type="button" @click="emit('unlock')">
        <span class="lock-screen__swipe-chevron" aria-hidden="true"></span>
        {{ phone.t('LockScreen.swipeUp') }}
      </button>
    </div>
  </section>
</template>
