<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import PhoneStatusIndicators from '@/components/PhoneStatusIndicators.vue'
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
    hour: '2-digit',
    hourCycle: 'h23',
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
    <time class="phone-status-bar__time">{{ time }}</time>
    <button
      class="phone-status-bar__indicators"
      type="button"
      :aria-label="phone.t('ControlCenter.open')"
      :aria-expanded="controlCenterOpened"
      @click.stop="emit('controlCenter')"
    >
      <PhoneStatusIndicators
        :airplane-mode="phone.preferences.settings.airplaneMode"
        :cellular-enabled="phone.preferences.settings.cellularEnabled"
        :wifi-enabled="phone.preferences.settings.wifiEnabled"
      />
    </button>
  </header>
</template>
