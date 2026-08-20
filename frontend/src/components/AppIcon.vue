<script setup lang="ts">
import { SkyBadge as kBadge } from '@/ui'
import { Minus } from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'

import { getPhoneAppLabel, isPhoneAppRemovable } from '@/config/apps'
import { useMailStore } from '@/stores/mail'
import { useBillingStore } from '@/stores/billing'
import { useCompaniesStore } from '@/stores/companies'
import { useMarketplaceStore } from '@/stores/marketplace'
import { useDarkChatStore } from '@/stores/darkchat'
import { usePhoneStore } from '@/stores/phone'
import type { PhoneAppDefinition } from '@/types/apps'
import {
  reorderDirectionFromKeyboard,
  type ReorderDirection,
} from '@/utils/keyboard'
import {
  readSpringboardDragMetrics,
  springboardPageDragCompensation,
  springboardSwipeIntent,
  springboardViewportToLocal,
  type SpringboardDragMetrics,
} from '@/utils/springboardDrag'
import { bindPointerDragSession } from '@/utils/pointerDragSession'

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
  dragmove: [event: PointerEvent]
  dragstart: [event: PointerEvent]
  edit: []
  remove: []
  reorder: [direction: ReorderDirection]
}>()

const phone = usePhoneStore()
const mail = useMailStore()
const billing = useBillingStore()
const companies = useCompaniesStore()
const marketplace = useMarketplaceStore()
const darkchat = useDarkChatStore()
const router = useRouter()
const iconFailed = ref(false)
const isDragging = ref(false)
const calendarToday = ref(new Date())
const dragOffset = ref({ x: 0, y: 0 })
let dragStartPage = 0
let dragPageWidth = 0
let dragPageMetrics: SpringboardDragMetrics | null = null
const dragStyle = computed(() =>
  isDragging.value
    ? {
        transform: `translate3d(${springboardPageDragCompensation(dragStartPage, phone.currentPage, dragPageWidth)}px, 0, 0)`,
      }
    : undefined,
)
const dragPointerStyle = computed(() =>
  isDragging.value
    ? {
        transform: `translate3d(${dragOffset.value.x}px, ${dragOffset.value.y}px, 0)`,
      }
    : undefined,
)
const iconStyle = computed(() =>
  props.app.kind === 'external' && props.app.iconBackground
    ? { backgroundColor: props.app.iconBackground }
    : undefined,
)
const suppressClick = ref(false)
let holdTimer: number | undefined
let calendarTimer: number | undefined
let pointerStart = { x: 0, y: 0 }
let pointerTarget: HTMLElement | null = null
let pointerId: number | null = null
let stopPointerSession: (() => void) | null = null

watch(
  () => props.app.iconImage,
  () => {
    iconFailed.value = false
  },
)

const unreadCount = computed(() => {
  if (props.app.id === 'mail') return mail.counts.unread
  if (props.app.id === 'citymarkt') return marketplace.counts.unread
  if (props.app.id === 'darkchat') return darkchat.unreadCount
  if (props.app.id === 'billing') return billing.overview?.unreadCount ?? 0
  if (props.app.id === 'companies') return companies.unreadCount
  return 0
})
const calendarWeekday = computed(() =>
  new Intl.DateTimeFormat(phone.lang, { weekday: 'short' })
    .format(calendarToday.value)
    .replace(/\.$/, ''),
)
const calendarDay = computed(() => calendarToday.value.getDate())

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
function clearHold(): void {
  if (holdTimer !== undefined) window.clearTimeout(holdTimer)
  holdTimer = undefined
}

function onPointerDown(event: PointerEvent): void {
  if (props.compact || event.button !== 0) return
  suppressClick.value = false
  pointerTarget = event.currentTarget as HTMLElement
  pointerId = event.pointerId
  pointerTarget.setPointerCapture(pointerId)
  stopPointerSession?.()
  stopPointerSession = bindPointerDragSession(window, pointerId, {
    cancel: cancelPointerDrag,
    move: onPointerMove,
    up: onPointerUp,
  })
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
    if (dragPageMetrics) {
      const pointer = springboardViewportToLocal(
        event.clientX,
        event.clientY,
        dragPageMetrics.viewportLeft,
        dragPageMetrics.viewportTop,
        dragPageMetrics.viewportWidth,
        dragPageMetrics.viewportHeight,
        dragPageMetrics.layoutWidth,
        dragPageMetrics.layoutHeight,
      )
      const start = springboardViewportToLocal(
        pointerStart.x,
        pointerStart.y,
        dragPageMetrics.viewportLeft,
        dragPageMetrics.viewportTop,
        dragPageMetrics.viewportWidth,
        dragPageMetrics.viewportHeight,
        dragPageMetrics.layoutWidth,
        dragPageMetrics.layoutHeight,
      )
      dragOffset.value = {
        x: pointer.x - start.x,
        y: pointer.y - start.y,
      }
    } else {
      dragOffset.value = {
        x: event.clientX - pointerStart.x,
        y: event.clientY - pointerStart.y,
      }
    }
    emit('dragmove', event)
    return
  }
  if (
    springboardSwipeIntent(
      event.clientX - pointerStart.x,
      event.clientY - pointerStart.y,
    ) !== 'pending'
  ) {
    suppressClick.value = true
    clearHold()
  }
}

function beginPointerDrag(event: PointerEvent): void {
  dragStartPage = phone.currentPage
  const element =
    pointerTarget ??
    (event.currentTarget instanceof Element
      ? event.currentTarget
      : event.target instanceof Element
        ? event.target
        : null)
  dragPageMetrics = readSpringboardDragMetrics(element)
  dragPageWidth = dragPageMetrics?.layoutWidth ?? 0
  isDragging.value = true
  emit('dragstart', event)
}

function onPointerUp(event: PointerEvent): void {
  clearHold()
  if (isDragging.value) {
    suppressClick.value = true
    isDragging.value = false
    dragOffset.value = { x: 0, y: 0 }
    releasePointerCapture()
    emit('dragend', event)
    return
  }
  releasePointerCapture()
}

function cancelPointerDrag(): void {
  clearHold()
  const wasDragging = isDragging.value
  isDragging.value = false
  dragOffset.value = { x: 0, y: 0 }
  releasePointerCapture()
  if (wasDragging) emit('dragcancel')
}

function releasePointerCapture(): void {
  stopPointerSession?.()
  stopPointerSession = null
  if (
    pointerTarget &&
    pointerId !== null &&
    pointerTarget.hasPointerCapture(pointerId)
  ) {
    pointerTarget.releasePointerCapture(pointerId)
  }
  pointerTarget = null
  pointerId = null
  dragPageMetrics = null
}

function onKeydown(event: KeyboardEvent): void {
  if (!props.editMode) return
  const direction = reorderDirectionFromKeyboard(event)
  if (!direction) return
  event.preventDefault()
  event.stopPropagation()
  emit('reorder', direction)
}

onMounted(() => {
  if (props.app.id !== 'calendar') return
  calendarTimer = window.setInterval(() => {
    calendarToday.value = new Date()
  }, 60_000)
})

onBeforeUnmount(() => {
  clearHold()
  if (calendarTimer !== undefined) window.clearInterval(calendarTimer)
  cancelPointerDrag()
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
      :aria-label="getPhoneAppLabel(app, phone.t)"
      :aria-disabled="!app.route"
      :aria-keyshortcuts="
        editMode ? 'ArrowLeft ArrowRight ArrowUp ArrowDown' : undefined
      "
      :style="dragPointerStyle"
      @click="launch"
      @contextmenu.prevent
      @keydown="onKeydown"
      @pointerdown="onPointerDown"
    >
      <span class="app-icon-anchor" aria-hidden="true">
        <span
          class="app-icon"
          :class="[
            app.iconClass,
            {
              'app-icon--image':
                !iconFailed && Boolean(app.iconImage) && app.id !== 'calendar',
            },
          ]"
          :style="iconStyle"
        >
          <span v-if="app.id === 'calendar'" class="app-icon-calendar">
            <strong>{{ calendarWeekday }}</strong>
            <b>{{ calendarDay }}</b>
          </span>
          <img
            v-else-if="!iconFailed && app.iconImage"
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
          tone="danger"
        >
          {{ unreadCount > 99 ? '99+' : unreadCount }}
        </k-badge>
      </span>
      <span v-if="showLabel" class="app-icon-label">{{
        getPhoneAppLabel(app, phone.t)
      }}</span>
    </button>
    <button
      v-if="editMode && isPhoneAppRemovable(app)"
      class="app-icon-remove"
      type="button"
      :aria-label="
        phone.t('Home.removeApp', {
          app: getPhoneAppLabel(app, phone.t),
        })
      "
      :style="dragPointerStyle"
      @click.stop="emit('remove')"
      @pointerdown.stop
    >
      <span class="app-icon-remove__badge" aria-hidden="true">
        <Minus :size="14" :stroke-width="4" />
      </span>
    </button>
  </div>
</template>
