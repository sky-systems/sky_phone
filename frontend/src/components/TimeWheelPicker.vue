<script setup lang="ts">
import { nextTick, onMounted, ref, watch } from 'vue'

const props = defineProps<{
  hoursLabel: string
  hoursUnitLabel?: string
  label: string
  minutesLabel: string
  minutesUnitLabel?: string
  modelValue: string
  secondsLabel?: string
  secondsUnitLabel?: string
  showUnitLabels?: boolean
}>()
const emit = defineEmits<{ 'update:modelValue': [value: string] }>()

type WheelType = 'hour' | 'minute' | 'second'
type DragState = {
  element: HTMLElement
  moved: boolean
  pointerId: number
  startScrollTop: number
  startY: number
}

const ITEM_HEIGHT = 40
const LOOP_CYCLES = 5
const CENTER_CYCLE = Math.floor(LOOP_CYCLES / 2)
const hours = Array.from({ length: 24 }, (_, index) => index)
const minutes = Array.from({ length: 60 }, (_, index) => index)
const seconds = Array.from({ length: 60 }, (_, index) => index)
const loopedHours = Array.from(
  { length: hours.length * LOOP_CYCLES },
  (_, index) => ({ index, value: index % hours.length }),
)
const loopedMinutes = Array.from(
  { length: minutes.length * LOOP_CYCLES },
  (_, index) => ({ index, value: index % minutes.length }),
)
const loopedSeconds = Array.from(
  { length: seconds.length * LOOP_CYCLES },
  (_, index) => ({ index, value: index % seconds.length }),
)
const initialTime = props.modelValue.split(':').map(Number)
const selectedHour = ref(normalize(initialTime[0] ?? 0, hours.length))
const selectedMinute = ref(normalize(initialTime[1] ?? 0, minutes.length))
const selectedSecond = ref(normalize(initialTime[2] ?? 0, seconds.length))
const selectedHourIndex = ref(CENTER_CYCLE * hours.length + selectedHour.value)
const selectedMinuteIndex = ref(
  CENTER_CYCLE * minutes.length + selectedMinute.value,
)
const selectedSecondIndex = ref(
  CENTER_CYCLE * seconds.length + selectedSecond.value,
)
const hourWheel = ref<HTMLElement | null>(null)
const minuteWheel = ref<HTMLElement | null>(null)
const secondWheel = ref<HTMLElement | null>(null)
let dragState: DragState | null = null
let suppressClick = false
let updateFrame: number | undefined

function normalize(value: number, length: number): number {
  return ((value % length) + length) % length
}

function format(value: number): string {
  return String(value).padStart(2, '0')
}

function emitTime(): void {
  const time = `${format(selectedHour.value)}:${format(selectedMinute.value)}`
  emit(
    'update:modelValue',
    props.secondsLabel ? `${time}:${format(selectedSecond.value)}` : time,
  )
}

function updateFromScroll(type: WheelType, element: HTMLElement): void {
  if (updateFrame) cancelAnimationFrame(updateFrame)
  updateFrame = requestAnimationFrame(() => {
    const values =
      type === 'hour' ? hours : type === 'minute' ? minutes : seconds
    let index = Math.max(
      0,
      Math.min(
        values.length * LOOP_CYCLES - 1,
        Math.round(element.scrollTop / ITEM_HEIGHT),
      ),
    )
    const value = index % values.length

    if (
      !dragState &&
      (index < values.length || index >= values.length * (LOOP_CYCLES - 1))
    ) {
      index = CENTER_CYCLE * values.length + value
      element.scrollTop = index * ITEM_HEIGHT
    }

    if (type === 'hour') {
      selectedHour.value = value
      selectedHourIndex.value = index
    } else if (type === 'minute') {
      selectedMinute.value = value
      selectedMinuteIndex.value = index
    } else {
      selectedSecond.value = value
      selectedSecondIndex.value = index
    }
    emitTime()
  })
}

function select(
  type: WheelType,
  index: number,
  value: number,
  element: HTMLElement | null,
): void {
  if (suppressClick) {
    suppressClick = false
    return
  }

  if (type === 'hour') {
    selectedHour.value = value
    selectedHourIndex.value = index
  } else if (type === 'minute') {
    selectedMinute.value = value
    selectedMinuteIndex.value = index
  } else {
    selectedSecond.value = value
    selectedSecondIndex.value = index
  }
  element?.scrollTo({ top: index * ITEM_HEIGHT })
  emitTime()
}

function beginDrag(event: PointerEvent, element: HTMLElement): void {
  if (
    !event.isPrimary ||
    (event.pointerType === 'mouse' && event.button !== 0)
  ) {
    return
  }

  dragState = {
    element,
    moved: false,
    pointerId: event.pointerId,
    startScrollTop: element.scrollTop,
    startY: event.clientY,
  }
  element.setPointerCapture(event.pointerId)
}

function drag(event: PointerEvent): void {
  if (!dragState || dragState.pointerId !== event.pointerId) return

  const distance = dragState.startY - event.clientY
  if (Math.abs(distance) > 3) dragState.moved = true
  dragState.element.scrollTop = dragState.startScrollTop + distance
  event.preventDefault()
}

function endDrag(event: PointerEvent): void {
  if (!dragState || dragState.pointerId !== event.pointerId) return

  const { element, moved, pointerId } = dragState
  dragState = null
  if (element.hasPointerCapture(pointerId))
    element.releasePointerCapture(pointerId)

  const index = Math.round(element.scrollTop / ITEM_HEIGHT)
  element.scrollTo({ behavior: 'smooth', top: index * ITEM_HEIGHT })
  suppressClick = moved
  if (moved) setTimeout(() => (suppressClick = false))
}

onMounted(() => {
  void nextTick(() => {
    hourWheel.value?.scrollTo({
      top: selectedHourIndex.value * ITEM_HEIGHT,
    })
    minuteWheel.value?.scrollTo({
      top: selectedMinuteIndex.value * ITEM_HEIGHT,
    })
    secondWheel.value?.scrollTo({
      top: selectedSecondIndex.value * ITEM_HEIGHT,
    })
  })
})

watch(
  () => props.modelValue,
  (value) => {
    const [hour = 0, minute = 0, second = 0] = value.split(':').map(Number)
    const normalizedHour = normalize(hour, hours.length)
    const normalizedMinute = normalize(minute, minutes.length)
    const normalizedSecond = normalize(second, seconds.length)
    if (
      normalizedHour === selectedHour.value &&
      normalizedMinute === selectedMinute.value &&
      normalizedSecond === selectedSecond.value
    ) {
      return
    }

    selectedHour.value = normalizedHour
    selectedMinute.value = normalizedMinute
    selectedSecond.value = normalizedSecond
    selectedHourIndex.value = CENTER_CYCLE * hours.length + normalizedHour
    selectedMinuteIndex.value = CENTER_CYCLE * minutes.length + normalizedMinute
    selectedSecondIndex.value = CENTER_CYCLE * seconds.length + normalizedSecond
    hourWheel.value?.scrollTo({ top: selectedHourIndex.value * ITEM_HEIGHT })
    minuteWheel.value?.scrollTo({
      top: selectedMinuteIndex.value * ITEM_HEIGHT,
    })
    secondWheel.value?.scrollTo({
      top: selectedSecondIndex.value * ITEM_HEIGHT,
    })
  },
)
</script>

<template>
  <section
    class="time-wheel-picker"
    :class="{
      'time-wheel-picker--duration': secondsLabel,
      'time-wheel-picker--unit-labels': showUnitLabels,
    }"
    :aria-label="label"
  >
    <div class="time-wheel-picker__selection" aria-hidden="true" />

    <div class="time-wheel-picker__field">
      <div
        ref="hourWheel"
        class="time-wheel-picker__column"
        role="listbox"
        :aria-label="hoursLabel"
        @pointercancel="endDrag"
        @pointerdown="beginDrag($event, $event.currentTarget as HTMLElement)"
        @pointermove="drag"
        @pointerup="endDrag"
        @scroll.passive="
          updateFromScroll('hour', $event.currentTarget as HTMLElement)
        "
      >
        <button
          v-for="item in loopedHours"
          :key="item.index"
          type="button"
          role="option"
          :aria-selected="selectedHourIndex === item.index"
          :class="{
            'time-wheel-picker__value--selected':
              selectedHourIndex === item.index,
          }"
          class="time-wheel-picker__value"
          @click="select('hour', item.index, item.value, hourWheel)"
        >
          {{ format(item.value) }}
        </button>
      </div>
      <span v-if="showUnitLabels" class="time-wheel-picker__unit">{{
        hoursUnitLabel ?? hoursLabel
      }}</span>
    </div>

    <div class="time-wheel-picker__field">
      <div
        ref="minuteWheel"
        class="time-wheel-picker__column"
        role="listbox"
        :aria-label="minutesLabel"
        @pointercancel="endDrag"
        @pointerdown="beginDrag($event, $event.currentTarget as HTMLElement)"
        @pointermove="drag"
        @pointerup="endDrag"
        @scroll.passive="
          updateFromScroll('minute', $event.currentTarget as HTMLElement)
        "
      >
        <button
          v-for="item in loopedMinutes"
          :key="item.index"
          type="button"
          role="option"
          :aria-selected="selectedMinuteIndex === item.index"
          :class="{
            'time-wheel-picker__value--selected':
              selectedMinuteIndex === item.index,
          }"
          class="time-wheel-picker__value"
          @click="select('minute', item.index, item.value, minuteWheel)"
        >
          {{ format(item.value) }}
        </button>
      </div>
      <span v-if="showUnitLabels" class="time-wheel-picker__unit">{{
        minutesUnitLabel ?? minutesLabel
      }}</span>
    </div>

    <div v-if="secondsLabel" class="time-wheel-picker__field">
      <div
        ref="secondWheel"
        class="time-wheel-picker__column"
        role="listbox"
        :aria-label="secondsLabel"
        @pointercancel="endDrag"
        @pointerdown="beginDrag($event, $event.currentTarget as HTMLElement)"
        @pointermove="drag"
        @pointerup="endDrag"
        @scroll.passive="
          updateFromScroll('second', $event.currentTarget as HTMLElement)
        "
      >
        <button
          v-for="item in loopedSeconds"
          :key="item.index"
          type="button"
          role="option"
          :aria-selected="selectedSecondIndex === item.index"
          :class="{
            'time-wheel-picker__value--selected':
              selectedSecondIndex === item.index,
          }"
          class="time-wheel-picker__value"
          @click="select('second', item.index, item.value, secondWheel)"
        >
          {{ format(item.value) }}
        </button>
      </div>
      <span v-if="showUnitLabels" class="time-wheel-picker__unit">{{
        secondsUnitLabel ?? secondsLabel
      }}</span>
    </div>
  </section>
</template>
