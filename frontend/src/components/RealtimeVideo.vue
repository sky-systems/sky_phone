<script setup lang="ts">
import { onBeforeUnmount, ref, watch } from 'vue'
const props = withDefaults(
  defineProps<{ stream: MediaStream | null; muted?: boolean }>(),
  { muted: false },
)
const video = ref<HTMLVideoElement | null>(null)
watch(
  [video, () => props.stream],
  () => {
    if (!video.value) return
    video.value.srcObject = props.stream
    if (props.stream)
      void video.value
        .play()
        .catch(() =>
          console.warn('[sky_phone] Live video autoplay was blocked.'),
        )
  },
  { flush: 'post' },
)
onBeforeUnmount(() => {
  if (video.value) {
    video.value.pause()
    video.value.srcObject = null
  }
})
</script>
<template><video ref="video" autoplay playsinline :muted="muted" /></template>
