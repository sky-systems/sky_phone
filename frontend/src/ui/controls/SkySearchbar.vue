<script setup lang="ts">
import { computed, ref, useId, watch, type StyleValue } from 'vue'

import SkyGlass from './SkyGlass.vue'

defineOptions({ inheritAttrs: false })

const props = withDefaults(
  defineProps<{
    clearLabel?: string
    cancelLabel?: string
    cancelButton?: boolean
    clearButton?: boolean
    component?: 'div' | 'form'
    disableButton?: boolean
    disableLabel?: string
    disabled?: boolean
    id?: string
    inputId?: string
    inputStyle?: StyleValue
    label?: string
    modelValue?: string
    name?: string
    placeholder?: string
    value?: string
  }>(),
  {
    disabled: false,
    cancelButton: false,
    cancelLabel: '',
    clearButton: true,
    clearLabel: '',
    component: 'div',
    disableButton: false,
    disableLabel: '',
    id: undefined,
    inputId: undefined,
    inputStyle: undefined,
    label: '',
    modelValue: undefined,
    name: undefined,
    placeholder: '',
    value: undefined,
  },
)

const emit = defineEmits<{
  blur: [event: FocusEvent]
  'blur-capture': [event: FocusEvent]
  cancel: []
  change: [event: Event]
  clear: [event?: MouseEvent]
  disable: [event: MouseEvent]
  focus: [event: FocusEvent]
  'focus-capture': [event: FocusEvent]
  input: [event: Event]
  'update:modelValue': [value: string]
}>()

const generatedId = useId()
const resolvedInputId = computed(() => props.inputId || props.id || generatedId)
const input = ref<HTMLInputElement | null>(null)
const effectiveValue = computed(() => props.modelValue ?? props.value ?? '')
const localValue = ref(effectiveValue.value)
const composing = ref(false)
const focused = ref(false)
const showCancel = computed(
  () => props.cancelButton && Boolean(props.cancelLabel),
)
const disableAccessibleLabel = computed(
  () => props.disableLabel || props.cancelLabel || props.label,
)
const showDisable = computed(
  () => props.disableButton && Boolean(disableAccessibleLabel.value),
)

watch(effectiveValue, (value) => {
  if (!composing.value) localValue.value = value
})

function handleInput(event: Event): void {
  if (!(event.target instanceof HTMLInputElement)) return
  localValue.value = event.target.value
  emit('update:modelValue', event.target.value)
  emit('input', event)
}

function handleCompositionEnd(event: CompositionEvent): void {
  composing.value = false
  if (!(event.target instanceof HTMLInputElement)) return
  localValue.value = event.target.value
  emit('update:modelValue', event.target.value)
}

function clear(event?: MouseEvent): void {
  if (props.disabled) return
  localValue.value = ''
  emit('update:modelValue', '')
  emit('clear', event)
}

function handleFocus(event: FocusEvent): void {
  focused.value = true
  emit('focus', event)
}

function handleBlur(event: FocusEvent): void {
  focused.value = false
  emit('blur', event)
}

function cancel(): void {
  if (props.disabled) return
  clear()
  emit('cancel')
}

function disable(event: MouseEvent): void {
  if (props.disabled) return
  input.value?.blur()
  clear(event)
  emit('disable', event)
}
</script>

<template>
  <component
    :is="component"
    v-bind="$attrs"
    class="sky-searchbar"
    :class="{
      'sky-searchbar--disabled': disabled,
      'sky-searchbar--focused': focused,
      'sky-searchbar--with-cancel': showCancel,
      'sky-searchbar--with-disable': showDisable,
    }"
    @blur.capture="emit('blur-capture', $event)"
    @focus.capture="emit('focus-capture', $event)"
  >
    <SkyGlass :highlight="false" class="sky-searchbar__control">
      <label v-if="label" class="sky-visually-hidden" :for="resolvedInputId">
        {{ label }}
      </label>
      <svg class="sky-searchbar__icon" aria-hidden="true" viewBox="0 0 24 24">
        <path
          fill-rule="evenodd"
          clip-rule="evenodd"
          d="M9.5 3a6.5 6.5 0 1 0 3.98 11.64l4.44 4.44a1 1 0 0 0 1.42-1.42l-4.44-4.44A6.5 6.5 0 0 0 9.5 3Zm0 2a4.5 4.5 0 1 1 0 9 4.5 4.5 0 0 1 0-9Z"
        />
      </svg>
      <input
        :id="resolvedInputId"
        ref="input"
        class="sky-searchbar__input"
        :style="inputStyle"
        type="search"
        :aria-label="label || placeholder || undefined"
        autocomplete="off"
        :disabled="disabled"
        :name="name"
        :placeholder="placeholder"
        :value="localValue"
        @blur="handleBlur"
        @change="emit('change', $event)"
        @compositionend="handleCompositionEnd"
        @compositionstart="composing = true"
        @focus="handleFocus"
        @input="handleInput"
      />
      <span v-if="$slots.suffix" class="sky-searchbar__suffix">
        <slot name="suffix" />
      </span>
      <button
        v-if="clearButton && localValue"
        class="sky-searchbar__clear"
        type="button"
        :aria-label="clearLabel || 'Clear search'"
        :disabled="disabled"
        @pointerdown.prevent
        @click="clear($event)"
      >
        <span aria-hidden="true" />
      </button>
    </SkyGlass>
    <button
      v-if="showCancel"
      class="sky-searchbar__cancel"
      type="button"
      :disabled="disabled"
      @pointerdown.prevent
      @click="cancel"
    >
      {{ cancelLabel }}
    </button>
    <button
      v-if="showDisable"
      class="sky-searchbar__disable sky-searchbar__cancel"
      type="button"
      :aria-label="disableAccessibleLabel"
      :disabled="disabled"
      @pointerdown.prevent
      @click="disable"
    >
      <span class="sky-searchbar__disable-icon" aria-hidden="true" />
    </button>
  </component>
</template>
