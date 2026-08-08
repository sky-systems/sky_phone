<script setup lang="ts">
import { computed } from 'vue'

import clearIcon from '@/assets/img/weather-icons/clear.webp'
import cloudyIcon from '@/assets/img/weather-icons/cloudy.webp'
import fogIcon from '@/assets/img/weather-icons/fog.webp'
import partlyCloudyIcon from '@/assets/img/weather-icons/partly_cloudy.webp'
import rainIcon from '@/assets/img/weather-icons/rain.webp'
import snowIcon from '@/assets/img/weather-icons/snow.webp'
import sunnyIcon from '@/assets/img/weather-icons/sunny.webp'
import thunderIcon from '@/assets/img/weather-icons/thunder.webp'
import type { WeatherConditionId } from '@/types/weather'

const props = withDefaults(
  defineProps<{
    condition: WeatherConditionId
    size?: number
    timestamp?: number
  }>(),
  { size: 24, timestamp: undefined },
)

const icons: Record<WeatherConditionId, string> = {
  sunny: sunnyIcon,
  clear: clearIcon,
  partly_cloudy: partlyCloudyIcon,
  cloudy: cloudyIcon,
  rain: rainIcon,
  thunder: thunderIcon,
  fog: fogIcon,
  snow: snowIcon,
}

const iconSource = computed(() => {
  if (props.condition !== 'clear' || props.timestamp === undefined) {
    return icons[props.condition]
  }

  const hour = new Date(props.timestamp).getUTCHours()
  return hour >= 7 && hour < 20 ? sunnyIcon : clearIcon
})
</script>

<template>
  <img
    class="weather-condition-icon"
    :src="iconSource"
    :width="size"
    :height="size"
    alt=""
    aria-hidden="true"
    draggable="false"
  />
</template>

<style scoped>
.weather-condition-icon {
  display: block;
  object-fit: contain;
}
</style>
