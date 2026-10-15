<script setup lang="ts">
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  onUpdated,
  ref,
  type ComponentPublicInstance,
  type CSSProperties,
} from 'vue'

import { useSkyNavbar } from '../navbar-context'
import SkyGlass from './SkyGlass.vue'

defineOptions({ inheritAttrs: false })

const props = withDefaults(
  defineProps<{
    activeIndex?: number
    ariaLabel?: string
    compact?: boolean
    glassHighlight?: boolean
    itemCount?: number
    navigation?: boolean
    outline?: boolean
    raised?: boolean
    rounded?: boolean
    strong?: boolean
  }>(),
  {
    activeIndex: undefined,
    ariaLabel: '',
    compact: false,
    glassHighlight: true,
    itemCount: undefined,
    navigation: undefined,
    outline: false,
    raised: false,
    rounded: false,
    strong: false,
  },
)

const insideNavbar = useSkyNavbar()
const isNavbarSegmented = computed(
  () => insideNavbar && typeof props.navigation === 'undefined',
)
const isNavigation = computed(() => props.navigation === true)
const usesGlass = computed(() => isNavigation.value || isNavbarSegmented.value)
const rootComponent = computed(() => (usesGlass.value ? SkyGlass : 'div'))
const root = ref<HTMLElement | ComponentPublicInstance | null>(null)
const measuredItemCount = ref(0)
const measuredActiveIndex = ref(0)
let observer: MutationObserver | undefined

function rootElement(): HTMLElement | null {
  const value = root.value
  if (!value || typeof HTMLElement === 'undefined') return null
  if (value instanceof HTMLElement) return value
  return value.$el instanceof HTMLElement ? value.$el : null
}

function measureChildren(): void {
  const element = rootElement()
  if (!element) return
  const buttons = Array.from(
    element.querySelectorAll<HTMLElement>(':scope > .sky-segmented-button'),
  )
  const activeIndex = buttons.findIndex((button) =>
    button.classList.contains('sky-segmented-button--active'),
  )

  measuredItemCount.value = buttons.length
  measuredActiveIndex.value = activeIndex < 0 ? 0 : activeIndex
}

onMounted(() => {
  measureChildren()
  const element = rootElement()
  if (!element || typeof MutationObserver === 'undefined') return
  observer = new MutationObserver(measureChildren)
  observer.observe(element, {
    attributes: true,
    attributeFilter: ['class'],
    childList: true,
    subtree: true,
  })
})

onUpdated(() => void nextTick(measureChildren))
onBeforeUnmount(() => observer?.disconnect())

const indicatorStyle = computed<CSSProperties | undefined>(() => {
  const itemCount = Number.isFinite(props.itemCount)
    ? Math.max(0, Math.floor(props.itemCount ?? 0))
    : measuredItemCount.value
  if (!props.strong || itemCount === 0) return undefined

  const requestedIndex = Number.isFinite(props.activeIndex)
    ? Math.floor(props.activeIndex ?? 0)
    : measuredActiveIndex.value
  const activeIndex = Math.max(0, Math.min(itemCount - 1, requestedIndex))
  const widthPercentage = Number((100 / itemCount).toFixed(4))
  const edgePadding = usesGlass.value ? 4 : 2
  const spacing = Number(
    ((edgePadding * 2 + (itemCount - 1) * 4) / itemCount).toFixed(4),
  )
  const percentageOffset = activeIndex * 100
  const pixelOffset = activeIndex * 4

  return {
    '--sky-segmented-indicator-offset': `calc(${percentageOffset}% + ${pixelOffset}px)`,
    '--sky-segmented-indicator-offset-rtl': `calc(-${percentageOffset}% - ${pixelOffset}px)`,
    width: `calc(${widthPercentage}% - ${spacing}px)`,
  }
})
</script>

<template>
  <component
    :is="rootComponent"
    ref="root"
    v-bind="$attrs"
    :highlight="usesGlass ? glassHighlight : undefined"
    :material="usesGlass ? 'clear' : undefined"
    class="sky-segmented"
    :class="{
      'sky-segmented--navigation': isNavigation,
      'sky-segmented--navbar': isNavbarSegmented,
      'sky-segmented--compact': compact,
      'sky-segmented--outline': outline,
      'sky-segmented--raised': raised,
      'sky-segmented--rounded': rounded,
      'sky-segmented--strong': strong,
    }"
    role="group"
    :aria-label="ariaLabel || undefined"
  >
    <slot />
    <span
      v-if="indicatorStyle"
      class="sky-segmented__highlight"
      :style="indicatorStyle"
      aria-hidden="true"
    />
  </component>
</template>
