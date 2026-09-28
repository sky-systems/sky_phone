<script setup lang="ts">
import { onBeforeUnmount, ref, watch } from 'vue'

import SkyButton from './SkyButton.vue'
import SkyField from './SkyField.vue'

const props = defineProps<{
  label: string
  disabled?: boolean
  modelValue: string
  options: { label: string; value: string }[]
  resolveKey: (event: KeyboardEvent) => string | null
  labels: {
    capture: string
    listening: string
    cancel: string
    unsupported: string
  }
}>()
const emit = defineEmits<{ 'update:modelValue': [value: string] }>()
const root = ref<HTMLElement | null>(null)
const listening = ref(false)
const invalid = ref(false)
let modifier = ''

function stop(): void {
  listening.value = false
  modifier = ''
  invalid.value = false
}

function accept(event: KeyboardEvent): void {
  const key = props.resolveKey(event)
  if (!key || !props.options.some((option) => option.value === key)) {
    invalid.value = true
    return
  }
  emit('update:modelValue', key)
  invalid.value = false
  stop()
}

function keydown(event: KeyboardEvent): void {
  if (event.key === 'Tab') {
    stop()
    return
  }
  event.preventDefault()
  event.stopImmediatePropagation()
  if (event.key === 'Escape') {
    stop()
    return
  }
  if (event.repeat) return
  if (['Shift', 'Control', 'Alt', 'Meta', 'AltGraph'].includes(event.key)) {
    if (
      modifier ||
      [event.ctrlKey, event.altKey, event.metaKey, event.shiftKey].filter(Boolean)
        .length > 1
    ) {
      modifier = ''
      invalid.value = true
      return
    }
    modifier = event.code
    return
  }
  if (event.ctrlKey || event.altKey || event.metaKey || event.shiftKey) {
    modifier = ''
    invalid.value = true
    return
  }
  accept(event)
}

function keyup(event: KeyboardEvent): void {
  if (event.code !== modifier) return
  event.preventDefault()
  event.stopImmediatePropagation()
  modifier = ''
  if (event.ctrlKey || event.altKey || event.metaKey || event.shiftKey) {
    invalid.value = true
    return
  }
  accept(event)
}

function detach(): void {
  window.removeEventListener('keydown', keydown, true)
  window.removeEventListener('keyup', keyup, true)
  window.removeEventListener('blur', stop)
}

watch(
  listening,
  (active) => {
    detach()
    if (active) {
      invalid.value = false
      window.addEventListener('keydown', keydown, true)
      window.addEventListener('keyup', keyup, true)
      window.addEventListener('blur', stop)
    }
  },
  { flush: 'sync' },
)
watch(
  () => props.disabled,
  (disabled) => {
    if (disabled) stop()
  },
)
onBeforeUnmount(detach)

function focusout(event: FocusEvent): void {
  if (
    !(event.relatedTarget instanceof Node) ||
    !root.value?.contains(event.relatedTarget)
  )
    stop()
}
</script>

<template>
  <div ref="root" class="sky-key-capture" @focusout="focusout">
    <div class="sky-key-capture__controls">
      <SkyField
        component="div"
        variant="control"
        dropdown
        type="select"
        :aria-label="label"
        :model-value="modelValue"
        :options="options"
        :disabled="disabled || listening"
        @update:model-value="emit('update:modelValue', String($event))"
      />
      <SkyButton
        inline
        large
        variant="secondary"
        :disabled="disabled"
        :aria-pressed="listening"
        @click="listening ? stop() : (listening = true)"
        >{{ listening ? labels.cancel : labels.capture }}</SkyButton
      >
    </div>
    <p v-if="listening || invalid" class="sky-key-capture__hint" role="status">
      {{ invalid ? labels.unsupported : labels.listening }}
    </p>
  </div>
</template>

<style scoped>
.sky-key-capture {
  min-width: 0;
}
.sky-key-capture__controls {
  display: flex;
  align-items: center;
  gap: var(--sky-space-2);
  flex-wrap: wrap;
}
.sky-key-capture__controls > .sky-field {
  flex: 1;
  min-width: 120px;
}
.sky-key-capture__hint {
  margin: var(--sky-space-2) 0 0;
  color: var(--sky-muted);
  font-size: var(--sky-font-caption);
}
</style>
