<script setup lang="ts">
import {
  kBlock,
  kBlockTitle,
  kButton,
  kList,
  kListInput,
  kListItem,
  kNavbar,
  kPage,
  kPreloader,
  kRange,
  kSegmented,
  kSegmentedButton,
  kToast,
  kToggle,
} from 'konsta/vue'
import {
  Clock3,
  RadioTower,
  Settings,
  Signal,
  Users,
  Volume2,
} from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

import { usePhoneStore } from '@/stores/phone'
import { useRadioStore } from '@/stores/radio'
import type { RadioHistoryEntry } from '@/types/radio'

type RadioTab = 'radio' | 'settings'

const phone = usePhoneStore()
const radio = useRadioStore()
const tab = ref<RadioTab>('radio')
const primaryInput = ref('')
const secondaryInput = ref('')
const badgeInput = ref('')
const displayNameInput = ref('')
const feedback = ref('')
const now = ref(Date.now())
const memberSnapshotAt = ref(Date.now())
let clockHandle: number | null = null

const statusText = computed(() => {
  if (!radio.data.connected) return phone.t('Apps.radio.disconnected')
  const secondary = radio.data.secondaryFrequency
    ? ` / ${radio.data.secondaryFrequency}`
    : ''
  return phone.t('Apps.radio.connectedTo', {
    frequency: `${radio.data.frequency}${secondary}`,
  })
})

function eventValue(event: Event): string {
  return (event.target as HTMLInputElement).value
}

function parseFrequency(value: string): number {
  return Number.parseFloat(value.replace(',', '.'))
}

function errorText(code: string): string {
  return phone.t(`Apps.radio.errors.${code || 'default'}`)
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

async function saveRadioProfile(): Promise<void> {
  if (radio.data.displayNameEnabled && radio.data.displayNameAllowed) {
    const displayNameSaved = await radio.saveDisplayName(
      normalizedDisplayName(),
    )
    if (!displayNameSaved) {
      feedback.value = errorText(radio.error)
      window.setTimeout(() => (feedback.value = ''), 2500)
      return
    }
  }

  if (radio.data.badgeEnabled) {
    const badgeSaved = await radio.saveBadge(normalizedBadge())
    if (!badgeSaved) {
      feedback.value = errorText(radio.error)
      window.setTimeout(() => (feedback.value = ''), 2500)
      return
    }
  }

  feedback.value = phone.t('Apps.radio.profileSaved')
  window.setTimeout(() => (feedback.value = ''), 2500)
}

function onMessage(event: MessageEvent): void {
  if (event.data?.type === 'radio:updated' && event.data.data?.members) {
    memberSnapshotAt.value = Date.now()
    radio.updateMembers(event.data.data.members)
  }
}

onMounted(async () => {
  window.addEventListener('message', onMessage)
  clockHandle = window.setInterval(() => (now.value = Date.now()), 1000)
  await radio.load()
  memberSnapshotAt.value = Date.now()
  badgeInput.value = radio.data.badge
  displayNameInput.value = radio.data.displayName
  if (radio.data.frequency) primaryInput.value = String(radio.data.frequency)
  if (radio.data.secondaryFrequency)
    secondaryInput.value = String(radio.data.secondaryFrequency)
})

onBeforeUnmount(() => {
  window.removeEventListener('message', onMessage)
  if (clockHandle) window.clearInterval(clockHandle)
})
</script>

<template>
  <k-page component="main" class="radio-app">
    <k-navbar :title="phone.t('Apps.radio.name')">
      <template #subnavbar>
        <k-segmented :key="tab" strong rounded class="radio-tabs">
          <k-segmented-button :active="tab === 'radio'" @click="tab = 'radio'">
            <RadioTower :size="17" />
            {{ phone.t('Apps.radio.tabs.radio') }}
          </k-segmented-button>
          <k-segmented-button
            :active="tab === 'settings'"
            @click="tab = 'settings'"
          >
            <Settings :size="17" />
            {{ phone.t('Apps.radio.tabs.settings') }}
          </k-segmented-button>
        </k-segmented>
      </template>
    </k-navbar>

    <div v-if="radio.isLoading && !radio.data.provider" class="radio-loading">
      <k-preloader />
      {{ phone.t('Common.loading') }}
    </div>

    <template v-else-if="tab === 'radio'">
      <k-block class="radio-status" strong inset>
        <Signal :size="22" :class="{ 'radio-online': radio.data.connected }" />
        <div>
          <strong>{{ statusText }}</strong>
          <small>{{
            radio.data.provider ?? phone.t('Apps.radio.noProvider')
          }}</small>
        </div>
        <i :class="{ 'radio-status-dot--online': radio.data.connected }"></i>
      </k-block>

      <k-block-title>{{ phone.t('Apps.radio.channel') }}</k-block-title>
      <k-list strong inset>
        <k-list-input
          type="number"
          :label="phone.t('Apps.radio.primaryFrequency')"
          :placeholder="phone.t('Apps.radio.frequencyPlaceholder')"
          :min="radio.data.frequencyMin"
          :max="radio.data.frequencyMax"
          :step="radio.data.frequencyStep"
          :value="primaryInput"
          @input="primaryInput = eventValue($event)"
        >
          <template #after>{{ phone.t('Apps.radio.mhz') }}</template>
        </k-list-input>
        <k-list-input
          v-if="radio.data.secondarySupported"
          type="number"
          :label="phone.t('Apps.radio.secondaryFrequency')"
          :placeholder="phone.t('Apps.radio.optional')"
          :min="radio.data.frequencyMin"
          :max="radio.data.frequencyMax"
          :step="radio.data.frequencyStep"
          :value="secondaryInput"
          @input="secondaryInput = eventValue($event)"
        >
          <template #after>{{ phone.t('Apps.radio.mhz') }}</template>
        </k-list-input>
        <k-list-item :title="phone.t('Apps.radio.volume')">
          <template #media><Volume2 :size="20" /></template>
          <template #inner>
            <div class="radio-volume">
              <k-range
                :value="radio.data.volume"
                :min="0"
                :max="100"
                :step="1"
                :aria-label="phone.t('Apps.radio.volume')"
                @input="radio.setVolume(Number(eventValue($event)))"
              />
              <span>{{ radio.data.volume }}%</span>
            </div>
          </template>
        </k-list-item>
      </k-list>

      <k-block inset class="radio-action-block">
        <k-button
          v-if="!radio.data.connected"
          large
          rounded
          :disabled="radio.isLoading"
          @click="connect()"
        >
          {{ phone.t('Apps.radio.connect') }}
        </k-button>
        <k-button
          v-else
          large
          rounded
          class="radio-disconnect"
          @click="disconnect"
        >
          {{ phone.t('Apps.radio.disconnect') }}
        </k-button>
        <p v-if="radio.error" class="radio-error">
          {{ errorText(radio.error) }}
        </p>
      </k-block>

      <template v-if="radio.data.connected">
        <k-block-title>
          <Users :size="16" />
          {{
            phone.t('Apps.radio.members', {
              count: String(radio.data.members.length),
            })
          }}
        </k-block-title>
        <k-list strong inset>
          <k-list-item
            v-for="member in radio.data.members"
            :key="member.id"
            :title="member.name"
            :subtitle="formatDuration(member.joinTime)"
            :after="member.rank || String(member.rankNumber || '')"
          />
          <k-list-item
            v-if="!radio.data.members.length"
            :title="phone.t('Apps.radio.noMembers')"
          />
        </k-list>
      </template>

      <template v-else>
        <k-block-title>
          <Clock3 :size="16" />
          {{ phone.t('Apps.radio.history') }}
        </k-block-title>
        <k-list strong inset>
          <k-list-item
            v-for="entry in radio.data.history"
            :key="`${entry.primary}-${entry.secondary}`"
            link
            :title="`${entry.primary}${entry.secondary ? ` / ${entry.secondary}` : ''} ${phone.t('Apps.radio.mhz')}`"
            @click="connectHistory(entry)"
          />
          <k-list-item
            v-if="!radio.data.history.length"
            :title="phone.t('Apps.radio.noHistory')"
          />
        </k-list>
      </template>
    </template>

    <template v-else>
      <template v-if="radio.data.displayNameEnabled">
        <k-block-title class="radio-settings-title">
          {{ phone.t('Apps.radio.displayName') }}
        </k-block-title>
        <k-list strong inset class="radio-settings-list">
          <k-list-input
            type="text"
            :disabled="!radio.data.displayNameAllowed"
            :maxlength="radio.data.displayNameMaxLength"
            :placeholder="phone.t('Apps.radio.displayNamePlaceholder')"
            :value="displayNameInput"
            @input="displayNameInput = eventValue($event)"
          />
        </k-list>
        <k-block class="radio-hint-block">
          <p class="radio-setting-hint">
            {{
              phone.t(
                radio.data.displayNameAllowed
                  ? 'Apps.radio.displayNameDescription'
                  : 'Apps.radio.displayNameNotAllowed',
              )
            }}
          </p>
        </k-block>
      </template>

      <template v-if="radio.data.badgeEnabled">
        <k-block-title class="radio-settings-title">
          {{ phone.t('Apps.radio.badge') }}
        </k-block-title>
        <k-list strong inset class="radio-settings-list">
          <k-list-input
            type="text"
            :maxlength="radio.data.badgeMaxLength"
            :placeholder="phone.t('Apps.radio.badgePlaceholder')"
            :value="badgeInput"
            @input="
              badgeInput = eventValue($event).replace(/[^A-Za-z0-9_-]/g, '')
            "
          />
        </k-list>
      </template>

      <k-block
        v-if="
          radio.data.badgeEnabled ||
          (radio.data.displayNameEnabled && radio.data.displayNameAllowed)
        "
        inset
        class="radio-action-block radio-profile-action"
      >
        <k-button rounded large @click="saveRadioProfile">
          {{ phone.t('Common.save') }}
        </k-button>
      </k-block>

      <k-block-title class="radio-settings-title">
        {{ phone.t('Apps.radio.otherSettings') }}
      </k-block-title>
      <k-list strong inset class="radio-settings-list">
        <k-list-item
          class="radio-setting-row"
          :title="phone.t('Apps.radio.autoRejoin')"
          :subtitle="phone.t('Apps.radio.autoRejoinDescription')"
        >
          <template #after>
            <k-toggle
              :checked="radio.data.settings.autoRejoin"
              @change="
                radio.saveSetting('autoRejoin', !radio.data.settings.autoRejoin)
              "
            />
          </template>
        </k-list-item>
        <k-list-item
          class="radio-setting-row"
          :title="phone.t('Apps.radio.radioNotifications')"
          :subtitle="phone.t('Apps.radio.notificationsDescription')"
        >
          <template #after>
            <k-toggle
              :checked="radio.data.settings.notifications"
              @change="
                radio.saveSetting(
                  'notifications',
                  !radio.data.settings.notifications,
                )
              "
            />
          </template>
        </k-list-item>
      </k-list>
    </template>

    <k-toast
      :opened="Boolean(feedback)"
      position="center"
      @click="feedback = ''"
    >
      {{ feedback }}
    </k-toast>
  </k-page>
</template>

<style scoped>
.radio-app {
  --radio-blue: #0a84ff;
  overflow-y: auto;
  padding-bottom: 34px;
}

.radio-tabs :deep(button) {
  align-items: center;
  display: flex;
  gap: 6px;
  justify-content: center;
}

.radio-loading {
  align-items: center;
  display: flex;
  gap: 10px;
  justify-content: center;
  min-height: 240px;
}

.radio-status {
  align-items: center;
  display: grid;
  gap: 12px;
  grid-template-columns: auto 1fr auto;
  margin-top: 18px;
}

.radio-status div {
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.radio-status small {
  color: var(--k-color-subtitle, #8e8e93);
  margin-top: 2px;
  text-transform: capitalize;
}

.radio-status i {
  background: #c7c7cc;
  border-radius: 50%;
  height: 10px;
  width: 10px;
}

.radio-status .radio-status-dot--online {
  background: #30d158;
}

.radio-online {
  color: #30d158;
}

.radio-volume {
  align-items: center;
  display: grid;
  gap: 12px;
  grid-template-columns: 1fr 44px;
  width: 100%;
}

.radio-volume span {
  color: var(--k-color-subtitle, #8e8e93);
  font-variant-numeric: tabular-nums;
  text-align: right;
}

.radio-action-block {
  padding-left: 0;
  padding-right: 0;
}

.radio-setting-hint {
  color: inherit;
  font-size: 16px;
  font-weight: 450;
  line-height: 1.45;
  margin: 0;
  opacity: 0.82;
}

.radio-hint-block {
  margin-bottom: 0;
  margin-top: 8px;
}

.radio-settings-title {
  margin-bottom: 6px;
  margin-top: 16px;
}

.radio-settings-list {
  margin-bottom: 0;
  margin-top: 0;
}

.radio-profile-action {
  margin-bottom: 0;
  margin-top: 12px;
}

.radio-setting-row :deep(.text-sm) {
  font-size: 15px;
  line-height: 1.35;
}

.radio-error {
  color: #ff3b30;
  font-size: 13px;
  margin: 10px 4px 0;
  text-align: center;
}

.radio-disconnect {
  background: #ff3b30 !important;
  color: #fff !important;
}

:deep(.k-block-title) {
  align-items: center;
  display: flex;
  gap: 6px;
}
</style>
