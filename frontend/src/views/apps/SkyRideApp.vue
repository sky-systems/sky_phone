<script setup lang="ts">
import {
  Bell,
  BriefcaseBusiness,
  Camera,
  CarFront,
  Check,
  CheckCircle2,
  ChevronRight,
  CircleUserRound,
  CircleDollarSign,
  Clock3,
  Crosshair,
  History,
  House,
  Images,
  MapPin,
  MessageCircle,
  Navigation,
  Phone,
  Pencil,
  Power,
  Route,
  ShieldCheck,
  Sparkles,
  Star,
  Trash2,
  UserRound,
  X,
} from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'

import { useCallsStore } from '@/stores/calls'
import { useMessageMediaStore } from '@/stores/messageMedia'
import { usePhoneStore } from '@/stores/phone'
import { useSkyRideStore } from '@/stores/skyride'
import type { PhoneMedia } from '@/types/media'
import type {
  SkyRideChangedMessage,
  SkyRideCustomFareInput,
  SkyRideDistanceUnit,
  SkyRideFareMode,
  SkyRideLocation,
  SkyRideMode,
  SkyRideQuoteOption,
  SkyRideRide,
  SkyRideRideStatus,
} from '@/types/skyride'
import { isTrustedRootMessageSource } from '@/utils/windowMessages'
import {
  SkyAppPage as kPage,
  SkyBadge as kBadge,
  SkyBlock as kBlock,
  SkyBlockHeader as kBlockHeader,
  SkyBlockTitle as kBlockTitle,
  SkyButton,
  SkyButton as kButton,
  SkyCard as kCard,
  SkyChip as kChip,
  SkyDialog as kDialog,
  SkyDialogButton as kDialogButton,
  SkyField,
  SkyField as kListInput,
  SkyLink as kLink,
  SkyList as kList,
  SkyListItem as kListItem,
  SkyNavbar as kNavbar,
  SkySegmented as kSegmented,
  SkySegmentedButton as kSegmentedButton,
  SkySettingsGroup,
  SkySettingsRow,
  SkySheet,
  SkySheet as kSheet,
  SkySpinner as kPreloader,
  SkyTabBar as kTabbar,
  SkyTabButton as kTabbarLink,
  SkyNotification as kNotification,
  SkyToggle as kToggle,
} from '@/ui'

type SkyRideTab = 'home' | 'rides' | 'activity' | 'messages' | 'profile'
type LocationTarget = 'pickup' | 'destination'
type ProfileMediaContext = {
  avatarMediaId: number
  name: string
  selectedAvatar: PhoneMedia | null
}

const phone = usePhoneStore()
const skyride = useSkyRideStore()
const calls = useCallsStore()
const messageMedia = useMessageMediaStore()
const router = useRouter()

const activeTab = ref<SkyRideTab>('home')
const mode = ref<SkyRideMode>('rider')
const pickup = ref<SkyRideLocation | null>(null)
const destination = ref<SkyRideLocation | null>(null)
const locationTarget = ref<LocationTarget | null>(null)
const selectedQuoteId = ref<string | null>(null)
const fareMode = ref<SkyRideFareMode>('calculated')
const customFareInput = ref('')
const cancelDialogOpened = ref(false)
const rating = ref(0)
const tip = ref(0)
const ratingComment = ref('')
const toastText = ref('')
const profileEditorOpened = ref(false)
const profileName = ref('')
const profileAvatarMediaId = ref(0)
const selectedProfileAvatar = ref<PhoneMedia | null>(null)
let toastTimer: number | undefined

const tabs = [
  { icon: House, id: 'home' as const },
  { icon: Route, id: 'rides' as const },
  { icon: Bell, id: 'activity' as const },
  { icon: MessageCircle, id: 'messages' as const },
  { icon: CircleUserRound, id: 'profile' as const },
]
const selectedQuote = computed(() =>
  skyride.quote?.options.find(
    (option) => option.quoteId === selectedQuoteId.value,
  ),
)
const canRequestSelectedQuote = computed(() => {
  const option = selectedQuote.value
  if (!option) return false
  if (fareMode.value === 'calculated') {
    return option.fareMode === 'calculated'
  }
  return (
    option.fareMode === 'custom' &&
    Number(customFareInput.value) === option.price
  )
})
const activeContact = computed(() =>
  mode.value === 'driver'
    ? skyride.activeRide?.passenger
    : skyride.activeRide?.driver,
)
const canCancelRide = computed(() =>
  [
    'searching',
    'accepted',
    'driver_arriving',
    'arrived',
    'in_progress',
  ].includes(skyride.activeRide?.status ?? ''),
)
const driverAction = computed<'arrive' | 'start' | 'complete' | null>(() => {
  const status = skyride.activeRide?.status
  if (status === 'accepted' || status === 'driver_arriving') return 'arrive'
  if (status === 'arrived') return 'start'
  if (status === 'in_progress') return 'complete'
  return null
})
const ratingRide = computed(() => skyride.pendingRating)
const profileAvatarUrl = computed(
  () =>
    selectedProfileAvatar.value?.url ??
    (profileAvatarMediaId.value > 0 ? skyride.profile?.avatarUrl : null),
)
const canSaveProfile = computed(() => {
  const length = Array.from(profileName.value.trim()).length
  return length >= 2 && length <= 50 && !skyride.isActionPending
})

function showToast(message: string): void {
  if (toastTimer) window.clearTimeout(toastTimer)
  toastText.value = message
  toastTimer = window.setTimeout(() => {
    toastText.value = ''
    toastTimer = undefined
  }, 2200)
}

function errorText(error?: string): string {
  const key = error ?? 'request_failed'
  const translated = phone.t(`Apps.skyride.errors.${key}`)
  return translated === `Apps.skyride.errors.${key}`
    ? phone.t('Apps.skyride.errors.request_failed')
    : translated
}

function locationLabel(location: SkyRideLocation | null): string {
  if (!location) return phone.t('Apps.skyride.notSelected')
  if (!location.id) return location.label
  const key = `Apps.skyride.quickLocations.${location.id}`
  const translated = phone.t(key)
  return translated === key ? phone.t('Apps.skyride.savedPlace') : translated
}

function paymentMethodLabel(method: string): string {
  const key = `Apps.skyride.paymentMethods.${method}`
  const translated = phone.t(key)
  return translated === key
    ? phone.t('Apps.skyride.paymentMethods.default')
    : translated
}

function formatMoney(amount: number, currency: string): string {
  if (/^[A-Z]{3}$/.test(currency)) {
    return new Intl.NumberFormat(phone.lang, {
      currency,
      maximumFractionDigits: 0,
      style: 'currency',
    }).format(amount)
  }
  return `${currency}${new Intl.NumberFormat(phone.lang, {
    maximumFractionDigits: 0,
  }).format(amount)}`
}

function formatQuoteDistance(
  distance: number,
  unit: SkyRideDistanceUnit,
): string {
  return phone.t(
    unit === 'mile'
      ? 'Apps.skyride.distanceMiles'
      : 'Apps.skyride.distanceKilometers',
    {
      distance: distance.toLocaleString(phone.lang, {
        maximumFractionDigits: 1,
      }),
    },
  )
}

function formatRideDistance(distanceMeters: number): string {
  return formatQuoteDistance(Math.max(0, distanceMeters) / 1000, 'kilometer')
}

function formatDistanceRate(option: SkyRideQuoteOption): string {
  const unitKey =
    skyride.quote?.distanceUnit === 'mile' ? 'perMile' : 'perKilometer'
  return phone.t(`Apps.skyride.${unitKey}`, {
    price: formatMoney(option.pricePerDistanceUnit, option.currency),
  })
}

function formatDuration(durationSeconds: number): string {
  return phone.t('Apps.skyride.durationMinutes', {
    minutes: Math.max(1, Math.round(durationSeconds / 60)).toLocaleString(
      phone.lang,
    ),
  })
}

function formatDate(timestamp: number): string {
  return new Intl.DateTimeFormat(phone.lang, {
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    month: 'short',
  }).format(new Date(timestamp * 1000))
}

function statusLabel(status: SkyRideRideStatus): string {
  return phone.t(`Apps.skyride.status.${status}`)
}

function vehicleLabel(ride: SkyRideRide): string {
  const model = ride.driver?.vehicle.model.trim() ?? ''
  return model && !/^-?\d+$/.test(model)
    ? model
    : phone.t('Apps.skyride.vehicle')
}

function updateRatingComment(event: Event): void {
  ratingComment.value = (event.target as HTMLInputElement).value
}

function openLocationPicker(target: LocationTarget): void {
  if (skyride.activeRide) return
  locationTarget.value = target
}

function chooseLocation(location: SkyRideLocation): void {
  const target = locationTarget.value
  if (!target) return
  if (target === 'pickup') pickup.value = { ...location }
  else destination.value = { ...location }
  locationTarget.value = null
  skyride.clearQuote()
}

function chooseQuickDestination(location: SkyRideLocation): void {
  destination.value = { ...location }
  skyride.clearQuote()
}

async function useCurrentLocation(): Promise<void> {
  const target = locationTarget.value
  if (!target) return
  const response = await skyride.getPlayerCoordinates()
  if (!response.success || !response.data) {
    showToast(errorText(response.error))
    return
  }
  chooseLocation({
    coords: response.data.coords,
    label: phone.t('Apps.skyride.currentLocation'),
  })
}

async function createQuote(customFare?: SkyRideCustomFareInput): Promise<void> {
  if (!pickup.value || !destination.value) return
  const preferredService =
    customFare?.serviceClass ?? selectedQuote.value?.serviceClass
  const response = await skyride.createQuote(
    pickup.value,
    destination.value,
    customFare,
  )
  if (!response.success || !response.data) {
    showToast(errorText(response.error))
    return
  }
  const option =
    response.data.options.find(
      (candidate) =>
        candidate.available && candidate.serviceClass === preferredService,
    ) ?? response.data.options.find((candidate) => candidate.available)
  selectedQuoteId.value = option?.quoteId ?? null
  fareMode.value = option?.fareMode ?? 'calculated'
  customFareInput.value = option ? String(option.price) : ''
}

async function requestRide(
  option: SkyRideQuoteOption | undefined,
): Promise<void> {
  if (!option) return
  const response = await skyride.requestRide(option)
  if (!response.success) showToast(errorText(response.error))
}

function selectQuoteOption(option: SkyRideQuoteOption): void {
  if (!option.available) return
  selectedQuoteId.value = option.quoteId
  fareMode.value = option.fareMode
  customFareInput.value = String(option.price)
}

function selectFareMode(nextMode: SkyRideFareMode): void {
  fareMode.value = nextMode
  const option = selectedQuote.value
  if (!option) return
  customFareInput.value = String(
    nextMode === 'custom' && option.fareMode === 'custom'
      ? option.price
      : option.calculatedPrice,
  )
}

function updateCustomFareInput(event: Event): void {
  customFareInput.value = (event.target as HTMLInputElement).value
}

async function applyCustomFare(): Promise<void> {
  const option = selectedQuote.value
  const price = Number(customFareInput.value)
  if (
    !option ||
    !Number.isInteger(price) ||
    price < option.minimumCustomPrice ||
    price > option.maximumCustomPrice
  ) {
    showToast(errorText('invalid_custom_fare'))
    return
  }
  await createQuote({ price, serviceClass: option.serviceClass })
}

async function applyCalculatedFare(): Promise<void> {
  if (selectedQuote.value?.fareMode === 'calculated') {
    selectFareMode('calculated')
    return
  }
  fareMode.value = 'calculated'
  await createQuote()
}

async function toggleDriverStatus(): Promise<void> {
  const response = await skyride.setDriverStatus(!skyride.driverOnline)
  if (!response.success) showToast(errorText(response.error))
}

async function acceptRide(ride: SkyRideRide): Promise<void> {
  const response = await skyride.performRideAction('accept', ride.id)
  if (!response.success) showToast(errorText(response.error))
}

async function performDriverAction(): Promise<void> {
  const ride = skyride.activeRide
  const action = driverAction.value
  if (!ride || !action) return
  const response = await skyride.performRideAction(action, ride.id)
  if (!response.success) showToast(errorText(response.error))
}

async function confirmCancel(): Promise<void> {
  const ride = skyride.activeRide
  if (!ride) return
  const response = await skyride.cancelRide(ride.id, 'changed_mind')
  if (!response.success) showToast(errorText(response.error))
  cancelDialogOpened.value = false
}

async function setRideWaypoint(): Promise<void> {
  const ride = skyride.activeRide
  if (!ride) return
  const location =
    mode.value === 'driver' && ride.status !== 'in_progress'
      ? ride.pickup
      : ride.destination
  const response = await skyride.setWaypoint(location.coords)
  showToast(
    response.success
      ? phone.t('Apps.skyride.waypointSet')
      : errorText(response.error),
  )
}

async function callActiveContact(): Promise<void> {
  const number = activeContact.value?.phoneNumber
  if (!number) return
  const response = await calls.dial(number)
  if (!response.success) showToast(errorText(response.error))
}

function openMessages(): void {
  void router.push('/apps/messages')
}

function syncProfileEditor(): void {
  if (!skyride.profile) return
  profileName.value = skyride.profile.name
  profileAvatarMediaId.value = skyride.profile.avatarMediaId ?? 0
  selectedProfileAvatar.value = null
}

function openProfileEditor(): void {
  syncProfileEditor()
  profileEditorOpened.value = true
}

function closeProfileEditor(): void {
  profileEditorOpened.value = false
  syncProfileEditor()
}

function openProfileMedia(app: 'camera' | 'photos'): void {
  messageMedia.begin(
    'skyride:profile-avatar',
    'photo',
    '/apps/skyride?profileEdit=1',
    1,
    {
      avatarMediaId: profileAvatarMediaId.value,
      name: profileName.value,
      selectedAvatar: selectedProfileAvatar.value,
    } satisfies ProfileMediaContext,
  )
  profileEditorOpened.value = false
  void router.push({
    path: `/apps/${app}`,
    query: { mediaAttachment: 'photo' },
  })
}

function removeProfileAvatar(): void {
  selectedProfileAvatar.value = null
  profileAvatarMediaId.value = 0
}

async function saveProfile(): Promise<void> {
  if (!canSaveProfile.value) {
    showToast(phone.t('Apps.skyride.errors.invalid_profile_name'))
    return
  }
  const response = await skyride.updateProfile({
    avatarMediaId:
      selectedProfileAvatar.value?.id ?? profileAvatarMediaId.value,
    name: profileName.value.trim(),
  })
  if (!response.success) {
    showToast(errorText(response.error))
    return
  }
  profileEditorOpened.value = false
  syncProfileEditor()
  showToast(phone.t('Apps.skyride.profileSaved'))
}

async function submitRating(): Promise<void> {
  const ride = ratingRide.value
  if (!ride || rating.value < 1) return
  const response = await skyride.rateRide(
    ride.id,
    rating.value,
    tip.value,
    ratingComment.value.trim(),
  )
  if (!response.success) {
    showToast(errorText(response.error))
    return
  }
  rating.value = 0
  tip.value = 0
  ratingComment.value = ''
  showToast(phone.t('Apps.skyride.ratingSaved'))
}

function dismissRating(): void {
  skyride.pendingRating = null
  rating.value = 0
  tip.value = 0
  ratingComment.value = ''
}

function selectTab(tab: SkyRideTab): void {
  activeTab.value = tab
  if (tab === 'rides' || tab === 'activity') void skyride.loadHistory()
}

function handleSkyRideMessage(event: MessageEvent<unknown>): void {
  if (!isTrustedRootMessageSource(event.source, window)) return
  if (typeof event.data !== 'object' || event.data === null) return
  const message = event.data as Partial<SkyRideChangedMessage>
  if (message.type !== 'skyride:changed' || !message.data) return
  skyride.applyUpdate(message.data)
}

watch(
  () => skyride.driverEligible,
  (eligible) => {
    if (!eligible) mode.value = 'rider'
  },
)

watch(
  () => skyride.activeRide,
  (ride) => {
    if (!ride || !skyride.profile) return
    mode.value = ride.passenger?.id === skyride.profile.id ? 'rider' : 'driver'
  },
)

onMounted(async () => {
  window.addEventListener('message', handleSkyRideMessage)
  const profileSelection = messageMedia.consumeMany<ProfileMediaContext>(
    'skyride:profile-avatar',
  )
  await skyride.bootstrap()
  syncProfileEditor()
  if (profileSelection?.context) {
    profileName.value = profileSelection.context.name
    profileAvatarMediaId.value = profileSelection.context.avatarMediaId
    selectedProfileAvatar.value =
      profileSelection.media[0] ?? profileSelection.context.selectedAvatar
    if (profileSelection.media[0]) {
      profileAvatarMediaId.value = profileSelection.media[0].id
    }
    activeTab.value = 'profile'
    profileEditorOpened.value = true
  }
  const response = await skyride.getPlayerCoordinates()
  if (response.success && response.data) {
    if (!pickup.value) {
      pickup.value = {
        coords: response.data.coords,
        label: phone.t('Apps.skyride.currentLocation'),
      }
    }
  }
})

onBeforeUnmount(() => {
  window.removeEventListener('message', handleSkyRideMessage)
  if (toastTimer) window.clearTimeout(toastTimer)
})
</script>

<template>
  <k-page
    class="skyride-app pb-safe-24"
    :class="{ 'skyride-app--dark': phone.isDarkMode }"
    :label="phone.t('Apps.skyride.name')"
    :dark="phone.isDarkMode"
    accent="#c49a00"
    accent-soft="rgba(245, 197, 24, 0.16)"
  >
    <div class="skyride-ambient" aria-hidden="true"></div>
    <k-navbar
      class="skyride-navbar"
      :title="phone.t('Apps.skyride.name')"
      :subtitle="phone.t(`Apps.skyride.mode.${mode}`)"
    />

    <k-block
      v-if="skyride.isLoading && !skyride.profile"
      class="skyride-loading"
    >
      <k-preloader />
      <span>{{ phone.t('Apps.skyride.loading') }}</span>
    </k-block>

    <k-card
      v-else-if="!skyride.profile"
      :content-wrap="false"
      class="skyride-unavailable"
    >
      <CarFront :size="36" aria-hidden="true" />
      <strong>{{ phone.t('Apps.skyride.unavailable') }}</strong>
      <p>{{ errorText(skyride.error) }}</p>
      <k-button rounded @click="skyride.bootstrap()">
        {{ phone.t('Apps.skyride.tryAgain') }}
      </k-button>
    </k-card>

    <template v-else>
      <div class="skyride-scroll">
        <div class="skyride-mode">
          <k-segmented v-if="skyride.driverEligible">
            <k-segmented-button
              :active="mode === 'rider'"
              :disabled="Boolean(skyride.activeRide)"
              @click="mode = 'rider'"
            >
              {{ phone.t('Apps.skyride.mode.rider') }}
            </k-segmented-button>
            <k-segmented-button
              :active="mode === 'driver'"
              :disabled="Boolean(skyride.activeRide)"
              @click="mode = 'driver'"
            >
              {{ phone.t('Apps.skyride.mode.driver') }}
            </k-segmented-button>
          </k-segmented>
        </div>

        <template v-if="activeTab === 'home'">
          <section v-if="mode === 'rider'" class="skyride-home-panel">
            <template v-if="!skyride.activeRide">
              <k-block-header inset component="header" class="skyride-heading">
                <div>
                  <span>{{ phone.t('Apps.skyride.riderEyebrow') }}</span>
                  <h1>{{ phone.t('Apps.skyride.whereTo') }}</h1>
                </div>
                <span class="skyride-heading__icon" aria-hidden="true">
                  <Navigation :size="20" aria-hidden="true" />
                </span>
              </k-block-header>

              <k-list inset strong class="skyride-location-list">
                <k-list-item
                  link
                  :title="phone.t('Apps.skyride.pickup')"
                  :subtitle="locationLabel(pickup)"
                  @click="openLocationPicker('pickup')"
                >
                  <template #media><span class="skyride-dot"></span></template>
                </k-list-item>
                <k-list-item
                  link
                  :title="phone.t('Apps.skyride.destination')"
                  :subtitle="locationLabel(destination)"
                  @click="openLocationPicker('destination')"
                >
                  <template #media><MapPin :size="19" /></template>
                </k-list-item>
              </k-list>

              <template v-if="!skyride.quote">
                <k-block-title class="skyride-custom-block-title">{{
                  phone.t('Apps.skyride.quickDestinations')
                }}</k-block-title>
                <k-block class="skyride-quick-grid">
                  <k-button
                    v-for="location in skyride.quickLocations.slice(0, 4)"
                    :key="location.id ?? location.label"
                    large
                    rounded
                    variant="secondary"
                    class="skyride-quick-card"
                    @click="chooseQuickDestination(location)"
                  >
                    <component
                      :is="location.id === 'work' ? BriefcaseBusiness : MapPin"
                      :size="18"
                      aria-hidden="true"
                    />
                    <span>{{ locationLabel(location) }}</span>
                  </k-button>
                </k-block>

                <k-button
                  large
                  rounded
                  class="skyride-primary"
                  :disabled="!pickup || !destination || skyride.isActionPending"
                  @click="createQuote()"
                >
                  <k-preloader v-if="skyride.isActionPending" />
                  <template v-else>
                    {{ phone.t('Apps.skyride.viewRides') }}
                    <ChevronRight :size="18" aria-hidden="true" />
                  </template>
                </k-button>
              </template>

              <template v-else>
                <div class="skyride-quote-summary">
                  <k-chip class="skyride-quote-chip">{{
                    formatQuoteDistance(
                      skyride.quote.distance,
                      skyride.quote.distanceUnit,
                    )
                  }}</k-chip>
                  <k-chip class="skyride-quote-chip">{{
                    formatDuration(skyride.quote.durationSeconds)
                  }}</k-chip>
                  <k-link @click="skyride.clearQuote()">
                    {{ phone.t('Apps.skyride.change') }}
                  </k-link>
                </div>
                <k-list inset strong class="skyride-service-list">
                  <k-list-item
                    v-for="option in skyride.quote.options"
                    :key="option.quoteId"
                    :link="option.available"
                    :aria-disabled="!option.available"
                    :class="{
                      'is-selected': selectedQuoteId === option.quoteId,
                      'is-unavailable': !option.available,
                    }"
                    :title="
                      phone.t(
                        `Apps.skyride.services.${option.serviceClass}.name`,
                      )
                    "
                    :subtitle="
                      phone.t('Apps.skyride.serviceMeta', {
                        eta: option.etaMinutes.toLocaleString(phone.lang),
                        seats: option.seats.toLocaleString(phone.lang),
                      })
                    "
                    @click="selectQuoteOption(option)"
                  >
                    <template #media>
                      <span class="skyride-service-icon">
                        <CarFront :size="22" aria-hidden="true" />
                      </span>
                    </template>
                    <template #after>
                      <strong>{{
                        formatMoney(option.price, option.currency)
                      }}</strong>
                      <Check
                        v-if="selectedQuoteId === option.quoteId"
                        :size="16"
                      />
                    </template>
                  </k-list-item>
                </k-list>
                <k-card
                  v-if="selectedQuote"
                  :content-wrap="false"
                  class="skyride-fare-card"
                >
                  <div class="skyride-fare-card__heading">
                    <span class="skyride-fare-card__icon">
                      <CircleDollarSign :size="19" aria-hidden="true" />
                    </span>
                    <div>
                      <small>{{ phone.t('Apps.skyride.fare') }}</small>
                      <strong>{{
                        formatMoney(selectedQuote.price, selectedQuote.currency)
                      }}</strong>
                    </div>
                    <span>{{ formatDistanceRate(selectedQuote) }}</span>
                  </div>
                  <k-segmented>
                    <k-segmented-button
                      :active="fareMode === 'calculated'"
                      @click="applyCalculatedFare"
                    >
                      {{ phone.t('Apps.skyride.calculatedFare') }}
                    </k-segmented-button>
                    <k-segmented-button
                      :active="fareMode === 'custom'"
                      @click="selectFareMode('custom')"
                    >
                      {{ phone.t('Apps.skyride.customFare') }}
                    </k-segmented-button>
                  </k-segmented>
                  <div
                    v-if="fareMode === 'calculated'"
                    class="skyride-fare-breakdown"
                  >
                    <span>{{
                      phone.t('Apps.skyride.calculatedFareBody')
                    }}</span>
                    <strong>{{
                      formatMoney(
                        selectedQuote.calculatedPrice,
                        selectedQuote.currency,
                      )
                    }}</strong>
                  </div>
                  <div v-else class="skyride-custom-fare">
                    <k-list inset strong>
                      <k-list-input
                        id="skyride-custom-fare"
                        outline
                        type="number"
                        inputmode="numeric"
                        step="1"
                        :label="phone.t('Apps.skyride.customFare')"
                        :min="selectedQuote.minimumCustomPrice"
                        :max="selectedQuote.maximumCustomPrice"
                        :value="customFareInput"
                        :help="
                          phone.t('Apps.skyride.customFareRange', {
                            maximum: formatMoney(
                              selectedQuote.maximumCustomPrice,
                              selectedQuote.currency,
                            ),
                            minimum: formatMoney(
                              selectedQuote.minimumCustomPrice,
                              selectedQuote.currency,
                            ),
                          })
                        "
                        @input="updateCustomFareInput"
                      />
                    </k-list>
                    <k-button
                      small
                      rounded
                      :disabled="skyride.isActionPending"
                      @click="applyCustomFare"
                    >
                      {{ phone.t('Apps.skyride.applyCustomFare') }}
                    </k-button>
                  </div>
                </k-card>
                <p class="skyride-player-driver-notice">
                  {{ phone.t('Apps.skyride.playerDriverNotice') }}
                </p>
                <k-button
                  large
                  rounded
                  class="skyride-primary"
                  :disabled="
                    !canRequestSelectedQuote || skyride.isActionPending
                  "
                  @click="requestRide(selectedQuote)"
                >
                  <k-preloader v-if="skyride.isActionPending" />
                  <template v-else>
                    {{ phone.t('Apps.skyride.requestRide') }}
                    <ChevronRight :size="18" aria-hidden="true" />
                  </template>
                </k-button>
              </template>
            </template>

            <template v-else>
              <k-card :content-wrap="false" class="skyride-ride-status-card">
                <span
                  class="skyride-status-icon"
                  :class="'is-' + skyride.activeRide.status"
                >
                  <k-preloader
                    v-if="skyride.activeRide.status === 'searching'"
                  />
                  <CheckCircle2 v-else :size="22" aria-hidden="true" />
                </span>
                <div>
                  <small>{{ phone.t('Apps.skyride.rideStatus') }}</small>
                  <h1>{{ statusLabel(skyride.activeRide.status) }}</h1>
                  <p>
                    {{
                      phone.t(
                        `Apps.skyride.statusBody.${skyride.activeRide.status}`,
                      )
                    }}
                  </p>
                </div>
              </k-card>

              <k-card
                v-if="skyride.activeRide.driver"
                :content-wrap="false"
                class="skyride-person-card"
              >
                <div class="skyride-avatar">
                  <img
                    v-if="skyride.activeRide.driver.avatarUrl"
                    :src="skyride.activeRide.driver.avatarUrl"
                    alt=""
                  />
                  <UserRound v-else :size="22" aria-hidden="true" />
                </div>
                <div class="skyride-person-card__body">
                  <strong>{{ skyride.activeRide.driver.name }}</strong>
                  <span>
                    <Star :size="13" fill="currentColor" aria-hidden="true" />
                    {{
                      skyride.activeRide.driver.rating.toLocaleString(
                        phone.lang,
                      )
                    }}
                    · {{ vehicleLabel(skyride.activeRide) }}
                  </span>
                  <b>{{ skyride.activeRide.driver.vehicle.plate }}</b>
                </div>
                <div class="skyride-contact-actions">
                  <k-button
                    small
                    rounded
                    outline
                    :disabled="!skyride.activeRide.driver.phoneNumber"
                    :aria-label="phone.t('Apps.skyride.call')"
                    @click="callActiveContact"
                  >
                    <Phone :size="17" aria-hidden="true" />
                  </k-button>
                  <k-button
                    small
                    rounded
                    outline
                    :aria-label="phone.t('Apps.skyride.message')"
                    @click="openMessages"
                  >
                    <MessageCircle :size="17" aria-hidden="true" />
                  </k-button>
                </div>
              </k-card>

              <k-card :content-wrap="false" class="skyride-trip-card">
                <div class="skyride-route-stop">
                  <span class="skyride-dot"></span>
                  <div>
                    <small>{{ phone.t('Apps.skyride.pickup') }}</small>
                    <strong>{{
                      locationLabel(skyride.activeRide.pickup)
                    }}</strong>
                  </div>
                </div>
                <i></i>
                <div class="skyride-route-stop">
                  <MapPin :size="18" aria-hidden="true" />
                  <div>
                    <small>{{ phone.t('Apps.skyride.destination') }}</small>
                    <strong>{{
                      locationLabel(skyride.activeRide.destination)
                    }}</strong>
                  </div>
                </div>
                <div class="skyride-trip-meta">
                  <span>{{
                    phone.t(
                      `Apps.skyride.services.${skyride.activeRide.serviceClass}.name`,
                    )
                  }}</span>
                  <strong>{{
                    formatMoney(
                      skyride.activeRide.price,
                      skyride.activeRide.currency,
                    )
                  }}</strong>
                </div>
              </k-card>

              <div class="skyride-active-actions">
                <k-button rounded outline @click="setRideWaypoint">
                  <Navigation :size="17" aria-hidden="true" />
                  {{ phone.t('Apps.skyride.navigate') }}
                </k-button>
                <k-button
                  v-if="canCancelRide"
                  rounded
                  variant="danger"
                  outline
                  @click="cancelDialogOpened = true"
                >
                  {{ phone.t('Apps.skyride.cancelRide') }}
                </k-button>
              </div>
              <k-block class="skyride-safety-note">
                <ShieldCheck :size="18" aria-hidden="true" />
                <span>{{ phone.t('Apps.skyride.safetyNote') }}</span>
              </k-block>
            </template>
          </section>

          <section v-else class="skyride-home-panel skyride-driver-home">
            <k-card :content-wrap="false" class="skyride-driver-status">
              <div
                class="skyride-driver-status__icon"
                :class="{ 'is-online': skyride.driverOnline }"
              >
                <Power :size="21" aria-hidden="true" />
              </div>
              <div>
                <strong>{{
                  phone.t(
                    `Apps.skyride.driver.${skyride.driverOnline ? 'online' : 'offline'}`,
                  )
                }}</strong>
                <span>{{
                  phone.t(
                    `Apps.skyride.driver.${skyride.driverOnline ? 'onlineBody' : 'offlineBody'}`,
                  )
                }}</span>
              </div>
              <k-toggle
                :checked="skyride.driverOnline"
                :disabled="
                  skyride.isActionPending || Boolean(skyride.activeRide)
                "
                :aria-label="phone.t('Apps.skyride.driver.toggleStatus')"
                @change="toggleDriverStatus"
              />
            </k-card>

            <template v-if="skyride.activeRide">
              <k-card :content-wrap="false" class="skyride-ride-status-card">
                <span class="skyride-status-icon"><CarFront :size="22" /></span>
                <div>
                  <small>{{ phone.t('Apps.skyride.rideStatus') }}</small>
                  <h1>{{ statusLabel(skyride.activeRide.status) }}</h1>
                  <p>
                    {{
                      phone.t(
                        `Apps.skyride.driver.statusBody.${skyride.activeRide.status}`,
                      )
                    }}
                  </p>
                </div>
              </k-card>
              <k-card
                v-if="skyride.activeRide.passenger"
                :content-wrap="false"
                class="skyride-person-card"
              >
                <div class="skyride-avatar">
                  <img
                    v-if="skyride.activeRide.passenger.avatarUrl"
                    :src="skyride.activeRide.passenger.avatarUrl"
                    alt=""
                  />
                  <UserRound v-else :size="22" aria-hidden="true" />
                </div>
                <div class="skyride-person-card__body">
                  <small>{{ phone.t('Apps.skyride.passenger') }}</small>
                  <strong>{{ skyride.activeRide.passenger.name }}</strong>
                  <span
                    ><Star :size="13" fill="currentColor" />
                    {{
                      skyride.activeRide.passenger.rating.toLocaleString(
                        phone.lang,
                      )
                    }}</span
                  >
                </div>
                <div class="skyride-contact-actions">
                  <k-button
                    small
                    rounded
                    outline
                    :disabled="!skyride.activeRide.passenger.phoneNumber"
                    @click="callActiveContact"
                  >
                    <Phone :size="17" aria-hidden="true" />
                  </k-button>
                  <k-button small rounded outline @click="openMessages">
                    <MessageCircle :size="17" aria-hidden="true" />
                  </k-button>
                </div>
              </k-card>
              <k-card :content-wrap="false" class="skyride-trip-card">
                <div class="skyride-route-stop">
                  <span class="skyride-dot"></span>
                  <div>
                    <small>{{ phone.t('Apps.skyride.pickup') }}</small
                    ><strong>{{
                      locationLabel(skyride.activeRide.pickup)
                    }}</strong>
                  </div>
                </div>
                <i></i>
                <div class="skyride-route-stop">
                  <MapPin :size="18" />
                  <div>
                    <small>{{ phone.t('Apps.skyride.destination') }}</small
                    ><strong>{{
                      locationLabel(skyride.activeRide.destination)
                    }}</strong>
                  </div>
                </div>
                <div class="skyride-trip-meta">
                  <span>{{
                    phone.t(
                      `Apps.skyride.services.${skyride.activeRide.serviceClass}.name`,
                    )
                  }}</span>
                  <strong>{{
                    formatMoney(
                      skyride.activeRide.price,
                      skyride.activeRide.currency,
                    )
                  }}</strong>
                </div>
              </k-card>
              <div class="skyride-driver-actions">
                <k-button rounded outline @click="setRideWaypoint">
                  <Navigation :size="17" />
                  {{ phone.t('Apps.skyride.navigate') }}
                </k-button>
                <k-button
                  v-if="driverAction"
                  rounded
                  :disabled="skyride.isActionPending"
                  @click="performDriverAction"
                >
                  <k-preloader v-if="skyride.isActionPending" />
                  <template v-else>{{
                    phone.t(`Apps.skyride.driver.actions.${driverAction}`)
                  }}</template>
                </k-button>
              </div>
            </template>

            <template v-else>
              <div class="skyride-driver-metrics">
                <k-card :content-wrap="false">
                  <CircleDollarSign :size="19" />
                  <strong>{{
                    formatMoney(
                      skyride.profile.earningsToday ?? 0,
                      skyride.profile.currency,
                    )
                  }}</strong>
                  <span>{{ phone.t('Apps.skyride.driver.today') }}</span>
                </k-card>
                <k-card :content-wrap="false">
                  <Star :size="19" />
                  <strong>{{
                    skyride.profile.rating.toLocaleString(phone.lang)
                  }}</strong>
                  <span>{{ phone.t('Apps.skyride.rating') }}</span>
                </k-card>
              </div>
              <k-block-title class="skyride-custom-block-title">{{
                phone.t('Apps.skyride.driver.requests')
              }}</k-block-title>
              <div
                v-if="skyride.driverOnline && skyride.availableRequests.length"
                class="skyride-request-list"
              >
                <k-card
                  v-for="request in skyride.availableRequests"
                  :key="request.id"
                  class="skyride-request-card"
                >
                  <div class="skyride-request-card__top">
                    <span class="skyride-service-icon"
                      ><CarFront :size="20"
                    /></span>
                    <div>
                      <strong>{{
                        phone.t(
                          `Apps.skyride.services.${request.serviceClass}.name`,
                        )
                      }}</strong>
                      <span>{{ formatDate(request.createdAt) }}</span>
                    </div>
                    <b>{{ formatMoney(request.price, request.currency) }}</b>
                  </div>
                  <div class="skyride-request-route">
                    <span>{{ locationLabel(request.pickup) }}</span>
                    <ChevronRight :size="15" />
                    <span>{{ locationLabel(request.destination) }}</span>
                  </div>
                  <k-button
                    rounded
                    :disabled="skyride.isActionPending"
                    @click="acceptRide(request)"
                  >
                    {{ phone.t('Apps.skyride.driver.accept') }}
                  </k-button>
                </k-card>
              </div>
              <k-card v-else :content-wrap="false" class="skyride-empty-card">
                <Power v-if="!skyride.driverOnline" :size="28" />
                <Clock3 v-else :size="28" />
                <strong>{{
                  phone.t(
                    `Apps.skyride.driver.${skyride.driverOnline ? 'noRequests' : 'goOnline'}`,
                  )
                }}</strong>
                <p>
                  {{
                    phone.t(
                      `Apps.skyride.driver.${skyride.driverOnline ? 'noRequestsBody' : 'goOnlineBody'}`,
                    )
                  }}
                </p>
              </k-card>
            </template>
          </section>
        </template>

        <template v-else-if="activeTab === 'rides'">
          <section class="skyride-section-screen">
            <k-block-header
              inset
              component="header"
              class="skyride-screen-title"
            >
              <History :size="25" aria-hidden="true" />
              <div>
                <h1>{{ phone.t('Apps.skyride.rides') }}</h1>
                <p>{{ phone.t('Apps.skyride.ridesBody') }}</p>
              </div>
            </k-block-header>
            <k-block v-if="skyride.history.length" class="skyride-history-list">
              <k-card
                v-for="ride in skyride.history"
                :key="ride.id"
                header-divider
                footer-divider
                content-wrap-padding="px-4 py-2"
                class="skyride-history-card"
              >
                <template #header>
                  <div class="skyride-history-card__header">
                    <span class="skyride-service-icon"
                      ><CarFront :size="19"
                    /></span>
                    <div>
                      <strong>{{
                        phone.t(
                          `Apps.skyride.services.${ride.serviceClass}.name`,
                        )
                      }}</strong
                      ><span>{{ formatDate(ride.createdAt) }}</span>
                    </div>
                    <k-badge>{{ statusLabel(ride.status) }}</k-badge>
                  </div>
                </template>
                <div class="skyride-history-route">
                  <span>{{ locationLabel(ride.pickup) }}</span
                  ><ChevronRight :size="15" /><span>{{
                    locationLabel(ride.destination)
                  }}</span>
                </div>
                <template #footer>
                  <div class="skyride-history-card__footer">
                    <div class="skyride-history-card__meta">
                      <span>{{
                        ride.driver?.name ??
                        ride.passenger?.name ??
                        phone.t('Apps.skyride.ride')
                      }}</span>
                      <span class="skyride-history-card__distance">
                        <Route :size="13" aria-hidden="true" />
                        {{ formatRideDistance(ride.distanceMeters) }}
                      </span>
                    </div>
                    <strong>{{
                      formatMoney(ride.finalPrice ?? ride.price, ride.currency)
                    }}</strong>
                  </div>
                </template>
              </k-card>
            </k-block>
            <k-card v-else :content-wrap="false" class="skyride-empty-card"
              ><History :size="29" /><strong>{{
                phone.t('Apps.skyride.noRides')
              }}</strong>
              <p>{{ phone.t('Apps.skyride.noRidesBody') }}</p></k-card
            >
          </section>
        </template>

        <template v-else-if="activeTab === 'activity'">
          <section class="skyride-section-screen">
            <k-block-header
              inset
              component="header"
              class="skyride-screen-title"
            >
              <Bell :size="25" />
              <div>
                <h1>{{ phone.t('Apps.skyride.activity') }}</h1>
                <p>{{ phone.t('Apps.skyride.activityBody') }}</p>
              </div>
            </k-block-header>
            <k-list
              v-if="skyride.history.length"
              inset
              strong
              class="skyride-activity-list"
            >
              <k-list-item
                v-for="ride in skyride.history"
                :key="ride.id"
                :title="statusLabel(ride.status)"
                :subtitle="`${locationLabel(ride.destination)} · ${formatDate(ride.updatedAt)}`"
                :after="
                  formatMoney(ride.finalPrice ?? ride.price, ride.currency)
                "
              >
                <template #media
                  ><span class="skyride-activity-icon"
                    ><CheckCircle2 :size="18" /></span
                ></template>
              </k-list-item>
            </k-list>
            <k-card v-else :content-wrap="false" class="skyride-empty-card"
              ><Bell :size="29" /><strong>{{
                phone.t('Apps.skyride.noActivity')
              }}</strong>
              <p>{{ phone.t('Apps.skyride.noActivityBody') }}</p></k-card
            >
          </section>
        </template>

        <template v-else-if="activeTab === 'messages'">
          <section class="skyride-section-screen">
            <k-block-header
              inset
              component="header"
              class="skyride-screen-title"
            >
              <MessageCircle :size="25" />
              <div>
                <h1>{{ phone.t('Apps.skyride.messages') }}</h1>
                <p>{{ phone.t('Apps.skyride.messagesBody') }}</p>
              </div>
            </k-block-header>
            <k-card
              v-if="activeContact"
              :content-wrap="false"
              class="skyride-message-contact"
            >
              <div class="skyride-avatar">
                <img
                  v-if="activeContact.avatarUrl"
                  :src="activeContact.avatarUrl"
                  alt=""
                /><UserRound v-else :size="22" />
              </div>
              <div>
                <strong>{{ activeContact.name }}</strong
                ><span
                  ><Star :size="13" fill="currentColor" />
                  {{ activeContact.rating.toLocaleString(phone.lang) }}</span
                >
              </div>
              <ChevronRight :size="18" />
            </k-card>
            <k-block v-if="activeContact" class="skyride-contact-buttons">
              <k-button
                rounded
                :disabled="!activeContact.phoneNumber"
                @click="callActiveContact"
                ><Phone :size="17" />
                {{ phone.t('Apps.skyride.call') }}</k-button
              >
              <k-button rounded @click="openMessages"
                ><MessageCircle :size="17" />
                {{ phone.t('Apps.skyride.openMessages') }}</k-button
              >
            </k-block>
            <k-card v-else :content-wrap="false" class="skyride-empty-card"
              ><MessageCircle :size="29" /><strong>{{
                phone.t('Apps.skyride.noMessages')
              }}</strong>
              <p>{{ phone.t('Apps.skyride.noMessagesBody') }}</p>
              <k-button rounded @click="openMessages">{{
                phone.t('Apps.skyride.openMessages')
              }}</k-button></k-card
            >
          </section>
        </template>

        <template v-else>
          <section class="skyride-section-screen skyride-profile">
            <div class="skyride-profile-hero">
              <button
                type="button"
                class="skyride-profile-avatar skyride-profile-avatar--editable"
                :aria-label="phone.t('Apps.skyride.editProfile')"
                @click="openProfileEditor"
              >
                <img
                  v-if="skyride.profile.avatarUrl"
                  :src="skyride.profile.avatarUrl"
                  alt=""
                /><UserRound v-else :size="32" />
                <span><Pencil :size="13" /></span>
              </button>
              <h1>{{ skyride.profile.name }}</h1>
              <span
                ><Star :size="15" fill="currentColor" />
                {{ skyride.profile.rating.toLocaleString(phone.lang) }}</span
              >
            </div>
            <k-card :content-wrap="false" class="skyride-profile-stats">
              <div>
                <strong>{{
                  skyride.profile.completedRides.toLocaleString(phone.lang)
                }}</strong
                ><span>{{ phone.t('Apps.skyride.completedRides') }}</span>
              </div>
              <div>
                <strong>{{
                  skyride.profile.cancelledRides.toLocaleString(phone.lang)
                }}</strong
                ><span>{{ phone.t('Apps.skyride.cancelledRides') }}</span>
              </div>
              <div>
                <strong>{{
                  skyride.profile.acceptanceRate === null
                    ? phone.t('Apps.skyride.notAvailable')
                    : `${skyride.profile.acceptanceRate}%`
                }}</strong
                ><span>{{ phone.t('Apps.skyride.acceptance') }}</span>
              </div>
            </k-card>
            <k-block-title>{{ phone.t('Apps.skyride.account') }}</k-block-title>
            <k-list inset strong>
              <k-list-item
                link
                :title="phone.t('Apps.skyride.editProfile')"
                :subtitle="phone.t('Apps.skyride.editProfileBody')"
                @click="openProfileEditor"
                ><template #media><Pencil :size="18" /></template
              ></k-list-item>
              <k-list-item
                :title="phone.t('Apps.skyride.paymentMethod')"
                :after="
                  paymentMethodLabel(skyride.profile.defaultPaymentMethod)
                "
                ><template #media><CircleDollarSign :size="18" /></template
              ></k-list-item>
              <k-list-item
                :title="phone.t('Apps.skyride.safety')"
                :subtitle="phone.t('Apps.skyride.safetyBody')"
                ><template #media><ShieldCheck :size="18" /></template
              ></k-list-item>
              <k-list-item
                v-if="skyride.driverEligible"
                :title="phone.t('Apps.skyride.driverMode')"
                :subtitle="phone.t('Apps.skyride.driverModeBody')"
                ><template #media><CarFront :size="18" /></template
                ><template #after
                  ><k-toggle
                    :checked="mode === 'driver'"
                    :disabled="Boolean(skyride.activeRide)"
                    :aria-label="phone.t('Apps.skyride.driverMode')"
                    @change="
                      mode = mode === 'driver' ? 'rider' : 'driver'
                    " /></template
              ></k-list-item>
            </k-list>
            <k-block class="skyride-member-note"
              ><Sparkles :size="17" /><span>{{
                phone.t('Apps.skyride.memberSince', {
                  date: formatDate(skyride.profile.memberSince),
                })
              }}</span></k-block
            >
          </section>
        </template>
      </div>

      <k-tabbar
        class="skyride-tabbar"
        floating
        :label="phone.t('Apps.skyride.navigation')"
      >
        <div class="skyride-tab-pane">
          <k-tabbar-link
            v-for="tab in tabs"
            :key="tab.id"
            :active="activeTab === tab.id"
            @click="selectTab(tab.id)"
          >
            <template #label>{{
              phone.t(`Apps.skyride.tabs.${tab.id}`)
            }}</template>
            <template #icon>
              <component :is="tab.icon" :size="23" :stroke-width="2" />
            </template>
          </k-tabbar-link>
        </div>
      </k-tabbar>
    </template>

    <SkySheet
      class="skyride-profile-sheet"
      :opened="profileEditorOpened"
      :aria-label="phone.t('Apps.skyride.editProfile')"
      swipe-to-close
      @backdropclick="closeProfileEditor"
      @escape="closeProfileEditor"
      @swipeclose="closeProfileEditor"
    >
      <section class="skyride-profile-editor">
        <div class="skyride-sheet__title">
          <div>
            <span>{{ phone.t('Apps.skyride.profile') }}</span>
            <h2>{{ phone.t('Apps.skyride.editProfile') }}</h2>
          </div>
          <SkyButton
            icon-only
            variant="plain"
            :aria-label="phone.t('Common.close')"
            @click="closeProfileEditor"
          >
            <X :size="20" />
          </SkyButton>
        </div>

        <div class="skyride-profile-editor__avatar">
          <div class="skyride-profile-avatar">
            <img v-if="profileAvatarUrl" :src="profileAvatarUrl" alt="" />
            <UserRound v-else :size="32" />
          </div>
          <strong>{{ phone.t('Apps.skyride.profilePhoto') }}</strong>
          <div>
            <SkyButton
              rounded
              class="skyride-profile-media-button"
              @click="openProfileMedia('photos')"
            >
              <Images :size="17" /> {{ phone.t('Apps.skyride.gallery') }}
            </SkyButton>
            <SkyButton
              rounded
              class="skyride-profile-media-button"
              @click="openProfileMedia('camera')"
            >
              <Camera :size="17" /> {{ phone.t('Apps.skyride.camera') }}
            </SkyButton>
          </div>
        </div>

        <SkySettingsGroup :title="phone.t('Apps.skyride.profileDetails')">
          <SkyField
            v-model="profileName"
            layout="inline"
            :label="phone.t('Apps.skyride.profileName')"
            :maxlength="50"
            :placeholder="phone.t('Apps.skyride.profileNamePlaceholder')"
            autocomplete="name"
          />
          <SkySettingsRow
            v-if="profileAvatarUrl"
            kind="action"
            tone="danger"
            :title="phone.t('Apps.skyride.removeProfilePhoto')"
            @activate="removeProfileAvatar"
          >
            <template #leading><Trash2 :size="18" /></template>
          </SkySettingsRow>
        </SkySettingsGroup>

        <div class="skyride-profile-editor__actions">
          <SkyButton
            block
            large
            rounded
            variant="secondary"
            @click="closeProfileEditor"
          >
            {{ phone.t('Common.cancel') }}
          </SkyButton>
          <SkyButton
            block
            large
            rounded
            :disabled="!canSaveProfile"
            @click="saveProfile"
          >
            <k-preloader v-if="skyride.isActionPending" />
            <template v-else>{{
              phone.t('Apps.skyride.saveProfile')
            }}</template>
          </SkyButton>
        </div>
      </section>
    </SkySheet>

    <k-sheet
      :opened="Boolean(locationTarget)"
      @backdropclick="locationTarget = null"
    >
      <section
        v-if="locationTarget"
        class="skyride-sheet__content"
        role="dialog"
        aria-modal="true"
        :aria-label="phone.t(`Apps.skyride.chooseLocation.${locationTarget}`)"
      >
        <div class="skyride-sheet__handle" aria-hidden="true"></div>
        <div class="skyride-sheet__title">
          <div>
            <span>{{ phone.t('Apps.skyride.location') }}</span>
            <h2>
              {{ phone.t(`Apps.skyride.chooseLocation.${locationTarget}`) }}
            </h2>
          </div>
          <k-link
            icon-only
            class="skyride-sheet__close"
            :aria-label="phone.t('Common.close')"
            @click="locationTarget = null"
            ><X :size="20"
          /></k-link>
        </div>
        <k-list inset strong class="skyride-sheet-list">
          <k-list-item
            link
            :title="phone.t('Apps.skyride.currentLocation')"
            :subtitle="phone.t('Apps.skyride.useGps')"
            @click="useCurrentLocation"
            ><template #media><Crosshair :size="19" /></template
          ></k-list-item>
        </k-list>
        <k-block-title class="skyride-sheet-section-title">{{
          phone.t('Apps.skyride.savedPlaces')
        }}</k-block-title>
        <k-list inset strong class="skyride-sheet-list skyride-saved-list">
          <k-list-item
            v-for="location in skyride.quickLocations"
            :key="location.id ?? location.label"
            link
            :title="locationLabel(location)"
            @click="chooseLocation(location)"
            ><template #media
              ><component
                :is="location.id === 'work' ? BriefcaseBusiness : MapPin"
                :size="18" /></template
          ></k-list-item>
        </k-list>
      </section>
    </k-sheet>

    <k-sheet :opened="Boolean(ratingRide)" @backdropclick="dismissRating">
      <section
        v-if="ratingRide"
        class="skyride-sheet__content skyride-rating"
        role="dialog"
        aria-modal="true"
        :aria-label="phone.t('Apps.skyride.rateRide')"
      >
        <div class="skyride-sheet__handle" aria-hidden="true"></div>
        <div class="skyride-rating__success"><CheckCircle2 :size="30" /></div>
        <h2>{{ phone.t('Apps.skyride.rideComplete') }}</h2>
        <p>{{ phone.t('Apps.skyride.rateRideBody') }}</p>
        <div
          class="skyride-rating-stars"
          :aria-label="phone.t('Apps.skyride.rating')"
        >
          <k-button
            v-for="value in 5"
            :key="value"
            small
            rounded
            variant="plain"
            class="skyride-rating-star"
            :class="{ 'is-active': value <= rating }"
            :aria-pressed="value <= rating"
            :aria-label="
              phone.t('Apps.skyride.ratingValue', { rating: value.toString() })
            "
            @click="rating = value"
          >
            <Star :size="28" fill="currentColor" />
          </k-button>
        </div>
        <span class="skyride-rating-label">{{
          phone.t('Apps.skyride.tip')
        }}</span>
        <div class="skyride-tip-options">
          <k-button
            v-for="value in [0, 5, 10, 20]"
            :key="value"
            small
            rounded
            :outline="tip !== value"
            @click="tip = value"
            >{{
              value === 0
                ? phone.t('Apps.skyride.noTip')
                : formatMoney(value, ratingRide.currency)
            }}</k-button
          >
        </div>
        <k-list inset strong
          ><k-list-input
            id="skyride-rating-comment"
            outline
            :label="phone.t('Apps.skyride.comment')"
            :placeholder="phone.t('Apps.skyride.commentPlaceholder')"
            :value="ratingComment"
            maxlength="180"
            @input="updateRatingComment"
        /></k-list>
        <k-button
          large
          rounded
          :disabled="rating < 1 || skyride.isActionPending"
          @click="submitRating"
          ><k-preloader v-if="skyride.isActionPending" /><template v-else>{{
            phone.t('Apps.skyride.submitRating')
          }}</template></k-button
        >
        <k-link @click="dismissRating">{{
          phone.t('Apps.skyride.notNow')
        }}</k-link>
      </section>
    </k-sheet>

    <k-dialog
      :opened="cancelDialogOpened"
      :title="phone.t('Apps.skyride.cancelTitle')"
      :content="phone.t('Apps.skyride.cancelBody')"
      role="alertdialog"
      @backdropclick="cancelDialogOpened = false"
      @escape="cancelDialogOpened = false"
    >
      <template #buttons
        ><k-dialog-button @click="cancelDialogOpened = false">{{
          phone.t('Common.cancel')
        }}</k-dialog-button
        ><k-dialog-button strong @click="confirmCancel">{{
          phone.t('Apps.skyride.cancelRide')
        }}</k-dialog-button></template
      >
    </k-dialog>

    <k-notification :opened="Boolean(toastText)" :text="toastText" />
  </k-page>
</template>

<style scoped>
.skyride-app {
  --ride-accent: #f5c518;
  --ride-accent-strong: #725600;
  --ride-bg-rgb: 244 244 247;
  --ride-bg: #f4f4f7;
  --ride-card: rgba(255, 255, 255, 0.88);
  --ride-card-strong: #fff;
  --ride-border: rgba(26, 26, 28, 0.09);
  --ride-text: #171719;
  --ride-muted: #707078;
  --ride-map: #07131f;
  --ride-profile-media-bg: #725600;
  --sky-bg: var(--ride-bg);
  --sky-surface: var(--ride-card-strong);
  --sky-surface-muted: #e6e6eb;
  --sky-text: var(--ride-text);
  --sky-muted: var(--ride-muted);
  --sky-hairline: var(--ride-border);
  --sky-danger: #d70015;
  position: relative;
  height: 100%;
  overflow: hidden;
  color: var(--ride-text);
  background: var(--ride-bg);
}

.skyride-app--dark {
  --ride-accent-strong: #f5c518;
  --ride-bg-rgb: 8 9 11;
  --ride-bg: #08090b;
  --ride-card: rgba(29, 30, 33, 0.9);
  --ride-card-strong: #1c1d20;
  --ride-border: rgba(255, 255, 255, 0.09);
  --ride-text: #f7f7f8;
  --ride-muted: #a2a2aa;
  --ride-map: #050a10;
  --ride-profile-media-bg: #9b7600;
  --sky-surface-muted: #2c2c2e;
  --sky-danger: #ff453a;
}

.skyride-ambient {
  position: absolute;
  inset: 0;
  pointer-events: none;
  background:
    radial-gradient(
      circle at 82% 10%,
      rgba(245, 197, 24, 0.16),
      transparent 28%
    ),
    linear-gradient(180deg, rgba(245, 197, 24, 0.04), transparent 32%);
}

.skyride-navbar {
  --k-safe-area-top: 56px;
  z-index: 22;
  position: relative;
  color: var(--ride-text);
}

.skyride-navbar :deep(.sky-navbar__blur),
.skyride-navbar :deep(.sky-navbar__background) {
  display: none;
}

.skyride-navbar :deep(.sky-navbar__title) {
  color: var(--ride-text);
  font-size: 18px;
  font-weight: 700;
  line-height: 20px;
  letter-spacing: -0.25px;
}

.skyride-navbar :deep(.sky-navbar__subtitle) {
  margin-top: 1px;
  color: var(--ride-muted);
  font-size: 12px;
  font-weight: 600;
  line-height: 14px;
  opacity: 1;
}

.skyride-mode {
  z-index: 21;
  position: relative;
  min-height: 9px;
  padding: 4px 16px 7px;
}

.skyride-mode > :deep(*) {
  width: 100%;
}

.skyride-mode :deep(button) {
  min-height: 38px;
  font-size: 15px;
  font-weight: 600;
}

.skyride-scroll {
  position: absolute;
  z-index: 2;
  box-sizing: border-box;
  inset: 114px 0 0;
  padding: 0 0 116px;
  overflow-x: hidden;
  overflow-y: auto;
  overscroll-behavior: contain;
  scrollbar-width: none;
}

.skyride-scroll::-webkit-scrollbar {
  display: none;
}

.skyride-loading,
.skyride-unavailable {
  position: absolute;
  z-index: 4;
  inset: 92px 24px 72px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-direction: column;
  gap: 12px;
  margin: 0;
  text-align: center;
}

.skyride-unavailable {
  padding: 24px;
  border: 1px solid var(--ride-border);
  border-radius: 22px;
  background: var(--ride-card);
}

.skyride-loading span,
.skyride-unavailable p {
  color: var(--ride-muted);
}

.skyride-unavailable strong {
  font-size: 20px;
}

.skyride-unavailable p {
  margin: 0;
  font-size: 13px;
}

.skyride-home-panel,
.skyride-section-screen {
  position: relative;
  z-index: 4;
  padding: 18px 14px 24px;
}

.skyride-home-panel {
  min-height: 320px;
  margin-top: 0;
  background: linear-gradient(
    180deg,
    rgb(var(--ride-bg-rgb) / 0) 0,
    rgb(var(--ride-bg-rgb) / 0.78) 54px,
    var(--ride-bg) 112px
  );
}

.skyride-heading,
.skyride-screen-title {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin: 0;
  padding: 0 4px 12px;
}

.skyride-heading span,
.skyride-screen-title p,
.skyride-ride-status-card p {
  margin: 0;
  color: var(--ride-muted);
  font-size: 13px;
  line-height: 18px;
}

.skyride-heading h1,
.skyride-ride-status-card h1,
.skyride-screen-title h1 {
  margin: 2px 0 0;
  color: var(--ride-text);
  font-size: 24px;
  font-weight: 700;
  line-height: 28px;
  letter-spacing: -0.55px;
}

.skyride-heading__icon,
.skyride-status-icon {
  display: grid;
  flex: 0 0 auto;
  width: 42px;
  height: 42px;
  place-items: center;
  border-radius: 15px;
  color: #111;
  background: var(--ride-accent);
  box-shadow: none;
}

.skyride-heading__icon > svg {
  display: block;
  width: 20px;
  height: 20px;
}

.skyride-status-icon.is-searching {
  color: var(--ride-accent-strong);
  background: rgba(245, 197, 24, 0.14);
  box-shadow: none;
}

.skyride-location-list,
.skyride-service-list,
.skyride-activity-list,
.skyride-sheet__content :deep(.sky-list),
.skyride-profile :deep(.sky-list) {
  margin-block: 0 14px;
}

.skyride-location-list,
.skyride-activity-list {
  margin-inline: 2px !important;
}

.skyride-location-list :deep(li),
.skyride-service-list :deep(li),
.skyride-activity-list :deep(li),
.skyride-profile :deep(li),
.skyride-sheet__content :deep(li) {
  background: var(--ride-card-strong);
}

.skyride-dot {
  display: block;
  width: 11px;
  height: 11px;
  border: 3px solid var(--ride-accent);
  border-radius: 50%;
  background: #171719;
}

.skyride-quick-grid,
.skyride-driver-metrics {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 9px;
  margin: 0 2px 16px;
  padding: 0;
}

.skyride-custom-block-title {
  height: auto !important;
  margin: 20px 4px 10px !important;
  padding: 0 !important;
  color: var(--ride-muted) !important;
  font-size: 15px !important;
  font-weight: 650 !important;
  line-height: 20px !important;
}

.skyride-quick-card,
.skyride-driver-metrics :deep(.sky-card),
.skyride-person-card,
.skyride-trip-card,
.skyride-driver-status,
.skyride-request-card,
.skyride-history-card,
.skyride-message-contact,
.skyride-empty-card,
.skyride-fare-card,
.skyride-ride-status-card {
  margin: 0;
  border: 1px solid var(--ride-border);
  color: var(--ride-text);
  background: var(--ride-card);
  box-shadow: 0 7px 23px rgba(0, 0, 0, 0.05);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
}

.skyride-ride-status-card {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 12px;
  padding: 15px;
  background:
    linear-gradient(135deg, rgba(245, 197, 24, 0.12), transparent 58%),
    var(--ride-card);
}

.skyride-ride-status-card > div {
  min-width: 0;
}

.skyride-ride-status-card small {
  color: var(--ride-accent-strong);
  font-size: 9px;
  font-weight: 750;
  text-transform: uppercase;
  letter-spacing: 0.9px;
}

.skyride-ride-status-card h1 {
  margin: 2px 0;
  font-size: 20px;
  line-height: 1.05;
}

.skyride-ride-status-card p {
  line-height: 1.3;
}

.skyride-quick-card {
  display: flex;
  width: 100%;
  min-height: 64px;
  align-items: center;
  justify-content: flex-start;
  gap: 10px;
  padding: 11px 13px;
  color: inherit;
  text-align: left;
}

.skyride-quick-card svg,
.skyride-driver-metrics svg {
  color: var(--ride-accent-strong);
}

.skyride-quick-card span {
  display: -webkit-box;
  min-width: 0;
  overflow: hidden;
  font-size: 12.5px;
  font-weight: 650;
  line-height: 16px;
  overflow-wrap: anywhere;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}

.skyride-primary {
  width: calc(100% - 4px);
  min-height: 50px;
  margin: 4px 2px 0;
  gap: 5px;
  font-size: 16px;
  font-weight: 650;
}

.skyride-player-driver-notice {
  margin: 2px 7px 8px;
  color: var(--ride-muted);
  font-size: 12px;
  line-height: 17px;
}

.skyride-primary :deep(svg) {
  margin-left: 4px;
}

.skyride-quote-summary {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 0 5px 12px;
  color: var(--ride-muted);
  font-size: 12px;
}

.skyride-quote-chip {
  min-width: 0;
  padding-inline: 8px;
  color: var(--ride-muted);
  font-size: 10px;
}

.skyride-quote-summary :deep(button) {
  margin-left: auto;
}

.skyride-service-list :deep(li.is-selected) {
  box-shadow: inset 3px 0 var(--ride-accent);
}

.skyride-service-list :deep(li.is-unavailable) {
  cursor: default;
  opacity: 0.45;
}

.skyride-service-list :deep(.sky-list-item__after) {
  display: flex;
  align-items: center;
  gap: 6px;
  color: var(--ride-text);
}

.skyride-fare-card {
  margin: 0 0 13px;
  padding: 14px;
}

.skyride-fare-card__heading {
  display: grid;
  grid-template-columns: auto 1fr auto;
  align-items: center;
  gap: 10px;
  margin-bottom: 11px;
}

.skyride-fare-card__icon {
  display: grid;
  width: 36px;
  height: 36px;
  place-items: center;
  border-radius: 12px;
  color: #151515;
  background: var(--ride-accent);
}

.skyride-fare-card__heading > div {
  display: flex;
  min-width: 0;
  flex-direction: column;
}

.skyride-fare-card__heading small,
.skyride-fare-card__heading > span:last-child,
.skyride-fare-breakdown span {
  color: var(--ride-muted);
  font-size: 10px;
}

.skyride-fare-card__heading strong {
  font-size: 17px;
}

.skyride-fare-card__heading > span:last-child {
  max-width: 96px;
  text-align: right;
}

.skyride-fare-card > :deep(.sky-segmented) {
  width: 100%;
}

.skyride-fare-breakdown {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  margin-top: 11px;
  padding: 10px 11px;
  border-radius: 12px;
  background: var(--ride-border);
}

.skyride-custom-fare {
  display: grid;
  gap: 8px;
  margin-top: 10px;
}

.skyride-custom-fare :deep(.sky-list) {
  margin: 0;
}

.skyride-custom-fare > :deep(button) {
  width: 100%;
}

.skyride-service-icon,
.skyride-activity-icon {
  display: grid;
  width: 36px;
  height: 36px;
  place-items: center;
  border-radius: 12px;
  color: #151515;
  background: var(--ride-accent);
}

.skyride-person-card,
.skyride-message-contact {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 10px;
  padding: 16px;
}

.skyride-person-card {
  margin-bottom: 12px;
}

.skyride-avatar,
.skyride-profile-avatar {
  display: grid;
  flex: 0 0 auto;
  width: 46px;
  height: 46px;
  place-items: center;
  overflow: hidden;
  border: 2px solid var(--ride-accent);
  border-radius: 50%;
  color: var(--ride-muted);
  background: var(--ride-bg);
}

.skyride-avatar img,
.skyride-profile-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.skyride-person-card__body,
.skyride-message-contact > div:nth-child(2) {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 2px;
}

.skyride-person-card__body > span,
.skyride-message-contact > div:nth-child(2) span {
  display: flex;
  align-items: center;
  gap: 3px;
  color: var(--ride-muted);
  font-size: 12px;
}

.skyride-person-card__body b {
  width: fit-content;
  margin-top: 2px;
  padding: 2px 6px;
  border-radius: 5px;
  color: var(--ride-text);
  background: var(--ride-border);
  font-size: 10px;
  letter-spacing: 0.8px;
}

.skyride-contact-actions,
.skyride-active-actions,
.skyride-driver-actions,
.skyride-contact-buttons {
  display: flex;
  gap: 8px;
}

.skyride-contact-actions {
  flex: 0 0 auto;
  margin-left: auto;
}

.skyride-contact-actions :deep(button) {
  width: 36px;
  min-width: 36px;
  flex: 0 0 36px;
  padding-inline: 0;
}

.skyride-trip-card {
  margin-bottom: 12px;
  padding: 16px;
}

.skyride-route-stop {
  display: grid;
  grid-template-columns: 18px minmax(0, 1fr);
  align-items: center;
  column-gap: 11px;
}

.skyride-route-stop > .skyride-dot {
  justify-self: center;
}

.skyride-route-stop > svg {
  width: 18px;
  height: 18px;
  color: var(--ride-accent-strong);
}

.skyride-route-stop > div {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 1px;
}

.skyride-route-stop small,
.skyride-person-card small {
  color: var(--ride-muted);
  font-size: 10px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.skyride-route-stop strong {
  overflow: hidden;
  font-size: 13px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.skyride-trip-card > i {
  display: block;
  width: 1px;
  height: 17px;
  margin: 1px 0 1px 8px;
  border-left: 1px dashed var(--ride-muted);
}

.skyride-trip-meta {
  display: flex;
  justify-content: space-between;
  margin-top: 13px;
  padding-top: 11px;
  border-top: 1px solid var(--ride-border);
  color: var(--ride-muted);
  font-size: 12px;
}

.skyride-trip-meta strong {
  color: var(--ride-text);
  font-size: 14px;
}

.skyride-active-actions > *,
.skyride-driver-actions > *,
.skyride-contact-buttons > * {
  flex: 1;
}

.skyride-active-actions :deep(button),
.skyride-driver-actions :deep(button),
.skyride-contact-buttons :deep(button) {
  gap: 6px;
}

.skyride-safety-note,
.skyride-member-note {
  display: flex;
  align-items: center;
  gap: 8px;
  margin: 12px 2px 0;
  color: var(--ride-muted);
  font-size: 11px;
  line-height: 1.35;
}

.skyride-safety-note svg,
.skyride-member-note svg {
  flex: 0 0 auto;
  color: var(--ride-accent-strong);
}

.skyride-driver-status {
  display: grid;
  grid-template-columns: auto 1fr auto;
  align-items: center;
  gap: 11px;
  margin-bottom: 14px;
  padding: 16px;
}

.skyride-driver-status__icon {
  display: grid;
  width: 42px;
  height: 42px;
  place-items: center;
  border-radius: 14px;
  color: var(--ride-muted);
  background: var(--ride-border);
}

.skyride-driver-status__icon.is-online {
  color: #151515;
  background: var(--ride-accent);
}

.skyride-driver-status > div:nth-child(2) {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 2px;
}

.skyride-driver-status span,
.skyride-driver-metrics span,
.skyride-request-card span,
.skyride-history-card span {
  color: var(--ride-muted);
  font-size: 12px;
  line-height: 16px;
}

.skyride-driver-metrics :deep(.sky-card) {
  display: flex;
  flex-direction: column;
  gap: 3px;
  padding: 16px;
}

.skyride-driver-metrics strong {
  margin-top: 3px;
  font-size: 19px;
}

.skyride-request-list,
.skyride-history-list {
  display: grid;
  gap: 10px;
}

.skyride-history-list {
  margin: 0;
  padding: 0;
}

.skyride-request-card__top,
.skyride-history-card__header {
  display: flex;
  align-items: center;
  gap: 9px;
}

.skyride-request-card__top > div,
.skyride-history-card__header > div {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
}

.skyride-request-card__top > div > span,
.skyride-history-card__header > div > span {
  font-size: 11px;
  line-height: 15px;
}

.skyride-request-route,
.skyride-history-route {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
  align-items: center;
  gap: 6px;
  margin: 12px 0;
  padding: 9px;
  border-radius: 11px;
  background: var(--ride-border);
}

.skyride-request-route span,
.skyride-history-route span {
  overflow: hidden;
  font-size: 12px;
  line-height: 16px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.skyride-request-route span:last-child,
.skyride-history-route span:last-child {
  text-align: right;
}

.skyride-empty-card {
  display: flex;
  align-items: center;
  flex-direction: column;
  gap: 7px;
  padding: 27px 16px;
  text-align: center;
}

.skyride-empty-card svg {
  color: var(--ride-accent-strong);
}

.skyride-empty-card p {
  max-width: 250px;
  margin: 0;
  color: var(--ride-muted);
  font-size: 12px;
  line-height: 1.45;
}

.skyride-screen-title {
  justify-content: flex-start;
  margin: 0 0 8px;
}

.skyride-screen-title > svg {
  color: var(--ride-accent-strong);
}

.skyride-history-card__footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  font-size: 12px;
}

.skyride-history-card__meta {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 2px;
}

.skyride-history-card__distance {
  display: inline-flex;
  align-items: center;
  gap: 4px;
}

.skyride-history-card__distance > svg {
  flex: 0 0 auto;
  color: var(--ride-accent-strong);
}

.skyride-message-contact > svg {
  color: var(--ride-muted);
}

.skyride-contact-buttons {
  margin: 10px 0 0;
  padding: 0;
}

.skyride-profile-hero {
  display: flex;
  align-items: center;
  flex-direction: column;
  padding: 8px 0 18px;
}

.skyride-profile-avatar {
  width: 78px;
  height: 78px;
  border-width: 3px;
  box-shadow: 0 0 0 5px rgba(245, 197, 24, 0.13);
}

button.skyride-profile-avatar--editable {
  position: relative;
  padding: 0;
  cursor: pointer;
  font: inherit;
}

.skyride-profile-avatar--editable:focus-visible {
  outline: 3px solid var(--ride-accent-strong);
  outline-offset: 5px;
}

.skyride-profile-avatar--editable > span {
  position: absolute;
  right: -1px;
  bottom: -1px;
  display: grid;
  width: 25px;
  height: 25px;
  place-items: center;
  border: 2px solid var(--ride-bg);
  border-radius: 50%;
  color: #171719;
  background: var(--ride-accent);
}

.skyride-profile-hero h1 {
  margin: 12px 0 3px;
  font-size: 22px;
}

.skyride-profile-hero > span {
  display: flex;
  align-items: center;
  gap: 4px;
  color: var(--ride-accent-strong);
  font-weight: 700;
}

.skyride-profile-stats {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  margin-bottom: 17px;
  padding: 13px 4px;
  border: 1px solid var(--ride-border);
  border-radius: 17px;
  background: var(--ride-card);
  box-shadow: 0 7px 23px rgba(0, 0, 0, 0.05);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
}

.skyride-profile-stats > div {
  display: flex;
  min-width: 0;
  align-items: center;
  flex-direction: column;
  gap: 2px;
  padding-inline: 4px;
  text-align: center;
}

.skyride-profile-stats > div + div {
  border-left: 1px solid var(--ride-border);
}

.skyride-profile-stats strong {
  font-size: 16px;
}

.skyride-profile-stats span {
  color: var(--ride-muted);
  font-size: 9px;
  line-height: 1.15;
}

.skyride-tabbar {
  z-index: 25;
  color: var(--ride-text);
}

.skyride-tabbar :deep(.sky-tabbar__inner),
.skyride-tabbar :deep(.sky-tabbar__pane) {
  width: 100% !important;
  max-width: none !important;
  gap: 0 !important;
}

.skyride-tabbar :deep(.sky-tabbar__blur),
.skyride-tabbar :deep(.sky-tabbar__background) {
  display: none;
}

.skyride-tab-pane {
  width: 100% !important;
  max-width: none !important;
  display: flex;
  align-items: stretch;
  gap: 0 !important;
}

.skyride-tab-pane :deep(> .sky-tab-button) {
  flex: 1 1 20%;
  min-width: 0 !important;
  padding-inline: 1px !important;
  outline: none;
}

.skyride-tab-pane :deep(> .sky-tab-button .sky-tab-button__label) {
  max-width: 100%;
  overflow: hidden;
  font-size: 10px;
  font-weight: 600;
  line-height: 13px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.skyride-tab-pane :deep(> .sky-tab-button .sky-tab-button__icon) {
  width: 24px;
  height: 24px;
}

.skyride-tab-pane :deep(> .sky-tab-button .sky-tab-button__icon > svg) {
  display: block;
  width: 23px;
  height: 23px;
}

.skyride-sheet__content {
  max-height: 74vh;
  overflow-y: auto;
  padding: 8px 14px calc(24px + env(safe-area-inset-bottom));
  color: var(--ride-text);
  background: var(--ride-bg);
  border-radius: 26px 26px 0 0;
}

.skyride-profile-editor {
  box-sizing: border-box;
  min-height: 0;
  padding: 4px 14px calc(var(--sky-safe-area-bottom) + 12px);
  color: var(--ride-text);
  background: var(--ride-bg);
  border-radius: 0 0 28px 28px;
}

.skyride-profile-sheet :deep(.sky-overlay-backdrop) {
  background: rgba(0, 0, 0, 0.38);
}

.skyride-profile-sheet :deep(.sky-sheet__panel) {
  top: auto;
  max-height: 78%;
  overflow-x: hidden;
  overflow-y: auto;
  border: 0;
  border-radius: 28px 28px 0 0;
  background: var(--ride-bg);
  box-shadow: none;
}

.skyride-profile-editor__avatar {
  display: flex;
  align-items: center;
  flex-direction: column;
  gap: 11px;
  padding: 8px 0 18px;
}

.skyride-profile-editor__avatar > strong {
  font-size: 14px;
}

.skyride-profile-editor__avatar > div:last-child,
.skyride-profile-editor__actions {
  display: flex;
  width: 100%;
  gap: 9px;
}

.skyride-profile-editor__avatar > div:last-child {
  justify-content: center;
}

.skyride-profile-editor__avatar :deep(.sky-button) {
  gap: 6px;
}

.skyride-profile-editor__avatar :deep(.skyride-profile-media-button) {
  border-color: var(--ride-profile-media-bg);
  background: var(--ride-profile-media-bg);
  color: #fff !important;
}

.skyride-profile-editor__avatar
  :deep(.skyride-profile-media-button:active:not(:disabled)) {
  border-color: var(--ride-profile-media-bg);
  background: var(--ride-profile-media-bg);
  color: #fff !important;
  filter: brightness(0.9);
}

.skyride-profile-editor__actions {
  margin-top: 4px;
}

.skyride-profile-editor__actions :deep(.sky-button) {
  flex: 1 1 0;
}

.skyride-sheet__handle {
  width: 38px;
  height: 5px;
  margin: 0 auto 14px;
  border-radius: 9px;
  background: var(--ride-muted);
  opacity: 0.65;
}

.skyride-sheet__title {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin: 0 4px 13px;
}

.skyride-sheet__title span,
.skyride-rating-label {
  color: var(--ride-muted);
  font-size: 11px;
  font-weight: 650;
  line-height: 14px;
  text-transform: uppercase;
  letter-spacing: 0.65px;
}

.skyride-sheet__title h2,
.skyride-rating h2 {
  margin: 3px 0 0;
  color: var(--ride-text);
  font-size: 22px;
  font-weight: 700;
  line-height: 27px;
  letter-spacing: -0.35px;
}

.skyride-sheet__close {
  display: grid;
  flex: 0 0 auto;
  width: 40px;
  height: 40px;
  margin-right: -8px;
  place-items: center;
  border-radius: 50%;
}

.skyride-sheet-list {
  margin-block: 0 !important;
}

.skyride-sheet-list :deep(.text-\[17px\]) {
  color: var(--ride-text);
  font-size: 16px;
  line-height: 21px;
}

.skyride-sheet-list :deep(.text-sm) {
  color: var(--ride-muted);
  font-size: 13px;
  line-height: 18px;
}

.skyride-sheet-section-title {
  height: auto !important;
  margin: 22px 4px 10px !important;
  padding: 0 !important;
  color: var(--ride-muted) !important;
  font-size: 15px !important;
  font-weight: 650 !important;
  line-height: 20px !important;
}

.skyride-saved-list {
  margin-bottom: 4px !important;
}

.skyride-rating {
  display: flex;
  align-items: center;
  flex-direction: column;
  text-align: center;
}

.skyride-rating__success {
  display: grid;
  width: 56px;
  height: 56px;
  place-items: center;
  border-radius: 20px;
  color: #151515;
  background: var(--ride-accent);
}

.skyride-rating p {
  max-width: 270px;
  margin: 4px 0 12px;
  color: var(--ride-muted);
  font-size: 12px;
}

.skyride-rating-stars {
  display: flex;
  gap: 5px;
  margin-bottom: 17px;
}

.skyride-rating-star {
  width: 34px;
  min-width: 34px;
  height: 34px;
  padding: 2px;
  color: var(--ride-border);
}

.skyride-rating-star.is-active {
  color: var(--ride-accent);
}

.skyride-tip-options {
  display: flex;
  gap: 6px;
  margin: 8px 0 12px;
}

.skyride-rating :deep(.sky-list) {
  width: 100%;
}

.skyride-rating > :deep(button) {
  width: 100%;
}

.skyride-rating > :deep(a),
.skyride-rating > :deep(.sky-link) {
  margin-top: 11px;
}

.skyride-dialog {
  padding: 20px 20px 8px;
  color: var(--ride-text);
  text-align: center;
}

.skyride-dialog h2 {
  margin: 0 0 7px;
  font-size: 18px;
}

.skyride-dialog p {
  margin: 0;
  color: var(--ride-muted);
  font-size: 13px;
  line-height: 1.4;
}

.skyride-app :deep(.bg-primary) {
  color: #141414;
  background-color: var(--ride-accent);
}

.skyride-app :deep(.sky-button--primary:not(.sky-button--outline)) {
  color: #171719;
}

.skyride-app :deep(.text-primary) {
  color: var(--ride-accent-strong);
}

.skyride-app--dark :deep(.text-primary) {
  color: var(--ride-accent);
}

@media (max-height: 730px) {
  .skyride-home-panel,
  .skyride-section-screen {
    padding-top: 14px;
  }
}
</style>
