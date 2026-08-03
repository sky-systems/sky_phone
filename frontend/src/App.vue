<script setup lang="ts">
import { kApp } from 'konsta/vue'
import { onBeforeUnmount, onMounted } from 'vue'

import { usePhoneStore, type PhoneOpenPayload } from '@/stores/phone'
import { nuiCall } from '@/utils/nui'

type AppMessage = {
  type?: string
  data?: PhoneOpenPayload
}

const phone = usePhoneStore()

function onMessage(event: MessageEvent<AppMessage>): void {
  if (event.data?.type === 'app:open') {
    phone.open(event.data.data)
  } else if (event.data?.type === 'app:close') {
    phone.close()
  }
}

function onKeydown(event: KeyboardEvent): void {
  if (event.key !== 'Escape' || !phone.isOpen) return

  phone.close()
  void nuiCall('close')
}

onMounted(() => {
  window.addEventListener('message', onMessage)
  window.addEventListener('keydown', onKeydown)
  void nuiCall('ui:ready')

  if (import.meta.env.DEV) {
    phone.open()
  }
})

onBeforeUnmount(() => {
  window.removeEventListener('message', onMessage)
  window.removeEventListener('keydown', onKeydown)
})
</script>

<template>
  <main v-if="phone.isOpen" class="phone-stage">
    <section class="phone-device" aria-label="Phone preview">
      <div class="phone-device__speaker" aria-hidden="true"></div>
      <div class="phone-screen">
        <k-app theme="ios" safe-areas class="phone-app">
          <RouterView />
        </k-app>
      </div>
    </section>
  </main>
</template>
