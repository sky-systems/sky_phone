<script setup lang="ts">
import { kBadge } from 'konsta/vue'
import { Minus } from 'lucide-vue-next'
import { computed, onBeforeUnmount, ref } from 'vue'
import { useRouter } from 'vue-router'

import { NON_REMOVABLE_PHONE_APP_IDS } from '@/config/apps'
import { useMailStore } from '@/stores/mail'
import { useMarketplaceStore } from '@/stores/marketplace'
import { useDarkChatStore } from '@/stores/darkchat'
import { usePhoneStore } from '@/stores/phone'
import type { PhoneAppDefinition } from '@/types/apps'

const props = withDefaults(
  defineProps<{
    app: PhoneAppDefinition
    compact?: boolean
    editMode?: boolean
    showLabel?: boolean
  }>(),
  {
    compact: false,
    editMode: false,
    showLabel: true,
  },
)
const emit = defineEmits<{
  dragcancel: []
  dragend: [event: PointerEvent]
  dragstart: [event: PointerEvent]
  edit: []
  remove: []
}>()

const phone = usePhoneStore()
const mail = useMailStore()
const marketplace = useMarketplaceStore()
const darkchat = useDarkChatStore()
const router = useRouter()
const iconFailed = ref(false)
const isDragging = ref(false)
const dragOffset = ref({ x: 0, y: 0 })
const dragStyle = computed(() =>
  isDragging.value
    ? {
        transform: `translate(${dragOffset.value.x}px, ${dragOffset.value.y}px)`,
      }
    : undefined,
)
const suppressClick = ref(false)
let holdTimer: number | undefined
let pointerStart = { x: 0, y: 0 }
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
  if (props.editMode || suppressClick.value) {
    suppressClick.value = false
    return
  }
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
const removeBadgeColors = {
  bg: 'bg-[#8e8e93]',
  text: 'text-black',
}

function clearHold(): void {
  if (holdTimer !== undefined) window.clearTimeout(holdTimer)
  holdTimer = undefined
}

function onPointerDown(event: PointerEvent): void {
  if (props.compact || event.button !== 0) return
  pointerStart = { x: event.clientX, y: event.clientY }
  clearHold()
  if (props.editMode) {
    beginPointerDrag(event)
    return
  }
  holdTimer = window.setTimeout(() => {
    suppressClick.value = true
    emit('edit')
    beginPointerDrag(event)
    holdTimer = undefined
  }, 520)
}

function onPointerMove(event: PointerEvent): void {
  if (isDragging.value) {
    dragOffset.value = {
      x: event.clientX - pointerStart.x,
      y: event.clientY - pointerStart.y,
    }
    return
  }
  if (
    Math.hypot(event.clientX - pointerStart.x, event.clientY - pointerStart.y) >
    8
  ) {
    clearHold()
  }
}

function beginPointerDrag(event: PointerEvent): void {
  isDragging.value = true
  window.addEventListener('pointermove', onPointerMove)
  window.addEventListener('pointerup', onPointerUp)
  window.addEventListener('pointercancel', cancelPointerDrag)
  emit('dragstart', event)
}

function onPointerUp(event: PointerEvent): void {
  clearHold()
  if (!isDragging.value) return
  suppressClick.value = true
  emit('dragend', event)
  isDragging.value = false
  dragOffset.value = { x: 0, y: 0 }
  removeDragListeners()
}

function cancelPointerDrag(): void {
  clearHold()
  if (!isDragging.value) return
  isDragging.value = false
  dragOffset.value = { x: 0, y: 0 }
  removeDragListeners()
  emit('dragcancel')
}

function removeDragListeners(): void {
  window.removeEventListener('pointermove', onPointerMove)
  window.removeEventListener('pointerup', onPointerUp)
  window.removeEventListener('pointercancel', cancelPointerDrag)
}

onBeforeUnmount(() => {
  clearHold()
  removeDragListeners()
})
</script>

<template>
  <div
    class="app-icon-item"
    :class="{
      'app-icon-item--compact': compact,
      'app-icon-item--dragging': isDragging,
      'app-icon-item--editing': editMode,
    }"
    :style="dragStyle"
  >
    <button
      class="app-icon-button"
      :class="{ 'app-icon-button--compact': compact }"
      type="button"
      :aria-label="phone.t(app.labelKey)"
      :aria-disabled="!app.route"
      @click="launch"
      @contextmenu.prevent
      @pointercancel="cancelPointerDrag"
      @pointerdown="onPointerDown"
      @pointerleave="isDragging || clearHold()"
      @pointermove="onPointerMove"
      @pointerup="onPointerUp"
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
    <button
      v-if="editMode && !NON_REMOVABLE_PHONE_APP_IDS.has(app.id)"
      class="app-icon-remove"
      type="button"
      :aria-label="phone.t('Home.removeApp', { app: phone.t(app.labelKey) })"
      @click.stop="emit('remove')"
      @pointerdown.stop
    >
      <k-badge class="app-icon-remove__badge" :colors="removeBadgeColors">
        <Minus :size="15" :stroke-width="3" aria-hidden="true" />
      </k-badge>
    </button>
  </div>
</template>
