<script setup lang="ts">
import {
  Banknote,
  Cloud,
  CloudFog,
  CloudLightning,
  CloudRain,
  CloudSun,
  MessageCircle,
  MoonStar,
  Pause,
  Phone,
  Play,
  SkipForward,
  Snowflake,
  Sun,
  WalletCards,
} from 'lucide-vue-next'
import { kBadge, kGlass } from 'konsta/vue'
import { computed, onBeforeUnmount, ref, type Component } from 'vue'
import { useRouter } from 'vue-router'

import {
  useBankService,
  useClockService,
  useContactsService,
  useMusicService,
  useWeatherService,
} from '@/services/widgetServices'
import { useCallsStore } from '@/stores/calls'
import { useMessagesStore } from '@/stores/messages'
import { usePhoneStore } from '@/stores/phone'
import type { WidgetInstance } from '@/types/widgets'
import type { WeatherConditionId } from '@/types/weather'
import { WIDGET_SPANS } from '@/utils/widgetLayout'

const props = withDefaults(
  defineProps<{
    editMode?: boolean
    instance: WidgetInstance
    interactive?: boolean
    preview?: boolean
  }>(),
  { editMode: false, interactive: true, preview: false },
)
const emit = defineEmits<{
  dragcancel: []
  dragend: [event: PointerEvent]
  dragmove: [event: PointerEvent]
  dragstart: [event: PointerEvent]
  menu: []
  remove: []
}>()

const phone = usePhoneStore()
const calls = useCallsStore()
const messages = useMessagesStore()
const router = useRouter()
const clock = useClockService()
const weather = useWeatherService()
const music = useMusicService()
const bank = useBankService()
const contactsService = useContactsService()
const isDragging = ref(false)
const dragOffset = ref({ x: 0, y: 0 })
const suppressClick = ref(false)
let holdTimer: number | undefined
let pointerStart = { x: 0, y: 0 }
let dragStartPage = 0
let dragPageWidth = 0

const weatherIcons: Record<WeatherConditionId, Component> = {
  sunny: Sun,
  clear: MoonStar,
  partly_cloudy: CloudSun,
  cloudy: Cloud,
  rain: CloudRain,
  thunder: CloudLightning,
  fog: CloudFog,
  snow: Snowflake,
}
const span = computed(() => WIDGET_SPANS[props.instance.size])
const placementStyle = computed(() =>
  props.preview
    ? undefined
    : {
        gridColumn: `${props.instance.column + 1} / span ${span.value.columns}`,
        gridRow: `${props.instance.row + 1} / span ${span.value.rows}`,
        translate: isDragging.value
          ? `${dragOffset.value.x}px ${dragOffset.value.y}px`
          : undefined,
        transform: isDragging.value
          ? `translateX(${(phone.currentPage - dragStartPage) * dragPageWidth}px) scale(1.035)`
          : undefined,
      },
)
const forecastHigh = computed(() =>
  weather.forecast.value?.hourly.length
    ? Math.max(
        ...weather.forecast.value.hourly.map((entry) => entry.temperature),
      )
    : null,
)
const forecastLow = computed(() =>
  weather.forecast.value?.hourly.length
    ? Math.min(
        ...weather.forecast.value.hourly.map((entry) => entry.temperature),
      )
    : null,
)
const weatherIcon = computed(
  () => weatherIcons[weather.forecast.value?.condition ?? 'partly_cloudy'],
)
const visibleHourlyWeather = computed(
  () => weather.forecast.value?.hourly.slice(0, 5) ?? [],
)
const balance = computed(() =>
  props.instance.settings.balanceSource === 'cash'
    ? bank.overview.value.cash
    : bank.overview.value.bank,
)
const favoriteContacts = computed(() => {
  const selected = props.instance.settings.contactIds ?? []
  const ordered = selected.length
    ? selected
        .map((id) =>
          contactsService.contacts.value.find((contact) => contact.id === id),
        )
        .filter((contact) => contact !== undefined)
    : contactsService.contacts.value
  return ordered.slice(0, props.instance.size === 'large' ? 6 : 4)
})
const visibleTransactions = computed(() =>
  bank.overview.value.transactions.slice(
    0,
    props.instance.size === 'large' ? 5 : 2,
  ),
)
const removeBadgeColors = {
  bg: 'bg-[#d1d1d6]',
  text: 'text-black',
}

function formatMoney(value: number): string {
  return `${bank.overview.value.currency}${new Intl.NumberFormat(phone.lang, {
    maximumFractionDigits: 0,
  }).format(value)}`
}

function avatar(name: string): string {
  return name.trim().charAt(0).toLocaleUpperCase(phone.lang) || '?'
}

function formatForecastHour(timestamp: number): string {
  return new Intl.DateTimeFormat(phone.lang, {
    hour: '2-digit',
    hourCycle: 'h23',
    minute: '2-digit',
  }).format(timestamp)
}

function clearHold(): void {
  if (holdTimer !== undefined) window.clearTimeout(holdTimer)
  holdTimer = undefined
}

function onPointerDown(event: PointerEvent): void {
  if (
    !props.interactive ||
    props.preview ||
    event.button !== 0 ||
    (event.target as HTMLElement).closest('[data-widget-control]')
  ) {
    return
  }
  pointerStart = { x: event.clientX, y: event.clientY }
  clearHold()
  if (props.editMode) {
    beginDrag(event)
    return
  }
  holdTimer = window.setTimeout(() => {
    suppressClick.value = true
    emit('menu')
    holdTimer = undefined
  }, 520)
}

function onPointerMove(event: PointerEvent): void {
  if (isDragging.value) {
    dragOffset.value = {
      x: event.clientX - pointerStart.x,
      y: event.clientY - pointerStart.y,
    }
    emit('dragmove', event)
    return
  }
  if (
    Math.hypot(event.clientX - pointerStart.x, event.clientY - pointerStart.y) >
    8
  ) {
    clearHold()
  }
}

function beginDrag(event: PointerEvent): void {
  dragStartPage = phone.currentPage
  dragPageWidth =
    (event.currentTarget as HTMLElement)
      .closest<HTMLElement>('.springboard-page')
      ?.getBoundingClientRect().width ?? 0
  isDragging.value = true
  window.addEventListener('pointermove', onPointerMove)
  window.addEventListener('pointerup', onPointerUp)
  window.addEventListener('pointercancel', cancelDrag)
  emit('dragstart', event)
}

function onPointerUp(event: PointerEvent): void {
  clearHold()
  if (!isDragging.value) return
  suppressClick.value = true
  emit('dragend', event)
  isDragging.value = false
  dragOffset.value = { x: 0, y: 0 }
  removeDragListeners()
}

function cancelDrag(): void {
  clearHold()
  if (!isDragging.value) return
  isDragging.value = false
  dragOffset.value = { x: 0, y: 0 }
  removeDragListeners()
  emit('dragcancel')
}

function removeDragListeners(): void {
  window.removeEventListener('pointermove', onPointerMove)
  window.removeEventListener('pointerup', onPointerUp)
  window.removeEventListener('pointercancel', cancelDrag)
}

function openWidget(): void {
  if (props.editMode || suppressClick.value || !props.interactive) {
    suppressClick.value = false
    return
  }
  const routes: Partial<Record<WidgetInstance['kind'], string>> = {
    clock: '/apps/clock',
    contacts: '/apps/phone',
    date: '/apps/calendar',
    transactions: '/apps/banking',
    wallet: '/apps/banking',
    weather: '/apps/weather',
  }
  const route = routes[props.instance.kind]
  if (route) {
    phone.setLaunchOrigin(null)
    void router.push(route)
  }
}

async function callContact(phoneNumber: string): Promise<void> {
  await calls.dial(phoneNumber)
  phone.setLaunchOrigin(null)
  void router.push('/apps/phone')
}

async function messageContact(phoneNumber: string): Promise<void> {
  await messages.openThread(phoneNumber)
  phone.setLaunchOrigin(null)
  void router.push('/apps/messages')
}

onBeforeUnmount(() => {
  clearHold()
  removeDragListeners()
})
</script>

<template>
  <div
    class="home-widget-shell"
    :class="[
      `home-widget-shell--${instance.size}`,
      {
        'home-widget-shell--dragging': isDragging,
        'home-widget-shell--editing': editMode,
        'home-widget-shell--preview': preview,
      },
    ]"
    :style="placementStyle"
    :data-widget-id="instance.id"
  >
    <k-glass
      component="article"
      class="home-widget"
      :class="`home-widget--${instance.kind}`"
      role="button"
      tabindex="0"
      @click="openWidget"
      @contextmenu.prevent
      @keydown.enter="openWidget"
      @pointercancel="cancelDrag"
      @pointerdown="onPointerDown"
      @pointerleave="isDragging || clearHold()"
      @pointermove="onPointerMove"
      @pointerup="onPointerUp"
    >
      <template v-if="instance.kind === 'clock'">
        <span class="widget-eyebrow">{{ clock.weekday.value }}</span>
        <strong class="widget-clock">{{ clock.time.value }}</strong>
        <small v-if="instance.settings.showDate !== false">{{
          clock.date.value
        }}</small>
      </template>

      <template v-else-if="instance.kind === 'date'">
        <span class="widget-date-month">{{ clock.month.value }}</span>
        <strong class="widget-date-day">{{ clock.day.value }}</strong>
        <small>{{ clock.weekday.value }}</small>
      </template>

      <template v-else-if="instance.kind === 'weather'">
        <div class="widget-weather-top">
          <div>
            <span class="widget-eyebrow">{{ weather.location.value }}</span>
            <strong>{{ weather.forecast.value?.temperature ?? '--' }}°</strong>
          </div>
          <component
            :is="weatherIcon"
            :size="instance.size === 'small' ? 30 : 40"
          />
        </div>
        <small>{{ weather.condition.value }}</small>
        <small v-if="instance.size !== 'small'" class="widget-weather-range">
          H: {{ forecastHigh ?? '--' }}° &nbsp; L: {{ forecastLow ?? '--' }}°
        </small>
        <div v-if="instance.size !== 'small'" class="widget-weather-hourly">
          <div v-for="hour in visibleHourlyWeather" :key="hour.timestamp">
            <time>{{ formatForecastHour(hour.timestamp) }}</time>
            <component :is="weatherIcons[hour.condition]" :size="21" />
            <strong>{{ hour.temperature }}°</strong>
          </div>
        </div>
      </template>

      <template v-else-if="instance.kind === 'music'">
        <div class="widget-album" aria-hidden="true">
          <span>SKY</span>
        </div>
        <div class="widget-music-copy">
          <strong>{{ music.current.value.title }}</strong>
          <small>{{ music.current.value.artist }}</small>
        </div>
        <div class="widget-music-controls" data-widget-control>
          <button
            type="button"
            :aria-label="
              phone.t(
                music.playing.value
                  ? 'Home.widgets.media.pause'
                  : 'Home.widgets.media.play',
              )
            "
            @click.stop="music.toggle"
          >
            <Pause v-if="music.playing.value" :size="20" fill="currentColor" />
            <Play v-else :size="20" fill="currentColor" />
          </button>
          <button
            type="button"
            :aria-label="phone.t('ControlCenter.next')"
            @click.stop="music.next"
          >
            <SkipForward :size="19" fill="currentColor" />
          </button>
        </div>
      </template>

      <template v-else-if="instance.kind === 'wallet'">
        <div class="widget-wallet-icon"><WalletCards :size="22" /></div>
        <span class="widget-eyebrow">{{
          phone.t(
            instance.settings.balanceSource === 'cash'
              ? 'Home.widgetSystem.wallet.cash'
              : 'Home.widgetSystem.wallet.bank',
          )
        }}</span>
        <strong class="widget-balance">{{ formatMoney(balance) }}</strong>
        <small>{{ bank.overview.value.playerName }}</small>
      </template>

      <template v-else-if="instance.kind === 'transactions'">
        <header class="widget-list-header">
          <span>{{ phone.t('Home.widgetSystem.transactions.name') }}</span>
          <Banknote :size="19" />
        </header>
        <button
          v-for="transaction in visibleTransactions"
          :key="transaction.id"
          type="button"
          class="widget-transaction"
          data-widget-control
          @click.stop="openWidget"
        >
          <span>
            <strong>{{ transaction.label }}</strong>
            <small>{{ transaction.reference }}</small>
          </span>
          <b
            :class="{
              positive:
                transaction.kind === 'deposit' ||
                transaction.kind === 'transfer_in',
            }"
            >{{
              transaction.kind === 'deposit' ||
              transaction.kind === 'transfer_in'
                ? '+'
                : '−'
            }}{{ formatMoney(transaction.amount) }}</b
          >
        </button>
      </template>

      <template v-else-if="instance.kind === 'contacts'">
        <header class="widget-list-header">
          <span>{{ phone.t('Home.widgetSystem.contacts.name') }}</span>
        </header>
        <div class="widget-contacts">
          <article v-for="contact in favoriteContacts" :key="contact.id">
            <span class="widget-contact-avatar">{{
              avatar(contact.name)
            }}</span>
            <strong>{{ contact.name }}</strong>
            <div data-widget-control>
              <button
                type="button"
                :aria-label="phone.t('Apps.messages.call')"
                @click.stop="callContact(contact.phone_number)"
              >
                <Phone :size="15" fill="currentColor" />
              </button>
              <button
                type="button"
                :aria-label="phone.t('Apps.messages.messageAction')"
                @click.stop="messageContact(contact.phone_number)"
              >
                <MessageCircle :size="15" fill="currentColor" />
              </button>
            </div>
          </article>
        </div>
      </template>
    </k-glass>

    <button
      v-if="editMode && !preview"
      class="home-widget-remove"
      type="button"
      :aria-label="phone.t('Home.widgetSystem.remove')"
      @click.stop="emit('remove')"
      @pointerdown.stop
    >
      <k-badge :colors="removeBadgeColors">−</k-badge>
    </button>
  </div>
</template>

<style scoped>
.home-widget-shell {
  position: relative;
  z-index: 2;
  min-width: 0;
  min-height: 0;
  transition:
    transform 0.32s cubic-bezier(0.32, 0.72, 0, 1),
    opacity 0.2s ease;
}

.home-widget-shell--dragging {
  z-index: 40;
  opacity: 0.86;
  transition:
    transform var(--springboard-page-duration) var(--springboard-page-easing),
    opacity 0.2s ease;
  pointer-events: none;
}

.home-widget-shell--editing:not(.home-widget-shell--dragging) {
  animation: widget-wobble 0.17s ease-in-out infinite alternate;
}

.home-widget-shell--preview {
  width: 100%;
  aspect-ratio: 2 / 1;
}

.home-widget-shell--preview.home-widget-shell--small {
  max-width: 150px;
  aspect-ratio: 1;
}

.home-widget-shell--preview.home-widget-shell--large {
  aspect-ratio: 1;
}

.home-widget {
  width: 100%;
  height: 100%;
  padding: 15px;
  overflow: hidden;
  border: 0.75px solid rgb(255 255 255 / 17%);
  border-radius: 25px;
  outline: none;
  color: #fff;
  background: rgb(25 25 27 / 91%);
  box-shadow:
    0 10px 25px rgb(0 0 0 / 28%),
    inset 0 0.75px rgb(255 255 255 / 15%);
  backdrop-filter: blur(26px) saturate(125%);
  -webkit-backdrop-filter: blur(26px) saturate(125%);
  cursor: pointer;
  font-family:
    -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'SF Pro Text',
    'Segoe UI', sans-serif;
  user-select: none;
  -webkit-user-select: none;
  touch-action: none;
}

.home-widget-shell--small .home-widget {
  padding: 13px;
  border-radius: 23px;
}

.home-widget-shell--large .home-widget {
  padding: 18px;
  border-radius: 28px;
}

.home-widget:active {
  filter: brightness(1.08);
}

.home-widget small,
.widget-eyebrow {
  color: rgb(255 255 255 / 62%);
  font-size: 11px;
  font-weight: 500;
  line-height: 1.25;
}

.home-widget--clock,
.home-widget--date,
.home-widget--wallet {
  display: flex;
  align-items: flex-start;
  flex-direction: column;
  justify-content: flex-end;
}

.home-widget--clock {
  background: rgb(12 12 13 / 94%);
}

.widget-clock {
  margin: 2px 0;
  font-size: 28px;
  font-weight: 500;
  letter-spacing: -1.8px;
  line-height: 1;
  white-space: nowrap;
}

.home-widget-shell--medium .widget-clock {
  font-size: 48px;
}

.home-widget--date {
  background: rgb(24 24 26 / 94%);
  color: #fff;
}

.home-widget--date small {
  color: rgb(255 255 255 / 58%);
}

.widget-date-month {
  color: #ff3b30;
  font-size: 12px;
  font-weight: 700;
  text-transform: uppercase;
}

.widget-date-day {
  font-size: 52px;
  font-weight: 400;
  letter-spacing: -2px;
  line-height: 0.95;
}

.home-widget--weather {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  background: rgb(34 42 78 / 95%);
}

.widget-weather-top {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
}

.widget-weather-top > div {
  display: flex;
  flex-direction: column;
}

.widget-weather-top strong {
  font-size: 38px;
  font-weight: 400;
  letter-spacing: -1.5px;
  line-height: 1;
}

.widget-weather-range {
  margin-top: 3px;
  color: rgb(255 255 255 / 86%) !important;
  font-weight: 600 !important;
}

.widget-weather-hourly {
  display: grid;
  margin-top: 12px;
  padding-top: 11px;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  border-top: 0.5px solid rgb(255 255 255 / 18%);
}

.widget-weather-hourly > div {
  display: grid;
  min-width: 0;
  justify-items: center;
  gap: 6px;
}

.widget-weather-hourly time {
  color: rgb(255 255 255 / 58%);
  font-size: 9px;
  font-weight: 600;
}

.widget-weather-hourly strong {
  font-size: 12px;
  font-weight: 650;
}

.home-widget-shell--medium .home-widget--weather {
  padding: 13px 15px;
}

.home-widget-shell--medium .widget-weather-top strong {
  font-size: 32px;
}

.home-widget-shell--medium .widget-weather-hourly {
  margin-top: 7px;
  padding-top: 7px;
}

.home-widget-shell--medium .widget-weather-hourly > div {
  gap: 3px;
}

.home-widget-shell--medium .widget-weather-hourly svg {
  width: 18px;
  height: 18px;
}

.home-widget-shell--medium .widget-weather-hourly time {
  font-size: 8px;
}

.home-widget-shell--medium .widget-weather-hourly strong {
  font-size: 11px;
}

.home-widget--music {
  display: grid;
  align-items: center;
  grid-template-columns: auto minmax(0, 1fr) auto;
  gap: 12px;
  background: rgb(25 25 28 / 94%);
}

.home-widget-shell--large .home-widget--music {
  align-content: center;
  grid-template-columns: 1fr;
  text-align: center;
}

.widget-album {
  display: grid;
  width: 58px;
  height: 58px;
  place-items: center;
  border-radius: 14px;
  color: #fff;
  background: #5653b8;
  box-shadow:
    inset 0 0 0 0.5px rgb(255 255 255 / 25%),
    0 5px 13px rgb(0 0 0 / 24%);
  font-size: 13px;
  font-weight: 800;
  letter-spacing: 1.5px;
}

.home-widget-shell--large .widget-album {
  width: 118px;
  height: 118px;
  margin: 0 auto;
  border-radius: 24px;
  font-size: 20px;
}

.widget-music-copy {
  display: flex;
  min-width: 0;
  flex-direction: column;
}

.widget-music-copy strong,
.widget-music-copy small {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.widget-music-copy strong {
  font-size: 13px;
}

.widget-music-controls {
  display: flex;
  align-items: center;
  gap: 5px;
}

.widget-music-controls button,
.widget-contacts button {
  display: grid;
  width: 32px;
  height: 32px;
  place-items: center;
  border: 0;
  border-radius: 50%;
  color: #fff;
  background: rgb(255 255 255 / 11%);
}

.home-widget--wallet {
  background: rgb(25 26 29 / 94%);
}

.widget-wallet-icon {
  position: absolute;
  top: 13px;
  right: 13px;
  display: grid;
  width: 36px;
  height: 36px;
  place-items: center;
  border-radius: 11px;
  color: #64d2ff;
  background: rgb(100 210 255 / 13%);
}

.widget-balance {
  margin: 2px 0;
  font-size: 30px;
  font-weight: 650;
  letter-spacing: -1.2px;
}

.home-widget--transactions,
.home-widget--contacts {
  display: flex;
  flex-direction: column;
}

.home-widget--transactions {
  background: rgb(29 29 31 / 94%);
}

.home-widget--contacts {
  background: rgb(25 26 29 / 94%);
}

.widget-list-header {
  display: flex;
  margin-bottom: 7px;
  align-items: center;
  justify-content: space-between;
  color: #64d2ff;
  font-size: 13px;
  font-weight: 700;
}

.home-widget--transactions .widget-list-header {
  color: #30d158;
}

.widget-transaction {
  display: flex;
  min-height: 43px;
  padding: 5px 0;
  align-items: center;
  justify-content: space-between;
  border: 0;
  border-top: 0.5px solid rgb(255 255 255 / 11%);
  color: #fff;
  background: transparent;
  text-align: left;
}

.widget-transaction > span {
  display: flex;
  min-width: 0;
  flex-direction: column;
}

.widget-transaction strong {
  font-size: 12px;
  font-weight: 650;
}

.widget-transaction small {
  margin-top: 1px;
  font-size: 9px;
}

.widget-transaction b {
  color: #fff;
  font-size: 12px;
  font-weight: 600;
}

.widget-transaction b.positive {
  color: #30d158;
}

.widget-contacts {
  display: grid;
  flex: 1;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 7px;
}

.home-widget-shell--large .widget-contacts {
  grid-template-columns: repeat(3, minmax(0, 1fr));
  grid-template-rows: repeat(2, 1fr);
}

.widget-contacts article {
  display: flex;
  min-width: 0;
  align-items: center;
  flex-direction: column;
  justify-content: center;
  gap: 4px;
}

.widget-contact-avatar {
  display: grid;
  width: 38px;
  height: 38px;
  place-items: center;
  border-radius: 50%;
  color: #fff;
  background: #5e5ce6;
  box-shadow: inset 0 1px rgb(255 255 255 / 20%);
  font-size: 16px;
  font-weight: 650;
}

.widget-contacts article:nth-child(2n) .widget-contact-avatar {
  background: #ff9f0a;
}

.widget-contacts article:nth-child(3n) .widget-contact-avatar {
  background: #34c759;
}

.widget-contacts strong {
  max-width: 100%;
  overflow: hidden;
  font-size: 9px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.widget-contacts article > div {
  display: flex;
  gap: 3px;
}

.widget-contacts button {
  width: 25px;
  height: 25px;
  color: #64d2ff;
  background: rgb(100 210 255 / 12%);
}

.home-widget-remove {
  position: absolute;
  z-index: 8;
  top: -8px;
  left: -8px;
  display: grid;
  width: 25px;
  height: 25px;
  padding: 0;
  place-items: center;
  border: 0;
  border-radius: 50%;
  background: transparent;
}

.home-widget-remove :deep(.k-badge) {
  width: 23px;
  height: 23px;
  min-width: 23px;
  padding: 0;
  border: 0.5px solid rgb(255 255 255 / 55%);
  box-shadow: 0 1px 5px rgb(0 0 0 / 55%);
  font-size: 20px;
  font-weight: 400;
}

@keyframes widget-wobble {
  from {
    transform: rotate(-0.7deg) translateY(-0.5px);
  }
  to {
    transform: rotate(0.7deg) translateY(0.5px);
  }
}

@media (prefers-reduced-motion: reduce) {
  .home-widget-shell--editing {
    animation: none;
  }
}
</style>
