<script setup lang="ts">
import { SkyButton } from '@/ui'
import { usePhoneStore } from '@/stores/phone'
import type { LiveEntry } from '@/features/realtime/types'
defineProps<{ entries: LiveEntry[] }>()
const emit = defineEmits<{ join: [profileId: string] }>()
const phone = usePhoneStore()
</script>
<template>
  <div
    v-if="entries.length"
    class="live-profiles"
    :aria-label="phone.t('Realtime.live')"
  >
    <SkyButton
      v-for="entry in entries"
      :key="entry.id"
      clear
      class="live-profiles__entry"
      :aria-label="phone.t('Realtime.joinLive', { name: entry.hostName })"
      @click="entry.profileId && emit('join', entry.profileId)"
    >
      <span class="live-profiles__avatar"
        ><img v-if="entry.hostAvatar" :src="entry.hostAvatar" alt="" /><span
          v-else
          >{{ entry.hostName.slice(0, 1) }}</span
        ><b>{{ phone.t('Realtime.live') }}</b></span
      >
      <small>{{ entry.hostName }}</small>
    </SkyButton>
  </div>
</template>
<style scoped>
.live-profiles {
  display: flex;
  gap: var(--sky-space-3);
  flex-shrink: 0;
  padding: var(--sky-space-2) var(--sky-space-1);
  overflow-x: auto;
  scrollbar-width: none;
}
.live-profiles__entry.sky-button {
  display: flex;
  flex-direction: column;
  flex: 0 0 68px;
  width: 68px;
  height: auto;
  gap: var(--sky-space-2);
  padding: 0;
  color: var(--sky-text);
  overflow: visible;
}
.live-profiles__avatar {
  position: relative;
  display: grid;
  place-items: center;
  width: 58px;
  height: 58px;
  border: 2px solid var(--sky-danger);
  border-radius: var(--sky-radius-pill);
  padding: 3px;
  box-shadow: 0 0 12px var(--sky-danger-soft);
  background: var(--sky-surface-variant);
  font-size: var(--sky-font-medium-title);
}
.live-profiles__avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  border-radius: inherit;
}
.live-profiles__avatar b {
  position: absolute;
  bottom: -5px;
  left: 50%;
  transform: translateX(-50%);
  padding: 2px var(--sky-space-1);
  border: 2px solid var(--sky-surface);
  border-radius: var(--sky-radius-control);
  color: var(--sky-action-surface);
  background: var(--sky-danger);
  font-size: 9px;
  letter-spacing: 0.4px;
}
.live-profiles__entry small {
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: var(--sky-font-caption);
  font-weight: 500;
}
</style>
