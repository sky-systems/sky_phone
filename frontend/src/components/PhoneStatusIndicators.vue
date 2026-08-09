<script setup lang="ts">
import { Plane } from 'lucide-vue-next'

withDefaults(
  defineProps<{
    airplaneMode?: boolean
    cellularEnabled?: boolean
    wifiEnabled?: boolean
  }>(),
  {
    airplaneMode: false,
    cellularEnabled: true,
    wifiEnabled: true,
  },
)
</script>

<template>
  <span class="phone-status-indicators" aria-hidden="true">
    <Plane
      v-if="airplaneMode"
      :size="18"
      :stroke-width="2.6"
      fill="currentColor"
    />
    <svg
      v-else-if="cellularEnabled"
      class="phone-status-indicators__signal"
      viewBox="0 0 20 16"
    >
      <rect x="0" y="11" width="3.5" height="5" rx="1.75" />
      <rect x="5.5" y="8" width="3.5" height="8" rx="1.75" />
      <rect x="11" y="4" width="3.5" height="12" rx="1.75" />
      <rect x="16.5" width="3.5" height="16" rx="1.75" opacity="0.42" />
    </svg>
    <svg
      v-if="wifiEnabled && !airplaneMode"
      class="phone-status-indicators__wifi"
      viewBox="0 0 22 17"
      fill="none"
    >
      <path d="M1.5 5.4a14.2 14.2 0 0 1 19 0" />
      <path d="M5 9.2a9 9 0 0 1 12 0" />
      <path d="M8.5 13a3.8 3.8 0 0 1 5 0" />
      <circle cx="11" cy="15.3" r="1.45" />
    </svg>
    <svg class="phone-status-indicators__battery" viewBox="0 0 29 16">
      <rect x="0.75" y="0.75" width="25" height="14.5" rx="4" />
      <rect x="3" y="3" width="14.5" height="10" rx="2.25" />
      <rect x="26.6" y="5" width="2.4" height="6" rx="1.2" />
    </svg>
  </span>
</template>

<style scoped>
.phone-status-indicators {
  display: flex;
  align-items: center;
  gap: 5px;
  line-height: 0;
}

.phone-status-indicators > svg {
  display: block;
  flex: 0 0 auto;
  overflow: visible;
}

.phone-status-indicators__signal {
  width: 18px;
  height: 14px;
  fill: currentColor;
}

.phone-status-indicators__wifi {
  width: 19px;
  height: 15px;
  stroke: currentColor;
  stroke-width: 2.2;
  stroke-linecap: round;
}

.phone-status-indicators__wifi circle {
  fill: currentColor;
  stroke: none;
}

.phone-status-indicators__battery {
  width: 25px;
  height: 14px;
  fill: currentColor;
}

.phone-status-indicators__battery rect:first-child {
  fill: none;
  stroke: currentColor;
  stroke-width: 1.5;
}
</style>
