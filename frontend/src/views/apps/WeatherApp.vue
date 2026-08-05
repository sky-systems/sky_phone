<script setup lang="ts">
import { kCard, kLink, kNavbar, kPage, kPreloader } from 'konsta/vue'
import {
  Cloud,
  CloudFog,
  CloudLightning,
  CloudRain,
  CloudSun,
  Droplets,
  Gauge,
  MoonStar,
  Navigation,
  RefreshCw,
  Snowflake,
  Sun,
  ThermometerSun,
  Umbrella,
  Wind,
} from 'lucide-vue-next'
import { computed, type Component } from 'vue'

import { usePhoneStore } from '@/stores/phone'
import { useWeatherStore } from '@/stores/weather'
import type { DailyWeather, WeatherConditionId } from '@/types/weather'

const phone = usePhoneStore()
const weather = useWeatherStore()
const forecast = computed(() => weather.forecast)
const cardColors = {
  bgIos: 'bg-transparent',
  textIos: 'text-white',
}

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

function conditionIcon(condition: WeatherConditionId, timestamp: number): Component {
  if (condition !== 'clear') return conditionIcons[condition]
  const hour = new Date(timestamp).getUTCHours()
  return hour >= 7 && hour < 20 ? Sun : MoonStar
}

function conditionLabel(condition: WeatherConditionId): string {
  return phone.t(`Apps.weather.conditions.${condition}`)
}

function formatHour(timestamp: number, index: number): string {
  if (index === 0) return phone.t('Apps.weather.now')
  return new Intl.DateTimeFormat(phone.lang, {
    hour: 'numeric',
    timeZone: 'UTC',
  }).format(timestamp)
}

function formatDay(day: DailyWeather, index: number): string {
  if (index === 0) return phone.t('Apps.weather.today')
  return new Intl.DateTimeFormat(phone.lang, {
    timeZone: 'UTC',
    weekday: 'short',
  }).format(day.timestamp)
}

function temperatureRange(day: DailyWeather): Record<string, string> {
  const lows = forecast.value?.daily.map((item) => item.low) ?? [day.low]
  const highs = forecast.value?.daily.map((item) => item.high) ?? [day.high]
  const minimum = Math.min(...lows)
  const maximum = Math.max(...highs)
  const span = Math.max(1, maximum - minimum)
  return {
    '--range-left': `${((day.low - minimum) / span) * 58}%`,
    '--range-width': `${Math.max(18, ((day.high - day.low) / span) * 58)}%`,
  }
}
</script>

<template>
  <k-page
    component="main"
    class="weather-app"
    :class="forecast ? `weather-app--${forecast.condition}` : ''"
    :colors="{ bgIos: 'bg-transparent' }"
  >
    <div class="weather-app__backdrop" aria-hidden="true"></div>
    <k-navbar class="weather-navbar" :title="phone.t('Apps.weather.name')">
      <template #after>
        <k-link
          component="button"
          :aria-label="phone.t('Apps.weather.refresh')"
          :disabled="weather.isLoading"
          @click="weather.refresh(true)"
        >
          <RefreshCw :size="17" :class="{ 'weather-spin': weather.isLoading }" />
        </k-link>
      </template>
    </k-navbar>

    <div v-if="forecast" class="weather-scroll">
      <header class="weather-hero">
        <div class="weather-location">
          <Navigation :size="13" fill="currentColor" />
          {{ phone.t(`Apps.weather.regions.${forecast.region}`) }}
        </div>
        <component
          :is="conditionIcon(forecast.condition, forecast.timestamp)"
          class="weather-hero__icon"
          :size="82"
          :stroke-width="1.25"
          aria-hidden="true"
        />
        <div class="weather-temperature">{{ forecast.temperature }}°</div>
        <strong>{{ conditionLabel(forecast.condition) }}</strong>
        <p>{{ phone.t(`Apps.weather.summaries.${forecast.condition}`) }}</p>
      </header>

      <p v-if="weather.error" class="weather-stale">
        {{ phone.t('Apps.weather.stale') }}
      </p>

      <section class="weather-details" :aria-label="phone.t('Apps.weather.details')">
        <k-card :colors="cardColors" :content-wrap="false" class="weather-detail-card">
          <ThermometerSun :size="18" />
          <span>{{ phone.t('Apps.weather.feelsLike') }}</span>
          <strong>{{ forecast.feelsLike }}°</strong>
        </k-card>
        <k-card :colors="cardColors" :content-wrap="false" class="weather-detail-card">
          <Wind :size="18" />
          <span>{{ phone.t('Apps.weather.wind') }}</span>
          <strong>{{ forecast.windSpeed }} km/h</strong>
        </k-card>
        <k-card :colors="cardColors" :content-wrap="false" class="weather-detail-card">
          <Droplets :size="18" />
          <span>{{ phone.t('Apps.weather.humidity') }}</span>
          <strong>{{ forecast.humidity }}%</strong>
        </k-card>
        <k-card :colors="cardColors" :content-wrap="false" class="weather-detail-card">
          <Umbrella :size="18" />
          <span>{{ phone.t('Apps.weather.rain') }}</span>
          <strong>{{ forecast.rainChance }}%</strong>
        </k-card>
      </section>

      <k-card
        :colors="cardColors"
        :content-wrap="false"
        class="weather-panel weather-hourly-panel"
      >
        <h2><Gauge :size="15" />{{ phone.t('Apps.weather.hourly') }}</h2>
        <div class="weather-hourly">
          <div
            v-for="(hour, index) in forecast.hourly"
            :key="hour.timestamp"
            class="weather-hour"
          >
            <span>{{ formatHour(hour.timestamp, index) }}</span>
            <component
              :is="conditionIcon(hour.condition, hour.timestamp)"
              :size="24"
              :stroke-width="1.7"
              aria-hidden="true"
            />
            <small v-if="hour.rainChance >= 30">{{ hour.rainChance }}%</small>
            <strong>{{ hour.temperature }}°</strong>
          </div>
        </div>
      </k-card>

      <k-card
        :colors="cardColors"
        :content-wrap="false"
        class="weather-panel weather-daily-panel"
      >
        <h2><CloudSun :size="15" />{{ phone.t('Apps.weather.daily') }}</h2>
        <div
          v-for="(day, index) in forecast.daily"
          :key="day.timestamp"
          class="weather-day"
        >
          <strong>{{ formatDay(day, index) }}</strong>
          <span class="weather-day__condition">
            <component
              :is="conditionIcon(day.condition, day.timestamp)"
              :size="24"
              :stroke-width="1.7"
              aria-hidden="true"
            />
            <small v-if="day.rainChance >= 30">{{ day.rainChance }}%</small>
          </span>
          <span class="weather-day__low">{{ day.low }}°</span>
          <span class="weather-day__range" :style="temperatureRange(day)">
            <i></i>
          </span>
          <span>{{ day.high }}°</span>
        </div>
      </k-card>
    </div>

    <div v-else class="weather-empty">
      <k-preloader v-if="weather.isLoading" />
      <CloudSun v-else :size="52" :stroke-width="1.4" />
      <strong>{{ phone.t(weather.isLoading ? 'Common.loading' : 'Apps.weather.unavailable') }}</strong>
      <k-link v-if="!weather.isLoading" component="button" @click="weather.refresh(true)">
        {{ phone.t('Apps.weather.tryAgain') }}
      </k-link>
    </div>
  </k-page>
</template>
