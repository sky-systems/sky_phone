<script setup lang="ts">
import fixWebmDuration from 'fix-webm-duration'
import { onBeforeUnmount, onMounted, watch } from 'vue'

import { useMemosStore } from '@/stores/memos'
import { usePhoneStore } from '@/stores/phone'
import type {
  MemoDto,
  MemoRecorderState,
  MemoRecorderStateName,
  MemoRecordingMetadata,
  MemoUploadReady,
  MemoUploadResult,
} from '@/types/memos'
import { isMemoDto } from '@/types/memos'
import {
  bindMediaRecorderError,
  stopMediaRecorder,
} from '@/utils/mediaRecorder'
import { nuiCall } from '@/utils/nui'
import { isTrustedRootMessageSource } from '@/utils/windowMessages'

type PendingMemo = {
  abortController?: AbortController
  blob: Blob
  fileName: string
  requestId?: string
}

const MAX_DURATION_MS = 5 * 60 * 1000
const MAX_RECORDING_BYTES = 2 * 1024 * 1024
const WAVEFORM_SAMPLES = 96
const LIVE_LEVEL_SAMPLES = 32
const AUDIO_BITS_PER_SECOND = 24_000
const memos = useMemosStore()
const phone = usePhoneStore()
const pendingMemos = new Map<string, PendingMemo>()

let recorder: MediaRecorder | null = null
let mediaStream: MediaStream | null = null
let audioContext: AudioContext | null = null
let analyser: AnalyserNode | null = null
let recordingTimer: number | undefined
let recordingGeneration = 0
let recordingStartedAt = 0
let pausedStartedAt = 0
let totalPausedMs = 0
let recordingBytes = 0
let recordingTooLarge = false
let recordingChunks: Blob[] = []
let recordingSamples: number[] = []
let liveLevels: number[] = Array(LIVE_LEVEL_SAMPLES).fill(0.08)
let metadata: MemoRecordingMetadata = { note: '', pinned: false, title: '' }
let currentState: MemoRecorderStateName = 'idle'
let currentElapsedMs = 0
let currentCorrelationId = ''
let recordingDeviceImei = ''
let removeRecorderErrorListener: (() => void) | null = null

function postRecorderState(state: MemoRecorderStateName, error?: string): void {
  currentState = state
  const data: MemoRecorderState = {
    elapsedMs: Math.round(currentElapsedMs),
    levels: [...liveLevels],
    state,
    ...(error ? { error } : {}),
  }
  window.postMessage({ data, type: 'memo:recordState' }, '*')
}

function updateMetadata(data: Record<string, unknown>): void {
  if (typeof data.title === 'string') metadata.title = data.title
  if (typeof data.note === 'string') metadata.note = data.note
  if (typeof data.pinned === 'boolean') metadata.pinned = data.pinned
}

function elapsedAt(now = performance.now()): number {
  if (!recordingStartedAt) return currentElapsedMs
  const activePause = pausedStartedAt ? now - pausedStartedAt : 0
  return Math.max(
    0,
    Math.min(
      MAX_DURATION_MS,
      now - recordingStartedAt - totalPausedMs - activePause,
    ),
  )
}

function recordingMime(): string | null {
  if (typeof MediaRecorder === 'undefined') return null
  if (MediaRecorder.isTypeSupported('audio/webm;codecs=opus')) {
    return 'audio/webm;codecs=opus'
  }
  if (MediaRecorder.isTypeSupported('audio/webm')) return 'audio/webm'
  return null
}

function sampleMicrophone(): void {
  if (!analyser || currentState !== 'recording') return
  const values = new Uint8Array(analyser.fftSize)
  analyser.getByteTimeDomainData(values)
  let total = 0
  for (const value of values) total += Math.abs(value - 128) / 128
  const level = Math.max(0.08, Math.min(1, (total / values.length) * 4.5))
  recordingSamples.push(level)
  liveLevels = [...liveLevels.slice(1), level]
  currentElapsedMs = elapsedAt()
  postRecorderState('recording')
  if (currentElapsedMs >= MAX_DURATION_MS) void stopRecording({})
}

function compressedWaveform(): number[] {
  if (!recordingSamples.length) return Array(WAVEFORM_SAMPLES).fill(0.08)
  const result: number[] = []
  const bucketSize = recordingSamples.length / WAVEFORM_SAMPLES
  for (let index = 0; index < WAVEFORM_SAMPLES; index += 1) {
    const start = Math.floor(index * bucketSize)
    const end = Math.max(start + 1, Math.floor((index + 1) * bucketSize))
    const bucket = recordingSamples.slice(start, end)
    const average = bucket.length
      ? bucket.reduce((sum, value) => sum + value, 0) / bucket.length
      : (recordingSamples.at(-1) ?? 0.08)
    result.push(Math.max(0.08, Math.min(1, average)))
  }
  return result
}

function blobDataUrl(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.addEventListener('load', () => {
      if (typeof reader.result === 'string') {
        resolve(reader.result)
        return
      }
      reject(new Error('invalid_audio_data'))
    })
    reader.addEventListener('error', () => {
      reject(reader.error ?? new Error('audio_read_failed'))
    })
    reader.addEventListener('abort', () =>
      reject(new Error('audio_read_failed')),
    )
    reader.readAsDataURL(blob)
  })
}

function resetRecordingData(): void {
  recordingChunks = []
  recordingSamples = []
  recordingBytes = 0
  recordingTooLarge = false
  recordingStartedAt = 0
  pausedStartedAt = 0
  totalPausedMs = 0
  currentElapsedMs = 0
  recordingDeviceImei = ''
  liveLevels = Array(LIVE_LEVEL_SAMPLES).fill(0.08)
}

function cleanupRecorder(stopActive: boolean): void {
  if (recordingTimer !== undefined) window.clearInterval(recordingTimer)
  recordingTimer = undefined
  removeRecorderErrorListener?.()
  removeRecorderErrorListener = null
  const activeRecorder = recorder
  recorder = null
  if (activeRecorder) {
    activeRecorder.ondataavailable = null
    if (stopActive && activeRecorder.state !== 'inactive') {
      try {
        activeRecorder.stop()
      } catch (error) {
        console.error('[Memos] Could not stop the media recorder.', error)
      }
    }
  }
  mediaStream?.getTracks().forEach((track) => track.stop())
  mediaStream = null
  void audioContext?.close()
  audioContext = null
  analyser = null
}

function failRecording(error: string, generation = recordingGeneration): void {
  if (generation !== recordingGeneration) return
  recordingGeneration += 1
  cleanupRecorder(true)
  resetRecordingData()
  postRecorderState('error', error)
}

async function startRecording(data: Record<string, unknown>): Promise<void> {
  const deviceImei = phone.device?.imei
  if (!phone.isOpen || !deviceImei) {
    console.error('[Memos] Cannot start a recording while the phone is closed.')
    return
  }
  if (!['idle', 'error'].includes(currentState)) {
    console.error(
      `[Memos] Cannot start while recorder state is ${currentState}.`,
    )
    postRecorderState(currentState, 'operation_in_progress')
    return
  }
  if (
    !navigator.mediaDevices?.getUserMedia ||
    typeof MediaRecorder === 'undefined'
  ) {
    postRecorderState('error', 'microphone_unavailable')
    return
  }
  const mimeType = recordingMime()
  if (!mimeType) {
    postRecorderState('error', 'microphone_unavailable')
    return
  }

  const generation = ++recordingGeneration
  metadata = { note: '', pinned: false, title: '' }
  updateMetadata(data)
  resetRecordingData()
  recordingDeviceImei = deviceImei
  postRecorderState('starting')
  try {
    const acquiredStream = await navigator.mediaDevices.getUserMedia({
      audio: {
        autoGainControl: true,
        echoCancellation: true,
        noiseSuppression: true,
      },
    })
    if (generation !== recordingGeneration) {
      acquiredStream.getTracks().forEach((track) => track.stop())
      return
    }
    mediaStream = acquiredStream
    recorder = new MediaRecorder(mediaStream, {
      audioBitsPerSecond: AUDIO_BITS_PER_SECOND,
      mimeType,
    })
    const activeRecorder = recorder
    activeRecorder.ondataavailable = (event) => {
      if (generation !== recordingGeneration || !event.data.size) return
      recordingChunks.push(event.data)
      recordingBytes += event.data.size
      if (recordingBytes > MAX_RECORDING_BYTES && !recordingTooLarge) {
        recordingTooLarge = true
        void stopRecording({})
      }
    }
    removeRecorderErrorListener = bindMediaRecorderError(
      activeRecorder,
      () => generation === recordingGeneration && recorder === activeRecorder,
      (event) => {
        console.error('[Memos] Media recorder failed while recording.', event)
        failRecording('recording_failed', generation)
      },
    )
    audioContext = new AudioContext()
    analyser = audioContext.createAnalyser()
    analyser.fftSize = 128
    audioContext.createMediaStreamSource(mediaStream).connect(analyser)
    activeRecorder.start(250)
    recordingStartedAt = performance.now()
    recordingTimer = window.setInterval(sampleMicrophone, 100)
    postRecorderState('recording')
  } catch (error) {
    if (generation !== recordingGeneration) return
    console.error('[Memos] Could not start audio recording.', error)
    failRecording('microphone_unavailable', generation)
  }
}

function pauseRecording(): void {
  if (
    !recorder ||
    recorder.state !== 'recording' ||
    currentState !== 'recording'
  ) {
    console.error('[Memos] Cannot pause because no memo is being recorded.')
    return
  }
  try {
    currentElapsedMs = elapsedAt()
    pausedStartedAt = performance.now()
    recorder.pause()
    postRecorderState('paused')
  } catch (error) {
    console.error('[Memos] Could not pause the media recorder.', error)
    failRecording('recording_failed')
  }
}

function resumeRecording(): void {
  if (!recorder || recorder.state !== 'paused' || currentState !== 'paused') {
    console.error('[Memos] Cannot resume because no memo recording is paused.')
    return
  }
  try {
    const now = performance.now()
    totalPausedMs += pausedStartedAt ? now - pausedStartedAt : 0
    pausedStartedAt = 0
    recorder.resume()
    currentElapsedMs = elapsedAt(now)
    postRecorderState('recording')
  } catch (error) {
    console.error('[Memos] Could not resume the media recorder.', error)
    failRecording('recording_failed')
  }
}

async function stopRecording(data: Record<string, unknown>): Promise<void> {
  const activeRecorder = recorder
  if (
    !activeRecorder ||
    activeRecorder.state === 'inactive' ||
    !['recording', 'paused'].includes(currentState)
  ) {
    return
  }
  const generation = recordingGeneration
  updateMetadata(data)
  currentElapsedMs = elapsedAt()
  postRecorderState('stopping')
  if (recordingTimer !== undefined) window.clearInterval(recordingTimer)
  recordingTimer = undefined
  removeRecorderErrorListener?.()
  removeRecorderErrorListener = null

  try {
    await stopMediaRecorder(activeRecorder)
    if (generation !== recordingGeneration) return
    const mimeType = activeRecorder.mimeType || 'audio/webm'
    const durationMs = Math.max(300, Math.round(currentElapsedMs))
    let blob = new Blob(recordingChunks, { type: mimeType })
    blob = await (
      fixWebmDuration as unknown as (
        source: Blob,
        duration: number,
        options: { logger: boolean },
      ) => Promise<Blob>
    )(blob, durationMs, { logger: false })
    if (generation !== recordingGeneration) return
    const waveform = compressedWaveform()
    const finalMetadata = { ...metadata }
    const finalDeviceImei = recordingDeviceImei
    const exceededSizeLimit = recordingTooLarge
    cleanupRecorder(false)
    resetRecordingData()

    if (exceededSizeLimit || !blob.size || blob.size > MAX_RECORDING_BYTES) {
      postRecorderState('error', 'recording_too_large')
      return
    }

    const correlationId = `memo-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`
    currentCorrelationId = correlationId
    currentElapsedMs = durationMs
    liveLevels = waveform.slice(-LIVE_LEVEL_SAMPLES)
    const uploadData = {
      correlationId,
      deviceImei: finalDeviceImei,
      durationMs,
      mimeType,
      note: finalMetadata.note,
      pinned: finalMetadata.pinned,
      title: finalMetadata.title,
      waveform,
    }
    postRecorderState('uploading')
    if (import.meta.env.DEV) {
      const response = await nuiCall<MemoDto>('memos:devCapture', {
        ...uploadData,
        audioDataUrl: await blobDataUrl(blob),
      })
      if (
        generation !== recordingGeneration ||
        currentCorrelationId !== correlationId
      ) {
        return
      }
      pendingMemos.delete(correlationId)
      currentCorrelationId = ''
      if (!response.success || !isMemoDto(response.data)) {
        postRecorderState('error', response.error ?? 'invalid_memo')
        return
      }
      memos.upsert(response.data)
      postRecorderState('idle')
      window.postMessage({ data: response.data, type: 'memo:saved' }, '*')
      return
    }
    pendingMemos.set(correlationId, {
      blob,
      fileName: `${correlationId}.webm`,
    })
    const response = await nuiCall('memos:requestUpload', uploadData)
    if (
      generation !== recordingGeneration ||
      currentCorrelationId !== correlationId
    ) {
      return
    }
    if (!response.success) {
      pendingMemos.delete(correlationId)
      currentCorrelationId = ''
      postRecorderState('error', response.error ?? 'request_failed')
    }
  } catch (error) {
    if (generation !== recordingGeneration) return
    console.error('[Memos] Could not finalize audio recording.', error)
    if (currentCorrelationId) pendingMemos.delete(currentCorrelationId)
    currentCorrelationId = ''
    cleanupRecorder(true)
    resetRecordingData()
    postRecorderState('error', 'recording_failed')
  }
}

async function cancelPendingMemo(
  correlationId: string,
  pending: PendingMemo,
): Promise<void> {
  pending.abortController?.abort()
  pendingMemos.delete(correlationId)
  await nuiCall('memos:cancelUpload', {
    correlationId,
    ...(pending.requestId ? { requestId: pending.requestId } : {}),
  })
}

function cancelRecording(): void {
  recordingGeneration += 1
  cleanupRecorder(true)
  resetRecordingData()
  for (const [correlationId, pending] of pendingMemos) {
    void cancelPendingMemo(correlationId, pending)
  }
  pendingMemos.clear()
  currentCorrelationId = ''
  postRecorderState('idle')
}

async function failUpload(requestId: string, error: string): Promise<void> {
  await nuiCall('memos:failUpload', { error, requestId })
}

async function uploadReady(ready: MemoUploadReady): Promise<void> {
  const pending = pendingMemos.get(ready.correlationId)
  if (!pending) {
    await nuiCall('memos:cancelUpload', {
      correlationId: ready.correlationId,
      requestId: ready.requestId,
    })
    return
  }
  pending.requestId = ready.requestId
  const form = new FormData()
  form.append('file', pending.blob, pending.fileName)
  form.append(
    'metadata',
    JSON.stringify({
      captureToken: ready.captureToken,
      purpose: 'memo',
      source: 'sky_phone',
    }),
  )
  const controller = new AbortController()
  pending.abortController = controller
  const timeout = window.setTimeout(
    () => controller.abort(),
    ready.uploadTimeoutMs ?? 25_000,
  )
  try {
    const response = await fetch(ready.presignedUrl, {
      body: form,
      method: 'POST',
      signal: controller.signal,
    })
    const body = (await response.json()) as {
      data?: { id?: string; url?: string }
      id?: string
      url?: string
    }
    const uploaded = body.data ?? body
    if (!response.ok || !uploaded.id || !uploaded.url) {
      throw new Error('upload_failed')
    }
    const complete = await nuiCall('memos:completeUpload', {
      remoteId: uploaded.id,
      requestId: ready.requestId,
      url: uploaded.url,
    })
    if (!complete.success) throw new Error('upload_failed')
  } catch (error) {
    if (controller.signal.aborted && !pendingMemos.has(ready.correlationId)) {
      return
    }
    const errorCode =
      error instanceof DOMException && error.name === 'AbortError'
        ? 'upload_timeout'
        : 'upload_failed'
    console.error('[Memos] Could not upload the audio recording.', error)
    pendingMemos.delete(ready.correlationId)
    await failUpload(ready.requestId, errorCode)
    currentCorrelationId = ''
    postRecorderState('error', errorCode)
  } finally {
    window.clearTimeout(timeout)
  }
}

function resultMemo(data: Record<string, unknown>): MemoDto | null {
  const candidate = data.memo ?? data.data ?? data
  return isMemoDto(candidate) ? candidate : null
}

function uploadResult(data: Record<string, unknown>): void {
  const result = data as Partial<MemoUploadResult>
  const correlationId =
    typeof result.correlationId === 'string' ? result.correlationId : ''
  if (!correlationId) return
  const pending = pendingMemos.get(correlationId)
  pending?.abortController?.abort()
  pendingMemos.delete(correlationId)
  if (currentCorrelationId !== correlationId) return
  currentCorrelationId = ''

  if (result.success) {
    const memo = resultMemo(data)
    if (!memo) {
      console.error('[Memos] Upload result did not contain a valid memo.')
      postRecorderState('error', 'invalid_memo')
      return
    }
    memos.upsert(memo)
    postRecorderState('idle')
    window.postMessage({ data: memo, type: 'memo:saved' }, '*')
    void memos.load()
    return
  }
  postRecorderState(
    'error',
    typeof result.error === 'string' ? result.error : 'upload_failed',
  )
}

function onMessage(event: MessageEvent): void {
  if (!isTrustedRootMessageSource(event.source, window)) return
  const message = event.data as {
    data?: Record<string, unknown>
    type?: string
  }
  const data = message.data ?? {}
  if (message.type === 'memo:recordStart') {
    void startRecording(data)
  } else if (message.type === 'memo:recordPause') {
    pauseRecording()
  } else if (message.type === 'memo:recordResume') {
    resumeRecording()
  } else if (message.type === 'memo:recordStop') {
    void stopRecording(data)
  } else if (message.type === 'memo:recordCancel') {
    cancelRecording()
  } else if (message.type === 'memo:recordStateRequest') {
    postRecorderState(currentState)
  } else if (message.type === 'memos:uploadReady') {
    void uploadReady(data as MemoUploadReady)
  } else if (message.type === 'memos:uploadResult') {
    uploadResult(data)
  }
}

onMounted(() => window.addEventListener('message', onMessage))

watch(
  () => phone.device?.imei ?? null,
  (imei, previousImei) => {
    if (previousImei && imei !== previousImei) cancelRecording()
  },
)

onBeforeUnmount(() => {
  window.removeEventListener('message', onMessage)
  recordingGeneration += 1
  cleanupRecorder(true)
  for (const [correlationId, pending] of pendingMemos) {
    void cancelPendingMemo(correlationId, pending)
  }
  pendingMemos.clear()
})
</script>

<template>
  <span class="phone-memo-recorder" aria-hidden="true"></span>
</template>

<style scoped>
.phone-memo-recorder {
  display: none;
}
</style>
