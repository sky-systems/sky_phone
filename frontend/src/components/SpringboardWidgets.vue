<script setup lang="ts">
import {
  BatteryCharging,
  Cloud,
  CloudFog,
  CloudLightning,
  CloudRain,
  CloudSun,
  MoonStar,
  Pause,
  Play,
  Snowflake,
  SkipForward,
  Sun,
} from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, ref, type Component } from 'vue'
import { useRouter } from 'vue-router'

import { usePhoneStore } from '@/stores/phone'
import { useWeatherStore } from '@/stores/weather'
import type { WeatherConditionId } from '@/types/weather'

const phone = usePhoneStore()
const weather = useWeatherStore()
const router = useRouter()
const now = ref(new Date())
const playing = ref(false)
let intervalId: number | undefined

const conditionIcons: Record<WeatherConditionId, Component> = {
  sunny: Sun,
  clear: MoonStar,
  partly_cloudy: CloudSun,
  cloudy: Cloud,
  rain: CloudRain,
  thunder: CloudLightning,
  fog: CloudFog,
  snow: Snowflake,
}
const weatherIcon = computed(
  () => conditionIcons[weather.forecast?.condition ?? 'partly_cloudy'],
)
const weatherRegion = computed(() =>
  weather.forecast
    ? phone.t(`Apps.weather.regions.${weather.forecast.region}`)
    : phone.t('Apps.weather.regions.los_santos'),
)
const weatherCondition = computed(() =>
  weather.forecast
    ? phone.t(`Apps.weather.conditions.${weather.forecast.condition}`)
    : phone.t('Common.loading'),
)
const date = computed(() =>
  new Intl.DateTimeFormat(phone.lang, {
    month: 'long',
    weekday: 'long',
  }).format(now.value),
)
const day = computed(() => now.value.getDate())

function openWeather(): void {
  phone.setLaunchOrigin(null)
  void router.push('/apps/weather')
}

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
    <button
      type="button"
      class="widget widget--weather"
      :aria-label="phone.t('Apps.weather.name')"
      @click="openWeather"
    >
      <div>
        <span>{{ weatherRegion }}</span>
        <strong>{{ weather.forecast?.temperature ?? '--' }}°</strong>
        <small>{{ weatherCondition }}</small>
      </div>
      <component :is="weatherIcon" :size="48" aria-hidden="true" />
    </button>

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
