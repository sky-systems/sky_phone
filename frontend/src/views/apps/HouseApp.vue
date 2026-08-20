<script setup lang="ts">
import {
  Camera,
  CarFront,
  Check,
  House,
  KeyRound,
  LocateFixed,
  Lock,
  LockOpen,
  Plus,
  Router,
  Share2,
  UserRound,
  UsersRound,
  WifiOff,
} from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

import { usePullToRefresh } from '@/composables/usePullToRefresh'
import { useEasyShareStore } from '@/stores/easyshare'
import { useHousingStore } from '@/stores/housing'
import { usePhoneStore } from '@/stores/phone'
import type {
  HousingKey,
  HousingKeyCandidate,
  HousingProperty,
} from '@/types/housing'
import {
  SkyAppPage,
  SkyBlockTitle,
  SkyButton,
  SkyCard,
  SkyDialog,
  SkyDialogButton,
  SkyList,
  SkyListItem,
  SkyNavbar,
  SkySheet,
  SkySpinner,
  SkyNotification,
} from '@/ui'

const phone = usePhoneStore()
const housing = useHousingStore()
const easyShare = useEasyShareStore()
const selectedPropertyId = ref<string | null>(null)
const candidatesOpened = ref(false)
const revokeCandidate = ref<HousingKey | null>(null)
const toastOpened = ref(false)
const toastText = ref('')
const houseScroll = ref<HTMLElement | null>(null)
let toastTimer: number | undefined

const {
  finishPull,
  movePull,
  pullDistance,
  pullThreshold,
  pullWithWheel: updatePullWithWheel,
  refresh,
  startPull,
} = usePullToRefresh({
  isAtTop: () => (houseScroll.value?.scrollTop ?? 0) <= 0,
  refresh: async () => {
    const loaded = await housing.load(true)
    if (!loaded && housing.error === 'reload_cooldown') {
      showToast(translatedError(housing.error))
    }
  },
})

const properties = computed(() => housing.overview?.properties ?? [])
const ownedCount = computed(
  () =>
    properties.value.filter((property) => property.access === 'owner').length,
)
const sharedCount = computed(() => properties.value.length - ownedCount.value)
const lockedCount = computed(
  () => properties.value.filter((property) => property.locked).length,
)
const selectedProperty = computed(
  () =>
    properties.value.find(
      (property) => property.id === selectedPropertyId.value,
    ) ?? null,
)

function translatedError(error: string): string {
  const key = `Apps.house.errors.${error}`
  const translated = phone.t(key)
  return translated === key ? phone.t('Apps.house.errors.default') : translated
}

function showToast(message: string): void {
  if (toastTimer) clearTimeout(toastTimer)
  toastText.value = message
  toastOpened.value = true
  toastTimer = window.setTimeout(() => {
    toastOpened.value = false
  }, 2400)
}

function isPending(action: string, property: HousingProperty): boolean {
  return housing.pendingAction === `${action}:${property.id}`
}

function pullWithWheel(event: WheelEvent): void {
  if (!updatePullWithWheel(event)) return
  if (toastTimer) clearTimeout(toastTimer)
}

async function runCommand(
  action: 'open_cctv' | 'set_waypoint' | 'toggle_lock',
  property: HousingProperty,
): Promise<void> {
  if (!(await housing.command(action, property.id))) {
    showToast(translatedError(housing.error))
    return
  }
  const successKeys = {
    open_cctv: 'cameraStarting',
    set_waypoint: 'waypointSuccess',
    toggle_lock: 'lockSuccess',
  } as const
  showToast(phone.t(`Apps.house.${successKeys[action]}`))
}

async function openKeyCandidates(property: HousingProperty): Promise<void> {
  candidatesOpened.value = true
  if (!(await housing.loadKeyCandidates(property.id))) {
    showToast(translatedError(housing.error))
  }
}

async function grantKey(candidate: HousingKeyCandidate): Promise<void> {
  const property = selectedProperty.value
  if (!property) return
  if (
    !(await housing.command('grant_key', property.id, { target: candidate.id }))
  ) {
    showToast(translatedError(housing.error))
    return
  }
  candidatesOpened.value = false
  showToast(phone.t('Apps.house.keyGranted'))
}

async function revokeKey(): Promise<void> {
  const property = selectedProperty.value
  const key = revokeCandidate.value
  if (!property || !key) return
  if (
    !(await housing.command('revoke_key', property.id, {
      identifier: key.identifier,
    }))
  ) {
    showToast(translatedError(housing.error))
    return
  }
  revokeCandidate.value = null
  showToast(phone.t('Apps.house.keyRevoked'))
}

function accessLabel(property: HousingProperty): string {
  return phone.t(
    property.access === 'owner' ? 'Apps.house.owner' : 'Apps.house.keyholder',
  )
}

function propertySubtitle(property: HousingProperty): string {
  const details = [accessLabel(property)]
  if (property.garage?.enabled) {
    details.push(
      phone.t('Apps.house.storedVehicles', {
        count: String(property.garage.storedVehicles),
      }),
    )
  }
  return details.join(' · ')
}

function shareProperty(property: HousingProperty): void {
  easyShare.open({
    appId: 'house',
    copyText: property.name,
    id: property.id,
    kind: 'document',
    link: `skyphone://house/property/${property.id}`,
    subtitle: accessLabel(property),
    title: property.name,
  })
}

onMounted(() => {
  void housing.load()
})

onBeforeUnmount(() => {
  if (toastTimer) clearTimeout(toastTimer)
})
</script>

<template>
  <sky-app-page component="main" class="house-page">
    <sky-navbar
      class="house-navbar"
      :subtitle="phone.t('Apps.house.subtitle')"
      :title="phone.t('Apps.house.name')"
    />

    <div v-if="housing.isLoading && !housing.overview" class="house-state">
      <sky-spinner />
      <span>{{ phone.t('Common.loading') }}</span>
    </div>

    <div v-else-if="!housing.overview" class="house-state">
      <span class="house-state__icon"><WifiOff :size="30" /></span>
      <strong>{{ phone.t('Apps.house.unavailable') }}</strong>
      <p>{{ translatedError(housing.error) }}</p>
      <sky-button
        rounded
        style="--sky-app-accent: var(--house-accent)"
        @click="refresh"
      >
        {{ phone.t('Apps.house.tryAgain') }}
      </sky-button>
    </div>

    <div v-else-if="!housing.overview.available" class="house-state">
      <span class="house-state__icon"><Router :size="31" /></span>
      <strong>{{ phone.t('Apps.house.offline') }}</strong>
      <p>{{ phone.t('Apps.house.offlineBody') }}</p>
      <sky-button
        rounded
        style="--sky-app-accent: var(--house-accent)"
        @click="refresh"
      >
        {{ phone.t('Apps.house.tryAgain') }}
      </sky-button>
    </div>

    <div
      v-else
      ref="houseScroll"
      class="house-scroll"
      @touchend="finishPull"
      @touchmove.passive="movePull"
      @touchstart.passive="startPull"
      @wheel="pullWithWheel"
    >
      <div
        class="house-pull-refresh"
        :class="{ 'is-visible': pullDistance > 0 }"
        :style="{ transform: `translateY(${pullDistance - pullThreshold}px)` }"
        aria-live="polite"
      >
        <sky-spinner />
      </div>
      <section v-if="properties.length" class="house-properties">
        <div class="house-overview" :aria-label="phone.t('Apps.house.myHomes')">
          <span
            ><b>{{ ownedCount }}</b
            >{{ phone.t('Apps.house.owned') }}</span
          >
          <span
            ><b>{{ sharedCount }}</b
            >{{ phone.t('Apps.house.shared') }}</span
          >
          <span
            ><b>{{ lockedCount }}</b
            >{{ phone.t('Apps.house.locked') }}</span
          >
        </div>

        <sky-list inset strong class="house-property-list">
          <sky-list-item
            v-for="property in properties"
            :key="property.id"
            link
            chevron
            :title="property.name"
            :subtitle="propertySubtitle(property)"
            :aria-label="`${phone.t('Apps.house.openDetails')}: ${property.name}`"
            @click="selectedPropertyId = property.id"
          >
            <template #media>
              <span class="house-property__icon"><House :size="21" /></span>
            </template>
            <template #after>
              <span
                v-if="property.capabilities.lock"
                class="house-property__status"
                :class="{ 'is-locked': property.locked }"
              >
                <Lock v-if="property.locked" :size="13" />
                <LockOpen v-else :size="13" />
                {{
                  phone.t(
                    property.locked
                      ? 'Apps.house.locked'
                      : 'Apps.house.unlocked',
                  )
                }}
              </span>
            </template>
          </sky-list-item>
        </sky-list>
      </section>

      <section v-else class="house-empty">
        <span class="house-empty__icon"><House :size="32" /></span>
        <small>{{ phone.t('Apps.house.myHomes') }}</small>
        <h1>{{ phone.t('Apps.house.empty') }}</h1>
        <p>{{ phone.t('Apps.house.emptyBody') }}</p>
        <sky-button
          inline
          rounded
          style="--sky-app-accent: var(--house-accent)"
          @click="refresh"
        >
          {{ phone.t('Apps.house.refresh') }}
        </sky-button>
      </section>
    </div>

    <sky-sheet
      :opened="Boolean(selectedProperty)"
      class="house-detail-sheet"
      grabber-clickable
      :grabber-label="phone.t('Common.close')"
      swipe-to-close
      @backdropclick="selectedPropertyId = null"
      @escape="selectedPropertyId = null"
      @grabberclick="selectedPropertyId = null"
      @swipeclose="selectedPropertyId = null"
    >
      <section v-if="selectedProperty" class="house-detail">
        <span class="house-detail__mark"><House :size="29" /></span>
        <small>{{ accessLabel(selectedProperty) }}</small>
        <h2>{{ selectedProperty.name }}</h2>
        <span
          v-if="selectedProperty.capabilities.lock"
          class="house-detail__status"
          :class="{ 'is-locked': selectedProperty.locked }"
        >
          <Lock v-if="selectedProperty.locked" :size="14" />
          <LockOpen v-else :size="14" />
          {{
            phone.t(
              selectedProperty.locked
                ? 'Apps.house.locked'
                : 'Apps.house.unlocked',
            )
          }}
        </span>

        <sky-button
          v-if="selectedProperty.capabilities.lock"
          large
          rounded
          class="house-lock-button"
          :disabled="isPending('toggle_lock', selectedProperty)"
          @click="runCommand('toggle_lock', selectedProperty)"
        >
          <LockOpen v-if="selectedProperty.locked" :size="19" />
          <Lock v-else :size="19" />
          {{
            phone.t(
              selectedProperty.locked
                ? 'Apps.house.unlockDoor'
                : 'Apps.house.lockDoor',
            )
          }}
        </sky-button>

        <sky-block-title>{{ phone.t('Apps.house.actions') }}</sky-block-title>
        <sky-list inset strong class="house-action-list">
          <sky-list-item
            link
            chevron
            :title="phone.t('Apps.house.setWaypoint')"
            :disabled="isPending('set_waypoint', selectedProperty)"
            @click="runCommand('set_waypoint', selectedProperty)"
          >
            <template #media><LocateFixed :size="19" /></template>
          </sky-list-item>
          <sky-list-item
            :link="selectedProperty.capabilities.cctv"
            :chevron="selectedProperty.capabilities.cctv"
            :title="phone.t('Apps.house.viewCamera')"
            :subtitle="
              phone.t(
                selectedProperty.capabilities.cctv
                  ? 'Apps.house.cameraAvailable'
                  : 'Apps.house.cameraUnavailable',
              )
            "
            :disabled="
              !selectedProperty.capabilities.cctv ||
              isPending('open_cctv', selectedProperty)
            "
            @click="
              selectedProperty.capabilities.cctv &&
              runCommand('open_cctv', selectedProperty)
            "
          >
            <template #media><Camera :size="19" /></template>
          </sky-list-item>
          <sky-list-item
            link
            chevron
            :title="phone.t('Apps.easyShare.share')"
            @click="shareProperty(selectedProperty)"
          >
            <template #media><Share2 :size="19" /></template>
          </sky-list-item>
        </sky-list>

        <sky-block-title>{{ phone.t('Apps.house.status') }}</sky-block-title>
        <sky-list inset strong class="house-facts">
          <sky-list-item
            :title="phone.t('Apps.house.access')"
            :after="accessLabel(selectedProperty)"
          >
            <template #media><UserRound :size="17" /></template>
          </sky-list-item>
          <sky-list-item
            :title="phone.t('Apps.house.camera')"
            :after="
              phone.t(
                selectedProperty.capabilities.cctv
                  ? 'Apps.house.cameraAvailable'
                  : 'Apps.house.cameraUnavailable',
              )
            "
          >
            <template #media><Camera :size="17" /></template>
          </sky-list-item>
          <sky-list-item
            v-if="selectedProperty.garage"
            :title="phone.t('Apps.house.garage')"
            :subtitle="
              phone.t('Apps.house.storedVehicles', {
                count: String(selectedProperty.garage.storedVehicles),
              })
            "
            :after="
              phone.t(
                selectedProperty.garage.enabled
                  ? 'Apps.house.garageEnabled'
                  : 'Apps.house.garageDisabled',
              )
            "
          >
            <template #media><CarFront :size="17" /></template>
          </sky-list-item>
        </sky-list>

        <section v-if="selectedProperty.capabilities.keys" class="house-keys">
          <header>
            <span
              ><small>{{ phone.t('Apps.house.access') }}</small
              ><strong>{{ phone.t('Apps.house.keys') }}</strong></span
            >
            <sky-button
              v-if="selectedProperty.capabilities.keyGrant !== false"
              rounded
              small
              inline
              @click="openKeyCandidates(selectedProperty)"
            >
              <Plus :size="15" />{{ phone.t('Apps.house.addKey') }}
            </sky-button>
          </header>
          <sky-list
            v-if="selectedProperty.keys?.length"
            inset
            strong
            class="house-key-list"
          >
            <sky-list-item
              v-for="key in selectedProperty.keys"
              :key="key.identifier"
              :title="key.name"
              :subtitle="
                phone.t(
                  key.online ? 'Apps.house.onlineKey' : 'Apps.house.offlineKey',
                )
              "
            >
              <template #media><KeyRound :size="17" /></template>
              <template #after>
                <sky-button
                  clear
                  rounded
                  small
                  :disabled="key.revocable === false"
                  @click.stop="revokeCandidate = key"
                >
                  {{ phone.t('Apps.house.revokeKey') }}
                </sky-button>
              </template>
            </sky-list-item>
          </sky-list>
          <sky-card v-else class="house-keys__empty">
            <KeyRound :size="25" />
            <strong>{{ phone.t('Apps.house.noKeys') }}</strong>
            <p>{{ phone.t('Apps.house.noKeysBody') }}</p>
          </sky-card>
        </section>
      </section>
    </sky-sheet>

    <sky-sheet
      :opened="candidatesOpened"
      class="house-candidates-sheet"
      grabber-clickable
      :grabber-label="phone.t('Common.close')"
      swipe-to-close
      @backdropclick="candidatesOpened = false"
      @escape="candidatesOpened = false"
      @grabberclick="candidatesOpened = false"
      @swipeclose="candidatesOpened = false"
    >
      <section class="house-candidates">
        <UsersRound :size="34" />
        <h2>{{ phone.t('Apps.house.chooseResident') }}</h2>
        <p>{{ phone.t('Apps.house.chooseResidentBody') }}</p>
        <div
          v-if="housing.isLoadingCandidates"
          class="house-candidates__loading"
        >
          <sky-spinner />
        </div>
        <sky-list v-else-if="housing.candidates.length" inset strong>
          <sky-list-item
            v-for="candidate in housing.candidates"
            :key="candidate.id"
            link
            chevron
            :title="candidate.name"
            @click="grantKey(candidate)"
          >
            <template #media><UserRound :size="17" /></template>
          </sky-list-item>
        </sky-list>
        <sky-card v-else class="house-keys__empty">
          <UsersRound :size="25" />
          <strong>{{ phone.t('Apps.house.noCandidates') }}</strong>
          <p>{{ phone.t('Apps.house.noCandidatesBody') }}</p>
        </sky-card>
      </section>
    </sky-sheet>

    <sky-dialog
      :opened="Boolean(revokeCandidate)"
      @backdropclick="revokeCandidate = null"
    >
      <template #title>{{ phone.t('Apps.house.revokeTitle') }}</template>
      <p v-if="revokeCandidate" class="house-revoke-copy">
        {{ phone.t('Apps.house.revokeBody', { name: revokeCandidate.name }) }}
      </p>
      <template #buttons>
        <sky-dialog-button @click="revokeCandidate = null">{{
          phone.t('Apps.house.cancel')
        }}</sky-dialog-button>
        <sky-dialog-button strong @click="revokeKey"
          ><Check :size="15" />{{
            phone.t('Apps.house.confirm')
          }}</sky-dialog-button
        >
      </template>
    </sky-dialog>

    <SkyNotification
      :opened="toastOpened"
      :text="toastText"
      @click="toastOpened = false"
    />
  </sky-app-page>
</template>

<style scoped>
.house-page {
  --house-accent: #f47a38;
  --house-accent-soft: #ffb054;
  --house-bg: #f3f3f7;
  --house-panel: rgb(255 255 255/0.84);
  --house-text: #161619;
  --house-muted: #72727a;
  position: absolute;
  inset: 0;
  overflow: hidden;
  isolation: isolate;
  background:
    radial-gradient(circle at 15% 4%, #ffd39b 0, transparent 32%),
    linear-gradient(165deg, #f4e9dd 0, #f3f3f7 47%, #e8edf3 100%);
  color: var(--house-text);
}
:global(.phone-app.dark .house-page) {
  --house-bg: #101114;
  --house-panel: rgb(39 39 43/0.78);
  --house-text: #fafafa;
  --house-muted: #aaaab2;
  background:
    radial-gradient(circle at 15% 4%, #7a3b1f 0, transparent 34%),
    linear-gradient(165deg, #26201d 0, #111216 48%, #171d25 100%);
}
.house-navbar {
  --sky-navbar-glass: transparent;
  position: absolute;
  z-index: 5;
  top: 0;
  right: 0;
  left: 0;
  background: transparent !important;
}
.house-navbar::after {
  opacity: 0;
}
.house-navbar :deep(.sky-navbar__heading) {
  width: 100%;
  justify-content: center;
  grid-column: 1 / -1;
  gap: 1px;
  padding: 0 var(--sky-page-gutter);
}
.house-navbar :deep(.sky-navbar__title) {
  line-height: 24px;
}
.house-navbar :deep(.sky-navbar__subtitle) {
  max-width: 100%;
  margin-top: 0;
  overflow: visible;
  line-height: 15px;
  text-overflow: clip;
  white-space: normal;
}
.house-scroll {
  position: absolute;
  inset: calc(
      var(--sky-safe-area-top) + var(--sky-navbar-height) + var(--sky-space-3)
    )
    0 25px;
  padding: 9px 13px 34px;
  overflow-x: hidden;
  overflow-y: auto;
}
.house-pull-refresh {
  position: absolute;
  z-index: 4;
  top: 4px;
  right: 0;
  left: 0;
  display: flex;
  justify-content: center;
  color: var(--house-accent);
  opacity: 0;
  pointer-events: none;
  transition:
    opacity 160ms ease,
    transform 160ms ease;
}
.house-pull-refresh.is-visible {
  opacity: 1;
}
.house-state {
  position: absolute;
  inset: calc(
      var(--sky-safe-area-top) + var(--sky-navbar-height) + var(--sky-space-3)
    )
    0 25px;
  padding: 30px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
}
.house-state__icon {
  width: 64px;
  height: 64px;
  margin-bottom: 13px;
  border-radius: 22px;
  display: grid;
  place-items: center;
  background: var(--house-panel);
  color: var(--house-accent);
  box-shadow: 0 12px 30px #5b2f1822;
}
.house-state strong {
  font-size: 18px;
}
.house-state p {
  max-width: 250px;
  margin: 6px 0 17px;
  color: var(--house-muted);
  font-size: 10px;
  line-height: 1.45;
}
.house-hero {
  padding: 16px;
  border: 1px solid #fff8;
  border-radius: 24px;
  background: linear-gradient(
    135deg,
    rgb(255 255 255/0.85),
    rgb(255 247 239/0.52)
  );
  box-shadow: 0 14px 34px #7338121c;
}
:global(.phone-app.dark .house-hero) {
  border-color: #ffffff17;
  background: linear-gradient(135deg, #ffffff1d, #ff8a4210);
}
.house-hero__title {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.house-hero__title small,
.house-hero__title strong {
  display: block;
}
.house-hero__title small {
  color: var(--house-muted);
  font-size: 9px;
  font-weight: 750;
  text-transform: uppercase;
}
.house-hero__title strong {
  font-size: 34px;
  line-height: 1;
}
.house-hero__title i {
  width: 51px;
  height: 51px;
  border-radius: 18px;
  display: grid;
  place-items: center;
  background: linear-gradient(
    145deg,
    var(--house-accent-soft),
    var(--house-accent)
  );
  color: #fff;
  box-shadow: 0 9px 18px #c64c2535;
}
.house-summary {
  margin-top: 15px;
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 7px;
}
.house-summary span {
  padding: 8px;
  border-radius: 13px;
  background: #fff8;
  color: var(--house-muted);
  font-size: 8px;
}
:global(.phone-app.dark .house-summary span) {
  background: #ffffff0c;
}
.house-summary b {
  display: block;
  color: var(--house-text);
  font-size: 16px;
}
.house-properties h2 {
  margin: 19px 3px 9px;
  font-size: 16px;
}
.house-property {
  width: 100%;
  margin-bottom: 8px;
  padding: 11px;
  border: 1px solid #ffffff80;
  border-radius: 19px;
  display: flex;
  align-items: center;
  gap: 10px;
  background: var(--house-panel);
  color: var(--house-text);
  text-align: left;
  box-shadow: 0 8px 20px #24252b12;
  cursor: pointer;
  transition: opacity 100ms ease;
}
:global(.phone-app.dark .house-property) {
  border-color: #ffffff12;
}
.house-property__icon {
  width: 47px;
  height: 47px;
  border-radius: 16px;
  display: grid;
  place-items: center;
  background: linear-gradient(145deg, #ffb45d, #f26d35);
  color: #fff;
}
.house-property__content {
  min-width: 0;
  flex: 1;
}
.house-property__content > strong {
  display: block;
  overflow: hidden;
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.house-property__content > small {
  margin: 2px 0 6px;
  display: flex;
  align-items: center;
  gap: 3px;
  color: var(--house-muted);
  font-size: 8px;
}
.house-property__chips {
  display: flex;
  gap: 4px;
}
.house-property__chips i {
  padding: 3px 6px;
  border-radius: 99px;
  display: flex;
  align-items: center;
  gap: 3px;
  background: #e8f8ed;
  color: #267c42;
  font-size: 7px;
  font-style: normal;
  font-weight: 750;
}
.house-property__chips i.is-locked {
  background: #fff0e7;
  color: #c8522b;
}
:global(.phone-app.dark .house-property__chips i) {
  background: #2a4b35;
  color: #8ce1a7;
}
:global(.phone-app.dark .house-property__chips i.is-locked) {
  background: #5a3023;
  color: #ffb392;
}
.house-empty,
.house-keys__empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  color: var(--house-muted);
}
.house-empty {
  margin-top: 18px;
  padding: 35px 20px;
}
.house-empty strong,
.house-keys__empty strong {
  margin-top: 7px;
  color: var(--house-text);
}
.house-empty p,
.house-keys__empty p {
  margin: 4px 0;
  font-size: 9px;
}
.house-provider {
  margin: 16px 0 0;
  color: var(--house-muted);
  font-size: 8px;
  text-align: center;
}
:global(.house-detail-sheet),
:global(.house-candidates-sheet) {
  --sky-sheet-background: var(--house-bg);
}
:global(.house-detail-sheet .sky-sheet__panel),
:global(.house-candidates-sheet .sky-sheet__panel) {
  height: 88%;
  overflow-x: hidden;
  overflow-y: auto;
  border-radius: 28px 28px 0 0;
}
.house-detail {
  position: relative;
  min-height: calc(100% - 32px);
  padding: 12px 14px 40px;
  text-align: center;
}
.house-detail__mark {
  width: 83px;
  height: 83px;
  margin: 45px auto 8px;
  border-radius: 27px;
  display: grid;
  place-items: center;
  background: linear-gradient(145deg, #ffb75f, #ef6b34);
  color: #fff;
  box-shadow: 0 15px 30px #b5452538;
}
.house-detail > small {
  color: var(--house-accent);
  font-size: 8px;
  font-weight: 850;
  text-transform: uppercase;
}
.house-detail h2 {
  margin: 2px 0 7px;
  font-size: 21px;
}
.house-detail__status {
  width: max-content;
  margin: 0 auto 13px;
  padding: 5px 9px;
  border-radius: 99px;
  display: flex;
  align-items: center;
  gap: 5px;
  background: #e8f8ed;
  color: #267c42;
  font-size: 9px;
  font-weight: 800;
}
.house-detail__status.is-locked {
  background: #fff0e7;
  color: #c8522b;
}
.house-lock-button {
  --sky-app-accent: var(--house-accent);
  width: 100%;
  margin-bottom: 18px;
  gap: 6px;
}
.house-detail h3 {
  margin: 0 0 8px;
  text-align: left;
  font-size: 13px;
}
.house-actions {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 7px;
}
.house-actions button {
  min-height: 76px;
  border: 1px solid #ffffff6b;
  border-radius: 18px;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  justify-content: space-between;
  padding: 12px;
  background: var(--house-panel);
  color: var(--house-text);
  font-size: 13px;
  line-height: 1.2;
  font-weight: 800;
  cursor: pointer;
  transition: opacity 100ms ease;
}
.house-actions svg {
  color: var(--house-accent);
}
.house-actions button:disabled {
  cursor: default;
  opacity: 0.42;
}
.house-property:active,
.house-actions button:not(:disabled):active {
  opacity: 0.78;
}
.house-facts {
  margin: 14px 0 !important;
  text-align: left;
}
.house-keys {
  text-align: left;
}
.house-keys header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.house-keys header small,
.house-keys header strong {
  display: block;
}
.house-keys header small {
  color: var(--house-muted);
  font-size: 10px;
  line-height: 1.2;
}
.house-keys header strong {
  font-size: 17px;
  line-height: 1.2;
}
.house-keys__empty {
  padding: 18px;
}
.house-candidates {
  min-height: calc(100% - 32px);
  padding: 12px 14px 35px;
  text-align: center;
}
.house-candidates > svg {
  display: block;
  margin: 0 auto;
  color: var(--house-accent);
}
.house-candidates h2 {
  margin: 6px 0 3px;
}
.house-candidates > p {
  margin: 0 auto 12px;
  max-width: 250px;
  color: var(--house-muted);
  font-size: 9px;
}
.house-candidates__loading {
  padding: 35px;
}
.house-revoke-copy {
  padding: 0 16px;
  color: var(--house-muted);
  font-size: 11px;
}

/* Native, task-first House layout. These overrides intentionally replace the
   old dashboard treatment while preserving the existing detail interactions. */
.house-page {
  --house-bg: #f2f2f7;
  --house-panel: #ffffff;
  --house-text: #161619;
  --house-muted: #6f6f78;
  background: var(--house-bg);
}
:global(.phone-app.dark .house-page) {
  --house-bg: #000000;
  --house-panel: #1c1c1e;
  --house-text: #fafafa;
  --house-muted: #a1a1aa;
  background: var(--house-bg);
}
.house-navbar {
  --sky-navbar-glass: var(--house-bg);
}
.house-scroll {
  padding: 0 0 46px;
  overscroll-behavior: contain;
}
.house-state {
  padding: 42px 28px 86px;
}
.house-state__icon {
  width: 62px;
  height: 62px;
  margin-bottom: 16px;
  border-radius: 19px;
  box-shadow: 0 8px 24px #00000014;
}
.house-state strong {
  font-size: 20px;
  line-height: 1.2;
}
.house-state p {
  margin: 8px 0 20px;
  font-size: 13px;
  line-height: 1.4;
}
.house-properties {
  padding-top: 4px;
}
.house-overview {
  margin: 0 16px 16px;
  padding: 12px 6px;
  border-radius: 18px;
  display: flex;
  background: var(--house-panel);
}
.house-overview span {
  min-width: 0;
  flex: 1;
  padding: 0 8px;
  color: var(--house-muted);
  font-size: 11px;
  line-height: 1.25;
}
.house-overview span + span {
  border-left: 1px solid #8e8e9338;
}
.house-overview b {
  display: block;
  margin-bottom: 2px;
  color: var(--house-text);
  font-size: 17px;
  line-height: 1;
}
.house-property-list {
  margin: 0 16px !important;
}
.house-property__icon {
  width: 40px;
  height: 40px;
  border-radius: 12px;
  background: var(--house-accent);
}
.house-property__status {
  padding: 4px 7px;
  border-radius: 999px;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  background: #e8f8ed;
  color: #267c42;
  font-size: 10px;
  font-weight: 700;
}
.house-property__status.is-locked {
  background: #fff0e7;
  color: #c8522b;
}
:global(.phone-app.dark .house-property__status) {
  background: #2a4b35;
  color: #8ce1a7;
}
:global(.phone-app.dark .house-property__status.is-locked) {
  background: #5a3023;
  color: #ffb392;
}
.house-empty {
  min-height: calc(100% - 16px);
  margin: 0;
  padding: 34px 31px 90px;
  justify-content: center;
}
.house-empty__icon {
  width: 68px;
  height: 68px;
  margin-bottom: 16px;
  border-radius: 21px;
  display: grid;
  place-items: center;
  background: var(--house-accent);
  color: #fff;
  box-shadow: 0 10px 30px #f47a383d;
}
.house-empty > small {
  color: var(--house-accent);
  font-size: 11px;
  font-weight: 750;
  letter-spacing: 0.05em;
  text-transform: uppercase;
}
.house-empty h1 {
  margin: 5px 0 0;
  color: var(--house-text);
  font-size: 22px;
  line-height: 1.2;
}
.house-empty p,
.house-keys__empty p {
  margin: 8px 0 20px;
  max-width: 260px;
  font-size: 13px;
  line-height: 1.42;
}
.house-detail {
  min-height: calc(100% - 32px);
  padding: 12px 0 42px;
}
.house-detail__mark {
  width: 58px;
  height: 58px;
  margin: 0 auto 10px;
  border-radius: 18px;
  background: var(--house-accent);
}
.house-detail > small {
  font-size: 11px;
  font-weight: 750;
}
.house-detail h2 {
  margin: 3px 32px 8px;
  font-size: 22px;
  line-height: 1.2;
}
.house-detail__status {
  font-size: 11px;
}
.house-lock-button {
  width: calc(100% - 32px);
  margin: 0 16px 20px;
}
.house-detail :deep(.sky-block-title) {
  margin-top: 18px;
  margin-bottom: 7px;
  padding: 0 20px;
  color: var(--house-muted);
  text-align: left;
}
.house-action-list,
.house-facts {
  margin: 0 16px !important;
  text-align: left;
}
.house-action-list svg {
  color: var(--house-accent);
}
.house-keys {
  padding: 0 16px;
}
.house-key-list {
  --sky-list-outer-left: 0px;
  --sky-list-outer-right: 0px;
  width: 100%;
  margin-top: 0;
  margin-bottom: 0;
}
.house-keys header {
  margin: 20px 4px 8px;
}
.house-keys header small {
  font-size: 11px;
}
.house-keys header strong {
  font-size: 16px;
}
.house-candidates {
  min-height: calc(100% - 32px);
  padding: 12px 14px 35px;
}
.house-candidates h2 {
  margin: 8px 0 5px;
}
.house-candidates > p {
  margin: 0 auto 16px;
  font-size: 13px;
  line-height: 1.4;
}
.house-revoke-copy {
  font-size: 13px;
  line-height: 1.4;
}
</style>
