<script setup lang="ts">
import { SkyButton, SkyGlass, SkyIcon, SkyRange } from '@/ui'

import {
  BellOff,
  Bluetooth,
  Calculator,
  Camera,
  Flashlight,
  Moon,
  Pause,
  Plane,
  Play,
  RadioTower,
  Signal,
  SkipBack,
  SkipForward,
  Sun,
  TimerReset,
  Volume2,
  Wifi,
} from 'lucide-vue-next'
import {
  computed,
  nextTick,
  onBeforeUnmount,
  ref,
  watch,
  type CSSProperties,
} from 'vue'
import { useRouter } from 'vue-router'

import { usePhoneStore } from '@/stores/phone'
import { useMusicStore } from '@/stores/music'
import { useEasyShareStore } from '@/stores/easyshare'
import type { EasySharePayload } from '@/types/easyshare'
import { nuiCall } from '@/utils/nui'
import { bindPointerDragSession } from '@/utils/pointerDragSession'

const props = defineProps<{ opened: boolean }>()
const emit = defineEmits<{ close: [] }>()

type ConnectivityPreference =
  | 'airplaneMode'
  | 'bluetoothEnabled'
  | 'cellularEnabled'
  | 'focusMode'
  | 'wifiEnabled'

const phone = usePhoneStore()
const music = useMusicStore()
const easyShare = useEasyShareStore()
const router = useRouter()
const panel = ref<HTMLElement | null>(null)
const brightness = ref(phone.preferences.settings.screenBrightness)
const volume = ref(
  Math.round(
    (phone.preferences.settings.notificationVolume +
      phone.preferences.settings.ringtoneVolume) /
      2,
  ),
)
const flashlightActive = ref(false)
const flashlightPending = ref(false)
const easySharePending = ref(false)
const previousAlertVolume = ref(volume.value || 75)
const sliderDragActive = ref(false)
type SliderKind = 'brightness' | 'volume'
type SliderDrag = {
  animationFrame: number | null
  currentValue: number
  kind: SliderKind
  lastClientY: number
  pendingClientY: number
  pointerId: number
  pointerType: string
  stopMouse: () => void
  stopPointer: () => void
  target: HTMLElement
}
let sliderDrag: SliderDrag | null = null

const alertsMuted = computed(() => volume.value === 0)
const brightnessStyle = computed<CSSProperties>(() => ({
  '--control-level': `${brightness.value}%`,
}))
const volumeStyle = computed<CSSProperties>(() => ({
  '--control-level': `${volume.value}%`,
}))

function togglePreference(key: ConnectivityPreference): void {
  phone.setPreference(key, !phone.preferences.settings[key])
}

function updateBrightness(event: Event): void {
  const nextValue = Number.parseInt(
    (event.target as HTMLInputElement).value,
    10,
  )
  brightness.value = nextValue
  phone.preferences.settings.screenBrightness = nextValue
}

function saveBrightness(event: Event): void {
  phone.setPreference(
    'screenBrightness',
    Number.parseInt((event.target as HTMLInputElement).value, 10),
  )
}

function updateVolume(event: Event): void {
  volume.value = Number.parseInt((event.target as HTMLInputElement).value, 10)
}

function saveVolume(event: Event): void {
  const nextValue = Number.parseInt(
    (event.target as HTMLInputElement).value,
    10,
  )
  if (nextValue > 0) previousAlertVolume.value = nextValue
  phone.setAlertVolumes(nextValue)
}

function toggleAlertMute(): void {
  if (alertsMuted.value) {
    volume.value = previousAlertVolume.value
  } else {
    previousAlertVolume.value = volume.value
    volume.value = 0
  }
  phone.setAlertVolumes(volume.value)
}

function sliderRange(kind: SliderKind): { maximum: number; minimum: number } {
  return kind === 'brightness'
    ? { maximum: 100, minimum: 10 }
    : { maximum: 100, minimum: 0 }
}

function applySliderValue(drag: SliderDrag, value: number): void {
  drag.currentValue = value
  if (drag.kind === 'brightness') {
    brightness.value = value
    phone.preferences.settings.screenBrightness = value
    return
  }
  volume.value = value
}

function updateSliderDrag(clientY: number, drag: SliderDrag): void {
  const rect = drag.target.getBoundingClientRect()
  const { maximum, minimum } = sliderRange(drag.kind)
  const deltaY = clientY - drag.lastClientY
  drag.lastClientY = clientY
  const nextValue =
    Math.round(
      Math.min(
        maximum,
        Math.max(
          minimum,
          drag.currentValue - (deltaY / rect.height) * (maximum - minimum),
        ),
      ) * 100,
    ) / 100
  applySliderValue(drag, nextValue)
}

function queueSliderDrag(clientY: number, drag: SliderDrag): void {
  drag.pendingClientY = clientY
  if (drag.animationFrame !== null) return
  drag.animationFrame = window.requestAnimationFrame(() => {
    drag.animationFrame = null
    if (sliderDrag !== drag) return
    updateSliderDrag(drag.pendingClientY, drag)
  })
}

function flushSliderDrag(clientY: number, drag: SliderDrag): void {
  drag.pendingClientY = clientY
  if (drag.animationFrame !== null) {
    window.cancelAnimationFrame(drag.animationFrame)
    drag.animationFrame = null
  }
  updateSliderDrag(drag.pendingClientY, drag)
}

function cancelSliderAnimation(drag: SliderDrag): void {
  if (drag.animationFrame === null) return
  window.cancelAnimationFrame(drag.animationFrame)
  drag.animationFrame = null
}

function bindSliderMouseFallback(drag: SliderDrag): () => void {
  let active = true
  const cleanup = (): void => {
    if (!active) return
    active = false
    window.removeEventListener('mousemove', onMouseMove, true)
    window.removeEventListener('mouseup', onMouseUp, true)
    window.removeEventListener('blur', onBlur, true)
  }
  const onMouseMove = (event: MouseEvent): void => {
    if (!active || sliderDrag !== drag) return
    queueSliderDrag(event.clientY, drag)
  }
  const onMouseUp = (event: MouseEvent): void => {
    if (!active || sliderDrag !== drag) return
    flushSliderDrag(event.clientY, drag)
    cleanup()
    finishSliderDrag(true)
  }
  const onBlur = (): void => {
    if (!active || sliderDrag !== drag) return
    cleanup()
    finishSliderDrag(true)
  }

  window.addEventListener('mousemove', onMouseMove, true)
  window.addEventListener('mouseup', onMouseUp, true)
  window.addEventListener('blur', onBlur, true)
  return cleanup
}

function continueSliderSurfaceDrag(event: MouseEvent | PointerEvent): void {
  const drag = sliderDrag
  if (!drag) return
  event.preventDefault()
  queueSliderDrag(event.clientY, drag)
}

function finishSliderSurfaceDrag(event: MouseEvent | PointerEvent): void {
  const drag = sliderDrag
  if (!drag) return
  event.preventDefault()
  flushSliderDrag(event.clientY, drag)
  finishSliderDrag(true)
}

function finishSliderDrag(save: boolean): void {
  const drag = sliderDrag
  if (!drag) return
  sliderDrag = null
  sliderDragActive.value = false
  cancelSliderAnimation(drag)
  drag.stopPointer()
  drag.stopMouse()
  if (!save) return
  if (drag.kind === 'brightness') {
    const nextValue = Math.round(brightness.value)
    brightness.value = nextValue
    phone.preferences.settings.screenBrightness = nextValue
    phone.setPreference('screenBrightness', nextValue)
    return
  }
  const nextValue = Math.round(volume.value)
  volume.value = nextValue
  if (nextValue > 0) previousAlertVolume.value = nextValue
  phone.setAlertVolumes(nextValue)
}

function startSliderDrag(kind: SliderKind, event: PointerEvent): void {
  if (event.button !== 0) return
  finishSliderDrag(true)
  const target = event.currentTarget as HTMLElement
  const pointerId = event.pointerId
  const initialValue = kind === 'brightness' ? brightness.value : volume.value
  const drag: SliderDrag = {
    animationFrame: null,
    currentValue: initialValue,
    kind,
    lastClientY: event.clientY,
    pendingClientY: event.clientY,
    pointerId,
    pointerType: event.pointerType,
    stopMouse: () => {},
    stopPointer: () => {},
    target,
  }
  sliderDrag = drag
  sliderDragActive.value = true
  applySliderValue(drag, initialValue)
  drag.stopPointer = bindPointerDragSession(window, pointerId, {
    cancel: () => {
      if (drag.pointerType === 'touch') {
        finishSliderDrag(true)
        return
      }
      drag.stopPointer()
      drag.stopPointer = () => {}
    },
    move: (moveEvent) => queueSliderDrag(moveEvent.clientY, drag),
    up: (upEvent) => {
      flushSliderDrag(upEvent.clientY, drag)
      finishSliderDrag(true)
    },
  })
  if (event.pointerType !== 'touch') {
    drag.stopMouse = bindSliderMouseFallback(drag)
  }
}

async function toggleFlashlight(): Promise<void> {
  if (flashlightPending.value) return
  const enabled = !flashlightActive.value
  flashlightActive.value = enabled
  flashlightPending.value = true
  const response = await nuiCall('camera:setFlash', { enabled })
  if (!response.success) flashlightActive.value = !enabled
  flashlightPending.value = false
}

async function shareOwnContact(): Promise<void> {
  if (easySharePending.value) return
  easySharePending.value = true
  const response = await nuiCall<EasySharePayload>('easyshare:own-contact')
  easySharePending.value = false
  if (!response.success || !response.data) {
    console.error(
      '[ControlCenter] Could not load own EasyShare contact.',
      response.error,
    )
    return
  }
  emit('close')
  easyShare.open(response.data)
  await easyShare.showNearby()
}

function openApp(path: string): void {
  emit('close')
  void router.push(path)
}

function openTimer(): void {
  emit('close')
  void router.push({ path: '/apps/clock', query: { section: 'timer' } })
}

watch(
  () => props.opened,
  (opened) => {
    if (!opened) {
      finishSliderDrag(true)
      return
    }
    brightness.value = phone.preferences.settings.screenBrightness
    volume.value = Math.round(
      (phone.preferences.settings.notificationVolume +
        phone.preferences.settings.ringtoneVolume) /
        2,
    )
    if (volume.value > 0) previousAlertVolume.value = volume.value
    void nextTick(() => panel.value?.focus({ preventScroll: true }))
  },
)

onBeforeUnmount(() => {
  finishSliderDrag(true)
  if (flashlightActive.value)
    void nuiCall('camera:setFlash', { enabled: false })
})
</script>

<template>
  <Transition name="control-center">
    <section
      v-if="opened"
      class="control-center"
      :class="{ 'control-center--slider-dragging': sliderDragActive }"
      role="dialog"
      aria-modal="true"
      :aria-label="phone.t('ControlCenter.label')"
    >
      <SkyButton
        variant="content"
        class="control-center__backdrop"
        type="button"
        tabindex="-1"
        :aria-label="phone.t('ControlCenter.close')"
        @click="emit('close')"
      ></SkyButton>

      <div ref="panel" class="control-center__panel" tabindex="-1">
        <div class="control-center__top-grid">
          <SkyGlass class="control-center__connectivity" :highlight="false">
            <SkyButton
              variant="content"
              type="button"
              class="control-center__connectivity-button"
              :class="{
                'control-center__connectivity-button--airplane':
                  phone.preferences.settings.airplaneMode,
              }"
              :aria-label="phone.t('ControlCenter.airplaneMode')"
              :aria-pressed="phone.preferences.settings.airplaneMode"
              @click="togglePreference('airplaneMode')"
            >
              <SkyIcon :icon="Plane" aria-hidden="true" />
            </SkyButton>
            <SkyButton
              variant="content"
              type="button"
              class="control-center__connectivity-button"
              :class="{
                'control-center__connectivity-button--cellular':
                  phone.preferences.settings.cellularEnabled,
              }"
              :aria-label="phone.t('ControlCenter.cellular')"
              :aria-pressed="phone.preferences.settings.cellularEnabled"
              @click="togglePreference('cellularEnabled')"
            >
              <SkyIcon :icon="Signal" aria-hidden="true" />
            </SkyButton>
            <SkyButton
              variant="content"
              type="button"
              class="control-center__connectivity-button"
              :class="{
                'control-center__connectivity-button--wifi':
                  phone.preferences.settings.wifiEnabled,
              }"
              :aria-label="phone.t('ControlCenter.wifi')"
              :aria-pressed="phone.preferences.settings.wifiEnabled"
              @click="togglePreference('wifiEnabled')"
            >
              <SkyIcon :icon="Wifi" aria-hidden="true" />
            </SkyButton>
            <SkyButton
              variant="content"
              type="button"
              class="control-center__connectivity-button"
              :class="{
                'control-center__connectivity-button--bluetooth':
                  phone.preferences.settings.bluetoothEnabled,
              }"
              :aria-label="phone.t('ControlCenter.bluetooth')"
              :aria-pressed="phone.preferences.settings.bluetoothEnabled"
              @click="togglePreference('bluetoothEnabled')"
            >
              <SkyIcon :icon="Bluetooth" aria-hidden="true" />
            </SkyButton>
          </SkyGlass>

          <SkyGlass class="control-center__media" :highlight="false">
            <div class="control-center__media-copy">
              <span>{{ phone.t('ControlCenter.media') }}</span>
              <strong>{{
                music.currentTrack?.title ?? phone.t('ControlCenter.notPlaying')
              }}</strong>
              <small v-if="music.currentTrack">{{
                music.currentTrack.artist
              }}</small>
            </div>
            <div class="control-center__media-controls">
              <SkyButton
                variant="content"
                type="button"
                :disabled="!music.currentTrack"
                :aria-label="phone.t('ControlCenter.previous')"
                @click="music.previous"
              >
                <SkyIcon :icon="SkipBack" aria-hidden="true" />
              </SkyButton>
              <SkyButton
                variant="content"
                type="button"
                :disabled="!music.currentTrack && !music.allTracks.length"
                :aria-label="
                  phone.t(
                    music.isPlaying ? 'Common.pause' : 'ControlCenter.play',
                  )
                "
                @click="music.toggle"
              >
                <SkyIcon
                  :icon="Pause"
                  v-if="music.isPlaying"
                  aria-hidden="true"
                />
                <SkyIcon :icon="Play" v-else aria-hidden="true" />
              </SkyButton>
              <SkyButton
                variant="content"
                type="button"
                :disabled="!music.currentTrack"
                :aria-label="phone.t('ControlCenter.next')"
                @click="music.next"
              >
                <SkyIcon :icon="SkipForward" aria-hidden="true" />
              </SkyButton>
            </div>
          </SkyGlass>
        </div>

        <div class="control-center__middle-grid">
          <div class="control-center__round-control">
            <SkyButton
              glass
              inline
              component="button"
              type="button"
              class="control-center__round-button"
              :class="{
                'control-center__round-button--light': alertsMuted,
              }"
              :aria-label="
                phone.t(
                  alertsMuted
                    ? 'ControlCenter.unmuteRingtone'
                    : 'ControlCenter.muteRingtone',
                )
              "
              :aria-pressed="alertsMuted"
              @click="toggleAlertMute"
            >
              <SkyIcon :icon="BellOff" aria-hidden="true" />
            </SkyButton>
          </div>

          <div class="control-center__round-control">
            <SkyButton
              glass
              inline
              component="button"
              type="button"
              class="control-center__round-button"
              :disabled="easySharePending || !phone.device?.sim"
              :aria-label="phone.t('ControlCenter.easyShareContact')"
              @click="shareOwnContact"
            >
              <SkyIcon :icon="RadioTower" aria-hidden="true" />
            </SkyButton>
          </div>

          <SkyGlass
            class="control-center__slider control-center__slider--brightness"
            :highlight="false"
            :style="brightnessStyle"
            @pointerdown="startSliderDrag('brightness', $event)"
          >
            <span
              class="control-center__slider-level"
              aria-hidden="true"
            ></span>
            <SkyRange
              class="control-center__range"
              :value="brightness"
              :min="10"
              :max="100"
              :aria-label="phone.t('ControlCenter.brightness')"
              @input="updateBrightness"
              @change="saveBrightness"
            />
            <SkyIcon
              :icon="Sun"
              class="control-center__slider-icon"
              fill="currentColor"
              aria-hidden="true"
            />
          </SkyGlass>

          <SkyGlass
            class="control-center__slider control-center__slider--volume"
            :highlight="false"
            :style="volumeStyle"
            @pointerdown="startSliderDrag('volume', $event)"
          >
            <span
              class="control-center__slider-level"
              aria-hidden="true"
            ></span>
            <SkyRange
              class="control-center__range"
              :value="volume"
              :min="0"
              :max="100"
              :aria-label="phone.t('ControlCenter.volume')"
              @input="updateVolume"
              @change="saveVolume"
            />
            <SkyIcon
              :icon="Volume2"
              class="control-center__slider-icon"
              fill="currentColor"
              aria-hidden="true"
            />
          </SkyGlass>

          <SkyButton
            glass
            inline
            component="button"
            type="button"
            class="control-center__focus-button"
            :class="{
              'control-center__focus-button--active':
                phone.preferences.settings.focusMode,
            }"
            :aria-label="phone.t('ControlCenter.focus')"
            :aria-pressed="phone.preferences.settings.focusMode"
            @click="togglePreference('focusMode')"
          >
            <SkyIcon :icon="Moon" aria-hidden="true" />
            <span>{{ phone.t('ControlCenter.focus') }}</span>
          </SkyButton>
        </div>

        <nav
          class="control-center__quick-actions"
          :aria-label="phone.t('ControlCenter.quickActions')"
        >
          <div class="control-center__quick-action">
            <SkyButton
              glass
              inline
              component="button"
              type="button"
              class="control-center__quick-button"
              :class="{
                'control-center__quick-button--flashlight-active':
                  flashlightActive,
              }"
              :disabled="flashlightPending"
              :aria-label="phone.t('ControlCenter.flashlight')"
              :aria-pressed="flashlightActive"
              @click="toggleFlashlight"
            >
              <SkyIcon :icon="Flashlight" aria-hidden="true" />
            </SkyButton>
            <span>{{ phone.t('ControlCenter.flashlight') }}</span>
          </div>
          <div class="control-center__quick-action">
            <SkyButton
              glass
              inline
              component="button"
              type="button"
              class="control-center__quick-button"
              :aria-label="phone.t('ControlCenter.timer')"
              @click="openTimer"
            >
              <SkyIcon :icon="TimerReset" aria-hidden="true" />
            </SkyButton>
            <span>{{ phone.t('ControlCenter.timer') }}</span>
          </div>
          <div class="control-center__quick-action">
            <SkyButton
              glass
              inline
              component="button"
              type="button"
              class="control-center__quick-button"
              :aria-label="phone.t('ControlCenter.camera')"
              @click="openApp('/apps/camera')"
            >
              <SkyIcon :icon="Camera" aria-hidden="true" />
            </SkyButton>
            <span>{{ phone.t('ControlCenter.camera') }}</span>
          </div>
          <div class="control-center__quick-action">
            <SkyButton
              glass
              inline
              component="button"
              type="button"
              class="control-center__quick-button"
              :aria-label="phone.t('ControlCenter.calculator')"
              @click="openApp('/apps/calculator')"
            >
              <SkyIcon :icon="Calculator" aria-hidden="true" />
            </SkyButton>
            <span>{{ phone.t('ControlCenter.calculator') }}</span>
          </div>
        </nav>
      </div>

      <div
        v-if="sliderDragActive"
        class="control-center__slider-drag-surface"
        aria-hidden="true"
        @mousemove="continueSliderSurfaceDrag"
        @mouseup="finishSliderSurfaceDrag"
        @pointermove="continueSliderSurfaceDrag"
        @pointerup="finishSliderSurfaceDrag"
      ></div>
    </section>
  </Transition>
</template>

<style scoped>
.control-center {
  --sky-glass-background: rgba(58, 62, 72, 0.6);
  --sky-glass-fallback: rgba(48, 52, 62, 0.9);
  --sky-button-glass-background: rgba(58, 62, 72, 0.6);
  --sky-button-glass-fallback: rgba(48, 52, 62, 0.9);
}
.control-center__focus-button--active {
  --sky-glass-background: #5e5ce6;
  --sky-glass-fallback: #5e5ce6;
  --sky-button-glass-background: #5e5ce6;
  --sky-button-glass-fallback: #5e5ce6;
}
.control-center__round-button--light,
.control-center__quick-button--flashlight-active {
  --sky-glass-background: #fff;
  --sky-glass-fallback: #fff;
  --sky-button-glass-background: #fff;
  --sky-button-glass-fallback: #fff;
  --sky-button-text: #17171c;
}

.control-center {
  position: absolute;
  z-index: 95;
  inset: 0;
  overflow: hidden;
  color: #fff;
  isolation: isolate;
}

.control-center__backdrop {
  position: absolute;
  z-index: 0;
  inset: 0;
  width: 100%;
  height: 100%;
  border: 0;
  background:
    radial-gradient(circle at 16% 12%, rgb(77 96 135 / 24%), transparent 46%),
    linear-gradient(180deg, #191b23 0%, #11131a 100%);
}

@supports (
  (backdrop-filter: blur(1px)) or (-webkit-backdrop-filter: blur(1px))
) {
  .control-center__backdrop {
    background:
      radial-gradient(circle at 16% 12%, rgb(77 96 135 / 14%), transparent 46%),
      linear-gradient(180deg, rgb(20 22 29 / 72%) 0%, rgb(13 15 21 / 86%) 100%);
    backdrop-filter: blur(32px) brightness(0.76) saturate(0.82);
    -webkit-backdrop-filter: blur(32px) brightness(0.76) saturate(0.82);
  }
}

.control-center__panel {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  gap: 12px;
  width: 100%;
  height: 100%;
  padding: 70px 18px 30px;
  outline: none;
  pointer-events: none;
  transform-origin: calc(100% - 38px) 18px;
}

.control-center__slider-drag-surface {
  position: absolute;
  z-index: 20;
  inset: 0;
  cursor: ns-resize;
  pointer-events: auto;
  touch-action: none;
}

.control-center__top-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
  pointer-events: auto;
}

.control-center__connectivity,
.control-center__media {
  min-width: 0;
  height: 154px;
  border-radius: 34px;
}

.control-center__connectivity {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  grid-template-rows: repeat(2, 1fr);
  gap: 10px;
  padding: 12px;
}

.control-center__connectivity-button {
  display: flex;
  align-items: center;
  justify-content: center;
  min-width: 0;
  border: 0;
  border-radius: 50%;
  color: #fff;
  background: rgba(72, 72, 74, 0.64);
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.14),
    0 2px 5px rgba(0, 0, 0, 0.28);
  transition:
    background 180ms ease,
    box-shadow 180ms ease,
    transform 160ms ease;
}

.control-center__connectivity-button--airplane {
  background: #ff9f0a;
}

.control-center__connectivity-button--cellular {
  background: #34c759;
}

.control-center__connectivity-button--wifi,
.control-center__connectivity-button--bluetooth {
  background: #0a84ff;
}

.control-center__connectivity-button:active,
.control-center__round-button:active,
.control-center__quick-button:active {
  transform: scale(0.92);
}

.control-center__connectivity-button svg {
  width: 27px;
  height: 27px;
  stroke-width: 2.3;
}

.control-center__connectivity-button:first-child svg {
  fill: currentcolor;
  stroke-width: 1.5;
}

.control-center__media {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  padding: 21px 18px 17px;
}

.control-center__media-copy {
  display: flex;
  flex-direction: column;
  gap: 3px;
  min-width: 0;
}

.control-center__media-copy span {
  color: rgba(255, 255, 255, 0.66);
  font-size: 11px;
  font-weight: 600;
}

.control-center__media-copy strong {
  overflow: hidden;
  font-size: 17px;
  line-height: 1.2;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.control-center__media-controls {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.control-center__media-controls button {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 38px;
  height: 38px;
  padding: 0;
  border: 0;
  color: rgba(255, 255, 255, 0.88);
  background: transparent;
}

.control-center__media-controls button:nth-child(2) svg {
  width: 31px;
  height: 31px;
  fill: currentcolor;
}

.control-center__media-controls svg {
  width: 25px;
  height: 25px;
  fill: currentcolor;
}

.control-center__middle-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  grid-template-rows: repeat(2, 73px);
  gap: 10px;
  min-height: 156px;
  pointer-events: auto;
}

.control-center__round-control,
.control-center__quick-action {
  display: flex;
  min-width: 0;
  flex-direction: column;
  align-items: center;
  gap: 7px;
}

.control-center__round-control {
  justify-content: center;
}

.control-center__round-control > span,
.control-center__quick-action > span {
  width: 100%;
  overflow: hidden;
  color: rgba(255, 255, 255, 0.82);
  font-size: 10px;
  font-weight: 600;
  line-height: 1.15;
  text-align: center;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.control-center__round-button {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 73px;
  height: 73px;
  border: 0;
  border-radius: 50%;
  color: #fff;
  transition: transform 160ms ease;
}

.control-center__round-button--light {
  color: var(--sky-button-text, #ffffff);
}

.control-center__focus-button {
  display: flex;
  grid-column: 1 / span 2;
  grid-row: 2;
  align-items: center;
  gap: 13px;
  min-width: 0;
  height: 73px;
  padding: 0 22px;
  border: 0;
  border-radius: 37px;
  color: #fff;
  font-size: 15px;
  font-weight: 650;
  transition: transform 160ms ease;
}

.control-center__focus-button:active {
  transform: scale(0.96);
}

.control-center__focus-button svg {
  width: 27px;
  height: 27px;
  fill: currentcolor;
}

.control-center__round-button svg,
.control-center__quick-button svg {
  width: 27px;
  height: 27px;
  stroke-width: 2;
}

.control-center__slider {
  position: relative;
  grid-row: 1 / span 2;
  height: 156px;
  overflow: hidden;
  border-radius: 38px;
  cursor: pointer;
  touch-action: none;
}

.control-center__slider--brightness {
  grid-column: 3;
}

.control-center__slider--volume {
  grid-column: 4;
}

.control-center__slider-level {
  position: absolute;
  z-index: 0;
  right: 0;
  bottom: 0;
  left: 0;
  height: var(--control-level);
  background: rgba(255, 255, 255, 0.96);
  transition: height 160ms cubic-bezier(0.2, 0.8, 0.2, 1);
  will-change: height;
}

.control-center--slider-dragging .control-center__slider-level {
  transition: none;
}

.control-center__range {
  position: absolute;
  z-index: 2;
  top: 50%;
  left: 50%;
  width: 172px;
  height: 58px !important;
  transform: translate(-50%, -50%) rotate(-90deg);
  pointer-events: none;
}

.control-center__range :deep(span) {
  opacity: 0;
}

.control-center__range :deep(input) {
  height: 58px !important;
}

.control-center__range :deep(input::-webkit-slider-thumb) {
  opacity: 0;
}

.control-center__range :deep(input::-moz-range-thumb) {
  opacity: 0;
}

.control-center__slider-icon {
  position: absolute;
  z-index: 3;
  bottom: 18px;
  left: 50%;
  width: 25px;
  height: 25px;
  color: #0a84ff;
  transform: translateX(-50%);
  pointer-events: none;
}

.control-center__quick-button.control-center__quick-button--flashlight-active {
  color: var(--sky-button-text, #ffffff) !important;
}

.control-center__slider--brightness .control-center__slider-icon {
  color: #ffd60a;
}

.control-center__quick-actions {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 10px;
  pointer-events: auto;
}

.control-center__quick-button {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 73px;
  height: 73px;
  border: 0;
  border-radius: 50%;
  color: #fff;
  transition: transform 160ms ease;
}

.control-center__quick-button:disabled {
  opacity: 0.72;
}

.control-center-enter-active,
.control-center-leave-active {
  transition: opacity 280ms ease;
}

.control-center-enter-active .control-center__panel {
  transition: transform 440ms cubic-bezier(0.16, 1, 0.3, 1);
}

.control-center-leave-active .control-center__panel {
  transition: transform 260ms cubic-bezier(0.7, 0, 0.84, 0);
}

.control-center-enter-from,
.control-center-leave-to {
  opacity: 0;
}

.control-center-enter-from .control-center__panel,
.control-center-leave-to .control-center__panel {
  transform: translate3d(28px, -22px, 0) scale(0.84);
}

@media (prefers-reduced-motion: reduce) {
  .control-center-enter-active,
  .control-center-leave-active,
  .control-center-enter-active .control-center__panel,
  .control-center-leave-active .control-center__panel,
  .control-center__connectivity-button,
  .control-center__round-button,
  .control-center__focus-button,
  .control-center__quick-button {
    transition-duration: 1ms;
  }
}
</style>
