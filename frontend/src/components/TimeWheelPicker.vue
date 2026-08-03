<script setup lang="ts">
import { nextTick, onMounted, ref } from 'vue'

const props = defineProps<{
  hoursLabel: string
  label: string
  minutesLabel: string
  modelValue: string
}>()
const emit = defineEmits<{ 'update:modelValue': [value: string] }>()

const ITEM_HEIGHT = 40
const hours = Array.from({ length: 24 }, (_, index) => index)
const minutes = Array.from({ length: 60 }, (_, index) => index)
const initialTime = props.modelValue.split(':').map(Number)
const selectedHour = ref(initialTime[0] ?? 0)
const selectedMinute = ref(initialTime[1] ?? 0)
const hourWheel = ref<HTMLElement | null>(null)
const minuteWheel = ref<HTMLElement | null>(null)
let updateFrame: number | undefined

function format(value: number): string {
  return String(value).padStart(2, '0')
}

function emitTime(): void {
  emit(
    'update:modelValue',
    `${format(selectedHour.value)}:${format(selectedMinute.value)}`,
  )
}

function updateFromScroll(type: 'hour' | 'minute', element: HTMLElement): void {
  if (updateFrame) cancelAnimationFrame(updateFrame)
  updateFrame = requestAnimationFrame(() => {
    const maximum = type === 'hour' ? hours.length - 1 : minutes.length - 1
    const value = Math.max(
      0,
      Math.min(maximum, Math.round(element.scrollTop / ITEM_HEIGHT)),
    )
    if (type === 'hour') selectedHour.value = value
    else selectedMinute.value = value
    emitTime()
  })
}

function select(
  type: 'hour' | 'minute',
  value: number,
  element: HTMLElement | null,
): void {
  if (type === 'hour') selectedHour.value = value
  else selectedMinute.value = value
  element?.scrollTo({ behavior: 'smooth', top: value * ITEM_HEIGHT })
  emitTime()
}

onMounted(() => {
  void nextTick(() => {
    hourWheel.value?.scrollTo({ top: selectedHour.value * ITEM_HEIGHT })
    minuteWheel.value?.scrollTo({ top: selectedMinute.value * ITEM_HEIGHT })
  })
})
</script>

<template>
  <section class="time-wheel-picker" :aria-label="label">
    <div class="time-wheel-picker__selection" aria-hidden="true" />
    <span class="time-wheel-picker__separator" aria-hidden="true">:</span>

    <div
      ref="hourWheel"
      class="time-wheel-picker__column"
      role="listbox"
      :aria-label="hoursLabel"
      @scroll.passive="updateFromScroll('hour', $event.currentTarget as HTMLElement)"
    >
      <button
        v-for="hour in hours"
        :key="hour"
        type="button"
        role="option"
        :aria-selected="selectedHour === hour"
        :class="{ 'time-wheel-picker__value--selected': selectedHour === hour }"
        class="time-wheel-picker__value"
        @click="select('hour', hour, hourWheel)"
      >
        {{ format(hour) }}
      </button>
    </div>

    <div
      ref="minuteWheel"
      class="time-wheel-picker__column"
      role="listbox"
      :aria-label="minutesLabel"
      @scroll.passive="
        updateFromScroll('minute', $event.currentTarget as HTMLElement)
      "
    >
      <button
        v-for="minute in minutes"
        :key="minute"
        type="button"
        role="option"
        :aria-selected="selectedMinute === minute"
        :class="{
          'time-wheel-picker__value--selected': selectedMinute === minute,
        }"
        class="time-wheel-picker__value"
        @click="select('minute', minute, minuteWheel)"
      >
        {{ format(minute) }}
      </button>
    </div>
  </section>
</template>
