<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'

import { readPhoneViewportGeometry } from '@/utils/phoneViewportGeometry'

defineOptions({ inheritAttrs: false })

const props = withDefaults(
  defineProps<{
    component?:
      | 'a'
      | 'article'
      | 'aside'
      | 'button'
      | 'div'
      | 'label'
      | 'nav'
      | 'section'
      | 'span'
    disabled?: boolean
    highlight?: boolean
    hoverHighlight?: boolean
    href?: string
    type?: 'button' | 'reset' | 'submit'
  }>(),
  {
    component: 'div',
    disabled: false,
    highlight: true,
    hoverHighlight: true,
    href: undefined,
    type: 'button',
  },
)

const emit = defineEmits<{
  click: [event: MouseEvent]
}>()

const root = ref<HTMLElement | null>(null)
const highlightVisible = ref(false)
const touchHighlight = ref(false)
const highlightX = ref('50%')
const highlightY = ref('50%')
const touchScale = ref('1.05')
const capturedPointerId = ref<number | null>(null)
const highlightStyle = computed(() => ({
  '--sky-glass-highlight-x': highlightX.value,
  '--sky-glass-highlight-y': highlightY.value,
  '--sky-glass-touch-scale': touchScale.value,
}))

const elementProps = computed<Record<string, unknown>>(() => {
  if (props.component === 'a') {
    return {
      'aria-disabled': props.disabled || undefined,
      href: props.disabled ? undefined : props.href,
      tabindex: props.disabled ? -1 : undefined,
    }
  }

  if (props.component === 'button') {
    return {
      disabled: props.disabled,
      type: props.type,
    }
  }

  return {
    'aria-disabled': props.disabled || undefined,
  }
})

function handleClick(event: MouseEvent): void {
  if (props.disabled) {
    event.preventDefault()
    event.stopPropagation()
    return
  }

  emit('click', event)
}

function updateHighlightPosition(event: PointerEvent): void {
  if (
    props.disabled ||
    !props.highlight ||
    !props.hoverHighlight ||
    event.pointerType !== 'mouse'
  ) {
    return
  }

  const element = root.value
  if (!element) return
  const bounds =
    readPhoneViewportGeometry(element)?.rect(element) ??
    element.getBoundingClientRect()
  const scaleX = bounds.width > 0 ? element.offsetWidth / bounds.width : 1
  const scaleY = bounds.height > 0 ? element.offsetHeight / bounds.height : 1
  const localX = (event.clientX - bounds.left) * scaleX
  const localY = (event.clientY - bounds.top) * scaleY
  highlightX.value = `${Math.max(0, Math.min(element.offsetWidth, localX))}px`
  highlightY.value = `${Math.max(0, Math.min(element.offsetHeight, localY))}px`
  highlightVisible.value = true
}

function releasePointerCapture(): void {
  if (
    root.value &&
    capturedPointerId.value !== null &&
    typeof root.value.hasPointerCapture === 'function' &&
    root.value.hasPointerCapture(capturedPointerId.value) &&
    typeof root.value.releasePointerCapture === 'function'
  ) {
    root.value.releasePointerCapture(capturedPointerId.value)
  }
  capturedPointerId.value = null
}

function clearPointerState(): void {
  releasePointerCapture()
  highlightVisible.value = false
  touchHighlight.value = false
}

function handlePointerDown(event: PointerEvent): void {
  if (props.disabled || !props.highlight) return

  if (event.pointerType === 'touch' || event.pointerType === 'pen') {
    const element = root.value
    const bounds = element
      ? (readPhoneViewportGeometry(element)?.rect(element) ??
        element.getBoundingClientRect())
      : null
    touchScale.value =
      bounds && bounds.width <= 60 && bounds.height <= 60 ? '1.25' : '1.05'
    capturedPointerId.value = event.pointerId
    if (typeof root.value?.setPointerCapture === 'function') {
      root.value.setPointerCapture(event.pointerId)
    }
    touchHighlight.value = true
  } else {
    updateHighlightPosition(event)
  }
}

function handlePointerEnd(): void {
  clearPointerState()
}

watch(
  () => [props.disabled, props.highlight] as const,
  ([disabled, highlight]) => {
    if (disabled || !highlight) clearPointerState()
  },
)

onBeforeUnmount(clearPointerState)
</script>

<template>
  <component
    :is="component"
    ref="root"
    v-bind="{ ...$attrs, ...elementProps }"
    class="sky-glass"
    :class="{
      'sky-glass--disabled': disabled,
      'sky-glass--highlight': highlight,
      'sky-glass--highlight-visible': highlightVisible,
      'sky-glass--interactive': component === 'a' || component === 'button',
      'sky-glass--touch-highlight': touchHighlight,
    }"
    :style="highlightStyle"
    @click="handleClick"
    @lostpointercapture="handlePointerEnd"
    @pointercancel="handlePointerEnd"
    @pointerdown="handlePointerDown"
    @pointerleave="handlePointerEnd"
    @pointermove="updateHighlightPosition"
    @pointerup="handlePointerEnd"
  >
    <slot />
  </component>
</template>
