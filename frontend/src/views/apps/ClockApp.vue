<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { AlarmClock, Clock3, Plus, Timer, TimerReset } from 'lucide-vue-next'

import { useClockStore } from '@/stores/clock'
import { usePhoneStore } from '@/stores/phone'
import {
  elapsedMilliseconds,
  formatStopwatch,
  formatTimer,
  remainingMilliseconds,
} from '@/utils/clock'

const phone = usePhoneStore()
const clock = useClockStore()
const tab = ref<'world' | 'alarm' | 'stopwatch' | 'timer'>('world')
const now = ref(Date.now())
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
const cities = [
  { key: 'cupertino', zone: 'America/Los_Angeles' },
  { key: 'newYork', zone: 'America/New_York' },
  { key: 'london', zone: 'Europe/London' },
  { key: 'tokyo', zone: 'Asia/Tokyo' },
]
const tabs = [
  { id: 'world', icon: Clock3 },
  { id: 'alarm', icon: AlarmClock },
  { id: 'stopwatch', icon: Timer },
  { id: 'timer', icon: TimerReset },
] as const
function cityTime(zone: string): string {
  return new Intl.DateTimeFormat(phone.lang, {
    hour: '2-digit',
    minute: '2-digit',
    timeZone: zone,
  }).format(now.value)
}
onMounted(() => {
  ticker = setInterval(() => {
    now.value = Date.now()
  }, 250)
})
onBeforeUnmount(() => clearInterval(ticker))
</script>

<template>
  <main class="native-app clock-app">
    <header class="reference-clock-header">
      <nav>
        <button type="button">{{ phone.t('Common.edit') }}</button
        ><button type="button" :aria-label="phone.t('Apps.clock.add')">
          <Plus :size="25" />
        </button>
      </nav>
      <h1>{{ phone.t(`Apps.clock.tabs.${tab}`) }}</h1>
    </header>
    <section class="clock-content">
      <div v-if="tab === 'world'" class="world-clock-list">
        <div v-for="city in cities" :key="city.key">
          <div>
            <small
              >{{ phone.t('Apps.clock.today') }},
              {{ phone.t('Apps.clock.offset') }}</small
            ><strong>{{ phone.t(`Apps.clock.cities.${city.key}`) }}</strong>
          </div>
          <time>{{ cityTime(city.zone) }}</time>
        </div>
      </div>
      <div v-else-if="tab === 'alarm'" class="settings-list">
        <div v-for="alarm in clock.alarms" :key="alarm.id" class="settings-row">
          <div>
            <strong class="alarm-time">{{ alarm.time }}</strong
            ><small>{{ phone.t(alarm.labelKey) }}</small>
          </div>
          <button
            class="ios-switch"
            :class="{ active: alarm.enabled }"
            type="button"
            @click="clock.toggleAlarm(alarm.id)"
          >
            <span />
          </button>
        </div>
      </div>
      <div v-else-if="tab === 'stopwatch'" class="clock-tool">
        <div class="clock-digits">{{ formatStopwatch(stopwatchValue) }}</div>
        <div class="clock-actions">
          <button
            type="button"
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
            }}</button
          ><button
            class="positive"
            type="button"
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
          </button>
        </div>
        <div class="lap-list">
          <div v-for="(lap, index) in clock.laps" :key="index">
            <span
              >{{ phone.t('Apps.clock.lap') }}
              {{ clock.laps.length - index }}</span
            ><span>{{ formatStopwatch(lap) }}</span>
          </div>
        </div>
      </div>
      <div v-else class="clock-tool">
        <div class="timer-ring">
          <span>{{ formatTimer(timerValue) }}</span>
        </div>
        <label class="timer-input"
          >{{ phone.t('Apps.clock.minutes')
          }}<input
            type="number"
            min="1"
            max="60"
            :value="clock.timerDuration / 60000"
            @change="
              clock.setTimerMinutes(
                Number(($event.target as HTMLInputElement).value),
              )
            "
        /></label>
        <div class="clock-actions">
          <button type="button" @click="clock.resetTimer()">
            {{ phone.t('Common.reset') }}</button
          ><button
            class="positive"
            type="button"
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
          </button>
        </div>
      </div>
    </section>
    <nav class="reference-tabbar reference-clock-tabs">
      <button
        v-for="item in tabs"
        :key="item.id"
        :class="{ active: tab === item.id }"
        type="button"
        @click="tab = item.id"
      >
        <component :is="item.icon" :size="22" /><span>{{
          phone.t(`Apps.clock.tabs.${item.id}`)
        }}</span>
      </button>
    </nav>
  </main>
</template>
