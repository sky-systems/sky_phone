<script setup lang="ts">
import fixWebmDuration from 'fix-webm-duration'
import { onBeforeUnmount, onMounted, ref } from 'vue'

import type { UploadReady } from '@/types/media'
import { createGameView, type GameView } from '@/utils/gameView'
import { nuiCall } from '@/utils/nui'

type RecordingChunk = { blob: Blob; durationMs: number }
type PendingVideo = { blob: Blob; fileName: string }

const canvasRef = ref<HTMLCanvasElement | null>(null)
const pendingVideos = new Map<string, PendingVideo>()
const captureFps = 30
const maxCaptureHeight = 720
let bitrateBps = 1_500_000
let gameView: GameView | null = null
let renderFrameId: number | undefined
let lastRenderAt = 0
let recorder: MediaRecorder | null = null
let stream: MediaStream | null = null
let chunks: RecordingChunk[] = []
let lastChunkAt = 0
let lastChunkTimecode: number | null = null
let flushTimer: number | undefined

function postRecordState(active: boolean, saving = false): void {
  window.postMessage(
    { data: { active, saving }, type: 'camera:recordState' },
    '*',
  )
}

function ensureGameView(): GameView {
  if (!canvasRef.value) throw new Error('capture_failed')
  if (gameView && !gameView.isLost()) return gameView
  gameView?.dispose()
  const scale = Math.min(1, maxCaptureHeight / window.innerHeight)
  gameView = createGameView(canvasRef.value)
  gameView.resize(
    Math.round(window.innerWidth * scale),
    Math.round(window.innerHeight * scale),
  )
  return gameView
}

function startRenderLoop(): void {
  const view = ensureGameView()
  if (renderFrameId !== undefined) return
  const render = (now: number) => {
    if (!gameView || gameView.isLost()) {
      renderFrameId = undefined
      return
    }
    renderFrameId = window.requestAnimationFrame(render)
    if (now - lastRenderAt < 1000 / captureFps) return
    lastRenderAt = now
    view.render()
  }
  lastRenderAt = 0
  renderFrameId = window.requestAnimationFrame(render)
}

function stopRenderLoop(): void {
  if (renderFrameId !== undefined) {
    window.cancelAnimationFrame(renderFrameId)
    renderFrameId = undefined
  }
}

function resetRecording(): void {
  chunks = []
  lastChunkAt = 0
  lastChunkTimecode = null
}

function stopTracks(): void {
  stream?.getTracks().forEach((track) => track.stop())
  stream = null
}

function cleanupRecording(): void {
  if (recorder && recorder.state !== 'inactive') recorder.stop()
  recorder = null
  stopTracks()
  if (flushTimer !== undefined) window.clearInterval(flushTimer)
  flushTimer = undefined
  stopRenderLoop()
  resetRecording()
  postRecordState(false)
}

function startRecording(data: Record<string, unknown>): void {
  if (recorder) return
  if (typeof MediaRecorder === 'undefined') {
    window.postMessage(
      {
        data: { error: 'unsupported', success: false },
        type: 'camera:recordError',
      },
      '*',
    )
    return
  }
  const configuredBitrate = Number(data.bitrateKbps)
  if (Number.isFinite(configuredBitrate) && configuredBitrate > 0) {
    bitrateBps = Math.round(configuredBitrate * 1000)
  }
  startRenderLoop()
  resetRecording()
  stream = canvasRef.value?.captureStream(captureFps) ?? null
  if (!stream) {
    cleanupRecording()
    return
  }
  recorder = new MediaRecorder(stream, {
    mimeType: 'video/webm',
    videoBitsPerSecond: bitrateBps,
  })
  recorder.ondataavailable = (event) => {
    if (!event.data.size) return
    const now = Date.now()
    let durationMs = Math.max(0, now - lastChunkAt)
    if (typeof event.timecode === 'number') {
      durationMs =
        lastChunkTimecode === null
          ? 0
          : Math.max(0, event.timecode - lastChunkTimecode)
      lastChunkTimecode = event.timecode
    }
    lastChunkAt = now
    chunks.push({ blob: event.data, durationMs })
  }
  recorder.start()
  flushTimer = window.setInterval(() => {
    if (recorder?.state === 'recording') recorder.requestData()
  }, 1000)
  postRecordState(true)
}

async function stopRecording(data: Record<string, unknown>): Promise<void> {
  const correlationId = String(data.correlationId ?? '')
  if (!recorder || recorder.state === 'inactive' || !correlationId) return
  postRecordState(false, true)
  recorder.requestData()
  await new Promise((resolve) => window.setTimeout(resolve, 120))
  recorder.stop()
  await new Promise((resolve) => window.setTimeout(resolve, 120))
  if (flushTimer !== undefined) window.clearInterval(flushTimer)
  flushTimer = undefined
  stopTracks()
  recorder = null
  stopRenderLoop()
  const durationMs = chunks.reduce((sum, entry) => sum + entry.durationMs, 0)
  let blob = new Blob(
    chunks.map((entry) => entry.blob),
    { type: 'video/webm' },
  )
  blob = await (
    fixWebmDuration as unknown as (
      source: Blob,
      duration: number,
      options: { logger: boolean },
    ) => Promise<Blob>
  )(blob, durationMs, { logger: false })
  resetRecording()
  pendingVideos.set(correlationId, {
    blob,
    fileName: `camera-${correlationId}.webm`,
  })
  await nuiCall('media:requestUpload', {
    correlationId,
    mediaType: 'video',
  })
}

async function renderFrames(view: GameView, count: number): Promise<void> {
  for (let index = 0; index < count; index += 1) {
    await new Promise<void>((resolve) => {
      window.requestAnimationFrame(() => {
        view.render()
        resolve()
      })
    })
  }
}

async function capturePhotoBlob(ready: UploadReady): Promise<Blob> {
  const width = window.innerWidth
  const height = window.innerHeight
  const canvas = document.createElement('canvas')
  canvas.width = width
  canvas.height = height
  const view = createGameView(canvas, { preserveDrawingBuffer: true })
  try {
    view.resize(width, height)
    await renderFrames(view, 3)
    const output = document.createElement('canvas')
    output.width = width
    output.height = height
    const context = output.getContext('2d')
    if (!context) throw new Error('capture_failed')
    context.drawImage(canvas, 0, 0)
    const encoding = ready.photo?.Encoding ?? 'jpg'
    const mimeType =
      encoding === 'png'
        ? 'image/png'
        : encoding === 'webp'
          ? 'image/webp'
          : 'image/jpeg'
    return await new Promise<Blob>((resolve, reject) => {
      output.toBlob(
        (blob) => (blob ? resolve(blob) : reject(new Error('capture_failed'))),
        mimeType,
        ready.photo?.Quality ?? 0.95,
      )
    })
  } finally {
    view.dispose()
  }
}

async function failUpload(requestId: string, error: string): Promise<void> {
  await nuiCall('media:failUpload', { error, requestId })
}

async function uploadReady(ready: UploadReady): Promise<void> {
  let blob: Blob
  let fileName: string
  try {
    if (ready.mediaType === 'video') {
      const pending = pendingVideos.get(ready.correlationId)
      if (!pending) throw new Error('capture_failed')
      pendingVideos.delete(ready.correlationId)
      blob = pending.blob
      fileName = pending.fileName
    } else {
      blob = await capturePhotoBlob(ready)
      fileName = `camera-${ready.correlationId}.${ready.photo?.Encoding ?? 'jpg'}`
    }
  } catch {
    await failUpload(ready.requestId, 'capture_failed')
    return
  }

  const form = new FormData()
  form.append('file', blob, fileName)
  form.append(
    'metadata',
    JSON.stringify({ captureToken: ready.captureToken, source: 'sky_phone' }),
  )
  const controller = new AbortController()
  const timeout = window.setTimeout(
    () => controller.abort(),
    ready.uploadTimeoutMs ?? 25000,
  )
  try {
    const response = await fetch(ready.presignedUrl, {
      body: form,
      method: 'POST',
      signal: controller.signal,
    })
    const text = await response.text()
    const body = JSON.parse(text) as {
      data?: { id?: string; url?: string }
      id?: string
      url?: string
    }
    const uploaded = body.data ?? body
    if (!response.ok || !uploaded.id || !uploaded.url) {
      throw new Error('upload_failed')
    }
    await nuiCall('media:completeUpload', {
      remoteId: uploaded.id,
      requestId: ready.requestId,
      url: uploaded.url,
    })
  } catch (error) {
    await failUpload(
      ready.requestId,
      error instanceof DOMException && error.name === 'AbortError'
        ? 'upload_timeout'
        : 'upload_failed',
    )
  } finally {
    window.clearTimeout(timeout)
  }
}

function onMessage(event: MessageEvent): void {
  const message = event.data as {
    data?: Record<string, unknown>
    type?: string
  }
  if (message.type === 'camera:recordStart') {
    startRecording(message.data ?? {})
  } else if (message.type === 'camera:recordStop') {
    void stopRecording(message.data ?? {})
  } else if (message.type === 'camera:recordCancel') {
    cleanupRecording()
  } else if (message.type === 'media:uploadReady') {
    void uploadReady(message.data as UploadReady)
  }
}

onMounted(() => window.addEventListener('message', onMessage))

onBeforeUnmount(() => {
  window.removeEventListener('message', onMessage)
  cleanupRecording()
  pendingVideos.clear()
  gameView?.dispose()
  gameView = null
})
</script>

<template>
  <canvas
    ref="canvasRef"
    class="phone-media-capture"
    aria-hidden="true"
  ></canvas>
</template>

<style scoped>
.phone-media-capture {
  position: fixed;
  width: 0;
  height: 0;
  opacity: 0;
  pointer-events: none;
}
</style>
