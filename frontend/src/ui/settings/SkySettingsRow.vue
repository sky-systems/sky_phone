<script setup lang="ts">
import SkyIcon from '../controls/SkyIcon.vue'

import { Check, ChevronRight } from 'lucide-vue-next'
import { computed, useId, useSlots } from 'vue'

import SkySpinner from '@/ui/controls/SkySpinner.vue'
import SkyToggle from '@/ui/controls/SkyToggle.vue'

defineOptions({ inheritAttrs: false })

type SettingsRowKind =
  | 'action'
  | 'choice'
  | 'custom'
  | 'navigation'
  | 'toggle'
  | 'value'

const props = withDefaults(
  defineProps<{
    ariaLabel?: string
    description?: string
    disabled?: boolean
    kind?: SettingsRowKind
    modelValue?: boolean
    name?: string
    pending?: boolean
    selected?: boolean
    title: string
    tone?: 'accent' | 'danger' | 'default'
    value?: number | string
  }>(),
  {
    ariaLabel: '',
    description: '',
    disabled: false,
    kind: 'value',
    modelValue: false,
    name: undefined,
    pending: false,
    selected: false,
    tone: 'default',
    value: undefined,
  },
)

const emit = defineEmits<{
  activate: [event: MouseEvent]
  'update:modelValue': [value: boolean]
}>()

const slots = useSlots()
const generatedId = useId()
const titleId = `${generatedId}-title`
const descriptionId = `${generatedId}-description`
const toggleId = `${generatedId}-toggle`
const valueId = `${generatedId}-value`
const trailingId = `${generatedId}-trailing`
const isInteractive = computed(() =>
  ['action', 'choice', 'navigation'].includes(props.kind),
)
const rowComponent = computed(() => (isInteractive.value ? 'button' : 'div'))
const hasDescription = computed(() =>
  Boolean(props.description || slots.description),
)
const hasValue = computed(
  () => props.value !== undefined && String(props.value).length > 0,
)
const hasFreeTrailing = computed(
  () =>
    Boolean(slots.trailing) &&
    ['custom', 'navigation', 'value'].includes(props.kind),
)
const labelledBy = computed(() => {
  if (props.ariaLabel) return undefined
  const ids = [titleId]
  if (hasValue.value) ids.push(valueId)
  if (hasFreeTrailing.value) ids.push(trailingId)
  return ids.join(' ')
})

function handleActivate(event: MouseEvent): void {
  if (props.disabled || props.pending || !isInteractive.value) return
  emit('activate', event)
}

function updateToggle(value: boolean): void {
  if (props.disabled || props.pending) return
  emit('update:modelValue', value)
}
</script>

<template>
  <li
    v-bind="$attrs"
    class="sky-settings-row"
    :class="[
      `sky-settings-row--${kind}`,
      `sky-settings-row--${tone}`,
      {
        'sky-settings-row--disabled': disabled,
        'sky-settings-row--has-media': Boolean($slots.leading),
        'sky-settings-row--pending': pending,
        'sky-settings-row--selected': selected,
      },
    ]"
  >
    <div
      v-if="kind === 'toggle'"
      class="sky-settings-row__frame"
      :aria-busy="pending || undefined"
    >
      <span v-if="$slots.leading" class="sky-settings-row__leading">
        <slot name="leading" />
      </span>

      <span class="sky-settings-row__content">
        <label :id="titleId" class="sky-settings-row__title" :for="toggleId">
          <slot name="title">{{ title }}</slot>
        </label>
        <span
          v-if="hasDescription"
          :id="descriptionId"
          class="sky-settings-row__description"
        >
          <slot name="description">{{ description }}</slot>
        </span>
      </span>

      <span class="sky-settings-row__accessory">
        <SkySpinner v-if="pending" :size="18" />
        <SkyToggle
          :id="toggleId"
          :model-value="modelValue"
          :name="name"
          :disabled="disabled || pending"
          :aria-labelledby="titleId"
          :aria-describedby="hasDescription ? descriptionId : undefined"
          @update:model-value="updateToggle"
        />
      </span>
    </div>

    <component
      :is="rowComponent"
      v-else
      class="sky-settings-row__frame"
      :type="isInteractive ? 'button' : undefined"
      :disabled="isInteractive ? disabled || pending : undefined"
      :aria-label="ariaLabel || undefined"
      :aria-labelledby="labelledBy"
      :aria-describedby="hasDescription ? descriptionId : undefined"
      :aria-pressed="kind === 'choice' ? selected : undefined"
      :aria-busy="pending || undefined"
      @click="handleActivate"
    >
      <span v-if="$slots.leading" class="sky-settings-row__leading">
        <slot name="leading" />
      </span>

      <span class="sky-settings-row__content">
        <span :id="titleId" class="sky-settings-row__title">
          <slot name="title">{{ title }}</slot>
        </span>
        <span
          v-if="hasDescription"
          :id="descriptionId"
          class="sky-settings-row__description"
        >
          <slot name="description">{{ description }}</slot>
        </span>
      </span>

      <span
        v-if="
          pending ||
          hasValue ||
          hasFreeTrailing ||
          kind === 'choice' ||
          kind === 'navigation'
        "
        class="sky-settings-row__accessory"
      >
        <SkySpinner v-if="pending" :size="18" />
        <template v-else>
          <span v-if="hasValue" :id="valueId" class="sky-settings-row__value">
            <slot name="value">{{ value }}</slot>
          </span>
          <span
            v-if="hasFreeTrailing"
            :id="trailingId"
            class="sky-settings-row__trailing"
          >
            <slot name="trailing" />
          </span>
          <SkyIcon
            :icon="Check"
            v-if="kind === 'choice' && selected"
            class="sky-settings-row__check"
            :size="20"
            :stroke-width="2.25"
            aria-hidden="true"
          />
          <SkyIcon
            :icon="ChevronRight"
            v-if="kind === 'navigation'"
            class="sky-settings-row__chevron"
            :size="18"
            :stroke-width="2"
            aria-hidden="true"
          />
        </template>
      </span>
    </component>
  </li>
</template>
