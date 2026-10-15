<script setup lang="ts">
import {
  computed,
  onBeforeUnmount,
  ref,
  useSlots,
  watch,
  type CSSProperties,
} from 'vue'

import { getSkyNavbarCollapseState } from './navbar-collapse'
import { provideSkyNavbar } from './navbar-context'
import { useSkyPageScroll } from './page-scroll-context'
import SkyGlass from './controls/SkyGlass.vue'

defineOptions({ inheritAttrs: false })

const props = withDefaults(
  defineProps<{
    backAppearance?: 'plain' | 'surface'
    backLabel?: string
    centerTitle?: boolean
    colors?: Record<string, string>
    component?: string
    innerClass?: string
    large?: boolean
    medium?: boolean
    outline?: boolean
    showBack?: boolean
    showBackText?: boolean
    scrollEl?: HTMLElement | null
    subnavbarClass?: string
    subtitle?: string
    title?: string
    transparent?: boolean
    variant?: 'compact' | 'large' | 'medium'
  }>(),
  {
    backAppearance: 'plain',
    backLabel: '',
    centerTitle: true,
    colors: undefined,
    component: 'header',
    innerClass: '',
    large: false,
    medium: false,
    outline: false,
    showBack: false,
    showBackText: false,
    subnavbarClass: '',
    subtitle: '',
    transparent: false,
    title: '',
    variant: 'compact',
  },
)

const emit = defineEmits<{
  back: []
}>()

provideSkyNavbar()

const slots = useSlots()
const pageScroll = useSkyPageScroll()
const resolvedVariant = computed(() => {
  if (props.large) return 'large'
  if (props.medium) return 'medium'
  return props.variant
})
const accessibleBackLabel = computed(() => props.backLabel || props.title)
const hasExtendedTitle = computed(() => resolvedVariant.value !== 'compact')
const isCollapsible = computed(
  () => hasExtendedTitle.value || props.transparent,
)
const titleHeight = computed(() =>
  resolvedVariant.value === 'large' ? 52 : 44,
)
const effectiveScrollElement = computed(() =>
  props.scrollEl === undefined
    ? (pageScroll?.element.value ?? null)
    : props.scrollEl,
)
const collapseState = ref(getSkyNavbarCollapseState(0, titleHeight.value))
const collapseStyle = computed<CSSProperties>(
  () =>
    ({
      '--sky-navbar-collapse-offset': `${collapseState.value.offset}px`,
      '--sky-navbar-compact-title-opacity': `${collapseState.value.compactTitleOpacity}`,
      '--sky-navbar-extended-title-opacity': `${collapseState.value.extendedTitleOpacity}`,
    }) as CSSProperties,
)

let observedScrollElement: HTMLElement | null = null
let animationFrame = 0

function updateCollapse(): void {
  animationFrame = 0
  collapseState.value = isCollapsible.value
    ? getSkyNavbarCollapseState(
        observedScrollElement?.scrollTop ?? 0,
        titleHeight.value,
        hasExtendedTitle.value,
      )
    : getSkyNavbarCollapseState(0, titleHeight.value)
  if (pageScroll) pageScroll.collapseOffset.value = collapseState.value.offset
}

function scheduleCollapseUpdate(): void {
  if (animationFrame) return
  animationFrame = window.requestAnimationFrame(updateCollapse)
}

function detachScrollElement(): void {
  observedScrollElement?.removeEventListener('scroll', scheduleCollapseUpdate)
  observedScrollElement = null
  if (animationFrame) {
    window.cancelAnimationFrame(animationFrame)
    animationFrame = 0
  }
}

watch(
  [effectiveScrollElement, isCollapsible, titleHeight],
  ([element]) => {
    detachScrollElement()
    observedScrollElement = element
    if (element && isCollapsible.value) {
      element.addEventListener('scroll', scheduleCollapseUpdate, {
        passive: true,
      })
    }
    updateCollapse()
  },
  { flush: 'post', immediate: true },
)

onBeforeUnmount(() => {
  detachScrollElement()
  if (pageScroll) pageScroll.collapseOffset.value = 0
})

function hasLeftContent(): boolean {
  return props.showBack || Boolean(slots.left)
}

function hasRightContent(): boolean {
  return Boolean(slots.right)
}

function hasNavigationRow(): boolean {
  return !hasExtendedTitle.value || hasLeftContent() || hasRightContent()
}
</script>

<template>
  <component
    :is="component"
    v-bind="$attrs"
    class="sky-navbar"
    :class="[
      `sky-navbar--${resolvedVariant}`,
      {
        'sky-navbar--outline': outline,
        'sky-navbar--transparent': transparent,
        'sky-navbar--with-subnavbar': Boolean($slots.subnavbar),
        'sky-navbar--no-navigation': !hasNavigationRow(),
      },
    ]"
    :style="collapseStyle"
  >
    <div class="sky-navbar__blur" aria-hidden="true" />
    <div class="sky-navbar__background" aria-hidden="true" />

    <div
      v-if="hasNavigationRow()"
      class="sky-navbar__inner"
      :class="innerClass"
    >
      <SkyGlass
        v-if="hasLeftContent()"
        material="clear"
        :highlight="false"
        class="sky-navbar__left sky-glass-surface"
      >
        <slot name="left">
          <button
            v-if="showBack"
            type="button"
            class="sky-navbar__back"
            :class="`sky-navbar__back--${backAppearance}`"
            :aria-label="accessibleBackLabel"
            @click="emit('back')"
          >
            <svg
              class="sky-navbar__back-icon"
              aria-hidden="true"
              viewBox="0 0 12 20"
            >
              <path
                d="M10.6737904,1.29289322 C11.0342516,1.65335447 11.0619794,2.22054978 10.7569738,2.61281627 L10.6737458,2.70706222 L3.76756619,9.61235263 C3.5939889,9.78590804 3.57468677,10.0553312 3.70967055,10.2502079 L3.76753111,10.3194689 L10.673816,17.2262348 C11.0643303,17.6167774 11.0643188,18.2499456 10.6737904,18.640474 C10.2832661,19.0309983 9.65010112,19.0309983 9.25957683,18.640474 L1.29289322,10.6737904 C0.902368927,10.2832661 0.902368927,9.65010112 1.29289322,9.25957683 L9.25957683,1.29289322 C9.62006079,0.932409257 10.1872918,0.904679722 10.5795831,1.20970461 L10.6737904,1.29289322 Z"
              />
            </svg>
            <span v-if="showBackText" class="sky-navbar__back-label">
              {{ backLabel }}
            </span>
          </button>
        </slot>
      </SkyGlass>

      <div v-if="!hasExtendedTitle" class="sky-navbar__heading">
        <h1 class="sky-navbar__title">
          <slot name="title">{{ title }}</slot>
        </h1>
        <p v-if="subtitle || $slots.subtitle" class="sky-navbar__subtitle">
          <slot name="subtitle">{{ subtitle }}</slot>
        </p>
      </div>

      <SkyGlass
        v-if="hasRightContent()"
        material="clear"
        :highlight="false"
        class="sky-navbar__right sky-glass-surface"
      >
        <slot name="right" />
      </SkyGlass>
    </div>

    <div v-if="hasExtendedTitle" class="sky-navbar__title-container">
      <div>
        <h1 class="sky-navbar__title">
          <slot name="title">{{ title }}</slot>
        </h1>
        <p v-if="subtitle || $slots.subtitle" class="sky-navbar__subtitle">
          <slot name="subtitle">{{ subtitle }}</slot>
        </p>
      </div>
    </div>

    <div
      v-if="hasExtendedTitle"
      class="sky-navbar__collapsed-heading"
      aria-hidden="true"
    >
      <span class="sky-navbar__title">
        <slot name="title">{{ title }}</slot>
      </span>
    </div>

    <div
      v-if="$slots.subnavbar"
      class="sky-navbar__subnavbar"
      :class="subnavbarClass"
    >
      <slot name="subnavbar" />
    </div>
  </component>
</template>
