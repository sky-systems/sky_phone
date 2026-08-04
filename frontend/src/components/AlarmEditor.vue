<script setup lang="ts">
import {
  kBlock,
  kBlockTitle,
  kButton,
  kLink,
  kList,
  kListInput,
  kListItem,
  kNavbar,
} from 'konsta/vue'
import { ChevronRight, Check, X } from 'lucide-vue-next'
import { reactive, ref } from 'vue'

import AlarmSoundMenu from '@/components/AlarmSoundMenu.vue'
import { usePhoneStore } from '@/stores/phone'
import TimeWheelPicker from '@/components/TimeWheelPicker.vue'
import {
  type Alarm,
  type AlarmDraft,
  WEEKDAY_IDS,
} from '@/utils/alarms'

const props = defineProps<{ alarm?: Alarm }>()
const emit = defineEmits<{
  cancel: []
  delete: []
  save: [draft: AlarmDraft]
}>()
const phone = usePhoneStore()
const soundMenuOpen = ref(false)
const weekdayKeys = [
  'sunday',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
] as const
const draft = reactive<AlarmDraft>({
  note: props.alarm?.note ?? '',
  sound: props.alarm?.sound ?? 'radar',
  time: props.alarm?.time ?? '07:00',
  weekdays: [...(props.alarm?.weekdays ?? [])],
})
const dangerColors = {
  tonalBgIos: 'bg-red-500/15 active:bg-red-500/25',
  tonalTextIos: 'text-red-500',
}
const saveLinkColors = {
  navbarTextIos: 'text-[#ff9f0a]',
}

function setNote(event: Event): void {
  draft.note = (event.target as HTMLInputElement).value.slice(0, 80)
}

function save(): void {
  emit('save', {
    note: draft.note,
    sound: draft.sound,
    time: draft.time,
    weekdays: [...draft.weekdays],
  })
}

function toggleWeekday(weekday: number): void {
  draft.weekdays = draft.weekdays.includes(weekday)
    ? draft.weekdays.filter((candidate) => candidate !== weekday)
    : [...draft.weekdays, weekday]
}
</script>

<template>
  <AlarmSoundMenu
    v-if="soundMenuOpen"
    :back-label="phone.t('Apps.clock.tabs.alarm')"
    :selected-sound="draft.sound"
    @close="soundMenuOpen = false"
    @select="draft.sound = $event"
  />

  <k-navbar v-show="!soundMenuOpen" :title="phone.t('Apps.clock.tabs.alarm')">
    <template #left>
      <k-link
        component="button"
        icon-only
        :link-props="{ type: 'button' }"
        :aria-label="phone.t('Common.cancel')"
        @click="emit('cancel')"
      >
        <X aria-hidden="true" />
      </k-link>
    </template>
    <template #right>
      <k-link
        component="button"
        icon-only
        :colors="saveLinkColors"
        :link-props="{ type: 'button' }"
        :aria-label="phone.t('Common.save')"
        @click="save"
      >
        <Check aria-hidden="true" />
      </k-link>
    </template>
  </k-navbar>

  <k-block
    v-show="!soundMenuOpen"
    component="section"
    class="clock-alarm-editor"
  >
    <TimeWheelPicker
      v-model="draft.time"
      :hours-label="phone.t('Apps.clock.alarm.hours')"
      :label="phone.t('Apps.clock.alarm.time')"
      :minutes-label="phone.t('Apps.clock.minutes')"
    />

    <k-block-title>{{ phone.t('Apps.clock.alarm.repeat') }}</k-block-title>
    <k-list strong inset>
      <k-list-item
        v-for="weekday in WEEKDAY_IDS"
        :key="weekday"
        link
        :chevron="false"
        :title="phone.t(`Apps.clock.alarm.days.${weekdayKeys[weekday]}`)"
        @click="toggleWeekday(weekday)"
      >
        <template #after>
          <Check
            v-if="draft.weekdays.includes(weekday)"
            class="w-5 h-5 text-primary"
          />
        </template>
      </k-list-item>
    </k-list>

    <k-list strong inset>
      <k-list-input
        :label="phone.t('Apps.clock.alarm.note')"
        :placeholder="phone.t('Apps.clock.alarm.notePlaceholder')"
        :value="draft.note"
        maxlength="80"
        @input="setNote"
      />
    </k-list>

    <k-list strong inset>
      <k-list-item
        link
        :chevron="false"
        :title="phone.t('Apps.clock.alarm.sound')"
        @click="soundMenuOpen = true"
      >
        <template #after>
          <span class="clock-sound-selection">
            {{ phone.t(`Apps.clock.alarm.sounds.${draft.sound}`) }}
            <ChevronRight aria-hidden="true" />
          </span>
        </template>
      </k-list-item>
    </k-list>

    <k-button
      v-if="alarm"
      large
      rounded
      tonal
      :colors="dangerColors"
      class="clock-alarm-delete"
      @click="emit('delete')"
    >
      {{ phone.t('Apps.clock.alarm.delete') }}
    </k-button>
  </k-block>
</template>
