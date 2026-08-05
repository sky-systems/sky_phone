<script setup lang="ts">
import { kNotification } from 'konsta/vue'
import { computed } from 'vue'

import { getPhoneApp } from '@/config/apps'
import type { PhoneNotification } from '@/stores/notifications'
import { usePhoneStore } from '@/stores/phone'

const props = defineProps<{
  notification: PhoneNotification | null
}>()
const emit = defineEmits<{
  close: []
}>()
const phone = usePhoneStore()
const icon = computed(() =>
  props.notification
    ? getPhoneApp(props.notification.appId)?.iconImage
    : undefined,
)
</script>

<template>
  <k-notification
    :opened="!!notification"
    :title="notification?.title"
    :subtitle="notification?.subtitle"
    :text="notification?.text"
    :title-right-text="phone.t('Notifications.now')"
    button="close"
    class="phone-notification"
    @close="emit('close')"
  >
    <template v-if="icon" #icon>
      <img :src="icon" alt="" class="phone-notification__icon" />
    </template>
    <template #button>
      <span class="sr-only">{{ phone.t('Common.close') }}</span>
    </template>
  </k-notification>
</template>
