<script setup lang="ts">
import {
  SkyBlock,
  SkyButton,
  SkyLink,
  SkyList,
  SkyField,
  SkyListItem,
  SkyNavbar,
  SkyAppPage,
  SkyTabBar,
  SkyTabButton,
  SkyToggle,
} from '@/ui'
import {
  AlarmClock,
  ChevronRight,
  Globe2,
  Minus,
  Pause,
  Play,
  Plus,
  Timer,
  TimerReset,
  X,
} from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'

import AlarmEditor from '@/components/AlarmEditor.vue'
import AlarmSoundMenu from '@/components/AlarmSoundMenu.vue'
import TimeWheelPicker from '@/components/TimeWheelPicker.vue'
import { useClockStore } from '@/stores/clock'
import { usePhoneStore } from '@/stores/phone'
import { type Alarm, type AlarmDraft } from '@/utils/alarms'
import {
  elapsedMilliseconds,
  formatStopwatch,
  formatTimer,
  remainingMilliseconds,
  timerPickerMilliseconds,
  timerPickerValue,
  timerProgressRatio,
} from '@/utils/clock'

const phone = usePhoneStore()
const clock = useClockStore()
const route = useRoute()
const tab = ref<'world' | 'alarm' | 'stopwatch' | 'timer'>(
  route.query.section === 'timer' || route.query.section === 'stopwatch'
    ? route.query.section
    : 'world',
)
const alarmEditor = ref<
  { mode: 'create' } | { id: string; mode: 'edit' } | null
>(null)
const timerSoundMenuOpen = ref(false)
const alarmsEditing = ref(false)
const now = ref(Date.now())
const browserTimeZone = Intl.DateTimeFormat().resolvedOptions().timeZone
let ticker: ReturnType<typeof setInterval> | undefined
let stopwatchFrame: number | undefined

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
const timerProgress = computed(() =>
  timerProgressRatio(timerValue.value, clock.timerDuration),
)
const timerPicker = computed({
  get: () => timerPickerValue(clock.timerRemainingAtStart),
  set: (value: string) =>
    clock.setTimerDuration(timerPickerMilliseconds(value)),
})
const currentTime = computed(() =>
  new Intl.DateTimeFormat(phone.lang, {
    hour: '2-digit',
    hourCycle: 'h23',
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
      .find((part) => part.type === 'timeZoneName')?.value ?? browserTimeZone,
)
const stopwatchDecimalSeparator = computed(
  () =>
    new Intl.NumberFormat(phone.lang)
      .formatToParts(1.1)
      .find((part) => part.type === 'decimal')?.value ?? '.',
)
const stopwatchDisplay = computed(() =>
  formatStopwatch(stopwatchValue.value).replace(
    '.',
    stopwatchDecimalSeparator.value,
  ),
)
const selectedAlarm = computed(() => {
  const editor = alarmEditor.value
  return editor?.mode === 'edit'
    ? clock.alarms.find((alarm) => alarm.id === editor.id)
    : undefined
})
const tabs = [
  { id: 'world', icon: Globe2 },
  { id: 'alarm', icon: AlarmClock },
  { id: 'stopwatch', icon: Timer },
  { id: 'timer', icon: TimerReset },
] as const
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

function setTimerNote(event: Event): void {
  clock.setTimerNote((event.target as HTMLInputElement).value.slice(0, 80))
}

function updateStopwatchFrame(): void {
  now.value = Date.now()
  stopwatchFrame = requestAnimationFrame(updateStopwatchFrame)
}

watch([() => clock.stopwatchStartedAt, tab], ([startedAt, activeTab]) => {
  if (stopwatchFrame !== undefined) cancelAnimationFrame(stopwatchFrame)
  stopwatchFrame =
    startedAt === null || activeTab !== 'stopwatch'
      ? undefined
      : requestAnimationFrame(updateStopwatchFrame)
})

watch(
  () => route.query.section,
  (section) => {
    if (section === 'timer' || section === 'stopwatch') tab.value = section
  },
)

onMounted(() => {
  ticker = setInterval(() => {
    now.value = Date.now()
  }, 250)
})

onBeforeUnmount(() => {
  clearInterval(ticker)
  if (stopwatchFrame !== undefined) cancelAnimationFrame(stopwatchFrame)
})
</script>

<template>
  <sky-app-page
    component="main"
    :accent="phone.isDarkMode ? '#ff9f0a' : '#9b5800'"
    accent-soft="rgba(255, 159, 10, 0.16)"
    class="native-app clock-app"
  >
    <AlarmSoundMenu
      v-if="timerSoundMenuOpen"
      :back-label="phone.t('Apps.clock.tabs.timer')"
      :selected-sound="clock.timerSound"
      @close="timerSoundMenuOpen = false"
      @select="clock.setTimerSound($event)"
    />

    <template v-else>
      <sky-navbar
        v-if="tab === 'alarm'"
        :title="phone.t(`Apps.clock.tabs.${tab}`)"
        variant="large"
        transparent
        class="clock-navbar clock-navbar--alarm"
      >
        <template #left>
          <sky-link
            component="button"
            icon-only
            class="clock-navbar-action clock-navbar-action--icon sky-glass-surface"
            :link-props="{ type: 'button' }"
            :aria-label="phone.t('Apps.clock.add')"
            @click="openAlarmEditor()"
          >
            <Plus aria-hidden="true" />
          </sky-link>
        </template>
        <template #right>
          <sky-link
            v-if="clock.alarms.length"
            component="button"
            class="clock-navbar-action clock-navbar-action--edit sky-glass-surface"
            :link-props="{ type: 'button' }"
            @click="toggleAlarmEditing"
          >
            {{ phone.t(alarmsEditing ? 'Common.done' : 'Common.edit') }}
          </sky-link>
        </template>
      </sky-navbar>

      <sky-block component="section" nested class="clock-content">
        <sky-block v-if="tab === 'world'" nested class="clock-world-now">
          <span class="clock-world-location">{{
            phone.t('Apps.clock.location')
          }}</span>
          <time class="clock-world-time">{{ currentTime }}</time>
          <span class="clock-world-zone">{{ currentTimeZone }}</span>
        </sky-block>

        <section
          v-else-if="tab === 'alarm'"
          class="clock-alarm-list"
          :aria-label="phone.t('Apps.clock.tabs.alarm')"
        >
          <article
            v-for="alarm in clock.alarms"
            :key="alarm.id"
            class="clock-alarm-item"
            :class="{ 'clock-alarm-item--disabled': !alarm.enabled }"
          >
            <sky-button
              v-if="alarmsEditing"
              rounded
              small
              icon-only
              variant="danger"
              class="clock-alarm-remove"
              :aria-label="phone.t('Apps.clock.alarm.delete')"
              @click="clock.deleteAlarm(alarm.id)"
            >
              <Minus aria-hidden="true" />
            </sky-button>

            <button
              type="button"
              class="clock-alarm-copy"
              @click="openAlarmEditor(alarm.id)"
            >
              <time class="clock-alarm-time">{{ alarm.time }}</time>
              <span class="clock-alarm-subtitle">{{
                alarmSubtitle(alarm)
              }}</span>
            </button>

            <ChevronRight
              v-if="alarmsEditing"
              class="clock-alarm-chevron"
              aria-hidden="true"
            />
            <sky-toggle
              v-else
              :checked="alarm.enabled"
              style="--sky-app-accent: #30d158"
              :aria-label="`${alarm.time}, ${alarmSubtitle(alarm)}`"
              @change="clock.toggleAlarm(alarm.id)"
            />
          </article>
        </section>

        <sky-block
          v-else-if="tab === 'stopwatch'"
          nested
          class="clock-tool clock-stopwatch"
        >
          <time class="clock-digits">{{ stopwatchDisplay }}</time>
          <div class="clock-actions clock-stopwatch-actions">
            <sky-button
              rounded
              variant="secondary"
              class="clock-action-button clock-action-button--secondary"
              :disabled="
                clock.stopwatchStartedAt === null && stopwatchValue <= 0
              "
              @click="
                clock.stopwatchStartedAt === null
                  ? clock.resetStopwatch()
                  : clock.addLap(Date.now())
              "
            >
              {{
                phone.t(
                  clock.stopwatchStartedAt === null
                    ? 'Common.reset'
                    : 'Apps.clock.lap',
                )
              }}
            </sky-button>
            <sky-button
              rounded
              variant="secondary"
              class="clock-action-button"
              :class="
                clock.stopwatchStartedAt === null
                  ? 'clock-action-button--start'
                  : 'clock-action-button--stop'
              "
              @click="
                clock.stopwatchStartedAt === null
                  ? clock.startStopwatch(Date.now())
                  : clock.pauseStopwatch(Date.now())
              "
            >
              {{
                phone.t(
                  clock.stopwatchStartedAt === null
                    ? 'Common.start'
                    : 'Common.stop',
                )
              }}
            </sky-button>
          </div>
          <div class="clock-tool-divider" aria-hidden="true" />
          <sky-list dividers class="clock-konsta-list clock-lap-list">
            <sky-list-item
              v-for="(lap, index) in clock.laps"
              :key="index"
              :title="`${phone.t('Apps.clock.lap')} ${clock.laps.length - index}`"
              :after="formatStopwatch(lap)"
            />
          </sky-list>
        </sky-block>

        <section v-else class="clock-tool clock-timer">
          <div
            v-if="clock.timerStartedAt !== null"
            class="timer-ring"
            role="progressbar"
            aria-valuemin="0"
            aria-valuemax="100"
            :aria-valuenow="Math.round(timerProgress * 100)"
            :aria-valuetext="formatTimer(timerValue)"
          >
            <svg viewBox="0 0 210 210" aria-hidden="true">
              <circle class="timer-ring-track" cx="105" cy="105" r="92" />
              <circle
                class="timer-ring-progress"
                cx="105"
                cy="105"
                r="92"
                pathLength="100"
                :style="{ strokeDashoffset: 100 - timerProgress * 100 }"
              />
            </svg>
            <span>{{ formatTimer(timerValue) }}</span>
          </div>
          <TimeWheelPicker
            v-else
            v-model="timerPicker"
            show-unit-labels
            :hours-label="phone.t('Apps.clock.timer.hours')"
            :hours-unit-label="phone.t('Apps.clock.timer.hoursShort')"
            :label="phone.t('Apps.clock.timer.time')"
            :minutes-label="phone.t('Apps.clock.timer.minutes')"
            :minutes-unit-label="phone.t('Apps.clock.timer.minutesShort')"
            :seconds-label="phone.t('Apps.clock.timer.seconds')"
            :seconds-unit-label="phone.t('Apps.clock.timer.secondsShort')"
          />

          <div class="clock-actions clock-timer-actions">
            <sky-button
              rounded
              variant="secondary"
              class="clock-action-button clock-action-button--secondary clock-action-button--icon"
              :aria-label="phone.t('Common.reset')"
              @click="clock.resetTimer()"
            >
              <X aria-hidden="true" />
            </sky-button>
            <sky-button
              rounded
              variant="secondary"
              class="clock-action-button clock-action-button--start clock-action-button--icon"
              :disabled="clock.timerStartedAt === null && timerValue <= 0"
              :aria-label="
                phone.t(
                  clock.timerStartedAt === null
                    ? 'Common.start'
                    : 'Common.pause',
                )
              "
              @click="
                clock.timerStartedAt === null
                  ? clock.startTimer(now)
                  : clock.pauseTimer(now)
              "
            >
              <Play v-if="clock.timerStartedAt === null" aria-hidden="true" />
              <Pause v-else aria-hidden="true" />
            </sky-button>
          </div>

          <sky-list strong inset class="clock-konsta-list clock-timer-settings">
            <sky-field
              :label="phone.t('Apps.clock.timer.description')"
              :placeholder="phone.t('Apps.clock.timer.notePlaceholder')"
              :value="clock.timerNote"
              maxlength="80"
              @input="setTimerNote"
            />
            <sky-list-item
              link
              :chevron="false"
              :title="phone.t('Apps.clock.timer.sound')"
              @click="timerSoundMenuOpen = true"
            >
              <template #after>
                <span class="clock-sound-selection">
                  {{ phone.t(`Apps.clock.alarm.sounds.${clock.timerSound}`) }}
                  <ChevronRight aria-hidden="true" />
                </span>
              </template>
            </sky-list-item>
          </sky-list>
        </section>
      </sky-block>

      <sky-tab-bar
        icons
        labels
        class="clock-tabbar"
        :aria-label="phone.t('Apps.clock.name')"
      >
        <sky-tab-button
          v-for="item in tabs"
          :key="item.id"
          :active="tab === item.id"
          :aria-label="phone.t(`Apps.clock.tabs.${item.id}`)"
          @click="selectTab(item.id)"
        >
          <template #icon>
            <component :is="item.icon" aria-hidden="true" />
          </template>
          <template #label>
            {{ phone.t(`Apps.clock.tabs.${item.id}`) }}
          </template>
        </sky-tab-button>
      </sky-tab-bar>

      <AlarmEditor
        v-if="alarmEditor"
        :alarm="selectedAlarm"
        @cancel="alarmEditor = null"
        @delete="deleteSelectedAlarm"
        @save="saveAlarm"
      />
    </template>
  </sky-app-page>
</template>
