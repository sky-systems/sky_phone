<script setup lang="ts">
import { Camera, Pause, Play } from 'lucide-vue-next'
import { computed, ref } from 'vue'

import type { SmsMessageType } from '@/types/messages'

type MessageAttachment = {
  media_asset_id: string | null
  media_duration_ms: number | null
  message_type: SmsMessageType
}

const props = defineProps<{ message: MessageAttachment }>()
const playing = ref(false)
const video = ref<HTMLVideoElement>()

const imageStyles: Record<string, string> = {
  'camera-1': 'linear-gradient(145deg, #ff6b6b, #845ec2 52%, #0f2027)',
  'camera-2': 'linear-gradient(150deg, #00c9a7, #4d8076 46%, #1f3a5f)',
  'camera-3': 'linear-gradient(135deg, #ffc75f, #f96d80 48%, #4b4453)',
  'city-lights': 'linear-gradient(135deg, #fbc2eb, #a6c1ee 48%, #302b63)',
  'desert-road': 'linear-gradient(150deg, #f6d365, #fda085 45%, #512b58)',
  'ocean-air': 'linear-gradient(160deg, #67d5b5, #26648e 55%, #0b132b)',
  'sunset-drive': 'linear-gradient(145deg, #ff9a62, #5f2c82 58%, #141e30)',
}
const videoStyles: Record<string, string> = {
  'city-loop': 'linear-gradient(135deg, #302b63, #a6c1ee 48%, #fbc2eb)',
  'ocean-loop': 'linear-gradient(145deg, #0b132b, #26648e 55%, #67d5b5)',
  'sunset-loop': 'linear-gradient(145deg, #141e30, #5f2c82 55%, #ff9a62)',
}
const gifContent: Record<string, { emoji: string; label: string }> = {
  celebrate: { emoji: '🎉', label: 'Celebrate!' },
  hearts: { emoji: '💖', label: 'Love it' },
  party: { emoji: '🥳', label: 'Party time' },
  thumbs_up: { emoji: '👍', label: 'Perfect' },
  wow: { emoji: '🤯', label: 'WOW' },
}

const background = computed(() =>
  props.message.message_type === 'video'
    ? videoStyles[props.message.media_asset_id ?? '']
    : imageStyles[props.message.media_asset_id ?? ''],
)
const gif = computed(
  () => gifContent[props.message.media_asset_id ?? ''] ?? gifContent.wow,
)
const mediaUrl = computed(() =>
  props.message.media_asset_id?.startsWith('https://')
    ? props.message.media_asset_id
    : '',
)

async function toggleVideo(): Promise<void> {
  if (!video.value) {
    playing.value = !playing.value
    return
  }
  if (video.value.paused) await video.value.play()
  else video.value.pause()
  playing.value = !video.value.paused
}

function durationLabel(milliseconds: number | null): string {
  const seconds = Math.max(0, Math.floor((milliseconds ?? 0) / 1000))
  return `0:${String(seconds).padStart(2, '0')}`
}
</script>

<template>
  <div
    v-if="message.message_type === 'image'"
    class="messages-attachment messages-attachment--image"
    :style="{ background }"
  >
    <img
      v-if="mediaUrl"
      :src="mediaUrl"
      alt=""
      loading="lazy"
      referrerpolicy="no-referrer"
    />
    <Camera v-else :size="18" />
  </div>
  <button
    v-else-if="message.message_type === 'video'"
    type="button"
    class="messages-attachment messages-attachment--video"
    :class="{ playing }"
    :style="{ background }"
    @click="toggleVideo"
  >
    <video
      v-if="mediaUrl"
      ref="video"
      :src="mediaUrl"
      playsinline
      preload="metadata"
      @ended="playing = false"
    />
    <span
      ><Pause v-if="playing" :size="22" fill="currentColor" /><Play
        v-else
        :size="22"
        fill="currentColor"
    /></span>
    <small>{{ durationLabel(message.media_duration_ms) }}</small>
  </button>
  <div v-else class="messages-attachment messages-attachment--gif">
    <img
      v-if="mediaUrl"
      :src="mediaUrl"
      alt="GIF"
      loading="lazy"
      referrerpolicy="no-referrer"
    />
    <template v-else>
      <span>{{ gif.emoji }}</span>
      <strong>{{ gif.label }}</strong>
    </template>
  </div>
</template>
