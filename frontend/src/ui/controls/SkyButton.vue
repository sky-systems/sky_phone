<script setup lang="ts">
import { computed } from 'vue'

import SkyGlass from './SkyGlass.vue'
import SkySpinner from './SkySpinner.vue'

defineOptions({ inheritAttrs: false })

const props = withDefaults(
  defineProps<{
    block?: boolean
    clear?: boolean
    component?: 'a' | 'button'
    disabled?: boolean
    glass?: boolean
    glassMaterial?: 'clear' | 'regular'
    href?: string
    iconOnly?: boolean
    inline?: boolean
    large?: boolean
    loading?: boolean
    outline?: boolean
    raised?: boolean
    rounded?: boolean
    small?: boolean
    tonal?: boolean
    type?: 'button' | 'reset' | 'submit'
    variant?: 'content' | 'danger' | 'plain' | 'primary' | 'secondary'
  }>(),
  {
    block: false,
    clear: false,
    component: 'button',
    disabled: false,
    glass: false,
    glassMaterial: 'clear',
    href: undefined,
    iconOnly: false,
    inline: false,
    large: false,
    loading: false,
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

const unavailable = computed(() => props.disabled || props.loading)

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
      'aria-busy': props.loading || undefined,
      'aria-disabled': unavailable.value || undefined,
      href: unavailable.value ? undefined : props.href,
      tabindex: unavailable.value ? -1 : undefined,
    }
  }

  return {
    'aria-busy': props.loading || undefined,
    disabled: unavailable.value,
    type: props.type,
  }
})

function handleClick(event: MouseEvent): void {
  if (unavailable.value) {
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
    :material="glassMaterial"
    v-bind="{ ...$attrs, ...elementProps }"
    class="sky-button"
    :class="buttonClasses"
    :disabled="unavailable"
    :href="href"
    :type="type"
    @click="handleClick"
  >
    <SkySpinner v-if="loading" class="sky-button__spinner" :size="20" />
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
    <SkySpinner v-if="loading" class="sky-button__spinner" :size="20" />
    <slot />
  </component>
</template>
