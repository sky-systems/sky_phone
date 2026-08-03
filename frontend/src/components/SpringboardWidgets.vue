<script setup lang="ts">
import {
  BatteryCharging,
  CloudSun,
  Pause,
  Play,
  SkipForward,
} from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

import { usePhoneStore } from '@/stores/phone'

const phone = usePhoneStore()
const now = ref(new Date())
const playing = ref(false)
let intervalId: number | undefined

const date = computed(() =>
  new Intl.DateTimeFormat(phone.lang, {
    month: 'long',
    weekday: 'long',
  }).format(now.value),
)
const day = computed(() => now.value.getDate())

onMounted(() => {
  intervalId = window.setInterval(() => {
    now.value = new Date()
  }, 60_000)
})

onBeforeUnmount(() => {
  if (intervalId !== undefined) window.clearInterval(intervalId)
})
</script>

<template>
  <div class="widgets-stack">
    <article class="widget widget--weather">
      <div>
        <span>{{ phone.t('Home.widgets.weather.city') }}</span>
        <strong>21°</strong>
        <small>{{ phone.t('Home.widgets.weather.condition') }}</small>
      </div>
      <CloudSun :size="48" aria-hidden="true" />
    </article>

    <div class="widget-row">
      <article class="widget widget--calendar">
        <span>{{ date }}</span>
        <strong>{{ day }}</strong>
        <small>{{ phone.t('Home.widgets.calendar.event') }}</small>
      </article>
      <article class="widget widget--battery">
        <BatteryCharging :size="25" aria-hidden="true" />
        <strong>78%</strong>
        <small>{{ phone.t('Home.widgets.battery.label') }}</small>
      </article>
    </div>

    <article class="widget widget--media">
      <div class="widget--media__art" aria-hidden="true"></div>
      <div class="widget--media__copy">
        <strong>{{ phone.t('Home.widgets.media.title') }}</strong>
        <small>{{ phone.t('Home.widgets.media.artist') }}</small>
      </div>
      <button
        type="button"
        :aria-label="
          phone.t(
            playing ? 'Home.widgets.media.pause' : 'Home.widgets.media.play',
          )
        "
        @click="playing = !playing"
      >
        <Pause v-if="playing" :size="20" fill="currentColor" />
        <Play v-else :size="20" fill="currentColor" />
      </button>
      <SkipForward :size="19" aria-hidden="true" />
    </article>
  </div>
</template>
