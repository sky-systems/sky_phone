<script setup lang="ts">
import { BatteryMedium, Signal, Wifi } from 'lucide-vue-next'
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { usePhoneStore } from '@/stores/phone'

const phone = usePhoneStore()
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
    <div class="phone-status-bar__indicators" aria-hidden="true">
      <Signal :size="12" :stroke-width="2.5" />
      <Wifi :size="13" :stroke-width="2.5" />
      <BatteryMedium :size="16" :stroke-width="2.4" />
    </div>
  </header>
</template>
