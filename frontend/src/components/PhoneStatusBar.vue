<script setup lang="ts">
import { SkyButton, SkyIcon } from '@/ui'

import { PhoneCall } from 'lucide-vue-next'
import { onBeforeUnmount, onMounted, ref } from 'vue'
import PhoneStatusIndicators from '@/components/PhoneStatusIndicators.vue'
import { usePhoneStore } from '@/stores/phone'
import { cellular } from '@/utils/cellular'

const phone = usePhoneStore()
const props = withDefaults(
  defineProps<{
    activeCallReturn?: boolean
    controlCenterOpened?: boolean
    interactive?: boolean
    lockable?: boolean
  }>(),
  {
    activeCallReturn: false,
    controlCenterOpened: false,
    interactive: true,
    lockable: false,
  },
)
const emit = defineEmits<{ activeCall: []; controlCenter: []; lock: [] }>()
const time = ref('')
let intervalId: number | undefined

function updateTime(): void {
  time.value = new Intl.DateTimeFormat([], {
    hour: '2-digit',
    hourCycle: 'h23',
    minute: '2-digit',
  }).format(new Date())
}

function handleTimeClick(): void {
  if (!props.interactive) return
  if (props.activeCallReturn) {
    emit('activeCall')
    return
  }
  emit('lock')
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
    <SkyButton
      variant="content"
      v-if="lockable"
      class="phone-status-bar__time phone-status-bar__time-button"
      :class="{
        'phone-status-bar__time-button--active-call': activeCallReturn,
      }"
      type="button"
      :aria-label="
        phone.t(
          activeCallReturn ? 'Apps.phone.returnToCall' : 'Notifications.center',
        )
      "
      @click.stop="handleTimeClick"
    >
      <SkyIcon
        :icon="PhoneCall"
        v-if="activeCallReturn"
        class="phone-status-bar__active-call-icon"
        aria-hidden="true"
      />
      <time>{{ time }}</time>
    </SkyButton>
    <time v-else class="phone-status-bar__time">{{ time }}</time>
    <component
      :is="interactive ? SkyButton : 'span'"
      :variant="interactive ? 'content' : undefined"
      class="phone-status-bar__indicators"
      :type="interactive ? 'button' : undefined"
      :aria-label="
        !interactive
          ? undefined
          : cellular.enabled && !cellular.hasSignal
            ? phone.t('Cellular.noSignal') +
              '. ' +
              phone.t('ControlCenter.open')
            : phone.t('ControlCenter.open')
      "
      :aria-expanded="interactive ? controlCenterOpened : undefined"
      @click.stop="interactive && emit('controlCenter')"
    >
      <span
        v-if="cellular.enabled && !cellular.hasSignal"
        class="phone-no-signal"
        role="status"
        >{{ phone.t('Cellular.noSignal') }}</span
      >
      <PhoneStatusIndicators
        :airplane-mode="phone.preferences.settings.airplaneMode"
        :cellular-enabled="
          phone.preferences.settings.cellularEnabled &&
          (!cellular.enabled || cellular.hasSignal)
        "
        :wifi-enabled="phone.preferences.settings.wifiEnabled"
      />
    </component>
  </header>
</template>

<style scoped>
.phone-no-signal {
  font-size: 11px;
  white-space: nowrap;
}
</style>
