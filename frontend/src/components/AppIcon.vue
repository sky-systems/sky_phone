<script setup lang="ts">
import { kBadge } from 'konsta/vue'
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'

import { useMailStore } from '@/stores/mail'
import { useMarketplaceStore } from '@/stores/marketplace'
import { useDarkChatStore } from '@/stores/darkchat'
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
const mail = useMailStore()
const marketplace = useMarketplaceStore()
const darkchat = useDarkChatStore()
const router = useRouter()
const iconFailed = ref(false)
const unreadCount = computed(() => {
  if (props.app.id === 'mail') return mail.counts.unread
  if (props.app.id === 'citymarkt') return marketplace.counts.unread
  if (props.app.id === 'darkchat') return darkchat.unreadCount
  return 0
})
const notificationBadgeColors = {
  bg: 'bg-[#ff3b30]',
  text: 'text-white',
}

function launch(event: MouseEvent): void {
  if (!props.app.route) return

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
    :aria-disabled="!app.route"
    @click="launch"
  >
    <span class="app-icon-anchor" aria-hidden="true">
      <span
        class="app-icon"
        :class="[app.iconClass, { 'app-icon--image': !iconFailed }]"
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
      <k-badge
        v-if="unreadCount"
        class="app-icon-badge"
        :small="compact"
        :colors="notificationBadgeColors"
      >
        {{ unreadCount > 99 ? '99+' : unreadCount }}
      </k-badge>
    </span>
    <span v-if="showLabel" class="app-icon-label">{{
      phone.t(app.labelKey)
    }}</span>
  </button>
</template>
