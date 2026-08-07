<script setup lang="ts">
import {
  kFab,
  kNavbar,
  kPage,
  kSegmented,
  kSegmentedButton,
} from 'konsta/vue'
import {
  Images,
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
import type { MediaType, PhoneMedia, UploadResult } from '@/types/media'
import { createGameView, type GameView } from '@/utils/gameView'
import { formatRecordingDuration, mediaErrorKey } from '@/utils/media'
import { nuiCall } from '@/utils/nui'

type CaptureItem = {
  error?: string
  id: string
  mediaType: MediaType
  status: 'uploading' | 'success' | 'error'
}

const isDevelopment = import.meta.env.DEV
const zoomLevels = [0.5, 1, 2, 3] as const
const phone = usePhoneStore()
const messageMedia = useMessageMediaStore()
const route = useRoute()
const router = useRouter()
const requestedMessageMedia = computed<MediaType | null>(() => {
  const value = route.query.messageAttachment
  return value === 'photo' || value === 'video' ? value : null
})
const mode = ref<MediaType>(requestedMessageMedia.value ?? 'photo')
const selectedZoom = ref<(typeof zoomLevels)[number]>(1)
const flashEnabled = ref(false)
const frontCamera = ref(false)
const shutterActive = ref(false)
const focused = ref(true)
const recording = ref(false)
const savingVideo = ref(false)
const recordingStartedAt = ref(0)
const elapsed = ref('00:00')
const captures = ref<CaptureItem[]>([])
const latestMedia = ref<PhoneMedia | null>(null)
const gameCanvas = ref<HTMLCanvasElement | null>(null)
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
const controlColors = {
  bgIos: 'bg-ios-light-glass/75 dark:bg-ios-dark-glass/75',
  activeBgIos: 'active:bg-white/90 dark:active:bg-white/20',
  textIos: 'text-black/80 dark:text-white/80',
}
const modeColors = {
  strongHighlightBgIos: 'bg-[#e5e5ea] dark:bg-[#2c2c2e]',
}
const modeButtonColors = {
  segmentedStrongTextIos: 'text-[#ffd60a]',
}
const modeNavbarColors = {
  bgIos: 'bg-transparent',
}
const flashColors = computed(() => ({
  ...controlColors,
  textIos: flashEnabled.value
    ? 'text-yellow-500 dark:text-yellow-300'
    : controlColors.textIos,
}))

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

function devMedia(id: string, mediaType: MediaType): PhoneMedia {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="900" height="1600"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#19354f"/><stop offset="1" stop-color="#d78357"/></linearGradient></defs><rect width="900" height="1600" fill="url(#g)"/><circle cx="680" cy="380" r="210" fill="#ffffff22"/><path d="M0 1200 260 840l180 220 170-170 290 310v400H0z" fill="#102331aa"/></svg>`
  return {
    createdAt: Date.now(),
    id: Number(Date.now()),
    mediaType,
    url: `data:image/svg+xml,${encodeURIComponent(svg)}#${id}`,
  }
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
    window.setTimeout(() => {
      window.dispatchEvent(
        new MessageEvent('message', {
          data: {
            data: {
              correlationId: id,
              media: devMedia(id, 'photo'),
              success: true,
            },
            type: 'media:uploadResult',
          },
        }),
      )
    }, 700)
    return
  }
  await nuiCall('media:requestUpload', {
    correlationId: id,
    mediaType: 'photo',
  })
}

function startRecording(): void {
  if (savingVideo.value) return
  window.postMessage(
    {
      data: { bitrateKbps: videoBitrateKbps.value },
      type: 'camera:recordStart',
    },
    '*',
  )
}

function stopRecording(): void {
  if (!recording.value || savingVideo.value) return
  const id = correlationId()
  queueCapture(id, 'video')
  if (isDevelopment) {
    recording.value = false
    savingVideo.value = true
    window.setTimeout(() => {
      window.dispatchEvent(
        new MessageEvent('message', {
          data: {
            data: {
              correlationId: id,
              media: devMedia(id, 'video'),
              success: true,
            },
            type: 'media:uploadResult',
          },
        }),
      )
    }, 900)
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
}

function setZoom(zoom: (typeof zoomLevels)[number]): void {
  selectedZoom.value = zoom
  resizeGameView()
  window.postMessage({ data: { zoom }, type: 'camera:zoom' }, '*')
  void nuiCall('camera:setZoom', { zoom })
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
  gameView = createGameView(gameCanvas.value)
  resizeObserver = new ResizeObserver((entries) => resizeGameView(entries[0]))
  resizeObserver.observe(gameCanvas.value)
  resizeGameView()
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
  if (event.code !== 'Space' || event.repeat || !focused.value) return
  event.preventDefault()
  focused.value = false
  void nuiCall('camera:setFocus', { focused: false })
}

function onMessage(event: MessageEvent): void {
  const message = event.data as {
    data?: Record<string, unknown>
    type?: string
  }
  if (message.type === 'camera:focus') {
    focused.value = message.data?.focused === true
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
  window.postMessage(
    { data: { zoom: selectedZoom.value }, type: 'camera:zoom' },
    '*',
  )
  window.addEventListener('keydown', onKeydown)
  window.addEventListener('message', onMessage)
  void nuiCall('camera:setActive', { active: true })
  void nuiCall<{ videoBitrateKbps?: number }>('media:config').then(
    (response) => {
      if (response.success && response.data?.videoBitrateKbps) {
        videoBitrateKbps.value = response.data.videoBitrateKbps
      }
    },
  )
  void loadLatest()
  startGameView()
})

onBeforeUnmount(() => {
  if (shutterTimer !== undefined) window.clearTimeout(shutterTimer)
  if (noticeTimer !== undefined) window.clearTimeout(noticeTimer)
  if (recordingTimer !== undefined) window.clearInterval(recordingTimer)
  window.removeEventListener('keydown', onKeydown)
  window.removeEventListener('message', onMessage)
  if (renderFrameId !== undefined) window.cancelAnimationFrame(renderFrameId)
  resizeObserver?.disconnect()
  gameView?.dispose()
  phone.setCameraLandscape(false)
  window.postMessage(
    { data: { landscape: false }, type: 'camera:orientation' },
    '*',
  )
  window.postMessage({ type: 'camera:recordCancel' }, '*')
  void nuiCall('camera:setFlash', { enabled: false })
  void nuiCall('camera:setActive', { active: false })
})
</script>

<template>
  <k-page
    class="camera-page"
    :class="{ 'camera-page--landscape': phone.cameraLandscape }"
    :aria-label="phone.t('Apps.camera.name')"
  >
    <div class="camera-viewport">
      <canvas
        v-if="!isDevelopment"
        ref="gameCanvas"
        class="camera-game-view"
        aria-hidden="true"
      ></canvas>
      <div
        v-else
        class="camera-dev-view"
        :style="{ transform: `scale(${Math.max(1, selectedZoom)})` }"
        aria-hidden="true"
      >
        <span class="camera-dev-sun"></span>
        <span class="camera-dev-horizon"></span>
      </div>
      <div class="camera-shade"></div>
      <div class="camera-flash" :class="{ active: shutterActive }"></div>
    </div>

    <header class="camera-topbar">
      <k-fab
        component="button"
        type="button"
        class="camera-control"
        :colors="flashColors"
        :aria-label="phone.t('Apps.camera.flash')"
        @click="toggleFlash"
      >
        <template #icon>
          <Zap v-if="flashEnabled" :size="19" />
          <ZapOff v-else :size="19" />
        </template>
      </k-fab>
      <span
        v-if="noticeText"
        class="camera-focus-pill camera-focus-pill--notice"
      >
        {{ noticeText }}
      </span>
      <span v-else-if="pendingCount" class="camera-upload-pill">
        {{ phone.t('Apps.camera.uploading', { count: String(pendingCount) }) }}
      </span>
      <span v-else class="camera-focus-pill">
        {{
          phone.t(focused ? 'Apps.camera.focusHelp' : 'Apps.camera.returnHelp')
        }}
      </span>
      <k-fab
        component="button"
        type="button"
        class="camera-control"
        :colors="controlColors"
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
      </k-fab>
    </header>

    <div v-if="recording || savingVideo" class="camera-record-status">
      <span class="camera-record-dot"></span>
      {{ savingVideo ? phone.t('Apps.camera.saving') : elapsed }}
    </div>

    <div class="camera-zoom-row">
      <button
        v-for="zoom in zoomLevels"
        :key="zoom"
        class="camera-zoom-pill"
        :class="{ active: selectedZoom === zoom }"
        type="button"
        :aria-label="phone.t('Apps.camera.zoom', { zoom: `${zoom}x` })"
        :aria-pressed="selectedZoom === zoom"
        @click="setZoom(zoom)"
      >
        {{ zoom }}x
      </button>
    </div>

    <footer class="camera-controls">
      <div class="camera-capture-row">
        <button
          class="camera-latest"
          type="button"
          :aria-label="phone.t('Apps.camera.openGallery')"
          @click="
            router.push({
              path: '/apps/photos',
              query: requestedMessageMedia
                ? { messageAttachment: requestedMessageMedia }
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
        </button>

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

        <k-fab
          component="button"
          type="button"
          class="camera-control camera-selfie"
          :colors="controlColors"
          :aria-label="phone.t('Apps.camera.flip')"
          @click="toggleFacing"
        >
          <template #icon><RefreshCw :size="20" /></template>
        </k-fab>
      </div>

      <k-navbar
        component="nav"
        class="camera-mode-navbar"
        inner-class="hidden"
        :colors="modeNavbarColors"
        :aria-label="phone.t('Apps.camera.name')"
      >
        <template #subnavbar>
          <k-segmented strong rounded :colors="modeColors">
            <k-segmented-button
              small
              :active="mode === 'photo'"
              :disabled="recording || savingVideo"
              :colors="modeButtonColors"
              :class="mode === 'photo' ? undefined : 'text-[#8e8e93]'"
              :aria-pressed="mode === 'photo'"
              @click="setMode('photo')"
            >
              {{ phone.t('Apps.camera.photo') }}
            </k-segmented-button>
            <k-segmented-button
              small
              :active="mode === 'video'"
              :disabled="recording || savingVideo"
              :colors="modeButtonColors"
              :class="mode === 'video' ? undefined : 'text-[#8e8e93]'"
              :aria-pressed="mode === 'video'"
              @click="setMode('video')"
            >
              {{ phone.t('Apps.camera.video') }}
            </k-segmented-button>
          </k-segmented>
        </template>
      </k-navbar>
    </footer>
  </k-page>
</template>

<style scoped>
.camera-page {
  position: relative;
  overflow: hidden;
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
  overflow: hidden;
  background: linear-gradient(#4a88ad 0 48%, #a88d68 49% 62%, #283528 63%);
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
  grid-template-columns: 44px 1fr 44px;
  align-items: center;
  gap: 10px;
}
.camera-control {
  --color-primary: transparent;
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
.camera-focus-pill,
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
.camera-zoom-row {
  position: absolute;
  z-index: 4;
  bottom: 164px;
  left: 50%;
  display: flex;
  gap: 6px;
  transform: translateX(-50%);
}
.camera-zoom-pill {
  width: 30px;
  height: 26px;
  padding: 0;
  border: 1px solid transparent;
  border-radius: 999px;
  background: transparent;
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
  border-color: transparent;
  background: rgb(44 44 46 / 88%);
  box-shadow: 0 8px 16px rgb(0 0 0 / 30%);
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
  padding: 0 24px 4px;
}
.camera-latest {
  width: 44px;
  height: 44px;
  overflow: hidden;
  border: 0;
  border-radius: 50%;
  background: #111b;
  color: #fff;
  display: grid;
  place-items: center;
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
  position: relative;
  top: auto;
  width: 50%;
  align-self: center;
  padding-bottom: 18px;
  padding-top: 0;
}
</style>
