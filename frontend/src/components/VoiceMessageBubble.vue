<script setup lang="ts">
import { Pause, Play } from 'lucide-vue-next'
import { computed, nextTick, onBeforeUnmount, ref } from 'vue'

import { useMessagesStore } from '@/stores/messages'
import { usePhoneStore } from '@/stores/phone'
import type { SmsMessage } from '@/types/messages'

const props = defineProps<{ message: SmsMessage }>()
const phone = usePhoneStore()
const messages = useMessagesStore()
const audio = ref<HTMLAudioElement>()
const currentTime = ref(0)
const playing = ref(false)
const loading = ref(false)
const failed = ref(false)
const duration = computed(() => (props.message.media_duration_ms ?? 0) / 1000)
const progress = computed(() =>
  duration.value > 0 ? Math.min(1, currentTime.value / duration.value) : 0,
)
const displayTime = computed(() =>
  formatDuration(playing.value || currentTime.value > 0 ? currentTime.value : duration.value),
)
const source = computed(() => messages.mediaSources[props.message.id] ?? '')

function formatDuration(seconds: number): string {
  const rounded = Math.max(0, Math.floor(seconds))
  return `${Math.floor(rounded / 60)}:${String(rounded % 60).padStart(2, '0')}`
}

async function togglePlayback(): Promise<void> {
  if (loading.value) return
  failed.value = false
  if (playing.value) {
    audio.value?.pause()
    return
  }
  if (!source.value) {
    loading.value = true
    const loaded = await messages.loadMedia(props.message.id)
    loading.value = false
    if (!loaded) {
      failed.value = true
      return
    }
    await nextTick()
  }
  try {
    await audio.value?.play()
  } catch (error) {
    failed.value = true
    console.error(`[Messages] Could not play audio message ${props.message.id}:`, error)
  }
}

function updateProgress(): void {
  currentTime.value = audio.value?.currentTime ?? 0
}

function finishPlayback(): void {
  playing.value = false
  currentTime.value = 0
}

onBeforeUnmount(() => audio.value?.pause())
</script>

<template>
  <div class="voice-message" :class="{ 'voice-message--failed': failed }">
    <button
      type="button"
      class="voice-message__play"
      :disabled="loading"
      :aria-label="phone.t(playing ? 'Apps.messages.pauseAudio' : 'Apps.messages.playAudio')"
      @click="togglePlayback"
    >
      <span v-if="loading" class="voice-message__loader" />
      <Pause v-else-if="playing" :size="16" fill="currentColor" />
      <Play v-else :size="16" fill="currentColor" />
    </button>
    <div class="voice-message__content">
      <div class="voice-message__waveform" aria-hidden="true">
        <i
          v-for="(sample, index) in message.media_waveform ?? []"
          :key="index"
          :class="{ active: index / Math.max(1, (message.media_waveform?.length ?? 1) - 1) <= progress }"
          :style="{ height: `${Math.max(4, sample * 22)}px` }"
        />
      </div>
      <span>{{ displayTime }}</span>
    </div>
    <audio
      ref="audio"
      :src="source"
      preload="metadata"
      @play="playing = true"
      @pause="playing = false"
      @timeupdate="updateProgress"
      @ended="finishPlayback"
      @error="failed = true"
    />
  </div>
</template>
