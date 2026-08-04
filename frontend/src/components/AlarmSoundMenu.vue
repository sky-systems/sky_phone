<script setup lang="ts">
import { kList, kListItem, kNavbar, kNavbarBackLink } from 'konsta/vue'
import { Check } from 'lucide-vue-next'
import { onBeforeUnmount } from 'vue'

import { usePhoneStore } from '@/stores/phone'
import { ALARM_SOUND_IDS, type AlarmSoundId } from '@/utils/alarms'
import { phoneToneDuration, playPhoneTone } from '@/utils/tones'

defineProps<{ backLabel: string; selectedSound: AlarmSoundId }>()
const emit = defineEmits<{
  close: []
  select: [sound: AlarmSoundId]
}>()
const phone = usePhoneStore()
let stopPreview: (() => void) | undefined
let previewTimer: ReturnType<typeof setTimeout> | undefined

function stopSoundPreview(): void {
  if (previewTimer) clearTimeout(previewTimer)
  previewTimer = undefined
  stopPreview?.()
  stopPreview = undefined
}

function selectSound(sound: AlarmSoundId): void {
  stopSoundPreview()
  emit('select', sound)
  stopPreview = playPhoneTone(
    sound,
    phone.preferences.settings.ringtoneVolume,
    false,
  )
  previewTimer = setTimeout(stopSoundPreview, phoneToneDuration(sound) + 100)
}

onBeforeUnmount(stopSoundPreview)
</script>

<template>
  <k-navbar :title="phone.t('Apps.clock.alarm.sound')">
    <template #left>
      <k-navbar-back-link :text="backLabel" @click="emit('close')" />
    </template>
  </k-navbar>

  <k-list strong inset class="clock-sound-menu">
    <k-list-item
      v-for="sound in ALARM_SOUND_IDS"
      :key="sound"
      link
      :chevron="false"
      :title="phone.t(`Apps.clock.alarm.sounds.${sound}`)"
      @click="selectSound(sound)"
    >
      <template #after>
        <Check v-if="selectedSound === sound" class="h-5 w-5 text-primary" />
      </template>
    </k-list-item>
  </k-list>
</template>
