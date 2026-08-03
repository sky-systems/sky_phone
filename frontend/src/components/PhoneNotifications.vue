<script setup lang="ts">
import { kNotification } from 'konsta/vue'
import { computed } from 'vue'

import { getPhoneApp } from '@/config/apps'
import { useNotificationsStore } from '@/stores/notifications'
import { usePhoneStore } from '@/stores/phone'

const notifications = useNotificationsStore()
const phone = usePhoneStore()
const icon = computed(() =>
  notifications.current
    ? getPhoneApp(notifications.current.appId)?.iconImage
    : undefined,
)
</script>

<template>
  <k-notification
    :opened="!!notifications.current"
    :title="notifications.current?.title"
    :subtitle="notifications.current?.subtitle"
    :text="notifications.current?.text"
    :title-right-text="phone.t('Notifications.now')"
    button="close"
    class="phone-notification"
    @close="notifications.dismissCurrent()"
  >
    <template v-if="icon" #icon>
      <img :src="icon" alt="" class="phone-notification__icon" />
    </template>
    <template #button>
      <span class="sr-only">{{ phone.t('Common.close') }}</span>
    </template>
  </k-notification>
</template>
