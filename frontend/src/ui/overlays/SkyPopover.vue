<script setup lang="ts">
import {
  computed,
  nextTick,
  onBeforeUnmount,
  ref,
  watch,
  type CSSProperties,
} from 'vue'
import { useOverlayFocusTrap } from './useOverlayFocusTrap'

defineOptions({ inheritAttrs: false })

type PopoverPlacement = 'auto' | 'bottom' | 'left' | 'right' | 'top'
type ResolvedPopoverPlacement = Exclude<PopoverPlacement, 'auto'>
type PositionError =
  | 'geometry-unavailable'
  | 'invalid-target-selector'
  | 'target-unavailable'

interface TargetBox {
  element: HTMLElement | null
  height: number
  left: number
  top: number
  width: number
}

interface PopoverPosition {
  anchored: boolean
  arrowOffset: number
  left: number
  placement: ResolvedPopoverPlacement
  top: number
}

const props = withDefaults(
  defineProps<{
    angle?: boolean
    angleClass?: string
    ariaDescribedby?: string
    ariaLabel?: string
    ariaLabelledby?: string
    ariaModal?: boolean | 'false' | 'true'
    backdrop?: boolean
    component?: 'div' | 'section'
    modal?: boolean
    motion?: 'fade' | 'spring'
    offset?: number
    opened: boolean
    placement?: PopoverPlacement
    role?: 'alertdialog' | 'dialog' | 'listbox' | 'menu' | 'region'
    tabindex?: number | string
    target?: HTMLElement | string | null
    targetHeight?: number
    targetWidth?: number
    targetX?: number
    targetY?: number
    viewportMargin?: number
  }>(),
  {
    angle: false,
    ariaModal: true,
    backdrop: true,
    component: 'div',
    modal: true,
    motion: 'spring',
    offset: 10,
    placement: 'auto',
    role: 'dialog',
    tabindex: -1,
    viewportMargin: 8,
  },
)

const emit = defineEmits<{
  backdropclick: [event: MouseEvent]
  escape: [event: KeyboardEvent]
  positionerror: [reason: PositionError]
}>()

const root = ref<HTMLElement | null>(null)
const panel = ref<HTMLElement | null>(null)
const position = ref<PopoverPosition | null>(null)
const trapActive = computed(
  () => props.opened && props.modal && position.value !== null,
)
const effectiveRole = computed(() => {
  const isDialog = props.role === 'dialog' || props.role === 'alertdialog'
  return isDialog && !props.ariaLabel && !props.ariaLabelledby
    ? 'region'
    : props.role
})
const hasDialogRole = computed(
  () =>
    effectiveRole.value === 'dialog' || effectiveRole.value === 'alertdialog',
)

const panelStyle = computed<CSSProperties>(() => {
  if (!position.value) return { visibility: 'hidden' }

  return {
    left: `${position.value.left}px`,
    top: `${position.value.top}px`,
  }
})

const arrowSide = computed<ResolvedPopoverPlacement>(() => {
  switch (position.value?.placement) {
    case 'bottom':
      return 'top'
    case 'left':
      return 'right'
    case 'right':
      return 'left'
    default:
      return 'bottom'
  }
})

const arrowStyle = computed<CSSProperties>(() => {
  if (!position.value) return {}

  if (
    position.value.placement === 'top' ||
    position.value.placement === 'bottom'
  ) {
    return { left: `${position.value.arrowOffset}px` }
  }

  return { top: `${position.value.arrowOffset}px` }
})

let animationFrame: number | null = null
let listenersAttached = false
let lastPositionError: PositionError | null = null
let resizeObserver: ResizeObserver | null = null
let observedElements: Element[] = []

useOverlayFocusTrap({
  onEscape: (event) => emit('escape', event),
  opened: trapActive,
  panel,
  root,
})

function isFiniteNumber(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value)
}

function positiveNumber(value: number, fallback: number): number {
  return isFiniteNumber(value) ? Math.max(0, value) : fallback
}

function scaleFor(renderedSize: number, layoutSize: number): number {
  if (renderedSize <= 0 || layoutSize <= 0) return 1
  return renderedSize / layoutSize
}

function reportPositionError(reason: PositionError): void {
  if (lastPositionError === reason) return

  lastPositionError = reason
  console.warn(`[sky_phone] SkyPopover positioning failed: ${reason}.`)
  emit('positionerror', reason)
}

function resolveTargetBox(
  rootElement: HTMLElement,
  rootRect: DOMRect,
): TargetBox | PositionError {
  const scaleX = scaleFor(rootRect.width, rootElement.clientWidth)
  const scaleY = scaleFor(rootRect.height, rootElement.clientHeight)

  let targetElement: HTMLElement | null = null

  if (props.target instanceof HTMLElement) {
    targetElement = props.target
  } else if (typeof props.target === 'string' && props.target.trim()) {
    try {
      const match = document.querySelector(props.target)
      if (match instanceof HTMLElement) targetElement = match
    } catch {
      return 'invalid-target-selector'
    }
  }

  if (targetElement) {
    if (!targetElement.isConnected) return 'target-unavailable'

    const targetRect = targetElement.getBoundingClientRect()

    return {
      element: targetElement,
      height: targetRect.height / scaleY,
      left: (targetRect.left - rootRect.left) / scaleX,
      top: (targetRect.top - rootRect.top) / scaleY,
      width: targetRect.width / scaleX,
    }
  }

  if (isFiniteNumber(props.targetX) && isFiniteNumber(props.targetY)) {
    return {
      element: null,
      height: positiveNumber(props.targetHeight ?? 0, 0) / scaleY,
      left: (props.targetX - rootRect.left) / scaleX,
      top: (props.targetY - rootRect.top) / scaleY,
      width: positiveNumber(props.targetWidth ?? 0, 0) / scaleX,
    }
  }

  return 'target-unavailable'
}

function placementOrder(): ResolvedPopoverPlacement[] {
  switch (props.placement) {
    case 'bottom':
      return ['bottom', 'top', 'right', 'left']
    case 'left':
      return ['left', 'right', 'top', 'bottom']
    case 'right':
      return ['right', 'left', 'top', 'bottom']
    case 'top':
      return ['top', 'bottom', 'right', 'left']
    default:
      return ['top', 'bottom', 'right', 'left']
  }
}

function selectPlacement(
  target: TargetBox,
  panelWidth: number,
  panelHeight: number,
  rootWidth: number,
  rootHeight: number,
  margin: number,
  offset: number,
): ResolvedPopoverPlacement {
  const available: Record<ResolvedPopoverPlacement, number> = {
    bottom: rootHeight - margin - target.top - target.height,
    left: target.left - margin,
    right: rootWidth - margin - target.left - target.width,
    top: target.top - margin,
  }
  const required: Record<ResolvedPopoverPlacement, number> = {
    bottom: panelHeight + offset,
    left: panelWidth + offset,
    right: panelWidth + offset,
    top: panelHeight + offset,
  }
  const order = placementOrder()
  const fittingPlacement = order.find(
    (candidate) => available[candidate] >= required[candidate],
  )

  if (fittingPlacement) return fittingPlacement

  return order.reduce((best, candidate) =>
    available[candidate] > available[best] ? candidate : best,
  )
}

function axisBounds(
  containerSize: number,
  itemSize: number,
  margin: number,
): { max: number; min: number } {
  const availableStart = Math.max(0, containerSize - itemSize)
  const min = Math.min(margin, availableStart)

  return {
    max: Math.max(min, availableStart - margin),
    min,
  }
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max)
}

function clampArrowOffset(value: number, panelSize: number): number {
  const min = Math.min(16, panelSize / 2)
  const max = Math.max(min, panelSize - 16)
  return clamp(value, min, max)
}

function syncResizeObserver(elements: Element[]): void {
  if (typeof ResizeObserver === 'undefined') return

  const unchanged =
    elements.length === observedElements.length &&
    elements.every((element, index) => element === observedElements[index])

  if (unchanged) return

  if (!resizeObserver) {
    resizeObserver = new ResizeObserver(() => schedulePosition())
  }

  resizeObserver.disconnect()
  observedElements = elements
  elements.forEach((element) => resizeObserver?.observe(element))
}

function centeredFallback(
  rootWidth: number,
  rootHeight: number,
  panelWidth: number,
  panelHeight: number,
): PopoverPosition {
  return {
    anchored: false,
    arrowOffset: 0,
    left: Math.max(0, (rootWidth - panelWidth) / 2),
    placement: 'top',
    top: Math.max(0, (rootHeight - panelHeight) / 2),
  }
}

function updatePosition(): void {
  if (!props.opened || !root.value || !panel.value) return

  const rootElement = root.value
  const panelElement = panel.value
  const rootRect = rootElement.getBoundingClientRect()
  const rootWidth = rootElement.clientWidth
  const rootHeight = rootElement.clientHeight
  const panelWidth = panelElement.offsetWidth
  const panelHeight = panelElement.offsetHeight

  syncResizeObserver([rootElement, panelElement])

  if (
    rootWidth <= 0 ||
    rootHeight <= 0 ||
    panelWidth <= 0 ||
    panelHeight <= 0
  ) {
    position.value = null
    reportPositionError('geometry-unavailable')
    return
  }

  const resolvedTarget = resolveTargetBox(rootElement, rootRect)

  if (typeof resolvedTarget === 'string') {
    syncResizeObserver([rootElement, panelElement])
    position.value = centeredFallback(
      rootWidth,
      rootHeight,
      panelWidth,
      panelHeight,
    )
    reportPositionError(resolvedTarget)
    return
  }

  lastPositionError = null
  syncResizeObserver(
    resolvedTarget.element
      ? [rootElement, panelElement, resolvedTarget.element]
      : [rootElement, panelElement],
  )

  const margin = positiveNumber(props.viewportMargin, 8)
  const offset = positiveNumber(props.offset, 10)
  const placement = selectPlacement(
    resolvedTarget,
    panelWidth,
    panelHeight,
    rootWidth,
    rootHeight,
    margin,
    offset,
  )
  const horizontalBounds = axisBounds(rootWidth, panelWidth, margin)
  const verticalBounds = axisBounds(rootHeight, panelHeight, margin)

  let left = resolvedTarget.left + resolvedTarget.width / 2 - panelWidth / 2
  let top = resolvedTarget.top + resolvedTarget.height / 2 - panelHeight / 2

  if (placement === 'top') {
    top = resolvedTarget.top - panelHeight - offset
  } else if (placement === 'bottom') {
    top = resolvedTarget.top + resolvedTarget.height + offset
  } else if (placement === 'left') {
    left = resolvedTarget.left - panelWidth - offset
  } else {
    left = resolvedTarget.left + resolvedTarget.width + offset
  }

  left = clamp(left, horizontalBounds.min, horizontalBounds.max)
  top = clamp(top, verticalBounds.min, verticalBounds.max)

  const arrowOffset =
    placement === 'top' || placement === 'bottom'
      ? clampArrowOffset(
          resolvedTarget.left + resolvedTarget.width / 2 - left,
          panelWidth,
        )
      : clampArrowOffset(
          resolvedTarget.top + resolvedTarget.height / 2 - top,
          panelHeight,
        )

  position.value = {
    anchored: true,
    arrowOffset,
    left,
    placement,
    top,
  }
}

function schedulePosition(): void {
  if (!props.opened || animationFrame !== null) return

  animationFrame = window.requestAnimationFrame(() => {
    animationFrame = null
    updatePosition()
  })
}

function onDocumentKeydown(event: KeyboardEvent): void {
  if (
    !props.opened ||
    event.key !== 'Escape' ||
    event.isComposing ||
    (props.modal && position.value)
  ) {
    return
  }

  event.preventDefault()
  event.stopPropagation()
  emit('escape', event)
}

function attachListeners(): void {
  if (listenersAttached) return

  window.addEventListener('resize', schedulePosition)
  document.addEventListener('scroll', schedulePosition, true)
  document.addEventListener('keydown', onDocumentKeydown, true)
  listenersAttached = true
}

function detachListeners(): void {
  if (listenersAttached) {
    window.removeEventListener('resize', schedulePosition)
    document.removeEventListener('scroll', schedulePosition, true)
    document.removeEventListener('keydown', onDocumentKeydown, true)
    listenersAttached = false
  }

  if (animationFrame !== null) {
    window.cancelAnimationFrame(animationFrame)
    animationFrame = null
  }

  resizeObserver?.disconnect()
  resizeObserver = null
  observedElements = []
}

watch(
  () => props.opened,
  async (opened) => {
    if (!opened) {
      detachListeners()
      lastPositionError = null
      return
    }

    attachListeners()
    await nextTick()
    if (props.opened) updatePosition()
  },
  { immediate: true, flush: 'post' },
)

watch(
  () => [
    props.angle,
    props.offset,
    props.placement,
    props.target,
    props.targetHeight,
    props.targetWidth,
    props.targetX,
    props.targetY,
    props.viewportMargin,
  ],
  async () => {
    if (!props.opened) return

    await nextTick()
    schedulePosition()
  },
  { flush: 'post' },
)

onBeforeUnmount(detachListeners)
</script>

<template>
  <Transition
    :name="motion === 'fade' ? 'sky-popover-fade' : 'sky-popover-scale'"
    :duration="
      motion === 'fade'
        ? { enter: 160, leave: 160 }
        : { enter: 600, leave: 600 }
    "
    appear
  >
    <div
      v-if="opened"
      ref="root"
      v-bind="$attrs"
      class="sky-popover"
      :class="{
        'sky-popover--modal': modal,
        'sky-popover--positioned': position,
      }"
    >
      <div
        v-if="backdrop"
        class="sky-overlay-backdrop sky-popover__backdrop"
        aria-hidden="true"
        @click="emit('backdropclick', $event)"
      ></div>

      <component
        :is="component"
        ref="panel"
        class="sky-popover__panel sky-glass-surface"
        :class="
          position ? `sky-popover__panel--${position.placement}` : undefined
        "
        :style="panelStyle"
        :role="effectiveRole"
        :aria-describedby="ariaDescribedby"
        :aria-label="ariaLabel"
        :aria-labelledby="ariaLabel ? undefined : ariaLabelledby"
        :aria-modal="modal && hasDialogRole ? ariaModal : undefined"
        :tabindex="tabindex"
      >
        <div
          v-if="angle && position?.anchored"
          class="sky-popover__arrow-wrap"
          :class="[angleClass, `sky-popover__arrow-wrap--${arrowSide}`]"
          :style="arrowStyle"
          aria-hidden="true"
        >
          <span class="sky-popover__arrow"></span>
        </div>

        <div class="sky-popover__content"><slot /></div>
      </component>
    </div>
  </Transition>
</template>
