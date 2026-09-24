<script setup lang="ts">
import {
  CloudSun,
  Droplets,
  Gauge,
  Navigation,
  ThermometerSun,
  Umbrella,
  Wind,
} from 'lucide-vue-next'
import { computed, onBeforeUnmount, ref, watch } from 'vue'

import WeatherConditionIcon from '@/components/WeatherConditionIcon.vue'
import { usePullToRefresh } from '@/composables/usePullToRefresh'
import { usePhoneStore } from '@/stores/phone'
import { useWeatherStore } from '@/stores/weather'
import type { WeatherConditionId } from '@/types/weather'
import {
  SkyAppPage,
  SkyCard,
  SkyLink,
  SkyNavbar,
  SkyScrollArea,
  SkySpinner,
  SkyNotification,
} from '@/ui'

const phone = usePhoneStore()
const weather = useWeatherStore()
const forecast = computed(() => weather.forecast)
const cooldownToastOpened = ref(false)
let cooldownToastTimer: ReturnType<typeof setTimeout> | undefined

const {
  finishPull,
  movePull,
  pullDistance,
  pullThreshold,
  pullWithWheel,
  startPull,
} = usePullToRefresh({
  isAtTop: (event) =>
    (event.currentTarget as HTMLElement | null)?.scrollTop === 0,
  isBusy: () => weather.isLoading,
  refresh: () => weather.refresh(true, true),
})

function closeCooldownToast(): void {
  cooldownToastOpened.value = false
  if (weather.error === 'reload_cooldown') weather.error = null
}
const isNight = computed(() => {
  if (!forecast.value) return false
  const hour = new Date(forecast.value.timestamp).getUTCHours()
  return hour < 6 || hour >= 20
})
const rainy = computed(
  () =>
    forecast.value?.condition === 'rain' ||
    forecast.value?.condition === 'thunder',
)
const rainDrops = [
  ['3%', '11px', '1.35s', '-0.3s', '0.32'],
  ['9%', '8px', '1.7s', '-1.1s', '0.2'],
  ['15%', '14px', '1.45s', '-0.8s', '0.38'],
  ['21%', '10px', '1.9s', '-1.6s', '0.24'],
  ['28%', '13px', '1.55s', '-0.2s', '0.3'],
  ['35%', '8px', '1.75s', '-1.35s', '0.18'],
  ['42%', '16px', '1.4s', '-0.65s', '0.36'],
  ['49%', '10px', '2s', '-1.8s', '0.22'],
  ['56%', '14px', '1.6s', '-0.45s', '0.34'],
  ['63%', '9px', '1.8s', '-1.2s', '0.2'],
  ['70%', '15px', '1.5s', '-0.9s', '0.37'],
  ['77%', '8px', '1.95s', '-1.55s', '0.2'],
  ['84%', '12px', '1.45s', '-0.15s', '0.31'],
  ['91%', '10px', '1.7s', '-1.05s', '0.24'],
  ['97%', '14px', '1.55s', '-0.6s', '0.28'],
].map(([left, height, duration, delay, opacity]) => ({
  '--rain-delay': delay,
  '--rain-duration': duration,
  '--rain-height': height,
  '--rain-left': left,
  '--rain-opacity': opacity,
}))
const snowFlakes = [
  ['4%', '1.8s', '-1.2s', '0.4'],
  ['12%', '2.6s', '-0.5s', '0.65'],
  ['19%', '2.1s', '-1.7s', '0.45'],
  ['27%', '2.9s', '-0.9s', '0.7'],
  ['36%', '2.3s', '-1.4s', '0.55'],
  ['44%', '3.1s', '-0.2s', '0.45'],
  ['53%', '2s', '-1.8s', '0.7'],
  ['62%', '2.7s', '-1.1s', '0.48'],
  ['70%', '2.2s', '-0.7s', '0.6'],
  ['78%', '3s', '-1.6s', '0.42'],
  ['87%', '2.4s', '-0.3s', '0.68'],
  ['95%', '2.8s', '-1.3s', '0.5'],
].map(([left, duration, delay, opacity]) => ({
  '--snow-delay': delay,
  '--snow-duration': duration,
  '--snow-left': left,
  '--snow-opacity': opacity,
}))
const fogLayers = [
  ['-18s', '44s', '0.28', '12%'],
  ['-7s', '38s', '0.18', '34%'],
  ['-27s', '51s', '0.23', '57%'],
].map(([delay, duration, opacity, top]) => ({
  '--fog-delay': delay,
  '--fog-duration': duration,
  '--fog-opacity': opacity,
  '--fog-top': top,
}))
function conditionLabel(condition: WeatherConditionId): string {
  return phone.t(`Apps.weather.conditions.${condition}`)
}

function formatHour(timestamp: number, index: number): string {
  if (index === 0) return phone.t('Apps.weather.now')
  return new Intl.DateTimeFormat(phone.lang, {
    hour: '2-digit',
    hourCycle: 'h23',
    timeZone: 'UTC',
  }).format(timestamp)
}

onBeforeUnmount(() => {
  if (cooldownToastTimer) clearTimeout(cooldownToastTimer)
})

watch(
  () => weather.error,
  (error) => {
    if (error !== 'reload_cooldown') return
    if (cooldownToastTimer) clearTimeout(cooldownToastTimer)
    cooldownToastOpened.value = true
    cooldownToastTimer = setTimeout(closeCooldownToast, 2800)
  },
)
</script>

<template>
  <SkyAppPage
    class="weather-app"
    data-theme-policy="scene"
    :class="[
      forecast ? `weather-app--${forecast.condition}` : '',
      { 'weather-app--night': isNight },
    ]"
    :label="phone.t('Apps.weather.name')"
    dark
  >
    <div class="weather-app__backdrop" aria-hidden="true"></div>
    <div v-if="rainy" class="weather-app__rain" aria-hidden="true">
      <i v-for="(drop, index) in rainDrops" :key="index" :style="drop"></i>
    </div>
    <div
      v-if="forecast?.condition === 'thunder'"
      class="weather-app__lightning"
      aria-hidden="true"
    ></div>
    <div
      v-if="forecast?.condition === 'fog'"
      class="weather-app__fog"
      aria-hidden="true"
    >
      <i v-for="(layer, index) in fogLayers" :key="index" :style="layer"></i>
    </div>
    <div
      v-if="forecast?.condition === 'snow'"
      class="weather-app__snow"
      aria-hidden="true"
    >
      <i v-for="(flake, index) in snowFlakes" :key="index" :style="flake"></i>
    </div>
    <div
      v-if="forecast?.condition === 'sunny'"
      class="weather-app__sun-glow"
      aria-hidden="true"
    ></div>
    <div v-if="isNight" class="weather-app__stars" aria-hidden="true"></div>
    <SkyNavbar class="weather-navbar" :title="phone.t('Apps.weather.name')" />

    <SkyScrollArea
      v-if="forecast"
      class="weather-scroll"
      @touchend="finishPull"
      @touchmove.passive="movePull"
      @touchstart.passive="startPull"
      @wheel="pullWithWheel"
    >
      <div
        class="weather-pull-refresh"
        :class="{ 'is-visible': pullDistance > 0 }"
        :style="{ transform: `translateY(${pullDistance - pullThreshold}px)` }"
        aria-live="polite"
      >
        <SkySpinner :label="phone.t('Common.loading')" />
      </div>
      <header class="weather-hero">
        <div class="weather-location">
          <Navigation :size="13" fill="currentColor" />
          {{ phone.t(`Apps.weather.regions.${forecast.region}`) }}
        </div>
        <WeatherConditionIcon
          :condition="forecast.condition"
          :timestamp="forecast.timestamp"
          class="weather-hero__icon"
          :size="82"
        />
        <div class="weather-temperature">{{ forecast.temperature }}°</div>
        <strong>{{ conditionLabel(forecast.condition) }}</strong>
        <p>{{ phone.t(`Apps.weather.summaries.${forecast.condition}`) }}</p>
      </header>

      <p
        v-if="weather.error && weather.error !== 'reload_cooldown'"
        class="weather-stale"
        role="status"
      >
        {{ phone.t('Apps.weather.stale') }}
      </p>

      <section
        class="weather-details"
        :aria-label="phone.t('Apps.weather.details')"
      >
        <SkyCard :content-wrap="false" class="weather-detail-card">
          <ThermometerSun :size="18" />
          <span>{{ phone.t('Apps.weather.feelsLike') }}</span>
          <strong>{{ forecast.feelsLike }}°</strong>
        </SkyCard>
        <SkyCard :content-wrap="false" class="weather-detail-card">
          <Wind :size="18" />
          <span>{{ phone.t('Apps.weather.wind') }}</span>
          <strong>{{ forecast.windSpeed }} km/h</strong>
        </SkyCard>
        <SkyCard :content-wrap="false" class="weather-detail-card">
          <Droplets :size="18" />
          <span>{{ phone.t('Apps.weather.humidity') }}</span>
          <strong>{{ forecast.humidity }}%</strong>
        </SkyCard>
        <SkyCard :content-wrap="false" class="weather-detail-card">
          <Umbrella :size="18" />
          <span>{{ phone.t('Apps.weather.rain') }}</span>
          <strong>{{ forecast.rainChance }}%</strong>
        </SkyCard>
      </section>

      <SkyCard :content-wrap="false" class="weather-panel weather-hourly-panel">
        <h2><Gauge :size="15" />{{ phone.t('Apps.weather.hourly') }}</h2>
        <div class="weather-hourly">
          <div
            v-for="(hour, index) in forecast.hourly"
            :key="hour.timestamp"
            class="weather-hour"
          >
            <span>{{ formatHour(hour.timestamp, index) }}</span>
            <WeatherConditionIcon
              :condition="hour.condition"
              :timestamp="hour.timestamp"
            />
            <small v-if="hour.rainChance >= 30">{{ hour.rainChance }}%</small>
            <strong>{{ hour.temperature }}°</strong>
          </div>
        </div>
      </SkyCard>
    </SkyScrollArea>

    <div v-else class="weather-empty">
      <SkySpinner v-if="weather.isLoading" :label="phone.t('Common.loading')" />
      <CloudSun v-else :size="52" :stroke-width="1.4" />
      <strong>{{
        phone.t(
          weather.isLoading ? 'Common.loading' : 'Apps.weather.unavailable',
        )
      }}</strong>
      <SkyLink
        v-if="!weather.isLoading"
        component="button"
        @click="weather.refresh(true, true)"
      >
        {{ phone.t('Apps.weather.tryAgain') }}
      </SkyLink>
    </div>

    <SkyNotification
      :opened="cooldownToastOpened"
      :text="phone.t('Apps.weather.errors.reload_cooldown')"
      @click="closeCooldownToast"
    />
  </SkyAppPage>
</template>

<style scoped>
.weather-scroll {
  padding: 4px 14px 24px;
}
</style>
