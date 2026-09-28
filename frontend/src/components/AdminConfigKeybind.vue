<script setup lang="ts">
import { computed, ref, watch } from 'vue'

import { usePhoneStore } from '@/stores/phone'
import { SkyKeyCapture, SkyToggle } from '@/ui'
import {
  KEYBOARD_MAPPING_KEYS,
  keyboardMappingFromEvent,
} from '@/utils/keyboardMapping'

const props = defineProps<{
  label: string
  disabled?: boolean
  modelValue: unknown
  optional?: boolean
}>()
const emit = defineEmits<{ 'update:modelValue': [value: string | false] }>()
const phone = usePhoneStore()
const lastEnabledKey = ref('F1')
watch(
  () => props.modelValue,
  (value) => {
    if (typeof value === 'string' && value) lastEnabledKey.value = value
  },
  { immediate: true },
)
const t = (key: string) => phone.t(`AdminPanel.configurator.keybind.${key}`)
const options = computed(() => {
  const keys = [...KEYBOARD_MAPPING_KEYS]
  const current = String(props.modelValue || '')
  // Preserve existing file/SQL values until the administrator explicitly changes them.
  if (current && !keys.includes(current)) keys.unshift(current)
  return keys.map((value) => ({ value, label: value }))
})
</script>

<template>
  <div class="admin-config-keybind">
    <SkyKeyCapture
      :label="label"
      :model-value="modelValue === false ? '' : String(modelValue ?? '')"
      :disabled="disabled || modelValue === false"
      :options="options"
      :resolve-key="keyboardMappingFromEvent"
      :labels="{
        capture: t('capture'),
        listening: t('listening'),
        cancel: t('cancel'),
        unsupported: t('unsupported'),
      }"
      @update:model-value="emit('update:modelValue', $event)"
    />
    <SkyToggle
      v-if="optional"
      :aria-label="`${label}: ${t('enabled')}`"
      :model-value="modelValue !== false"
      :disabled="disabled"
      @update:model-value="
        emit('update:modelValue', $event ? lastEnabledKey : false)
      "
      >{{ t('enabled') }}</SkyToggle
    >
    <p>{{ t('help') }}</p>
  </div>
</template>

<style scoped>
.admin-config-keybind {
  min-width: 0;
  display: grid;
  gap: var(--sky-space-2);
}
.admin-config-keybind > p {
  margin: 0;
  color: var(--sky-muted);
  font-size: var(--sky-font-caption);
  line-height: 1.5;
}
</style>
