<script setup lang="ts">
import {
  Activity,
  ChartNoAxesColumnIncreasing,
  Check,
  ChevronDown,
  ContactRound,
  Flame,
  Footprints,
  HeartPulse,
  MapPin,
  Phone,
  RefreshCw,
  Timer,
  UserRound,
} from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, reactive, ref } from 'vue'

import { useHealthStore } from '@/stores/health'
import { usePhoneStore } from '@/stores/phone'
import type { HealthMedicalIdInput } from '@/types/health'
import {
  SkyAppPage,
  SkyActionButton,
  SkyActionGroup,
  SkyActionSheet,
  SkyActionsLabel,
  SkyButton,
  SkyEmptyState,
  SkyField,
  SkyIcon,
  SkyLink,
  SkyNavbar,
  SkyPillNavigation,
  SkyScrollArea,
  SkySegmented,
  SkySegmentedButton,
  SkySpinner,
} from '@/ui'
import { nuiCall } from '@/utils/nui'

type HealthTab = 'medicalId' | 'today' | 'trends'

const phone = usePhoneStore()
const health = useHealthStore()
const activeTab = ref<HealthTab>('today')
const editingMedicalId = ref(false)
const bloodTypePickerOpened = ref(false)
const actionError = ref('')
const medicalDraft = reactive<HealthMedicalIdInput>({
  allergies: '',
  bloodType: '',
  conditions: '',
  emergencyName: '',
  emergencyPhone: '',
  emergencyRelation: '',
  medication: '',
})

const overview = computed(() => health.overview)
const visibleDays = computed(() => overview.value?.days.slice(-7) ?? [])
const today = computed(() => visibleDays.value.at(-1))
const activeTabIndex = computed(() =>
  activeTab.value === 'today' ? 0 : activeTab.value === 'trends' ? 1 : 2,
)
const navbarTitle = computed(() =>
  activeTab.value === 'today'
    ? phone.t('Apps.health.name')
    : activeTab.value === 'trends'
      ? phone.t('Apps.health.trends.title')
      : phone.t('Apps.health.medicalId.title'),
)
const goalProgress = computed(() => {
  const goal = overview.value?.dailyStepGoal ?? 1
  return Math.min(1, Math.max(0, (today.value?.steps ?? 0) / goal))
})
const ringOffset = computed(() => 527.79 * (1 - goalProgress.value))
const maximumDaySteps = computed(() =>
  Math.max(
    overview.value?.dailyStepGoal ?? 1,
    ...visibleDays.value.map((day) => day.steps),
  ),
)
const weekSteps = computed(() =>
  visibleDays.value.reduce((total, day) => total + day.steps, 0),
)
const dailyAverage = computed(() =>
  Math.round(weekSteps.value / Math.max(1, visibleDays.value.length)),
)
const previousWeekSteps = computed(() => overview.value?.previousWeekSteps ?? 0)
const trendPercent = computed(() => {
  if (previousWeekSteps.value <= 0) return 0
  return Math.round(
    ((weekSteps.value - previousWeekSteps.value) / previousWeekSteps.value) *
      100,
  )
})
const trendCopy = computed(() => {
  if (trendPercent.value > 0) {
    return phone.t('Apps.health.trends.more', {
      count: String(trendPercent.value),
    })
  }
  if (trendPercent.value < 0) {
    return phone.t('Apps.health.trends.less', {
      count: String(Math.abs(trendPercent.value)),
    })
  }
  return phone.t('Apps.health.trends.same')
})
const dateRange = computed(() => {
  if (!visibleDays.value.length) return ''
  const start = new Date(`${visibleDays.value[0].date}T12:00:00`)
  const end = new Date(`${visibleDays.value.at(-1)?.date}T12:00:00`)
  const formatter = new Intl.DateTimeFormat(phone.lang, {
    day: 'numeric',
    month: 'short',
  })
  return `${formatter.format(start)}–${formatter.format(end)}`
})
const medicalId = computed(() => overview.value?.medicalId)
const bloodTypeOptions = [
  { label: '—', value: '' },
  ...['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((value) => ({
    label: value,
    value,
  })),
]

function formatNumber(value: number): string {
  return new Intl.NumberFormat(phone.lang).format(value)
}

function formatDistance(meters: number): string {
  return phone.t('Apps.health.kilometers', {
    count: (meters / 1000).toFixed(1),
  })
}

function formatMinutes(seconds: number): string {
  return phone.t('Apps.health.minutes', {
    count: String(Math.round(seconds / 60)),
  })
}

function weekday(date: string): string {
  const value = new Intl.DateTimeFormat(phone.lang, { weekday: 'short' })
    .format(new Date(`${date}T12:00:00`))
    .replace(/\.$/, '')
  return Array.from(value).slice(0, 2).join('')
}

function fullDate(date: string): string {
  return new Intl.DateTimeFormat(phone.lang, {
    day: 'numeric',
    month: 'short',
  }).format(new Date(`${date}T12:00:00`))
}

function selectTab(tab: HealthTab): void {
  if (editingMedicalId.value && tab !== 'medicalId') return
  actionError.value = ''
  activeTab.value = tab
}

function syncMedicalDraft(): void {
  if (!medicalId.value) return
  medicalDraft.allergies = medicalId.value.allergies
  medicalDraft.bloodType = medicalId.value.bloodType
  medicalDraft.conditions = medicalId.value.conditions
  medicalDraft.emergencyName = medicalId.value.emergencyName
  medicalDraft.emergencyPhone = medicalId.value.emergencyPhone
  medicalDraft.emergencyRelation = medicalId.value.emergencyRelation
  medicalDraft.medication = medicalId.value.medication
}

async function toggleMedicalEdit(): Promise<void> {
  actionError.value = ''
  bloodTypePickerOpened.value = false
  if (!editingMedicalId.value) {
    syncMedicalDraft()
    editingMedicalId.value = true
    return
  }
  if (await health.saveMedicalId({ ...medicalDraft })) {
    editingMedicalId.value = false
    return
  }
  const errorKey = `Apps.health.errors.${health.error}`
  const translatedError = phone.t(errorKey)
  actionError.value =
    translatedError === errorKey
      ? phone.t('Apps.health.medicalId.saveFailed')
      : translatedError
}

function selectBloodType(value: string): void {
  medicalDraft.bloodType = value
  bloodTypePickerOpened.value = false
}

async function dial(number: string): Promise<void> {
  if (!number) return
  actionError.value = ''
  const response = await nuiCall('calls:dial', { phoneNumber: number })
  if (!response.success) {
    actionError.value = phone.t('Apps.phone.callFailed')
  }
}

function handleWindowMessage(event: MessageEvent): void {
  if (event.data?.type === 'health:changed') void health.load()
}

onMounted(() => {
  window.addEventListener('message', handleWindowMessage)
  void health.load()
})

onBeforeUnmount(() => {
  window.removeEventListener('message', handleWindowMessage)
})
</script>

<template>
  <SkyAppPage
    class="health-app"
    :accent="phone.isDarkMode ? '#ff375f' : '#d9264d'"
    accent-soft="rgba(255, 55, 95, 0.16)"
    :dark="phone.isDarkMode"
    :label="phone.t('Apps.health.name')"
  >
    <SkyNavbar :title="navbarTitle">
      <template v-if="activeTab === 'medicalId'" #right>
        <SkyLink
          component="button"
          :disabled="health.isSaving"
          type="button"
          @click="toggleMedicalEdit"
        >
          {{
            editingMedicalId
              ? phone.t('Apps.health.medicalId.done')
              : phone.t('Apps.health.medicalId.edit')
          }}
        </SkyLink>
      </template>
    </SkyNavbar>

    <SkyScrollArea class="health-content" padded with-tabbar>
      <div v-if="health.isLoading && !overview" class="health-loading">
        <SkySpinner />
        <span>{{ phone.t('Apps.health.loading') }}</span>
      </div>

      <SkyEmptyState
        v-else-if="!overview"
        :body="phone.t('Apps.health.errorBody')"
        :title="phone.t('Apps.health.errorTitle')"
        tone="danger"
      >
        <template #icon><HeartPulse :size="30" /></template>
        <template #actions>
          <SkyButton rounded tonal @click="health.load">
            <RefreshCw :size="17" />{{ phone.t('Apps.health.tryAgain') }}
          </SkyButton>
        </template>
      </SkyEmptyState>

      <template v-else-if="activeTab === 'today'">
        <section class="health-hero" aria-labelledby="health-step-value">
          <svg class="health-ring" viewBox="0 0 188 188" aria-hidden="true">
            <circle class="health-ring__track" cx="94" cy="94" r="84" />
            <circle
              class="health-ring__progress"
              cx="94"
              cy="94"
              r="84"
              :style="{ strokeDashoffset: ringOffset }"
            />
          </svg>
          <div class="health-hero__content">
            <Footprints :size="25" aria-hidden="true" />
            <strong id="health-step-value">{{
              formatNumber(today?.steps ?? 0)
            }}</strong>
            <span>{{ phone.t('Apps.health.steps') }}</span>
            <small>{{
              phone.t('Apps.health.goal', {
                count: formatNumber(overview.dailyStepGoal),
              })
            }}</small>
          </div>
        </section>

        <section
          class="health-metrics"
          :aria-label="phone.t('Apps.health.snapshot')"
        >
          <div>
            <MapPin :size="20" aria-hidden="true" />
            <strong>{{ formatDistance(today?.distanceMeters ?? 0) }}</strong>
            <span>{{ phone.t('Apps.health.distance') }}</span>
          </div>
          <div>
            <Timer :size="20" aria-hidden="true" />
            <strong>{{ formatMinutes(today?.activeSeconds ?? 0) }}</strong>
            <span>{{ phone.t('Apps.health.active') }}</span>
          </div>
          <div>
            <Flame :size="20" aria-hidden="true" />
            <strong>{{
              phone.t('Apps.health.kilocalories', {
                count: formatNumber(today?.energyKcal ?? 0),
              })
            }}</strong>
            <span>{{ phone.t('Apps.health.energy') }}</span>
          </div>
        </section>

        <section class="health-section">
          <h2>{{ phone.t('Apps.health.thisWeek') }}</h2>
          <div class="health-week-chart">
            <div
              v-for="day in visibleDays"
              :key="day.date"
              class="health-week-day"
            >
              <span>{{ weekday(day.date) }}</span>
              <div class="health-week-bar" aria-hidden="true">
                <i
                  :style="{
                    height: `${Math.max(5, (day.steps / maximumDaySteps) * 100)}%`,
                  }"
                />
              </div>
              <small>{{ formatNumber(day.steps) }}</small>
            </div>
          </div>
        </section>
      </template>

      <template v-else-if="activeTab === 'trends'">
        <section class="health-trend-header">
          <span>{{ dateRange }}</span>
          <strong>{{
            phone.t('Apps.health.trends.total', {
              count: formatNumber(weekSteps),
            })
          }}</strong>
          <small :class="{ 'health-trend-negative': trendPercent < 0 }">{{
            trendCopy
          }}</small>
        </section>

        <section
          class="health-trend-chart"
          :aria-label="phone.t('Apps.health.trends.dailyActivity')"
        >
          <div class="health-goal-line" aria-hidden="true">
            <span>{{ phone.t('Apps.health.trends.goal') }}</span>
          </div>
          <div
            v-for="day in visibleDays"
            :key="day.date"
            class="health-trend-column"
          >
            <div class="health-trend-column__bar">
              <i
                :style="{
                  height: `${Math.max(3, (day.steps / maximumDaySteps) * 100)}%`,
                }"
              />
            </div>
            <span>{{ weekday(day.date) }}</span>
          </div>
        </section>

        <div class="health-list health-trend-summary">
          <div class="health-list__row">
            <span class="health-list__icon">
              <ChartNoAxesColumnIncreasing :size="21" />
            </span>
            <span>{{ phone.t('Apps.health.trends.dailyAverage') }}</span>
            <strong>{{ formatNumber(dailyAverage) }}</strong>
          </div>
          <div class="health-list__row">
            <span class="health-list__icon health-list__icon--orange">
              <MapPin :size="21" />
            </span>
            <span>{{ phone.t('Apps.health.distance') }}</span>
            <strong>{{
              formatDistance(
                visibleDays.reduce(
                  (total, day) => total + day.distanceMeters,
                  0,
                ),
              )
            }}</strong>
          </div>
          <div class="health-list__row">
            <span class="health-list__icon health-list__icon--orange">
              <Timer :size="21" />
            </span>
            <span>{{ phone.t('Apps.health.trends.activeTime') }}</span>
            <strong>{{
              formatMinutes(
                visibleDays.reduce(
                  (total, day) => total + day.activeSeconds,
                  0,
                ),
              )
            }}</strong>
          </div>
        </div>

        <section class="health-section">
          <h2>{{ phone.t('Apps.health.trends.dailyActivity') }}</h2>
          <div class="health-list health-daily-list">
            <div
              v-for="day in visibleDays"
              :key="day.date"
              class="health-list__row"
            >
              <strong class="health-day-letter">{{ weekday(day.date) }}</strong>
              <span>{{ fullDate(day.date) }}</span>
              <strong>{{ formatNumber(day.steps) }}</strong>
            </div>
          </div>
        </section>
      </template>

      <template v-else>
        <section class="health-medical-hero">
          <span class="health-medical-mark"><HeartPulse :size="40" /></span>
          <div>
            <strong>{{ medicalId?.playerName }}</strong>
            <span>{{ phone.t('Apps.health.medicalId.resident') }}</span>
          </div>
        </section>

        <template v-if="editingMedicalId">
          <section class="health-section">
            <h2>{{ phone.t('Apps.health.medicalId.emergencyInformation') }}</h2>
            <ul class="health-form">
              <li class="health-blood-type-field">
                <button
                  type="button"
                  aria-haspopup="dialog"
                  :aria-expanded="bloodTypePickerOpened"
                  @click="bloodTypePickerOpened = true"
                >
                  <span>{{ phone.t('Apps.health.medicalId.bloodType') }}</span>
                  <strong>{{ medicalDraft.bloodType || '—' }}</strong>
                  <ChevronDown :size="17" aria-hidden="true" />
                </button>
              </li>
              <SkyField
                v-model="medicalDraft.allergies"
                :label="phone.t('Apps.health.medicalId.allergies')"
                :maxlength="500"
                type="textarea"
              />
              <SkyField
                v-model="medicalDraft.conditions"
                :label="phone.t('Apps.health.medicalId.conditions')"
                :maxlength="500"
                type="textarea"
              />
              <SkyField
                v-model="medicalDraft.medication"
                :label="phone.t('Apps.health.medicalId.medication')"
                :maxlength="500"
                type="textarea"
              />
            </ul>
          </section>
          <section class="health-section">
            <h2>{{ phone.t('Apps.health.medicalId.emergencyContact') }}</h2>
            <ul class="health-form">
              <SkyField
                v-model="medicalDraft.emergencyName"
                :label="phone.t('Apps.health.medicalId.contactName')"
                :maxlength="80"
              />
              <SkyField
                v-model="medicalDraft.emergencyRelation"
                :label="phone.t('Apps.health.medicalId.relation')"
                :maxlength="40"
              />
              <SkyField
                v-model="medicalDraft.emergencyPhone"
                input-mode="tel"
                :label="phone.t('Apps.health.medicalId.phoneNumber')"
                :maxlength="24"
                type="tel"
              />
            </ul>
          </section>
        </template>

        <template v-else>
          <section class="health-section">
            <h2>{{ phone.t('Apps.health.medicalId.emergencyInformation') }}</h2>
            <div class="health-list health-medical-list">
              <div class="health-list__row">
                <span>{{ phone.t('Apps.health.medicalId.bloodType') }}</span>
                <strong class="health-value--accent">{{
                  medicalId?.bloodType ||
                  phone.t('Apps.health.medicalId.noneRecorded')
                }}</strong>
              </div>
              <div class="health-list__row">
                <span>{{ phone.t('Apps.health.medicalId.allergies') }}</span>
                <strong>{{
                  medicalId?.allergies ||
                  phone.t('Apps.health.medicalId.noneRecorded')
                }}</strong>
              </div>
              <div class="health-list__row">
                <span>{{ phone.t('Apps.health.medicalId.conditions') }}</span>
                <strong>{{
                  medicalId?.conditions ||
                  phone.t('Apps.health.medicalId.noneRecorded')
                }}</strong>
              </div>
              <div class="health-list__row">
                <span>{{ phone.t('Apps.health.medicalId.medication') }}</span>
                <strong>{{
                  medicalId?.medication ||
                  phone.t('Apps.health.medicalId.noneRecorded')
                }}</strong>
              </div>
            </div>
          </section>

          <section class="health-section">
            <h2>{{ phone.t('Apps.health.medicalId.emergencyContact') }}</h2>
            <div class="health-contact">
              <span class="health-contact__avatar"
                ><UserRound :size="27"
              /></span>
              <div>
                <strong>{{
                  medicalId?.emergencyName ||
                  phone.t('Apps.health.medicalId.noneRecorded')
                }}</strong>
                <span>{{ medicalId?.emergencyRelation }}</span>
              </div>
              <button
                type="button"
                :aria-label="phone.t('Apps.health.medicalId.callContact')"
                :disabled="!medicalId?.emergencyPhone"
                @click="dial(medicalId?.emergencyPhone ?? '')"
              >
                <Phone :size="22" />
              </button>
            </div>
          </section>

          <SkyButton
            block
            class="health-emergency-button"
            large
            variant="danger"
            @click="dial(overview.emergencyNumber)"
          >
            <Phone :size="20" />{{
              phone.t('Apps.health.medicalId.emergencyCall')
            }}
          </SkyButton>
        </template>

        <p v-if="actionError" class="health-action-error" role="alert">
          {{ actionError }}
        </p>
      </template>
    </SkyScrollArea>

    <SkyActionSheet
      :aria-label="phone.t('Apps.health.medicalId.bloodType')"
      :opened="bloodTypePickerOpened"
      @backdropclick="bloodTypePickerOpened = false"
      @escape="bloodTypePickerOpened = false"
    >
      <SkyActionGroup>
        <SkyActionsLabel>
          {{ phone.t('Apps.health.medicalId.bloodType') }}
        </SkyActionsLabel>
        <SkyActionButton
          v-for="option in bloodTypeOptions"
          :key="option.value || 'none'"
          class="health-blood-type-option"
          :bold="medicalDraft.bloodType === option.value"
          :aria-pressed="medicalDraft.bloodType === option.value"
          @click="selectBloodType(option.value)"
        >
          <span>{{ option.label }}</span>
          <Check
            v-if="medicalDraft.bloodType === option.value"
            :size="18"
            aria-hidden="true"
          />
        </SkyActionButton>
      </SkyActionGroup>
      <SkyActionGroup>
        <SkyActionButton bold @click="bloodTypePickerOpened = false">
          {{ phone.t('Common.cancel') }}
        </SkyActionButton>
      </SkyActionGroup>
    </SkyActionSheet>

    <SkyPillNavigation
      class="health-navigation"
      layout="full"
      :label="phone.t('Apps.health.navigation')"
    >
      <SkySegmented
        strong
        rounded
        navigation
        :active-index="activeTabIndex"
        :aria-label="phone.t('Apps.health.navigation')"
        :item-count="3"
      >
        <SkySegmentedButton
          :active="activeTab === 'today'"
          :disabled="editingMedicalId"
          @click="selectTab('today')"
        >
          <span class="health-navigation__item">
            <SkyIcon :size="20"><Activity :size="20" /></SkyIcon>
            <span>{{ phone.t('Apps.health.tabs.today') }}</span>
          </span>
        </SkySegmentedButton>
        <SkySegmentedButton
          :active="activeTab === 'trends'"
          :disabled="editingMedicalId"
          @click="selectTab('trends')"
        >
          <span class="health-navigation__item">
            <SkyIcon :size="20"
              ><ChartNoAxesColumnIncreasing :size="20"
            /></SkyIcon>
            <span>{{ phone.t('Apps.health.tabs.trends') }}</span>
          </span>
        </SkySegmentedButton>
        <SkySegmentedButton
          :active="activeTab === 'medicalId'"
          @click="selectTab('medicalId')"
        >
          <span class="health-navigation__item">
            <SkyIcon :size="20"><ContactRound :size="20" /></SkyIcon>
            <span>{{ phone.t('Apps.health.tabs.medicalId') }}</span>
          </span>
        </SkySegmentedButton>
      </SkySegmented>
    </SkyPillNavigation>
  </SkyAppPage>
</template>

<style scoped>
.health-app {
  --health-accent: var(--sky-app-accent);
  --health-orange: #ff9f0a;
  --health-green: var(--sky-success);
  --health-panel: var(--sky-surface);
  --health-panel-border: var(--sky-hairline);
  --health-track: var(--sky-surface-tint);
  background: var(--sky-bg);
}

.health-app.sky-app-page--dark {
  --health-panel: #171719;
  --health-panel-border: rgba(255, 255, 255, 0.13);
  --health-track: #343438;
}

.health-content {
  display: flex;
  flex-direction: column;
  gap: var(--sky-space-5);
}

.health-loading {
  display: flex;
  min-height: 360px;
  align-items: center;
  justify-content: center;
  flex-direction: column;
  gap: var(--sky-space-3);
  color: var(--sky-muted);
  font-size: 14px;
}

.health-hero {
  position: relative;
  width: 232px;
  height: 232px;
  margin: 2px auto 0;
}

.health-ring {
  width: 100%;
  height: 100%;
  filter: drop-shadow(0 8px 18px rgba(255, 55, 95, 0.18));
  transform: rotate(-90deg);
}

.health-ring circle {
  fill: none;
  stroke-width: 14;
}

.health-ring__track {
  stroke: var(--health-track);
}

.health-ring__progress {
  stroke: var(--health-accent);
  stroke-linecap: round;
  stroke-dasharray: 527.79;
  transition: stroke-dashoffset 500ms var(--sky-ease-out);
}

.health-hero__content {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-direction: column;
  color: var(--health-accent);
}

.health-hero__content strong {
  margin-top: 5px;
  color: var(--sky-text);
  font-size: 42px;
  font-weight: 750;
  letter-spacing: -1.8px;
  line-height: 1;
}

.health-hero__content > span {
  margin-top: 5px;
  color: var(--sky-text);
  font-size: 17px;
  font-weight: 650;
}

.health-hero__content small {
  margin-top: 4px;
  color: var(--sky-muted);
  font-size: 13px;
}

.health-metrics {
  display: grid;
  overflow: hidden;
  border: calc(var(--sky-hairline-scale) * 1px) solid var(--health-panel-border);
  border-radius: var(--sky-radius-card);
  background: var(--health-panel);
  flex: none;
  grid-template-columns: repeat(3, 1fr);
}

.health-metrics > div {
  position: relative;
  display: flex;
  min-width: 0;
  min-height: 104px;
  align-items: center;
  justify-content: center;
  flex-direction: column;
  gap: 4px;
  color: var(--health-accent);
}

.health-metrics > div:nth-child(2) {
  color: var(--health-orange);
}

.health-metrics > div:not(:last-child)::after {
  position: absolute;
  top: 18px;
  right: 0;
  bottom: 18px;
  width: calc(var(--sky-hairline-scale) * 1px);
  background: var(--health-panel-border);
  content: '';
}

.health-metrics strong {
  color: var(--sky-text);
  font-size: 15px;
  font-weight: 700;
  white-space: nowrap;
}

.health-metrics span {
  color: var(--sky-text);
  font-size: 13px;
  font-weight: 600;
}

.health-section {
  display: flex;
  flex-direction: column;
  gap: var(--sky-space-3);
}

.health-section h2 {
  margin: 0 2px;
  color: var(--sky-text);
  font-size: 20px;
  font-weight: 720;
  letter-spacing: -0.25px;
}

.health-week-chart {
  display: grid;
  min-height: 158px;
  padding: 16px 10px 13px;
  border: calc(var(--sky-hairline-scale) * 1px) solid var(--health-panel-border);
  border-radius: var(--sky-radius-card);
  background: var(--health-panel);
  grid-template-columns: repeat(7, 1fr);
}

.health-week-day {
  display: grid;
  min-width: 0;
  justify-items: center;
  grid-template-rows: 18px 1fr 16px;
  gap: 6px;
  color: var(--sky-muted);
  font-size: 11px;
}

.health-week-bar {
  display: flex;
  width: 12px;
  height: 86px;
  align-items: flex-end;
  overflow: hidden;
  border-radius: var(--sky-radius-pill);
  background: var(--health-track);
}

.health-week-bar i {
  display: block;
  width: 100%;
  border-radius: inherit;
  background: var(--health-accent);
}

.health-week-day small {
  overflow: hidden;
  max-width: 40px;
  color: var(--sky-muted);
  font-size: 9px;
  text-overflow: ellipsis;
}

.health-list {
  overflow: hidden;
  border: calc(var(--sky-hairline-scale) * 1px) solid var(--health-panel-border);
  border-radius: var(--sky-radius-card);
  background: var(--health-panel);
}

.health-list__row {
  position: relative;
  display: grid;
  min-height: 62px;
  align-items: center;
  padding: 8px 14px;
  grid-template-columns: auto minmax(0, 1fr) auto;
  gap: 12px;
  color: var(--sky-text);
  font-size: 15px;
}

.health-list__row:not(:last-child)::after {
  position: absolute;
  right: 14px;
  bottom: 0;
  left: 56px;
  height: calc(var(--sky-hairline-scale) * 1px);
  background: var(--health-panel-border);
  content: '';
}

.health-list__row > strong:last-child {
  overflow: hidden;
  max-width: 164px;
  color: var(--sky-muted);
  font-weight: 620;
  text-align: right;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.health-list__icon {
  display: grid;
  width: 34px;
  height: 34px;
  place-items: center;
  border-radius: 12px;
  background: var(--sky-app-accent-soft);
  color: var(--health-accent);
}

.health-list__icon--green {
  background: var(--sky-success-soft);
  color: var(--health-green);
}

.health-list__icon--orange {
  background: var(--sky-warning-soft);
  color: var(--health-orange);
}

.health-list__row .health-value--accent {
  color: var(--health-accent);
}

.health-trend-header {
  display: flex;
  align-items: center;
  flex-direction: column;
  padding-top: 4px;
}

.health-trend-header > span {
  color: var(--sky-muted);
  font-size: 14px;
}

.health-trend-header strong {
  margin-top: 8px;
  color: var(--sky-text);
  font-size: 35px;
  font-weight: 760;
  letter-spacing: -1px;
}

.health-trend-header small {
  margin-top: 3px;
  color: var(--health-accent);
  font-size: 14px;
  font-weight: 650;
}

.health-trend-header .health-trend-negative {
  color: var(--health-orange);
}

.health-trend-chart {
  position: relative;
  display: grid;
  height: 230px;
  padding: 20px 10px 0;
  border-bottom: calc(var(--sky-hairline-scale) * 1px) solid
    var(--health-panel-border);
  grid-template-columns: repeat(7, 1fr);
}

.health-trend-column {
  z-index: 1;
  display: grid;
  justify-items: center;
  grid-template-rows: 1fr 32px;
  color: var(--sky-muted);
  font-size: 12px;
}

.health-trend-column__bar {
  display: flex;
  width: 25px;
  height: 178px;
  align-items: flex-end;
}

.health-trend-column__bar i {
  width: 100%;
  min-height: 5px;
  border-radius: 7px 7px 3px 3px;
  background: var(--health-accent);
  opacity: 0.56;
}

.health-trend-column:last-child .health-trend-column__bar i {
  opacity: 1;
}

.health-goal-line {
  position: absolute;
  z-index: 0;
  top: 57px;
  right: 10px;
  left: 10px;
  border-top: 1px dashed var(--health-accent);
}

.health-goal-line span {
  position: absolute;
  top: -10px;
  right: 0;
  padding: 2px 5px;
  border-radius: 6px;
  background: var(--health-accent);
  color: #fff;
  font-size: 10px;
  font-weight: 700;
}

.health-trend-summary {
  flex: none;
}

.health-day-letter {
  width: 20px;
  color: var(--health-accent);
}

.health-medical-hero {
  display: flex;
  align-items: center;
  padding: 5px 3px 3px;
  gap: 18px;
}

.health-medical-mark {
  display: grid;
  width: 92px;
  height: 92px;
  flex: none;
  place-items: center;
  border: 1px solid var(--health-panel-border);
  border-radius: 28px;
  background: var(--health-panel);
  color: var(--health-accent);
}

.health-medical-hero > div {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 5px;
}

.health-medical-hero strong {
  overflow: hidden;
  color: var(--sky-text);
  font-size: 25px;
  font-weight: 740;
  letter-spacing: -0.5px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.health-medical-hero span {
  color: var(--sky-muted);
  font-size: 14px;
}

.health-medical-list .health-list__row {
  min-height: 67px;
  grid-template-columns: minmax(0, 1fr) auto;
}

.health-medical-list .health-list__row::after {
  left: 14px;
}

.health-contact {
  display: grid;
  min-height: 96px;
  align-items: center;
  padding: 12px 14px;
  border: calc(var(--sky-hairline-scale) * 1px) solid var(--health-panel-border);
  border-radius: var(--sky-radius-card);
  background: var(--health-panel);
  grid-template-columns: auto minmax(0, 1fr) auto;
  gap: 12px;
}

.health-contact__avatar {
  display: grid;
  width: 54px;
  height: 54px;
  place-items: center;
  border: 1px solid var(--health-panel-border);
  border-radius: 50%;
  color: var(--sky-muted);
}

.health-contact > div {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 4px;
}

.health-contact > div strong,
.health-contact > div span {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.health-contact > div strong {
  color: var(--sky-text);
  font-size: 17px;
}

.health-contact > div span {
  color: var(--sky-muted);
  font-size: 13px;
}

.health-contact button {
  display: grid;
  width: var(--sky-touch-target);
  height: var(--sky-touch-target);
  place-items: center;
  border: 1px solid var(--health-panel-border);
  border-radius: 14px;
  background: var(--sky-surface-variant);
  color: var(--health-accent);
  cursor: pointer;
}

.health-contact button:disabled {
  color: var(--sky-subtle);
  cursor: default;
}

.health-emergency-button {
  min-height: 54px;
  flex: none;
  gap: 9px;
}

.health-form {
  overflow: hidden;
  margin: 0;
  padding: 0;
  border: calc(var(--sky-hairline-scale) * 1px) solid var(--health-panel-border);
  border-radius: var(--sky-radius-card);
  background: var(--health-panel);
  list-style: none;
}

.health-blood-type-field button {
  display: grid;
  width: 100%;
  min-height: 58px;
  align-items: center;
  padding: 8px 16px;
  border: 0;
  background: transparent;
  color: var(--sky-text);
  cursor: pointer;
  grid-template-columns: 1fr auto auto;
  grid-template-rows: auto auto;
  text-align: left;
}

.health-blood-type-field button:focus-visible {
  outline: 2px solid var(--sky-app-accent);
  outline-offset: -2px;
}

.health-blood-type-field span {
  grid-column: 1 / -1;
  color: var(--sky-muted);
  font-size: 12px;
  line-height: 16px;
}

.health-blood-type-field strong {
  font-size: 17px;
  font-weight: 400;
  line-height: 24px;
}

.health-blood-type-field svg {
  color: var(--sky-muted);
}

.health-blood-type-option {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.health-blood-type-option svg {
  color: var(--sky-app-accent);
}

.health-action-error {
  margin: 0;
  padding: 0 4px;
  color: var(--sky-danger);
  font-size: 13px;
  text-align: center;
}

.health-navigation__item {
  display: flex;
  min-width: 0;
  align-items: center;
  justify-content: center;
  flex-direction: column;
  gap: 2px;
  font-size: 10px;
  font-weight: 620;
  line-height: 1.1;
  white-space: nowrap;
}

@media (prefers-reduced-motion: reduce) {
  .health-ring__progress {
    transition: none;
  }
}
</style>
