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
  kTabbar,
  kTabbarLink,
  kToggle,
} from 'konsta/vue'
import { AlarmClock, Clock3, Plus, Timer, TimerReset } from 'lucide-vue-next'
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
const losSantosTime = computed(() =>
  new Intl.DateTimeFormat(phone.lang, {
    hour: '2-digit',
    minute: '2-digit',
    timeZone: 'America/Los_Angeles',
  }).format(now.value),
)
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
const tabColors = {
  textActiveIos: 'text-[#d99900]',
  textIos: 'text-[#77777c]',
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
        >
          {{ phone.t('Common.edit') }}
        </k-link>
      </template>
      <template #right>
        <k-link
          component="button"
          icon-only
          :link-props="{ type: 'button' }"
          :aria-label="phone.t('Apps.clock.add')"
        >
          <Plus />
        </k-link>
      </template>
    </k-navbar>

    <k-block component="section" nested class="clock-content">
      <k-block v-if="tab === 'world'" nested class="clock-world-now">
        <span class="clock-world-location">{{
          phone.t('Apps.clock.location')
        }}</span>
        <time class="clock-world-time">{{ losSantosTime }}</time>
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
          :title="alarm.time"
          :subtitle="phone.t(alarm.labelKey)"
          title-font-size-ios="text-[30px]"
          class="clock-alarm-item"
        >
          <template #after>
            <k-toggle
              :checked="alarm.enabled"
              :colors="toggleColors"
              :aria-label="`${alarm.time}, ${phone.t(alarm.labelKey)}`"
              @change="clock.toggleAlarm(alarm.id)"
            />
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

    <k-tabbar
      component="nav"
      labels
      icons
      class="clock-tabbar"
      inner-class="!w-full !gap-0"
      :aria-label="phone.t('Apps.clock.name')"
    >
      <k-tabbar-link
        v-for="item in tabs"
        :key="item.id"
        component="button"
        :active="tab === item.id"
        :colors="tabColors"
        :link-props="{ type: 'button' }"
        @click="tab = item.id"
      >
        <template #icon>
          <component :is="item.icon" :size="22" />
        </template>
        <span class="clock-tab-label">{{
          phone.t(`Apps.clock.tabs.${item.id}`)
        }}</span>
      </k-tabbar-link>
    </k-tabbar>
  </k-page>
</template>
