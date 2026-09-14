<script setup lang="ts">
import {
  Bike,
  CarFront,
  CheckCircle2,
  Clock3,
  CircleDollarSign,
  Fuel,
  Gauge,
  MapPin,
  Navigation,
  Plane,
  Route,
  Sparkles,
  Sailboat,
  ShieldAlert,
  Warehouse,
  Wrench,
} from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

import { useGarageStore } from '@/stores/garage'
import { usePhoneStore } from '@/stores/phone'
import type {
  GarageVehicle,
  GarageVehicleKind,
  GarageVehicleStatus,
  GarageValetState,
} from '@/types/garage'
import { isTrustedRootMessageSource } from '@/utils/windowMessages'
import {
  SkyAppPage,
  SkyButton,
  SkyDialog,
  SkyDialogButton,
  SkyEmptyState,
  SkyGlass,
  SkyNavbar,
  SkyScrollArea,
  SkySearchbar,
  SkySegmented,
  SkySegmentedButton,
  SkySheet,
  SkySpinner,
  SkyNotification,
} from '@/ui'

type GarageFilter = 'all' | GarageVehicleStatus

const phone = usePhoneStore()
const garage = useGarageStore()
const activeFilter = ref<GarageFilter>('all')
const query = ref('')
const selectedVehicle = ref<GarageVehicle | null>(null)
const valetCandidate = ref<GarageVehicle | null>(null)
const toastOpened = ref(false)
const toastText = ref('')
const failedVehicleImages = ref<Record<string, true>>({})

const kindIcons: Record<GarageVehicleKind, typeof CarFront> = {
  bike: Bike,
  boat: Sailboat,
  car: CarFront,
  helicopter: Plane,
  plane: Plane,
}

const vehicles = computed(() => garage.overview?.vehicles ?? [])
const counts = computed(() => ({
  all: vehicles.value.length,
  garaged: vehicles.value.filter((vehicle) => vehicle.status === 'garaged')
    .length,
  impounded: vehicles.value.filter((vehicle) => vehicle.status === 'impounded')
    .length,
  out: vehicles.value.filter((vehicle) => vehicle.status === 'out').length,
}))
const filters = computed(() =>
  (['all', 'garaged', 'out', 'impounded'] as const).map((id) => ({
    count: counts.value[id],
    id,
    label: phone.t(`Apps.garage.filters.${id}`),
  })),
)
const filteredVehicles = computed(() => {
  const search = query.value.trim().toLocaleLowerCase(phone.lang)
  return vehicles.value.filter((vehicle) => {
    if (activeFilter.value !== 'all' && vehicle.status !== activeFilter.value) {
      return false
    }
    if (!search) return true
    return [
      displayName(vehicle),
      vehicle.model,
      vehicle.plate,
      vehicle.location,
      vehicle.nickname,
      vehicle.vin,
    ].some((value) =>
      String(value ?? '')
        .toLocaleLowerCase(phone.lang)
        .includes(search),
    )
  })
})

function displayName(vehicle: GarageVehicle): string {
  if (vehicle.nickname) return vehicle.nickname
  if (vehicle.name) return vehicle.name
  if (typeof vehicle.model === 'string' && vehicle.model) return vehicle.model
  return phone.t('Apps.garage.unknownVehicle')
}

function modelName(vehicle: GarageVehicle): string {
  if (vehicle.name && vehicle.nickname) return vehicle.name
  if (typeof vehicle.model === 'string' && vehicle.model) return vehicle.model
  return phone.t(`Apps.garage.kinds.${vehicle.kind}`)
}

function vehicleImageUrl(vehicle: GarageVehicle): string {
  if (failedVehicleImages.value[vehicle.id]) return ''
  return vehicle.imageUrl ?? ''
}

function useVehicleIcon(vehicle: GarageVehicle): void {
  failedVehicleImages.value = {
    ...failedVehicleImages.value,
    [vehicle.id]: true,
  }
}

function conditionValue(vehicle: GarageVehicle): number | null {
  const values = [vehicle.engine, vehicle.body].filter(
    (value): value is number => value !== null,
  )
  if (!values.length) return null
  return Math.round(
    values.reduce((sum, value) => sum + value, 0) / values.length,
  )
}

function metricLabel(value: number | null): string {
  return value === null ? phone.t('Apps.garage.notAvailable') : `${value}%`
}

function translatedError(error: string): string {
  const key = `Apps.garage.errors.${error}`
  const translated = phone.t(key)
  return translated === key ? phone.t('Apps.garage.errors.default') : translated
}

function errorMessage(): string {
  return translatedError(garage.error)
}

function formatPrice(value: number): string {
  return new Intl.NumberFormat(phone.lang, {
    currency: 'USD',
    maximumFractionDigits: 0,
    style: 'currency',
  }).format(value)
}

function canRequestValet(vehicle: GarageVehicle): boolean {
  return (
    Boolean(garage.overview?.valet.enabled) &&
    vehicle.status === 'garaged' &&
    Boolean(garage.overview?.valet.vehicleTypes[vehicle.kind]) &&
    !garage.valet
  )
}

function valetAvailability(vehicle: GarageVehicle): string {
  if (vehicle.status !== 'garaged') {
    return phone.t('Apps.garage.valet.unavailableStatus')
  }
  if (!garage.overview?.valet.vehicleTypes[vehicle.kind]) {
    return phone.t('Apps.garage.valet.unsupported')
  }
  if (garage.valet) return phone.t('Apps.garage.valet.activeOrder')
  return phone.t('Apps.garage.valet.body')
}

function statusDistance(): string {
  if (!garage.valet) return ''
  if (garage.valet.status === 'arriving') {
    return phone.t('Apps.garage.valet.arriving')
  }
  if (garage.valet.etaSeconds !== null) {
    return phone.t('Apps.garage.valet.eta', {
      seconds: String(Math.max(1, Math.round(garage.valet.etaSeconds))),
    })
  }
  if (garage.valet.distance !== null) {
    return phone.t('Apps.garage.valet.distance', {
      distance: String(Math.round(garage.valet.distance)),
    })
  }
  return phone.t('Apps.garage.valet.connecting')
}

async function confirmValet(): Promise<void> {
  const candidate = valetCandidate.value
  if (!candidate) return
  if (await garage.requestValet(candidate.plate)) {
    valetCandidate.value = null
    selectedVehicle.value = null
    return
  }
  toastText.value = translatedError(garage.valetError)
  toastOpened.value = true
}

async function cancelValet(): Promise<void> {
  if (await garage.cancelValet()) return
  toastText.value = translatedError(garage.valetError)
  toastOpened.value = true
}

function handleValetStatus(event: MessageEvent): void {
  if (!isTrustedRootMessageSource(event.source, window)) return
  if (event.data?.type !== 'garage:valet-status') return
  garage.setValetState((event.data.data as GarageValetState | null) ?? null)
}

onMounted(() => {
  void garage.load()
  void garage.syncValet()
  window.addEventListener('message', handleValetStatus)
})

onBeforeUnmount(() => {
  window.removeEventListener('message', handleValetStatus)
})
</script>

<template>
  <SkyAppPage
    class="garage-page"
    :label="phone.t('Apps.garage.name')"
    :dark="phone.isDarkMode"
    accent="#0a84ff"
    accent-soft="rgba(10, 132, 255, 0.15)"
  >
    <SkyNavbar
      class="garage-navbar"
      variant="large"
      :subtitle="phone.t('Apps.garage.subtitle')"
      :title="phone.t('Apps.garage.name')"
    />

    <div v-if="garage.isLoading && !garage.overview" class="garage-state">
      <SkySpinner />
      <span>{{ phone.t('Common.loading') }}</span>
    </div>

    <SkyEmptyState
      v-else-if="!garage.overview"
      class="garage-state"
      tone="danger"
      :title="phone.t('Apps.garage.unavailable')"
      :body="errorMessage()"
    >
      <template #icon><Wrench :size="31" /></template>
      <template #actions>
        <SkyButton rounded @click="garage.load()">
          {{ phone.t('Apps.garage.tryAgain') }}
        </SkyButton>
      </template>
    </SkyEmptyState>

    <SkyScrollArea v-else padded class="garage-scroll">
      <SkyGlass class="garage-summary">
        <div class="garage-summary__heading">
          <span>
            <small>{{ phone.t('Apps.garage.myVehicles') }}</small>
            <strong>{{ counts.all }}</strong>
          </span>
          <i><CarFront :size="27" /></i>
        </div>
        <div class="garage-summary__stats">
          <span>
            <i class="is-garaged" />
            <b>{{ counts.garaged }}</b>
            {{ phone.t('Apps.garage.filters.garaged') }}
          </span>
          <span>
            <i class="is-out" />
            <b>{{ counts.out }}</b>
            {{ phone.t('Apps.garage.filters.out') }}
          </span>
          <span>
            <i class="is-impounded" />
            <b>{{ counts.impounded }}</b>
            {{ phone.t('Apps.garage.filters.impounded') }}
          </span>
        </div>
      </SkyGlass>

      <SkyGlass v-if="garage.valet" class="garage-valet-live">
        <div class="garage-valet-live__icon">
          <Navigation v-if="garage.valet.status !== 'delivered'" :size="24" />
          <CheckCircle2 v-else :size="24" />
        </div>
        <div class="garage-valet-live__body">
          <small>{{ phone.t('Apps.garage.valet.liveEyebrow') }}</small>
          <strong>{{ garage.valet.vehicleName }}</strong>
          <span>
            {{ phone.t(`Apps.garage.valet.status.${garage.valet.status}`) }}
            · {{ statusDistance() }}
          </span>
          <div class="garage-valet-live__track"><i /></div>
        </div>
        <SkyButton
          v-if="garage.valet.canCancel"
          clear
          rounded
          small
          :disabled="garage.isValetRequesting"
          @click="cancelValet"
        >
          {{ phone.t('Apps.garage.valet.cancel') }}
        </SkyButton>
      </SkyGlass>
      <SkySearchbar
        v-model="query"
        class="garage-search"
        :clear-label="phone.t('Common.clear')"
        :placeholder="phone.t('Apps.garage.searchPlaceholder')"
      />

      <SkySegmented
        strong
        rounded
        class="garage-filters"
        :aria-label="phone.t('Apps.garage.filtersLabel')"
      >
        <SkySegmentedButton
          v-for="filter in filters"
          :key="filter.id"
          :active="activeFilter === filter.id"
          @click="activeFilter = filter.id"
        >
          <span>{{ filter.label }}</span>
          <small>{{ filter.count }}</small>
        </SkySegmentedButton>
      </SkySegmented>

      <section v-if="filteredVehicles.length" class="garage-vehicles">
        <SkyGlass
          v-for="vehicle in filteredVehicles"
          :key="vehicle.id"
          component="button"
          type="button"
          class="garage-vehicle"
          @click="selectedVehicle = vehicle"
        >
          <span class="garage-vehicle__visual" :class="`is-${vehicle.kind}`">
            <img
              v-if="vehicleImageUrl(vehicle)"
              :src="vehicleImageUrl(vehicle)"
              :alt="displayName(vehicle)"
              loading="lazy"
              @error="useVehicleIcon(vehicle)"
            />
            <component v-else :is="kindIcons[vehicle.kind]" :size="47" />
            <i :class="`is-${vehicle.status}`">
              {{ phone.t(`Apps.garage.status.${vehicle.status}`) }}
            </i>
          </span>
          <span class="garage-vehicle__content">
            <span class="garage-vehicle__title">
              <span>
                <strong>{{ displayName(vehicle) }}</strong>
                <small>{{ modelName(vehicle) }}</small>
              </span>
              <b>{{ vehicle.plate }}</b>
            </span>
            <span class="garage-vehicle__meta">
              <span
                ><MapPin :size="13" />{{
                  vehicle.location || phone.t('Apps.garage.unknownLocation')
                }}</span
              >
              <span v-if="conditionValue(vehicle) !== null"
                ><Gauge :size="13" />{{ conditionValue(vehicle) }}%</span
              >
            </span>
          </span>
        </SkyGlass>
      </section>

      <SkyEmptyState
        v-else
        compact
        class="garage-empty"
        :title="
          query
            ? phone.t('Apps.garage.noResults')
            : phone.t('Apps.garage.noVehicles')
        "
        :body="
          query
            ? phone.t('Apps.garage.noResultsBody')
            : phone.t('Apps.garage.noVehiclesBody')
        "
      >
        <template #icon><Warehouse :size="37" /></template>
      </SkyEmptyState>
    </SkyScrollArea>

    <div class="garage-sheet">
      <SkySheet
        :opened="Boolean(selectedVehicle)"
        :aria-label="selectedVehicle ? displayName(selectedVehicle) : undefined"
        swipe-to-close
        grabber-clickable
        :grabber-label="phone.t('Common.close')"
        @backdropclick="selectedVehicle = null"
        @escape="selectedVehicle = null"
        @grabberclick="selectedVehicle = null"
        @swipeclose="selectedVehicle = null"
      >
        <section v-if="selectedVehicle" class="garage-detail">
          <span
            class="garage-detail__visual"
            :class="`is-${selectedVehicle.kind}`"
          >
            <img
              v-if="vehicleImageUrl(selectedVehicle)"
              :src="vehicleImageUrl(selectedVehicle)"
              :alt="displayName(selectedVehicle)"
              @error="useVehicleIcon(selectedVehicle)"
            />
            <component
              v-else
              :is="kindIcons[selectedVehicle.kind]"
              :size="62"
            />
          </span>
          <span
            class="garage-detail__status"
            :class="`is-${selectedVehicle.status}`"
          >
            {{ phone.t(`Apps.garage.status.${selectedVehicle.status}`) }}
          </span>
          <h2>{{ displayName(selectedVehicle) }}</h2>
          <p>{{ modelName(selectedVehicle) }} · {{ selectedVehicle.plate }}</p>

          <div class="garage-detail__location">
            <i class="garage-detail__location-icon">
              <MapPin :size="17" />
            </i>
            <span>
              <small>{{ phone.t('Apps.garage.location') }}</small>
              <strong>{{
                selectedVehicle.location ||
                phone.t('Apps.garage.unknownLocation')
              }}</strong>
            </span>
          </div>

          <div class="garage-metrics">
            <article>
              <span><Fuel :size="17" />{{ phone.t('Apps.garage.fuel') }}</span>
              <strong>{{ metricLabel(selectedVehicle.fuel) }}</strong>
              <i><b :style="{ width: `${selectedVehicle.fuel ?? 0}%` }" /></i>
            </article>
            <article>
              <span
                ><Gauge :size="17" />{{ phone.t('Apps.garage.engine') }}</span
              >
              <strong>{{ metricLabel(selectedVehicle.engine) }}</strong>
              <i><b :style="{ width: `${selectedVehicle.engine ?? 0}%` }" /></i>
            </article>
            <article>
              <span
                ><ShieldAlert :size="17" />{{
                  phone.t('Apps.garage.body')
                }}</span
              >
              <strong>{{ metricLabel(selectedVehicle.body) }}</strong>
              <i><b :style="{ width: `${selectedVehicle.body ?? 0}%` }" /></i>
            </article>
          </div>

          <SkyGlass
            v-if="garage.overview?.valet.enabled"
            class="garage-valet-offer"
          >
            <div class="garage-valet-offer__top">
              <span><Sparkles :size="22" /></span>
              <div>
                <small>{{ phone.t('Apps.garage.valet.eyebrow') }}</small>
                <strong>{{ phone.t('Apps.garage.valet.title') }}</strong>
              </div>
              <b>{{ formatPrice(garage.overview?.valet.price ?? 0) }}</b>
            </div>
            <p>{{ valetAvailability(selectedVehicle) }}</p>
            <div class="garage-valet-offer__facts">
              <span
                ><Route :size="15" />{{
                  phone.t('Apps.garage.valet.tracked')
                }}</span
              >
              <span
                ><Clock3 :size="15" />{{
                  phone.t('Apps.garage.valet.onDemand')
                }}</span
              >
            </div>
            <SkyButton
              large
              rounded
              :disabled="!canRequestValet(selectedVehicle)"
              @click="valetCandidate = selectedVehicle"
            >
              <CircleDollarSign :size="18" />
              {{ phone.t('Apps.garage.valet.deliver') }}
            </SkyButton>
          </SkyGlass>
          <div v-if="selectedVehicle.vin" class="garage-detail__vin">
            <small>{{ phone.t('Apps.garage.vin') }}</small>
            <strong>{{ selectedVehicle.vin }}</strong>
          </div>
        </section>
      </SkySheet>
    </div>
    <SkyDialog
      :opened="Boolean(valetCandidate)"
      class="garage-valet-confirm"
      @backdropclick="valetCandidate = null"
      @escape="valetCandidate = null"
    >
      <template #title>{{
        phone.t('Apps.garage.valet.confirmTitle')
      }}</template>
      <div v-if="valetCandidate" class="garage-valet-dialog">
        <span><Sparkles :size="24" /></span>
        <p>
          {{
            phone.t('Apps.garage.valet.confirmBody', {
              price: formatPrice(garage.overview?.valet.price ?? 0),
              vehicle: displayName(valetCandidate),
            })
          }}
        </p>
        <small>
          {{
            phone.t('Apps.garage.valet.account', {
              account: garage.overview?.valet.account ?? 'bank',
            })
          }}
        </small>
      </div>
      <template #buttons>
        <SkyDialogButton @click="valetCandidate = null">
          {{ phone.t('Common.cancel') }}
        </SkyDialogButton>
        <SkyDialogButton
          strong
          :disabled="garage.isValetRequesting"
          @click="confirmValet"
        >
          {{
            garage.isValetRequesting
              ? phone.t('Apps.garage.valet.ordering')
              : phone.t('Apps.garage.valet.confirm')
          }}
        </SkyDialogButton>
      </template>
    </SkyDialog>

    <SkyNotification
      :opened="toastOpened"
      :text="toastText"
      @click="toastOpened = false"
    />
  </SkyAppPage>
</template>

<style scoped>
.garage-page {
  --garage-blue: var(--sky-app-accent);
  --garage-surface-muted: var(--sky-surface-muted);
  --garage-text: var(--sky-text);
  --garage-secondary: var(--sky-muted);
  --garage-separator: var(--sky-hairline);
}
.garage-navbar :deep(.sky-navbar__title-container > div) {
  transform: translateY(-30px);
}
.garage-scroll {
  padding-top: 0;
}
.garage-summary {
  padding: 16px;
  border-radius: var(--sky-radius-card);
}
.garage-summary__heading {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.garage-summary__heading > span {
  display: flex;
  flex-direction: column;
}
.garage-summary__heading small {
  color: var(--garage-secondary);
  font-size: 12px;
  font-weight: 650;
  text-transform: uppercase;
  letter-spacing: 0.07em;
}
.garage-summary__heading strong {
  margin-top: 2px;
  font-size: 35px;
  line-height: 1;
  letter-spacing: -0.05em;
}
.garage-summary__heading > i {
  width: 46px;
  height: 46px;
  display: grid;
  place-items: center;
  border-radius: var(--sky-radius-control);
  background: var(--garage-blue);
  color: #fff;
}
.garage-summary__stats {
  margin-top: 14px;
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 7px;
}
.garage-summary__stats span {
  min-width: 0;
  padding: 9px 7px;
  display: grid;
  grid-template-columns: 7px auto;
  align-items: center;
  column-gap: 5px;
  border-radius: var(--sky-radius-control);
  border: 1px solid var(--garage-separator);
  background: var(--garage-surface-muted);
  color: var(--garage-secondary);
  font-size: 11px;
  font-weight: 560;
}
.garage-summary__stats i {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: #34c759;
}
.garage-summary__stats i.is-out {
  background: #ff9f0a;
}
.garage-summary__stats i.is-impounded {
  background: #ff453a;
}
.garage-summary__stats b {
  color: var(--garage-text);
  font-size: 16px;
}
.garage-summary__stats span {
  grid-template-rows: auto auto;
}
.garage-summary__stats span > i {
  grid-row: 1 / 3;
}
.garage-search {
  margin: 13px 0 10px;
}
.garage-filters {
  height: 40px;
  min-height: 40px;
  margin-bottom: 13px;
  padding: 2px;
}
.garage-filters :deep(button) {
  min-width: 0;
  height: 36px;
  min-height: 36px;
  padding-right: 4px;
  padding-left: 4px;
  align-items: center;
  justify-content: center;
  gap: 4px;
  font-size: 11px;
  font-weight: 600;
  line-height: 1;
}
.garage-filters :deep(.sky-segmented__highlight) {
  top: 2px;
  bottom: 2px;
}
.garage-filters span,
.garage-filters small {
  height: 18px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  line-height: 1;
}
.garage-filters small {
  min-width: 17px;
  padding: 0 4px;
  border-radius: var(--sky-radius-pill);
  background: rgb(36 120 255 / 13%);
  font-size: 10px;
  font-weight: 700;
}
.garage-vehicles {
  display: flex;
  flex-direction: column;
  gap: 11px;
}
.garage-vehicle {
  width: 100%;
  min-height: 104px;
  padding: 0;
  overflow: hidden;
  display: flex;
  flex-direction: row;
  border-radius: var(--sky-radius-card);
  color: var(--garage-text);
  text-align: left;
  transition:
    transform 0.16s ease,
    opacity 0.16s ease;
}
.garage-vehicle:active {
  transform: scale(0.985);
  opacity: 0.82;
}
.garage-vehicle__visual {
  position: relative;
  width: 86px;
  min-width: 86px;
  min-height: 104px;
  display: grid;
  place-items: center;
  border-right: 1px solid var(--garage-separator);
  background: var(--sky-app-accent-soft);
  color: var(--garage-blue);
}
.garage-vehicle__visual.is-bike {
  background: #f2eaff;
  color: #57368e;
}
.garage-vehicle__visual.is-boat {
  background: #e3f8fb;
  color: #11546b;
}
.garage-vehicle__visual.is-plane,
.garage-vehicle__visual.is-helicopter {
  background: #fff4dd;
  color: #744914;
}
.garage-vehicle__visual > img,
.garage-detail__visual > img {
  width: 100%;
  height: 100%;
  display: block;
  object-fit: contain;
}
.garage-vehicle__visual > img {
  padding: 20px 7px 7px;
  box-sizing: border-box;
}
.garage-vehicle__visual > i {
  position: absolute;
  top: 7px;
  left: 50%;
  display: inline-grid;
  width: max-content;
  min-width: 48px;
  max-width: 70px;
  height: 16px;
  padding: 1px 6px 0;
  place-items: center;
  box-sizing: border-box;
  border-radius: var(--sky-radius-pill);
  background: var(--sky-success);
  color: #fff;
  font-size: 7px;
  font-style: normal;
  font-weight: 720;
  line-height: normal;
  white-space: nowrap;
  text-transform: uppercase;
  letter-spacing: 0.02em;
  transform: translateX(-50%);
}
.garage-vehicle__visual > i.is-out {
  background: var(--sky-warning);
}
.garage-vehicle__visual > i.is-impounded {
  background: var(--sky-danger);
}
.garage-vehicle__content {
  min-width: 0;
  flex: 1;
  padding: 14px 12px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.garage-vehicle__title {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 9px;
}
.garage-vehicle__title > span {
  min-width: 0;
  display: flex;
  flex-direction: column;
}
.garage-vehicle__title strong {
  overflow: hidden;
  color: var(--garage-text);
  font-size: 16px;
  font-weight: 740;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.garage-vehicle__title small {
  color: var(--garage-secondary);
  font-size: 12px;
  line-height: 1.25;
}
.garage-vehicle__title > b {
  flex: none;
  padding: 2px 5px;
  border: 1px solid var(--garage-separator);
  border-radius: var(--sky-radius-control);
  background: var(--garage-surface-muted);
  color: var(--garage-text);
  font-size: 8px;
  font-weight: 700;
  line-height: 1.2;
  letter-spacing: 0.02em;
}
.garage-vehicle__meta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  color: var(--garage-secondary);
  font-size: 12px;
  font-weight: 520;
}
.garage-vehicle__meta span {
  min-width: 0;
  display: flex;
  align-items: center;
  gap: 4px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.garage-empty {
  margin: var(--sky-space-5) 0;
}
.garage-state {
  min-height: 0;
  margin: 0 var(--sky-page-gutter) var(--sky-space-3);
  padding: var(--sky-space-6);
  flex: 1 1 auto;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-direction: column;
  gap: 9px;
  color: var(--garage-secondary);
  text-align: center;
}
.garage-detail {
  position: relative;
  padding: 6px 18px 28px;
  background: var(--sky-surface);
  color: var(--garage-text);
  text-align: center;
}
.garage-detail__visual {
  width: 104px;
  height: 82px;
  margin: 4px auto 9px;
  display: grid;
  place-items: center;
  border-radius: var(--sky-radius-card);
  background: var(--sky-app-accent-soft);
  color: var(--garage-blue);
}
.garage-detail__visual > img {
  padding: 7px;
  box-sizing: border-box;
}
.garage-detail__visual.is-bike {
  background: #f2eaff;
  color: #57368e;
}
.garage-detail__visual.is-boat {
  background: #e3f8fb;
  color: #11546b;
}
.garage-detail__visual.is-plane,
.garage-detail__visual.is-helicopter {
  background: #fff4dd;
  color: #744914;
}
.garage-detail__status {
  min-height: 24px;
  padding: 1px 10px 0;
  display: inline-grid;
  place-items: center;
  box-sizing: border-box;
  border-radius: var(--sky-radius-pill);
  background: var(--sky-success-soft);
  color: var(--sky-success);
  font-size: 12px;
  font-weight: 720;
  line-height: normal;
  text-transform: uppercase;
}
.garage-detail__status.is-out {
  background: var(--sky-warning-soft);
  color: var(--sky-warning);
}
.garage-detail__status.is-impounded {
  background: var(--sky-danger-soft);
  color: var(--sky-danger);
}
.garage-detail h2 {
  margin: 8px 0 1px;
  font-size: 22px;
  line-height: 1.1;
  letter-spacing: -0.03em;
}
.garage-detail > p {
  margin: 0;
  color: var(--garage-secondary);
  font-size: 14px;
  font-weight: 520;
}
.garage-detail__location {
  margin: 17px 0 11px;
  padding: 12px;
  display: flex;
  align-items: center;
  gap: 10px;
  border-radius: var(--sky-radius-card);
  border: 1px solid var(--sky-hairline);
  background: var(--sky-app-accent-soft);
  text-align: left;
}
.garage-detail__location-icon {
  width: 31px;
  height: 31px;
  flex: none;
  display: grid;
  place-items: center;
  border-radius: var(--sky-radius-control);
  background: var(--garage-blue);
  color: #fff;
  font-style: normal;
}
.garage-detail__location span {
  display: flex;
  flex-direction: column;
}
.garage-detail__location small {
  color: var(--garage-secondary);
  font-size: 12px;
  font-weight: 560;
}
.garage-detail__location strong {
  color: var(--garage-text);
  font-size: 15px;
}
.garage-metrics {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 7px;
}
.garage-metrics article {
  padding: 10px 8px;
  border-radius: var(--sky-radius-control);
  border: 1px solid var(--garage-separator);
  background: var(--garage-surface-muted);
  text-align: left;
}
.garage-metrics article > span {
  display: flex;
  align-items: center;
  gap: 4px;
  color: var(--garage-secondary);
  font-size: 12px;
  font-weight: 600;
}
.garage-metrics article > strong {
  margin: 5px 0 7px;
  display: block;
  font-size: 17px;
}
.garage-metrics article > i {
  height: 4px;
  display: block;
  overflow: hidden;
  border-radius: var(--sky-radius-pill);
  background: rgb(118 118 128 / 16%);
}
.garage-metrics article > i b {
  height: 100%;
  display: block;
  border-radius: inherit;
  background: var(--garage-blue);
}
.garage-detail__vin {
  margin-top: 11px;
  padding: 9px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-top: 1px solid rgb(60 60 67 / 10%);
  color: var(--garage-secondary);
  font-size: 12px;
  font-weight: 560;
}
.garage-detail__vin strong {
  color: var(--garage-text);
  font-size: 12px;
  letter-spacing: 0.04em;
}
.garage-valet-live {
  margin: 11px 0 13px;
  padding: 13px;
  display: grid;
  grid-template-columns: 42px minmax(0, 1fr) auto;
  align-items: center;
  gap: 10px;
  border-radius: var(--sky-radius-card);
}
.garage-valet-live__icon {
  width: 42px;
  height: 42px;
  display: grid;
  place-items: center;
  border-radius: var(--sky-radius-control);
  background: var(--garage-blue);
  color: white;
}
.garage-valet-live__body {
  min-width: 0;
  display: flex;
  flex-direction: column;
}
.garage-valet-live__body small,
.garage-valet-offer__top small {
  color: var(--garage-blue);
  font-size: 12px;
  font-weight: 760;
  letter-spacing: 0.01em;
}
.garage-valet-live__body strong {
  overflow: hidden;
  font-size: 15px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.garage-valet-live__body span {
  color: var(--garage-secondary);
  font-size: 11px;
}
.garage-valet-live__track {
  height: 3px;
  margin-top: 7px;
  overflow: hidden;
  border-radius: var(--sky-radius-pill);
  background: rgb(10 132 255 / 13%);
}
.garage-valet-live__track i {
  width: 42%;
  height: 100%;
  display: block;
  border-radius: inherit;
  background: var(--garage-blue);
  animation: garage-valet-track 1.4s ease-in-out infinite alternate;
}
.garage-valet-live :deep(button) {
  min-width: 0;
  padding: 5px 8px;
  font-size: 11px;
}
.garage-valet-offer {
  margin-top: 13px;
  padding: 14px;
  border-radius: var(--sky-radius-card);
  text-align: left;
}
.garage-valet-offer__top {
  display: grid;
  grid-template-columns: 40px minmax(0, 1fr) auto;
  align-items: center;
  gap: 9px;
}
.garage-valet-offer__top > span {
  width: 40px;
  height: 40px;
  display: grid;
  place-items: center;
  border-radius: var(--sky-radius-control);
  background: var(--garage-blue);
  color: #fff;
}
.garage-valet-offer__top > div {
  display: flex;
  flex-direction: column;
}
.garage-valet-offer__top strong {
  font-size: 16px;
}
.garage-valet-offer__top > b {
  color: var(--garage-blue);
  font-size: 16px;
}
.garage-valet-offer > p {
  margin: 10px 0;
  color: var(--garage-secondary);
  font-size: 14px;
  font-weight: 500;
  line-height: 1.45;
}
.garage-valet-offer__facts {
  margin-bottom: 11px;
  display: flex;
  gap: 12px;
  color: var(--garage-secondary);
  font-size: 12px;
  font-weight: 560;
}
.garage-valet-offer__facts span {
  display: inline-flex;
  align-items: center;
  gap: 4px;
}
.garage-valet-offer :deep(button) {
  width: 100%;
  min-height: 44px;
  gap: 7px;
  background: var(--garage-blue);
  font-size: 14px;
  font-weight: 650;
}
.garage-valet-offer :deep(button:disabled) {
  opacity: 0.65;
}
.garage-valet-dialog {
  display: flex;
  align-items: center;
  flex-direction: column;
  color: var(--garage-secondary);
  text-align: center;
}
.garage-valet-dialog > span {
  width: 48px;
  height: 48px;
  margin-bottom: 8px;
  display: grid;
  place-items: center;
  border-radius: var(--sky-radius-card);
  background: var(--garage-blue);
  color: #fff;
}
.garage-valet-dialog p {
  margin: 0;
  font-size: 12px;
  line-height: 1.45;
}
.garage-valet-dialog small {
  margin-top: 7px;
  color: var(--garage-blue);
  font-size: 11px;
}
@keyframes garage-valet-track {
  from {
    transform: translateX(-18%);
  }
  to {
    transform: translateX(155%);
  }
}
@media (prefers-reduced-motion: reduce) {
  .garage-valet-live__track i {
    animation: none;
    transform: none;
  }
}
.garage-page.sky-app-page--dark .garage-vehicle__visual {
  border-color: rgb(10 132 255 / 18%);
  background: #17263a;
  color: #64aaff;
}
.garage-page.sky-app-page--dark .garage-vehicle__visual.is-bike {
  background: #352445;
  color: #d3a4ff;
}
.garage-page.sky-app-page--dark .garage-vehicle__visual.is-boat {
  background: #153740;
  color: #70e5f4;
}
.garage-page.sky-app-page--dark .garage-vehicle__visual.is-plane,
.garage-page.sky-app-page--dark .garage-vehicle__visual.is-helicopter {
  background: #3d2d17;
  color: #ffd37a;
}
.garage-vehicle__visual > i {
  color: #17211b;
}
</style>
