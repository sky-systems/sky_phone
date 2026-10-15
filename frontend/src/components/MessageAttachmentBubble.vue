<script setup lang="ts">
import { SkyButton, SkyIcon } from '@/ui'

import { Camera, Pause, Play, TriangleAlert } from 'lucide-vue-next'
import { computed, ref } from 'vue'

import { usePhoneStore } from '@/stores/phone'
import type { SmsMessageType } from '@/types/messages'

type MessageAttachment = {
  body?: string
  media_asset_id: string | null
  media_duration_ms: number | null
  message_type: SmsMessageType
}

const props = defineProps<{ message: MessageAttachment }>()
const phone = usePhoneStore()
const playing = ref(false)
const playbackFailed = ref(false)
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
const gifContent: Record<string, { emoji: string; key: string }> = {
  celebrate: { emoji: '🎉', key: 'celebrate' },
  hearts: { emoji: '💖', key: 'hearts' },
  party: { emoji: '🥳', key: 'party' },
  thumbs_up: { emoji: '👍', key: 'thumbsUp' },
  wow: { emoji: '🤯', key: 'wow' },
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
  if (!video.value.paused) {
    video.value.pause()
    return
  }
  playbackFailed.value = false
  try {
    await video.value.play()
  } catch (error) {
    playing.value = false
    playbackFailed.value = true
    console.error('[Messages] Could not play the attached video.', error)
  }
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
    role="img"
    :aria-label="phone.t('Apps.photos.photoAlt')"
    :style="{ background }"
  >
    <img
      v-if="mediaUrl"
      :src="mediaUrl"
      alt=""
      loading="lazy"
      referrerpolicy="no-referrer"
    />
    <SkyIcon :icon="Camera" v-else :size="18" />
  </div>
  <SkyButton
    variant="content"
    v-else-if="message.message_type === 'video'"
    type="button"
    class="messages-attachment messages-attachment--video"
    :class="{ playing, 'messages-attachment--failed': playbackFailed }"
    :style="{ background }"
    :aria-label="
      playbackFailed
        ? phone.t('Apps.photos.errors.unsupported')
        : phone.t('Apps.photos.videoAlt')
    "
    @click="toggleVideo"
  >
    <video
      v-if="mediaUrl"
      ref="video"
      :src="mediaUrl"
      playsinline
      preload="metadata"
      @play="playing = true"
      @pause="playing = false"
      @ended="playing = false"
      @error="playbackFailed = true"
    />
    <span
      ><SkyIcon
        :icon="TriangleAlert"
        v-if="playbackFailed"
        :size="22" /><SkyIcon
        :icon="Pause"
        v-else-if="playing"
        :size="22"
        fill="currentColor" /><SkyIcon
        :icon="Play"
        v-else
        :size="22"
        fill="currentColor"
    /></span>
    <small v-if="playbackFailed">{{
      phone.t('Apps.photos.errors.unsupported')
    }}</small>
    <small v-else>{{ durationLabel(message.media_duration_ms) }}</small>
  </SkyButton>
  <div
    v-else
    class="messages-attachment messages-attachment--gif"
    :class="{ 'messages-attachment--remote': mediaUrl }"
  >
    <img
      v-if="mediaUrl"
      :src="mediaUrl"
      :alt="phone.t('Apps.messages.gif')"
      loading="lazy"
      referrerpolicy="no-referrer"
    />
    <template v-else>
      <span>{{ gif.emoji }}</span>
      <strong>{{ phone.t(`Apps.messages.gifLabels.${gif.key}`) }}</strong>
    </template>
  </div>
  <p v-if="message.body?.trim()" class="messages-attachment-caption">
    {{ message.body }}
  </p>
</template>

<style scoped>
.messages-attachment-caption {
  max-width: 205px;
  margin: 7px 1px 1px;
  overflow-wrap: anywhere;
  white-space: pre-wrap;
}
</style>
