<script setup lang="ts">
import { computed, useSlots } from 'vue'

import SkyGlass from './SkyGlass.vue'

defineOptions({ inheritAttrs: false })

const props = withDefaults(
  defineProps<{
    ariaLabel?: string
    component?: 'a' | 'button'
    disabled?: boolean
    href?: string
    text?: string
    textPosition?: 'after' | 'before'
    type?: 'button' | 'reset' | 'submit'
    variant?: 'glass' | 'neutral' | 'primary'
  }>(),
  {
    ariaLabel: '',
    component: 'button',
    disabled: false,
    href: undefined,
    text: '',
    textPosition: 'after',
    type: 'button',
    variant: 'primary',
  },
)

const emit = defineEmits<{
  click: [event: MouseEvent]
}>()

const slots = useSlots()
const hasText = computed(() => Boolean(props.text || slots.text))
const elementProps = computed<Record<string, unknown>>(() => {
  if (props.component === 'a') {
    return {
      'aria-disabled': props.disabled || undefined,
      'aria-label': props.ariaLabel || undefined,
      href: props.disabled ? undefined : props.href,
      tabindex: props.disabled ? -1 : undefined,
    }
  }

  return {
    'aria-label': props.ariaLabel || undefined,
    disabled: props.disabled,
    type: props.type,
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
</script>

<template>
  <SkyGlass
    v-bind="{ ...$attrs, ...elementProps }"
    :component="component"
    :disabled="disabled"
    :href="href"
    :type="type"
    class="sky-fab"
    :class="{
      'sky-fab--disabled': disabled,
      'sky-fab--glass': variant === 'glass',
      'sky-fab--icon-only': !hasText,
      'sky-fab--neutral': variant === 'neutral',
      'sky-fab--with-text': hasText,
    }"
    role="button"
    @click="handleClick"
  >
    <span class="sky-fab__accent-layer" aria-hidden="true"></span>
    <span class="sky-fab__dark-accent-layer" aria-hidden="true"></span>
    <span class="sky-fab__surface-layer" aria-hidden="true"></span>
    <span v-if="hasText && textPosition === 'before'" class="sky-fab__text">
      {{ text }}<slot name="text" />
    </span>
    <span v-if="$slots.icon" class="sky-fab__icon">
      <slot name="icon" />
    </span>
    <span v-if="hasText && textPosition === 'after'" class="sky-fab__text">
      {{ text }}<slot name="text" />
    </span>
    <slot />
  </SkyGlass>
</template>
