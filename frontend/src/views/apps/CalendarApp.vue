<script setup lang="ts">
import {
  Bell,
  CalendarDays,
  Check,
  ChevronLeft,
  ChevronRight,
  Circle,
  Clock3,
  FileText,
  LayoutGrid,
  List,
  Plus,
  Rows3,
  Search,
  Share2,
  Trash2,
  UserRound,
  X,
} from 'lucide-vue-next'
import { SkyGlass, SkySearchbar, SkyToggle } from '@/ui'
import { computed, nextTick, onMounted, reactive, ref } from 'vue'

import { useAccountStore } from '@/stores/account'
import { useCalendarStore } from '@/stores/calendar'
import { useEasyShareStore } from '@/stores/easyshare'
import { usePhoneStore } from '@/stores/phone'
import type { CalendarEvent, CalendarEventDraft } from '@/types/calendar'

type CalendarScreen = 'detail' | 'form' | 'main'
type CalendarViewMode = 'compact' | 'details' | 'list' | 'stacked'
type TimeField = 'endTime' | 'startTime'
type YearMonth = {
  cells: Array<Date | null>
  date: Date
  key: string
  label: string
}
type YearOverview = {
  months: YearMonth[]
  year: number
}

const phone = usePhoneStore()
const account = useAccountStore()
const calendar = useCalendarStore()
const easyShare = useEasyShareStore()
const today = new Date()
const visibleYear = ref(today.getFullYear())
const selectedDate = ref(dateKey(today))
const selectedEvent = ref<CalendarEvent | null>(null)
const editingEvent = ref<CalendarEvent | null>(null)
const screen = ref<CalendarScreen>('main')
const viewMode = ref<CalendarViewMode>('details')
const viewMenuOpen = ref(false)
const yearOverviewOpen = ref(false)
const searchOpen = ref(false)
const searchQuery = ref('')
const reminderOpen = ref(false)
const saving = ref(false)
const formError = ref('')
const datePickerOpen = ref(false)
const pickerDate = ref(selectedDate.value)
const pickerMonth = ref(new Date(today.getFullYear(), today.getMonth(), 1))
const timePickerField = ref<TimeField | null>(null)
const pickerHour = ref('09')
const pickerMinute = ref('00')
const hourColumn = ref<HTMLElement | null>(null)
const minuteColumn = ref<HTMLElement | null>(null)
const calendarScroll = ref<HTMLElement | null>(null)
const yearOverviewScroll = ref<HTMLElement | null>(null)
const searchToolbar = ref<HTMLElement | null>(null)
const draft = reactive({
  allDay: false,
  date: selectedDate.value,
  endTime: '10:00',
  note: '',
  reminderMinutes: 60 as number | null,
  startTime: '09:00',
  title: '',
})
const reminderOptions: Array<number | null> = [null, 0, 10, 30, 60, 1440]
const hourOptions = Array.from({ length: 24 }, (_, index) =>
  String(index).padStart(2, '0'),
)
const minuteOptions = Array.from({ length: 12 }, (_, index) =>
  String(index * 5).padStart(2, '0'),
)
const viewModes: Array<{
  icon: typeof LayoutGrid
  id: CalendarViewMode
  labelKey: string
}> = [
  {
    icon: LayoutGrid,
    id: 'compact',
    labelKey: 'Apps.calendar.views.compact',
  },
  {
    icon: Rows3,
    id: 'stacked',
    labelKey: 'Apps.calendar.views.stacked',
  },
  {
    icon: CalendarDays,
    id: 'details',
    labelKey: 'Apps.calendar.views.details',
  },
  {
    icon: List,
    id: 'list',
    labelKey: 'Apps.calendar.views.list',
  },
]

const isAuthenticated = computed(() => account.email !== '')
const timePickerTitle = computed(() =>
  timePickerField.value === 'startTime'
    ? phone.t('Apps.calendar.starts')
    : phone.t('Apps.calendar.ends'),
)
const draftDateLabel = computed(() =>
  new Intl.DateTimeFormat(phone.lang, {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(new Date(`${draft.date}T12:00:00`)),
)
const pickerMonthLabel = computed(() =>
  new Intl.DateTimeFormat(phone.lang, {
    month: 'long',
    year: 'numeric',
  }).format(pickerMonth.value),
)
const pickerMonthCells = computed(() => monthCells(pickerMonth.value))
const weekdayLabels = computed(() => {
  const monday = new Date(2026, 0, 5)
  return Array.from({ length: 7 }, (_, index) =>
    new Intl.DateTimeFormat(phone.lang, { weekday: 'narrow' }).format(
      addDays(monday, index),
    ),
  )
})
const yearMonths = computed<YearMonth[]>(() =>
  Array.from({ length: 12 }, (_, monthIndex) => {
    const date = new Date(visibleYear.value, monthIndex, 1)
    return {
      cells: monthCells(date),
      date,
      key: `${visibleYear.value}-${String(monthIndex + 1).padStart(2, '0')}`,
      label: new Intl.DateTimeFormat(phone.lang, { month: 'long' }).format(
        date,
      ),
    }
  }),
)
const yearOverview = computed<YearOverview[]>(() =>
  Array.from({ length: 11 }, (_, yearIndex) => {
    const year = visibleYear.value - 5 + yearIndex
    return {
      months: Array.from({ length: 12 }, (_, monthIndex) => {
        const date = new Date(year, monthIndex, 1)
        return {
          cells: monthCells(date),
          date,
          key: `${year}-${String(monthIndex + 1).padStart(2, '0')}`,
          label: new Intl.DateTimeFormat(phone.lang, { month: 'long' }).format(
            date,
          ),
        }
      }),
      year,
    }
  }),
)
const normalizedSearch = computed(() => searchQuery.value.trim().toLowerCase())
const eventsByDate = computed(() => {
  const groups = new Map<string, CalendarEvent[]>()
  for (const event of [...calendar.events]
    .filter(matchesSearch)
    .sort((left, right) => left.startsAt - right.startsAt)) {
    const key = dateKey(event.startsAt)
    const events = groups.get(key) ?? []
    events.push(event)
    groups.set(key, events)
  }
  return groups
})
const monthEventGroups = computed(() => {
  return [...eventsByDate.value.entries()].map(([key, events]) => ({
    events,
    key,
    label: new Intl.DateTimeFormat(phone.lang, {
      day: 'numeric',
      month: 'long',
      weekday: 'long',
    }).format(new Date(`${key}T12:00:00`)),
  }))
})

function addDays(date: Date, amount: number): Date {
  const next = new Date(date)
  next.setDate(next.getDate() + amount)
  return next
}

function monthCells(month: Date): Array<Date | null> {
  const first = new Date(month.getFullYear(), month.getMonth(), 1)
  const leading = (first.getDay() + 6) % 7
  const daysInMonth = new Date(
    month.getFullYear(),
    month.getMonth() + 1,
    0,
  ).getDate()
  const cellCount = Math.ceil((leading + daysInMonth) / 7) * 7
  return Array.from({ length: cellCount }, (_, index) => {
    const day = index - leading + 1
    return day > 0 && day <= daysInMonth
      ? new Date(month.getFullYear(), month.getMonth(), day)
      : null
  })
}

function dateKey(value: Date | number): string {
  const date = value instanceof Date ? value : new Date(value)
  return [
    date.getFullYear(),
    String(date.getMonth() + 1).padStart(2, '0'),
    String(date.getDate()).padStart(2, '0'),
  ].join('-')
}

function timeValue(value: number): string {
  const date = new Date(value)
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`
}

function combineDateAndTime(date: string, time: string): number {
  return new Date(`${date}T${time}:00`).getTime()
}

function matchesSearch(event: CalendarEvent): boolean {
  if (!normalizedSearch.value) return true
  return `${event.title} ${event.note}`
    .toLowerCase()
    .includes(normalizedSearch.value)
}

function eventsForDay(day: Date): CalendarEvent[] {
  return eventsByDate.value.get(dateKey(day)) ?? []
}

function formatTime(value: number): string {
  return new Intl.DateTimeFormat(phone.lang, {
    hour: '2-digit',
    hourCycle: 'h23',
    minute: '2-digit',
  }).format(value)
}

function formatLongDate(value: number): string {
  return new Intl.DateTimeFormat(phone.lang, {
    day: 'numeric',
    month: 'long',
    weekday: 'long',
    year: 'numeric',
  }).format(value)
}

function reminderLabel(minutes: number | null): string {
  if (minutes === null) return phone.t('Apps.calendar.reminders.none')
  if (minutes === 0) return phone.t('Apps.calendar.reminders.atStart')
  if (minutes === 10) return phone.t('Apps.calendar.reminders.tenMinutes')
  if (minutes === 30) return phone.t('Apps.calendar.reminders.thirtyMinutes')
  if (minutes === 60) return phone.t('Apps.calendar.reminders.oneHour')
  return phone.t('Apps.calendar.reminders.oneDay')
}

async function loadYear(): Promise<void> {
  if (!isAuthenticated.value) {
    calendar.events = []
    return
  }
  const start = new Date(visibleYear.value, 0, 1)
  const end = new Date(visibleYear.value + 1, 0, 1)
  await calendar.load(start.getTime(), end.getTime())
}

async function moveYear(amount: number): Promise<void> {
  visibleYear.value += amount
  selectedDate.value = `${visibleYear.value}-01-01`
  await loadYear()
  await nextTick()
  calendarScroll.value?.scrollTo({ behavior: 'smooth', top: 0 })
}

async function goToday(): Promise<void> {
  const current = new Date()
  visibleYear.value = current.getFullYear()
  selectedDate.value = dateKey(current)
  await loadYear()
  await nextTick()
  if (yearOverviewOpen.value) {
    yearOverviewScroll.value
      ?.querySelector<HTMLElement>(`[data-year="${visibleYear.value}"]`)
      ?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  } else {
    scrollToMonth(current)
  }
}

function selectDay(day: Date): void {
  selectedDate.value = dateKey(day)
}

function selectView(mode: CalendarViewMode): void {
  viewMode.value = mode
  viewMenuOpen.value = false
}

async function openYearOverview(): Promise<void> {
  viewMenuOpen.value = false
  yearOverviewOpen.value = true
  await nextTick()
  yearOverviewScroll.value
    ?.querySelector<HTMLElement>(`[data-year="${visibleYear.value}"]`)
    ?.scrollIntoView({ block: 'start' })
}

async function selectOverviewDay(day: Date): Promise<void> {
  visibleYear.value = day.getFullYear()
  selectedDate.value = dateKey(day)
  yearOverviewOpen.value = false
  await loadYear()
  await nextTick()
  scrollToMonth(day, 'auto')
}

function scrollToMonth(date: Date, behavior: ScrollBehavior = 'smooth'): void {
  calendarScroll.value
    ?.querySelector<HTMLElement>(`[data-month="${dateKey(date).slice(0, 7)}"]`)
    ?.scrollIntoView({ behavior, block: 'start' })
}

async function toggleSearch(): Promise<void> {
  searchOpen.value = !searchOpen.value
  viewMenuOpen.value = false
  if (!searchOpen.value) {
    searchQuery.value = ''
    return
  }
  await nextTick()
  searchToolbar.value?.querySelector('input')?.focus()
}

function isAllDayEvent(event: CalendarEvent): boolean {
  return (
    timeValue(event.startsAt) === '00:00' && timeValue(event.endsAt) === '23:59'
  )
}

function eventTimeLabel(event: CalendarEvent): string {
  if (isAllDayEvent(event)) return phone.t('Apps.calendar.allDay')
  return `${formatTime(event.startsAt)} – ${formatTime(event.endsAt)}`
}

function updateSearch(event: Event): void {
  searchQuery.value = (event.target as HTMLInputElement).value
}

function resetDraft(event?: CalendarEvent): void {
  editingEvent.value = event ?? null
  draft.allDay = event ? isAllDayEvent(event) : false
  draft.title = event?.title ?? ''
  draft.note = event?.note ?? ''
  draft.date = event ? dateKey(event.startsAt) : selectedDate.value
  draft.startTime = event ? timeValue(event.startsAt) : '09:00'
  draft.endTime = event ? timeValue(event.endsAt) : '10:00'
  draft.reminderMinutes = event?.reminderMinutes ?? 60
  datePickerOpen.value = false
  reminderOpen.value = false
  formError.value = ''
}

function openCreate(): void {
  resetDraft()
  screen.value = 'form'
}

function openDetail(event: CalendarEvent): void {
  selectedEvent.value = event
  screen.value = 'detail'
}

function openEdit(): void {
  if (!selectedEvent.value) return
  resetDraft(selectedEvent.value)
  screen.value = 'form'
}

function shareEvent(): void {
  if (!selectedEvent.value) return
  easyShare.open({
    appId: 'calendar',
    copyText: `${selectedEvent.value.title}\n${selectedEvent.value.note}`,
    id: selectedEvent.value.id,
    kind: 'document',
    link: `skyphone://calendar/event/${selectedEvent.value.id}`,
    subtitle: formatLongDate(selectedEvent.value.startsAt),
    title: selectedEvent.value.title,
  })
}

function closeForm(): void {
  datePickerOpen.value = false
  timePickerField.value = null
  screen.value = editingEvent.value ? 'detail' : 'main'
}

function toggleAllDay(): void {
  draft.allDay = !draft.allDay
  timePickerField.value = null
  if (
    !draft.allDay &&
    draft.startTime === '00:00' &&
    draft.endTime === '23:59'
  ) {
    draft.startTime = '09:00'
    draft.endTime = '10:00'
  }
}

function openDatePicker(): void {
  const date = new Date(`${draft.date}T12:00:00`)
  pickerDate.value = draft.date
  pickerMonth.value = new Date(date.getFullYear(), date.getMonth(), 1)
  timePickerField.value = null
  datePickerOpen.value = true
}

function movePickerMonth(amount: number): void {
  pickerMonth.value = new Date(
    pickerMonth.value.getFullYear(),
    pickerMonth.value.getMonth() + amount,
    1,
  )
}

function confirmDatePicker(): void {
  draft.date = pickerDate.value
  datePickerOpen.value = false
}

async function openTimePicker(field: TimeField): Promise<void> {
  const [hour, minute] = draft[field].split(':')
  timePickerField.value = field
  pickerHour.value = hour ?? '09'
  pickerMinute.value = minute ?? '00'
  datePickerOpen.value = false
  await nextTick()
  hourColumn.value
    ?.querySelector(`[data-value="${pickerHour.value}"]`)
    ?.scrollIntoView({ block: 'center' })
  minuteColumn.value
    ?.querySelector(`[data-value="${pickerMinute.value}"]`)
    ?.scrollIntoView({ block: 'center' })
}

function confirmTimePicker(): void {
  if (!timePickerField.value) return
  draft[timePickerField.value] = `${pickerHour.value}:${pickerMinute.value}`
  timePickerField.value = null
}

function selectPickerValue(
  column: 'hour' | 'minute',
  value: string,
  target: EventTarget | null,
): void {
  if (column === 'hour') pickerHour.value = value
  else pickerMinute.value = value
  if (target instanceof HTMLElement) {
    target.scrollIntoView({ block: 'center', behavior: 'smooth' })
  }
}

async function saveEvent(): Promise<void> {
  const startsAt = combineDateAndTime(
    draft.date,
    draft.allDay ? '00:00' : draft.startTime,
  )
  const endsAt = combineDateAndTime(
    draft.date,
    draft.allDay ? '23:59' : draft.endTime,
  )
  if (!draft.title.trim() || endsAt <= startsAt) {
    formError.value = phone.t('Apps.calendar.errors.invalid_event')
    return
  }
  const payload: CalendarEventDraft = {
    endsAt,
    note: draft.note.trim(),
    reminderMinutes: draft.reminderMinutes,
    startsAt,
    title: draft.title.trim(),
  }
  saving.value = true
  const success = editingEvent.value
    ? await calendar.update(editingEvent.value, payload)
    : await calendar.create(payload)
  saving.value = false
  if (!success) {
    formError.value = phone.t(
      `Apps.calendar.errors.${calendar.error || 'default'}`,
    )
    return
  }
  selectedDate.value = draft.date
  visibleYear.value = new Date(startsAt).getFullYear()
  await loadYear()
  screen.value = 'main'
}

async function deleteEvent(): Promise<void> {
  if (
    !selectedEvent.value ||
    !(await calendar.deleteEvent(selectedEvent.value.id))
  ) {
    return
  }
  selectedEvent.value = null
  screen.value = 'main'
}

onMounted(async () => {
  await loadYear()
  await nextTick()
  scrollToMonth(today, 'auto')
})
</script>

<template>
  <main class="calendar" :class="{ 'calendar--light': !phone.isDarkMode }">
    <template v-if="screen === 'main'">
      <header
        class="calendar__toolbar"
        :class="{ 'calendar__toolbar--year': yearOverviewOpen }"
      >
        <Transition name="calendar-search" mode="out-in">
          <div
            v-if="searchOpen"
            ref="searchToolbar"
            class="calendar__search-toolbar"
          >
            <sky-searchbar
              class="calendar__searchbar"
              :placeholder="phone.t('Apps.calendar.searchPlaceholder')"
              :value="searchQuery"
              @clear="searchQuery = ''"
              @input="updateSearch"
            />
            <sky-glass
              component="button"
              type="button"
              class="calendar__control calendar__control--close"
              :aria-label="phone.t('Common.close')"
              @click="toggleSearch"
            >
              <X :size="20" />
            </sky-glass>
          </div>
          <div v-else class="calendar__toolbar-default">
            <sky-glass
              v-if="!yearOverviewOpen"
              component="button"
              type="button"
              class="calendar__control calendar__control--year"
              :aria-label="String(visibleYear)"
              @click="openYearOverview"
            >
              <ChevronLeft :size="20" />
              <span>{{ visibleYear }}</span>
            </sky-glass>
            <div class="calendar__toolbar-actions">
              <sky-glass
                v-if="!yearOverviewOpen"
                component="button"
                class="calendar__control"
                :aria-label="phone.t(`Apps.calendar.views.${viewMode}`)"
                type="button"
                @click="viewMenuOpen = !viewMenuOpen"
              >
                <component
                  :is="viewModes.find((mode) => mode.id === viewMode)?.icon"
                  :size="19"
                />
              </sky-glass>
              <sky-glass
                component="button"
                class="calendar__control"
                :aria-label="phone.t('Common.search')"
                type="button"
                @click="toggleSearch"
              >
                <Search :size="19" />
              </sky-glass>
              <sky-glass
                v-if="isAuthenticated"
                component="button"
                class="calendar__control"
                :aria-label="phone.t('Apps.calendar.newEvent')"
                type="button"
                @click="openCreate"
              >
                <Plus :size="21" />
              </sky-glass>
            </div>

            <Transition name="calendar-popover">
              <div v-if="viewMenuOpen" class="calendar__view-menu">
                <button
                  v-for="mode in viewModes"
                  :key="mode.id"
                  :class="{ active: viewMode === mode.id }"
                  type="button"
                  @click="selectView(mode.id)"
                >
                  <component :is="mode.icon" :size="19" />
                  <span>{{ phone.t(mode.labelKey) }}</span>
                  <Check v-if="viewMode === mode.id" :size="17" />
                </button>
              </div>
            </Transition>
          </div>
        </Transition>
      </header>

      <section v-if="!isAuthenticated" class="calendar__auth">
        <span><UserRound :size="33" /></span>
        <h1>{{ phone.t('Apps.calendar.signInTitle') }}</h1>
        <p>{{ phone.t('Apps.calendar.signInBody') }}</p>
      </section>

      <div
        v-else-if="yearOverviewOpen"
        ref="yearOverviewScroll"
        class="calendar__year-overview"
      >
        <section
          v-for="overview in yearOverview"
          :key="overview.year"
          class="calendar__overview-year"
          :data-year="overview.year"
        >
          <h1>{{ overview.year }}</h1>
          <div class="calendar__overview-months">
            <section
              v-for="month in overview.months"
              :key="month.key"
              class="calendar__overview-month"
            >
              <h2
                :class="{
                  current:
                    month.date.getFullYear() === today.getFullYear() &&
                    month.date.getMonth() === today.getMonth(),
                }"
              >
                {{ month.label }}
              </h2>
              <div>
                <template
                  v-for="(day, cellIndex) in month.cells"
                  :key="day ? dateKey(day) : `${month.key}-${cellIndex}`"
                >
                  <button
                    v-if="day"
                    type="button"
                    :class="{
                      selected: dateKey(day) === selectedDate,
                      today: dateKey(day) === dateKey(today),
                    }"
                    @click="selectOverviewDay(day)"
                  >
                    {{ day.getDate() }}
                  </button>
                  <span v-else />
                </template>
              </div>
            </section>
          </div>
        </section>
      </div>

      <div
        v-else
        ref="calendarScroll"
        class="calendar__content"
        :class="`calendar__content--${viewMode}`"
      >
        <template v-if="viewMode !== 'list'">
          <section
            v-for="month in yearMonths"
            :key="month.key"
            class="calendar__year-month"
            :data-month="month.key"
          >
            <h1>{{ month.label }}</h1>
            <div class="calendar__weekdays">
              <span
                v-for="(weekday, weekdayIndex) in weekdayLabels"
                :key="`${month.key}-${weekdayIndex}`"
                :class="{ weekend: weekdayIndex > 4 }"
              >
                {{ weekday }}
              </span>
            </div>
            <div
              class="calendar__year-grid"
              :class="`calendar__year-grid--${viewMode}`"
            >
              <template
                v-for="(day, cellIndex) in month.cells"
                :key="day ? dateKey(day) : `${month.key}-blank-${cellIndex}`"
              >
                <button
                  v-if="day"
                  type="button"
                  :class="{
                    selected: dateKey(day) === selectedDate,
                    today: dateKey(day) === dateKey(today),
                    weekend: cellIndex % 7 > 4,
                  }"
                  @click="selectDay(day)"
                >
                  <span class="calendar__day-number">{{ day.getDate() }}</span>
                  <span
                    v-if="viewMode === 'compact' && eventsForDay(day).length"
                    class="calendar__compact-indicator"
                  />
                  <span
                    v-else-if="
                      viewMode === 'stacked' && eventsForDay(day).length
                    "
                    class="calendar__event-bars"
                  >
                    <i
                      v-for="(event, eventIndex) in eventsForDay(day).slice(
                        0,
                        3,
                      )"
                      :key="event.id"
                      :class="`calendar__event-dot--${eventIndex % 3}`"
                    />
                  </span>
                  <span
                    v-else-if="
                      viewMode === 'details' && eventsForDay(day).length
                    "
                    class="calendar__event-titles"
                  >
                    <i
                      v-for="event in eventsForDay(day).slice(0, 2)"
                      :key="event.id"
                    >
                      {{ event.title }}
                    </i>
                  </span>
                </button>
                <span v-else class="calendar__blank-day" />
              </template>
            </div>
          </section>

          <button
            class="calendar__next-year"
            type="button"
            @click="moveYear(1)"
          >
            <span>{{ visibleYear + 1 }}</span>
            <ChevronRight :size="19" />
          </button>
        </template>

        <section v-else class="calendar__list-view">
          <div v-if="calendar.loading" class="calendar__empty-copy">
            {{ phone.t('Common.loading') }}
          </div>
          <div
            v-else-if="!monthEventGroups.length"
            class="calendar__empty-copy calendar__empty-copy--list"
          >
            <CalendarDays :size="38" />
            <strong>{{ phone.t('Apps.calendar.noEvents') }}</strong>
            <span>{{ phone.t('Apps.calendar.noEventsBody') }}</span>
          </div>
          <section
            v-for="group in monthEventGroups"
            v-else
            :key="group.key"
            class="calendar__list-group"
          >
            <header>
              <strong>{{ group.label }}</strong>
              <span>{{ group.events.length }}</span>
            </header>
            <button
              v-for="event in group.events"
              :key="event.id"
              type="button"
              @click="openDetail(event)"
            >
              <i />
              <span>
                <strong>{{ event.title }}</strong>
                <small>{{ eventTimeLabel(event) }}</small>
              </span>
              <ChevronRight :size="17" />
            </button>
          </section>
        </section>
      </div>

      <footer v-if="isAuthenticated" class="calendar__footer">
        <sky-glass
          component="button"
          type="button"
          class="calendar__control calendar__control--today"
          @click="goToday"
        >
          {{ phone.t('Apps.calendar.today') }}
        </sky-glass>
      </footer>
    </template>

    <section
      v-else-if="screen === 'detail' && selectedEvent"
      class="calendar__detail"
    >
      <header class="calendar__sheet-header">
        <button type="button" @click="screen = 'main'">
          <ChevronLeft :size="20" />
          {{ phone.t('Apps.calendar.name') }}
        </button>
        <strong>{{ phone.t('Apps.calendar.event') }}</strong>
        <button type="button" @click="openEdit">
          {{ phone.t('Common.edit') }}
        </button>
      </header>
      <div class="calendar__sheet-scroll">
        <section class="calendar__detail-title">
          <i />
          <div>
            <h1>{{ selectedEvent.title }}</h1>
            <span>{{ phone.t('Apps.calendar.calendarName') }}</span>
          </div>
        </section>
        <section class="calendar__group">
          <div class="calendar__group-row calendar__group-row--tall">
            <Clock3 :size="20" />
            <div>
              <small>{{ phone.t('Apps.calendar.date') }}</small>
              <strong>{{ formatLongDate(selectedEvent.startsAt) }}</strong>
              <span>{{ eventTimeLabel(selectedEvent) }}</span>
            </div>
          </div>
          <div class="calendar__group-row">
            <Bell :size="20" />
            <span>{{ phone.t('Apps.calendar.reminder') }}</span>
            <strong>{{ reminderLabel(selectedEvent.reminderMinutes) }}</strong>
          </div>
        </section>
        <section v-if="selectedEvent.note" class="calendar__group">
          <div class="calendar__group-row calendar__group-row--note">
            <FileText :size="20" />
            <p>{{ selectedEvent.note }}</p>
          </div>
        </section>
        <button
          class="calendar__delete calendar__share"
          type="button"
          @click="shareEvent"
        >
          <Share2 :size="18" />
          {{ phone.t('Apps.easyShare.share') }}
        </button>
        <button class="calendar__delete" type="button" @click="deleteEvent">
          <Trash2 :size="18" />
          {{ phone.t('Apps.calendar.deleteEvent') }}
        </button>
      </div>
    </section>

    <section v-else class="calendar__form">
      <header class="calendar__sheet-header">
        <sky-glass
          component="button"
          type="button"
          class="calendar__control calendar__sheet-action"
          @click="closeForm"
        >
          {{ phone.t('Common.cancel') }}
        </sky-glass>
        <strong>
          {{
            editingEvent
              ? phone.t('Apps.calendar.editEvent')
              : phone.t('Apps.calendar.newEvent')
          }}
        </strong>
        <sky-glass
          component="button"
          type="button"
          class="calendar__control calendar__sheet-action"
          :disabled="saving"
          @click="saveEvent"
        >
          {{ editingEvent ? phone.t('Common.save') : phone.t('Common.add') }}
        </sky-glass>
      </header>
      <form class="calendar__sheet-scroll" @submit.prevent="saveEvent">
        <section class="calendar__group calendar__group--fields">
          <input
            v-model="draft.title"
            maxlength="120"
            :placeholder="phone.t('Apps.calendar.title')"
          />
          <textarea
            v-model="draft.note"
            maxlength="2000"
            :placeholder="phone.t('Apps.calendar.notePlaceholder')"
          />
        </section>

        <section class="calendar__group calendar__group--fields">
          <button
            class="calendar__date-time-row"
            type="button"
            @click="openDatePicker"
          >
            <span>{{ phone.t('Apps.calendar.date') }}</span>
            <strong>{{ draftDateLabel }}</strong>
            <ChevronRight :size="17" />
          </button>
          <div class="calendar__all-day-row">
            <span>{{ phone.t('Apps.calendar.allDay') }}</span>
            <sky-toggle
              :checked="draft.allDay"
              style="--sky-app-accent: #ff3b30"
              :aria-label="phone.t('Apps.calendar.allDay')"
              @change="toggleAllDay"
            />
          </div>
          <button
            v-if="!draft.allDay"
            class="calendar__date-time-row"
            type="button"
            @click="openTimePicker('startTime')"
          >
            <span>{{ phone.t('Apps.calendar.starts') }}</span>
            <strong>{{ draft.startTime }}</strong>
            <ChevronRight :size="17" />
          </button>
          <button
            v-if="!draft.allDay"
            class="calendar__date-time-row"
            type="button"
            @click="openTimePicker('endTime')"
          >
            <span>{{ phone.t('Apps.calendar.ends') }}</span>
            <strong>{{ draft.endTime }}</strong>
            <ChevronRight :size="17" />
          </button>
        </section>

        <section class="calendar__group calendar__group--fields">
          <button
            class="calendar__form-row"
            type="button"
            @click="reminderOpen = !reminderOpen"
          >
            <Bell :size="19" />
            <span>{{ phone.t('Apps.calendar.reminder') }}</span>
            <strong>{{ reminderLabel(draft.reminderMinutes) }}</strong>
            <ChevronRight :size="17" :class="{ open: reminderOpen }" />
          </button>
          <div v-if="reminderOpen" class="calendar__reminders">
            <button
              v-for="option in reminderOptions"
              :key="String(option)"
              type="button"
              :class="{ active: draft.reminderMinutes === option }"
              @click="draft.reminderMinutes = option"
            >
              <span>{{ reminderLabel(option) }}</span>
              <Check v-if="draft.reminderMinutes === option" :size="18" />
            </button>
          </div>
          <div class="calendar__form-row">
            <Circle :size="17" fill="#ff3b30" color="#ff3b30" />
            <span>{{ phone.t('Apps.calendar.calendar') }}</span>
            <strong>{{ phone.t('Apps.calendar.calendarName') }}</strong>
          </div>
        </section>

        <p v-if="formError" class="calendar__error">{{ formError }}</p>
      </form>
    </section>

    <Transition name="calendar-picker">
      <div
        v-if="datePickerOpen"
        class="calendar__picker-backdrop"
        role="presentation"
        @click.self="datePickerOpen = false"
      >
        <section
          class="calendar__time-picker calendar__date-picker"
          role="dialog"
          aria-modal="true"
          :aria-label="phone.t('Apps.calendar.date')"
        >
          <header>
            <button type="button" @click="datePickerOpen = false">
              {{ phone.t('Common.cancel') }}
            </button>
            <strong>{{ phone.t('Apps.calendar.date') }}</strong>
            <button type="button" @click="confirmDatePicker">
              {{ phone.t('Common.done') }}
            </button>
          </header>

          <div class="calendar__date-picker-month">
            <sky-glass
              component="button"
              type="button"
              :aria-label="phone.t('Apps.calendar.previousMonth')"
              @click="movePickerMonth(-1)"
            >
              <ChevronLeft :size="20" />
            </sky-glass>
            <strong>{{ pickerMonthLabel }}</strong>
            <sky-glass
              component="button"
              type="button"
              :aria-label="phone.t('Apps.calendar.nextMonth')"
              @click="movePickerMonth(1)"
            >
              <ChevronRight :size="20" />
            </sky-glass>
          </div>

          <div class="calendar__date-picker-weekdays" aria-hidden="true">
            <span v-for="weekday in weekdayLabels" :key="weekday">
              {{ weekday }}
            </span>
          </div>
          <div class="calendar__date-picker-grid">
            <template v-for="(day, index) in pickerMonthCells" :key="index">
              <button
                v-if="day"
                type="button"
                :class="{
                  selected: pickerDate === dateKey(day),
                  today: dateKey(day) === dateKey(today),
                }"
                :aria-label="formatLongDate(day.getTime())"
                @click="pickerDate = dateKey(day)"
              >
                {{ day.getDate() }}
              </button>
              <span v-else />
            </template>
          </div>
        </section>
      </div>
    </Transition>

    <Transition name="calendar-picker">
      <div
        v-if="timePickerField"
        class="calendar__picker-backdrop"
        role="presentation"
        @click.self="timePickerField = null"
      >
        <section
          class="calendar__time-picker"
          role="dialog"
          aria-modal="true"
          :aria-label="timePickerTitle"
        >
          <header>
            <button type="button" @click="timePickerField = null">
              {{ phone.t('Common.cancel') }}
            </button>
            <strong>{{ timePickerTitle }}</strong>
            <button type="button" @click="confirmTimePicker">
              {{ phone.t('Common.done') }}
            </button>
          </header>

          <div class="calendar__time-preview">
            {{ pickerHour }}<span>:</span>{{ pickerMinute }}
          </div>

          <div class="calendar__time-wheels">
            <div ref="hourColumn" class="calendar__time-column">
              <button
                v-for="hour in hourOptions"
                :key="hour"
                :data-value="hour"
                :class="{ selected: pickerHour === hour }"
                type="button"
                @click="selectPickerValue('hour', hour, $event.currentTarget)"
              >
                {{ hour }}
              </button>
            </div>
            <strong>:</strong>
            <div ref="minuteColumn" class="calendar__time-column">
              <button
                v-for="minute in minuteOptions"
                :key="minute"
                :data-value="minute"
                :class="{ selected: pickerMinute === minute }"
                type="button"
                @click="
                  selectPickerValue('minute', minute, $event.currentTarget)
                "
              >
                {{ minute }}
              </button>
            </div>
            <i aria-hidden="true" />
          </div>
        </section>
      </div>
    </Transition>
  </main>
</template>

<style scoped>
.calendar {
  --color-primary: transparent;
  --accent: #ff3b30;
  --bg: #000;
  --elevated: #1c1c1e;
  --field: #2c2c2e;
  --glass: rgb(58 58 60 / 76%);
  --label: #fff;
  --line: rgb(255 255 255 / 10%);
  --muted: #98989f;
  position: absolute;
  inset: 0;
  overflow: hidden;
  padding: 47px 0 24px;
  background: var(--bg);
  color: var(--label);
  font-family: var(--sky-font-family);
}

.calendar--light {
  --bg: #f2f2f7;
  --elevated: #fff;
  --field: #f2f2f7;
  --glass: rgb(250 250 252 / 78%);
  --label: #111114;
  --line: rgb(60 60 67 / 13%);
  --muted: #6e6e73;
}

.calendar button,
.calendar input,
.calendar textarea {
  border: 0;
  color: inherit;
  font: inherit;
}

.calendar button {
  cursor: pointer;
}

.calendar__toolbar {
  position: relative;
  z-index: 8;
  height: 68px;
  padding: 11px 14px 9px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.calendar__toolbar-actions {
  margin-left: auto;
  display: flex;
  align-items: center;
  gap: 8px;
}

.calendar__toolbar-default,
.calendar__search-toolbar {
  width: 100%;
  display: flex;
  align-items: center;
}

.calendar__toolbar-default {
  justify-content: space-between;
  gap: 10px;
}

.calendar__search-toolbar {
  gap: 8px;
}

.calendar__searchbar {
  min-width: 0;
  flex: 1;
}

.calendar__searchbar :deep(> div:first-child) {
  height: 44px;
  border-radius: 9999px;
  overflow: hidden;
  background: var(--color-ios-dark-glass);
  box-shadow: var(--shadow-ios-dark-glass);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
}

.calendar--light .calendar__searchbar :deep(> div:first-child) {
  background: var(--color-ios-light-glass);
  box-shadow: var(--shadow-ios-light-glass);
}

.calendar__searchbar :deep(input) {
  color: var(--label);
  font-size: 14px;
}

.calendar__control {
  width: 44px;
  height: 44px;
  padding: 0;
  border-radius: 9999px;
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 3px;
  background: var(--color-ios-dark-glass);
  color: var(--label);
  box-shadow: var(--shadow-ios-dark-glass);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
}

.calendar--light .calendar__control {
  background: var(--color-ios-light-glass);
  box-shadow: var(--shadow-ios-light-glass);
}

.calendar__control--year {
  width: auto;
  min-width: 86px;
  padding: 0 11px 0 7px;
  color: var(--accent);
  font-size: 14px;
  font-weight: 700;
}

.calendar__control--today {
  width: auto;
  min-width: 74px;
  padding: 0 14px;
  color: var(--accent);
  font-size: 13px;
  font-weight: 750;
}

.calendar__control--close {
  flex: none;
  color: var(--accent);
}

.calendar__view-menu {
  position: absolute;
  z-index: 12;
  top: 62px;
  right: 91px;
  width: 190px;
  padding: 8px;
  border: 1px solid var(--line);
  border-radius: 18px;
  background: var(--elevated);
  box-shadow: 0 16px 44px rgb(0 0 0 / 38%);
  backdrop-filter: blur(28px) saturate(180%);
  -webkit-backdrop-filter: blur(28px) saturate(180%);
}

.calendar__view-menu button {
  width: 100%;
  min-height: 42px;
  padding: 7px 9px;
  border-radius: 11px;
  display: grid;
  grid-template-columns: 22px 1fr 18px;
  align-items: center;
  gap: 7px;
  background: transparent;
  font-size: 14px;
  text-align: left;
}

.calendar__view-menu button.active {
  background: rgb(255 59 48 / 14%);
  color: var(--accent);
}

.calendar__content {
  height: calc(100% - 68px);
  padding: 4px 0 100px;
  overflow-y: auto;
  overscroll-behavior: contain;
  scroll-behavior: smooth;
  scrollbar-width: none;
}

.calendar__year-overview {
  height: calc(100% - 68px);
  padding: 4px 14px 100px;
  overflow-y: auto;
  overscroll-behavior: contain;
  scroll-behavior: smooth;
  scrollbar-width: none;
}

.calendar__year-overview::-webkit-scrollbar {
  display: none;
}

.calendar__overview-year {
  scroll-margin-top: 4px;
  padding-bottom: 36px;
}

.calendar__overview-year > h1 {
  margin: 0 0 14px;
  padding: 10px 2px 9px;
  border-bottom: 1px solid var(--line);
  color: var(--accent);
  font-size: 40px;
  font-weight: 780;
  line-height: 1;
  letter-spacing: -1.4px;
}

.calendar__overview-months {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(145px, 1fr));
  gap: 28px 18px;
}

.calendar__overview-month {
  min-width: 0;
}

.calendar__overview-month h2 {
  margin: 0 0 7px;
  overflow: hidden;
  color: var(--label);
  font-size: 16px;
  font-weight: 680;
  line-height: 1.1;
  text-overflow: ellipsis;
  text-transform: capitalize;
  white-space: nowrap;
}

.calendar__overview-month h2.current {
  color: var(--accent);
}

.calendar__overview-month > div {
  display: grid;
  grid-template-columns: repeat(7, minmax(0, 1fr));
}

.calendar__overview-month button,
.calendar__overview-month > div > span {
  min-width: 0;
  height: 22px;
}

.calendar__overview-month button {
  padding: 0;
  border-radius: 50%;
  display: grid;
  place-items: center;
  background: transparent;
  color: var(--label);
  font-size: 11px;
  font-variant-numeric: tabular-nums;
  font-weight: 540;
}

.calendar__overview-month button.today,
.calendar__overview-month button.selected {
  background: var(--accent);
  color: #fff;
  font-weight: 750;
}

.calendar__content::-webkit-scrollbar {
  display: none;
}

.calendar__year-month {
  scroll-margin-top: 8px;
  margin-bottom: 30px;
}

.calendar__year-month h1 {
  margin: 0;
  padding: 13px 18px 16px;
  font-size: 34px;
  font-weight: 780;
  line-height: 1;
  letter-spacing: -1.2px;
  text-transform: capitalize;
}

.calendar__weekdays,
.calendar__year-grid {
  display: grid;
  grid-template-columns: repeat(7, minmax(0, 1fr));
}

.calendar__weekdays {
  height: 28px;
  padding: 0 7px;
  align-items: center;
  color: var(--label);
  font-size: 10px;
  font-weight: 680;
  text-align: center;
}

.calendar__weekdays span.weekend {
  color: var(--muted);
}

.calendar__year-grid {
  padding: 0 7px;
}

.calendar__year-grid button,
.calendar__blank-day {
  height: 92px;
  border-top: 1px solid var(--line) !important;
}

.calendar__year-grid--compact > * {
  height: 72px;
}

.calendar__year-grid--stacked > * {
  height: 88px;
}

.calendar__year-grid--details > * {
  height: 112px;
}

.calendar__year-grid button {
  min-width: 0;
  padding: 11px 1px 8px;
  display: flex;
  flex-direction: column;
  align-items: center;
  overflow: hidden;
  background: transparent;
  color: var(--label);
}

.calendar__year-grid button.weekend {
  color: var(--muted);
}

.calendar__day-number {
  width: 34px;
  height: 34px;
  flex: none;
  border-radius: 50%;
  display: grid;
  place-items: center;
  font-size: 17px;
  font-weight: 600;
}

.calendar__year-grid button.today .calendar__day-number {
  color: var(--accent);
  font-weight: 800;
}

.calendar__year-grid button.selected .calendar__day-number {
  background: var(--accent);
  color: #fff;
  font-weight: 800;
}

.calendar__compact-indicator {
  width: 5px;
  height: 5px;
  margin-top: 2px;
  border-radius: 50%;
  background: #a855f7;
}

.calendar__event-bars {
  width: 74%;
  margin-top: 3px;
  display: flex;
  align-items: center;
  gap: 2px;
}

.calendar__event-bars i {
  height: 4px;
  min-width: 0;
  flex: 1;
  border-radius: 2px;
}

.calendar__event-dot--0 {
  background: #a855f7;
}

.calendar__event-dot--1 {
  background: #0ea5e9;
}

.calendar__event-dot--2 {
  background: #f59e0b;
}

.calendar__event-titles {
  width: 100%;
  padding: 0 2px;
  display: flex;
  flex-direction: column;
  gap: 1px;
}

.calendar__event-titles i {
  overflow: hidden;
  color: var(--accent);
  font-size: 8px;
  font-style: normal;
  font-weight: 650;
  line-height: 10px;
  text-align: left;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.calendar__next-year {
  width: calc(100% - 28px);
  height: 48px;
  margin: 0 14px 20px;
  border-top: 1px solid var(--line) !important;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 4px;
  background: transparent;
  color: var(--accent) !important;
  font-size: 15px !important;
  font-weight: 650 !important;
}

.calendar__footer {
  position: absolute;
  z-index: 9;
  bottom: 29px;
  left: 14px;
  display: flex;
  align-items: center;
}

.calendar__list-view {
  padding: 0 14px;
}

.calendar__agenda {
  padding: 16px 1px 22px;
}

.calendar__agenda > header {
  min-height: 44px;
  padding: 0 3px 9px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.calendar__agenda > header div {
  display: flex;
  align-items: center;
  gap: 6px;
}

.calendar__agenda > header strong {
  font-size: 18px;
  text-transform: capitalize;
}

.calendar__agenda > header span {
  min-width: 28px;
  height: 28px;
  padding: 0 6px;
  border-radius: 10px;
  display: grid;
  place-items: center;
  background: var(--elevated);
  color: var(--muted);
  font-size: 12px;
}

.calendar__agenda > header button {
  width: 34px;
  height: 34px;
  padding: 0;
  border-radius: 50%;
  display: grid;
  place-items: center;
  background: rgb(255 59 48 / 12%);
  color: var(--accent);
}

.calendar__event-row {
  width: 100%;
  min-height: 74px;
  padding: 11px 2px;
  border-bottom: 1px solid var(--line) !important;
  display: grid;
  grid-template-columns: 56px 4px 1fr 18px;
  align-items: center;
  gap: 8px;
  background: transparent;
  text-align: left;
}

.calendar__event-time strong,
.calendar__event-time small,
.calendar__event-copy strong,
.calendar__event-copy small {
  display: block;
}

.calendar__event-time {
  text-align: right;
}

.calendar__event-time strong {
  font-size: 12px;
}

.calendar__event-time small,
.calendar__event-copy small {
  color: var(--muted);
  font-size: 10px;
}

.calendar__event-row > i,
.calendar__list-group button > i {
  width: 4px;
  height: 40px;
  border-radius: 3px;
  background: var(--accent);
}

.calendar__event-copy {
  min-width: 0;
}

.calendar__event-copy strong {
  overflow: hidden;
  font-size: 14px;
  white-space: nowrap;
  text-overflow: ellipsis;
}

.calendar__event-copy small {
  margin-top: 2px;
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
}

.calendar__event-row > svg,
.calendar__list-group button > svg {
  color: var(--muted);
}

.calendar__empty-copy {
  min-height: 70px;
  padding: 14px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 3px;
  color: var(--muted);
  font-size: 12px;
  text-align: center;
}

.calendar__empty-copy strong {
  color: var(--label);
  font-size: 14px;
}

.calendar__empty-copy--list {
  height: 250px;
}

.calendar__list-view {
  padding-top: 4px;
}

.calendar__list-group {
  margin-bottom: 13px;
}

.calendar__list-group > header {
  height: 42px;
  padding: 0 5px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  color: var(--accent);
}

.calendar__list-group > header strong {
  font-size: 16px;
  text-transform: capitalize;
}

.calendar__list-group > header span {
  font-size: 12px;
}

.calendar__list-group button {
  width: 100%;
  min-height: 70px;
  padding: 10px 5px;
  border-bottom: 1px solid var(--line) !important;
  display: grid;
  grid-template-columns: 3px 1fr 15px;
  align-items: center;
  gap: 9px;
  background: transparent;
  text-align: left;
}

.calendar__list-group button span {
  min-width: 0;
}

.calendar__list-group button strong,
.calendar__list-group button small {
  display: block;
}

.calendar__list-group button strong {
  overflow: hidden;
  font-size: 14px;
  white-space: nowrap;
  text-overflow: ellipsis;
}

.calendar__list-group button small {
  margin-top: 2px;
  color: var(--muted);
  font-size: 12px;
}

.calendar__auth {
  height: calc(100% - 52px);
  padding: 37px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: var(--muted);
  text-align: center;
}

.calendar__auth > span {
  width: 58px;
  height: 58px;
  border-radius: 18px;
  display: grid;
  place-items: center;
  background: var(--elevated);
  color: var(--accent);
}

.calendar__auth h1 {
  margin: 14px 0 5px;
  color: var(--label);
  font-size: 22px;
}

.calendar__auth p {
  margin: 0;
  font-size: 12px;
  line-height: 1.5;
}

.calendar__detail,
.calendar__form {
  position: absolute;
  inset: 0;
  padding-top: 47px;
  background: var(--bg);
}

.calendar__sheet-header {
  height: 60px;
  padding: 0 16px;
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  align-items: center;
  border-bottom: 1px solid var(--line);
  background: var(--bg);
  background: color-mix(in srgb, var(--bg) 82%, transparent);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
}

.calendar__sheet-header button {
  padding: 6px 0;
  display: flex;
  align-items: center;
  background: transparent;
  color: var(--accent);
  font-size: 14px;
  font-weight: 600;
}

.calendar__sheet-header button:last-child {
  justify-self: end;
}

.calendar__sheet-header button:disabled {
  opacity: 0.4;
}

.calendar__sheet-action {
  width: 68px;
  height: 38px;
  padding: 0 12px;
  border-radius: 9999px;
  color: var(--accent);
  font-size: 13px;
  font-weight: 700;
}

.calendar__sheet-header > strong {
  font-size: 15px;
}

.calendar__sheet-scroll {
  height: calc(100% - 60px);
  padding: 20px 16px 48px;
  overflow-y: auto;
  scrollbar-width: none;
}

.calendar__detail-title {
  padding: 9px 5px 18px;
  display: grid;
  grid-template-columns: 9px 1fr;
  gap: 10px;
}

.calendar__detail-title > i {
  width: 9px;
  height: 9px;
  margin-top: 7px;
  border-radius: 50%;
  background: var(--accent);
}

.calendar__detail-title h1 {
  margin: 0;
  font-size: 29px;
  line-height: 1.12;
}

.calendar__detail-title span {
  display: block;
  margin-top: 5px;
  color: var(--accent);
  font-size: 13px;
}

.calendar__group {
  margin-bottom: 13px;
  border-radius: 12px;
  overflow: hidden;
  background: var(--elevated);
}

.calendar__group-row {
  min-height: 58px;
  padding: 13px 15px;
  display: flex;
  align-items: center;
  gap: 9px;
  border-bottom: 1px solid var(--line);
  font-size: 13px;
}

.calendar__group-row:last-child {
  border-bottom: 0;
}

.calendar__group-row > svg {
  flex: none;
  color: var(--accent);
}

.calendar__group-row > span {
  flex: 1;
}

.calendar__group-row > strong {
  color: var(--muted);
  font-size: 12px;
  font-weight: 500;
}

.calendar__group-row--tall {
  align-items: flex-start;
}

.calendar__group-row--tall div {
  min-width: 0;
}

.calendar__group-row--tall small,
.calendar__group-row--tall strong,
.calendar__group-row--tall span {
  display: block;
}

.calendar__group-row--tall small {
  color: var(--muted);
  font-size: 11px;
}

.calendar__group-row--tall strong {
  margin-top: 2px;
  font-size: 14px;
}

.calendar__group-row--tall span {
  margin-top: 3px;
  color: var(--accent);
  font-size: 13px;
}

.calendar__group-row--note {
  align-items: flex-start;
}

.calendar__group-row--note p {
  margin: 0;
  color: var(--label);
  font-size: 13px;
  line-height: 1.45;
  white-space: pre-wrap;
}

.calendar__delete {
  width: 100%;
  min-height: 58px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  background: var(--elevated);
  color: var(--accent) !important;
  font-size: 14px !important;
}

.calendar__share {
  color: #0a84ff !important;
}

.calendar__group--fields input,
.calendar__group--fields textarea {
  width: 100%;
  box-sizing: border-box;
  outline: 0;
  background: transparent;
}

.calendar__group--fields > input {
  height: 56px;
  padding: 0 12px;
  border-bottom: 1px solid var(--line);
  font-size: 18px;
}

.calendar__group--fields > textarea {
  height: 88px;
  padding: 14px;
  resize: none;
  font-size: 14px;
  line-height: 1.4;
}

.calendar__date-time-row {
  width: 100%;
  min-height: 58px;
  padding: 0 15px;
  border-bottom: 1px solid var(--line) !important;
  display: grid;
  grid-template-columns: 1fr auto 18px;
  align-items: center;
  gap: 10px;
  background: transparent;
  font-size: 13px;
  text-align: left;
}

.calendar__all-day-row {
  min-height: 58px;
  padding: 0 15px;
  border-bottom: 1px solid var(--line);
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  color: var(--label);
  font-size: 13px;
}

.calendar__date-time-row span {
  min-width: 0;
}

.calendar__date-time-row strong {
  color: var(--accent);
  font-size: 14px;
  font-variant-numeric: tabular-nums;
}

.calendar__date-time-row svg {
  color: var(--muted);
}

.calendar__form-row {
  width: 100%;
  min-height: 58px;
  padding: 0 15px;
  display: flex;
  align-items: center;
  gap: 8px;
  border-bottom: 1px solid var(--line) !important;
  background: transparent;
  font-size: 13px;
  text-align: left;
}

.calendar__form-row > svg:first-child {
  flex: none;
  color: var(--accent);
}

.calendar__form-row > span {
  flex: 1;
}

.calendar__form-row > strong {
  color: var(--muted);
  font-size: 12px;
  font-weight: 500;
}

.calendar__form-row > svg:last-child {
  color: var(--muted);
  transition: transform 0.18s ease;
}

.calendar__form-row > svg:last-child.open {
  transform: rotate(90deg);
}

.calendar__reminders {
  padding-left: 35px;
  background: var(--field);
}

.calendar__reminders button {
  width: 100%;
  min-height: 48px;
  padding: 0 11px 0 0;
  border-bottom: 1px solid var(--line) !important;
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: transparent;
  color: var(--muted);
  font-size: 12px;
  text-align: left;
}

.calendar__reminders button.active {
  color: var(--accent);
}

.calendar__error {
  margin: 3px 5px 0;
  color: var(--accent);
  font-size: 12px;
  line-height: 1.4;
}

.calendar__picker-backdrop {
  position: absolute;
  z-index: 30;
  inset: 0;
  display: flex;
  align-items: flex-end;
  background: rgb(0 0 0 / 52%);
  backdrop-filter: blur(4px);
  -webkit-backdrop-filter: blur(4px);
}

.calendar__time-picker {
  width: 100%;
  padding: 0 14px 31px;
  border: 1px solid var(--line);
  border-bottom: 0;
  border-radius: 28px 28px 0 0;
  overflow: hidden;
  background: var(--elevated);
  background: color-mix(in srgb, var(--elevated) 94%, transparent);
  box-shadow: 0 -18px 60px rgb(0 0 0 / 38%);
  backdrop-filter: blur(30px) saturate(180%);
  -webkit-backdrop-filter: blur(30px) saturate(180%);
}

.calendar__time-picker > header {
  height: 62px;
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  align-items: center;
  border-bottom: 1px solid var(--line);
}

.calendar__time-picker > header strong {
  font-size: 16px;
}

.calendar__time-picker > header button {
  padding: 10px 0;
  background: transparent;
  color: var(--accent);
  font-size: 14px;
  font-weight: 650;
}

.calendar__time-picker > header button:last-child {
  justify-self: end;
}

.calendar__date-picker-month {
  height: 58px;
  display: grid;
  grid-template-columns: 40px 1fr 40px;
  align-items: center;
  gap: 10px;
}

.calendar__date-picker-month > strong {
  color: var(--label);
  font-size: 18px;
  text-align: center;
  text-transform: capitalize;
}

.calendar__date-picker-month > button {
  width: 38px;
  height: 38px;
  padding: 0;
  border-radius: 9999px;
  display: grid;
  place-items: center;
  background: var(--color-ios-dark-glass);
  color: var(--accent);
  box-shadow: var(--shadow-ios-dark-glass);
}

.calendar--light .calendar__date-picker-month > button {
  background: var(--color-ios-light-glass);
  box-shadow: var(--shadow-ios-light-glass);
}

.calendar__date-picker-weekdays,
.calendar__date-picker-grid {
  display: grid;
  grid-template-columns: repeat(7, minmax(0, 1fr));
  align-items: center;
}

.calendar__date-picker-weekdays {
  height: 28px;
  color: var(--muted);
  font-size: 11px;
  font-weight: 700;
  text-align: center;
  text-transform: uppercase;
}

.calendar__date-picker-grid {
  gap: 4px 0;
}

.calendar__date-picker-grid button,
.calendar__date-picker-grid > span {
  width: 38px;
  height: 38px;
  justify-self: center;
}

.calendar__date-picker-grid button {
  padding: 0;
  border-radius: 9999px;
  display: grid;
  place-items: center;
  background: transparent;
  color: var(--label);
  font-size: 14px;
  font-variant-numeric: tabular-nums;
  font-weight: 650;
}

.calendar__date-picker-grid button.today {
  box-shadow: inset 0 0 0 1px var(--accent);
  color: var(--accent);
}

.calendar__date-picker-grid button.selected {
  background: var(--accent);
  color: #fff;
  box-shadow: none;
  font-weight: 800;
}

.calendar__time-preview {
  height: 64px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--label);
  font-size: 34px;
  font-variant-numeric: tabular-nums;
  font-weight: 720;
  letter-spacing: -1px;
}

.calendar__time-preview span {
  margin: 0 5px;
  color: var(--accent);
}

.calendar__time-wheels {
  position: relative;
  height: 232px;
  display: grid;
  grid-template-columns: 1fr 28px 1fr;
  align-items: center;
  overflow: hidden;
  mask-image: linear-gradient(
    to bottom,
    transparent,
    #000 25%,
    #000 75%,
    transparent
  );
}

.calendar__time-wheels > strong {
  position: relative;
  z-index: 2;
  color: var(--accent);
  font-size: 28px;
  text-align: center;
}

.calendar__time-wheels > i {
  position: absolute;
  z-index: 0;
  top: 87px;
  right: 0;
  left: 0;
  height: 58px;
  border-top: 1px solid var(--line);
  border-bottom: 1px solid var(--line);
  border-radius: 14px;
  background: rgb(255 255 255 / 7%);
  pointer-events: none;
}

.calendar--light .calendar__time-wheels > i {
  background: rgb(0 0 0 / 5%);
}

.calendar__time-column {
  position: relative;
  z-index: 1;
  height: 232px;
  padding: 87px 4px;
  overflow-y: auto;
  scroll-snap-type: y mandatory;
  scrollbar-width: none;
}

.calendar__time-column::-webkit-scrollbar {
  display: none;
}

.calendar__time-column button {
  width: 100%;
  height: 58px;
  padding: 0;
  scroll-snap-align: center;
  background: transparent;
  color: var(--muted);
  font-size: 23px;
  font-variant-numeric: tabular-nums;
  font-weight: 560;
  transition:
    color 0.16s ease,
    transform 0.16s ease;
}

.calendar__time-column button.selected {
  color: var(--label);
  font-size: 27px;
  font-weight: 750;
  transform: scale(1.06);
}

.calendar-popover-enter-active,
.calendar-popover-leave-active,
.calendar-search-enter-active,
.calendar-search-leave-active {
  transition:
    opacity 0.16s ease,
    transform 0.16s ease;
}

.calendar-popover-enter-from,
.calendar-popover-leave-to {
  opacity: 0;
  transform: translateY(-5px) scale(0.96);
}

.calendar-search-enter-from,
.calendar-search-leave-to {
  opacity: 0;
  transform: translateY(-58px);
}

.calendar-picker-enter-active,
.calendar-picker-leave-active {
  transition: opacity 0.22s ease;
}

.calendar-picker-enter-active .calendar__time-picker,
.calendar-picker-leave-active .calendar__time-picker {
  transition: transform 0.26s cubic-bezier(0.22, 1, 0.36, 1);
}

.calendar-picker-enter-from,
.calendar-picker-leave-to {
  opacity: 0;
}

.calendar-picker-enter-from .calendar__time-picker,
.calendar-picker-leave-to .calendar__time-picker {
  transform: translateY(100%);
}

.calendar__agenda > header span,
.calendar__list-group > header span {
  font-size: 13px;
}

.calendar__event-time strong {
  font-size: 13px;
}

.calendar__event-time small,
.calendar__event-copy small {
  font-size: 12px;
  line-height: 1.35;
}

.calendar__empty-copy {
  font-size: 13px;
}
</style>
