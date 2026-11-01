<script setup lang="ts">
import {
  CarFront,
  Check,
  LocateFixed,
  MapPin,
  Minus,
  Navigation,
  Plus,
  RefreshCw,
} from 'lucide-vue-next'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'

import {
  defaultCayoStyle,
  defaultMainlandStyle,
  defaultMapCoordinates,
  defaultMapPercentToWorld,
  defaultMapWorldToPercent,
} from '@/features/map/defaultMapGeometry'
import { useKnowayStore } from '@/stores/knoway'
import { usePhoneStore } from '@/stores/phone'
import type {
  KnowayCoordinates,
  KnowayLocation,
  KnowayStateUpdate,
} from '@/types/knoway'
import { isKnowayRideTerminal } from '@/types/knoway'
import {
  SkyAppPage,
  SkyButton,
  SkyEmptyState,
  SkyNavbar,
  SkyScrollArea,
  SkySettingsGroup,
  SkySettingsRow,
  SkySpinner,
} from '@/ui'
import { isTrustedRootMessageSource } from '@/utils/windowMessages'

const phone = usePhoneStore()
const knoway = useKnowayStore()
const destination = ref<KnowayLocation | null>(null)
const currentLocation = ref<KnowayCoordinates | null>(null)
const mapViewport = ref<HTMLElement | null>(null)
const mapCanvas = ref<HTMLElement | null>(null)
const mapError = ref(false)
const locating = ref(false)
const now = ref(Date.now() / 1000)
const zoom = ref(1.6)
const pan = ref({ x: 0, y: 0 })
const baseWidth = 440
const aspect = defaultMapCoordinates.width / defaultMapCoordinates.height
const mapUrl = `${import.meta.env.BASE_URL}img/maps/gtav-map.svg`
const cayoUrl = `${import.meta.env.BASE_URL}img/maps/cayo-perico.svg`
let clock: number | undefined
let refreshTimer: number | undefined
let refreshPending = false
let pointer:
  | {
      id: number
      x: number
      y: number
      panX: number
      panY: number
      moved: boolean
    }
  | undefined

const ride = computed(() => knoway.activeRide)
const terminal = computed(
  () => !!ride.value && isKnowayRideTerminal(ride.value.status),
)
const pickup = computed(
  () =>
    ride.value?.pickup ??
    knoway.quote?.pickup ??
    (currentLocation.value
      ? {
          coords: currentLocation.value,
          label: phone.t('Apps.knoway.currentLocation'),
        }
      : null),
)
const selectedDestination = computed(
  () =>
    ride.value?.destination ?? knoway.quote?.destination ?? destination.value,
)
const quoteSeconds = computed(() =>
  Math.max(0, Math.ceil((knoway.quote?.expiresAt ?? 0) - now.value)),
)
const waitingSeconds = computed(() =>
  Math.max(0, Math.ceil((ride.value?.expiresAt ?? 0) - now.value)),
)
const canChooseDestination = computed(
  () => !knoway.hasActiveRide && !knoway.isActionPending,
)
const mapStyle = computed(() => ({
  width: `${baseWidth}px`,
  height: `${baseWidth / aspect}px`,
  transform: `translate(-50%, -50%) translate(${pan.value.x}px, ${pan.value.y}px) scale(${zoom.value})`,
}))
const errorText = computed(() => {
  if (!knoway.error) return ''
  const key = `Apps.knoway.errors.${knoway.error}`
  const text = phone.t(key)
  return text === key ? phone.t('Apps.knoway.errors.request_failed') : text
})
const refundText = computed(() => {
  const status = ride.value?.refundStatus
  if (!status || status === 'none') return ''
  if (status === 'refunded' || status === 'completed' || status === 'paid')
    return phone.t('Apps.knoway.refundCompleted')
  if (
    status === 'review' ||
    status === 'manual_review' ||
    status === 'uncertain'
  )
    return phone.t('Apps.knoway.refundReview')
  if (
    status === 'refund_pending' ||
    status === 'refund_processing' ||
    status === 'pending'
  )
    return phone.t('Apps.knoway.refundPending')
  return ''
})
const refundPolicy = computed(
  () =>
    ride.value?.refundPolicy ??
    knoway.quote?.refundPolicy ??
    knoway.refundPolicy,
)
const policyText = computed(() => {
  const afterStart =
    ride.value?.status === 'driving' || ride.value?.status === 'stopping'
  if (afterStart)
    return phone.t(
      refundPolicy.value.afterStart
        ? 'Apps.knoway.afterStartRefunded'
        : 'Apps.knoway.afterStartCharged',
    )
  return phone.t(
    refundPolicy.value.beforeStart
      ? 'Apps.knoway.beforeStartRefund'
      : 'Apps.knoway.beforeStartCharged',
  )
})

function money(value: number, currency: string): string {
  return `${new Intl.NumberFormat(phone.lang, { maximumFractionDigits: 2 }).format(value)} ${currency}`
}

function markerStyle(coords: KnowayCoordinates): Record<string, string> {
  const point = defaultMapWorldToPercent(coords)
  return {
    left: `${point.x * 100}%`,
    top: `${point.y * 100}%`,
    transform: `translate(-50%, -50%) scale(${1 / zoom.value})`,
  }
}

function centreMap(coords: KnowayCoordinates): void {
  const point = defaultMapWorldToPercent(coords)
  pan.value = {
    x: (0.5 - point.x) * baseWidth * zoom.value,
    y: (((0.5 - point.y) * baseWidth) / aspect) * zoom.value,
  }
}

function changeZoom(amount: number): void {
  const previous = zoom.value
  zoom.value = Math.min(8, Math.max(0.65, previous + amount))
  pan.value = {
    x: (pan.value.x * zoom.value) / previous,
    y: (pan.value.y * zoom.value) / previous,
  }
}

function selectPoint(x: number, y: number): void {
  if (!canChooseDestination.value || !mapCanvas.value) return
  const rect = mapCanvas.value.getBoundingClientRect()
  const percent = {
    x: (x - rect.left) / rect.width,
    y: (y - rect.top) / rect.height,
  }
  if (percent.x < 0 || percent.x > 1 || percent.y < 0 || percent.y > 1) return
  const coords = defaultMapPercentToWorld(percent)
  knoway.dismissRide()
  knoway.clearQuote()
  destination.value = {
    coords: { ...coords, z: 0 },
    label: phone.t('Apps.knoway.mapDestination'),
  }
}

function pointerDown(event: PointerEvent): void {
  if (event.button !== 0) return
  mapViewport.value?.setPointerCapture(event.pointerId)
  pointer = {
    id: event.pointerId,
    x: event.clientX,
    y: event.clientY,
    panX: pan.value.x,
    panY: pan.value.y,
    moved: false,
  }
}

function pointerMove(event: PointerEvent): void {
  if (!pointer || pointer.id !== event.pointerId) return
  const x = event.clientX - pointer.x
  const y = event.clientY - pointer.y
  if (Math.hypot(x, y) > 5) pointer.moved = true
  if (pointer.moved) pan.value = { x: pointer.panX + x, y: pointer.panY + y }
}

function pointerUp(event: PointerEvent): void {
  if (!pointer || pointer.id !== event.pointerId) return
  if (!pointer.moved) selectPoint(event.clientX, event.clientY)
  pointer = undefined
}

function mapKeydown(event: KeyboardEvent): void {
  const directions: Record<string, { x: number; y: number }> = {
    ArrowLeft: { x: 40, y: 0 },
    ArrowRight: { x: -40, y: 0 },
    ArrowUp: { x: 0, y: 40 },
    ArrowDown: { x: 0, y: -40 },
  }
  const direction = directions[event.key]
  if (direction) {
    event.preventDefault()
    pan.value = { x: pan.value.x + direction.x, y: pan.value.y + direction.y }
  } else if (event.key === 'Enter' || event.key === ' ') {
    event.preventDefault()
    const rect = mapViewport.value?.getBoundingClientRect()
    if (rect)
      selectPoint(rect.left + rect.width / 2, rect.top + rect.height / 2)
  }
}

async function locate(): Promise<void> {
  if (locating.value) return
  locating.value = true
  try {
    const response = await knoway.getLocation('player')
    if (response.success && response.data) {
      currentLocation.value = response.data.coords
      await nextTick()
      centreMap(response.data.coords)
    }
  } finally {
    locating.value = false
  }
}

async function useWaypoint(): Promise<void> {
  if (!canChooseDestination.value || locating.value) return
  locating.value = true
  try {
    const response = await knoway.getLocation('waypoint')
    if (response.success && response.data) {
      knoway.dismissRide()
      knoway.clearQuote()
      destination.value = {
        coords: response.data.coords,
        label: phone.t('Apps.knoway.gpsDestination'),
      }
      centreMap(response.data.coords)
    }
  } finally {
    locating.value = false
  }
}

function onMessage(event: MessageEvent): void {
  if (!isTrustedRootMessageSource(event.source, window)) return
  if (
    event.data?.type !== 'knoway:changed' ||
    !event.data.data ||
    typeof event.data.data !== 'object'
  )
    return
  knoway.applyUpdate(event.data.data as KnowayStateUpdate)
}

watch(
  () => `${ride.value?.id ?? ''}:${ride.value?.status ?? ''}`,
  async () => {
    await nextTick()
    mapViewport.value?.closest('.knoway-content')?.scrollTo({ top: 0 })
  },
)

onMounted(async () => {
  window.addEventListener('message', onMessage)
  clock = window.setInterval(() => {
    now.value = Date.now() / 1000
  }, 1000)
  refreshTimer = window.setInterval(async () => {
    if (!knoway.hasActiveRide || refreshPending) return
    refreshPending = true
    try {
      await knoway.refreshState()
    } finally {
      refreshPending = false
    }
  }, 2000)
  await knoway.bootstrap()
  if (ride.value) centreMap(ride.value.position ?? ride.value.pickup.coords)
  else await locate()
})

onBeforeUnmount(() => {
  window.removeEventListener('message', onMessage)
  if (clock !== undefined) window.clearInterval(clock)
  if (refreshTimer !== undefined) window.clearInterval(refreshTimer)
})
</script>

<template>
  <SkyAppPage
    class="knoway-app"
    :dark="phone.isDarkMode"
    :label="phone.t('Apps.knoway.name')"
    :accent="phone.isDarkMode ? '#0a84ff' : '#0066d6'"
    accent-soft="rgba(10, 132, 255, 0.15)"
  >
    <SkyNavbar
      variant="large"
      :title="phone.t('Apps.knoway.name')"
      :subtitle="phone.t('Apps.knoway.subtitle')"
    />
    <SkyScrollArea class="knoway-content" padded>
      <div
        v-if="knoway.isLoading && !knoway.hasLoaded"
        class="knoway-loading"
        role="status"
      >
        <SkySpinner />
        <p>{{ phone.t('Apps.knoway.loading') }}</p>
      </div>
      <SkyEmptyState
        v-else-if="!knoway.hasLoaded || (!knoway.available && !ride)"
        :title="phone.t('Apps.knoway.unavailable')"
        :body="errorText"
        compact
      >
        <template #icon><CarFront :size="32" /></template>
        <template #actions
          ><SkyButton variant="secondary" @click="knoway.bootstrap()"
            ><RefreshCw :size="18" />{{
              phone.t('Apps.knoway.refresh')
            }}</SkyButton
          ></template
        >
      </SkyEmptyState>
      <template v-else>
        <SkySettingsGroup
          v-if="ride"
          :footer="phone.t(`Apps.knoway.statusDescription.${ride.status}`)"
          aria-live="polite"
        >
          <SkySettingsRow :title="phone.t(`Apps.knoway.status.${ride.status}`)">
            <template #leading><CarFront :size="22" /></template>
          </SkySettingsRow>
        </SkySettingsGroup>

        <section
          class="knoway-map-section"
          :aria-label="phone.t('Apps.knoway.destinationLabel')"
        >
          <div
            ref="mapViewport"
            class="knoway-map"
            role="application"
            tabindex="0"
            :aria-label="phone.t('Apps.knoway.mapLabel')"
            data-testid="knoway-map"
            @pointerdown="pointerDown"
            @pointermove="pointerMove"
            @pointerup="pointerUp"
            @pointercancel="pointer = undefined"
            @keydown="mapKeydown"
            @wheel.prevent="changeZoom($event.deltaY < 0 ? 0.2 : -0.2)"
          >
            <div
              ref="mapCanvas"
              class="knoway-map-canvas"
              :style="mapStyle"
              aria-hidden="true"
            >
              <img
                class="knoway-map-layer"
                :style="defaultMainlandStyle"
                :src="mapUrl"
                alt=""
                draggable="false"
                @error="mapError = true"
              />
              <img
                class="knoway-map-layer"
                :style="defaultCayoStyle"
                :src="cayoUrl"
                alt=""
                draggable="false"
              />
              <span
                v-if="pickup"
                class="knoway-map-marker knoway-map-marker--pickup"
                :style="markerStyle(pickup.coords)"
                ><LocateFixed :size="19"
              /></span>
              <span
                v-if="selectedDestination"
                class="knoway-map-marker knoway-map-marker--destination"
                :style="markerStyle(selectedDestination.coords)"
                ><MapPin :size="20"
              /></span>
              <span
                v-if="ride?.position"
                class="knoway-map-marker knoway-map-marker--vehicle"
                :style="markerStyle(ride.position)"
                ><CarFront :size="21"
              /></span>
            </div>
            <span v-if="mapError" class="knoway-map-error">{{
              phone.t('Apps.knoway.errors.map_unavailable')
            }}</span>
          </div>
          <div class="knoway-map-tools">
            <SkyButton
              variant="plain"
              icon-only
              :aria-label="phone.t('Apps.knoway.zoomOut')"
              :disabled="zoom <= 0.65"
              @click="changeZoom(-0.4)"
              ><Minus :size="19"
            /></SkyButton>
            <SkyButton
              variant="plain"
              icon-only
              :aria-label="phone.t('Apps.knoway.zoomIn')"
              :disabled="zoom >= 8"
              @click="changeZoom(0.4)"
              ><Plus :size="19"
            /></SkyButton>
            <SkyButton
              class="knoway-locate"
              variant="plain"
              :disabled="locating"
              @click="locate"
              ><LocateFixed :size="18" />{{
                phone.t(
                  locating ? 'Apps.knoway.locating' : 'Apps.knoway.locate',
                )
              }}</SkyButton
            >
          </div>
        </section>

        <SkySettingsGroup
          :title="phone.t('Apps.knoway.destination')"
          :footer="phone.t('Apps.knoway.chooseOnMap')"
        >
          <SkySettingsRow
            :title="phone.t('Apps.knoway.pickup')"
            :value="pickup?.label ?? phone.t('Apps.knoway.currentLocation')"
          >
            <template #leading><LocateFixed :size="21" /></template>
          </SkySettingsRow>
          <SkySettingsRow
            :title="phone.t('Apps.knoway.destinationLabel')"
            :value="selectedDestination?.label ?? '—'"
          >
            <template #leading><MapPin :size="21" /></template>
          </SkySettingsRow>
          <SkySettingsRow
            v-if="!knoway.hasActiveRide && !terminal"
            kind="action"
            tone="accent"
            :title="phone.t('Apps.knoway.useWaypoint')"
            :disabled="!canChooseDestination || locating"
            @activate="useWaypoint"
          >
            <template #leading><Navigation :size="21" /></template>
          </SkySettingsRow>
        </SkySettingsGroup>

        <SkySettingsGroup
          v-if="knoway.quote || ride"
          :footer="
            knoway.quote
              ? quoteSeconds
                ? phone.t('Apps.knoway.quoteValidFor', {
                    seconds: String(quoteSeconds),
                  })
                : phone.t('Apps.knoway.quoteExpired')
              : ''
          "
        >
          <SkySettingsRow
            :title="phone.t('Apps.knoway.price')"
            :value="
              money(
                (ride ?? knoway.quote)!.price,
                (ride ?? knoway.quote)!.currency,
              )
            "
          />
          <SkySettingsRow
            :title="phone.t('Apps.knoway.distance')"
            :value="
              new Intl.NumberFormat(phone.lang, {
                maximumFractionDigits: 1,
              }).format((ride ?? knoway.quote)!.distanceMeters / 1000) +
              ' ' +
              phone.t('Apps.knoway.kilometerUnit')
            "
          />
          <SkySettingsRow
            :title="phone.t('Apps.knoway.duration')"
            :value="
              Math.max(
                1,
                Math.ceil((ride ?? knoway.quote)!.durationSeconds / 60),
              ) +
              ' ' +
              phone.t('Apps.knoway.minuteUnit')
            "
          />
        </SkySettingsGroup>

        <SkySettingsGroup
          v-if="ride"
          :footer="
            ride.status === 'waiting' && ride.expiresAt
              ? phone.t('Apps.knoway.waitingTime', {
                  seconds: String(waitingSeconds),
                })
              : ''
          "
        >
          <SkySettingsRow
            :title="phone.t('Apps.knoway.vehicle')"
            :value="ride.vehicle.plate"
          >
            <template #leading><CarFront :size="22" /></template>
          </SkySettingsRow>
          <SkySettingsRow
            v-if="refundText"
            :title="phone.t('Apps.knoway.refund')"
            :value="refundText"
          />
        </SkySettingsGroup>

        <p v-if="errorText" class="knoway-error" role="alert">
          {{ errorText }}
        </p>

        <div class="knoway-actions" :aria-busy="knoway.isActionPending">
          <template v-if="!ride">
            <SkyButton
              v-if="!knoway.quote || !quoteSeconds"
              block
              large
              :disabled="
                !selectedDestination ||
                knoway.isActionPending ||
                !knoway.available
              "
              @click="
                selectedDestination && knoway.createQuote(selectedDestination)
              "
              >{{ phone.t('Apps.knoway.quote') }}</SkyButton
            >
            <SkyButton
              v-else
              block
              large
              :disabled="knoway.isActionPending || !knoway.available"
              @click="knoway.requestRide()"
              >{{ phone.t('Apps.knoway.request') }} ·
              {{ money(knoway.quote.price, knoway.quote.currency) }}</SkyButton
            >
          </template>
          <template v-else-if="!terminal">
            <SkyButton
              v-if="ride.status === 'waiting'"
              block
              large
              :disabled="knoway.isActionPending"
              @click="knoway.performAction('start')"
              ><Navigation :size="18" />{{
                phone.t('Apps.knoway.start')
              }}</SkyButton
            >
            <SkyButton
              v-if="ride.status !== 'stopping'"
              variant="secondary"
              block
              :disabled="knoway.isActionPending"
              @click="knoway.performAction('cancel')"
              >{{
                phone.t(
                  ride.status === 'driving'
                    ? 'Apps.knoway.stop'
                    : 'Apps.knoway.cancel',
                )
              }}</SkyButton
            >
            <SkySpinner v-else />
          </template>
          <SkyButton
            v-else
            block
            large
            :disabled="!knoway.available"
            @click="knoway.dismissRide()"
            ><Check :size="18" />{{ phone.t('Apps.knoway.newRide') }}</SkyButton
          >
        </div>

        <p class="knoway-policy">{{ phone.t('Apps.knoway.passengers') }}</p>
        <p class="knoway-policy">
          {{ policyText }}
          {{
            phone.t(
              refundPolicy.technical
                ? 'Apps.knoway.technicalRefunded'
                : 'Apps.knoway.technicalCharged',
            )
          }}
        </p>
      </template>
    </SkyScrollArea>
  </SkyAppPage>
</template>

<style scoped>
.knoway-app {
  background: var(--sky-bg);
}
.knoway-content {
  display: flex;
  flex-direction: column;
  gap: var(--sky-space-4);
  padding-bottom: calc(var(--sky-space-6) + var(--sky-safe-area-bottom, 0px));
}
.knoway-content > * {
  flex-shrink: 0;
}

.knoway-loading {
  display: grid;
  min-height: 320px;
  place-content: center;
  justify-items: center;
  gap: var(--sky-space-3);
  color: var(--sky-muted);
}
.knoway-map-section {
  flex-shrink: 0;
  overflow: hidden;
  border-radius: var(--sky-radius-card);
  background: var(--sky-surface);
}
.knoway-map {
  position: relative;
  height: 256px;
  overflow: hidden;
  background: #2c6c7d;
  touch-action: none;
  cursor: crosshair;
}
.knoway-map:focus-visible {
  outline: 3px solid var(--sky-app-accent);
  outline-offset: -3px;
}
.knoway-map-canvas {
  position: absolute;
  left: 50%;
  top: 50%;
  transform-origin: center;
}
.knoway-map-layer {
  position: absolute;
  max-width: none;
  pointer-events: none;
  user-select: none;
}
.knoway-map-marker {
  position: absolute;
  z-index: 1;
  display: grid;
  width: 34px;
  height: 34px;
  place-content: center;
  border-radius: var(--sky-radius-pill);
  background: var(--sky-surface);
  color: var(--sky-text);
  box-shadow: 0 2px 7px rgba(0, 0, 0, 0.3);
}
.knoway-map-marker--pickup {
  background: #fff;
  color: #007aff;
}
.knoway-map-marker--destination {
  background: #007aff;
  color: #fff;
}
.knoway-map-marker--vehicle {
  background: #007aff;
  color: #fff;
}
.knoway-map-error {
  position: absolute;
  inset: 0;
  display: grid;
  place-content: center;
  padding: var(--sky-space-4);
  background: var(--sky-surface);
  color: var(--sky-text);
  text-align: center;
}
.knoway-map-tools {
  display: flex;
  gap: var(--sky-space-1);
  padding: var(--sky-space-2);
}
.knoway-map-tools .knoway-locate {
  margin-left: auto;
  min-width: 0;
  font-size: 13px;
}
.knoway-error {
  margin: 0;
  padding: var(--sky-space-3);
  border-radius: var(--sky-radius-control);
  background: var(--sky-danger-soft);
  color: var(--sky-text);
  font-size: 14px;
  line-height: 1.5;
}

.knoway-actions {
  display: grid;
  gap: var(--sky-space-2);
}
.knoway-actions :deep(.sky-button--primary),
.knoway-actions :deep(.sky-button--primary:active:not(:disabled)) {
  background: var(--sky-app-accent-shade);
}
.knoway-policy {
  margin: calc(-1 * var(--sky-space-2)) 0 0;
  color: var(--sky-muted);
  font-size: 12px;
  line-height: 1.5;
}
@media (max-width: 340px) {
  .knoway-map {
    height: 220px;
  }
}
</style>
