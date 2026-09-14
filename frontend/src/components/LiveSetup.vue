<script setup lang="ts">
import { computed, onBeforeUnmount, ref } from 'vue'
import { Radio } from 'lucide-vue-next'
import { SkyButton, SkyCard, SkyField, SkyList } from '@/ui'
import { usePhoneStore } from '@/stores/phone'
import { useRealtimeStore } from '@/features/realtime/store'
import type { LiveApp } from '@/features/realtime/types'
import LiveBroadcast from './LiveBroadcast.vue'
const props = defineProps<{ app: LiveApp }>()
const phone = usePhoneStore(),
  realtime = useRealtimeStore()
const title = ref(''),
  description = ref('')
const live = ref<InstanceType<typeof LiveBroadcast> | null>(null)
const valid = computed(() =>
  props.app === 'picstagram'
    ? title.value.trim().length > 0
    : description.value.trim().length > 0,
)
let starting = false
onBeforeUnmount(() => {
  if (starting) realtime.stop()
})
async function start(): Promise<void> {
  if (!valid.value || realtime.busy) return
  const heading =
    props.app === 'picstagram'
      ? title.value.trim()
      : [...description.value.trim()].slice(0, 120).join('')
  starting = true
  try {
    await realtime.startLive(props.app, heading, description.value.trim())
  } finally {
    starting = false
  }
  if (realtime.room?.app === props.app && realtime.room.role === 'host')
    await live.value?.open()
}
</script>
<template>
  <SkyCard class="live-setup">
    <Radio class="live-setup__icon" :size="32" />
    <strong>{{ phone.t('Realtime.goLive') }}</strong>
    <p>{{ phone.t('Realtime.microphoneHelp') }}</p>
    <SkyList>
      <SkyField
        v-if="app === 'picstagram'"
        v-model="title"
        :label="phone.t('Realtime.title')"
        :maxlength="120"
      />
      <SkyField
        v-model="description"
        type="textarea"
        :rows="4"
        :maxlength="1000"
        :label="
          phone.t(
            app === 'picstagram'
              ? 'Realtime.description'
              : 'Apps.fliptok.caption',
          )
        "
        :placeholder="
          phone.t(
            app === 'picstagram'
              ? 'Realtime.descriptionPlaceholder'
              : 'Apps.fliptok.captionPlaceholder',
          )
        "
      />
    </SkyList>
    <SkyButton
      glass
      rounded
      :disabled="!valid || realtime.busy"
      @click="start"
      >{{
        phone.t(realtime.busy ? 'Realtime.connecting' : 'Realtime.goLive')
      }}</SkyButton
    >
    <p v-if="realtime.error" role="alert">
      {{ phone.t('Realtime.errors.default') }}
    </p>
    <LiveBroadcast ref="live" :app="app" hide-trigger />
  </SkyCard>
</template>
<style scoped>
.live-setup {
  display: flex;
  flex-direction: column;
  gap: var(--sky-space-4);
}
.live-setup__icon {
  color: var(--sky-app-accent);
}
.live-setup p {
  margin: 0;
}
</style>
