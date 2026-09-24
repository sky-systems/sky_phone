<script setup lang="ts">
import {
  Clock3,
  RadioTower,
  Settings,
  Signal,
  Users,
  Volume2,
} from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'

import { usePhoneStore } from '@/stores/phone'
import { useRadioStore } from '@/stores/radio'
import type { RadioHistoryEntry } from '@/types/radio'
import {
  SkyAppPage,
  SkyButton,
  SkyEmptyState,
  SkyField,
  SkyList,
  SkyListItem,
  SkyNavbar,
  SkyPillNavigation,
  SkyRange,
  SkyScrollArea,
  SkySection,
  SkySegmented,
  SkySegmentedButton,
  SkySettingsGroup,
  SkySettingsRow,
  SkySpinner,
  SkyStatusCard,
  SkyNotification,
  SkyToggle,
} from '@/ui'
import { isTrustedRootMessageSource } from '@/utils/windowMessages'

type RadioTab = 'radio' | 'settings'

const phone = usePhoneStore()
const radio = useRadioStore()
const tab = ref<RadioTab>('radio')
const primaryInput = ref('')
const secondaryInput = ref('')
const badgeInput = ref('')
const displayNameInput = ref('')
const feedback = ref('')
const volumeInput = ref(50)
const now = ref(Date.now())
const memberSnapshotAt = ref(Date.now())
let clockHandle: number | null = null
let feedbackHandle: number | null = null

const statusText = computed(() => {
  if (!radio.data.connected) return phone.t('Apps.radio.disconnected')
  const secondary = radio.data.secondaryFrequency
    ? ` / ${radio.data.secondaryFrequency}`
    : ''
  return phone.t('Apps.radio.connectedTo', {
    frequency: `${radio.data.frequency}${secondary}`,
  })
})

const providerText = computed(() => {
  const provider = radio.data.provider
  if (!provider) return phone.t('Apps.radio.noProvider')
  return provider.replace(/^./, (character) => character.toLocaleUpperCase())
})

const speakerDescription = computed(() =>
  phone.t(
    radio.data.speakerSupported
      ? 'Apps.radio.speakerDescription'
      : 'Apps.radio.providerFeatureUnavailable',
  ),
)

function parseFrequency(value: string): number {
  return Number.parseFloat(value.replace(',', '.'))
}

function errorText(code: string): string {
  return phone.t(`Apps.radio.errors.${code || 'default'}`)
}

function showFeedback(message: string): void {
  if (feedbackHandle !== null) window.clearTimeout(feedbackHandle)
  feedback.value = message
  feedbackHandle = window.setTimeout(() => {
    feedback.value = ''
    feedbackHandle = null
  }, 2500)
}

async function connect(
  primary = parseFrequency(primaryInput.value),
  secondary = parseFrequency(secondaryInput.value) || 0,
): Promise<void> {
  if (!Number.isFinite(primary)) {
    radio.error = 'invalid_frequency'
    return
  }

  const connected = await radio.connect(primary, secondary)
  if (connected) {
    memberSnapshotAt.value = Date.now()
    primaryInput.value = String(radio.data.frequency)
    secondaryInput.value = radio.data.secondaryFrequency
      ? String(radio.data.secondaryFrequency)
      : ''
  }
}

async function disconnect(): Promise<void> {
  await radio.disconnect()
}

function saveVolume(): void {
  void radio.setVolume(volumeInput.value)
}

async function setSpeaker(enabled: boolean): Promise<void> {
  if (await radio.setSpeaker(enabled)) return
  showFeedback(errorText(radio.error))
}

function connectHistory(entry: RadioHistoryEntry): void {
  primaryInput.value = String(entry.primary)
  secondaryInput.value = entry.secondary ? String(entry.secondary) : ''
  void connect(entry.primary, entry.secondary)
}

function formatDuration(joinTime: number): string {
  const seconds = Math.max(
    0,
    joinTime + Math.floor((now.value - memberSnapshotAt.value) / 1000),
  )
  const minutes = Math.floor(seconds / 60)
  const hours = Math.floor(minutes / 60)
  if (hours) return `${hours}h ${minutes % 60}m`
  if (minutes) return `${minutes}m ${seconds % 60}s`
  return `${seconds}s`
}

function normalizedBadge(): string {
  const clean = badgeInput.value
    .replace(/[^A-Za-z0-9_-]/g, '')
    .slice(0, radio.data.badgeMaxLength)
  badgeInput.value = clean
  return clean
}

function normalizedDisplayName(): string {
  const clean = Array.from(
    displayNameInput.value
      .replace(/[\u0000-\u001F\u007F]/g, '')
      .replace(/\s+/g, ' ')
      .trim(),
  )
    .slice(0, radio.data.displayNameMaxLength)
    .join('')
  displayNameInput.value = clean
  return clean
}

async function saveDisplayNameSetting(): Promise<void> {
  if (!radio.data.displayNameEnabled || !radio.data.displayNameAllowed) return

  const displayName = normalizedDisplayName()
  if (displayName === radio.data.displayName) return

  const saved = await radio.saveDisplayName(displayName)
  if (displayNameInput.value !== displayName) return

  if (!saved) {
    displayNameInput.value = radio.data.displayName
    showFeedback(errorText(radio.error))
    return
  }

  displayNameInput.value = radio.data.displayName
}

async function saveBadgeSetting(): Promise<void> {
  if (!radio.data.badgeEnabled) return

  const badge = normalizedBadge()
  if (badge === radio.data.badge) return

  const saved = await radio.saveBadge(badge)
  if (badgeInput.value !== badge) return

  if (!saved) {
    badgeInput.value = radio.data.badge
    showFeedback(errorText(radio.error))
    return
  }

  badgeInput.value = radio.data.badge
}

function onMessage(event: MessageEvent): void {
  if (!isTrustedRootMessageSource(event.source, window)) return
  if (event.data?.type === 'radio:updated' && event.data.data?.members) {
    memberSnapshotAt.value = Date.now()
    radio.updateMembers(event.data.data.members)
  }
}

watch(
  () => radio.data.volume,
  (volume) => (volumeInput.value = volume),
)

onMounted(async () => {
  window.addEventListener('message', onMessage)
  clockHandle = window.setInterval(() => (now.value = Date.now()), 1000)
  await radio.load()
  memberSnapshotAt.value = Date.now()
  badgeInput.value = radio.data.badge
  displayNameInput.value = radio.data.displayName
  volumeInput.value = radio.data.volume
  if (radio.data.frequency) primaryInput.value = String(radio.data.frequency)
  if (radio.data.secondaryFrequency) {
    secondaryInput.value = String(radio.data.secondaryFrequency)
  }
})

onBeforeUnmount(() => {
  window.removeEventListener('message', onMessage)
  if (clockHandle !== null) window.clearInterval(clockHandle)
  if (feedbackHandle !== null) window.clearTimeout(feedbackHandle)
})
</script>

<template>
  <SkyAppPage
    class="radio-app"
    :accent="phone.isDarkMode ? '#0a84ff' : '#0074e8'"
    accent-soft="rgba(10, 132, 255, 0.16)"
    :dark="phone.isDarkMode"
    :label="phone.t('Apps.radio.name')"
  >
    <SkyNavbar :title="phone.t('Apps.radio.name')" />

    <SkyScrollArea padded class="radio-content" with-tabbar>
      <div v-if="radio.isLoading && !radio.data.provider" class="radio-loading">
        <SkySpinner :label="phone.t('Common.loading')" />
        <span aria-hidden="true">{{ phone.t('Common.loading') }}</span>
      </div>

      <template v-else-if="tab === 'radio'">
        <SkyStatusCard
          :title="statusText"
          :subtitle="providerText"
          :tone="radio.data.connected ? 'success' : 'neutral'"
          aria-live="polite"
          indicator
        >
          <template #icon>
            <Signal :size="22" aria-hidden="true" />
          </template>
        </SkyStatusCard>

        <SkySection :title="phone.t('Apps.radio.channel')">
          <SkyList density="compact" flush inset strong>
            <SkyField
              v-model="primaryInput"
              type="number"
              input-mode="decimal"
              :label="phone.t('Apps.radio.primaryFrequency')"
              :placeholder="phone.t('Apps.radio.frequencyPlaceholder')"
              :min="radio.data.frequencyMin"
              :max="radio.data.frequencyMax"
              :step="radio.data.frequencyStep"
            >
              <template #leading>
                <RadioTower :size="20" aria-hidden="true" />
              </template>
              <template #trailing>
                <span class="radio-unit">{{ phone.t('Apps.radio.mhz') }}</span>
              </template>
            </SkyField>
            <SkyField
              v-model="secondaryInput"
              type="number"
              input-mode="decimal"
              :disabled="!radio.data.secondarySupported"
              :label="phone.t('Apps.radio.secondaryFrequency')"
              :placeholder="
                phone.t(
                  radio.data.secondarySupported
                    ? 'Apps.radio.optional'
                    : 'Apps.radio.notSupported',
                )
              "
              :min="radio.data.frequencyMin"
              :max="radio.data.frequencyMax"
              :step="radio.data.frequencyStep"
            >
              <template #leading>
                <RadioTower :size="20" aria-hidden="true" />
              </template>
              <template v-if="radio.data.secondarySupported" #trailing>
                <span class="radio-unit">{{ phone.t('Apps.radio.mhz') }}</span>
              </template>
            </SkyField>
            <SkyListItem
              media-class="radio-audio-control-icon"
              :strong-title="false"
              :title="phone.t('Apps.radio.volume')"
              title-font-size-ios="radio-audio-control-title"
            >
              <template #media>
                <Volume2 :size="20" aria-hidden="true" />
              </template>
              <template #after>
                <output class="radio-volume-value" for="radio-volume">
                  {{ volumeInput }}%
                </output>
              </template>
              <template #inner>
                <SkyRange
                  id="radio-volume"
                  v-model="volumeInput"
                  class="radio-volume-slider"
                  :aria-label="phone.t('Apps.radio.volume')"
                  :aria-value-text="`${volumeInput}%`"
                  :min="0"
                  :max="100"
                  :step="1"
                  @change="saveVolume"
                />
              </template>
            </SkyListItem>
            <SkyListItem
              inner-class="radio-speaker-content"
              media-class="radio-audio-control-icon"
              :aria-busy="radio.speakerPending || undefined"
              :disabled="!radio.data.speakerSupported"
              :strong-title="false"
              :title="phone.t('Apps.radio.speaker')"
              title-font-size-ios="radio-audio-control-title"
              :subtitle="speakerDescription"
            >
              <template #media>
                <Volume2 :size="20" aria-hidden="true" />
              </template>
              <template #after>
                <SkyToggle
                  :model-value="radio.data.speakerEnabled"
                  :disabled="
                    !radio.data.speakerSupported ||
                    !radio.data.connected ||
                    radio.speakerPending
                  "
                  :aria-label="phone.t('Apps.radio.speaker')"
                  @update:model-value="setSpeaker"
                />
              </template>
            </SkyListItem>
          </SkyList>

          <div class="radio-primary-action">
            <SkyButton
              v-if="!radio.data.connected"
              block
              large
              rounded
              :disabled="radio.isLoading"
              @click="connect()"
            >
              {{ phone.t('Apps.radio.connect') }}
            </SkyButton>
            <SkyButton
              v-else
              block
              large
              rounded
              variant="danger"
              :disabled="radio.isLoading"
              @click="disconnect"
            >
              {{ phone.t('Apps.radio.disconnect') }}
            </SkyButton>
            <p v-if="radio.error" class="radio-error" role="alert">
              {{ errorText(radio.error) }}
            </p>
          </div>
        </SkySection>

        <SkySection
          v-if="radio.data.connected"
          :title="
            phone.t('Apps.radio.members', {
              count: String(radio.data.members.length),
            })
          "
        >
          <SkyEmptyState
            v-if="!radio.data.members.length"
            compact
            :title="phone.t('Apps.radio.noMembers')"
          >
            <template #icon>
              <Users :size="32" aria-hidden="true" />
            </template>
          </SkyEmptyState>
          <SkyList v-else inset strong>
            <SkyListItem
              v-for="member in radio.data.members"
              :key="member.id"
              :title="member.name"
              :subtitle="formatDuration(member.joinTime)"
              :after="member.rank || String(member.rankNumber || '')"
            />
          </SkyList>
        </SkySection>

        <SkySection v-else :title="phone.t('Apps.radio.history')">
          <SkyEmptyState
            v-if="!radio.data.history.length"
            compact
            :title="phone.t('Apps.radio.noHistory')"
          >
            <template #icon>
              <Clock3 :size="32" aria-hidden="true" />
            </template>
          </SkyEmptyState>
          <SkyList v-else inset strong class="radio-history-list">
            <SkyListItem
              v-for="entry in radio.data.history"
              :key="`${entry.primary}-${entry.secondary}`"
              link
              :title="`${entry.primary}${entry.secondary ? ` / ${entry.secondary}` : ''} ${phone.t('Apps.radio.mhz')}`"
              @click="connectHistory(entry)"
            />
          </SkyList>
        </SkySection>
      </template>

      <template v-else>
        <SkySettingsGroup
          v-if="radio.data.displayNameEnabled"
          :title="phone.t('Apps.radio.displayName')"
          :footer="
            phone.t(
              radio.data.displayNameAllowed
                ? 'Apps.radio.displayNameDescription'
                : 'Apps.radio.displayNameNotAllowed',
            )
          "
        >
          <SkyField
            v-model="displayNameInput"
            class="radio-profile-field"
            type="text"
            :aria-label="phone.t('Apps.radio.displayName')"
            :readonly="!radio.data.displayNameAllowed"
            :maxlength="radio.data.displayNameMaxLength"
            :placeholder="phone.t('Apps.radio.displayNamePlaceholder')"
            @change="saveDisplayNameSetting"
          />
        </SkySettingsGroup>

        <SkySettingsGroup
          v-if="radio.data.badgeEnabled"
          :title="phone.t('Apps.radio.badge')"
        >
          <SkyField
            v-model="badgeInput"
            class="radio-profile-field"
            type="text"
            :aria-label="phone.t('Apps.radio.badge')"
            :maxlength="radio.data.badgeMaxLength"
            :placeholder="phone.t('Apps.radio.badgePlaceholder')"
            @input="badgeInput = badgeInput.replace(/[^A-Za-z0-9_-]/g, '')"
            @change="saveBadgeSetting"
          />
        </SkySettingsGroup>

        <SkySettingsGroup :title="phone.t('Apps.radio.otherSettings')">
          <SkySettingsRow
            kind="toggle"
            :model-value="radio.data.settings.autoRejoin"
            :title="phone.t('Apps.radio.autoRejoin')"
            :description="phone.t('Apps.radio.autoRejoinDescription')"
            @update:model-value="radio.saveSetting('autoRejoin', $event)"
          />
          <SkySettingsRow
            kind="toggle"
            :model-value="radio.data.settings.notifications"
            :title="phone.t('Apps.radio.radioNotifications')"
            :description="phone.t('Apps.radio.notificationsDescription')"
            @update:model-value="radio.saveSetting('notifications', $event)"
          />
        </SkySettingsGroup>
      </template>
    </SkyScrollArea>

    <SkyPillNavigation
      class="radio-navigation"
      layout="full"
      :label="phone.t('Apps.radio.name')"
    >
      <SkySegmented
        navigation
        rounded
        strong
        :active-index="tab === 'radio' ? 0 : 1"
        :aria-label="phone.t('Apps.radio.name')"
        :data-active-tab="tab"
        :item-count="2"
      >
        <SkySegmentedButton
          :active="tab === 'radio'"
          :aria-label="phone.t('Apps.radio.tabs.radio')"
          type="button"
          @click="tab = 'radio'"
        >
          <span class="radio-navigation__item">
            <RadioTower :size="20" aria-hidden="true" />
            <span>{{ phone.t('Apps.radio.tabs.radio') }}</span>
          </span>
        </SkySegmentedButton>
        <SkySegmentedButton
          :active="tab === 'settings'"
          :aria-label="phone.t('Apps.radio.tabs.settings')"
          type="button"
          @click="tab = 'settings'"
        >
          <span class="radio-navigation__item">
            <Settings :size="20" aria-hidden="true" />
            <span>{{ phone.t('Apps.radio.tabs.settings') }}</span>
          </span>
        </SkySegmentedButton>
      </SkySegmented>
    </SkyPillNavigation>

    <SkyNotification
      :opened="Boolean(feedback)"
      :text="feedback"
      @click="feedback = ''"
    />
  </SkyAppPage>
</template>

<style scoped>
.radio-navigation__item {
  min-width: 0;
  max-width: 100%;
  display: flex;
  align-items: center;
  flex-direction: column;
  gap: 2px;
  line-height: 1;
}

.radio-navigation__item > span:last-child {
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.radio-content {
  padding-top: 4px;
}

.radio-loading {
  min-height: 240px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  color: var(--sky-muted);
  font-size: 14px;
}

.radio-unit {
  color: var(--sky-muted);
  font-size: 12px;
  font-weight: 600;
}

.radio-volume-slider {
  width: 100%;
}

.radio-volume-value {
  color: var(--sky-muted);
  font-size: 12px;
  font-variant-numeric: tabular-nums;
  line-height: 16px;
}

:deep(.radio-audio-control-icon) {
  color: var(--sky-text);
}

:deep(.radio-audio-control-title) {
  font-size: 12px;
  font-weight: 400;
  line-height: 16px;
}

:deep(.radio-speaker-content .sky-list-item__subtitle) {
  color: var(--sky-muted);
  font-size: 12px;
  line-height: 16px;
}

:deep(.radio-profile-field .sky-field__input) {
  min-width: 0;
  font-size: 15px;
}

.radio-primary-action {
  margin-top: 12px;
}

.radio-history-list {
  margin-top: var(--sky-space-2);
}

.radio-error {
  margin: 9px 4px 0;
  color: var(--sky-danger);
  font-size: 12px;
  line-height: 16px;
  text-align: center;
}
</style>
