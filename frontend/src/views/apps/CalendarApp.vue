<script setup lang="ts">
import {
  Bell,
  CalendarDays,
  Check,
  ChevronLeft,
  ChevronRight,
  Clock3,
  FileText,
  Pencil,
  Plus,
  Trash2,
  UserRound,
  X,
} from 'lucide-vue-next'
import { computed, onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'

import { useAccountStore } from '@/stores/account'
import { useCalendarStore } from '@/stores/calendar'
import { usePhoneStore } from '@/stores/phone'
import type { CalendarEvent, CalendarEventDraft } from '@/types/calendar'

type CalendarScreen = 'main' | 'detail' | 'form'

const reminderOptions = [null, 0, 10, 30, 60, 1440] as const
const router = useRouter()
const phone = usePhoneStore()
const account = useAccountStore()
const calendar = useCalendarStore()
const today = new Date()
const visibleMonth = ref(new Date(today.getFullYear(), today.getMonth(), 1))
const selectedDate = ref(dateKey(today))
const selectedEvent = ref<CalendarEvent | null>(null)
const editingEvent = ref<CalendarEvent | null>(null)
const screen = ref<CalendarScreen>('main')
const reminderOpen = ref(false)
const saving = ref(false)
const formError = ref('')
const draft = reactive({
  date: selectedDate.value,
  endTime: '10:00',
  note: '',
  reminderMinutes: 60 as number | null,
  startTime: '09:00',
  title: '',
})

function dateKey(value: Date | number): string {
  const date = new Date(value)
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

function timeValue(value: number): string {
  const date = new Date(value)
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`
}

function combineDateAndTime(date: string, time: string): number {
  const [year, month, day] = date.split('-').map(Number)
  const [hour, minute] = time.split(':').map(Number)
  return new Date(year, month - 1, day, hour, minute).getTime()
}

function addDays(value: Date, amount: number): Date {
  return new Date(value.getFullYear(), value.getMonth(), value.getDate() + amount)
}

function calendarGridStart(month: Date): Date {
  const first = new Date(month.getFullYear(), month.getMonth(), 1)
  const mondayOffset = (first.getDay() + 6) % 7
  return addDays(first, -mondayOffset)
}

const isAuthenticated = computed(() => account.email !== '')
const monthLabel = computed(() =>
  new Intl.DateTimeFormat(phone.lang, {
    month: 'long',
    year: 'numeric',
  }).format(visibleMonth.value),
)
const weekdayLabels = computed(() => {
  const monday = new Date(2026, 0, 5)
  return Array.from({ length: 7 }, (_, index) =>
    new Intl.DateTimeFormat(phone.lang, { weekday: 'narrow' }).format(
      addDays(monday, index),
    ),
  )
})
const monthDays = computed(() => {
  const start = calendarGridStart(visibleMonth.value)
  return Array.from({ length: 42 }, (_, index) => addDays(start, index))
})
const selectedEvents = computed(() =>
  calendar.events
    .filter((event) => dateKey(event.startsAt) === selectedDate.value)
    .sort((left, right) => left.startsAt - right.startsAt),
)
const selectedDateLabel = computed(() =>
  new Intl.DateTimeFormat(phone.lang, {
    day: 'numeric',
    month: 'long',
    weekday: 'long',
  }).format(new Date(`${selectedDate.value}T12:00:00`)),
)

function hasEvents(day: Date): boolean {
  const key = dateKey(day)
  return calendar.events.some((event) => dateKey(event.startsAt) === key)
}

function formatTime(value: number): string {
  return new Intl.DateTimeFormat(phone.lang, {
    hour: '2-digit',
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

async function loadMonth(): Promise<void> {
  if (!isAuthenticated.value) {
    calendar.events = []
    return
  }
  const start = calendarGridStart(visibleMonth.value)
  await calendar.load(start.getTime(), addDays(start, 42).getTime())
}

async function moveMonth(amount: number): Promise<void> {
  visibleMonth.value = new Date(
    visibleMonth.value.getFullYear(),
    visibleMonth.value.getMonth() + amount,
    1,
  )
  selectedDate.value = dateKey(visibleMonth.value)
  await loadMonth()
}

function selectDay(day: Date): void {
  selectedDate.value = dateKey(day)
  if (day.getMonth() !== visibleMonth.value.getMonth()) {
    visibleMonth.value = new Date(day.getFullYear(), day.getMonth(), 1)
    void loadMonth()
  }
}

function resetDraft(event?: CalendarEvent): void {
  editingEvent.value = event ?? null
  draft.title = event?.title ?? ''
  draft.note = event?.note ?? ''
  draft.date = event ? dateKey(event.startsAt) : selectedDate.value
  draft.startTime = event ? timeValue(event.startsAt) : '09:00'
  draft.endTime = event ? timeValue(event.endsAt) : '10:00'
  draft.reminderMinutes = event?.reminderMinutes ?? 60
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

async function saveEvent(): Promise<void> {
  const startsAt = combineDateAndTime(draft.date, draft.startTime)
  const endsAt = combineDateAndTime(draft.date, draft.endTime)
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
  visibleMonth.value = new Date(startsAt)
  visibleMonth.value = new Date(
    visibleMonth.value.getFullYear(),
    visibleMonth.value.getMonth(),
    1,
  )
  await loadMonth()
  screen.value = 'main'
}

async function deleteEvent(): Promise<void> {
  if (!selectedEvent.value || !(await calendar.deleteEvent(selectedEvent.value.id))) {
    return
  }
  selectedEvent.value = null
  screen.value = 'main'
}

onMounted(loadMonth)
</script>

<template>
  <main class="calendar" :class="{ 'calendar--light': !phone.isDarkMode }">
    <template v-if="screen === 'main'">
      <header class="calendar__header">
        <button :aria-label="phone.t('Common.home')" type="button" @click="router.push('/')">
          <ChevronLeft :size="19" />
        </button>
        <div>
          <span>{{ phone.t('Apps.calendar.eyebrow') }}</span>
          <h1>{{ phone.t('Apps.calendar.name') }}</h1>
        </div>
        <button v-if="isAuthenticated" :aria-label="phone.t('Apps.calendar.newEvent')" type="button" @click="openCreate">
          <Plus :size="20" />
        </button>
        <span v-else />
      </header>

      <section v-if="!isAuthenticated" class="calendar__auth">
        <UserRound :size="43" />
        <h2>{{ phone.t('Apps.calendar.signInTitle') }}</h2>
        <p>{{ phone.t('Apps.calendar.signInBody') }}</p>
      </section>

      <div v-else class="calendar__content">
        <section class="calendar__month">
          <div class="calendar__month-nav">
            <button type="button" @click="moveMonth(-1)"><ChevronLeft :size="18" /></button>
            <strong>{{ monthLabel }}</strong>
            <button type="button" @click="moveMonth(1)"><ChevronRight :size="18" /></button>
          </div>
          <div class="calendar__weekdays">
            <span v-for="weekday in weekdayLabels" :key="weekday">{{ weekday }}</span>
          </div>
          <div class="calendar__grid">
            <button
              v-for="day in monthDays"
              :key="dateKey(day)"
              type="button"
              :class="{
                selected: dateKey(day) === selectedDate,
                today: dateKey(day) === dateKey(today),
                outside: day.getMonth() !== visibleMonth.getMonth(),
              }"
              @click="selectDay(day)"
            >
              <span>{{ day.getDate() }}</span>
              <i v-if="hasEvents(day)" />
            </button>
          </div>
        </section>

        <section class="calendar__agenda">
          <div class="calendar__agenda-title">
            <div>
              <small>{{ phone.t('Apps.calendar.schedule') }}</small>
              <h2>{{ selectedDateLabel }}</h2>
            </div>
            <span>{{ selectedEvents.length }}</span>
          </div>
          <div v-if="calendar.loading" class="calendar__empty">{{ phone.t('Common.loading') }}</div>
          <div v-else-if="!selectedEvents.length" class="calendar__empty">
            <CalendarDays :size="28" />
            <strong>{{ phone.t('Apps.calendar.noEvents') }}</strong>
            <span>{{ phone.t('Apps.calendar.noEventsBody') }}</span>
            <button type="button" @click="openCreate"><Plus :size="15" /> {{ phone.t('Apps.calendar.newEvent') }}</button>
          </div>
          <button
            v-for="event in selectedEvents"
            v-else
            :key="event.id"
            class="calendar__event"
            type="button"
            @click="openDetail(event)"
          >
            <span><b>{{ formatTime(event.startsAt) }}</b><small>{{ formatTime(event.endsAt) }}</small></span>
            <i />
            <div><strong>{{ event.title }}</strong><small>{{ event.note || reminderLabel(event.reminderMinutes) }}</small></div>
            <ChevronRight :size="16" />
          </button>
        </section>
      </div>
    </template>

    <section v-else-if="screen === 'detail' && selectedEvent" class="calendar__detail">
      <header>
        <button type="button" @click="screen = 'main'"><ChevronLeft :size="19" /></button>
        <strong>{{ phone.t('Apps.calendar.event') }}</strong>
        <button type="button" @click="openEdit"><Pencil :size="17" /></button>
      </header>
      <article>
        <span class="calendar__detail-icon"><CalendarDays :size="28" /></span>
        <small>{{ phone.t('Apps.calendar.appointment') }}</small>
        <h1>{{ selectedEvent.title }}</h1>
        <div class="calendar__detail-row">
          <Clock3 :size="18" />
          <span><small>{{ formatLongDate(selectedEvent.startsAt) }}</small><strong>{{ formatTime(selectedEvent.startsAt) }} – {{ formatTime(selectedEvent.endsAt) }}</strong></span>
        </div>
        <div class="calendar__detail-row">
          <Bell :size="18" />
          <span><small>{{ phone.t('Apps.calendar.reminder') }}</small><strong>{{ reminderLabel(selectedEvent.reminderMinutes) }}</strong></span>
        </div>
        <div v-if="selectedEvent.note" class="calendar__note">
          <FileText :size="18" />
          <p>{{ selectedEvent.note }}</p>
        </div>
        <button class="calendar__delete" type="button" @click="deleteEvent"><Trash2 :size="16" /> {{ phone.t('Apps.calendar.deleteEvent') }}</button>
      </article>
    </section>

    <section v-else class="calendar__form">
      <header>
        <button type="button" @click="screen = editingEvent ? 'detail' : 'main'"><X :size="19" /></button>
        <div><small>{{ editingEvent ? phone.t('Apps.calendar.editEvent') : phone.t('Apps.calendar.newEvent') }}</small><strong>{{ phone.t('Apps.calendar.details') }}</strong></div>
        <button :disabled="saving" type="button" @click="saveEvent"><Check :size="18" /></button>
      </header>
      <form @submit.prevent="saveEvent">
        <label>{{ phone.t('Apps.calendar.title') }}<input v-model="draft.title" maxlength="120" :placeholder="phone.t('Apps.calendar.titlePlaceholder')" /></label>
        <label>{{ phone.t('Apps.calendar.date') }}<input v-model="draft.date" type="date" /></label>
        <div class="calendar__time-row">
          <label>{{ phone.t('Apps.calendar.starts') }}<input v-model="draft.startTime" type="time" /></label>
          <label>{{ phone.t('Apps.calendar.ends') }}<input v-model="draft.endTime" type="time" /></label>
        </div>
        <label>{{ phone.t('Apps.calendar.reminder') }}</label>
        <div class="calendar__select">
          <button type="button" @click="reminderOpen = !reminderOpen"><Bell :size="16" /><span>{{ reminderLabel(draft.reminderMinutes) }}</span><ChevronRight :size="16" :class="{ open: reminderOpen }" /></button>
          <div v-if="reminderOpen">
            <button v-for="option in reminderOptions" :key="String(option)" type="button" :class="{ active: draft.reminderMinutes === option }" @click="draft.reminderMinutes = option; reminderOpen = false">
              {{ reminderLabel(option) }}<Check v-if="draft.reminderMinutes === option" :size="14" />
            </button>
          </div>
        </div>
        <label>{{ phone.t('Apps.calendar.note') }}<textarea v-model="draft.note" maxlength="2000" :placeholder="phone.t('Apps.calendar.notePlaceholder')" /></label>
        <p v-if="formError" class="calendar__error">{{ formError }}</p>
        <button class="calendar__save" :disabled="saving" type="submit">{{ saving ? phone.t('Common.loading') : phone.t('Common.save') }}</button>
      </form>
    </section>
  </main>
</template>

<style scoped>
.calendar{--accent:#ff4d5f;--panel:#20242c;--muted:#9da4af;position:absolute;inset:0;padding:47px 0 24px;overflow:hidden;background:#11151b;color:#f8f8f6;font-family:Inter,system-ui,sans-serif}.calendar--light{--panel:#f0f1f4;--muted:#747984;background:#fbfbfc;color:#191b20}.calendar button,.calendar input,.calendar textarea{font:inherit;color:inherit}.calendar button{border:0}.calendar__header{height:65px;padding:7px 14px;display:grid;grid-template-columns:36px 1fr 36px;align-items:center}.calendar__header>button,.calendar__detail>header button,.calendar__form>header>button{width:34px;height:34px;padding:0;border-radius:11px;display:grid;place-items:center;background:var(--panel)}.calendar__header>div{text-align:center}.calendar__header span,.calendar__form header small{display:block;color:var(--accent);font-size:8px;font-weight:900;letter-spacing:.1em;text-transform:uppercase}.calendar__header h1{margin:1px 0 0;font-size:23px;line-height:1}.calendar__content{height:calc(100% - 65px);padding:0 13px 19px;overflow-y:auto;scrollbar-width:none}.calendar__month{padding:11px 10px 9px;border-radius:17px;background:var(--panel);box-shadow:0 8px 24px #0002}.calendar__month-nav{height:31px;display:grid;grid-template-columns:32px 1fr 32px;align-items:center;text-align:center}.calendar__month-nav button{height:29px;padding:0;border-radius:9px;display:grid;place-items:center;background:#ffffff09}.calendar--light .calendar__month-nav button{background:#00000008}.calendar__month-nav strong{font-size:14px;text-transform:capitalize}.calendar__weekdays,.calendar__grid{display:grid;grid-template-columns:repeat(7,1fr)}.calendar__weekdays{padding:5px 0 3px;color:var(--muted);font-size:8px;font-weight:800;text-align:center}.calendar__grid button{height:31px;padding:1px;display:flex;flex-direction:column;align-items:center;background:none;color:inherit;font-size:10px}.calendar__grid button span{width:23px;height:23px;border-radius:50%;display:grid;place-items:center}.calendar__grid button.outside{opacity:.3}.calendar__grid button.today span{box-shadow:inset 0 0 0 1px var(--accent);color:var(--accent);font-weight:900}.calendar__grid button.selected span{background:var(--accent);color:#fff;box-shadow:none;font-weight:900}.calendar__grid button i{width:3px;height:3px;margin-top:1px;border-radius:50%;background:var(--accent)}.calendar__grid button.selected i{background:#fff}.calendar__agenda{padding:13px 1px 5px}.calendar__agenda-title{margin-bottom:9px;display:flex;align-items:end;justify-content:space-between}.calendar__agenda-title small{display:block;color:var(--accent);font-size:8px;font-weight:900;text-transform:uppercase}.calendar__agenda-title h2{margin:2px 0 0;font-size:16px;text-transform:capitalize}.calendar__agenda-title>span{min-width:24px;height:24px;border-radius:8px;display:grid;place-items:center;background:var(--panel);font-size:10px;font-weight:800}.calendar__empty{min-height:145px;padding:19px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:5px;border-radius:15px;background:var(--panel);color:var(--muted);text-align:center}.calendar__empty strong{color:inherit;font-size:13px}.calendar__empty span{max-width:220px;font-size:9px}.calendar__empty button{margin-top:4px;padding:8px 11px;border-radius:9px;display:flex;align-items:center;gap:4px;background:var(--accent);color:#fff;font-size:9px;font-weight:900}.calendar__event{width:100%;min-height:59px;margin-bottom:7px;padding:8px 9px;border-radius:13px;display:flex;align-items:center;gap:8px;background:var(--panel);text-align:left}.calendar__event>span{width:39px;text-align:right}.calendar__event b,.calendar__event small,.calendar__event strong{display:block}.calendar__event b{font-size:10px}.calendar__event small{color:var(--muted);font-size:8px}.calendar__event>i{width:3px;height:39px;border-radius:3px;background:var(--accent)}.calendar__event>div{min-width:0;flex:1}.calendar__event strong{overflow:hidden;font-size:11px;white-space:nowrap;text-overflow:ellipsis}.calendar__event div small{overflow:hidden;white-space:nowrap;text-overflow:ellipsis}.calendar__event>svg{color:var(--muted)}.calendar__auth{height:calc(100% - 65px);padding:35px;display:flex;flex-direction:column;align-items:center;justify-content:center;color:var(--muted);text-align:center}.calendar__auth svg{color:var(--accent)}.calendar__auth h2{margin:12px 0 4px;color:inherit;font-size:18px}.calendar__auth p{margin:0;font-size:10px;line-height:1.5}.calendar__detail,.calendar__form{position:absolute;inset:0;padding-top:47px;background:#11151b}.calendar--light .calendar__detail,.calendar--light .calendar__form{background:#fbfbfc}.calendar__detail>header,.calendar__form>header{height:54px;padding:6px 13px;display:grid;grid-template-columns:36px 1fr 36px;align-items:center;border-bottom:1px solid #ffffff12}.calendar__detail>header>strong{text-align:center;font-size:13px}.calendar__detail article{height:calc(100% - 54px);padding:22px 17px 35px;overflow-y:auto}.calendar__detail-icon{width:56px;height:56px;margin-bottom:13px;border-radius:17px;display:grid;place-items:center;background:linear-gradient(145deg,#ff7a67,var(--accent));color:white;box-shadow:0 9px 24px #ff405044}.calendar__detail article>small{color:var(--accent);font-size:8px;font-weight:900;text-transform:uppercase}.calendar__detail h1{margin:3px 0 20px;font-size:25px;line-height:1.12}.calendar__detail-row{margin-bottom:8px;padding:11px;border-radius:13px;display:flex;align-items:center;gap:10px;background:var(--panel)}.calendar__detail-row>svg{color:var(--accent)}.calendar__detail-row small,.calendar__detail-row strong{display:block}.calendar__detail-row small{color:var(--muted);font-size:8px}.calendar__detail-row strong{font-size:11px}.calendar__note{margin-top:14px;padding:13px;border-radius:13px;display:flex;align-items:flex-start;gap:9px;background:var(--panel)}.calendar__note svg{flex:none;color:var(--accent)}.calendar__note p{margin:0;color:var(--muted);font-size:10px;line-height:1.5;white-space:pre-wrap}.calendar__delete{width:100%;margin-top:18px;padding:10px;border-radius:11px;display:flex;align-items:center;justify-content:center;gap:5px;background:#ff4d5f1c;color:#ff6573;font-size:10px;font-weight:800}.calendar__form>header>div{text-align:center}.calendar__form header small,.calendar__form header strong{display:block}.calendar__form header strong{font-size:13px}.calendar__form>header>button:last-child{background:var(--accent);color:#fff}.calendar__form>form{height:calc(100% - 54px);padding:17px 15px 40px;overflow-y:auto}.calendar__form label{display:block;margin-bottom:13px;color:var(--muted);font-size:9px;font-weight:800}.calendar__form input,.calendar__form textarea{width:100%;margin-top:5px;padding:11px;border:1px solid #ffffff14;border-radius:11px;outline:0;background:var(--panel);font-size:12px}.calendar--light .calendar__form input,.calendar--light .calendar__form textarea{border-color:#00000010}.calendar__form textarea{height:104px;resize:none;line-height:1.45}.calendar__time-row{display:grid;grid-template-columns:1fr 1fr;gap:8px}.calendar__select{margin:-8px 0 13px;position:relative}.calendar__select>button{width:100%;padding:10px;border-radius:11px;display:flex;align-items:center;gap:8px;background:var(--panel);font-size:11px;text-align:left}.calendar__select>button span{flex:1}.calendar__select>button svg:first-child{color:var(--accent)}.calendar__select>button svg:last-child{transition:transform .18s}.calendar__select>button svg.open{transform:rotate(90deg)}.calendar__select>div{position:absolute;z-index:4;top:43px;right:0;left:0;padding:5px;border-radius:12px;background:#292e37;box-shadow:0 12px 35px #0008}.calendar--light .calendar__select>div{background:#fff}.calendar__select>div button{width:100%;padding:8px;border-radius:8px;display:flex;justify-content:space-between;background:none;font-size:10px;text-align:left}.calendar__select>div button.active{background:var(--accent);color:#fff}.calendar__error{margin:-4px 0 10px;color:#ff6976;font-size:9px}.calendar__save{width:100%;padding:11px;border-radius:11px;background:var(--accent);color:#fff!important;font-size:11px;font-weight:900}.calendar__save:disabled,.calendar__form>header>button:disabled{opacity:.45}
</style>
