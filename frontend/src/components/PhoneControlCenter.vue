<script setup lang="ts">
import { kGlass, kRange } from 'konsta/vue'
import {
  BellOff,
  Bluetooth,
  Calculator,
  Camera,
  Flashlight,
  LockKeyhole,
  Moon,
  Plane,
  Play,
  RotateCw,
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
import { nuiCall } from '@/utils/nui'

const props = defineProps<{ opened: boolean }>()
const emit = defineEmits<{ close: [] }>()

type ConnectivityPreference =
  | 'airplaneMode'
  | 'bluetoothEnabled'
  | 'cellularEnabled'
  | 'focusMode'
  | 'rotationLocked'
  | 'wifiEnabled'

const phone = usePhoneStore()
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
const previousAlertVolume = ref(volume.value || 75)

const inactiveGlassColors = {
  bgIos: 'bg-[rgba(72,72,74,0.58)]',
  shadowIos: 'shadow-ios-dark-glass',
}
const rotationColors = computed(() =>
  phone.preferences.settings.rotationLocked
    ? {
        bgIos: 'bg-white',
        shadowIos: 'shadow-ios-light-glass',
      }
    : inactiveGlassColors,
)
const focusColors = computed(() =>
  phone.preferences.settings.focusMode
    ? {
        bgIos: 'bg-[#5e5ce6]',
        shadowIos: 'shadow-ios-dark-glass',
      }
    : inactiveGlassColors,
)
const alertsMuted = computed(() => volume.value === 0)
const alertMuteColors = computed(() =>
  alertsMuted.value
    ? {
        bgIos: 'bg-white',
        shadowIos: 'shadow-ios-light-glass',
      }
    : inactiveGlassColors,
)
const flashlightColors = computed(() =>
  flashlightActive.value
    ? {
        bgIos: 'bg-white',
        shadowIos: 'shadow-ios-light-glass',
      }
    : inactiveGlassColors,
)
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

function pointerRangeValue(
  event: PointerEvent,
  minimum: number,
  maximum: number,
): number {
  const rect = (event.currentTarget as HTMLElement).getBoundingClientRect()
  const ratio =
    1 - Math.min(1, Math.max(0, (event.clientY - rect.top) / rect.height))
  return Math.round(minimum + ratio * (maximum - minimum))
}

function startBrightnessDrag(event: PointerEvent): void {
  ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
  const nextValue = pointerRangeValue(event, 10, 100)
  brightness.value = nextValue
  phone.preferences.settings.screenBrightness = nextValue
}

function dragBrightness(event: PointerEvent): void {
  if (!(event.currentTarget as HTMLElement).hasPointerCapture(event.pointerId))
    return
  const nextValue = pointerRangeValue(event, 10, 100)
  brightness.value = nextValue
  phone.preferences.settings.screenBrightness = nextValue
}

function finishBrightnessDrag(event: PointerEvent): void {
  const target = event.currentTarget as HTMLElement
  if (!target.hasPointerCapture(event.pointerId)) return
  const nextValue = pointerRangeValue(event, 10, 100)
  brightness.value = nextValue
  phone.setPreference('screenBrightness', nextValue)
  target.releasePointerCapture(event.pointerId)
}

function startVolumeDrag(event: PointerEvent): void {
  ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
  volume.value = pointerRangeValue(event, 0, 100)
}

function dragVolume(event: PointerEvent): void {
  if (!(event.currentTarget as HTMLElement).hasPointerCapture(event.pointerId))
    return
  volume.value = pointerRangeValue(event, 0, 100)
}

function finishVolumeDrag(event: PointerEvent): void {
  const target = event.currentTarget as HTMLElement
  if (!target.hasPointerCapture(event.pointerId)) return
  volume.value = pointerRangeValue(event, 0, 100)
  if (volume.value > 0) previousAlertVolume.value = volume.value
  phone.setAlertVolumes(volume.value)
  target.releasePointerCapture(event.pointerId)
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
    if (!opened) return
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
  if (flashlightActive.value)
    void nuiCall('camera:setFlash', { enabled: false })
})
</script>

<template>
  <Transition name="control-center">
    <section
      v-if="opened"
      class="control-center"
      role="dialog"
      aria-modal="true"
      :aria-label="phone.t('ControlCenter.label')"
    >
      <button
        class="control-center__backdrop"
        type="button"
        tabindex="-1"
        :aria-label="phone.t('ControlCenter.close')"
        @click="emit('close')"
      ></button>

      <div ref="panel" class="control-center__panel" tabindex="-1">
        <div class="control-center__top-grid">
          <k-glass
            class="control-center__connectivity"
            :colors="inactiveGlassColors"
            :highlight="false"
          >
            <button
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
              <Plane aria-hidden="true" />
            </button>
            <button
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
              <Signal aria-hidden="true" />
            </button>
            <button
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
              <Wifi aria-hidden="true" />
            </button>
            <button
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
              <Bluetooth aria-hidden="true" />
            </button>
          </k-glass>

          <k-glass
            class="control-center__media"
            :colors="inactiveGlassColors"
            :highlight="false"
          >
            <div class="control-center__media-copy">
              <span>{{ phone.t('ControlCenter.media') }}</span>
              <strong>{{ phone.t('ControlCenter.notPlaying') }}</strong>
            </div>
            <div class="control-center__media-controls">
              <button
                type="button"
                disabled
                :aria-label="phone.t('ControlCenter.previous')"
              >
                <SkipBack aria-hidden="true" />
              </button>
              <button
                type="button"
                disabled
                :aria-label="phone.t('ControlCenter.play')"
              >
                <Play aria-hidden="true" />
              </button>
              <button
                type="button"
                disabled
                :aria-label="phone.t('ControlCenter.next')"
              >
                <SkipForward aria-hidden="true" />
              </button>
            </div>
          </k-glass>
        </div>

        <div class="control-center__middle-grid">
          <div class="control-center__round-control">
            <k-glass
              component="button"
              type="button"
              class="control-center__round-button"
              :class="{
                'control-center__round-button--light':
                  phone.preferences.settings.rotationLocked,
              }"
              :colors="rotationColors"
              :aria-label="phone.t('ControlCenter.rotationLock')"
              :aria-pressed="phone.preferences.settings.rotationLocked"
              @click="togglePreference('rotationLocked')"
            >
              <RotateCw aria-hidden="true" />
              <LockKeyhole
                class="control-center__rotation-lock"
                aria-hidden="true"
              />
            </k-glass>
          </div>

          <div class="control-center__round-control">
            <k-glass
              component="button"
              type="button"
              class="control-center__round-button"
              :class="{
                'control-center__round-button--light': alertsMuted,
              }"
              :colors="alertMuteColors"
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
              <BellOff aria-hidden="true" />
            </k-glass>
          </div>

          <k-glass
            class="control-center__slider"
            :colors="inactiveGlassColors"
            :highlight="false"
            :style="brightnessStyle"
            @pointerdown="startBrightnessDrag"
            @pointermove="dragBrightness"
            @pointerup="finishBrightnessDrag"
            @pointercancel="finishBrightnessDrag"
          >
            <span
              class="control-center__slider-level"
              aria-hidden="true"
            ></span>
            <k-range
              class="control-center__range"
              :value="brightness"
              :min="10"
              :max="100"
              :aria-label="phone.t('ControlCenter.brightness')"
              @input="updateBrightness"
              @change="saveBrightness"
            />
            <Sun
              class="control-center__slider-icon"
              fill="currentColor"
              aria-hidden="true"
            />
          </k-glass>

          <k-glass
            class="control-center__slider"
            :colors="inactiveGlassColors"
            :highlight="false"
            :style="volumeStyle"
            @pointerdown="startVolumeDrag"
            @pointermove="dragVolume"
            @pointerup="finishVolumeDrag"
            @pointercancel="finishVolumeDrag"
          >
            <span
              class="control-center__slider-level"
              aria-hidden="true"
            ></span>
            <k-range
              class="control-center__range"
              :value="volume"
              :min="0"
              :max="100"
              :aria-label="phone.t('ControlCenter.volume')"
              @input="updateVolume"
              @change="saveVolume"
            />
            <Volume2
              class="control-center__slider-icon"
              fill="currentColor"
              aria-hidden="true"
            />
          </k-glass>

          <k-glass
            component="button"
            type="button"
            class="control-center__focus-button"
            :colors="focusColors"
            :aria-label="phone.t('ControlCenter.focus')"
            :aria-pressed="phone.preferences.settings.focusMode"
            @click="togglePreference('focusMode')"
          >
            <Moon aria-hidden="true" />
            <span>{{ phone.t('ControlCenter.focus') }}</span>
          </k-glass>
        </div>

        <nav
          class="control-center__quick-actions"
          :aria-label="phone.t('ControlCenter.quickActions')"
        >
          <div class="control-center__quick-action">
            <k-glass
              component="button"
              type="button"
              class="control-center__quick-button"
              :class="{
                'control-center__quick-button--flashlight-active':
                  flashlightActive,
              }"
              :colors="flashlightColors"
              :disabled="flashlightPending"
              :aria-label="phone.t('ControlCenter.flashlight')"
              :aria-pressed="flashlightActive"
              @click="toggleFlashlight"
            >
              <Flashlight aria-hidden="true" />
            </k-glass>
            <span>{{ phone.t('ControlCenter.flashlight') }}</span>
          </div>
          <div class="control-center__quick-action">
            <k-glass
              component="button"
              type="button"
              class="control-center__quick-button"
              :colors="inactiveGlassColors"
              :aria-label="phone.t('ControlCenter.timer')"
              @click="openTimer"
            >
              <TimerReset aria-hidden="true" />
            </k-glass>
            <span>{{ phone.t('ControlCenter.timer') }}</span>
          </div>
          <div class="control-center__quick-action">
            <k-glass
              component="button"
              type="button"
              class="control-center__quick-button"
              :colors="inactiveGlassColors"
              :aria-label="phone.t('ControlCenter.camera')"
              @click="openApp('/apps/camera')"
            >
              <Camera aria-hidden="true" />
            </k-glass>
            <span>{{ phone.t('ControlCenter.camera') }}</span>
          </div>
          <div class="control-center__quick-action">
            <k-glass
              component="button"
              type="button"
              class="control-center__quick-button"
              :colors="inactiveGlassColors"
              :aria-label="phone.t('ControlCenter.calculator')"
              @click="openApp('/apps/calculator')"
            >
              <Calculator aria-hidden="true" />
            </k-glass>
            <span>{{ phone.t('ControlCenter.calculator') }}</span>
          </div>
        </nav>
      </div>
    </section>
  </Transition>
</template>

<style scoped>
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
  z-index: -1;
  inset: 0;
  width: 100%;
  height: 100%;
  border: 0;
  background: rgba(20, 20, 24, 0.34);
  backdrop-filter: blur(25px) saturate(1.45);
  -webkit-backdrop-filter: blur(25px) saturate(1.45);
}

.control-center__panel {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 12px;
  width: 100%;
  height: 100%;
  padding: 62px 18px 30px;
  outline: none;
  pointer-events: none;
  transform-origin: calc(100% - 38px) 18px;
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
  color: #ff453a;
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

.control-center__round-button .control-center__rotation-lock {
  position: absolute;
  width: 13px;
  height: 13px;
  stroke-width: 2.5;
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

.control-center__slider-level {
  position: absolute;
  z-index: 0;
  right: 0;
  bottom: 0;
  left: 0;
  height: var(--control-level);
  background: rgba(255, 255, 255, 0.96);
  transition: height 80ms linear;
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
  color: #bf5af2 !important;
}

.control-center__slider:nth-child(3) .control-center__slider-icon {
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
