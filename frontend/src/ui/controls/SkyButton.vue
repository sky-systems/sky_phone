<script setup lang="ts">
import { computed } from 'vue'

import SkyGlass from './SkyGlass.vue'

defineOptions({ inheritAttrs: false })

const props = withDefaults(
  defineProps<{
    block?: boolean
    clear?: boolean
    component?: 'a' | 'button'
    disabled?: boolean
    glass?: boolean
    href?: string
    iconOnly?: boolean
    inline?: boolean
    large?: boolean
    outline?: boolean
    raised?: boolean
    rounded?: boolean
    small?: boolean
    tonal?: boolean
    type?: 'button' | 'reset' | 'submit'
    variant?: 'danger' | 'plain' | 'primary' | 'secondary'
  }>(),
  {
    block: false,
    clear: false,
    component: 'button',
    disabled: false,
    glass: false,
    href: undefined,
    iconOnly: false,
    inline: false,
    large: false,
    outline: false,
    raised: false,
    rounded: false,
    small: false,
    tonal: false,
    type: 'button',
    variant: 'primary',
  },
)

const emit = defineEmits<{
  click: [event: MouseEvent]
}>()

const buttonClasses = computed(() => [
  `sky-button--${props.variant}`,
  {
    'sky-button--block': props.block,
    'sky-button--clear': props.clear,
    'sky-button--glass': props.glass,
    'sky-button--icon-only': props.iconOnly,
    'sky-button--inline': props.inline,
    'sky-button--large': props.large,
    'sky-button--outline': props.outline,
    'sky-button--raised': props.raised,
    'sky-button--rounded': props.rounded,
    'sky-button--small': props.small && !props.large,
    'sky-button--tonal': props.tonal,
  },
])

const elementProps = computed<Record<string, unknown>>(() => {
  if (props.component === 'a') {
    return {
      'aria-disabled': props.disabled || undefined,
      href: props.disabled ? undefined : props.href,
      tabindex: props.disabled ? -1 : undefined,
    }
  }

  return {
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
    v-if="glass"
    :component="component"
    v-bind="{ ...$attrs, ...elementProps }"
    class="sky-button"
    :class="buttonClasses"
    :disabled="disabled"
    :href="href"
    :type="type"
    @click="handleClick"
  >
    <slot />
  </SkyGlass>
  <component
    v-else
    :is="component"
    v-bind="{ ...$attrs, ...elementProps }"
    class="sky-button"
    :class="buttonClasses"
    @click="handleClick"
  >
    <slot />
  </component>
</template>
