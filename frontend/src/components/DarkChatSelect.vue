<script setup lang="ts">
import { Check, ChevronDown } from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

export type DarkChatSelectOption = {
  label: string
  value: number | string
}

const props = defineProps<{
  label: string
  modelValue: number | string
  options: DarkChatSelectOption[]
}>()

const emit = defineEmits<{
  'update:modelValue': [value: number | string]
}>()

const root = ref<HTMLElement | null>(null)
const opened = ref(false)
const selectedOption = computed(
  () =>
    props.options.find((option) => option.value === props.modelValue) ??
    props.options[0],
)

function selectOption(option: DarkChatSelectOption): void {
  emit('update:modelValue', option.value)
  opened.value = false
}

function closeFromOutside(event: PointerEvent): void {
  if (!root.value?.contains(event.target as Node)) opened.value = false
}

function closeFromEscape(event: KeyboardEvent): void {
  if (event.key === 'Escape') opened.value = false
}

onMounted(() => {
  document.addEventListener('pointerdown', closeFromOutside)
  document.addEventListener('keydown', closeFromEscape)
})

onBeforeUnmount(() => {
  document.removeEventListener('pointerdown', closeFromOutside)
  document.removeEventListener('keydown', closeFromEscape)
})
</script>

<template>
  <div ref="root" class="darkchat-choice">
    <button
      type="button"
      class="darkchat-choice__trigger"
      role="combobox"
      :aria-label="label"
      :aria-expanded="opened"
      aria-haspopup="listbox"
      @click="opened = !opened"
    >
      <span>{{ selectedOption?.label }}</span>
      <ChevronDown :size="14" :class="{ open: opened }" />
    </button>

    <Transition name="darkchat-choice">
      <div v-if="opened" class="darkchat-choice__menu" role="listbox">
        <button
          v-for="option in options"
          :key="option.value"
          type="button"
          role="option"
          :aria-selected="option.value === modelValue"
          :class="{ selected: option.value === modelValue }"
          @click="selectOption(option)"
        >
          <span>{{ option.label }}</span>
          <Check v-if="option.value === modelValue" :size="14" />
        </button>
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.darkchat-choice { position: relative; min-width: 0; }
.darkchat-choice__trigger {
  width: 145px;
  height: 35px;
  padding: 0 10px 0 11px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 5px;
  overflow: hidden;
  border: 1px solid rgb(139 92 246 / 28%);
  border-radius: 10px;
  background: linear-gradient(145deg, rgb(44 44 46 / 96%), rgb(28 28 30 / 96%));
  box-shadow: inset 0 1px 0 rgb(255 255 255 / 7%);
  color: #c4b5fd;
  font-size: 11px;
  text-align: left;
}
.darkchat-choice__trigger span,
.darkchat-choice__menu span { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.darkchat-choice__trigger svg { flex: none; transition: transform .18s ease; }
.darkchat-choice__trigger svg.open { transform: rotate(180deg); }
.darkchat-choice__menu {
  position: absolute;
  z-index: 80;
  top: calc(100% + 5px);
  right: 0;
  width: 195px;
  padding: 5px;
  overflow: hidden;
  border: 1px solid rgb(139 92 246 / 28%);
  border-radius: 13px;
  background: rgb(28 28 30 / 98%);
  box-shadow: 0 14px 38px rgb(0 0 0 / 65%);
  backdrop-filter: blur(24px);
}
.darkchat-choice__menu button {
  width: 100%;
  min-height: 40px;
  padding: 7px 9px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 7px;
  border: 0;
  border-radius: 9px;
  background: transparent;
  color: #f5f5f7;
  font-size: 11px;
  text-align: left;
}
.darkchat-choice__menu button.selected { background: rgb(139 92 246 / 18%); color: #c4b5fd; }
.darkchat-choice__menu button svg { flex: none; color: #a78bfa; }
.darkchat-choice-enter-active,
.darkchat-choice-leave-active { transition: opacity .16s ease, transform .16s ease; transform-origin: top right; }
.darkchat-choice-enter-from,
.darkchat-choice-leave-to { opacity: 0; transform: translateY(-4px) scale(.97); }
</style>
