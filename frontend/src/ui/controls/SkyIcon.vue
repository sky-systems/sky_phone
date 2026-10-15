<script setup lang="ts">
import { computed, type Component, type CSSProperties, useSlots } from 'vue'

import SkyBadge from './SkyBadge.vue'

defineOptions({ inheritAttrs: false })

const props = withDefaults(
  defineProps<{
    badge?: number | string
    badgeColors?: {
      bg?: string
      text?: string
    }
    component?: string
    icon?: Component
    label?: string
    size?: number | string
    src?: string
  }>(),
  {
    badge: undefined,
    badgeColors: undefined,
    component: 'i',
    icon: undefined,
    label: '',
    size: undefined,
    src: undefined,
  },
)

const slots = useSlots()

const iconStyle = computed<CSSProperties | undefined>(() => {
  const requestedSize = props.size
  if (requestedSize === undefined && !props.src) return undefined
  const size =
    typeof requestedSize === 'number' ? `${requestedSize}px` : requestedSize
  return {
    ...(requestedSize === undefined ? {} : { height: size, width: size }),
    ...(props.size === undefined ? {} : { '--sky-icon-size': size }),
    ...(props.src
      ? { '--sky-icon-source': `url(${JSON.stringify(props.src)})` }
      : {}),
  }
})

const badgeStyle = computed<CSSProperties | undefined>(() => {
  if (!props.badgeColors?.bg && !props.badgeColors?.text) return undefined
  return {
    background: props.badgeColors.bg,
    color: props.badgeColors.text,
  }
})

const hasBadge = computed(
  () =>
    (props.badge !== undefined && props.badge !== null) || Boolean(slots.badge),
)
</script>

<template>
  <component
    :is="icon && !hasBadge ? icon : component"
    v-bind="$attrs"
    class="sky-icon"
    :class="{ 'sky-icon--badged': hasBadge, 'sky-icon--image': !!src }"
    :size="icon ? (size ?? 20) : undefined"
    :style="iconStyle"
    :aria-hidden="label ? undefined : true"
    :aria-label="label || undefined"
    :role="label ? 'img' : undefined"
  >
    <component v-if="icon && hasBadge" :is="icon" aria-hidden="true" />
    <slot />
    <SkyBadge v-if="hasBadge" class="sky-icon__badge" small :style="badgeStyle">
      {{ badge }}<slot name="badge" />
    </SkyBadge>
  </component>
</template>

<style scoped>
.sky-icon {
  font-style: normal;
}
.sky-icon--badged {
  position: relative;
}
.sky-icon--image {
  display: inline-block;
  flex: none;
  width: var(--sky-icon-size, 20px);
  height: var(--sky-icon-size, 20px);
  background-color: currentColor;
  -webkit-mask: var(--sky-icon-source) center / contain no-repeat;
  mask: var(--sky-icon-source) center / contain no-repeat;
}
.sky-icon > svg.sky-icon {
  width: 100%;
  height: 100%;
}

.sky-icon__badge {
  position: absolute;
  inset-block-start: -2px;
  inset-inline-end: -6px;
}
</style>
