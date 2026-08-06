<script setup lang="ts">
import { Check, ChevronDown } from 'lucide-vue-next'
import { computed, onMounted, onUnmounted, ref } from 'vue'

type SelectOption = {
  label: string
  value: string
}

const props = defineProps<{
  modelValue: string
  options: SelectOption[]
}>()

const emit = defineEmits<{
  change: [value: string]
}>()

const root = ref<HTMLElement | null>(null)
const isOpen = ref(false)
const highlightedIndex = ref(0)
const selectedLabel = computed(
  () => props.options.find((option) => option.value === props.modelValue)?.label ?? '',
)

function open(): void {
  highlightedIndex.value = Math.max(
    0,
    props.options.findIndex((option) => option.value === props.modelValue),
  )
  isOpen.value = true
}

function select(value: string): void {
  emit('change', value)
  isOpen.value = false
}

function handleKeydown(event: KeyboardEvent): void {
  if (event.key === 'Escape') {
    isOpen.value = false
    return
  }
  if (event.key === 'Enter' || event.key === ' ') {
    event.preventDefault()
    if (!isOpen.value) open()
    else select(props.options[highlightedIndex.value]?.value ?? props.modelValue)
    return
  }
  if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp') return
  event.preventDefault()
  if (!isOpen.value) open()
  const direction = event.key === 'ArrowDown' ? 1 : -1
  highlightedIndex.value =
    (highlightedIndex.value + direction + props.options.length) % props.options.length
}

function handleOutsidePointer(event: PointerEvent): void {
  if (!root.value?.contains(event.target as Node)) isOpen.value = false
}

onMounted(() => window.addEventListener('pointerdown', handleOutsidePointer))
onUnmounted(() => window.removeEventListener('pointerdown', handleOutsidePointer))
</script>

<template>
  <div ref="root" class="citymarkt-select" @keydown="handleKeydown">
    <button
      class="citymarkt-select__trigger"
      type="button"
      aria-haspopup="listbox"
      :aria-expanded="isOpen"
      @click="isOpen ? (isOpen = false) : open()"
    >
      <span>{{ selectedLabel }}</span>
      <ChevronDown :size="14" :class="{ open: isOpen }" />
    </button>

    <Transition name="citymarkt-select">
      <div v-if="isOpen" class="citymarkt-select__menu" role="listbox">
        <button
          v-for="(option, index) in options"
          :key="option.value"
          type="button"
          role="option"
          :aria-selected="option.value === modelValue"
          :class="{
            highlighted: index === highlightedIndex,
            selected: option.value === modelValue,
          }"
          @pointerenter="highlightedIndex = index"
          @click="select(option.value)"
        >
          <span>{{ option.label }}</span>
          <Check v-if="option.value === modelValue" :size="13" />
        </button>
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.citymarkt-select{position:relative;min-width:0}.citymarkt-select__trigger{width:100%;height:36px;padding:0 10px;border:1px solid #ffffff0d;border-radius:10px;display:flex;align-items:center;justify-content:space-between;gap:6px;background:var(--panel);color:inherit;font-size:10px;text-align:left}.citymarkt-select__trigger span{overflow:hidden;white-space:nowrap;text-overflow:ellipsis}.citymarkt-select__trigger svg{flex:none;color:var(--yellow);transition:transform .18s ease}.citymarkt-select__trigger svg.open{transform:rotate(180deg)}.citymarkt-select__menu{position:absolute;z-index:12;top:calc(100% + 5px);right:0;left:0;max-height:176px;padding:4px;border:1px solid #ffffff16;border-radius:11px;overflow-y:auto;background:#292a27;box-shadow:0 12px 28px #0009;scrollbar-width:none}:global(.citymarkt--light) .citymarkt-select__menu{border-color:#00000014;background:#fff;box-shadow:0 12px 28px #0003}.citymarkt-select__menu button{width:100%;min-height:31px;padding:6px 7px;border:0;border-radius:8px;display:flex;align-items:center;justify-content:space-between;gap:5px;background:none;color:var(--muted);font-size:10px;text-align:left}.citymarkt-select__menu button.highlighted{background:#ffffff0b;color:inherit}:global(.citymarkt--light) .citymarkt-select__menu button.highlighted{background:#0000000b}.citymarkt-select__menu button.selected{color:var(--yellow);font-weight:800}.citymarkt-select-enter-active,.citymarkt-select-leave-active{transition:opacity .15s ease,transform .15s ease}.citymarkt-select-enter-from,.citymarkt-select-leave-to{opacity:0;transform:translateY(-4px) scale(.98)}
</style>
