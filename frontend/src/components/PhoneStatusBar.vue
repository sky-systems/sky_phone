<script setup lang="ts">
import { BatteryMedium, Plane, Signal, Wifi } from 'lucide-vue-next'
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { usePhoneStore } from '@/stores/phone'

const phone = usePhoneStore()
withDefaults(defineProps<{ controlCenterOpened?: boolean }>(), {
  controlCenterOpened: false,
})
const emit = defineEmits<{ controlCenter: [] }>()
const time = ref('')
let intervalId: number | undefined

function updateTime(): void {
  time.value = new Intl.DateTimeFormat([], {
    hour: 'numeric',
    minute: '2-digit',
  }).format(new Date())
}

onMounted(() => {
  updateTime()
  intervalId = window.setInterval(updateTime, 30_000)
})

onBeforeUnmount(() => {
  if (intervalId !== undefined) window.clearInterval(intervalId)
})
</script>

<template>
  <header class="phone-status-bar" :aria-label="phone.t('Common.phoneStatus')">
    <time>{{ time }}</time>
    <button
      class="phone-status-bar__indicators"
      type="button"
      :aria-label="phone.t('ControlCenter.open')"
      :aria-expanded="controlCenterOpened"
      @click.stop="emit('controlCenter')"
    >
      <Plane
        v-if="phone.preferences.settings.airplaneMode"
        :size="18"
        :stroke-width="2.5"
        aria-hidden="true"
      />
      <Signal
        v-else-if="phone.preferences.settings.cellularEnabled"
        :size="19"
        :stroke-width="2.5"
        aria-hidden="true"
      />
      <Wifi
        v-if="
          phone.preferences.settings.wifiEnabled &&
          !phone.preferences.settings.airplaneMode
        "
        :size="20"
        :stroke-width="2.5"
        aria-hidden="true"
      />
      <BatteryMedium :size="26" :stroke-width="2.4" aria-hidden="true" />
    </button>
  </header>
</template>
