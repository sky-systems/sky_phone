<script setup lang="ts">
import {
  BellRing,
  Building2,
  CheckCircle2,
  ChevronRight,
  CircleAlert,
  Flame,
  HeartPulse,
  History,
  Info,
  LocateFixed,
  MapPinned,
  Minus,
  Megaphone,
  Plus,
  RadioTower,
  RefreshCw,
  RotateCcw,
  ShieldAlert,
  ShieldCheck,
  Siren,
  TriangleAlert,
  Users,
} from 'lucide-vue-next'
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'

import {
  defaultCayoStyle,
  defaultMainlandStyle,
  defaultMapCoordinates,
} from '@/features/map/defaultMapGeometry'
import { useMapPanZoom } from '@/features/map/useMapPanZoom'
import {
  cityWarnColorStyle,
  cityWarnMapArea,
  cityWarnMapPosition,
} from '@/utils/citywarnPresentation'
import {
  CITYWARN_CATEGORIES,
  CITYWARN_SEVERITIES,
  useCityWarnStore,
} from '@/stores/citywarn'
import { usePhoneStore } from '@/stores/phone'
import type {
  CityWarnAlert,
  CityWarnAreaType,
  CityWarnCategory,
  CityWarnSeverity,
} from '@/types/citywarn'
import {
  SkyAppPage,
  SkyButton,
  SkyCard,
  SkyEmptyState,
  SkyField,
  SkyNavbar,
  SkyPillNavigation,
  SkyScrollArea,
  SkySegmented,
  SkySegmentedButton,
  SkySettingsGroup,
  SkySettingsRow,
  SkySheet,
  SkySpinner,
} from '@/ui'
import { nuiCall } from '@/utils/nui'

type CityWarnTab = 'active' | 'map' | 'archive' | 'settings'
type ManageMode = 'resolve' | 'update'

const mapAssetBase = `${import.meta.env.BASE_URL}img/maps/`
const route = useRoute()
const phone = usePhoneStore()
const citywarn = useCityWarnStore()
const tab = ref<CityWarnTab>('active')
const selected = ref<CityWarnAlert | null>(null)
const composeOpened = ref(false)
const composeStep = ref(1)
const publishing = ref(false)
const composeError = ref('')
const feedback = ref('')
const manageOpened = ref(false)
const manageMode = ref<ManageMode>('update')
const manageText = ref('')
const managing = ref(false)
const mapViewport = ref<HTMLElement | null>(null)
const mapCanvas = ref<HTMLElement | null>(null)
const {
  canvasStyle: mapTransform,
  changeZoom,
  dragging: mapDragging,
  maxZoom,
  minZoom,
  onClickCapture: onMapClickCapture,
  onKeydown: onMapKeydown,
  onPointerDown: onMapPointerDown,
  onPointerEnd: onMapPointerEnd,
  onPointerMove: onMapPointerMove,
  onWheel: onMapWheel,
  reset: resetMap,
  zoom: mapZoom,
} = useMapPanZoom(mapViewport, mapCanvas)

const draftCategory = ref<CityWarnCategory>('public_safety')
const draftSeverity = ref<CityWarnSeverity>('warning')
const draftAreaType = ref<CityWarnAreaType>('radius')
const draftAreaLabel = ref('')
const draftCenterX = ref('')
const draftCenterY = ref('')
const draftRadius = ref('800')
const draftTitle = ref('')
const draftBody = ref('')
const draftInstructions = ref('')
const draftDuration = ref('60')
const locating = ref(false)

const severityRank: Record<CityWarnSeverity, number> = {
  danger: 2,
  extreme: 3,
  information: 0,
  warning: 1,
}

const categoryIcons = {
  evacuation: Users,
  fire: Flame,
  infrastructure: RadioTower,
  medical: HeartPulse,
  police: ShieldAlert,
  public_safety: Siren,
}

const tabs: Array<{ icon: typeof BellRing; id: CityWarnTab }> = [
  { icon: BellRing, id: 'active' },
  { icon: MapPinned, id: 'map' },
  { icon: History, id: 'archive' },
  { icon: ShieldCheck, id: 'settings' },
]

const availableCategories = computed(
  () => citywarn.context?.allowedCategories ?? CITYWARN_CATEGORIES,
)
const availableSeverities = computed(() => {
  const maximum = citywarn.context?.maximumSeverity
  if (!maximum) return CITYWARN_SEVERITIES
  return CITYWARN_SEVERITIES.filter(
    (severity) => severityRank[severity] <= severityRank[maximum],
  )
})
const composeValid = computed(() => {
  if (composeStep.value === 1) return true
  if (composeStep.value === 2) {
    if (!draftAreaLabel.value.trim()) return false
    return (
      draftCenterX.value.trim() !== '' &&
      draftCenterY.value.trim() !== '' &&
      Number.isFinite(Number(draftCenterX.value)) &&
      Number.isFinite(Number(draftCenterY.value)) &&
      (draftAreaType.value !== 'radius' || Number(draftRadius.value) >= 100)
    )
  }
  if (composeStep.value === 3) {
    return Boolean(
      draftTitle.value.trim() &&
        draftBody.value.trim() &&
        Number(draftDuration.value) > 0,
    )
  }
  return true
})

function t(key: string, values?: Record<string, string>): string {
  const path = `Apps.citywarn.${key}`
  const value = phone.t(path, values)
  if (value === path && key.startsWith('errors.')) {
    return phone.t('Apps.citywarn.errors.default')
  }
  return value
}

function categoryLabel(category: CityWarnCategory): string {
  return t(`categories.${category}`)
}

function severityLabel(severity: CityWarnSeverity): string {
  return t(`severity.${severity}`)
}

function formatDate(value: number): string {
  return new Intl.DateTimeFormat(undefined, {
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    month: 'short',
  }).format(value)
}

function formatRelative(value: number): string {
  const minutes = Math.max(0, Math.round((Date.now() - value) / 60000))
  if (minutes < 1) return t('updated')
  if (minutes < 60) return `${minutes} min`
  if (minutes < 1440) return `${Math.round(minutes / 60)} h`
  return formatDate(value)
}

function openAlert(alert: CityWarnAlert): void {
  selected.value = alert
}

function closeDetail(): void {
  selected.value = null
}

function resetDraft(): void {
  draftCategory.value = availableCategories.value[0] ?? 'public_safety'
  draftSeverity.value = availableSeverities.value.includes('warning')
    ? 'warning'
    : (availableSeverities.value[0] ?? 'information')
  draftAreaType.value = 'radius'
  draftAreaLabel.value = ''
  draftCenterX.value = ''
  draftCenterY.value = ''
  draftRadius.value = '800'
  draftTitle.value = ''
  draftBody.value = ''
  draftInstructions.value = ''
  draftDuration.value = '60'
  composeStep.value = 1
  composeError.value = ''
}

function openCompose(): void {
  resetDraft()
  composeOpened.value = true
}

async function useCurrentLocation(): Promise<void> {
  locating.value = true
  const response = await nuiCall<{
    coords?: { x: number; y: number; z?: number }
  }>('map:getPlayerCoords')
  locating.value = false
  if (!response.success || !response.data?.coords) return
  draftCenterX.value = response.data.coords.x.toFixed(1)
  draftCenterY.value = response.data.coords.y.toFixed(1)
  if (!draftAreaLabel.value) draftAreaLabel.value = t('currentLocation')
}

function nextComposeStep(): void {
  composeError.value = ''
  if (!composeValid.value) {
    composeError.value = t('errors.invalid_warning')
    return
  }
  composeStep.value = Math.min(4, composeStep.value + 1)
}

async function publishWarning(): Promise<void> {
  if (publishing.value) return
  publishing.value = true
  composeError.value = ''
  const response = await citywarn.publish({
    area: {
      centerX: !draftCenterX.value ? null : Number(draftCenterX.value),
      centerY: !draftCenterY.value ? null : Number(draftCenterY.value),
      label: draftAreaLabel.value.trim(),
      radius:
        draftAreaType.value === 'radius' ? Number(draftRadius.value) : null,
      type: draftAreaType.value,
    },
    body: draftBody.value.trim(),
    category: draftCategory.value,
    durationMinutes: Number(draftDuration.value),
    instructions: draftInstructions.value.trim(),
    severity: draftSeverity.value,
    title: draftTitle.value.trim(),
  })
  publishing.value = false
  if (!response.success || !response.data) {
    composeError.value = t(`errors.${response.error ?? 'request_failed'}`)
    return
  }
  composeOpened.value = false
  selected.value = response.data.alert
  feedback.value = t('compose.success')
}

function openManage(mode: ManageMode): void {
  manageMode.value = mode
  manageText.value = ''
  manageOpened.value = true
  composeError.value = ''
}

async function submitManage(): Promise<void> {
  const alert = selected.value
  if (!alert || !manageText.value.trim() || managing.value) return
  managing.value = true
  const response =
    manageMode.value === 'update'
      ? await citywarn.addUpdate(alert, manageText.value.trim())
      : await citywarn.resolve(alert, manageText.value.trim())
  managing.value = false
  if (!response.success || !response.data) {
    composeError.value = t(`errors.${response.error ?? 'request_failed'}`)
    return
  }
  selected.value = response.data.alert
  manageOpened.value = false
  feedback.value = manageMode.value === 'resolve' ? t('manage.resolved') : ''
}

function categoryStyle(category: CityWarnCategory): Record<string, string> {
  return cityWarnColorStyle(citywarn.categoryColors[category])
}

function setAreaType(type: CityWarnAreaType): void {
  draftAreaType.value = type
  if (type === 'city') {
    draftAreaLabel.value = 'Los Santos'
  }
}

onMounted(async () => {
  await citywarn.load()
  const alertId =
    typeof route.query.alertId === 'string' ? route.query.alertId : ''
  if (alertId) {
    selected.value =
      [...citywarn.active, ...citywarn.archive].find(
        (alert) => alert.id === alertId,
      ) ?? null
  }
})
</script>

<template>
  <SkyAppPage class="citywarn-app" accent="#dc2626" accent-soft="#fee2e2">
    <SkyNavbar
      v-if="selected"
      :title="t('details')"
      :show-back="true"
      :back-label="t('name')"
      outline
      @back="closeDetail"
    />
    <SkyNavbar v-else :title="t('name')" outline>
      <template #title>
        <span class="citywarn-brand"><Siren :size="17" /> CityWarn</span>
      </template>
      <template v-if="citywarn.context?.canPublish" #right>
        <SkyButton
          class="citywarn-add"
          icon-only
          clear
          :aria-label="t('compose.new')"
          @click="openCompose"
        >
          <Plus :size="22" />
        </SkyButton>
      </template>
    </SkyNavbar>

    <SkyScrollArea
      v-if="selected"
      class="citywarn-scroll citywarn-detail"
      :style="categoryStyle(selected.category)"
    >
      <section
        class="citywarn-detail-hero"
        :class="`severity-${selected.severity}`"
      >
        <div class="citywarn-detail-icon">
          <component :is="categoryIcons[selected.category]" :size="28" />
        </div>
        <span class="citywarn-severity">{{
          severityLabel(selected.severity)
        }}</span>
        <h2>{{ selected.title }}</h2>
        <p>{{ selected.area.label }}</p>
      </section>

      <div class="citywarn-detail-content">
        <div class="citywarn-meta-grid">
          <div>
            <Megaphone :size="16" /><span>{{ t('issuedBy') }}</span
            ><strong>{{ selected.sourceLabel }}</strong>
          </div>
          <div>
            <MapPinned :size="16" /><span>{{ t('affectedArea') }}</span
            ><strong>{{ selected.area.label }}</strong>
          </div>
          <div>
            <RefreshCw :size="16" /><span>{{ t('updated') }}</span
            ><strong>{{ formatDate(selected.updatedAt) }}</strong>
          </div>
          <div>
            <History :size="16" /><span>{{ t('expires') }}</span
            ><strong>{{ formatDate(selected.expiresAt) }}</strong>
          </div>
        </div>

        <section class="citywarn-copy">
          <p>{{ selected.body }}</p>
        </section>

        <section v-if="selected.instructions" class="citywarn-instructions">
          <div>
            <CircleAlert :size="20" /><strong>{{ t('instructions') }}</strong>
          </div>
          <p>{{ selected.instructions }}</p>
        </section>

        <section class="citywarn-timeline">
          <h3>{{ t('timeline') }}</h3>
          <article v-for="update in selected.updates" :key="update.id">
            <span :class="`timeline-dot timeline-dot--${update.kind}`"></span>
            <div>
              <strong>{{ update.message }}</strong>
              <small
                >{{ update.actorName }} ·
                {{ formatDate(update.createdAt) }}</small
              >
            </div>
          </article>
        </section>

        <div
          v-if="citywarn.context?.canPublish && selected.status === 'active'"
          class="citywarn-manage"
        >
          <SkyButton block outline @click="openManage('update')">
            <RefreshCw :size="17" /> {{ t('manage.update') }}
          </SkyButton>
          <SkyButton block variant="danger" @click="openManage('resolve')">
            <CheckCircle2 :size="17" /> {{ t('manage.resolve') }}
          </SkyButton>
        </div>
      </div>
    </SkyScrollArea>

    <SkyScrollArea v-else class="citywarn-scroll" with-tabbar>
      <div
        v-if="citywarn.isLoading && !citywarn.initialized"
        class="citywarn-loading"
      >
        <SkySpinner :size="28" />
        <span>{{ t('loading') }}</span>
      </div>

      <SkyEmptyState
        v-else-if="citywarn.error"
        :title="t('errors.default')"
        :body="t(`errors.${citywarn.error}`)"
        tone="danger"
      >
        <template #actions>
          <SkyButton @click="citywarn.load()">{{ t('tabs.active') }}</SkyButton>
        </template>
      </SkyEmptyState>

      <template v-else-if="tab === 'active'">
        <section
          class="citywarn-overview"
          :class="{
            'citywarn-overview--active': citywarn.visibleActive.length,
          }"
        >
          <div class="citywarn-overview-symbol">
            <TriangleAlert v-if="citywarn.visibleActive.length" :size="27" />
            <ShieldCheck v-else :size="27" />
          </div>
          <div>
            <strong>
              {{
                citywarn.visibleActive.length
                  ? t('hero.active', {
                      count: String(citywarn.visibleActive.length),
                    })
                  : t('hero.safe')
              }}
            </strong>
            <p>
              {{
                citywarn.visibleActive.length
                  ? t('hero.activeBody')
                  : t('hero.safeBody')
              }}
            </p>
          </div>
        </section>

        <div class="citywarn-feed">
          <article
            v-for="alert in citywarn.visibleActive"
            :key="alert.id"
            class="citywarn-alert-card"
            :style="categoryStyle(alert.category)"
            tabindex="0"
            role="button"
            @click="openAlert(alert)"
            @keydown.enter="openAlert(alert)"
          >
            <div class="citywarn-card-stripe"></div>
            <div class="citywarn-card-top">
              <div class="citywarn-card-icon">
                <component :is="categoryIcons[alert.category]" :size="20" />
              </div>
              <div>
                <span>{{ severityLabel(alert.severity) }}</span>
                <small>{{ formatRelative(alert.updatedAt) }}</small>
              </div>
              <ChevronRight :size="19" />
            </div>
            <h3>{{ alert.title }}</h3>
            <p>{{ alert.body }}</p>
            <footer>
              <span><MapPinned :size="14" /> {{ alert.area.label }}</span>
              <span>{{ alert.sourceLabel }}</span>
            </footer>
          </article>

          <SkyEmptyState
            v-if="!citywarn.visibleActive.length && citywarn.active.length"
            :title="t('emptyFiltered')"
            :body="t('emptyFilteredBody')"
            compact
          />
        </div>

        <SkyCard
          v-if="citywarn.context"
          class="citywarn-publisher-card"
          outline
        >
          <div class="citywarn-publisher-icon"><Building2 :size="20" /></div>
          <div>
            <strong>{{ t('publisher.title') }}</strong>
            <p v-if="citywarn.context.canPublish">
              {{
                t('publisher.body', {
                  job: citywarn.context.jobLabel ?? '',
                  grade: citywarn.context.gradeLabel ?? '',
                })
              }}
            </p>
            <p
              v-else-if="
                citywarn.context.requiresDuty &&
                !citywarn.context.onDuty &&
                citywarn.context.jobLabel
              "
            >
              {{ t('publisher.offDuty') }}
            </p>
            <p v-else>{{ t('publisher.unavailable') }}</p>
          </div>
        </SkyCard>
      </template>

      <template v-else-if="tab === 'map'">
        <section class="citywarn-map-heading">
          <span><MapPinned :size="20" /></span>
          <div>
            <h2>{{ t('mapTitle') }}</h2>
            <p>{{ t('mapBody') }}</p>
            <p>{{ t('mapHint') }}</p>
          </div>
        </section>
        <div
          ref="mapViewport"
          class="citywarn-map"
          :class="{ 'citywarn-map--dragging': mapDragging }"
          tabindex="0"
          role="region"
          :aria-label="t('mapTitle')"
          @pointerdown.capture="onMapPointerDown"
          @pointermove="onMapPointerMove"
          @pointerup="onMapPointerEnd"
          @pointercancel="onMapPointerEnd"
          @lostpointercapture="onMapPointerEnd"
          @click.capture="onMapClickCapture"
          @wheel="onMapWheel"
          @keydown="onMapKeydown"
        >
          <div
            ref="mapCanvas"
            class="citywarn-map-canvas"
            :style="{
              aspectRatio: `${defaultMapCoordinates.width} / ${defaultMapCoordinates.height}`,
              ...mapTransform,
            }"
          >
            <img
              :src="`${mapAssetBase}gtav-map.svg`"
              :style="defaultMainlandStyle"
              alt=""
              draggable="false"
            />
            <img
              :src="`${mapAssetBase}cayo-perico.svg`"
              :style="defaultCayoStyle"
              alt=""
              draggable="false"
            />
            <template
              v-for="alert in citywarn.visibleActive"
              :key="`area-${alert.id}`"
            >
              <span
                v-if="cityWarnMapArea(alert.area, citywarn.mapBlip)"
                class="citywarn-map-zone"
                :style="{
                  ...categoryStyle(alert.category),
                  ...cityWarnMapArea(alert.area, citywarn.mapBlip),
                }"
                aria-hidden="true"
              ></span>
            </template>
            <template v-for="alert in citywarn.visibleActive" :key="alert.id">
              <button
                v-if="cityWarnMapPosition(alert.area)"
                class="citywarn-map-pin"
                :style="{
                  ...categoryStyle(alert.category),
                  ...cityWarnMapPosition(alert.area),
                }"
                :aria-label="alert.title"
                :title="alert.title"
                @click="openAlert(alert)"
              >
                <span
                  ><component :is="categoryIcons[alert.category]" :size="17"
                /></span>
              </button>
            </template>
          </div>
          <div
            class="citywarn-map-controls"
            data-map-controls
            role="group"
            :aria-label="t('mapControls')"
            @pointerdown.stop
            @click.stop
          >
            <SkyButton
              icon-only
              :aria-label="t('mapZoomIn')"
              :title="t('mapZoomIn')"
              :disabled="mapZoom >= maxZoom"
              @click="changeZoom(mapZoom * 1.25)"
              ><Plus :size="19"
            /></SkyButton>
            <SkyButton
              icon-only
              :aria-label="t('mapZoomOut')"
              :title="t('mapZoomOut')"
              :disabled="mapZoom <= minZoom"
              @click="changeZoom(mapZoom / 1.25)"
              ><Minus :size="19"
            /></SkyButton>
            <SkyButton
              icon-only
              :aria-label="t('mapReset')"
              :title="t('mapReset')"
              @click="resetMap"
              ><RotateCcw :size="18"
            /></SkyButton>
          </div>
        </div>
        <div class="citywarn-map-list">
          <button
            v-for="alert in citywarn.visibleActive"
            :key="alert.id"
            @click="openAlert(alert)"
          >
            <span
              class="map-list-dot"
              :style="categoryStyle(alert.category)"
            ></span>
            <div>
              <strong>{{ alert.area.label }}</strong
              ><small>{{ alert.title }}</small>
            </div>
            <ChevronRight :size="18" />
          </button>
        </div>
      </template>

      <template v-else-if="tab === 'archive'">
        <div class="citywarn-feed citywarn-feed--archive">
          <article
            v-for="alert in citywarn.archive"
            :key="alert.id"
            class="citywarn-archive-card"
            role="button"
            tabindex="0"
            @click="openAlert(alert)"
            @keydown.enter="openAlert(alert)"
          >
            <span class="archive-icon" :style="categoryStyle(alert.category)"
              ><component :is="categoryIcons[alert.category]" :size="18"
            /></span>
            <div>
              <small
                >{{ t(`status.${alert.status}`) }} ·
                {{ formatDate(alert.updatedAt) }}</small
              ><strong>{{ alert.title }}</strong
              ><span>{{ alert.area.label }}</span>
            </div>
            <ChevronRight :size="18" />
          </article>
          <SkyEmptyState
            v-if="!citywarn.archive.length"
            :title="t('emptyArchive')"
            :body="t('emptyArchiveBody')"
          />
        </div>
      </template>

      <template v-else>
        <div class="citywarn-settings">
          <SkySettingsGroup
            :title="t('settings.locationTitle')"
            :footer="t('settings.locationBody')"
          >
            <SkySettingsRow
              kind="toggle"
              :title="t('settings.locationTitle')"
              :model-value="citywarn.preferences.locationAlerts"
              @update:model-value="citywarn.setLocationAlerts"
              ><template #leading><LocateFixed :size="20" /></template
            ></SkySettingsRow>
          </SkySettingsGroup>
          <SkySettingsGroup
            :title="t('settings.levelTitle')"
            :footer="t('settings.levelBody')"
          >
            <SkySettingsRow
              v-for="severity in CITYWARN_SEVERITIES"
              :key="severity"
              kind="choice"
              :selected="citywarn.preferences.minimumSeverity === severity"
              :title="severityLabel(severity)"
              @activate="citywarn.setMinimumSeverity(severity)"
              ><template #leading
                ><span
                  :class="`settings-dot severity-${severity}`"
                ></span></template
            ></SkySettingsRow>
          </SkySettingsGroup>
          <SkySettingsGroup
            :title="t('settings.categoryTitle')"
            :footer="t('settings.categoryBody')"
          >
            <SkySettingsRow
              v-for="category in CITYWARN_CATEGORIES"
              :key="category"
              kind="toggle"
              :title="categoryLabel(category)"
              :model-value="citywarn.preferences.categories[category]"
              @update:model-value="citywarn.setCategory(category, $event)"
              ><template #leading
                ><component
                  :is="categoryIcons[category]"
                  :style="{ color: citywarn.categoryColors[category] }"
                  :size="19" /></template
            ></SkySettingsRow>
          </SkySettingsGroup>
          <p class="citywarn-settings-hint">
            <Info :size="16" /> {{ t('settings.notificationHint') }}
          </p>
        </div>
      </template>
    </SkyScrollArea>

    <SkyPillNavigation v-if="!selected" :label="t('navigation')" layout="full">
      <SkySegmented strong rounded navigation>
        <SkySegmentedButton
          v-for="item in tabs"
          :key="item.id"
          :active="tab === item.id"
          tab
          @click="tab = item.id"
        >
          <span class="citywarn-navigation-item">
            <component :is="item.icon" :size="16" />
            <span>{{ t(`tabs.${item.id}`) }}</span>
          </span>
        </SkySegmentedButton>
      </SkySegmented>
    </SkyPillNavigation>

    <Transition name="citywarn-toast">
      <div v-if="feedback" class="citywarn-feedback" @click="feedback = ''">
        <CheckCircle2 :size="17" /> {{ feedback }}
      </div>
    </Transition>

    <SkySheet
      class="citywarn-compose-sheet"
      :opened="composeOpened"
      swipe-to-close
      :aria-label="t('compose.new')"
      @backdropclick="composeOpened = false"
      @escape="composeOpened = false"
      @swipeclose="composeOpened = false"
    >
      <section class="citywarn-compose">
        <header>
          <span aria-hidden="true"></span>
          <div>
            <small>{{
              t('compose.step', { step: String(composeStep) })
            }}</small>
            <h2>{{ t('compose.new') }}</h2>
          </div>
          <span></span>
        </header>
        <div class="compose-progress">
          <i
            v-for="step in 4"
            :key="step"
            :class="{ active: step <= composeStep }"
          ></i>
        </div>

        <div class="compose-body">
          <template v-if="composeStep === 1">
            <h3>{{ t('compose.categoryTitle') }}</h3>
            <p>{{ t('compose.categoryBody') }}</p>
            <div class="compose-category-grid">
              <button
                v-for="category in availableCategories"
                :key="category"
                :class="{ active: draftCategory === category }"
                :style="categoryStyle(category)"
                @click="draftCategory = category"
              >
                <component :is="categoryIcons[category]" :size="21" /><span>{{
                  categoryLabel(category)
                }}</span>
              </button>
            </div>
            <h3>{{ t('compose.severityTitle') }}</h3>
            <div class="compose-severity-list">
              <button
                v-for="severity in availableSeverities"
                :key="severity"
                :class="[
                  `severity-${severity}`,
                  { active: draftSeverity === severity },
                ]"
                @click="draftSeverity = severity"
              >
                <span></span>{{ severityLabel(severity)
                }}<CheckCircle2 v-if="draftSeverity === severity" :size="18" />
              </button>
            </div>
          </template>

          <template v-else-if="composeStep === 2">
            <h3>{{ t('compose.areaTitle') }}</h3>
            <p>{{ t('compose.areaBody') }}</p>
            <SkySegmented class="compose-area-tabs">
              <SkySegmentedButton
                :active="draftAreaType === 'radius'"
                @click="setAreaType('radius')"
                >{{ t('compose.areaTypes.radius') }}</SkySegmentedButton
              >
              <SkySegmentedButton
                :active="draftAreaType === 'district'"
                @click="setAreaType('district')"
                >{{ t('compose.areaTypes.district') }}</SkySegmentedButton
              >
              <SkySegmentedButton
                v-if="citywarn.context?.canCityWide"
                :active="draftAreaType === 'city'"
                @click="setAreaType('city')"
                >{{ t('compose.areaTypes.city') }}</SkySegmentedButton
              >
            </SkySegmented>
            <div class="compose-fields">
              <SkyField
                v-model="draftAreaLabel"
                component="div"
                outline
                :label="t('compose.areaLabel')"
                :placeholder="t('compose.areaPlaceholder')"
              />
              <SkyField
                v-if="draftAreaType === 'radius'"
                v-model="draftRadius"
                component="div"
                outline
                type="number"
                min="100"
                max="10000"
                :label="t('compose.radius')"
              />
              <SkyButton
                block
                outline
                :disabled="locating"
                @click="useCurrentLocation"
                ><LocateFixed :size="17" />
                {{
                  locating
                    ? t('loading')
                    : draftCenterX
                      ? t('compose.locationSet')
                      : t('compose.useLocation')
                }}</SkyButton
              >
            </div>
          </template>

          <template v-else-if="composeStep === 3">
            <h3>{{ t('compose.contentTitle') }}</h3>
            <div class="compose-fields">
              <SkyField
                v-model="draftTitle"
                component="div"
                outline
                :maxlength="120"
                :label="t('compose.title')"
                :placeholder="t('compose.titlePlaceholder')"
              />
              <SkyField
                v-model="draftBody"
                component="div"
                outline
                type="textarea"
                :rows="5"
                :maxlength="2000"
                :label="t('compose.body')"
                :placeholder="t('compose.bodyPlaceholder')"
              />
              <SkyField
                v-model="draftInstructions"
                component="div"
                outline
                type="textarea"
                :rows="4"
                :maxlength="2000"
                :label="t('compose.instructions')"
                :placeholder="t('compose.instructionsPlaceholder')"
              />
              <SkyField
                v-model="draftDuration"
                component="div"
                outline
                type="select"
                dropdown
                :label="t('compose.duration')"
                :options="[
                  {
                    value: '30',
                    label: t('compose.durationMinutes', { count: '30' }),
                  },
                  {
                    value: '60',
                    label: t('compose.durationMinutes', { count: '60' }),
                  },
                  {
                    value: '180',
                    label: t('compose.durationMinutes', { count: '180' }),
                  },
                  {
                    value: '360',
                    label: t('compose.durationMinutes', { count: '360' }),
                  },
                ]"
              />
            </div>
          </template>

          <template v-else>
            <h3>{{ t('compose.previewTitle') }}</h3>
            <article
              class="compose-preview"
              :class="`severity-${draftSeverity}`"
            >
              <span
                >{{ severityLabel(draftSeverity) }} ·
                {{ categoryLabel(draftCategory) }}</span
              >
              <h4>{{ draftTitle }}</h4>
              <p>{{ draftBody }}</p>
              <footer><MapPinned :size="15" /> {{ draftAreaLabel }}</footer>
            </article>
            <div class="compose-recipient">
              <Users :size="22" />
              <div>
                <strong>{{
                  t('compose.recipients', {
                    count: String(citywarn.onlinePlayers),
                  })
                }}</strong>
                <p>{{ t('compose.legal') }}</p>
              </div>
            </div>
          </template>
          <p v-if="composeError" class="compose-error">{{ composeError }}</p>
        </div>

        <footer class="compose-actions">
          <SkyButton v-if="composeStep > 1" outline @click="composeStep -= 1">{{
            t('compose.back')
          }}</SkyButton>
          <SkyButton
            v-if="composeStep < 4"
            :block="composeStep === 1"
            :disabled="!composeValid"
            @click="nextComposeStep"
            >{{ t('compose.next') }}</SkyButton
          >
          <SkyButton
            v-else
            block
            variant="danger"
            :disabled="publishing"
            @click="publishWarning"
            ><SkySpinner v-if="publishing" :size="17" /><Siren
              v-else
              :size="17"
            />
            {{
              publishing ? t('compose.publishing') : t('compose.publish')
            }}</SkyButton
          >
        </footer>
      </section>
    </SkySheet>

    <SkySheet
      class="citywarn-manage-overlay"
      :opened="manageOpened"
      swipe-to-close
      :aria-label="t(`manage.${manageMode}Title`)"
      @backdropclick="manageOpened = false"
      @escape="manageOpened = false"
      @swipeclose="manageOpened = false"
    >
      <section class="citywarn-manage-sheet">
        <h2>{{ t(`manage.${manageMode}Title`) }}</h2>
        <SkyField
          v-model="manageText"
          component="div"
          outline
          type="textarea"
          :rows="5"
          :maxlength="2000"
          :placeholder="t(`manage.${manageMode}Placeholder`)"
        />
        <p v-if="composeError" class="compose-error">{{ composeError }}</p>
        <SkyButton
          block
          :variant="manageMode === 'resolve' ? 'danger' : 'primary'"
          :disabled="!manageText.trim() || managing"
          @click="submitManage"
        >
          <SkySpinner v-if="managing" :size="17" />
          {{ t(manageMode === 'resolve' ? 'manage.confirm' : 'manage.send') }}
        </SkyButton>
      </section>
    </SkySheet>
  </SkyAppPage>
</template>

<style scoped>
.citywarn-app {
  --citywarn-red: #dc2626;
  --citywarn-ink: #111827;
  color: var(--citywarn-ink);
  text-rendering: geometricprecision;
}
.citywarn-app,
.citywarn-app :deep(*),
.citywarn-app :deep(*::before),
.citywarn-app :deep(*::after) {
  -webkit-backdrop-filter: none !important;
  backdrop-filter: none !important;
  filter: none !important;
  will-change: auto !important;
}
.citywarn-app :deep(.sky-settings-row__frame),
.citywarn-app :deep(.sky-button),
.citywarn-app :deep(.sky-segmented-button),
.citywarn-alert-card,
.citywarn-archive-card {
  transform: none !important;
}
.citywarn-app :deep(.sky-navbar__blur),
.citywarn-app :deep(.sky-glass),
.citywarn-app :deep(.sky-glass-surface) {
  -webkit-backdrop-filter: none;
  backdrop-filter: none;
}
.citywarn-app :deep(.sky-pill-navigation .sky-segmented) {
  background: rgb(255 255 255 / 98%);
}
.citywarn-brand {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-weight: 800;
  letter-spacing: -0.3px;
}
.citywarn-brand svg {
  color: var(--citywarn-red);
}
.citywarn-add {
  width: 34px;
  height: 34px;
  color: var(--citywarn-red);
}
.citywarn-navigation-item {
  display: flex;
  align-items: center;
  flex-direction: column;
  gap: 3px;
  font-size: 9.5px;
  line-height: 1;
}
.citywarn-navigation-item > svg {
  width: 18px;
  height: 18px;
}
.citywarn-scroll {
  min-height: 0;
  height: auto;
  flex: 1 1 0;
  padding: 12px 13px calc(28px + env(safe-area-inset-bottom));
  overflow-y: auto;
}
.citywarn-scroll.sky-scroll-area--tabbar {
  padding-bottom: calc(var(--sky-safe-area-bottom) + 84px);
  scroll-padding-bottom: calc(var(--sky-safe-area-bottom) + 84px);
}
.citywarn-loading {
  display: grid;
  height: 58vh;
  place-content: center;
  justify-items: center;
  gap: 10px;
  color: #6b7280;
  font-size: 12px;
}
.citywarn-overview {
  display: flex;
  padding: var(--sky-space-3);
  align-items: center;
  gap: var(--sky-space-3);
  border: 1px solid #bbf7d0;
  border-radius: var(--sky-radius-card);
  background: linear-gradient(135deg, #f0fdf4, #ecfdf5);
}
.citywarn-overview--active {
  border-color: #fecaca;
  background: linear-gradient(135deg, #fff7ed, #fef2f2);
}
.citywarn-overview-symbol {
  display: grid;
  width: 46px;
  height: 46px;
  flex: 0 0 auto;
  place-items: center;
  border-radius: var(--sky-radius-control);
  color: #15803d;
  background: #dcfce7;
}
.citywarn-overview--active .citywarn-overview-symbol {
  color: #b91c1c;
  background: #fee2e2;
}
.citywarn-overview strong {
  font-size: 15px;
  font-weight: 800;
}
.citywarn-overview p {
  margin: 3px 0 0;
  color: #6b7280;
  font-size: 12px;
  line-height: 1.4;
}
.citywarn-feed {
  display: flex;
  margin-top: 12px;
  flex-direction: column;
  gap: 10px;
}
.citywarn-overview + .citywarn-feed {
  margin-top: var(--sky-space-3);
  gap: var(--sky-space-3);
}
.citywarn-alert-card {
  position: relative;
  padding: var(--sky-space-3) var(--sky-space-3) var(--sky-space-3)
    var(--sky-space-4);
  overflow: hidden;
  border: 1px solid #e5e7eb;
  border-radius: var(--sky-radius-card);
  background: #fff;
  box-shadow: 0 4px 15px rgb(15 23 42 / 5%);
  cursor: pointer;
}
.citywarn-card-stripe {
  position: absolute;
  top: 0;
  bottom: 0;
  left: 0;
  width: 4px;
  background: var(--category);
}
.citywarn-card-top {
  display: grid;
  align-items: center;
  grid-template-columns: 32px 1fr auto;
  gap: 8px;
}
.citywarn-card-icon {
  display: grid;
  width: 32px;
  height: 32px;
  place-items: center;
  border-radius: var(--sky-radius-control);
  color: var(--category-ink);
  background: var(--category-soft);
}
.citywarn-card-top div:nth-child(2) {
  display: flex;
  flex-direction: column;
}
.citywarn-card-top span {
  color: var(--category-ink);
  font-size: 10.5px;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.6px;
}
.citywarn-card-top small {
  margin-top: 1px;
  color: #9ca3af;
  font-size: 10px;
}
.citywarn-card-top > svg {
  color: #9ca3af;
}
.citywarn-alert-card h3 {
  margin: var(--sky-space-2) 0 var(--sky-space-1);
  font-size: 16px;
  line-height: 1.18;
}
.citywarn-alert-card > p {
  display: -webkit-box;
  margin: 0;
  overflow: hidden;
  color: #4b5563;
  font-size: 12.5px;
  line-height: 1.45;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}
.citywarn-alert-card footer {
  display: flex;
  margin-top: var(--sky-space-2);
  align-items: center;
  justify-content: space-between;
  gap: var(--sky-space-2);
  color: #6b7280;
  font-size: 10.5px;
}
.citywarn-alert-card footer span {
  display: inline-flex;
  min-width: 0;
  align-items: center;
  gap: 4px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.citywarn-publisher-card {
  margin: var(--sky-space-3) 0 0;
  border-radius: var(--sky-radius-card);
}
.citywarn-publisher-card :deep(.sky-card__content) {
  display: flex;
  padding: var(--sky-space-3);
  gap: var(--sky-space-3);
}
.citywarn-publisher-icon {
  display: grid;
  width: 36px;
  height: 36px;
  flex: 0 0 auto;
  place-items: center;
  border-radius: var(--sky-radius-control);
  color: #1d4ed8;
  background: #dbeafe;
}
.citywarn-publisher-card strong {
  font-size: 13.5px;
}
.citywarn-publisher-card p {
  margin: 3px 0 0;
  color: #6b7280;
  font-size: 11px;
  line-height: 1.4;
}
.severity-information {
  --severity: #2563eb;
}
.severity-warning {
  --severity: #d97706;
}
.severity-danger {
  --severity: #dc2626;
}
.severity-extreme {
  --severity: #7f1d1d;
}
.citywarn-detail {
  padding: 0 0 calc(26px + env(safe-area-inset-bottom));
}
.citywarn-detail-hero {
  position: relative;
  padding: 24px 18px 22px;
  color: var(--category-foreground);
  background: var(--category);
}
.citywarn-detail-icon {
  display: grid;
  width: 49px;
  height: 49px;
  margin-bottom: 12px;
  place-items: center;
  border: 1px solid rgb(255 255 255 / 28%);
  border-radius: 15px;
  background: rgb(255 255 255 / 15%);
}
.citywarn-severity {
  font-size: 10.5px;
  font-weight: 850;
  text-transform: uppercase;
  letter-spacing: 1px;
}
.citywarn-detail-hero h2 {
  margin: 6px 0;
  font-size: 23px;
  line-height: 1.08;
  letter-spacing: -0.6px;
}
.citywarn-detail-hero p {
  margin: 0;
  color: inherit;
  font-size: 12px;
}
.citywarn-detail-content {
  min-width: 0;
  padding: 13px;
}
.citywarn-meta-grid {
  display: grid;
  width: 100%;
  min-width: 0;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
}
.citywarn-meta-grid > div {
  display: grid;
  min-width: 0;
  padding: 10px;
  border: 1px solid #e5e7eb;
  border-radius: 13px;
  grid-template-columns: auto 1fr;
  column-gap: 6px;
  background: #fff;
}
.citywarn-meta-grid svg {
  color: var(--category-ink);
  grid-row: span 2;
}
.citywarn-meta-grid span {
  overflow: hidden;
  color: #6b7280;
  font-size: 9.5px;
  text-overflow: ellipsis;
  text-transform: uppercase;
  letter-spacing: 0.4px;
  white-space: nowrap;
}
.citywarn-meta-grid strong {
  overflow: hidden;
  font-size: 11px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.citywarn-copy {
  padding: 16px 3px 8px;
}
.citywarn-copy p {
  margin: 0;
  color: #374151;
  font-size: 13px;
  line-height: 1.6;
}
.citywarn-instructions {
  margin-top: 8px;
  padding: 13px;
  border: 1px solid #fecaca;
  border-radius: 15px;
  background: #fef2f2;
}
.citywarn-instructions > div {
  display: flex;
  align-items: center;
  gap: 7px;
  color: #b91c1c;
  font-size: 13px;
}
.citywarn-instructions p {
  margin: 7px 0 0;
  color: #7f1d1d;
  font-size: 12.5px;
  line-height: 1.5;
}
.citywarn-timeline {
  margin-top: 18px;
}
.citywarn-timeline h3 {
  margin: 0 0 10px;
  font-size: 16px;
}
.citywarn-timeline article {
  position: relative;
  display: flex;
  min-height: 44px;
  margin-left: 7px;
  padding: 0 0 13px 19px;
  border-left: 1px solid #d1d5db;
}
.timeline-dot {
  position: absolute;
  top: 1px;
  left: -5px;
  width: 9px;
  height: 9px;
  border: 2px solid #fff;
  border-radius: 50%;
  background: #6b7280;
  box-shadow: 0 0 0 1px #9ca3af;
}
.timeline-dot--resolved {
  background: #16a34a;
}
.timeline-dot--update {
  background: #dc2626;
}
.citywarn-timeline article div {
  display: flex;
  flex-direction: column;
  gap: 3px;
}
.citywarn-timeline strong {
  font-size: 12.5px;
  line-height: 1.4;
}
.citywarn-timeline small {
  color: #9ca3af;
  font-size: 10px;
}
.citywarn-manage {
  display: grid;
  margin-top: 5px;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
}
.citywarn-manage :deep(button) {
  min-height: 42px;
  gap: 5px;
  font-size: 12px;
}
.citywarn-map-heading {
  display: flex;
  padding: 4px 3px 12px;
  gap: 10px;
}
.citywarn-map-heading > span {
  display: grid;
  width: 38px;
  height: 38px;
  place-items: center;
  border-radius: 12px;
  color: #b91c1c;
  background: #fee2e2;
}
.citywarn-map-heading h2 {
  margin: 0;
  font-size: 18px;
}
.citywarn-map-heading p {
  margin: 2px 0 0;
  color: #6b7280;
  font-size: 11.5px;
  line-height: 1.4;
}
.citywarn-map {
  position: relative;
  height: 430px;
  overflow: hidden;
  border: 1px solid #d1d5db;
  border-radius: 18px;
  background: #dfe6dc;
  touch-action: none;
  user-select: none;
  cursor: grab;
}
.citywarn-map--dragging,
.citywarn-map--dragging .citywarn-map-pin {
  cursor: grabbing;
}
.citywarn-map:focus-visible {
  outline: 2px solid var(--sky-app-accent);
  outline-offset: 2px;
}
.citywarn-map-controls {
  position: absolute;
  top: var(--sky-space-2);
  right: var(--sky-space-2);
  display: flex;
  flex-direction: column;
  gap: var(--sky-space-1);
}
.citywarn-map-controls :deep(.sky-button) {
  width: 44px;
  height: 44px;
  min-height: 44px;
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-control);
  background: var(--sky-surface);
  color: var(--sky-text);
}
.citywarn-map-canvas {
  position: relative;
  height: 100%;
  max-width: 100%;
  margin: auto;
  transform-origin: center;
}
.citywarn-map-canvas > img {
  position: absolute;
  opacity: 0.86;
  pointer-events: none;
}
.citywarn-map-zone {
  position: absolute;
  box-shadow: inset 0 0 0 1px var(--category);
  border-radius: 50%;
  background: var(--category-area);
  pointer-events: none;
}
.citywarn-map-pin {
  position: absolute;
  display: grid;
  width: 44px;
  height: 44px;
  padding: 0;
  place-items: center;
  border: 0;
  background: transparent;
  clip-path: circle(50%);
  transform: translate(-50%, -50%) scale(var(--citywarn-map-pin-scale, 1));
  cursor: pointer;
}
.citywarn-map-pin > span {
  display: grid;
  width: 29px;
  height: 29px;
  place-items: center;
  border: 2px solid white;
  border-radius: 50%;
  color: var(--category-foreground);
  background: var(--category);
  box-shadow: 0 2px 6px rgb(0 0 0 / 50%);
}
.citywarn-map-pin:focus-visible {
  outline: 2px solid var(--sky-text);
  outline-offset: -2px;
  border-radius: 50%;
}
.citywarn-map-list {
  margin-top: 10px;
  overflow: hidden;
  border: 1px solid #e5e7eb;
  border-radius: 15px;
  background: #fff;
}
.citywarn-map-list button {
  display: grid;
  width: 100%;
  min-height: 58px;
  padding: 13px;
  align-items: center;
  border: 0;
  border-bottom: 1px solid #f3f4f6;
  color: inherit;
  background: transparent;
  grid-template-columns: 9px 1fr auto;
  gap: 9px;
  text-align: left;
}
.citywarn-map-list button:last-child {
  border-bottom: 0;
}
.map-list-dot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
  background: var(--category);
}
.settings-dot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
  background: var(--severity);
}
.citywarn-map-list div {
  display: flex;
  min-width: 0;
  flex-direction: column;
}
.citywarn-map-list strong {
  font-size: 12.5px;
}
.citywarn-map-list small {
  overflow: hidden;
  color: #6b7280;
  font-size: 10.5px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.citywarn-feed--archive {
  margin-top: 0;
}
.citywarn-archive-card {
  display: grid;
  min-height: 68px;
  padding: 13px;
  align-items: center;
  border: 1px solid #e5e7eb;
  border-radius: 15px;
  background: #fff;
  grid-template-columns: 36px 1fr auto;
  gap: 10px;
  cursor: pointer;
}
.archive-icon {
  display: grid;
  width: 36px;
  height: 36px;
  place-items: center;
  border-radius: 11px;
  color: var(--category-ink);
  background: var(--category-soft);
}
.citywarn-archive-card div {
  display: flex;
  min-width: 0;
  flex-direction: column;
}
.citywarn-archive-card small {
  color: #9ca3af;
  font-size: 9.5px;
  text-transform: uppercase;
}
.citywarn-archive-card strong {
  margin: 2px 0;
  overflow: hidden;
  font-size: 13.5px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.citywarn-archive-card div > span {
  color: #6b7280;
  font-size: 10.5px;
}
.citywarn-settings {
  display: flex;
  flex-direction: column;
  gap: var(--sky-space-5);
}
.citywarn-settings :deep(.sky-settings-group) {
  margin: 0;
}
.citywarn-settings :deep(.sky-settings-group__title) {
  margin: 0 var(--sky-space-1) var(--sky-space-2);
}
.citywarn-settings :deep(.sky-settings-group__footer) {
  margin: var(--sky-space-2) var(--sky-space-1) 0;
}
.citywarn-settings-hint {
  display: flex;
  margin: 0 var(--sky-space-1);
  align-items: flex-start;
  gap: 7px;
  color: #6b7280;
  font-size: 11px;
  line-height: 1.45;
}
.citywarn-feedback {
  position: absolute;
  z-index: 20;
  right: 14px;
  bottom: calc(18px + env(safe-area-inset-bottom));
  left: 14px;
  display: flex;
  padding: 11px 13px;
  align-items: center;
  border-radius: 13px;
  color: #fff;
  background: rgb(17 24 39 / 94%);
  box-shadow: 0 8px 24px rgb(0 0 0 / 24%);
  gap: 7px;
  font-size: 10px;
  font-weight: 700;
}
.citywarn-toast-enter-active,
.citywarn-toast-leave-active {
  transition: all 0.22s ease;
}
.citywarn-toast-enter-from,
.citywarn-toast-leave-to {
  opacity: 0;
  transform: translateY(12px);
}
.citywarn-compose {
  box-sizing: border-box;
  display: flex;
  width: 100%;
  height: calc(100% - 32px);
  min-height: 0;
  max-height: none;
  padding: 13px 14px calc(var(--sky-safe-area-bottom) + 10px);
  flex-direction: column;
  color: #111827;
}
.citywarn-compose-sheet :deep(.sky-sheet__panel) {
  height: 88%;
  max-height: 88%;
  overflow: hidden;
}
.citywarn-compose > header {
  display: grid;
  align-items: center;
  grid-template-columns: 34px 1fr 34px;
  text-align: center;
}
.citywarn-compose header small {
  color: #9ca3af;
  font-size: 10px;
  text-transform: uppercase;
  letter-spacing: 0.6px;
}
.citywarn-compose h2 {
  margin: 1px 0 0;
  font-size: 18px;
}
.compose-progress {
  display: flex;
  margin: 12px 0 13px;
  gap: 5px;
}
.compose-progress i {
  height: 3px;
  flex: 1;
  border-radius: 4px;
  background: #e5e7eb;
}
.compose-progress i.active {
  background: #dc2626;
}
.compose-body {
  flex: 1;
  overflow-y: auto;
}
.compose-body h3 {
  margin: 4px 0 3px;
  font-size: 17px;
}
.compose-body > p {
  margin: 0 0 13px;
  color: #6b7280;
  font-size: 11.5px;
  line-height: 1.4;
}
.compose-category-grid {
  display: grid;
  margin: 10px 0 18px;
  grid-template-columns: 1fr 1fr;
  gap: 7px;
}
.compose-category-grid button {
  display: flex;
  min-height: 72px;
  padding: 10px;
  align-items: flex-start;
  flex-direction: column;
  justify-content: space-between;
  border: 1px solid #e5e7eb;
  border-radius: 13px;
  color: #374151;
  background: #fff;
  font-size: 11.5px;
  font-weight: 700;
  text-align: left;
}
.compose-category-grid button > svg {
  color: var(--category);
}
.compose-category-grid button.active {
  border-color: var(--category);
  color: var(--category-ink);
  background: var(--category-soft);
  box-shadow: inset 0 0 0 1px var(--category);
}
.compose-severity-list {
  display: flex;
  margin-top: 9px;
  flex-direction: column;
  gap: 6px;
}
.compose-severity-list button {
  display: grid;
  padding: 10px;
  align-items: center;
  border: 1px solid #e5e7eb;
  border-radius: 12px;
  color: #374151;
  background: #fff;
  grid-template-columns: 9px 1fr auto;
  gap: 8px;
  font-size: 12px;
  font-weight: 700;
  text-align: left;
}
.compose-severity-list button > span {
  width: 9px;
  height: 9px;
  border-radius: 50%;
  background: var(--severity);
}
.compose-severity-list button.active {
  border-color: var(--severity);
  color: var(--severity);
  background: #f3f4f6;
}
.compose-area-tabs {
  margin: 13px 0;
}
.compose-area-tabs :deep(button) {
  font-size: 11px;
}
.compose-fields {
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.compose-fields :deep(.sky-field) {
  margin: 0;
}
.compose-fields :deep(.sky-field__input) {
  font-size: 13px;
}
.compose-preview {
  padding: 15px;
  border: 1px solid var(--severity);
  border-radius: 16px;
  background: var(--sky-surface-primary, #fff);
}
.compose-preview > span {
  color: var(--severity);
  font-size: 10px;
  font-weight: 850;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
.compose-preview h4 {
  margin: 7px 0 5px;
  font-size: 18px;
}
.compose-preview p {
  margin: 0;
  color: #4b5563;
  font-size: 12px;
  line-height: 1.45;
}
.compose-preview footer {
  display: flex;
  margin-top: 12px;
  align-items: center;
  gap: 5px;
  color: #6b7280;
  font-size: 10.5px;
}
.compose-recipient {
  display: flex;
  margin-top: 12px;
  padding: 12px;
  border-radius: 14px;
  color: #1e3a8a;
  background: #eff6ff;
  gap: 9px;
}
.compose-recipient strong {
  font-size: 12px;
}
.compose-recipient p {
  margin: 3px 0 0;
  color: #64748b;
  font-size: 10.5px;
  line-height: 1.4;
}
.compose-error {
  margin: 9px 0 0 !important;
  color: #dc2626 !important;
  font-size: 11px !important;
}
.compose-actions {
  display: flex;
  padding-top: 12px;
  gap: 8px;
}
.compose-actions :deep(button) {
  min-height: 42px;
  gap: 6px;
  font-size: 12.5px;
}
.compose-actions :deep(button:not(.sky-button--block)) {
  flex: 1;
}
.citywarn-manage-sheet {
  display: flex;
  min-height: 330px;
  padding: 20px 15px calc(var(--sky-safe-area-bottom) + 10px);
  flex-direction: column;
  color: #111827;
  gap: 13px;
}
.citywarn-manage-sheet h2 {
  margin: 0;
  font-size: 20px;
  text-align: center;
}
.citywarn-manage-sheet :deep(.sky-button) {
  margin-top: auto;
  min-height: 43px;
}
.sky-app-page--dark.citywarn-app {
  --citywarn-ink: #f9fafb;
}
.sky-app-page--dark.citywarn-app :deep(.sky-pill-navigation .sky-segmented) {
  background: rgb(23 25 29 / 98%);
}
.sky-app-page--dark .citywarn-alert-card,
.sky-app-page--dark .citywarn-archive-card,
.sky-app-page--dark .citywarn-map-list,
.sky-app-page--dark .citywarn-meta-grid > div {
  border-color: #30343b;
  background: #17191d;
}
.sky-app-page--dark .citywarn-alert-card > p,
.sky-app-page--dark .citywarn-copy p {
  color: #c7cbd1;
}
.sky-app-page--dark .citywarn-overview {
  border-color: #1f4931;
  background: #12251b;
}
.sky-app-page--dark .citywarn-overview--active {
  border-color: #542626;
  background: #2b1818;
}
.sky-app-page--dark .citywarn-instructions {
  border-color: #632c2c;
  background: #2d1717;
}
.sky-app-page--dark .citywarn-instructions p {
  color: #fecaca;
}
.sky-app-page--dark .citywarn-compose,
.sky-app-page--dark .citywarn-manage-sheet {
  color: #f9fafb;
  background: #111317;
}
.sky-app-page--dark .compose-category-grid button,
.sky-app-page--dark .compose-severity-list button,
.sky-app-page--dark .compose-preview {
  border-color: #343840;
  color: #e5e7eb;
  background: #1c1f24;
}
.sky-app-page--dark .compose-category-grid button.active {
  border-color: var(--category);
  color: var(--category-ink);
  background: var(--category-soft);
}
.sky-app-page--dark .compose-severity-list button.active {
  border-color: var(--severity, #dc2626);
  background: #321a1a;
}
</style>
