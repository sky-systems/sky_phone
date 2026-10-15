<script setup lang="ts">
import { computed } from 'vue'

defineOptions({ inheritAttrs: false })

const props = withDefaults(
  defineProps<{
    component?: 'a' | 'button'
    disabled?: boolean
    variant?: 'action' | 'content'
    href?: string
    iconOnly?: boolean
    linkProps?: Record<string, unknown>
    type?: 'button' | 'reset' | 'submit'
  }>(),
  {
    component: undefined,
    disabled: false,
    variant: 'action',
    href: undefined,
    iconOnly: false,
    linkProps: () => ({}),
    type: 'button',
  },
)

const emit = defineEmits<{
  click: [event: MouseEvent]
}>()

const element = computed(() => props.component ?? (props.href ? 'a' : 'button'))

const elementProps = computed<Record<string, unknown>>(() => {
  if (element.value === 'a') {
    return {
      ...props.linkProps,
      'aria-disabled': props.disabled || undefined,
      href: props.disabled ? undefined : props.href,
      tabindex: props.disabled ? -1 : 0,
    }
  }

  return {
    ...props.linkProps,
    disabled: props.disabled,
    type: props.linkProps.type ?? props.type,
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
  <component
    :is="element"
    v-bind="{ ...$attrs, ...elementProps }"
    class="sky-link"
    :class="{
      'sky-link--content': variant === 'content',
      'sky-link--icon-only': iconOnly,
    }"
    @click="handleClick"
  >
    <slot />
  </component>
</template>
