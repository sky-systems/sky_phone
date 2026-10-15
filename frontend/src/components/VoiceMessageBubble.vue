<script setup lang="ts">
import { SkyButton, SkyIcon } from '@/ui'

import { Pause, Play } from 'lucide-vue-next'
import { computed, nextTick, onBeforeUnmount, ref } from 'vue'

import { useMessagesStore } from '@/stores/messages'
import { usePhoneStore } from '@/stores/phone'
import type { SmsMessage } from '@/types/messages'
import { SkyRange } from '@/ui'

const props = defineProps<{ message: SmsMessage }>()
const phone = usePhoneStore()
const messages = useMessagesStore()
const audio = ref<HTMLAudioElement>()
const currentTime = ref(0)
const playing = ref(false)
const loading = ref(false)
const failed = ref(false)
const metadataDuration = ref(0)
let sourceLoadPromise: Promise<boolean> | undefined
const duration = computed(
  () => metadataDuration.value || (props.message.media_duration_ms ?? 0) / 1000,
)
const progress = computed(() =>
  duration.value > 0 ? Math.min(1, currentTime.value / duration.value) : 0,
)
const displayTime = computed(() =>
  formatDuration(
    playing.value || currentTime.value > 0 ? currentTime.value : duration.value,
  ),
)
const seekValueText = computed(() => formatDuration(currentTime.value))
const source = computed(() => messages.mediaSources[props.message.id] ?? '')

function formatDuration(seconds: number): string {
  const rounded = Math.max(0, Math.floor(seconds))
  return `${Math.floor(rounded / 60)}:${String(rounded % 60).padStart(2, '0')}`
}

async function ensureSource(): Promise<boolean> {
  if (source.value) return Boolean(audio.value)
  if (!sourceLoadPromise) {
    loading.value = true
    sourceLoadPromise = (async () => {
      const loaded = await messages.loadMedia(props.message.id)
      if (!loaded) {
        failed.value = true
        return false
      }
      await nextTick()
      return Boolean(audio.value && source.value)
    })().finally(() => {
      loading.value = false
      sourceLoadPromise = undefined
    })
  }
  return sourceLoadPromise
}

async function togglePlayback(): Promise<void> {
  if (loading.value) return
  failed.value = false
  if (playing.value) {
    audio.value?.pause()
    return
  }
  if (!(await ensureSource())) return
  try {
    await audio.value?.play()
  } catch (error) {
    failed.value = true
    console.error(
      `[Messages] Could not play audio message ${props.message.id}:`,
      error,
    )
  }
}

async function seekPlayback(event: Event): Promise<void> {
  const value = Number((event.target as HTMLInputElement).value)
  failed.value = false
  if (!Number.isFinite(value) || !(await ensureSource()) || !audio.value) return
  const nextTime = Math.min(duration.value, Math.max(0, value))
  audio.value.currentTime = nextTime
  currentTime.value = nextTime
}

function updateProgress(): void {
  currentTime.value = audio.value?.currentTime ?? 0
}

function finishPlayback(): void {
  playing.value = false
  currentTime.value = 0
}

function updateDuration(): void {
  const value = audio.value?.duration ?? 0
  if (Number.isFinite(value) && value > 0) metadataDuration.value = value
}

onBeforeUnmount(() => audio.value?.pause())
</script>

<template>
  <div class="voice-message" :class="{ 'voice-message--failed': failed }">
    <SkyButton
      variant="content"
      type="button"
      class="voice-message__play"
      :disabled="loading"
      :aria-label="
        phone.t(
          playing ? 'Apps.messages.pauseAudio' : 'Apps.messages.playAudio',
        )
      "
      @click="togglePlayback"
    >
      <span v-if="loading" class="voice-message__loader" />
      <SkyIcon
        :icon="Pause"
        v-else-if="playing"
        :size="16"
        fill="currentColor"
      />
      <SkyIcon :icon="Play" v-else :size="16" fill="currentColor" />
    </SkyButton>
    <div class="voice-message__content">
      <div class="voice-message__timeline">
        <div class="voice-message__waveform" aria-hidden="true">
          <i
            v-for="(sample, index) in message.media_waveform ?? []"
            :key="index"
            :class="{
              active:
                index /
                  Math.max(1, (message.media_waveform?.length ?? 1) - 1) <=
                progress,
            }"
            :style="{ height: `${Math.max(4, sample * 22)}px` }"
          />
        </div>
        <SkyRange
          class="voice-message__range"
          :model-value="currentTime"
          :min="0"
          :max="Math.max(0.1, duration)"
          :step="0.1"
          :aria-label="phone.t('Apps.messages.seekAudio')"
          :aria-value-text="seekValueText"
          @input="seekPlayback"
        />
      </div>
      <span>{{ displayTime }}</span>
    </div>
    <audio
      ref="audio"
      :src="source"
      preload="metadata"
      @loadedmetadata="updateDuration"
      @play="playing = true"
      @pause="playing = false"
      @timeupdate="updateProgress"
      @ended="finishPlayback"
      @error="failed = true"
    />
  </div>
</template>

<style scoped>
.voice-message__timeline {
  position: relative;
  min-width: 0;
  height: 24px;
}

.voice-message__waveform {
  min-width: 0;
  overflow: hidden;
  gap: 1px;
  pointer-events: none;
}

.voice-message__waveform i {
  width: auto;
  min-width: 1px;
  flex: 1 1 1px;
}

.voice-message__range {
  position: absolute;
  inset: 0;
  cursor: pointer;
}

.voice-message__range :deep(.sky-range__input) {
  width: 100%;
  height: 24px;
  opacity: 0;
  cursor: pointer;
}

.voice-message__timeline:focus-within {
  border-radius: var(--sky-radius-pill);
  outline: 2px solid currentColor;
  outline-offset: 2px;
}
</style>
