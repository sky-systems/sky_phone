<script setup lang="ts">
import fixWebmDuration from 'fix-webm-duration'
import { onBeforeUnmount, onMounted, ref } from 'vue'

import type { UploadReady } from '@/types/media'
import { createGameView, type GameView } from '@/utils/gameView'
import {
  bindMediaRecorderError,
  setBoundedMapEntry,
  stopMediaRecorder,
} from '@/utils/mediaRecorder'
import { nuiCall } from '@/utils/nui'
import { isTrustedRootMessageSource } from '@/utils/windowMessages'

type RecordingChunk = { blob: Blob; durationMs: number }
type PendingVideo = { blob: Blob; fileName: string }
type UploadFailureDebug = {
  correlationId: string
  message: string
  stage: string
  status?: number
}

const canvasRef = ref<HTMLCanvasElement | null>(null)
const pendingVideos = new Map<string, PendingVideo>()
const maxPendingVideos = 3
const captureFps = 30
const maxCaptureEdge = 720
const portraitAspect = 3 / 4
const landscapeAspect = 16 / 9
let bitrateBps = 1_500_000
let landscape = false
let zoom = 1
let gameView: GameView | null = null
let renderFrameId: number | undefined
let lastRenderAt = 0
let recorder: MediaRecorder | null = null
let recordingStarting = false
let stream: MediaStream | null = null
let microphoneStream: MediaStream | null = null
let chunks: RecordingChunk[] = []
let lastChunkAt = 0
let lastChunkTimecode: number | null = null
let recordingStartedAt = 0
let recordingGeneration = 0
let flushTimer: number | undefined
let removeRecorderErrorListener: (() => void) | null = null

function captureDimensions(): { height: number; width: number } {
  return landscape
    ? {
        height: Math.round(maxCaptureEdge / landscapeAspect),
        width: maxCaptureEdge,
      }
    : {
        height: maxCaptureEdge,
        width: Math.round(maxCaptureEdge * portraitAspect),
      }
}

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
  const dimensions = captureDimensions()
  gameView = createGameView(canvasRef.value, {
    onContextRestored: () => {
      if (recorder?.state === 'recording') startRenderLoop()
    },
  })
  gameView.resize(
    dimensions.width,
    dimensions.height,
    window.innerWidth,
    window.innerHeight,
    zoom,
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
  recordingStartedAt = 0
}

function stopTracks(): void {
  stream?.getTracks().forEach((track) => track.stop())
  microphoneStream?.getTracks().forEach((track) => track.stop())
  stream = null
  microphoneStream = null
}

function cleanupRecording(): void {
  recordingGeneration += 1
  recordingStarting = false
  const activeRecorder = recorder
  recorder = null
  removeRecorderErrorListener?.()
  removeRecorderErrorListener = null
  if (activeRecorder) {
    activeRecorder.ondataavailable = null
    if (activeRecorder.state !== 'inactive') {
      try {
        activeRecorder.stop()
      } catch (error) {
        console.error(
          '[Camera] Could not stop the failed media recorder.',
          error,
        )
      }
    }
  }
  stopTracks()
  if (flushTimer !== undefined) window.clearInterval(flushTimer)
  flushTimer = undefined
  stopRenderLoop()
  resetRecording()
  postRecordState(false)
}

async function startRecording(data: Record<string, unknown>): Promise<void> {
  if (recorder || recordingStarting) return
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
  try {
    startRenderLoop()
  } catch (error) {
    console.error('[Camera] Could not start game-view recording.', error)
    cleanupRecording()
    window.postMessage(
      {
        data: { error: 'capture_failed', success: false },
        type: 'camera:recordError',
      },
      '*',
    )
    return
  }
  recordingStarting = true
  const generation = ++recordingGeneration
  resetRecording()
  const videoStream = canvasRef.value?.captureStream(captureFps) ?? null
  if (!videoStream) {
    cleanupRecording()
    return
  }
  if (data.microphoneEnabled === true) {
    try {
      const acquiredMicrophoneStream =
        await navigator.mediaDevices.getUserMedia({
          audio: {
            autoGainControl: true,
            echoCancellation: true,
            noiseSuppression: true,
          },
        })
      if (generation !== recordingGeneration) {
        acquiredMicrophoneStream.getTracks().forEach((track) => track.stop())
        videoStream.getTracks().forEach((track) => track.stop())
        return
      }
      microphoneStream = acquiredMicrophoneStream
    } catch {
      videoStream.getTracks().forEach((track) => track.stop())
      if (generation !== recordingGeneration) return
      cleanupRecording()
      window.postMessage(
        {
          data: { error: 'microphone_unavailable', success: false },
          type: 'camera:recordError',
        },
        '*',
      )
      return
    }
  }
  stream = new MediaStream([
    ...videoStream.getVideoTracks(),
    ...(microphoneStream?.getAudioTracks() ?? []),
  ])
  if (generation !== recordingGeneration) {
    stopTracks()
    stopRenderLoop()
    return
  }
  const mimeType = [
    'video/webm;codecs=vp8,opus',
    'video/webm;codecs=vp8',
    'video/webm',
  ].find((type) => MediaRecorder.isTypeSupported(type))
  try {
    recorder = new MediaRecorder(stream, {
      ...(mimeType ? { mimeType } : {}),
      audioBitsPerSecond: 128_000,
      videoBitsPerSecond: bitrateBps,
    })
  } catch (error) {
    console.error('[Camera] Could not create the media recorder.', error)
    cleanupRecording()
    window.postMessage(
      {
        data: { error: 'unsupported', success: false },
        type: 'camera:recordError',
      },
      '*',
    )
    return
  }
  const activeRecorder = recorder
  removeRecorderErrorListener = bindMediaRecorderError(
    activeRecorder,
    () => generation === recordingGeneration && recorder === activeRecorder,
    (event) => {
      console.error('[Camera] Media recorder failed while recording.', event)
      cleanupRecording()
      window.postMessage(
        {
          data: { error: 'capture_failed', success: false },
          type: 'camera:recordError',
        },
        '*',
      )
    },
  )
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
  try {
    recorder.start()
  } catch (error) {
    console.error('[Camera] Could not start the media recorder.', error)
    cleanupRecording()
    window.postMessage(
      {
        data: { error: 'capture_failed', success: false },
        type: 'camera:recordError',
      },
      '*',
    )
    return
  }
  recordingStartedAt = Date.now()
  recordingStarting = false
  flushTimer = window.setInterval(() => {
    if (recorder?.state === 'recording') recorder.requestData()
  }, 1000)
  postRecordState(true)
}

async function stopRecording(data: Record<string, unknown>): Promise<void> {
  const correlationId = String(data.correlationId ?? '')
  if (!recorder || recorder.state === 'inactive' || !correlationId) return
  const generation = recordingGeneration
  const activeRecorder = recorder
  postRecordState(false, true)
  if (flushTimer !== undefined) window.clearInterval(flushTimer)
  flushTimer = undefined
  const stopErrorListener = removeRecorderErrorListener
  stopErrorListener?.()
  if (removeRecorderErrorListener === stopErrorListener) {
    removeRecorderErrorListener = null
  }
  try {
    await stopMediaRecorder(activeRecorder)
    if (generation !== recordingGeneration) return
    const durationMs = Math.max(
      chunks.reduce((sum, entry) => sum + entry.durationMs, 0),
      recordingStartedAt ? Date.now() - recordingStartedAt : 0,
    )
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
    if (generation !== recordingGeneration) return
    setBoundedMapEntry(
      pendingVideos,
      correlationId,
      { blob, fileName: `camera-${correlationId}.webm` },
      maxPendingVideos,
    )
    const response = await nuiCall('media:requestUpload', {
      correlationId,
      mediaType: 'video',
    })
    if (generation !== recordingGeneration) return
    if (!response.success) {
      pendingVideos.delete(correlationId)
      window.postMessage(
        {
          data: { correlationId, error: 'request_failed', success: false },
          type: 'media:uploadResult',
        },
        '*',
      )
    }
  } catch (error) {
    if (generation === recordingGeneration) {
      console.error('[Camera] Could not finalize the video recording.', error)
      pendingVideos.delete(correlationId)
      window.postMessage(
        {
          data: { correlationId, error: 'capture_failed', success: false },
          type: 'media:uploadResult',
        },
        '*',
      )
    }
  } finally {
    if (generation === recordingGeneration || recorder === activeRecorder) {
      if (recorder === activeRecorder) {
        recorder = null
      }
      stopTracks()
      stopRenderLoop()
      resetRecording()
    }
  }
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
  const { height, width } = captureDimensions()
  const canvas = document.createElement('canvas')
  canvas.width = width
  canvas.height = height
  const view = createGameView(canvas, { preserveDrawingBuffer: true })
  try {
    view.resize(width, height, window.innerWidth, window.innerHeight, zoom)
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

async function failUpload(
  requestId: string,
  error: string,
  debug: UploadFailureDebug,
): Promise<void> {
  console.error('[Sky Phone Media] Upload failed.', {
    correlationId: debug.correlationId,
    detail: debug.message,
    error,
    stage: debug.stage,
    status: debug.status,
  })
  const response = await nuiCall('media:failUpload', {
    correlationId: debug.correlationId,
    debugMessage: debug.message,
    debugStage: debug.stage,
    debugStatus: debug.status,
    error,
    requestId,
  })
  if (!response.success) {
    console.error('[Sky Phone Media] Could not forward upload diagnostics.', {
      correlationId: debug.correlationId,
      error: response.error,
    })
  }
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
  } catch (error) {
    await failUpload(ready.requestId, 'capture_failed', {
      correlationId: ready.correlationId,
      message: error instanceof Error ? error.message : String(error),
      stage: 'capture',
    })
    return
  }

  console.info('[Sky Phone Media] Capture prepared for upload.', {
    bytes: blob.size,
    correlationId: ready.correlationId,
    mimeType: blob.type,
    type: ready.mediaType,
  })

  const form = new FormData()
  form.append('file', blob, fileName)
  const controller = new AbortController()
  const timeout = window.setTimeout(
    () => controller.abort(),
    ready.uploadTimeoutMs ?? 25000,
  )
  let debugStage = 'provider_request'
  let debugStatus: number | undefined
  try {
    const response = await fetch(ready.presignedUrl, {
      body: form,
      method: 'POST',
      signal: controller.signal,
    })
    debugStatus = response.status
    debugStage = 'provider_response'
    console.info('[Sky Phone Media] FiveManage upload responded.', {
      correlationId: ready.correlationId,
      status: response.status,
    })
    const text = await response.text()
    const body = JSON.parse(text) as {
      data?: { id?: string; url?: string }
      error?: string
      id?: string
      message?: string
      url?: string
    }
    const uploaded = body.data ?? body
    if (!response.ok || !uploaded.id || !uploaded.url) {
      throw new Error(
        (typeof body.error === 'string' && body.error) ||
          (typeof body.message === 'string' && body.message) ||
          'upload_failed',
      )
    }
    debugStage = 'completion_callback'
    const completion = await nuiCall('media:completeUpload', {
      correlationId: ready.correlationId,
      remoteId: uploaded.id,
      requestId: ready.requestId,
      url: uploaded.url,
    })
    if (!completion.success) {
      throw new Error(completion.error ?? 'completion_callback_failed')
    }
    console.info(
      '[Sky Phone Media] Upload completion forwarded to the server.',
      {
        correlationId: ready.correlationId,
      },
    )
  } catch (error) {
    await failUpload(
      ready.requestId,
      error instanceof DOMException && error.name === 'AbortError'
        ? 'upload_timeout'
        : 'upload_failed',
      {
        correlationId: ready.correlationId,
        message: error instanceof Error ? error.message : String(error),
        stage: debugStage,
        status: debugStatus,
      },
    )
  } finally {
    window.clearTimeout(timeout)
  }
}

function onMessage(event: MessageEvent): void {
  if (!isTrustedRootMessageSource(event.source, window)) return
  const message = event.data as {
    data?: Record<string, unknown>
    type?: string
  }
  if (message.type === 'camera:recordStart') {
    void startRecording(message.data ?? {})
  } else if (message.type === 'camera:recordStop') {
    void stopRecording(message.data ?? {})
  } else if (message.type === 'camera:recordCancel') {
    cleanupRecording()
  } else if (message.type === 'camera:orientation') {
    landscape = message.data?.landscape === true
    if (gameView && !gameView.isLost()) {
      const dimensions = captureDimensions()
      gameView.resize(
        dimensions.width,
        dimensions.height,
        window.innerWidth,
        window.innerHeight,
        zoom,
      )
    }
  } else if (message.type === 'camera:zoom') {
    const nextZoom = Number(message.data?.zoom)
    if (!Number.isFinite(nextZoom) || nextZoom < 0.5 || nextZoom > 3) return
    zoom = nextZoom
    if (gameView && !gameView.isLost()) {
      const dimensions = captureDimensions()
      gameView.resize(
        dimensions.width,
        dimensions.height,
        window.innerWidth,
        window.innerHeight,
        zoom,
      )
    }
  } else if (message.type === 'media:uploadReady') {
    const ready = message.data as UploadReady
    console.info('[Sky Phone Media] Upload-ready received.', {
      correlationId: ready.correlationId,
      type: ready.mediaType,
    })
    void uploadReady(ready)
  } else if (message.type === 'media:uploadResult') {
    const correlationId = String(message.data?.correlationId ?? '')
    if (correlationId) pendingVideos.delete(correlationId)
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
