<script setup lang="ts">
import { kApp } from 'konsta/vue'
import { computed, onBeforeUnmount, onMounted } from 'vue'
import { useRoute } from 'vue-router'

import PhoneHomeIndicator from '@/components/PhoneHomeIndicator.vue'
import PhoneStatusBar from '@/components/PhoneStatusBar.vue'
import { usePhoneStore, type PhoneOpenPayload } from '@/stores/phone'
import { nuiCall } from '@/utils/nui'
import SpringboardView from '@/views/SpringboardView.vue'

type AppMessage = {
  type?: string
  data?: PhoneOpenPayload
}

const phone = usePhoneStore()
const route = useRoute()
const isAppRoute = computed(() => route.name === 'app')

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
  if (import.meta.env.DEV) phone.open()
})

onBeforeUnmount(() => {
  window.removeEventListener('message', onMessage)
  window.removeEventListener('keydown', onKeydown)
})
</script>

<template>
  <main v-if="phone.isOpen" class="phone-stage">
    <section class="phone-device" :aria-label="phone.t('Common.phone')">
      <div class="phone-device__island" aria-hidden="true"></div>
      <div class="phone-screen" :class="{ 'phone-screen--app': isAppRoute }">
        <k-app theme="ios" dark safe-areas class="phone-app">
          <PhoneStatusBar />
          <SpringboardView />
          <RouterView v-slot="{ Component }">
            <Transition name="app-window">
              <component :is="Component" v-if="isAppRoute" />
            </Transition>
          </RouterView>
          <PhoneHomeIndicator />
        </k-app>
      </div>
    </section>
  </main>
</template>
