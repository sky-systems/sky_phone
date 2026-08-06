<script setup lang="ts">
import { Pause, Play } from 'lucide-vue-next'
import { computed, nextTick, onBeforeUnmount, ref } from 'vue'

import { useDarkChatStore } from '@/stores/darkchat'
import type { DarkChatMessage } from '@/types/darkchat'

const props = defineProps<{ message: DarkChatMessage }>()
const darkchat = useDarkChatStore()
const audio = ref<HTMLAudioElement>()
const currentTime = ref(0)
const playing = ref(false)
const loading = ref(false)
const failed = ref(false)
const speed = ref<1 | 1.5 | 2>(1)
const duration = computed(() => (props.message.mediaDurationMs ?? 0) / 1000)
const progress = computed(() =>
  duration.value > 0 ? Math.min(1, currentTime.value / duration.value) : 0,
)
const source = computed(() => darkchat.mediaSources[props.message.id] ?? '')
const displayTime = computed(() => {
  const seconds = Math.max(0, Math.floor(playing.value || currentTime.value ? currentTime.value : duration.value))
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`
})

async function togglePlayback(): Promise<void> {
  if (loading.value) return
  failed.value = false
  if (playing.value) {
    audio.value?.pause()
    return
  }
  if (!source.value) {
    loading.value = true
    const loaded = await darkchat.loadMedia(props.message.id)
    loading.value = false
    if (!loaded) {
      failed.value = true
      return
    }
    await nextTick()
  }
  if (audio.value) audio.value.playbackRate = speed.value
  try {
    await audio.value?.play()
  }
  catch (error) {
    failed.value = true
    console.error(`[DarkChat] Could not play voice message ${props.message.id}:`, error)
  }
}

function cycleSpeed(): void {
  speed.value = speed.value === 1 ? 1.5 : speed.value === 1.5 ? 2 : 1
  if (audio.value) audio.value.playbackRate = speed.value
}

function finish(): void {
  playing.value = false
  currentTime.value = 0
}

onBeforeUnmount(() => audio.value?.pause())
</script>

<template>
  <div class="darkchat-voice" :class="{ 'darkchat-voice--failed': failed }">
    <button type="button" :disabled="loading" @click="togglePlayback">
      <span v-if="loading" class="darkchat-loader darkchat-loader--small" />
      <Pause v-else-if="playing" :size="15" fill="currentColor" />
      <Play v-else :size="15" fill="currentColor" />
    </button>
    <div>
      <span class="darkchat-voice__wave" aria-hidden="true">
        <i
          v-for="(sample, index) in message.mediaWaveform ?? []"
          :key="index"
          :class="{ active: index / Math.max(1, (message.mediaWaveform?.length ?? 1) - 1) <= progress }"
          :style="{ height: `${Math.max(3, sample * 21)}px` }"
        />
      </span>
      <small>{{ displayTime }}</small>
    </div>
    <button type="button" class="darkchat-voice__speed" @click="cycleSpeed">{{ speed }}×</button>
    <audio
      ref="audio"
      :src="source"
      preload="metadata"
      @play="playing = true"
      @pause="playing = false"
      @timeupdate="currentTime = audio?.currentTime ?? 0"
      @ended="finish"
      @error="failed = true"
    />
  </div>
</template>
