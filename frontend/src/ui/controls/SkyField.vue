<script setup lang="ts">
import {
  computed,
  ref,
  useAttrs,
  useId,
  useSlots,
  type CSSProperties,
} from 'vue'

import { useComposedFieldValue } from '@/ui/controls/useComposedFieldValue'

defineOptions({ inheritAttrs: false })

type FieldValue = number | string
type FieldOption = {
  disabled?: boolean
  label: string
  value: FieldValue
}

const props = withDefaults(
  defineProps<{
    ariaLabel?: string
    accept?: number | string
    autocapitalize?:
      | 'characters'
      | 'none'
      | 'off'
      | 'on'
      | 'sentences'
      | 'words'
    autocomplete?: string
    autocorrect?: 'off' | 'on'
    autofocus?: boolean
    autosave?: string
    clearButton?: boolean
    clearLabel?: string
    component?: string
    disabled?: boolean
    error?: boolean | string
    dropdown?: boolean
    floatingLabel?: boolean
    help?: string
    id?: string
    info?: string
    inputClass?: string
    inputId?: string
    inputMode?:
      | 'decimal'
      | 'email'
      | 'none'
      | 'numeric'
      | 'search'
      | 'tel'
      | 'text'
      | 'url'
    inputmode?:
      | 'decimal'
      | 'email'
      | 'none'
      | 'numeric'
      | 'search'
      | 'tel'
      | 'text'
      | 'url'
    inputStyle?: CSSProperties | string
    label?: string
    layout?: 'inline' | 'stacked'
    max?: number | string
    maxlength?: number | string
    minlength?: number | string
    min?: number | string
    modelValue?: FieldValue
    name?: string
    outline?: boolean
    options?: readonly FieldOption[]
    pattern?: string
    placeholder?: string
    readonly?: boolean
    required?: boolean
    rows?: number
    size?: number | string
    spellcheck?: boolean | 'false' | 'true'
    step?: number | string
    tabindex?: number | string
    type?:
      | 'date'
      | 'datetime-local'
      | 'email'
      | 'number'
      | 'password'
      | 'search'
      | 'select'
      | 'tel'
      | 'text'
      | 'textarea'
      | 'time'
      | 'url'
    value?: FieldValue
    variant?: 'row' | 'control'
  }>(),
  {
    accept: undefined,
    ariaLabel: '',
    autocapitalize: undefined,
    autocomplete: undefined,
    autocorrect: undefined,
    autofocus: false,
    autosave: undefined,
    clearButton: false,
    clearLabel: '',
    component: 'li',
    disabled: false,
    error: false,
    dropdown: false,
    floatingLabel: false,
    help: '',
    id: undefined,
    info: '',
    inputClass: '',
    inputId: undefined,
    inputMode: undefined,
    inputmode: undefined,
    inputStyle: undefined,
    label: '',
    layout: 'stacked',
    max: undefined,
    maxlength: undefined,
    minlength: undefined,
    min: undefined,
    modelValue: undefined,
    name: undefined,
    outline: false,
    options: () => [],
    pattern: undefined,
    placeholder: '',
    readonly: false,
    required: false,
    rows: 3,
    size: undefined,
    spellcheck: undefined,
    step: undefined,
    tabindex: undefined,
    type: 'text',
    value: undefined,
    variant: 'row',
  },
)

const emit = defineEmits<{
  blur: [event: FocusEvent]
  change: [event: Event]
  clear: []
  focus: [event: FocusEvent]
  input: [event: Event]
  'update:modelValue': [value: string]
}>()

const generatedId = useId()
const attrs = useAttrs()
const slots = useSlots()
const isFocused = ref(false)
const hasMedia = computed(() => Boolean(slots.media || slots.leading))
const resolvedInputId = computed(() => props.inputId || props.id || generatedId)
const helpId = computed(() => `${resolvedInputId.value}-help`)
const errorId = computed(() => `${resolvedInputId.value}-error`)
const infoId = computed(() => `${resolvedInputId.value}-info`)
const nativeAttrs = computed(() =>
  Object.fromEntries(
    Object.entries(attrs).filter(
      ([name]) => name !== 'class' && name !== 'style',
    ),
  ),
)
const effectiveValue = computed(() => props.modelValue ?? props.value ?? '')
const {
  clear: clearValue,
  endComposition,
  input,
  localValue,
  startComposition,
} = useComposedFieldValue(effectiveValue, (value) =>
  emit('update:modelValue', value),
)
const hasClearButton = computed(
  () =>
    props.clearButton &&
    Boolean(props.clearLabel) &&
    localValue.value.length > 0,
)
const isFloatingRaised = computed(
  () =>
    Boolean(props.label || slots.label) &&
    props.floatingLabel &&
    (isFocused.value || localValue.value.length > 0),
)

const describedBy = computed(() => {
  const ids: string[] = []
  if (props.help || slots.help) ids.push(helpId.value)
  if ((props.info && !props.error) || slots.info) ids.push(infoId.value)
  if ((props.error && props.error !== true) || slots.error) {
    ids.push(errorId.value)
  }
  return ids.length ? ids.join(' ') : undefined
})

function fieldValue(event: Event): string {
  const target = event.target
  if (
    !(target instanceof HTMLInputElement) &&
    !(target instanceof HTMLSelectElement) &&
    !(target instanceof HTMLTextAreaElement)
  ) {
    return ''
  }
  return target.value
}

function handleInput(event: Event): void {
  const value = fieldValue(event)
  input(value)
  emit('input', event)
}

function handleCompositionEnd(event: CompositionEvent): void {
  endComposition(fieldValue(event))
}

function handleFocus(event: FocusEvent): void {
  isFocused.value = true
  emit('focus', event)
}

function handleBlur(event: FocusEvent): void {
  isFocused.value = false
  emit('blur', event)
}

function clear(): void {
  if (props.disabled || props.readonly) return
  clearValue()
  emit('clear')
}
</script>

<template>
  <component
    :is="component"
    class="sky-field"
    :class="[
      attrs.class,
      {
        'sky-field--disabled': disabled,
        'sky-field--error': Boolean(error),
        'sky-field--floating-label':
          Boolean(label || $slots.label) && floatingLabel,
        'sky-field--floating-raised': isFloatingRaised,
        'sky-field--has-label': Boolean(label || slots.label),
        'sky-field--inline': layout === 'inline',
        'sky-field--control': variant === 'control',
        'sky-field--outline': outline,
        'sky-field--has-leading': Boolean(slots.leading),
        'sky-field--has-media': hasMedia,
      },
    ]"
    :style="attrs.style"
  >
    <span v-if="hasMedia" class="sky-field__media">
      <slot v-if="$slots.media" name="media" />
      <slot v-else name="leading" />
    </span>
    <div class="sky-field__inner">
      <label
        v-if="label || $slots.label"
        class="sky-field__label"
        :for="resolvedInputId"
      >
        <span class="sky-field__label-text"
          >{{ label }}<slot name="label"
        /></span>
      </label>
      <div class="sky-field__control">
        <slot v-if="$slots.input" name="input" />
        <textarea
          v-else-if="type === 'textarea'"
          v-bind="nativeAttrs"
          :id="resolvedInputId"
          class="sky-field__input sky-field__textarea"
          :class="inputClass"
          :aria-describedby="describedBy"
          :aria-invalid="error ? true : undefined"
          :aria-label="ariaLabel || undefined"
          :autocapitalize="autocapitalize"
          :autocorrect="autocorrect"
          :autofocus="autofocus"
          :autosave="autosave"
          :disabled="disabled"
          :maxlength="maxlength"
          :minlength="minlength"
          :name="name"
          :placeholder="placeholder"
          :readonly="readonly"
          :required="required"
          :rows="rows"
          :spellcheck="spellcheck"
          :tabindex="tabindex"
          :style="inputStyle"
          :value="localValue"
          @blur="handleBlur"
          @change="emit('change', $event)"
          @compositionend="handleCompositionEnd"
          @compositionstart="startComposition"
          @focus="handleFocus"
          @input="handleInput"
        />
        <select
          v-else-if="type === 'select'"
          v-bind="nativeAttrs"
          :id="resolvedInputId"
          class="sky-field__input sky-field__select"
          :class="inputClass"
          :aria-describedby="describedBy"
          :aria-invalid="error ? true : undefined"
          :aria-label="ariaLabel || undefined"
          :disabled="disabled"
          :autofocus="autofocus"
          :name="name"
          :placeholder="placeholder"
          :required="required"
          :size="size === undefined ? undefined : String(size)"
          :style="inputStyle"
          :value="localValue"
          :tabindex="tabindex"
          @blur="handleBlur"
          @change="emit('change', $event)"
          @focus="handleFocus"
          @input="handleInput"
        >
          <option
            v-for="(option, index) in options"
            :key="`${typeof option.value}:${String(option.value)}:${index}`"
            :disabled="option.disabled"
            :value="option.value"
          >
            {{ option.label }}
          </option>
          <slot />
        </select>
        <input
          v-else
          v-bind="nativeAttrs"
          :id="resolvedInputId"
          class="sky-field__input"
          :class="inputClass"
          :aria-describedby="describedBy"
          :aria-invalid="error ? true : undefined"
          :aria-label="ariaLabel || undefined"
          :autocapitalize="autocapitalize"
          :accept="accept === undefined ? undefined : String(accept)"
          :autocomplete="autocomplete"
          :autocorrect="autocorrect"
          :autofocus="autofocus"
          :autosave="autosave"
          :disabled="disabled"
          :inputmode="inputMode ?? inputmode"
          :max="max"
          :maxlength="maxlength"
          :minlength="minlength"
          :min="min"
          :name="name"
          :pattern="pattern"
          :placeholder="placeholder"
          :readonly="readonly"
          :required="required"
          :size="size"
          :step="step"
          :tabindex="tabindex"
          :spellcheck="spellcheck"
          :style="inputStyle"
          :type="type"
          :value="localValue"
          @blur="handleBlur"
          @change="emit('change', $event)"
          @compositionend="handleCompositionEnd"
          @compositionstart="startComposition"
          @focus="handleFocus"
          @input="handleInput"
        />
        <span v-if="$slots.trailing" class="sky-field__trailing">
          <slot name="trailing" />
        </span>
        <svg
          v-if="dropdown"
          class="sky-field__dropdown"
          xmlns="http://www.w3.org/2000/svg"
          width="8"
          height="5"
          viewBox="0 0 8 5"
          fill="currentColor"
          aria-hidden="true"
          focusable="false"
        >
          <polygon fill-rule="evenodd" points="0 0 8 0 4 5" />
        </svg>
        <button
          v-if="hasClearButton"
          class="sky-field__clear"
          type="button"
          :aria-label="clearLabel"
          :disabled="disabled || readonly"
          @pointerdown.prevent
          @click="clear"
        >
          <span aria-hidden="true" />
        </button>
      </div>
      <small v-if="help || $slots.help" :id="helpId" class="sky-field__help">
        {{ help }}<slot name="help" />
      </small>
      <small
        v-if="(error && error !== true) || $slots.error"
        :id="errorId"
        class="sky-field__error"
        role="alert"
      >
        {{ error === true ? '' : error }}<slot name="error" />
      </small>
      <small
        v-if="(info && !error) || $slots.info"
        :id="infoId"
        class="sky-field__info"
      >
        {{ info }}<slot name="info" />
      </small>
    </div>
    <span v-if="outline" class="sky-field__border" aria-hidden="true" />
    <slot v-if="type !== 'select' && !$slots.input" />
  </component>
</template>
