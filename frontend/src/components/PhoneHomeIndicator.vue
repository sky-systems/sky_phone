<script setup lang="ts">
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { usePhoneStore } from '@/stores/phone'

const route = useRoute()
const router = useRouter()
const phone = usePhoneStore()
const HOME_PAGE = 1
const canGoHome = computed(
  () => route.name !== 'home' || phone.currentPage !== HOME_PAGE,
)

function goHome(): void {
  if (!canGoHome.value) return

  phone.setCurrentPage(HOME_PAGE)
  if (route.name !== 'home') void router.push('/')
}
</script>

<template>
  <button
    class="phone-home-indicator"
    :class="{ 'phone-home-indicator--interactive': canGoHome }"
    type="button"
    :aria-label="phone.t('Common.home')"
    @pointerdown.stop="goHome"
    @click.stop="goHome"
  >
    <span aria-hidden="true"></span>
  </button>
</template>
