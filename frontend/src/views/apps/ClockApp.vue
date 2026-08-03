<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

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
const tabs = ['world', 'alarm', 'stopwatch', 'timer'] as const
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
    <header class="app-header">
      <h1>{{ phone.t(`Apps.clock.tabs.${tab}`) }}</h1>
    </header>
    <section class="clock-content">
      <div v-if="tab === 'world'" class="settings-list">
        <div v-for="city in cities" :key="city.key" class="settings-row">
          <span>{{ phone.t(`Apps.clock.cities.${city.key}`) }}</span
          ><strong>{{ cityTime(city.zone) }}</strong>
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
    <nav class="app-tabs">
      <button
        v-for="item in tabs"
        :key="item"
        :class="{ active: tab === item }"
        type="button"
        @click="tab = item"
      >
        {{ phone.t(`Apps.clock.tabs.${item}`) }}
      </button>
    </nav>
  </main>
</template>
