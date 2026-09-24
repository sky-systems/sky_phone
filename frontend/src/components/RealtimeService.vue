<script setup lang="ts">
import { onBeforeUnmount, watch } from 'vue'
import { useRoute } from 'vue-router'
import { useCallsStore } from '@/stores/calls'
import { usePhoneStore } from '@/stores/phone'
import { useRealtimeStore } from '@/features/realtime/store'
const route = useRoute()
const calls = useCallsStore()
const phone = usePhoneStore()
const realtime = useRealtimeStore()
realtime.initialize()
watch(
  () =>
    calls.activeCall?.state === 'connected' && calls.activeCall.video
      ? calls.activeCall.id
      : null,
  (id) => {
    if (!(import.meta.env.DEV && route.name === 'development-realtime'))
      void realtime.syncCall(id)
  },
  { immediate: true },
)
watch(
  () => phone.isOpen,
  (open) => {
    if (open) void realtime.refreshConfig()
    else realtime.stop()
  },
)
onBeforeUnmount(() => realtime.dispose())
</script>
<template>
  <div
    v-if="realtime.nearbyCount"
    class="realtime-microphone-indicator"
    role="status"
  >
    {{ phone.t('Realtime.contributing') }}
  </div>
</template>
<style scoped>
.realtime-microphone-indicator {
  position: fixed;
  bottom: 12px;
  right: 12px;
  z-index: 30;
  padding: 6px 10px;
  background: var(--sky-surface);
  color: var(--sky-text);
  border-radius: var(--sky-radius-card);
  font-size: 12px;
}
</style>
