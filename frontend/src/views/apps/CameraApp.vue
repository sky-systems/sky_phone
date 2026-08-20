<script setup lang="ts">
import { SkyAppPage, SkyButton, SkyFab, SkyGlass } from '@/ui'
import {
  ArrowLeft,
  Images,
  LockKeyhole,
  LockOpen,
  Mic,
  MicOff,
  RefreshCw,
  RotateCcwSquare,
  Video,
  Zap,
  ZapOff,
} from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { useMessageMediaStore } from '@/stores/messageMedia'
import { usePhoneStore } from '@/stores/phone'
import type {
  MediaConfig,
  MediaType,
  PhoneMedia,
  UploadResult,
} from '@/types/media'
import { SkySegmented, SkySegmentedButton } from '@/ui'
import { createGameView, type GameView } from '@/utils/gameView'
import { formatRecordingDuration, mediaErrorKey } from '@/utils/media'
import { nuiCall } from '@/utils/nui'
import { isTrustedRootMessageSource } from '@/utils/windowMessages'

type CaptureItem = {
  error?: string
  id: string
  mediaType: MediaType
  status: 'uploading' | 'success' | 'error'
}

const isDevelopment = import.meta.env.DEV
const zoomLevels = [0.5, 1, 2, 3] as const
const minimumZoom = zoomLevels[0]
const maximumZoom = zoomLevels[zoomLevels.length - 1]
const phone = usePhoneStore()
const messageMedia = useMessageMediaStore()
const route = useRoute()
const router = useRouter()
const requestedMessageMedia = computed<MediaType | null>(() => {
  const value = route.query.mediaAttachment ?? route.query.messageAttachment
  return value === 'photo' || value === 'video' ? value : null
})
const mode = ref<MediaType>(requestedMessageMedia.value ?? 'photo')
const selectedZoom = ref(1)
const flashEnabled = ref(false)
const microphoneEnabled = ref(true)
const frontCamera = ref(false)
const shutterActive = ref(false)
const cameraLocked = ref(false)
const movementEnabled = ref(false)
const recording = ref(false)
const savingVideo = ref(false)
const recordingStartedAt = ref(0)
const elapsed = ref('00:00')
const captures = ref<CaptureItem[]>([])
const latestMedia = ref<PhoneMedia | null>(null)
const gameCanvas = ref<HTMLCanvasElement | null>(null)
const gameViewUnavailable = ref(false)
const noticeText = ref('')
const videoBitrateKbps = ref(1500)
let shutterTimer: number | undefined
let noticeTimer: number | undefined
let recordingTimer: number | undefined
let gameView: GameView | null = null
let renderFrameId: number | undefined
let resizeObserver: ResizeObserver | null = null

const pendingCount = computed(
  () =>
    captures.value.filter((capture) => capture.status === 'uploading').length,
)
function correlationId(): string {
  return `${Date.now()}-${crypto.randomUUID()}`
}

function showCameraNotice(text: string): void {
  if (noticeTimer !== undefined) window.clearTimeout(noticeTimer)
  noticeText.value = text
  noticeTimer = window.setTimeout(() => {
    noticeText.value = ''
  }, 3000)
}

function updateCapture(id: string, updates: Partial<CaptureItem>): void {
  const index = captures.value.findIndex((capture) => capture.id === id)
  if (index < 0) return
  captures.value[index] = { ...captures.value[index], ...updates }
}

function queueCapture(id: string, mediaType: MediaType): void {
  captures.value.unshift({ id, mediaType, status: 'uploading' })
  captures.value = captures.value.slice(0, 6)
}

async function completeDevelopmentCapture(
  correlationId: string,
  mediaType: MediaType,
): Promise<void> {
  const response = await nuiCall<PhoneMedia>('media:devCapture', { mediaType })
  window.dispatchEvent(
    new MessageEvent('message', {
      data: {
        data: {
          correlationId,
          error: response.error,
          media: response.data,
          success: response.success,
        },
        type: 'media:uploadResult',
      },
    }),
  )
}

async function requestPhoto(): Promise<void> {
  if (recording.value || savingVideo.value) return
  const id = correlationId()
  queueCapture(id, 'photo')
  shutterActive.value = true
  if (shutterTimer !== undefined) window.clearTimeout(shutterTimer)
  shutterTimer = window.setTimeout(() => {
    shutterActive.value = false
  }, 280)
  if (isDevelopment) {
    window.setTimeout(() => void completeDevelopmentCapture(id, 'photo'), 700)
    return
  }
  await nuiCall('media:requestUpload', {
    correlationId: id,
    mediaType: 'photo',
  })
}

function startRecording(): void {
  if (savingVideo.value) return
  if (isDevelopment) {
    recording.value = true
    recordingStartedAt.value = Date.now()
    updateRecordingTimer()
    if (recordingTimer !== undefined) window.clearInterval(recordingTimer)
    recordingTimer = window.setInterval(updateRecordingTimer, 250)
    return
  }
  window.postMessage(
    {
      data: {
        bitrateKbps: videoBitrateKbps.value,
        microphoneEnabled: microphoneEnabled.value,
      },
      type: 'camera:recordStart',
    },
    '*',
  )
}

function toggleMicrophone(): void {
  if (recording.value || savingVideo.value) return
  microphoneEnabled.value = !microphoneEnabled.value
}

function stopRecording(): void {
  if (!recording.value || savingVideo.value) return
  const id = correlationId()
  queueCapture(id, 'video')
  if (isDevelopment) {
    recording.value = false
    savingVideo.value = true
    if (recordingTimer !== undefined) window.clearInterval(recordingTimer)
    recordingTimer = undefined
    window.setTimeout(() => void completeDevelopmentCapture(id, 'video'), 900)
    return
  }
  window.postMessage(
    { data: { correlationId: id }, type: 'camera:recordStop' },
    '*',
  )
}

function capture(): void {
  if (mode.value === 'video') {
    if (recording.value) {
      stopRecording()
    } else {
      startRecording()
    }
    return
  }
  void requestPhoto()
}

function cancelMediaSelection(): void {
  void router.replace(messageMedia.cancel())
}

function setMode(nextMode: MediaType): void {
  if (recording.value || savingVideo.value) return
  mode.value = nextMode
}

async function toggleFlash(): Promise<void> {
  flashEnabled.value = !flashEnabled.value
  await nuiCall('camera:setFlash', { enabled: flashEnabled.value })
}

async function toggleFacing(): Promise<void> {
  frontCamera.value = !frontCamera.value
  await nuiCall('camera:setFacing', { front: frontCamera.value })
}

async function toggleCameraLock(): Promise<void> {
  cameraLocked.value = !cameraLocked.value
  if (cameraLocked.value && movementEnabled.value) {
    movementEnabled.value = false
    await nuiCall('camera:setFocus', { focused: true })
  }
  await nuiCall('camera:setLocked', { locked: cameraLocked.value })
}

function toggleOrientation(): void {
  if (recording.value || savingVideo.value) return
  phone.setCameraLandscape(!phone.cameraLandscape)
  window.postMessage(
    {
      data: { landscape: phone.cameraLandscape },
      type: 'camera:orientation',
    },
    '*',
  )
  void nuiCall('camera:setOrientation', {
    landscape: phone.cameraLandscape,
  })
}

function setZoom(zoom: number): void {
  const normalizedZoom = Math.min(
    maximumZoom,
    Math.max(minimumZoom, Math.round(zoom * 100) / 100),
  )
  if (normalizedZoom === selectedZoom.value) return
  selectedZoom.value = normalizedZoom
  resizeGameView()
  window.postMessage(
    { data: { zoom: normalizedZoom }, type: 'camera:zoom' },
    '*',
  )
  void nuiCall('camera:setZoom', { zoom: normalizedZoom })
}

function zoomWithWheel(event: WheelEvent): void {
  const deltaMultiplier =
    event.deltaMode === WheelEvent.DOM_DELTA_LINE
      ? 16
      : event.deltaMode === WheelEvent.DOM_DELTA_PAGE
        ? window.innerHeight
        : 1
  const wheelDelta = Math.max(
    -120,
    Math.min(120, event.deltaY * deltaMultiplier),
  )
  setZoom(selectedZoom.value - wheelDelta * 0.00075)
}

function resizeGameView(entry?: ResizeObserverEntry): void {
  if (!gameCanvas.value || !gameView) return
  const width = entry?.contentRect.width ?? gameCanvas.value.offsetWidth
  const height = entry?.contentRect.height ?? gameCanvas.value.offsetHeight
  const renderScale = Math.min(window.devicePixelRatio, 2)
  gameView.resize(
    Math.max(1, Math.round(width * renderScale)),
    Math.max(1, Math.round(height * renderScale)),
    window.innerWidth,
    window.innerHeight,
    selectedZoom.value,
  )
}

function startGameView(): void {
  if (isDevelopment || !gameCanvas.value) return
  try {
    gameView = createGameView(gameCanvas.value, {
      onContextRestored: () => {
        resizeGameView()
        startGameViewRenderLoop()
      },
    })
  } catch (error) {
    gameViewUnavailable.value = true
    console.error('[Camera] Game-view rendering is unavailable.', error)
    return
  }
  resizeObserver = new ResizeObserver((entries) => resizeGameView(entries[0]))
  resizeObserver.observe(gameCanvas.value)
  resizeGameView()
  startGameViewRenderLoop()
}

function startGameViewRenderLoop(): void {
  if (renderFrameId !== undefined) return
  const render = () => {
    if (!gameView || gameView.isLost()) {
      renderFrameId = undefined
      return
    }
    gameView.render()
    renderFrameId = window.requestAnimationFrame(render)
  }
  renderFrameId = window.requestAnimationFrame(render)
}

function updateRecordingTimer(): void {
  elapsed.value = formatRecordingDuration(Date.now() - recordingStartedAt.value)
}

function onKeydown(event: KeyboardEvent): void {
  if (
    event.code !== 'Space' ||
    event.repeat ||
    cameraLocked.value ||
    movementEnabled.value
  )
    return
  event.preventDefault()
  movementEnabled.value = true
  void nuiCall('camera:setFocus', { focused: false })
}

function onKeyup(event: KeyboardEvent): void {
  if (event.code !== 'Space' || !movementEnabled.value) return
  event.preventDefault()
  movementEnabled.value = false
  void nuiCall('camera:setFocus', { focused: true })
}

function onMessage(event: MessageEvent): void {
  if (!isTrustedRootMessageSource(event.source, window)) return
  const message = event.data as {
    data?: Record<string, unknown>
    type?: string
  }
  if (message.type === 'camera:zoom') {
    const zoom = Number(message.data?.zoom)
    if (Number.isFinite(zoom) && zoom >= minimumZoom && zoom <= maximumZoom) {
      selectedZoom.value = zoom
      resizeGameView()
    }
  } else if (message.type === 'camera:recordState') {
    const active = message.data?.active === true
    savingVideo.value = message.data?.saving === true
    recording.value = active
    if (active) {
      recordingStartedAt.value = Date.now()
      updateRecordingTimer()
      if (recordingTimer !== undefined) window.clearInterval(recordingTimer)
      recordingTimer = window.setInterval(updateRecordingTimer, 250)
    } else if (recordingTimer !== undefined) {
      window.clearInterval(recordingTimer)
      recordingTimer = undefined
    }
  } else if (message.type === 'camera:recordError') {
    showCameraNotice(
      phone.t(
        `Apps.camera.errors.${mediaErrorKey(String(message.data?.error ?? ''))}`,
      ),
    )
  } else if (message.type === 'media:uploadResult') {
    const result = message.data as UploadResult
    if (!result?.correlationId) return
    savingVideo.value = false
    if (result.success && result.media) {
      latestMedia.value = result.media
      updateCapture(result.correlationId, { status: 'success' })
      if (requestedMessageMedia.value === result.media.mediaType) {
        const returnPath = messageMedia.complete(result.media)
        if (returnPath) void router.replace(returnPath)
        return
      }
      showCameraNotice(phone.t('Apps.camera.saved'))
      window.setTimeout(() => {
        captures.value = captures.value.filter(
          (captureItem) => captureItem.id !== result.correlationId,
        )
      }, 2500)
    } else {
      const error = mediaErrorKey(result.error)
      updateCapture(result.correlationId, { error, status: 'error' })
      showCameraNotice(phone.t(`Apps.camera.errors.${error}`))
    }
  }
}

async function loadLatest(): Promise<void> {
  const response = await nuiCall<PhoneMedia[]>('gallery:list', {
    limit: 1,
    offset: 0,
  })
  if (response.success && response.data?.[0])
    latestMedia.value = response.data[0]
}

onMounted(() => {
  phone.setCameraLandscape(false)
  window.postMessage(
    { data: { landscape: false }, type: 'camera:orientation' },
    '*',
  )
  void nuiCall('camera:setOrientation', { landscape: false })
  window.postMessage(
    { data: { zoom: selectedZoom.value }, type: 'camera:zoom' },
    '*',
  )
  window.addEventListener('keydown', onKeydown)
  window.addEventListener('keyup', onKeyup)
  window.addEventListener('message', onMessage)
  void nuiCall('camera:setActive', { active: true })
  void nuiCall<MediaConfig>('media:config').then((response) => {
    if (response.success && response.data?.videoBitrateKbps) {
      videoBitrateKbps.value = response.data.videoBitrateKbps
    }
  })
  void loadLatest()
  startGameView()
})

onBeforeUnmount(() => {
  if (shutterTimer !== undefined) window.clearTimeout(shutterTimer)
  if (noticeTimer !== undefined) window.clearTimeout(noticeTimer)
  if (recordingTimer !== undefined) window.clearInterval(recordingTimer)
  window.removeEventListener('keydown', onKeydown)
  window.removeEventListener('keyup', onKeyup)
  window.removeEventListener('message', onMessage)
  if (movementEnabled.value) {
    movementEnabled.value = false
    void nuiCall('camera:setFocus', { focused: true })
  }
  if (renderFrameId !== undefined) window.cancelAnimationFrame(renderFrameId)
  resizeObserver?.disconnect()
  gameView?.dispose()
  phone.setCameraLandscape(false)
  window.postMessage(
    { data: { landscape: false }, type: 'camera:orientation' },
    '*',
  )
  window.postMessage({ type: 'camera:recordCancel' }, '*')
  void nuiCall('camera:setOrientation', { landscape: false })
  void nuiCall('camera:setFlash', { enabled: false })
  void nuiCall('camera:setActive', { active: false })
})
</script>

<template>
  <sky-app-page
    class="camera-page"
    :class="{ 'camera-page--landscape': phone.cameraLandscape }"
    :aria-label="phone.t('Apps.camera.name')"
  >
    <div class="camera-viewport" @wheel.prevent.stop="zoomWithWheel">
      <canvas
        v-if="!isDevelopment && !gameViewUnavailable"
        ref="gameCanvas"
        class="camera-game-view"
        aria-hidden="true"
      ></canvas>
      <div
        v-else
        class="camera-dev-view"
        :style="{ transform: `scale(${selectedZoom})` }"
        aria-hidden="true"
      >
        <span class="camera-dev-sun"></span>
        <span class="camera-dev-horizon"></span>
      </div>
      <div class="camera-shade"></div>
      <div class="camera-flash" :class="{ active: shutterActive }"></div>
    </div>

    <header class="camera-topbar">
      <div class="camera-topbar-actions">
        <sky-fab
          v-if="requestedMessageMedia"
          component="button"
          class="camera-control camera-picker-back"
          type="button"
          variant="glass"
          :aria-label="phone.t('Common.back')"
          @click="cancelMediaSelection"
        >
          <template #icon><ArrowLeft :size="20" /></template>
        </sky-fab>
        <sky-fab
          v-else
          component="button"
          type="button"
          class="camera-control"
          :class="{ 'camera-control--flash-active': flashEnabled }"
          variant="glass"
          :aria-label="phone.t('Apps.camera.flash')"
          @click="toggleFlash"
        >
          <template #icon>
            <Zap v-if="flashEnabled" :size="19" />
            <ZapOff v-else :size="19" />
          </template>
        </sky-fab>
        <sky-fab
          v-if="mode === 'video'"
          component="button"
          type="button"
          class="camera-control"
          :class="{ 'camera-control--danger': !microphoneEnabled }"
          variant="glass"
          :disabled="recording || savingVideo"
          :aria-label="
            phone.t(
              microphoneEnabled
                ? 'Apps.camera.microphoneOn'
                : 'Apps.camera.microphoneOff',
            )
          "
          :aria-pressed="microphoneEnabled"
          @click="toggleMicrophone"
        >
          <template #icon>
            <Mic v-if="microphoneEnabled" :size="19" />
            <MicOff v-else :size="19" />
          </template>
        </sky-fab>
      </div>
      <span
        v-if="noticeText"
        class="camera-focus-pill camera-focus-pill--notice"
      >
        {{ noticeText }}
      </span>
      <span v-else-if="pendingCount" class="camera-upload-pill">
        {{ phone.t('Apps.camera.uploading', { count: String(pendingCount) }) }}
      </span>
      <SkyButton
        v-else
        glass
        rounded
        class="camera-focus-pill camera-lock-control"
        :class="{ 'camera-lock-control--active': cameraLocked }"
        type="button"
        :aria-label="
          phone.t(
            cameraLocked
              ? 'Apps.camera.unlockCamera'
              : 'Apps.camera.lockCamera',
          )
        "
        :aria-pressed="cameraLocked"
        @click="toggleCameraLock"
      >
        <LockKeyhole v-if="cameraLocked" :size="12" />
        <LockOpen v-else :size="12" />
        <kbd>{{ phone.t('Apps.camera.spaceKey') }}</kbd>
      </SkyButton>
      <sky-fab
        component="button"
        type="button"
        class="camera-control"
        variant="glass"
        :disabled="recording || savingVideo"
        :aria-label="
          phone.t(
            phone.cameraLandscape
              ? 'Apps.camera.portrait'
              : 'Apps.camera.landscape',
          )
        "
        @click="toggleOrientation"
      >
        <template #icon><RotateCcwSquare :size="19" /></template>
      </sky-fab>
    </header>

    <div v-if="recording || savingVideo" class="camera-record-status">
      <span class="camera-record-dot"></span>
      {{ savingVideo ? phone.t('Apps.camera.saving') : elapsed }}
    </div>

    <div class="camera-zoom-control">
      <div class="camera-zoom-row">
        <SkyButton
          v-for="zoom in zoomLevels"
          :key="zoom"
          glass
          rounded
          class="camera-zoom-pill"
          :class="{ active: Math.abs(selectedZoom - zoom) < 0.03 }"
          type="button"
          :aria-label="phone.t('Apps.camera.zoom', { zoom: `${zoom}x` })"
          :aria-pressed="Math.abs(selectedZoom - zoom) < 0.03"
          @click="setZoom(zoom)"
        >
          {{ zoom }}x
        </SkyButton>
      </div>
    </div>

    <footer class="camera-controls">
      <div class="camera-capture-row">
        <sky-glass
          component="button"
          class="camera-latest"
          type="button"
          :aria-label="phone.t('Apps.camera.openGallery')"
          @click="
            router.push({
              path: '/apps/photos',
              query: requestedMessageMedia
                ? { mediaAttachment: requestedMessageMedia }
                : undefined,
            })
          "
        >
          <img
            v-if="latestMedia?.mediaType === 'photo'"
            :src="latestMedia.url"
            alt=""
          />
          <Video v-else-if="latestMedia" :size="22" />
          <Images v-else :size="22" />
        </sky-glass>

        <button
          class="camera-shutter"
          :class="{ recording, video: mode === 'video' }"
          type="button"
          :disabled="savingVideo"
          :aria-label="
            phone.t(
              mode === 'photo'
                ? 'Apps.camera.takePhoto'
                : recording
                  ? 'Apps.camera.stopRecording'
                  : 'Apps.camera.startRecording',
            )
          "
          @click="capture"
        >
          <span></span>
        </button>

        <sky-fab
          component="button"
          type="button"
          class="camera-control camera-selfie"
          variant="glass"
          :aria-label="phone.t('Apps.camera.flip')"
          @click="toggleFacing"
        >
          <template #icon><RefreshCw :size="20" /></template>
        </sky-fab>
      </div>

      <SkySegmented
        class="camera-mode-navbar"
        :active-index="mode === 'photo' ? 0 : 1"
        :aria-label="phone.t('Apps.camera.name')"
        :item-count="2"
        navigation
        compact
        strong
      >
        <SkySegmentedButton
          :active="mode === 'photo'"
          :disabled="recording || savingVideo"
          @click="setMode('photo')"
        >
          {{ phone.t('Apps.camera.photo') }}
        </SkySegmentedButton>
        <SkySegmentedButton
          :active="mode === 'video'"
          :disabled="recording || savingVideo"
          @click="setMode('video')"
        >
          {{ phone.t('Apps.camera.video') }}
        </SkySegmentedButton>
      </SkySegmented>
    </footer>
  </sky-app-page>
</template>

<style scoped>
.camera-page {
  position: relative;
  overflow: clip;
  background: #000;
  color: #fff;
}
.camera-viewport {
  position: absolute;
  top: 46%;
  left: 0;
  width: 100%;
  aspect-ratio: 3 / 4;
  overflow: hidden;
  transform: translateY(-50%);
}
.camera-page--landscape .camera-viewport {
  top: 46%;
  left: 50%;
  width: calc(100% * 16 / 9);
  height: auto;
  aspect-ratio: 16 / 9;
  transform: translate(-50%, -50%) rotate(90deg);
}
.camera-game-view,
.camera-dev-view,
.camera-shade,
.camera-flash {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
}
.camera-game-view {
  border: 0;
  object-fit: cover;
}
.camera-dev-view {
  inset: -50%;
  width: 200%;
  height: 200%;
  overflow: hidden;
  background: linear-gradient(#4a88ad 0 48%, #a88d68 49% 62%, #283528 63%);
  transform-origin: center;
  transition: transform 160ms ease;
}
.camera-dev-sun {
  position: absolute;
  top: 18%;
  right: 16%;
  width: 68px;
  height: 68px;
  border-radius: 50%;
  background: #fff3b0;
  box-shadow: 0 0 50px #ffd36a;
}
.camera-dev-horizon {
  position: absolute;
  left: -10%;
  right: -10%;
  bottom: 31%;
  height: 24%;
  background: #142b21;
  clip-path: polygon(
    0 100%,
    0 64%,
    18% 22%,
    34% 61%,
    54% 8%,
    73% 58%,
    88% 27%,
    100% 74%,
    100% 100%
  );
}
.camera-shade {
  pointer-events: none;
  background: linear-gradient(#0008, transparent 22%);
}
.camera-flash {
  z-index: 8;
  pointer-events: none;
  background: #fff;
  opacity: 0;
  transition: opacity 0.25s ease;
}
.camera-flash.active {
  opacity: 0.9;
  transition-duration: 0.04s;
}
.camera-topbar {
  position: absolute;
  z-index: 4;
  top: 52px;
  left: 18px;
  right: 18px;
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) 44px;
  align-items: center;
  gap: 8px;
}
.camera-topbar-actions {
  display: flex;
  gap: 8px;
}
.camera-topbar-spacer {
  min-width: 0;
}
.camera-topbar .camera-control {
  width: 44px;
  height: 44px;
}
.camera-control {
  --sky-glass: rgb(28 28 30 / 58%);
  --sky-hairline: rgb(255 255 255 / 16%);
  color: rgb(255 255 255 / 92%) !important;
}
.camera-control--flash-active {
  color: #ffd60a !important;
}
.camera-control--danger {
  color: #ff6961 !important;
}
.camera-picker-back {
  width: 44px;
  height: 44px;
}
.camera-control svg {
  width: 21px;
  height: 21px;
  transition: transform 0.25s ease;
}
.camera-latest svg {
  transition: transform 0.25s ease;
}
.camera-page--landscape .camera-control svg,
.camera-page--landscape .camera-latest svg {
  transform: rotate(90deg);
}
.camera-focus-pill:not(.sky-button--glass),
.camera-upload-pill {
  min-width: 0;
  padding: 7px 10px;
  overflow: hidden;
  border-radius: 999px;
  background: #0006;
  text-align: center;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 11px;
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
}
.camera-upload-pill {
  color: #ffd60a;
}
.camera-focus-pill--notice {
  color: #ffd60a;
}
.camera-lock-control {
  min-height: 44px;
  padding: 7px 10px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
  color: #fff;
  cursor: pointer;
}
.camera-lock-control--active {
  color: #ffd60a;
}
.camera-lock-control kbd {
  padding: 1px 5px;
  border: 1px solid rgb(255 255 255 / 24%);
  border-radius: 5px;
  background: rgb(255 255 255 / 10%);
  color: inherit;
  font: inherit;
  font-size: 9px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
.camera-record-status {
  position: absolute;
  z-index: 4;
  top: 108px;
  left: 50%;
  display: flex;
  align-items: center;
  gap: 7px;
  padding: 6px 10px;
  border-radius: 999px;
  background: #0009;
  transform: translateX(-50%);
  font-size: 12px;
  font-variant-numeric: tabular-nums;
}
.camera-record-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #ff3b30;
}
.camera-zoom-control {
  position: absolute;
  z-index: 4;
  bottom: 196px;
  left: 50%;
  width: auto;
  transform: translateX(-50%);
}
.camera-zoom-row {
  display: flex;
  justify-content: space-between;
  gap: 8px;
}
.camera-zoom-pill {
  width: 44px;
  min-width: 44px;
  height: 44px;
  min-height: 44px;
  padding: 0;
  color: #fff;
  font-size: 10px;
  text-align: center;
  transition:
    background-color 0.2s ease,
    color 0.2s ease,
    border-color 0.2s ease,
    box-shadow 0.2s ease;
}
.camera-zoom-pill.active {
  color: #ffd60a;
}
.camera-controls {
  position: absolute;
  z-index: 4;
  right: 0;
  bottom: 0;
  left: 0;
  display: flex;
  flex-direction: column;
  gap: 0;
  padding: 0;
}
.camera-capture-row {
  display: grid;
  grid-template-columns: 54px 1fr 54px;
  align-items: center;
  padding: 0 24px 32px;
}
.camera-latest {
  --sky-glass: rgb(28 28 30 / 58%);
  --sky-hairline: rgb(255 255 255 / 16%);
  width: 44px;
  height: 44px;
  overflow: hidden;
  border-radius: 50%;
  background: var(--sky-glass);
  color: #fff;
  display: grid;
  place-items: center;
  box-shadow: var(--sky-shadow-glass);
}
.camera-selfie {
  justify-self: end;
}
.camera-latest img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.camera-shutter {
  justify-self: center;
  width: 76px;
  height: 76px;
  padding: 4px;
  border: 3px solid #fff;
  border-radius: 50%;
  background: transparent;
}
.camera-shutter span {
  display: block;
  width: 100%;
  height: 100%;
  border-radius: 50%;
  background: #fff;
  transition: 0.18s ease;
}
.camera-shutter.video span {
  background: #ff3b30;
}
.camera-shutter.recording span {
  width: 48%;
  height: 48%;
  margin: 26%;
  border-radius: 6px;
}
.camera-shutter:disabled {
  opacity: 0.5;
}
.camera-mode-navbar {
  width: 54%;
  align-self: center;
  margin-bottom: 18px;
  transform: translateY(-16px);
}
.camera-mode-navbar.sky-segmented--navigation {
  border-color: rgb(255 255 255 / 14%);
  background: rgb(28 28 30 / 88%);
}
.camera-mode-navbar :deep(.sky-segmented__highlight) {
  background: #3a3a3c;
}
.camera-mode-navbar :deep(.sky-segmented-button) {
  color: #8e8e93;
  font-size: 12px;
}
.camera-mode-navbar :deep(.sky-segmented-button--active) {
  color: #ffd60a;
}
.camera-mode-navbar :deep(.sky-segmented-button:focus-visible) {
  outline: 0;
  box-shadow: none;
}
</style>
