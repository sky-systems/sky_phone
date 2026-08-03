<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'

import { usePhoneStore } from '@/stores/phone'
import type { PhoneAppDefinition } from '@/types/apps'

const props = withDefaults(
  defineProps<{
    app: PhoneAppDefinition
    compact?: boolean
    showLabel?: boolean
  }>(),
  {
    compact: false,
    showLabel: true,
  },
)

const phone = usePhoneStore()
const router = useRouter()
const iconFailed = ref(false)

function launch(event: MouseEvent): void {
  const button = event.currentTarget as HTMLElement
  const screen = button.closest('.phone-screen')
  const icon = button.querySelector<HTMLElement>('.app-icon')
  if (screen && icon) {
    const origin = icon.getBoundingClientRect()
    const target = screen.getBoundingClientRect()
    const scaleX = origin.width / target.width
    const scaleY = origin.height / target.height
    const screenScaleX = target.width / screen.clientWidth
    const screenScaleY = target.height / screen.clientHeight
    const iconRadius = Number.parseFloat(getComputedStyle(icon).borderRadius)
    phone.setLaunchOrigin({
      borderRadius: iconRadius / Math.min(scaleX, scaleY),
      scaleX,
      scaleY,
      x: (origin.left - target.left) / screenScaleX,
      y: (origin.top - target.top) / screenScaleY,
    })
  } else {
    phone.setLaunchOrigin(null)
  }

  void router.push(props.app.route)
}
</script>

<template>
  <button
    class="app-icon-button"
    :class="{ 'app-icon-button--compact': compact }"
    type="button"
    :aria-label="phone.t(app.labelKey)"
    @click="launch"
  >
    <span
      class="app-icon"
      :class="[app.iconClass, { 'app-icon--image': !iconFailed }]"
      aria-hidden="true"
    >
      <img
        v-if="!iconFailed"
        :src="app.iconImage"
        alt=""
        draggable="false"
        @error="iconFailed = true"
      />
      <component
        :is="app.icon"
        v-else
        :size="compact ? 18 : 28"
        :stroke-width="2"
      />
    </span>
    <span v-if="showLabel" class="app-icon-label">{{
      phone.t(app.labelKey)
    }}</span>
  </button>
</template>
