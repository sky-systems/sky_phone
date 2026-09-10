<script setup lang="ts">
import {
  FileAudio,
  FileCode2,
  LoaderCircle,
  LockKeyhole,
  Pause,
  Play,
  Plus,
  Trash2,
  Upload,
} from 'lucide-vue-next'
import { computed, onBeforeUnmount, ref } from 'vue'

import { useAdminStore } from '@/stores/admin'
import { usePhoneStore } from '@/stores/phone'
import type { AdminCustomTone } from '@/types/admin'
import { SkyButton } from '@/ui'
import { MAX_CUSTOM_TONE_BYTES, playCustomPhoneTone } from '@/utils/customTones'

const MAX_DURATION_MS = 30_000
const AUDIO_METADATA_TIMEOUT_MS = 8_000
const props = defineProps<{ disabled?: boolean }>()
const emit = defineEmits<{
  toast: [message: string, tone: 'error' | 'success']
}>()
const admin = useAdminStore()
const phone = usePhoneStore()
const fileInput = ref<HTMLInputElement | null>(null)
const fileInputResetKey = ref(0)
const label = ref('')
const toneType = ref<'notification' | 'ringtone'>('ringtone')
const selectedFile = ref<File | null>(null)
const selectedMimeType = ref('')
const selectedDurationMs = ref(0)
const previewUrl = ref('')
const processingFile = ref(false)
const playingToneId = ref('')
const pendingDeleteId = ref('')
let stopPreview: (() => void) | null = null
let previewTimer: number | undefined

const ringtoneTones = computed(() =>
  admin.customTones.filter((tone) => tone.toneType === 'ringtone'),
)
const notificationTones = computed(() =>
  admin.customTones.filter((tone) => tone.toneType === 'notification'),
)
const saving = computed(() => admin.actionKey === 'custom-tone:create')
const canSave = computed(
  () =>
    !props.disabled &&
    !processingFile.value &&
    !saving.value &&
    label.value.trim().length >= 1 &&
    label.value.trim().length <= 64 &&
    !!selectedFile.value &&
    !!selectedMimeType.value &&
    selectedDurationMs.value >= 250 &&
    selectedDurationMs.value <= MAX_DURATION_MS,
)

function t(key: string, params?: Record<string, string>): string {
  return phone.t(`AdminPanel.configurator.customTones.${key}`, params)
}

function errorText(error?: string): string {
  const key = error || admin.error || 'request_failed'
  const translated = phone.t(`AdminPanel.errors.${key}`)
  return translated === `AdminPanel.errors.${key}`
    ? phone.t('AdminPanel.errors.default')
    : translated
}

function normalizedMimeType(file: File): string {
  const aliases: Record<string, string> = {
    'audio/mp3': 'audio/mpeg',
    'audio/x-wav': 'audio/wav',
  }
  const browserType = file.type.toLocaleLowerCase().split(';')[0]
  if (aliases[browserType]) return aliases[browserType]
  if (
    ['audio/mpeg', 'audio/ogg', 'audio/wav', 'audio/webm'].includes(browserType)
  ) {
    return browserType
  }
  const extension = file.name.split('.').pop()?.toLocaleLowerCase()
  return (
    {
      mp3: 'audio/mpeg',
      ogg: 'audio/ogg',
      wav: 'audio/wav',
      webm: 'audio/webm',
    }[extension ?? ''] ?? ''
  )
}

function audioDuration(url: string): Promise<number> {
  return new Promise((resolve, reject) => {
    const audio = new Audio(url)
    audio.preload = 'metadata'
    let settled = false
    const finish = (duration?: number): void => {
      if (settled) return
      settled = true
      window.clearTimeout(timeout)
      audio.removeEventListener('loadedmetadata', handleMetadata)
      audio.removeEventListener('error', handleError)
      audio.removeAttribute('src')
      audio.load()
      if (duration !== undefined && Number.isFinite(duration)) {
        resolve(Math.round(duration * 1000))
      } else {
        reject(new Error('invalid_audio'))
      }
    }
    const handleMetadata = (): void => finish(audio.duration)
    const handleError = (): void => finish()
    const timeout = window.setTimeout(finish, AUDIO_METADATA_TIMEOUT_MS)
    audio.addEventListener('loadedmetadata', handleMetadata, { once: true })
    audio.addEventListener('error', handleError, { once: true })
  })
}

function resetFileInput(target = fileInput.value): void {
  if (target) target.value = ''
  fileInputResetKey.value += 1
}

function releaseSelectedFile(resetInput = true): void {
  if (previewUrl.value) URL.revokeObjectURL(previewUrl.value)
  previewUrl.value = ''
  selectedFile.value = null
  selectedMimeType.value = ''
  selectedDurationMs.value = 0
  if (resetInput) resetFileInput()
}

async function chooseFile(event: Event): Promise<void> {
  const target = event.target
  if (!(target instanceof HTMLInputElement)) return
  const file = target.files?.[0]
  releaseSelectedFile(false)
  resetFileInput(target)
  if (!file) return
  const mimeType = normalizedMimeType(file)
  if (!mimeType) {
    emit('toast', t('errors.type'), 'error')
    return
  }
  if (file.size < 1 || file.size > MAX_CUSTOM_TONE_BYTES) {
    emit('toast', t('errors.size'), 'error')
    return
  }

  processingFile.value = true
  const url = URL.createObjectURL(file)
  try {
    const durationMs = await audioDuration(url)
    if (durationMs < 250 || durationMs > MAX_DURATION_MS) {
      URL.revokeObjectURL(url)
      emit('toast', t('errors.duration'), 'error')
      return
    }
    selectedFile.value = file
    selectedMimeType.value = mimeType
    selectedDurationMs.value = durationMs
    previewUrl.value = url
    if (!label.value.trim()) {
      label.value = file.name.replace(/\.[^.]+$/, '').slice(0, 64)
    }
  } catch (error) {
    URL.revokeObjectURL(url)
    console.error('[Phone admin] Could not read the selected tone.', error)
    emit('toast', t('errors.invalid'), 'error')
  } finally {
    processingFile.value = false
  }
}

function fileBase64(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.addEventListener('load', () => {
      if (typeof reader.result !== 'string') {
        reject(new Error('invalid_audio'))
        return
      }
      const delimiter = reader.result.indexOf(',')
      if (delimiter < 0) {
        reject(new Error('invalid_audio'))
        return
      }
      resolve(reader.result.slice(delimiter + 1))
    })
    reader.addEventListener('error', () => reject(reader.error))
    reader.readAsDataURL(file)
  })
}

function stopActivePreview(): void {
  stopPreview?.()
  stopPreview = null
  playingToneId.value = ''
  if (previewTimer !== undefined) window.clearTimeout(previewTimer)
  previewTimer = undefined
}

function previewSelected(): void {
  if (!previewUrl.value) return
  if (playingToneId.value === 'selected') {
    stopActivePreview()
    return
  }
  stopActivePreview()
  const player = new Audio(previewUrl.value)
  player.volume = 0.75
  player.addEventListener('ended', stopActivePreview, { once: true })
  void player.play().catch((error: unknown) => {
    console.error('[Phone admin] Could not preview selected tone.', error)
    emit('toast', t('errors.playback'), 'error')
  })
  playingToneId.value = 'selected'
  stopPreview = () => {
    player.pause()
    player.currentTime = 0
  }
}

function previewStored(tone: AdminCustomTone): void {
  if (playingToneId.value === tone.id) {
    stopActivePreview()
    return
  }
  stopActivePreview()
  playingToneId.value = tone.id
  stopPreview = playCustomPhoneTone(
    {
      ...tone,
      id: `custom:${tone.id}`,
    },
    75,
    false,
    {
      onError: () => {
        if (playingToneId.value !== tone.id) return
        stopActivePreview()
        emit('toast', t('errors.playback'), 'error')
      },
      onStarted: () => {
        if (playingToneId.value !== tone.id) return
        if (previewTimer !== undefined) window.clearTimeout(previewTimer)
        previewTimer = window.setTimeout(
          stopActivePreview,
          Math.min(MAX_DURATION_MS, tone.durationMs) + 750,
        )
      },
    },
  )
}

async function saveTone(): Promise<void> {
  const file = selectedFile.value
  const name = label.value.trim()
  if (!canSave.value || !file) return
  try {
    const payload = await fileBase64(file)
    const response = await admin.createCustomTone({
      durationMs: selectedDurationMs.value,
      label: name,
      mimeType: selectedMimeType.value,
      payload,
      toneType: toneType.value,
    })
    if (!response.success) {
      emit('toast', errorText(response.error), 'error')
      return
    }
    label.value = ''
    releaseSelectedFile()
    emit('toast', t('saved'), 'success')
  } catch (error) {
    console.error('[Phone admin] Could not prepare the custom tone.', error)
    emit('toast', t('errors.invalid'), 'error')
  }
}

async function deleteTone(tone: AdminCustomTone): Promise<void> {
  if (pendingDeleteId.value !== tone.id) {
    pendingDeleteId.value = tone.id
    return
  }
  stopActivePreview()
  const response = await admin.deleteCustomTone(tone.id)
  pendingDeleteId.value = ''
  if (!response.success) {
    emit('toast', errorText(response.error), 'error')
    return
  }
  emit('toast', t('deleted'), 'success')
}

function formatDuration(durationMs: number): string {
  return `${(durationMs / 1000).toLocaleString(phone.lang, {
    maximumFractionDigits: 1,
  })} s`
}

function formatBytes(byteSize: number): string {
  return `${Math.ceil(byteSize / 1024).toLocaleString(phone.lang)} KB`
}

onBeforeUnmount(() => {
  stopActivePreview()
  releaseSelectedFile(false)
})
</script>

<template>
  <section class="admin-custom-tones">
    <article class="admin-custom-tones__config-note">
      <FileCode2 :size="18" style="--admin-icon-size: 18" />
      <div>
        <strong>{{ t('configTitle') }}</strong>
        <p>{{ t('configBody') }}</p>
        <code>Config.CustomTones · config/custom_tones/</code>
      </div>
    </article>

    <div class="admin-custom-tones__form">
      <label>
        <span>{{ t('name') }}</span>
        <input
          v-model="label"
          type="text"
          maxlength="64"
          autocomplete="off"
          :disabled="disabled || saving"
          :placeholder="t('namePlaceholder')"
        />
      </label>

      <fieldset :disabled="disabled || saving">
        <legend>{{ t('category') }}</legend>
        <button
          type="button"
          :class="{ 'is-active': toneType === 'ringtone' }"
          @click="toneType = 'ringtone'"
        >
          {{ t('ringtone') }}
        </button>
        <button
          type="button"
          :class="{ 'is-active': toneType === 'notification' }"
          @click="toneType = 'notification'"
        >
          {{ t('notification') }}
        </button>
      </fieldset>

      <label
        class="admin-custom-tones__picker"
        :class="{
          'is-disabled': disabled || saving || processingFile,
          'has-file': selectedFile,
        }"
      >
        <input
          :key="fileInputResetKey"
          ref="fileInput"
          class="admin-custom-tones__file-input"
          type="file"
          accept=".mp3,.ogg,.wav,.webm,audio/mpeg,audio/ogg,audio/wav,audio/webm"
          :disabled="disabled || saving || processingFile"
          @change="chooseFile"
        />
        <LoaderCircle
          v-if="processingFile"
          :size="20"
          style="--admin-icon-size: 20"
          class="is-spinning"
        />
        <Upload v-else :size="20" style="--admin-icon-size: 20" />
        <span>
          <strong>{{ selectedFile?.name ?? t('chooseFile') }}</strong>
          <small>
            {{
              selectedFile
                ? `${formatDuration(selectedDurationMs)} · ${formatBytes(selectedFile.size)}`
                : t('fileHint')
            }}
          </small>
        </span>
      </label>

      <div class="admin-custom-tones__actions">
        <SkyButton
          small
          variant="secondary"
          :disabled="!previewUrl || saving"
          @click="previewSelected"
        >
          <Pause
            v-if="playingToneId === 'selected'"
            :size="17"
            style="--admin-icon-size: 17"
          />
          <Play v-else :size="17" style="--admin-icon-size: 17" />
          {{ t('preview') }}
        </SkyButton>
        <SkyButton small :disabled="!canSave" @click="saveTone">
          <LoaderCircle
            v-if="saving"
            :size="17"
            style="--admin-icon-size: 17"
            class="is-spinning"
          />
          <Plus v-else :size="17" style="--admin-icon-size: 17" />
          {{ t('add') }}
        </SkyButton>
      </div>
    </div>

    <div v-if="admin.customTonesLoading" class="admin-custom-tones__loading">
      <LoaderCircle
        :size="22"
        style="--admin-icon-size: 22"
        class="is-spinning"
      />
      {{ t('loading') }}
    </div>
    <div v-else class="admin-custom-tones__catalog">
      <section
        v-for="group in [
          { key: 'ringtone', label: t('ringtones'), tones: ringtoneTones },
          {
            key: 'notification',
            label: t('notifications'),
            tones: notificationTones,
          },
        ]"
        :key="group.key"
      >
        <header>
          <strong>{{ group.label }}</strong>
          <span>{{ group.tones.length }}/32</span>
        </header>
        <p v-if="!group.tones.length" class="admin-custom-tones__empty">
          {{ t('empty') }}
        </p>
        <article v-for="tone in group.tones" :key="tone.id">
          <span class="admin-custom-tones__tone-icon"
            ><FileAudio :size="18" style="--admin-icon-size: 18"
          /></span>
          <span class="admin-custom-tones__tone-copy">
            <strong>{{ tone.label }}</strong>
            <small>
              {{ formatDuration(tone.durationMs) }} ·
              {{ formatBytes(tone.byteSize) }} ·
              {{
                tone.source === 'config' ? t('configSource') : tone.createdBy
              }}
            </small>
          </span>
          <button
            type="button"
            :aria-label="t('preview')"
            @click="previewStored(tone)"
          >
            <Pause
              v-if="playingToneId === tone.id"
              :size="17"
              style="--admin-icon-size: 17"
            />
            <Play v-else :size="17" style="--admin-icon-size: 17" />
          </button>
          <button
            v-if="tone.source === 'database'"
            type="button"
            class="is-danger"
            :class="{ 'is-confirming': pendingDeleteId === tone.id }"
            :aria-label="
              pendingDeleteId === tone.id ? t('confirmDelete') : t('delete')
            "
            :disabled="admin.actionKey === `custom-tone:delete:${tone.id}`"
            @click="deleteTone(tone)"
          >
            <LoaderCircle
              v-if="admin.actionKey === `custom-tone:delete:${tone.id}`"
              :size="17"
              style="--admin-icon-size: 17"
              class="is-spinning"
            />
            <Trash2 v-else :size="17" style="--admin-icon-size: 17" />
          </button>
          <span
            v-else
            class="admin-custom-tones__locked"
            :title="t('configManaged')"
            :aria-label="t('configManaged')"
          >
            <LockKeyhole :size="15" style="--admin-icon-size: 15" />
          </span>
        </article>
      </section>
    </div>
  </section>
</template>

<style scoped>
.admin-custom-tones {
  --sky-app-accent: var(--admin-green, #5ccb70);
  --sky-button-text: #fff;
  --sky-surface-muted: #1b1e1b;
  --sky-text: #fff;

  display: grid;
  gap: calc(8 * var(--admin-unit));
  color: var(--admin-text, #f0f3f0);
}

.admin-custom-tones__config-note {
  display: grid;
  grid-template-columns: calc(26 * var(--admin-unit)) minmax(0, 1fr);
  align-items: start;
  gap: calc(9 * var(--admin-unit));
  padding: calc(10 * var(--admin-unit)) calc(11 * var(--admin-unit));
  border-radius: calc(3 * var(--admin-unit));
  background: linear-gradient(90deg, rgb(0 184 228 / 11%), transparent 82%);
}

.admin-custom-tones__config-note > svg {
  color: var(--admin-accent, #00b8e4);
}

.admin-custom-tones__config-note div {
  display: grid;
  gap: calc(3 * var(--admin-unit));
}

.admin-custom-tones__config-note strong {
  font-size: calc(10 * var(--admin-unit));
}

.admin-custom-tones__config-note p {
  margin: 0;
  color: var(--admin-muted, #818781);
  font-size: calc(9 * var(--admin-unit));
  line-height: 1.45;
}

.admin-custom-tones__config-note code {
  width: fit-content;
  margin-top: calc(2 * var(--admin-unit));
  padding: calc(3 * var(--admin-unit)) calc(5 * var(--admin-unit));
  border-radius: calc(3 * var(--admin-unit));
  color: #8edcf0;
  background: rgb(0 0 0 / 25%);
  font-size: calc(8 * var(--admin-unit));
}

.admin-custom-tones__tone-icon {
  display: grid;
  place-items: center;
  flex: 0 0 calc(40 * var(--admin-unit));
  width: calc(40 * var(--admin-unit));
  height: calc(40 * var(--admin-unit));
  border-radius: calc(10 * var(--admin-unit));
  background: rgb(0 194 255 / 10%);
  color: #14c9ff;
}

.admin-custom-tones__empty {
  margin: calc(4 * var(--admin-unit)) 0 0;
  color: #8f9994;
  font-size: calc(12 * var(--admin-unit));
  line-height: 1.5;
}

.admin-custom-tones__form {
  display: grid;
  grid-template-columns: minmax(calc(220 * var(--admin-unit)), 1fr) minmax(
      calc(230 * var(--admin-unit)),
      0.8fr
    );
  gap: calc(8 * var(--admin-unit));
  padding: calc(10 * var(--admin-unit));
  border: calc(1 * var(--admin-unit)) solid
    var(--admin-border, rgb(255 255 255 / 5%));
  border-radius: calc(3 * var(--admin-unit));
  background: var(--admin-panel-raised, #131514);
}

.admin-custom-tones__form label,
.admin-custom-tones__form fieldset {
  display: grid;
  gap: calc(7 * var(--admin-unit));
  min-width: 0;
  margin: 0;
  padding: 0;
  border: 0;
}

.admin-custom-tones__form label > span,
.admin-custom-tones__form legend {
  color: #aab3af;
  font-size: calc(8 * var(--admin-unit));
  font-weight: 700;
  letter-spacing: 0.05em;
  text-transform: uppercase;
}

.admin-custom-tones__form input[type='text'] {
  min-height: calc(36 * var(--admin-unit));
  padding: 0 calc(10 * var(--admin-unit));
  border: calc(1 * var(--admin-unit)) solid
    var(--admin-border-strong, rgb(255 255 255 / 9%));
  border-radius: calc(4 * var(--admin-unit));
  outline: none;
  background: #1b1e1b;
  color: #fff;
  font-size: calc(10 * var(--admin-unit));
}

.admin-custom-tones__form input[type='text']:focus {
  border-color: #14c9ff;
  box-shadow: 0 0 0 calc(2 * var(--admin-unit)) rgb(20 201 255 / 14%);
}

.admin-custom-tones__form fieldset {
  grid-template-columns: 1fr 1fr;
}

.admin-custom-tones__form legend {
  grid-column: 1 / -1;
}

.admin-custom-tones__form fieldset button {
  min-height: calc(36 * var(--admin-unit));
  border: calc(1 * var(--admin-unit)) solid
    var(--admin-border-strong, rgb(255 255 255 / 9%));
  border-radius: calc(4 * var(--admin-unit));
  background: #1b1e1b;
  color: #b7c0bc;
  font-size: calc(10 * var(--admin-unit));
  font-weight: 700;
}

.admin-custom-tones__form fieldset button.is-active {
  border-color: #14c9ff;
  background: rgb(20 201 255 / 12%);
  color: #fff;
}

.admin-custom-tones__file-input {
  position: absolute;
  z-index: 3;
  inset: 0;
  width: 100%;
  height: 100%;
  margin: 0;
  opacity: 0;
  cursor: pointer;
}

.admin-custom-tones__form .admin-custom-tones__picker {
  position: relative;
  display: flex;
  grid-column: 1 / -1;
  gap: calc(12 * var(--admin-unit));
  align-items: center;
  min-height: calc(52 * var(--admin-unit));
  padding: calc(8 * var(--admin-unit)) calc(11 * var(--admin-unit));
  border: calc(1 * var(--admin-unit)) dashed
    var(--admin-border-strong, rgb(255 255 255 / 9%));
  border-radius: calc(4 * var(--admin-unit));
  background: #111311;
  color: #dfe7e3;
  text-align: left;
}

.admin-custom-tones__picker:focus-within,
.admin-custom-tones__picker:hover:not(.is-disabled) {
  border-color: var(--admin-accent, #00b8e4);
  background: rgb(0 184 228 / 6%);
}

.admin-custom-tones__picker.is-disabled {
  opacity: 0.45;
}

.admin-custom-tones__picker > span,
.admin-custom-tones__tone-copy {
  display: grid;
  gap: calc(3 * var(--admin-unit));
  min-width: 0;
}

.admin-custom-tones__picker strong,
.admin-custom-tones__tone-copy strong {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: calc(10 * var(--admin-unit));
}

.admin-custom-tones__picker small,
.admin-custom-tones__tone-copy small {
  color: #89938e;
  font-size: calc(8 * var(--admin-unit));
}

.admin-custom-tones__actions {
  display: flex;
  grid-column: 1 / -1;
  gap: calc(10 * var(--admin-unit));
  justify-content: flex-end;
}

.admin-custom-tones__actions :deep(.sky-button) {
  flex: 1 1 0;
  border-color: var(--admin-border-strong, rgb(255 255 255 / 9%));
  font-size: calc(10 * var(--admin-unit));
}

.admin-custom-tones__catalog {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: calc(12 * var(--admin-unit));
}

.admin-custom-tones__catalog > section {
  overflow: hidden;
  border: calc(1 * var(--admin-unit)) solid rgb(255 255 255 / 7%);
  border-radius: calc(3 * var(--admin-unit));
  background: #111311;
}

.admin-custom-tones__catalog > section > header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: calc(44 * var(--admin-unit));
  padding: 0 calc(10 * var(--admin-unit));
  border-bottom: calc(1 * var(--admin-unit)) solid rgb(255 255 255 / 7%);
}

.admin-custom-tones__catalog > section > header span {
  color: #82908a;
  font-size: calc(11 * var(--admin-unit));
}

.admin-custom-tones__catalog > section > header strong {
  font-size: calc(10 * var(--admin-unit));
}

.admin-custom-tones__catalog article {
  display: flex;
  gap: calc(10 * var(--admin-unit));
  align-items: center;
  min-height: calc(54 * var(--admin-unit));
  padding: calc(8 * var(--admin-unit)) calc(10 * var(--admin-unit));
  border-bottom: calc(1 * var(--admin-unit)) solid rgb(255 255 255 / 5%);
}

.admin-custom-tones__catalog article:last-child {
  border-bottom: 0;
}

.admin-custom-tones__tone-icon {
  flex-basis: calc(30 * var(--admin-unit));
  width: calc(30 * var(--admin-unit));
  height: calc(30 * var(--admin-unit));
  border-radius: calc(5 * var(--admin-unit));
}

.admin-custom-tones__tone-copy {
  flex: 1;
}

.admin-custom-tones__catalog article > button {
  display: grid;
  place-items: center;
  flex: 0 0 calc(32 * var(--admin-unit));
  width: calc(32 * var(--admin-unit));
  height: calc(32 * var(--admin-unit));
  border: calc(1 * var(--admin-unit)) solid
    var(--admin-border-strong, rgb(255 255 255 / 9%));
  border-radius: calc(4 * var(--admin-unit));
  background: #151a18;
  color: #dfe7e3;
}

.admin-custom-tones__locked {
  display: grid;
  place-items: center;
  flex: 0 0 calc(32 * var(--admin-unit));
  width: calc(32 * var(--admin-unit));
  height: calc(32 * var(--admin-unit));
  color: var(--admin-dim, #555b55);
}

.admin-custom-tones__catalog article > button.is-danger {
  color: #ff6875;
}

.admin-custom-tones__catalog article > button.is-confirming {
  border-color: #ff5263;
  background: rgb(255 82 99 / 14%);
}

.admin-custom-tones__empty,
.admin-custom-tones__loading {
  padding: calc(18 * var(--admin-unit)) calc(13 * var(--admin-unit));
}

.admin-custom-tones__loading {
  display: flex;
  gap: calc(10 * var(--admin-unit));
  align-items: center;
  color: #98a39e;
}

.is-spinning {
  animation: admin-custom-tone-spin 0.8s linear infinite;
}

@keyframes admin-custom-tone-spin {
  to {
    transform: rotate(360deg);
  }
}

@media (max-width: 900px) {
  .admin-custom-tones__form,
  .admin-custom-tones__catalog {
    grid-template-columns: 1fr;
  }
}
</style>
