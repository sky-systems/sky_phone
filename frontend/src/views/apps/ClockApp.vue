<script setup lang="ts">
import {
  kBlock,
  kButton,
  kLink,
  kList,
  kListInput,
  kListItem,
  kNavbar,
  kPage,
  kSegmented,
  kSegmentedButton,
  kToggle,
} from 'konsta/vue'
import {
  AlarmClock,
  Clock3,
  Minus,
  Plus,
  Timer,
  TimerReset,
} from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

import AlarmEditor from '@/components/AlarmEditor.vue'
import { useClockStore } from '@/stores/clock'
import { usePhoneStore } from '@/stores/phone'
import type { Alarm, AlarmDraft } from '@/utils/alarms'
import {
  elapsedMilliseconds,
  formatStopwatch,
  formatTimer,
  remainingMilliseconds,
} from '@/utils/clock'

const phone = usePhoneStore()
const clock = useClockStore()
const tab = ref<'world' | 'alarm' | 'stopwatch' | 'timer'>('world')
const alarmEditor = ref<
  { mode: 'create' } | { id: string; mode: 'edit' } | null
>(null)
const alarmsEditing = ref(false)
const now = ref(Date.now())
const browserTimeZone = Intl.DateTimeFormat().resolvedOptions().timeZone
let ticker: ReturnType<typeof setInterval> | undefined

const stopwatchValue = computed(() =>
  elapsedMilliseconds(
    clock.stopwatchAccumulated,
    clock.stopwatchStartedAt,
    now.value,
  ),
)
const timerValue = computed(() =>
  remainingMilliseconds(
    clock.timerRemainingAtStart,
    clock.timerStartedAt,
    now.value,
  ),
)
const currentTime = computed(() =>
  new Intl.DateTimeFormat(phone.lang, {
    hour: '2-digit',
    minute: '2-digit',
    timeZone: browserTimeZone,
  }).format(now.value),
)
const currentTimeZone = computed(
  () =>
    new Intl.DateTimeFormat(phone.lang, {
      timeZone: browserTimeZone,
      timeZoneName: 'short',
    })
      .formatToParts(now.value)
      .find((part) => part.type === 'timeZoneName')?.value ??
    browserTimeZone,
)
const selectedAlarm = computed(() => {
  const editor = alarmEditor.value
  return editor?.mode === 'edit'
    ? clock.alarms.find((alarm) => alarm.id === editor.id)
    : undefined
})
const tabs = [
  { id: 'world', icon: Clock3 },
  { id: 'alarm', icon: AlarmClock },
  { id: 'stopwatch', icon: Timer },
  { id: 'timer', icon: TimerReset },
] as const
const secondaryActionColors = {
  tonalBgIos: 'bg-[#2c2c2e] active:bg-[#3a3a3c]',
  tonalTextIos: 'text-white',
}
const positiveActionColors = {
  fillBgIos: 'bg-[#103a20] active:bg-[#174d2a]',
  fillTextIos: 'text-[#30d158]',
}
const toggleColors = {
  checkedBgIos: 'bg-[#30d158]',
}
const dangerActionColors = {
  fillBgIos: 'bg-red-500 active:bg-red-600',
  fillTextIos: 'text-white',
}
const weekdayKeys = [
  'sunday',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
] as const

function alarmRepeat(alarm: Alarm): string {
  const weekdays = [...alarm.weekdays].sort()
  if (!weekdays.length) return phone.t('Apps.clock.alarm.never')
  if (weekdays.length === 7) return phone.t('Apps.clock.alarm.everyDay')
  if (weekdays.join(',') === '1,2,3,4,5') {
    return phone.t('Apps.clock.alarm.weekdays')
  }
  if (weekdays.join(',') === '0,6') {
    return phone.t('Apps.clock.alarm.weekends')
  }
  return weekdays
    .map((weekday) =>
      phone.t(`Apps.clock.alarm.daysShort.${weekdayKeys[weekday]}`),
    )
    .join(', ')
}

function alarmSubtitle(alarm: Alarm): string {
  const repeat = alarmRepeat(alarm)
  return alarm.note ? `${repeat} · ${alarm.note}` : repeat
}

function openAlarmEditor(id?: string): void {
  tab.value = 'alarm'
  alarmEditor.value = id ? { id, mode: 'edit' } : { mode: 'create' }
}

function saveAlarm(draft: AlarmDraft): void {
  if (alarmEditor.value?.mode === 'edit') {
    clock.updateAlarm(alarmEditor.value.id, draft)
  } else {
    clock.createAlarm(draft)
  }
  alarmEditor.value = null
}

function deleteSelectedAlarm(): void {
  if (alarmEditor.value?.mode === 'edit') {
    clock.deleteAlarm(alarmEditor.value.id)
  }
  alarmEditor.value = null
}

function toggleAlarmEditing(): void {
  tab.value = 'alarm'
  alarmsEditing.value = !alarmsEditing.value
}

function selectTab(nextTab: (typeof tabs)[number]['id']): void {
  tab.value = nextTab
  if (nextTab !== 'alarm') alarmsEditing.value = false
}
onMounted(() => {
  ticker = setInterval(() => {
    now.value = Date.now()
  }, 250)
})

onBeforeUnmount(() => clearInterval(ticker))
</script>

<template>
  <k-page component="main" class="native-app clock-app">
    <AlarmEditor
      v-if="alarmEditor"
      :alarm="selectedAlarm"
      @cancel="alarmEditor = null"
      @delete="deleteSelectedAlarm"
      @save="saveAlarm"
    />

    <template v-else>
      <k-navbar
      :title="phone.t(`Apps.clock.tabs.${tab}`)"
      :large="tab === 'world' || tab === 'alarm'"
      :transparent="tab === 'world' || tab === 'alarm'"
      class="clock-navbar"
    >
      <template #left>
        <k-link
          component="button"
          :link-props="{ type: 'button' }"
          @click="toggleAlarmEditing"
        >
          {{ phone.t(alarmsEditing ? 'Common.done' : 'Common.edit') }}
        </k-link>
      </template>
      <template #right>
        <k-link
          component="button"
          icon-only
          :link-props="{ type: 'button' }"
          :aria-label="phone.t('Apps.clock.add')"
          @click="openAlarmEditor()"
        >
          <Plus />
        </k-link>
      </template>
    </k-navbar>

    <k-block component="section" nested class="clock-content">
      <k-block v-if="tab === 'world'" nested class="clock-world-now">
        <span class="clock-world-location">{{
          browserTimeZone.replace(/_/g, ' ')
        }}</span>
        <time class="clock-world-time">{{ currentTime }}</time>
        <span class="clock-world-zone">{{ currentTimeZone }}</span>
      </k-block>

      <k-list
        v-else-if="tab === 'alarm'"
        strong
        inset
        class="clock-konsta-list clock-alarm-list"
      >
        <k-list-item
          v-for="alarm in clock.alarms"
          :key="alarm.id"
          link
          :chevron="alarmsEditing"
          :title="alarm.time"
          :subtitle="alarmSubtitle(alarm)"
          :strong-title="false"
          title-font-size-ios="text-[38px] font-light"
          class="clock-alarm-item"
          @click="openAlarmEditor(alarm.id)"
        >
          <template v-if="alarmsEditing" #media>
            <k-button
              rounded
              small
              inline
              :colors="dangerActionColors"
              class="clock-alarm-remove"
              :aria-label="phone.t('Apps.clock.alarm.delete')"
              @click.stop="clock.deleteAlarm(alarm.id)"
            >
              <Minus aria-hidden="true" />
            </k-button>
          </template>
          <template #after>
            <span v-if="!alarmsEditing" @click.stop>
              <k-toggle
                :checked="alarm.enabled"
                :colors="toggleColors"
                :aria-label="`${alarm.time}, ${alarmSubtitle(alarm)}`"
                @change="clock.toggleAlarm(alarm.id)"
              />
            </span>
          </template>
        </k-list-item>
      </k-list>

      <k-block v-else-if="tab === 'stopwatch'" nested class="clock-tool">
        <div class="clock-digits">{{ formatStopwatch(stopwatchValue) }}</div>
        <div class="clock-actions">
          <k-button
            rounded
            tonal
            :colors="secondaryActionColors"
            class="clock-action-button"
            @click="
              clock.stopwatchStartedAt === null
                ? clock.resetStopwatch()
                : clock.addLap(now)
            "
          >
            {{
              phone.t(
                clock.stopwatchStartedAt === null
                  ? 'Common.reset'
                  : 'Apps.clock.lap',
              )
            }}
          </k-button>
          <k-button
            rounded
            :colors="positiveActionColors"
            class="clock-action-button"
            @click="
              clock.stopwatchStartedAt === null
                ? clock.startStopwatch(now)
                : clock.pauseStopwatch(now)
            "
          >
            {{
              phone.t(
                clock.stopwatchStartedAt === null
                  ? 'Common.start'
                  : 'Common.stop',
              )
            }}
          </k-button>
        </div>
        <k-list dividers class="clock-konsta-list clock-lap-list">
          <k-list-item
            v-for="(lap, index) in clock.laps"
            :key="index"
            :title="`${phone.t('Apps.clock.lap')} ${clock.laps.length - index}`"
            :after="formatStopwatch(lap)"
          />
        </k-list>
      </k-block>

      <k-block v-else nested class="clock-tool">
        <div class="timer-ring">
          <span>{{ formatTimer(timerValue) }}</span>
        </div>
        <k-list strong inset class="clock-konsta-list clock-timer-input">
          <k-list-input
            :label="phone.t('Apps.clock.minutes')"
            type="number"
            min="1"
            max="60"
            :value="clock.timerDuration / 60000"
            @change="
              clock.setTimerMinutes(
                Number(($event.target as HTMLInputElement).value),
              )
            "
          />
        </k-list>
        <div class="clock-actions">
          <k-button
            rounded
            tonal
            :colors="secondaryActionColors"
            class="clock-action-button"
            @click="clock.resetTimer()"
          >
            {{ phone.t('Common.reset') }}
          </k-button>
          <k-button
            rounded
            :colors="positiveActionColors"
            class="clock-action-button"
            @click="
              clock.timerStartedAt === null
                ? clock.startTimer(now)
                : clock.pauseTimer(now)
            "
          >
            {{
              phone.t(
                clock.timerStartedAt === null ? 'Common.start' : 'Common.pause',
              )
            }}
          </k-button>
        </div>
      </k-block>
    </k-block>

    <k-navbar
      component="nav"
      :aria-label="phone.t('Apps.clock.name')"
    >
      <template #subnavbar>
        <k-segmented :key="tab" strong rounded>
          <k-segmented-button
            v-for="item in tabs"
            :key="item.id"
            :active="tab === item.id"
            :aria-label="phone.t(`Apps.clock.tabs.${item.id}`)"
            :aria-pressed="tab === item.id"
            @click="selectTab(item.id)"
          >
            <component :is="item.icon" aria-hidden="true" />
          </k-segmented-button>
        </k-segmented>
      </template>
    </k-navbar>
    </template>
  </k-page>
</template>
