<script setup lang="ts">
import {
  kButton,
  kCard,
  kDialog,
  kDialogButton,
  kGlass,
  kLink,
  kNavbar,
  kPage,
  kPreloader,
  kSearchbar,
  kSegmented,
  kSegmentedButton,
  kSheet,
  kToast,
} from 'konsta/vue'
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
  X,
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

type GarageFilter = 'all' | GarageVehicleStatus

const phone = usePhoneStore()
const garage = useGarageStore()
const activeFilter = ref<GarageFilter>('all')
const query = ref('')
const selectedVehicle = ref<GarageVehicle | null>(null)
const valetCandidate = ref<GarageVehicle | null>(null)
const toastOpened = ref(false)
const toastText = ref('')

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

function updateSearch(event: Event): void {
  query.value = (event.target as HTMLInputElement).value
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
  <k-page component="main" class="garage-page !pt-[44px] !pb-[25px]">
    <k-navbar
      class="garage-navbar"
      :subtitle="phone.t('Apps.garage.subtitle')"
      :title="phone.t('Apps.garage.name')"
    />

    <div v-if="garage.isLoading && !garage.overview" class="garage-state">
      <k-preloader />
      <span>{{ phone.t('Common.loading') }}</span>
    </div>

    <div v-else-if="!garage.overview" class="garage-state">
      <span class="garage-state__icon"><Wrench :size="31" /></span>
      <strong>{{ phone.t('Apps.garage.unavailable') }}</strong>
      <p>{{ errorMessage() }}</p>
      <k-button rounded @click="garage.load()">
        {{ phone.t('Apps.garage.tryAgain') }}
      </k-button>
    </div>

    <div v-else class="garage-scroll">
      <k-glass class="garage-summary">
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
      </k-glass>

      <k-glass v-if="garage.valet" class="garage-valet-live">
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
        <k-button
          v-if="garage.valet.canCancel"
          clear
          rounded
          small
          :disabled="garage.isValetRequesting"
          @click="cancelValet"
        >
          {{ phone.t('Apps.garage.valet.cancel') }}
        </k-button>
      </k-glass>
      <k-searchbar
        class="garage-search"
        :placeholder="phone.t('Apps.garage.searchPlaceholder')"
        :value="query"
        @clear="query = ''"
        @input="updateSearch"
      />

      <k-segmented strong rounded class="garage-filters">
        <k-segmented-button
          v-for="filter in filters"
          :key="filter.id"
          :active="activeFilter === filter.id"
          @click="activeFilter = filter.id"
        >
          <span>{{ filter.label }}</span>
          <small>{{ filter.count }}</small>
        </k-segmented-button>
      </k-segmented>

      <section v-if="filteredVehicles.length" class="garage-vehicles">
        <k-glass
          v-for="vehicle in filteredVehicles"
          :key="vehicle.id"
          component="button"
          type="button"
          class="garage-vehicle"
          @click="selectedVehicle = vehicle"
        >
          <span class="garage-vehicle__visual" :class="`is-${vehicle.kind}`">
            <component :is="kindIcons[vehicle.kind]" :size="47" />
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
        </k-glass>
      </section>

      <k-card v-else class="garage-empty">
        <Warehouse :size="37" />
        <strong>{{
          query
            ? phone.t('Apps.garage.noResults')
            : phone.t('Apps.garage.noVehicles')
        }}</strong>
        <p>
          {{
            query
              ? phone.t('Apps.garage.noResultsBody')
              : phone.t('Apps.garage.noVehiclesBody')
          }}
        </p>
      </k-card>

      <p class="garage-provider">
        {{
          phone.t('Apps.garage.provider', { system: garage.overview.system })
        }}
      </p>
    </div>

    <k-sheet
      :opened="Boolean(selectedVehicle)"
      class="garage-sheet"
      @backdropclick="selectedVehicle = null"
    >
      <section v-if="selectedVehicle" class="garage-detail">
        <k-link
          component="button"
          icon-only
          class="garage-detail__close"
          :aria-label="phone.t('Common.close')"
          :link-props="{ type: 'button' }"
          @click="selectedVehicle = null"
        >
          <X :size="18" />
        </k-link>
        <span
          class="garage-detail__visual"
          :class="`is-${selectedVehicle.kind}`"
        >
          <component :is="kindIcons[selectedVehicle.kind]" :size="62" />
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
          <MapPin :size="18" />
          <span>
            <small>{{ phone.t('Apps.garage.location') }}</small>
            <strong>{{
              selectedVehicle.location || phone.t('Apps.garage.unknownLocation')
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
            <span><Gauge :size="17" />{{ phone.t('Apps.garage.engine') }}</span>
            <strong>{{ metricLabel(selectedVehicle.engine) }}</strong>
            <i><b :style="{ width: `${selectedVehicle.engine ?? 0}%` }" /></i>
          </article>
          <article>
            <span
              ><ShieldAlert :size="17" />{{ phone.t('Apps.garage.body') }}</span
            >
            <strong>{{ metricLabel(selectedVehicle.body) }}</strong>
            <i><b :style="{ width: `${selectedVehicle.body ?? 0}%` }" /></i>
          </article>
        </div>

        <k-glass
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
          <k-button
            large
            rounded
            :disabled="!canRequestValet(selectedVehicle)"
            @click="valetCandidate = selectedVehicle"
          >
            <CircleDollarSign :size="18" />
            {{ phone.t('Apps.garage.valet.deliver') }}
          </k-button>
        </k-glass>
        <div v-if="selectedVehicle.vin" class="garage-detail__vin">
          <small>{{ phone.t('Apps.garage.vin') }}</small>
          <strong>{{ selectedVehicle.vin }}</strong>
        </div>
      </section>
    </k-sheet>
    <k-dialog
      :opened="Boolean(valetCandidate)"
      class="garage-valet-confirm"
      @backdropclick="valetCandidate = null"
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
        <k-dialog-button @click="valetCandidate = null">
          {{ phone.t('Common.cancel') }}
        </k-dialog-button>
        <k-dialog-button
          strong
          :disabled="garage.isValetRequesting"
          @click="confirmValet"
        >
          {{
            garage.isValetRequesting
              ? phone.t('Apps.garage.valet.ordering')
              : phone.t('Apps.garage.valet.confirm')
          }}
        </k-dialog-button>
      </template>
    </k-dialog>

    <k-toast
      :opened="toastOpened"
      position="center"
      @click="toastOpened = false"
    >
      {{ toastText }}
    </k-toast>
  </k-page>
</template>

<style scoped>
.garage-page {
  --garage-blue: #2478ff;
  --garage-cyan: #52d7ff;
  --garage-background: #f2f2f7;
  --garage-surface: rgb(255 255 255 / 88%);
  --garage-surface-solid: #fff;
  --garage-surface-muted: #f7f7fa;
  --garage-text: #111114;
  --garage-secondary: #5f5f65;
  --garage-separator: rgb(60 60 67 / 13%);
  --garage-shadow: 0 1px 3px rgb(29 29 31 / 7%);
  position: relative;
  overflow: hidden;
  background: var(--garage-background) !important;
  color: var(--garage-text);
}
.garage-navbar {
  position: relative;
  z-index: 3;
  padding-top: max(24px, var(--k-safe-area-top)) !important;
  border-bottom: 0.5px solid var(--garage-separator);
  background: rgb(248 248 250 / 72%);
  backdrop-filter: saturate(180%) blur(24px);
  -webkit-backdrop-filter: saturate(180%) blur(24px);
}
.garage-scroll {
  position: relative;
  z-index: 1;
  height: calc(100% - 52px);
  padding: 12px 12px 32px;
  overflow-y: auto;
}
.garage-summary {
  padding: 16px;
  border: 0.5px solid rgb(255 255 255 / 75%);
  border-radius: 16px;
  background: var(--garage-surface) !important;
  box-shadow: var(--garage-shadow);
  color: var(--garage-text);
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
  border-radius: 14px;
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
  border-radius: 13px;
  border: 0.5px solid var(--garage-separator);
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
.garage-search > :deep(.k-glass) {
  overflow: hidden;
  border: 0.5px solid var(--garage-separator);
  background: rgb(118 118 128 / 12%) !important;
  box-shadow: none !important;
}
.garage-search :deep(input) {
  border: 0;
  background: transparent !important;
  color: var(--garage-text);
  font-size: 13px;
}
.garage-search :deep(input::placeholder) {
  color: var(--garage-secondary);
  opacity: 1;
}
.garage-filters {
  margin-bottom: 13px;
  padding: 2px;
  border: 0.5px solid var(--garage-separator);
  background: rgb(118 118 128 / 10%);
}
.garage-filters :deep(button) {
  min-width: 0;
  padding-right: 4px;
  padding-left: 4px;
  gap: 4px;
  font-size: 11px;
  font-weight: 600;
}
.garage-filters small {
  min-width: 17px;
  padding: 1px 4px;
  border-radius: 9px;
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
  border: 0.5px solid var(--garage-separator);
  border-radius: 15px;
  background: var(--garage-surface-solid) !important;
  box-shadow: var(--garage-shadow);
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
  border-right: 0.5px solid rgb(10 132 255 / 12%);
  background: #eaf3ff;
  color: #2671c9;
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
.garage-vehicle__visual > i {
  position: absolute;
  top: 7px;
  left: 50%;
  display: inline-flex;
  width: max-content;
  min-width: 48px;
  max-width: 70px;
  height: 14px;
  padding: 0 6px;
  align-items: center;
  justify-content: center;
  box-sizing: border-box;
  border-radius: 999px;
  background: rgb(20 92 48 / 78%);
  color: #fff;
  font-size: 7px;
  font-style: normal;
  font-weight: 720;
  line-height: 1;
  white-space: nowrap;
  text-transform: uppercase;
  letter-spacing: 0.02em;
  backdrop-filter: blur(12px);
  transform: translateX(-50%);
}
.garage-vehicle__visual > i.is-out {
  background: rgb(176 91 0 / 82%);
}
.garage-vehicle__visual > i.is-impounded {
  background: rgb(176 28 34 / 84%);
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
  border: 0.5px solid var(--garage-separator);
  border-radius: 5px;
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
.garage-provider {
  margin: 16px 0 0;
  color: var(--garage-secondary);
  font-size: 11px;
  text-align: center;
}
.garage-empty {
  margin: 25px 0 !important;
  padding: 28px 22px !important;
  background: var(--garage-surface-solid) !important;
  color: var(--garage-secondary);
  text-align: center;
}
.garage-empty svg {
  margin: 0 auto 12px;
  color: var(--garage-blue);
}
.garage-empty strong {
  display: block;
  color: var(--garage-text);
  font-size: 16px;
}
.garage-empty p {
  margin: 5px 0 0;
  font-size: 13px;
  line-height: 1.45;
}
.garage-state {
  height: calc(100% - 52px);
  padding: 30px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-direction: column;
  gap: 9px;
  color: var(--garage-secondary);
  text-align: center;
}
.garage-state__icon {
  width: 60px;
  height: 60px;
  display: grid;
  place-items: center;
  border-radius: 20px;
  background: rgb(36 120 255 / 12%);
  color: var(--garage-blue);
}
.garage-state strong {
  color: var(--garage-text);
  font-size: 18px;
}
.garage-state p {
  margin: 0 0 5px;
  font-size: 13px;
  line-height: 1.45;
}
.garage-detail {
  position: relative;
  padding: 12px 18px 28px;
  background: var(--garage-surface-solid);
  color: var(--garage-text);
  text-align: center;
}
.garage-detail__close {
  position: absolute;
  z-index: 2;
  top: 10px;
  right: 14px;
  width: 30px;
  height: 30px;
  padding: 0;
  display: grid;
  place-items: center;
  border-radius: 50%;
  background: rgb(118 118 128 / 12%);
  color: var(--garage-secondary);
}
.garage-detail__visual {
  width: 104px;
  height: 82px;
  margin: 4px auto 9px;
  display: grid;
  place-items: center;
  border-radius: 18px;
  background: #eaf3ff;
  color: #24518f;
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
  display: inline-flex;
  padding: 4px 9px;
  border-radius: 999px;
  background: rgb(52 199 89 / 13%);
  color: #21813b;
  font-size: 12px;
  font-weight: 720;
  text-transform: uppercase;
}
.garage-detail__status.is-out {
  background: rgb(255 159 10 / 14%);
  color: #b66500;
}
.garage-detail__status.is-impounded {
  background: rgb(255 69 58 / 13%);
  color: #c12922;
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
  border-radius: 16px;
  border: 0.5px solid rgb(10 132 255 / 12%);
  background: rgb(10 132 255 / 8%);
  color: var(--garage-blue);
  text-align: left;
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
  border-radius: 15px;
  border: 0.5px solid var(--garage-separator);
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
  border-radius: 3px;
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
  border: 0.5px solid rgb(10 132 255 / 22%);
  border-radius: 15px;
  background: var(--garage-surface-solid) !important;
  color: var(--garage-text);
}
.garage-valet-live__icon {
  width: 42px;
  height: 42px;
  display: grid;
  place-items: center;
  border-radius: 14px;
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
  border-radius: 3px;
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
  border: 0.5px solid rgb(10 132 255 / 18%);
  border-radius: 15px;
  background: var(--garage-surface-muted) !important;
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
  border-radius: 13px;
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
.garage-valet-confirm {
  border: 1px solid rgb(60 60 67 / 18%);
  background: rgb(250 250 252 / 98%) !important;
  box-shadow: 0 24px 70px rgb(0 0 0 / 32%);
  color: var(--garage-text);
}
.garage-valet-dialog > span {
  width: 48px;
  height: 48px;
  margin-bottom: 8px;
  display: grid;
  place-items: center;
  border-radius: 16px;
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
:global(.phone-app.dark .garage-valet-live) {
  background: var(--garage-surface-solid) !important;
}
:global(.phone-app.dark .garage-valet-offer) {
  background: var(--garage-surface-muted) !important;
}
:global(.phone-app.dark .garage-valet-confirm) {
  border-color: rgb(255 255 255 / 14%);
  background: rgb(28 28 30 / 98%) !important;
  box-shadow: 0 24px 70px rgb(0 0 0 / 72%);
  color: #f5f5f7;
}
@keyframes garage-valet-track {
  from {
    transform: translateX(-18%);
  }
  to {
    transform: translateX(155%);
  }
}
:global(.phone-app.dark .garage-page) {
  --garage-background: #000;
  --garage-surface: rgb(28 28 30 / 88%);
  --garage-surface-solid: #1c1c1e;
  --garage-surface-muted: #2c2c2e;
  --garage-text: #f5f5f7;
  --garage-secondary: #b4b4ba;
  --garage-separator: rgb(84 84 88 / 52%);
  --garage-shadow: 0 1px 3px rgb(0 0 0 / 28%);
  background: var(--garage-background) !important;
}
:global(.phone-app.dark .garage-navbar) {
  background: rgb(18 18 20 / 72%);
}
:global(.phone-app.dark .garage-summary),
:global(.phone-app.dark .garage-vehicle) {
  color: #f5f7fb;
}
:global(.phone-app.dark .garage-summary__heading strong),
:global(.phone-app.dark .garage-summary__stats b),
:global(.phone-app.dark .garage-vehicle__title strong),
:global(.phone-app.dark .garage-empty strong),
:global(.phone-app.dark .garage-state strong) {
  color: #f5f7fb;
}
:global(.phone-app.dark .garage-summary__stats span) {
  background: var(--garage-surface-muted);
}
:global(.phone-app.dark .garage-vehicle__title > b) {
  background: var(--garage-surface-muted);
}
:global(.phone-app.dark .garage-search > .k-glass) {
  background: rgb(118 118 128 / 24%) !important;
}
:global(.phone-app.dark .garage-search input) {
  background: transparent !important;
  color: var(--garage-text);
}
:global(.phone-app.dark .garage-filters) {
  background: rgb(118 118 128 / 24%);
}
:global(.phone-app.dark .garage-vehicle__visual) {
  border-color: rgb(10 132 255 / 18%);
  background: #17263a;
  color: #64aaff;
}
:global(.phone-app.dark .garage-vehicle__visual.is-bike) {
  background: #352445;
  color: #d3a4ff;
}
:global(.phone-app.dark .garage-vehicle__visual.is-boat) {
  background: #153740;
  color: #70e5f4;
}
:global(.phone-app.dark .garage-vehicle__visual.is-plane),
:global(.phone-app.dark .garage-vehicle__visual.is-helicopter) {
  background: #3d2d17;
  color: #ffd37a;
}
:global(.phone-app.dark .garage-detail) {
  color: #f5f7fb;
}
:global(.phone-app.dark .garage-detail__close) {
  background: rgb(118 118 128 / 28%);
  color: #d1d1d6;
}
:global(.phone-app.dark .garage-detail__location),
:global(.phone-app.dark .garage-metrics article) {
  background: var(--garage-surface-muted);
}
:global(.phone-app.dark .garage-detail__location strong),
:global(.phone-app.dark .garage-detail__vin strong) {
  color: #f5f7fb;
}
</style>
