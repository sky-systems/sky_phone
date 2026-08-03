<script setup lang="ts">
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { usePhoneStore } from '@/stores/phone'

const route = useRoute()
const router = useRouter()
const phone = usePhoneStore()
const isApp = computed(() => route.name === 'app')

function goHome(): void {
  if (isApp.value) void router.push('/')
}
</script>

<template>
  <button
    class="phone-home-indicator"
    :class="{ 'phone-home-indicator--interactive': isApp }"
    type="button"
    :aria-label="phone.t('Common.home')"
    @click="goHome"
  >
    <span aria-hidden="true"></span>
  </button>
</template>
