<script setup lang="ts">
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  onUpdated,
  ref,
  useAttrs,
  type CSSProperties,
} from 'vue'

import SkyGlass from './controls/SkyGlass.vue'

defineOptions({ inheritAttrs: false })

const props = withDefaults(
  defineProps<{
    bgClass?: string
    component?: string
    floating?: boolean
    icons?: boolean
    innerClass?: string
    label?: string
    labels?: boolean
  }>(),
  {
    bgClass: '',
    component: 'nav',
    floating: true,
    icons: true,
    innerClass: '',
    label: '',
    labels: true,
  },
)

const attrs = useAttrs()
const links = ref<HTMLElement | null>(null)
const hasLinks = ref(false)
const pressed = ref(false)
const highlightWidth = ref('0%')
const highlightTransform = ref('translateX(0%)')
const transitionTimingFunction = ref('')
const accessibleLabel = computed(() => {
  if (props.label) return props.label
  const attribute = attrs['aria-label']
  return typeof attribute === 'string' && attribute ? attribute : undefined
})
let activeIndex = 0
let newActiveIndex = 0
let touchRect: DOMRect | null = null
let touchActive = false
let frame = 0
let suppressNativeClick = false
let observer: MutationObserver | null = null

const highlightStyle = computed<CSSProperties>(() => ({
  transform: highlightTransform.value,
  transitionTimingFunction: transitionTimingFunction.value,
  width: highlightWidth.value,
}))

function getButtons(): HTMLElement[] {
  return links.value
    ? Array.from(links.value.querySelectorAll<HTMLElement>('.sky-tab-button'))
    : []
}

function isRtl(): boolean {
  return links.value ? getComputedStyle(links.value).direction === 'rtl' : false
}

function indexTransform(index: number): string {
  return `translateX(${(isRtl() ? -1 : 1) * index * 100}%)`
}

function updateHighlight(): void {
  const buttons = getButtons()
  if (!buttons.length) {
    hasLinks.value = false
    return
  }

  hasLinks.value = true
  const requestedIndex = buttons.findIndex((button) =>
    button.classList.contains('sky-tab-button--active'),
  )
  activeIndex = requestedIndex >= 0 ? requestedIndex : 0
  newActiveIndex = activeIndex
  highlightWidth.value = `${100 / buttons.length}%`
  highlightTransform.value = indexTransform(activeIndex)
}

function startAnimation(transform: string): void {
  cancelAnimationFrame(frame)
  frame = requestAnimationFrame(() => {
    highlightTransform.value = transform
    transitionTimingFunction.value = 'ease-out'
  })
}

function updateTouchHighlight(event: PointerEvent): void {
  const buttons = getButtons()
  if (!touchRect || !buttons.length) return

  const width = touchRect.width / buttons.length
  const pointerOffset = isRtl()
    ? touchRect.right - event.clientX - width / 2
    : event.clientX - touchRect.left - width / 2
  const offset = Math.max(0, Math.min(pointerOffset, touchRect.width - width))
  newActiveIndex = Math.max(
    0,
    Math.min(buttons.length - 1, Math.round(offset / width)),
  )
  pressed.value = true
  startAnimation(`translateX(${(isRtl() ? -1 : 1) * offset}px)`)
}

function handlePointerDown(event: PointerEvent): void {
  if (event.pointerType !== 'touch' || !links.value || !hasLinks.value) return
  touchRect = links.value.getBoundingClientRect()
  touchActive = true
  updateTouchHighlight(event)
}

function finishTouch(commit: boolean): void {
  if (!touchActive) return

  cancelAnimationFrame(frame)
  touchActive = false
  pressed.value = false
  touchRect = null

  const buttons = getButtons()
  if (commit && activeIndex !== newActiveIndex) {
    buttons[newActiveIndex]?.click()
    suppressNativeClick = true
  }

  const settledIndex = commit ? newActiveIndex : activeIndex
  highlightTransform.value = indexTransform(settledIndex)
  transitionTimingFunction.value = ''
}

function handlePointerMove(event: PointerEvent): void {
  if (touchActive && event.pointerType === 'touch') updateTouchHighlight(event)
}

function handlePointerUp(event: PointerEvent): void {
  if (event.pointerType === 'touch') finishTouch(true)
}

function handlePointerCancel(event: PointerEvent): void {
  if (event.pointerType === 'touch') finishTouch(false)
}

function handleClickCapture(event: MouseEvent): void {
  if (!suppressNativeClick || !event.isTrusted) return
  suppressNativeClick = false
  event.stopPropagation()
}

onMounted(() => {
  updateHighlight()
  observer = new MutationObserver((mutations) => {
    const needsUpdate = mutations.some(
      (mutation) =>
        mutation.type === 'childList' ||
        (mutation.type === 'attributes' &&
          mutation.target instanceof Element &&
          mutation.target.classList.contains('sky-tab-button')),
    )
    if (needsUpdate) updateHighlight()
  })
  if (links.value) {
    observer.observe(links.value, {
      attributeFilter: ['class'],
      attributes: true,
      childList: true,
      subtree: true,
    })
  }
  links.value?.addEventListener('pointerdown', handlePointerDown)
  links.value?.addEventListener('click', handleClickCapture, true)
  document.addEventListener('pointermove', handlePointerMove)
  document.addEventListener('pointerup', handlePointerUp)
  document.addEventListener('pointercancel', handlePointerCancel)
})

onUpdated(() => {
  void nextTick(updateHighlight)
})

onBeforeUnmount(() => {
  cancelAnimationFrame(frame)
  observer?.disconnect()
  observer = null
  links.value?.removeEventListener('pointerdown', handlePointerDown)
  links.value?.removeEventListener('click', handleClickCapture, true)
  document.removeEventListener('pointermove', handlePointerMove)
  document.removeEventListener('pointerup', handlePointerUp)
  document.removeEventListener('pointercancel', handlePointerCancel)
})
</script>

<template>
  <component
    :is="component"
    v-bind="$attrs"
    class="sky-tabbar"
    :class="{
      'sky-tabbar--floating': props.floating,
      'sky-tabbar--icons': props.icons,
      'sky-tabbar--labels': props.labels,
    }"
    :aria-label="accessibleLabel"
  >
    <span class="sky-tabbar__blur" aria-hidden="true" />
    <span class="sky-tabbar__background" :class="bgClass" aria-hidden="true" />
    <div class="sky-tabbar__inner" :class="innerClass">
      <SkyGlass material="clear" class="sky-tabbar__pane">
        <div ref="links" class="sky-tabbar__links">
          <slot />
        </div>
        <span
          v-if="hasLinks"
          class="sky-tabbar__highlight"
          :class="{ 'sky-tabbar__highlight--pressed': pressed }"
          :style="highlightStyle"
          aria-hidden="true"
        >
          <span class="sky-tabbar__highlight-inner" />
          <span class="sky-tabbar__highlight-thumb" />
        </span>
      </SkyGlass>
    </div>
  </component>
</template>
