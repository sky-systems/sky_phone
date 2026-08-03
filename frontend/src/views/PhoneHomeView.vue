<script setup lang="ts">
import { kBlock, kButton, kGlass, kNavbar, kPage } from 'konsta/vue'

import { usePhoneStore } from '@/stores/phone'
import { nuiCall } from '@/utils/nui'

const phone = usePhoneStore()

function closePhone(): void {
  phone.close()
  void nuiCall('close')
}
</script>

<template>
  <k-page class="phone-home">
    <k-navbar :title="phone.t('Phone.title')" class="top-0 sticky" />

    <div class="phone-home__content">
      <k-glass class="mx-4 rounded-3xl p-4">
        <h1 class="mb-2 text-xl font-semibold">
          {{ phone.t('Phone.readyTitle') }}
        </h1>
        <p class="text-sm leading-6 text-black/60">
          {{ phone.t('Phone.readyBody') }}
        </p>
      </k-glass>

      <k-block inset>
        <k-button large rounded @click="closePhone">
          {{ phone.t('Phone.close') }}
        </k-button>
      </k-block>
    </div>
  </k-page>
</template>
