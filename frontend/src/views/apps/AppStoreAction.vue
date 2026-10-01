<script setup lang="ts">
import { usePhoneStore } from '@/stores/phone'

defineProps<{
  action: 'get' | 'installing' | 'open'
  price?: number
}>()

const phone = usePhoneStore()
</script>

<template>
  <span
    class="app-store-action"
    :class="{ 'app-store-action--icon': action === 'installing' }"
    aria-hidden="true"
  >
    <template v-if="action === 'get'">
      {{
        price
          ? phone.t('Apps.customApps.price', {
              price: price.toLocaleString(phone.lang),
            })
          : phone.t('Apps.appStore.get')
      }}
    </template>
    <span
      v-else-if="action === 'installing'"
      class="app-store-action__progress"
    >
      <svg viewBox="0 0 28 28">
        <circle class="app-store-action__track" cx="14" cy="14" r="11" />
        <circle class="app-store-action__value" cx="14" cy="14" r="11" />
      </svg>
      <i></i>
    </span>
    <template v-else>{{ phone.t('Apps.appStore.open') }}</template>
  </span>
</template>

<style scoped>
.app-store-action {
  display: grid;
  place-items: center;
  font: inherit;
}

.app-store-action--icon {
  width: 28px;
  height: 28px;
  color: var(--sky-app-accent);
}

.app-store-action__progress {
  width: 28px;
  height: 28px;
  position: relative;
  display: grid;
  place-items: center;
}

.app-store-action__progress svg {
  width: 28px;
  height: 28px;
  position: absolute;
  inset: 0;
  overflow: visible;
  fill: none;
  stroke-width: 2.2;
}

.app-store-action__track {
  stroke: var(--sky-app-accent-soft);
}

.app-store-action__value {
  stroke: var(--sky-app-accent);
  stroke-linecap: round;
  stroke-dasharray: 69.2;
  stroke-dashoffset: 69.2;
  transform: rotate(-90deg);
  transform-origin: 50% 50%;
  animation: app-store-download-progress 3s linear forwards;
}

.app-store-action__progress i {
  width: 7px;
  height: 7px;
  border-radius: 1.5px;
  background: var(--sky-app-accent);
}

@keyframes app-store-download-progress {
  from {
    stroke-dashoffset: 69.2;
  }
  to {
    stroke-dashoffset: 4;
  }
}

@media (prefers-reduced-motion: reduce) {
  .app-store-action__value {
    animation: none;
    stroke-dashoffset: 34.6;
  }
}
</style>
