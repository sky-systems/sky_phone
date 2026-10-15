<script setup lang="ts">
import {
  computed,
  onBeforeUnmount,
  onMounted,
  ref,
  shallowRef,
  useId,
  watch,
} from 'vue'

import { readPhoneViewportGeometry } from '@/utils/phoneViewportGeometry'
import { useSkyTheme } from '../theme'
import { createGlassLens, type GlassLens } from './glassLens'

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
    material?: 'clear' | 'regular'
    type?: 'button' | 'reset' | 'submit'
  }>(),
  {
    component: 'div',
    disabled: false,
    highlight: true,
    hoverHighlight: true,
    href: undefined,
    material: 'regular',
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
const theme = useSkyTheme()
const mounted = ref(false)
const lens = shallowRef<GlassLens | null>(null)
const filterId = `sky-glass-lens-${useId()}`
const refractionEnabled = computed(
  () =>
    mounted.value &&
    props.material === 'clear' &&
    (theme?.glassEffects.value ?? true) &&
    document.documentElement.dataset.skyRefraction === 'true',
)
let lensObserver: ResizeObserver | undefined
let lensFrame = 0

function refreshLens(): void {
  cancelAnimationFrame(lensFrame)
  lensFrame = requestAnimationFrame(() => {
    const element = root.value
    if (!element || !refractionEnabled.value) return
    const width = element.offsetWidth
    const height = element.offsetHeight
    if (!width || !height) return
    const cssRadius = getComputedStyle(element).borderTopLeftRadius
    const radius = Math.min(
      width / 2,
      height / 2,
      cssRadius.endsWith('%')
        ? (Math.min(width, height) * parseFloat(cssRadius)) / 100
        : parseFloat(cssRadius) || 0,
    )
    // Maps are static and bounded; never rebuild them in a pointer/animation loop.
    if (width > 1024 || height > 1024) {
      lens.value = null
      return
    }
    lens.value = createGlassLens(width, height, Math.max(1, Math.round(radius)))
  })
}

watch(
  [root, refractionEnabled],
  ([element, enabled]) => {
    lensObserver?.disconnect()
    cancelAnimationFrame(lensFrame)
    lens.value = null
    if (!element || !enabled) return
    lensObserver = new ResizeObserver(refreshLens)
    lensObserver.observe(element)
    refreshLens()
  },
  { flush: 'post' },
)

onMounted(() => {
  mounted.value = true
})

const highlightStyle = computed(() => ({
  '--sky-glass-highlight-x': highlightX.value,
  '--sky-glass-highlight-y': highlightY.value,
  '--sky-glass-touch-scale': touchScale.value,
  ...(lens.value
    ? {
        '--sky-glass-refraction': `url("#${filterId}")`,
        '--sky-glass-rim-image': `url("${lens.value.highlightMap}")`,
      }
    : {}),
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

onBeforeUnmount(() => {
  clearPointerState()
  lensObserver?.disconnect()
  cancelAnimationFrame(lensFrame)
})
</script>

<template>
  <component
    :is="component"
    ref="root"
    v-bind="{ ...$attrs, ...elementProps }"
    class="sky-glass"
    :class="{
      'sky-glass--disabled': disabled,
      'sky-glass--clear': material === 'clear',
      'sky-glass--refractive': !!lens,
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
    <svg
      v-if="lens"
      class="sky-glass__filter"
      width="0"
      height="0"
      aria-hidden="true"
      focusable="false"
    >
      <defs>
        <filter
          :id="filterId"
          x="0"
          y="0"
          :width="lens.width"
          :height="lens.height"
          filterUnits="userSpaceOnUse"
          color-interpolation-filters="sRGB"
        >
          <feImage
            :href="lens.displacementMap"
            x="0"
            y="0"
            :width="lens.width"
            :height="lens.height"
            preserveAspectRatio="none"
            result="displacement"
          />
          <feDisplacementMap
            in="SourceGraphic"
            in2="displacement"
            :scale="lens.scale"
            xChannelSelector="R"
            yChannelSelector="G"
          />
        </filter>
      </defs>
    </svg>
    <span
      v-if="material === 'clear'"
      class="sky-glass__rim"
      aria-hidden="true"
    ></span>
    <slot />
  </component>
</template>
