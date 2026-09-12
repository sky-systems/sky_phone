<script setup lang="ts">
import {
  ChartNoAxesCombined,
  BadgeDollarSign,
  BellRing,
  BriefcaseBusiness,
  Check,
  ChevronRight,
  CircleUserRound,
  Clipboard,
  Database,
  Eye,
  Grid2X2,
  HardDrive,
  KeyRound,
  LayoutDashboard,
  LoaderCircle,
  LockKeyhole,
  MessageSquare,
  PhoneCall,
  PhoneForwarded,
  Save,
  ScrollText,
  Search,
  Settings2,
  ShieldAlert,
  Smartphone,
  Trash2,
  TriangleAlert,
  UsersRound,
  WalletCards,
  Wifi,
  X,
} from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'

import {
  DEFAULT_INSTALLED_PHONE_APP_IDS,
  getPhoneApp,
  getPhoneAppLabel,
  isExternalPhoneApp,
  isLaunchablePhoneApp,
  isPhoneAppRemovable,
  PHONE_APPS,
} from '@/config/apps'
import { vConfigInputWidth } from '@/directives/configInputWidth'
import { useAdminStore } from '@/stores/admin'
import { usePhoneStore } from '@/stores/phone'
import type {
  AdminAuditEntry,
  AdminConfiguratorChange,
  AdminConfiguratorField,
  AdminConfiguratorStructure,
  AdminDevice,
} from '@/types/admin'
import type { LaunchablePhoneAppDefinition } from '@/types/apps'
import { SkyButton } from '@/ui'
import {
  configuratorPathName,
  describeConfiguratorValue,
} from '@/utils/adminConfiguratorDescription'
import { copyText } from '@/utils/clipboard'
import { parseDatabaseDate } from '@/utils/date'
import { nuiCall } from '@/utils/nui'

import AdminConfigValueEditor, {
  type AdminConfigEditorLabels,
} from './AdminConfigValueEditor.vue'
import AdminCustomToneManager from './AdminCustomToneManager.vue'

type AdminTab =
  | 'overview'
  | 'players'
  | 'devices'
  | 'apps'
  | 'accounts'
  | 'messages'
  | 'calls'
  | 'moderation'
  | 'tones'
  | 'audit'
  | 'configurator'
type ConfiguratorScope = 'config' | 'media'
type DeviceAction = 'reset-passcode' | 'change-number' | 'factory-reset'
type PendingAction = { kind: 'close' } | { kind: 'player'; source: number }
const emit = defineEmits<{ close: [] }>()
const admin = useAdminStore()
const phone = usePhoneStore()
const tab = ref<AdminTab>('overview')
const playerQuery = ref('')
const appQuery = ref('')
const configuratorQuery = ref('')
const configuratorScope = ref<ConfiguratorScope>('config')
const selectedConfiguratorSection = ref('')
const selectedImei = ref('')
const drafts = ref<Record<string, Record<string, boolean>>>({})
const configuratorDrafts = ref<Record<string, unknown>>({})
const saving = ref(false)
const revealDialogImei = ref('')
const deviceAction = ref<DeviceAction | null>(null)
const deviceActionInput = ref('')
const discardDialog = ref(false)
const pendingAction = ref<PendingAction | null>(null)
const toast = ref('')
const toastTone = ref<'error' | 'success'>('success')
let toastTimer: number | undefined
let statisticsTimer: number | undefined

const filteredPlayers = computed(() => {
  const needle = playerQuery.value.trim().toLocaleLowerCase(phone.lang)
  if (!needle) return admin.players
  return admin.players.filter((player) =>
    [
      player.name,
      player.serverName,
      player.source,
      player.identifier,
      player.job,
      player.phoneNumber ?? '',
    ]
      .join(' ')
      .toLocaleLowerCase(phone.lang)
      .includes(needle),
  )
})

const selectedDevice = computed(() => {
  const devices = admin.selectedPlayer?.devices ?? []
  return (
    devices.find((device) => device.imei === selectedImei.value) ??
    devices[0] ??
    null
  )
})

const manageableApps = computed(() => {
  const needle = appQuery.value.trim().toLocaleLowerCase(phone.lang)
  return PHONE_APPS.filter(
    (app): app is LaunchablePhoneAppDefinition =>
      isLaunchablePhoneApp(app) &&
      !app.adminOnly &&
      !admin.disabledApps.includes(app.id),
  )
    .filter(
      (app) =>
        !needle ||
        getPhoneAppLabel(app, phone.t)
          .toLocaleLowerCase(phone.lang)
          .includes(needle),
    )
    .sort((left, right) =>
      getPhoneAppLabel(left, phone.t).localeCompare(
        getPhoneAppLabel(right, phone.t),
        phone.lang,
      ),
    )
})

const appPendingCount = computed(() =>
  Object.values(drafts.value).reduce(
    (total, changes) => total + Object.keys(changes).length,
    0,
  ),
)
const configuratorPendingCount = computed(
  () => Object.keys(configuratorDrafts.value).length,
)
const pendingCount = computed(
  () => appPendingCount.value + configuratorPendingCount.value,
)
const hasChanges = computed(() => pendingCount.value > 0)
const selectedDeviceChanges = computed(() =>
  selectedDevice.value
    ? Object.keys(drafts.value[selectedDevice.value.imei] ?? {}).length
    : 0,
)
const revealedCredential = computed(() =>
  selectedDevice.value
    ? admin.revealedCredentials[selectedDevice.value.imei]
    : undefined,
)

function configuratorStructureCount(
  structure: AdminConfiguratorStructure | undefined,
): number {
  if (
    !structure ||
    structure.kind === 'value' ||
    structure.kind === 'optionalString'
  )
    return 1
  if (structure.kind === 'vector') return Number(structure.vectorType.slice(-1))
  if (structure.kind === 'list') {
    return Math.max(
      1,
      structure.items.reduce(
        (total, item) => total + configuratorStructureCount(item),
        0,
      ),
    )
  }
  if (structure.kind === 'map') {
    return Math.max(
      1,
      structure.entries.reduce(
        (total, entry) => total + configuratorStructureCount(entry.structure),
        0,
      ),
    )
  }
  return Math.max(
    1,
    Object.values(structure.fields).reduce(
      (total, field) => total + configuratorStructureCount(field),
      0,
    ),
  )
}

function configuratorSectionCount(fields: AdminConfiguratorField[]): number {
  return fields.reduce(
    (total, field) => total + configuratorStructureCount(field.structure),
    0,
  )
}

function configuratorFieldRepeatsSection(
  field: AdminConfiguratorField,
): boolean {
  const section = activeConfiguratorSection.value
  if (!section || field.type !== 'json') return false
  const normalize = (value: string) =>
    value.toLocaleLowerCase().replace(/[^a-z0-9]/g, '')
  return normalize(field.label) === normalize(section.label)
}

function configuratorStructureContains(
  structure: AdminConfiguratorStructure | undefined,
  needle: string,
): boolean {
  if (
    !structure ||
    structure.kind === 'value' ||
    structure.kind === 'optionalString'
  )
    return false
  if (structure.kind === 'vector') return structure.vectorType.includes(needle)
  if (structure.kind === 'list') {
    return structure.items.some((item) =>
      configuratorStructureContains(item, needle),
    )
  }
  if (structure.kind === 'map') {
    return structure.entries.some(
      (entry) =>
        String(entry.key).toLocaleLowerCase(phone.lang).includes(needle) ||
        configuratorStructureContains(entry.structure, needle),
    )
  }
  return Object.entries(structure.fields).some(
    ([key, field]) =>
      key.toLocaleLowerCase(phone.lang).includes(needle) ||
      configuratorStructureContains(field, needle),
  )
}

const selectedMessages = computed(() =>
  selectedDevice.value
    ? (admin.deviceActivity[selectedDevice.value.imei]?.messages ?? [])
    : [],
)
const selectedCalls = computed(() =>
  selectedDevice.value
    ? (admin.deviceActivity[selectedDevice.value.imei]?.calls ?? [])
    : [],
)
const filteredConfiguratorSections = computed(() => {
  const sections = (admin.configurator?.sections ?? []).filter(
    (section) => section.scope === configuratorScope.value,
  )
  const needle = configuratorQuery.value.trim().toLocaleLowerCase(phone.lang)
  if (!needle) return sections
  return sections.filter(
    (section) =>
      section.label.toLocaleLowerCase(phone.lang).includes(needle) ||
      section.scope.includes(needle) ||
      section.fields.some(
        (field) =>
          field.label.toLocaleLowerCase(phone.lang).includes(needle) ||
          field.path.toLocaleLowerCase(phone.lang).includes(needle) ||
          configuratorStructureContains(field.structure, needle),
      ),
  )
})
const configuratorScopeCounts = computed(() => {
  const sections = admin.configurator?.sections ?? []
  return {
    config: sections.filter((section) => section.scope === 'config').length,
    media: sections.filter((section) => section.scope === 'media').length,
  }
})
const filteredConfiguratorFieldCount = computed(() =>
  filteredConfiguratorSections.value.reduce(
    (total, section) => total + configuratorSectionCount(section.fields),
    0,
  ),
)
const activeConfiguratorSection = computed(() => {
  const sections = filteredConfiguratorSections.value
  return (
    sections.find(
      (section) => section.id === selectedConfiguratorSection.value,
    ) ??
    sections[0] ??
    null
  )
})

watch(
  () => admin.selectedPlayer,
  (player) => {
    if (!player?.devices.some((device) => device.imei === selectedImei.value)) {
      selectedImei.value = player?.devices[0]?.imei ?? ''
    }
  },
)

watch(
  [() => admin.configurator?.sections, configuratorScope],
  ([sections, scope]) => {
    if (
      !sections?.some(
        (section) =>
          section.id === selectedConfiguratorSection.value &&
          section.scope === scope,
      )
    ) {
      selectedConfiguratorSection.value =
        sections?.find((section) => section.scope === scope)?.id ?? ''
    }
  },
)

watch(
  [tab, selectedImei, () => admin.selectedPlayer?.source],
  ([currentTab, imei, source]) => {
    if (
      !source ||
      !imei ||
      (currentTab !== 'messages' && currentTab !== 'calls')
    ) {
      return
    }
    void admin.loadActivity(source, imei, currentTab).then((loaded) => {
      if (!loaded) showToast(errorText(), 'error')
    })
  },
)

function t(key: string, params?: Record<string, string>): string {
  return phone.t('AdminPanel.' + key, params)
}

function configuratorLocaleText(key: string, fallback: string): string {
  const translated = t(key)
  return translated === key || translated === `AdminPanel.${key}`
    ? fallback
    : translated
}

function configuratorSubtabLabel(key: string, value: unknown): string {
  const record =
    value !== null && typeof value === 'object'
      ? (value as Record<string, unknown>)
      : null
  if (
    /^[a-z0-9_-]+$/.test(key) &&
    typeof record?.Name === 'string' &&
    record.Name
  ) {
    return record.Name
  }
  const fallback = configuratorPathName(key)
  return configuratorLocaleText(
    `configurator.table.subtabs.${key}`,
    fallback.charAt(0).toLocaleUpperCase(phone.lang) + fallback.slice(1),
  )
}

function selectConfiguratorScope(scope: ConfiguratorScope): void {
  configuratorScope.value = scope
  configuratorQuery.value = ''
}

function configuratorDescription(
  path: string,
  value: unknown,
  structure?: AdminConfiguratorStructure,
  label?: string,
): string {
  return describeConfiguratorValue(t, path, value, structure, label)
}

const configuratorEditorLabels = computed<AdminConfigEditorLabels>(() => ({
  addField: t('configurator.table.addField'),
  addJob: t('configurator.table.addJob'),
  addRow: t('configurator.table.addRow'),
  configuredSecret: t('configurator.secretConfigured'),
  convertToList: t('configurator.table.convertToList'),
  convertToMap: t('configurator.table.convertToMap'),
  convertToTable: t('configurator.table.convertToTable'),
  emptyList: t('configurator.table.emptyList'),
  emptyTable: t('configurator.table.emptyTable'),
  entry: t('configurator.table.entry'),
  general: configuratorLocaleText('configurator.table.general', 'General'),
  jobPlaceholder: t('configurator.table.jobPlaceholder'),
  keyPlaceholder: t('configurator.table.keyPlaceholder'),
  list: t('configurator.table.list'),
  remove: t('configurator.table.remove'),
  table: t('configurator.table.table'),
  types: {
    boolean: t('configurator.table.types.boolean'),
    list: t('configurator.table.types.list'),
    number: t('configurator.table.types.number'),
    string: t('configurator.table.types.string'),
    table: t('configurator.table.types.table'),
  },
  vector: t('configurator.table.vector'),
}))

function showToast(
  message: string,
  tone: 'error' | 'success' = 'success',
): void {
  if (toastTimer) window.clearTimeout(toastTimer)
  toast.value = message
  toastTone.value = tone
  toastTimer = window.setTimeout(() => (toast.value = ''), 2800)
}

function formatMoney(value: number, currency: string): string {
  const formatted = new Intl.NumberFormat(phone.lang, {
    maximumFractionDigits: 0,
  }).format(value)
  return `${currency}${formatted}`
}

function formatDate(value: string): string {
  const date = parseDatabaseDate(value)
  return Number.isNaN(date.getTime())
    ? value
    : new Intl.DateTimeFormat(phone.lang, {
        dateStyle: 'medium',
        timeStyle: 'short',
      }).format(date)
}

function formatDuration(seconds: number): string {
  const minutes = Math.floor(seconds / 60)
  const remainder = Math.max(0, seconds % 60)
  return `${minutes}:${String(remainder).padStart(2, '0')}`
}

function initials(name: string): string {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part.charAt(0).toLocaleUpperCase(phone.lang))
    .join('')
}

function baseInstalled(
  device: AdminDevice,
  app: LaunchablePhoneAppDefinition,
): boolean {
  if (device.apps.uninstalled.includes(app.id)) return false
  if (device.apps.claimed.includes(app.id)) return true
  return isExternalPhoneApp(app)
    ? app.defaultInstalled
    : DEFAULT_INSTALLED_PHONE_APP_IDS.has(app.id)
}

function isInstalled(
  device: AdminDevice,
  app: LaunchablePhoneAppDefinition,
): boolean {
  const deviceDraft = drafts.value[device.imei]
  return deviceDraft &&
    Object.prototype.hasOwnProperty.call(deviceDraft, app.id)
    ? deviceDraft[app.id]
    : baseInstalled(device, app)
}

function toggleApp(app: LaunchablePhoneAppDefinition): void {
  const device = selectedDevice.value
  if (!device) return
  const nextInstalled = !isInstalled(device, app)
  if (!nextInstalled && !isPhoneAppRemovable(app)) return

  const deviceDraft = drafts.value[device.imei] ?? {}
  if (nextInstalled === baseInstalled(device, app)) {
    delete deviceDraft[app.id]
  } else {
    deviceDraft[app.id] = nextInstalled
  }
  if (Object.keys(deviceDraft).length) drafts.value[device.imei] = deviceDraft
  else delete drafts.value[device.imei]
}

function errorText(error = admin.error): string {
  return t('errors.' + (error || 'default'))
}

async function loadPlayer(source: number): Promise<void> {
  if (await admin.openPlayer(source)) return
  showToast(errorText(), 'error')
}

async function refreshData(): Promise<void> {
  const selectedSource = admin.selectedPlayer?.source
  if (!(await admin.load())) {
    showToast(errorText(), 'error')
    return
  }
  const nextSource =
    admin.players.find((player) => player.source === selectedSource)?.source ??
    admin.players[0]?.source
  if (nextSource) await loadPlayer(nextSource)
}

function queueAction(action: PendingAction): void {
  if (!hasChanges.value) {
    void runAction(action)
    return
  }
  pendingAction.value = action
  discardDialog.value = true
}

function selectTab(nextTab: AdminTab): void {
  tab.value = nextTab
  if (nextTab === 'overview' && admin.initialized && !admin.loading) {
    void admin.load()
  }
  if (nextTab === 'configurator') {
    void (
      admin.configurator ? Promise.resolve(true) : admin.loadConfigurator()
    ).then((loaded) => {
      if (!loaded) showToast(errorText(), 'error')
    })
  }
  if (nextTab === 'tones') {
    void admin.loadCustomTones().then((loaded) => {
      if (!loaded) showToast(errorText(), 'error')
    })
  }
}

function formatStatistic(value: number): string {
  return value.toLocaleString(phone.lang)
}

function statisticPercentage(value: number, total: number): number {
  if (total <= 0) return 0
  return Math.min(100, Math.round((value / total) * 100))
}

async function runAction(action: PendingAction): Promise<void> {
  if (action.kind === 'close') {
    const response = await nuiCall('admin:close')
    if (response.success) emit('close')
    else showToast(errorText(response.error), 'error')
    return
  }
  await loadPlayer(action.source)
}

async function discardAndContinue(): Promise<void> {
  const action = pendingAction.value
  drafts.value = {}
  configuratorDrafts.value = {}
  pendingAction.value = null
  discardDialog.value = false
  if (action) await runAction(action)
}

function configuratorFieldKey(field: AdminConfiguratorField): string {
  return `${field.scope}:${field.path}`
}

function configuratorFieldValue(field: AdminConfiguratorField): unknown {
  const key = configuratorFieldKey(field)
  if (Object.prototype.hasOwnProperty.call(configuratorDrafts.value, key)) {
    return configuratorDrafts.value[key]
  }
  return field.value
}

function updateConfiguratorField(
  field: AdminConfiguratorField,
  value: unknown,
): void {
  const key = configuratorFieldKey(field)
  const matchesInitial =
    field.type === 'json'
      ? JSON.stringify(value) === JSON.stringify(field.value)
      : field.type === 'number'
        ? String(value) === String(field.value)
        : value === field.value
  if (!field.sensitive && matchesInitial) {
    delete configuratorDrafts.value[key]
    return
  }
  configuratorDrafts.value[key] = value
}

function updateConfiguratorInput(
  field: AdminConfiguratorField,
  event: Event,
): void {
  const target = event.target
  if (target instanceof HTMLInputElement) {
    updateConfiguratorField(field, target.value)
  }
}

function updateConfiguratorToggle(
  field: AdminConfiguratorField,
  event: Event,
): void {
  const target = event.target
  if (target instanceof HTMLInputElement) {
    updateConfiguratorField(field, target.checked)
  }
}

function updateOptionalStringToggle(
  field: AdminConfiguratorField,
  event: Event,
): void {
  const target = event.target
  if (!(target instanceof HTMLInputElement)) return
  const current = configuratorFieldValue(field)
  updateConfiguratorField(
    field,
    target.checked ? (current === false ? '' : String(current ?? '')) : false,
  )
}

function findConfiguratorField(key: string): AdminConfiguratorField | null {
  for (const section of admin.configurator?.sections ?? []) {
    const field = section.fields.find(
      (candidate) => configuratorFieldKey(candidate) === key,
    )
    if (field) return field
  }
  return null
}

function buildConfiguratorChanges(): AdminConfiguratorChange[] | null {
  const changes: AdminConfiguratorChange[] = []
  for (const [key, draft] of Object.entries(configuratorDrafts.value)) {
    const field = findConfiguratorField(key)
    if (!field) return null

    let value: unknown = draft
    if (field.type === 'number') {
      value = Number(draft)
      if (!Number.isFinite(value)) return null
    } else if (field.type === 'json') {
      value = draft
      if (!value || typeof value !== 'object') return null
    } else if (field.type === 'string') {
      value = String(draft)
    } else if (field.type === 'stringOrFalse') {
      if (value !== false && typeof value !== 'string') return null
    } else if (field.type === 'boolean' && typeof value !== 'boolean') {
      return null
    }

    changes.push({ path: field.path, scope: field.scope, value })
  }
  return changes
}

function cancelDiscard(): void {
  discardDialog.value = false
  pendingAction.value = null
}

async function saveChanges(): Promise<void> {
  const player = admin.selectedPlayer
  if (!hasChanges.value || saving.value) return
  saving.value = true

  if (configuratorPendingCount.value) {
    const changes = buildConfiguratorChanges()
    if (!changes) {
      saving.value = false
      showToast(t('configurator.invalidValue'), 'error')
      return
    }
    const response = await admin.saveConfigurator(changes)
    if (!response.success) {
      saving.value = false
      showToast(errorText(response.error), 'error')
      return
    }
    configuratorDrafts.value = {}
  }

  if (!appPendingCount.value) {
    saving.value = false
    showToast(t('configurator.saved'))
    return
  }
  if (!player) {
    saving.value = false
    showToast(t('editor.saveFailed'), 'error')
    return
  }
  const pendingDevices = Object.entries(drafts.value)
  for (const [imei, deviceChanges] of pendingDevices) {
    const device = admin.selectedPlayer?.devices.find(
      (candidate) => candidate.imei === imei,
    )
    if (!device) {
      saving.value = false
      showToast(t('editor.saveFailed'), 'error')
      return
    }
    const changes = Object.entries(deviceChanges).map(([appId, installed]) => ({
      appId,
      installed,
    }))
    const response = await admin.saveApps(
      player.source,
      imei,
      device.apps.revision,
      changes,
    )
    if (!response.success) {
      saving.value = false
      showToast(errorText(response.error), 'error')
      return
    }
    delete drafts.value[imei]
  }
  saving.value = false
  await admin.load()
  showToast(t('editor.saved'))
}

async function revealPassword(): Promise<void> {
  const player = admin.selectedPlayer
  const imei = revealDialogImei.value
  revealDialogImei.value = ''
  if (!player || !imei) return
  const response = await admin.revealPassword(player.source, imei)
  if (!response.success) showToast(errorText(response.error), 'error')
}

async function copyPassword(): Promise<void> {
  if (!revealedCredential.value) return
  if (await copyText(revealedCredential.value.password)) {
    showToast(t('credentials.copied'))
  }
}

function openDeviceAction(action: DeviceAction): void {
  if (!selectedDevice.value) return
  deviceActionInput.value =
    action === 'change-number' ? (selectedDevice.value.number ?? '') : ''
  deviceAction.value = action
}

function cancelDeviceAction(): void {
  deviceAction.value = null
  deviceActionInput.value = ''
}

async function confirmDeviceAction(): Promise<void> {
  const player = admin.selectedPlayer
  const device = selectedDevice.value
  const action = deviceAction.value
  if (!player || !device || !action || admin.actionKey) return

  let response
  if (action === 'reset-passcode') {
    response = await admin.resetPasscode(player.source, device.imei)
  } else if (action === 'change-number') {
    response = await admin.changeNumber(
      player.source,
      device.imei,
      deviceActionInput.value,
    )
  } else {
    response = await admin.factoryReset(player.source, device.imei)
  }
  if (!response.success) {
    showToast(errorText(response.error), 'error')
    return
  }

  if (action === 'factory-reset') delete drafts.value[device.imei]
  deviceAction.value = null
  deviceActionInput.value = ''
  showToast(t(`moderation.${action}Success`))
  await admin.load()
}

function auditDescription(entry: AdminAuditEntry): string {
  const appId =
    typeof entry.details.appId === 'string' ? entry.details.appId : ''
  const app = appId ? getPhoneApp(appId) : undefined
  return app
    ? getPhoneAppLabel(app, phone.t)
    : typeof entry.details.email === 'string'
      ? entry.details.email
      : entry.deviceImei || entry.targetIdentifier
}

function onKeydown(event: KeyboardEvent): void {
  if (event.key !== 'Escape') return
  event.preventDefault()
  if (revealDialogImei.value) {
    revealDialogImei.value = ''
    return
  }
  if (deviceAction.value) {
    deviceAction.value = null
    deviceActionInput.value = ''
    return
  }
  if (discardDialog.value) {
    discardDialog.value = false
    pendingAction.value = null
    return
  }
  queueAction({ kind: 'close' })
}

onMounted(() => {
  document.addEventListener('keydown', onKeydown)
  void refreshData()
  statisticsTimer = window.setInterval(() => {
    if (tab.value === 'overview' && !admin.loading) void admin.load()
  }, 15_000)
})

onBeforeUnmount(() => {
  document.removeEventListener('keydown', onKeydown)
  if (toastTimer) window.clearTimeout(toastTimer)
  if (statisticsTimer) window.clearInterval(statisticsTimer)
})
</script>

<template>
  <div class="admin-panel-overlay" role="dialog" :aria-label="t('name')">
    <div class="admin-panel-window">
      <header class="admin-panel-header">
        <div class="admin-panel-brand">
          <div>
            <strong>{{ t('editor.brand') }}</strong>
            <span>{{ t('editor.workspace') }}</span>
          </div>
        </div>

        <div class="admin-panel-context">
          <span class="admin-panel-context__path">
            {{ t('tabs.' + tab) }}
          </span>
          <ChevronRight :size="14" style="--admin-icon-size: 14" />
          <strong>{{
            tab === 'configurator'
              ? t('configurator.context')
              : tab === 'tones'
                ? t('configurator.customTones.context')
                : admin.selectedPlayer?.name || t('editor.noSelection')
          }}</strong>
        </div>

        <div class="admin-panel-actions">
          <span v-if="hasChanges" class="admin-panel-dirty">
            <span></span>{{ t('editor.unsaved') }} · {{ pendingCount }}
          </span>
          <button
            type="button"
            class="admin-panel-save"
            :class="{ 'is-ready': hasChanges }"
            :aria-label="t('editor.save')"
            :title="hasChanges ? t('editor.saveHint') : t('editor.save')"
            :disabled="!hasChanges || saving"
            @click="saveChanges"
          >
            <LoaderCircle
              v-if="saving"
              :size="18"
              style="--admin-icon-size: 18"
              class="is-spinning"
            />
            <Check
              v-else
              :size="19"
              style="--admin-icon-size: 19"
              stroke-width="3"
            />
          </button>
          <button
            type="button"
            class="admin-panel-icon-button admin-panel-close"
            :aria-label="t('editor.close')"
            :title="t('editor.close')"
            @click="queueAction({ kind: 'close' })"
          >
            <X :size="18" style="--admin-icon-size: 18" />
          </button>
        </div>
      </header>

      <div class="admin-panel-body">
        <nav class="admin-panel-rail" :aria-label="t('navigation')">
          <button
            type="button"
            :class="{ 'is-active': tab === 'overview' }"
            :aria-label="t('tabs.overview')"
            :title="t('tabs.overview')"
            @click="selectTab('overview')"
          >
            <LayoutDashboard :size="19" style="--admin-icon-size: 19" />
          </button>
          <button
            type="button"
            :class="{ 'is-active': tab === 'players' }"
            :aria-label="t('tabs.players')"
            :title="t('tabs.players')"
            @click="selectTab('players')"
          >
            <UsersRound :size="19" style="--admin-icon-size: 19" />
          </button>
          <button
            type="button"
            :class="{ 'is-active': tab === 'devices' }"
            :aria-label="t('tabs.devices')"
            :title="t('tabs.devices')"
            @click="selectTab('devices')"
          >
            <Smartphone :size="19" style="--admin-icon-size: 19" />
          </button>
          <button
            type="button"
            :class="{ 'is-active': tab === 'apps' }"
            :aria-label="t('tabs.apps')"
            :title="t('tabs.apps')"
            @click="selectTab('apps')"
          >
            <Grid2X2 :size="19" style="--admin-icon-size: 19" />
          </button>
          <button
            type="button"
            :class="{ 'is-active': tab === 'accounts' }"
            :aria-label="t('tabs.accounts')"
            :title="t('tabs.accounts')"
            @click="selectTab('accounts')"
          >
            <KeyRound :size="19" style="--admin-icon-size: 19" />
          </button>
          <button
            type="button"
            :class="{ 'is-active': tab === 'messages' }"
            :aria-label="t('tabs.messages')"
            :title="t('tabs.messages')"
            @click="selectTab('messages')"
          >
            <MessageSquare :size="19" style="--admin-icon-size: 19" />
          </button>
          <button
            type="button"
            :class="{ 'is-active': tab === 'calls' }"
            :aria-label="t('tabs.calls')"
            :title="t('tabs.calls')"
            @click="selectTab('calls')"
          >
            <PhoneCall :size="19" style="--admin-icon-size: 19" />
          </button>
          <button
            type="button"
            :class="{ 'is-active': tab === 'moderation' }"
            :aria-label="t('tabs.moderation')"
            :title="t('tabs.moderation')"
            @click="selectTab('moderation')"
          >
            <ShieldAlert :size="19" style="--admin-icon-size: 19" />
          </button>
          <button
            type="button"
            :class="{ 'is-active': tab === 'tones' }"
            :aria-label="t('tabs.tones')"
            :title="t('tabs.tones')"
            @click="selectTab('tones')"
          >
            <BellRing :size="19" style="--admin-icon-size: 19" />
          </button>
          <button
            type="button"
            :class="{ 'is-active': tab === 'audit' }"
            :aria-label="t('tabs.audit')"
            :title="t('tabs.audit')"
            @click="selectTab('audit')"
          >
            <ScrollText :size="19" style="--admin-icon-size: 19" />
          </button>
          <button
            type="button"
            class="admin-panel-rail__configurator"
            :class="{ 'is-active': tab === 'configurator' }"
            :aria-label="t('tabs.configurator')"
            :title="t('tabs.configurator')"
            @click="selectTab('configurator')"
          >
            <Settings2 :size="19" style="--admin-icon-size: 19" />
          </button>
        </nav>

        <aside class="admin-panel-directory">
          <template v-if="tab === 'overview'">
            <div class="admin-panel-directory__header">
              <div>
                <span>{{ t('overview.eyebrow') }}</span>
                <h2>{{ t('overview.features') }}</h2>
              </div>
              <strong>{{ admin.stats.online }}</strong>
            </div>
            <div class="admin-panel-overview-directory">
              <button type="button" @click="selectTab('players')">
                <UsersRound :size="17" style="--admin-icon-size: 17" />
                <span>
                  <strong>{{ t('tabs.players') }}</strong>
                  <small>{{ t('overview.playerFeature') }}</small>
                </span>
                <ChevronRight :size="14" style="--admin-icon-size: 14" />
              </button>
              <button type="button" @click="selectTab('devices')">
                <Smartphone :size="17" style="--admin-icon-size: 17" />
                <span>
                  <strong>{{ t('tabs.devices') }}</strong>
                  <small>{{ t('overview.deviceFeature') }}</small>
                </span>
                <ChevronRight :size="14" style="--admin-icon-size: 14" />
              </button>
              <button type="button" @click="selectTab('apps')">
                <Grid2X2 :size="17" style="--admin-icon-size: 17" />
                <span>
                  <strong>{{ t('tabs.apps') }}</strong>
                  <small>{{ t('overview.appFeature') }}</small>
                </span>
                <ChevronRight :size="14" style="--admin-icon-size: 14" />
              </button>
              <button type="button" @click="selectTab('accounts')">
                <KeyRound :size="17" style="--admin-icon-size: 17" />
                <span>
                  <strong>{{ t('tabs.accounts') }}</strong>
                  <small>{{ t('overview.accountFeature') }}</small>
                </span>
                <ChevronRight :size="14" style="--admin-icon-size: 14" />
              </button>
              <button type="button" @click="selectTab('messages')">
                <MessageSquare :size="17" style="--admin-icon-size: 17" />
                <span>
                  <strong>{{ t('tabs.messages') }}</strong>
                  <small>{{ t('overview.messageFeature') }}</small>
                </span>
                <ChevronRight :size="14" style="--admin-icon-size: 14" />
              </button>
              <button type="button" @click="selectTab('calls')">
                <PhoneCall :size="17" style="--admin-icon-size: 17" />
                <span>
                  <strong>{{ t('tabs.calls') }}</strong>
                  <small>{{ t('overview.callFeature') }}</small>
                </span>
                <ChevronRight :size="14" style="--admin-icon-size: 14" />
              </button>
              <button type="button" @click="selectTab('moderation')">
                <ShieldAlert :size="17" style="--admin-icon-size: 17" />
                <span>
                  <strong>{{ t('tabs.moderation') }}</strong>
                  <small>{{ t('overview.moderationFeature') }}</small>
                </span>
                <ChevronRight :size="14" style="--admin-icon-size: 14" />
              </button>
              <button type="button" @click="selectTab('audit')">
                <ScrollText :size="17" style="--admin-icon-size: 17" />
                <span>
                  <strong>{{ t('tabs.audit') }}</strong>
                  <small>{{ t('overview.auditFeature') }}</small>
                </span>
                <ChevronRight :size="14" style="--admin-icon-size: 14" />
              </button>
              <button type="button" @click="selectTab('tones')">
                <BellRing :size="17" style="--admin-icon-size: 17" />
                <span>
                  <strong>{{ t('tabs.tones') }}</strong>
                  <small>{{ t('overview.tonesFeature') }}</small>
                </span>
                <ChevronRight :size="14" style="--admin-icon-size: 14" />
              </button>
              <button type="button" @click="selectTab('configurator')">
                <Settings2 :size="17" style="--admin-icon-size: 17" />
                <span>
                  <strong>{{ t('tabs.configurator') }}</strong>
                  <small>{{ t('overview.configuratorFeature') }}</small>
                </span>
                <ChevronRight :size="14" style="--admin-icon-size: 14" />
              </button>
            </div>
          </template>

          <template v-else-if="tab === 'tones'">
            <div class="admin-panel-directory__header">
              <div>
                <span>{{ t('configurator.customTones.eyebrow') }}</span>
                <h2>{{ t('configurator.customTones.library') }}</h2>
              </div>
              <strong>{{ admin.customTones.length }}</strong>
            </div>
            <div class="admin-panel-tone-directory">
              <article>
                <span
                  ><PhoneCall :size="16" style="--admin-icon-size: 16"
                /></span>
                <div>
                  <strong>{{ t('configurator.customTones.ringtones') }}</strong>
                  <small
                    >{{
                      admin.customTones.filter(
                        (tone) => tone.toneType === 'ringtone',
                      ).length
                    }}/32</small
                  >
                </div>
              </article>
              <article>
                <span
                  ><MessageSquare :size="16" style="--admin-icon-size: 16"
                /></span>
                <div>
                  <strong>{{
                    t('configurator.customTones.notifications')
                  }}</strong>
                  <small
                    >{{
                      admin.customTones.filter(
                        (tone) => tone.toneType === 'notification',
                      ).length
                    }}/32</small
                  >
                </div>
              </article>
            </div>
          </template>

          <template v-else-if="tab === 'configurator'">
            <div class="admin-panel-directory__header">
              <div>
                <span>{{ t('configurator.eyebrow') }}</span>
                <h2>{{ t('configurator.sections') }}</h2>
              </div>
              <strong>{{ filteredConfiguratorFieldCount }}</strong>
            </div>
            <label class="admin-panel-search">
              <Search :size="16" style="--admin-icon-size: 16" />
              <input
                v-model="configuratorQuery"
                type="search"
                :placeholder="t('configurator.search')"
                :aria-label="t('configurator.search')"
              />
            </label>
            <div
              class="admin-panel-config-scopes"
              role="tablist"
              :aria-label="t('configurator.sections')"
            >
              <button
                type="button"
                role="tab"
                :aria-selected="configuratorScope === 'config'"
                :class="{ 'is-active': configuratorScope === 'config' }"
                @click="selectConfiguratorScope('config')"
              >
                <span>{{ t('configurator.configScope') }}</span>
                <em>{{ configuratorScopeCounts.config }}</em>
              </button>
              <button
                type="button"
                role="tab"
                :aria-selected="configuratorScope === 'media'"
                :class="{ 'is-active': configuratorScope === 'media' }"
                @click="selectConfiguratorScope('media')"
              >
                <span>{{ t('configurator.mediaScope') }}</span>
                <em>{{ configuratorScopeCounts.media }}</em>
              </button>
            </div>
            <div class="admin-panel-config-sections">
              <button
                v-for="section in filteredConfiguratorSections"
                :key="section.id"
                type="button"
                :class="{
                  'is-active': activeConfiguratorSection?.id === section.id,
                }"
                @click="selectedConfiguratorSection = section.id"
              >
                <Settings2 :size="16" style="--admin-icon-size: 16" />
                <span>
                  <strong>{{ section.label }}</strong>
                  <small>{{
                    section.scope === 'media'
                      ? t('configurator.mediaScope')
                      : t('configurator.configScope')
                  }}</small>
                </span>
                <em>{{ configuratorSectionCount(section.fields) }}</em>
              </button>
              <div
                v-if="!filteredConfiguratorSections.length"
                class="admin-panel-empty-list"
              >
                <Search :size="24" style="--admin-icon-size: 24" />
                <strong>{{ t('configurator.noResults') }}</strong>
              </div>
            </div>
          </template>

          <template v-else-if="tab !== 'audit'">
            <div class="admin-panel-directory__header">
              <div>
                <span>{{ t('players.eyebrow') }}</span>
                <h2>{{ t('players.title') }}</h2>
              </div>
              <strong>{{ filteredPlayers.length }}</strong>
            </div>
            <label class="admin-panel-search">
              <Search :size="16" style="--admin-icon-size: 16" />
              <input
                v-model="playerQuery"
                type="search"
                :placeholder="t('search.players')"
                :aria-label="t('search.players')"
              />
            </label>

            <div class="admin-panel-player-list">
              <button
                v-for="player in filteredPlayers"
                :key="player.source"
                type="button"
                :class="{
                  'is-active': admin.selectedPlayer?.source === player.source,
                }"
                @click="queueAction({ kind: 'player', source: player.source })"
              >
                <span class="admin-panel-avatar">{{
                  initials(player.name)
                }}</span>
                <span class="admin-panel-player-list__copy">
                  <strong>{{ player.name }}</strong>
                  <small>{{ player.job }} · ID {{ player.source }}</small>
                </span>
                <span class="admin-panel-player-list__meta">
                  <span class="admin-panel-online-dot"></span>
                  {{ player.deviceCount }}
                </span>
              </button>

              <div
                v-if="!filteredPlayers.length"
                class="admin-panel-empty-list"
              >
                <UsersRound :size="26" style="--admin-icon-size: 26" />
                <strong>{{ t('players.empty') }}</strong>
                <span>{{ t('players.emptyBody') }}</span>
              </div>
            </div>
          </template>

          <template v-else>
            <div class="admin-panel-directory__header">
              <div>
                <span>{{ t('audit.eyebrow') }}</span>
                <h2>{{ t('audit.title') }}</h2>
              </div>
              <strong>{{ admin.audit.length }}</strong>
            </div>
            <div class="admin-panel-audit-mini-list">
              <article v-for="entry in admin.audit" :key="entry.id">
                <span class="admin-panel-audit-icon"
                  ><ScrollText :size="15" style="--admin-icon-size: 15"
                /></span>
                <div>
                  <strong>{{ t('audit.actions.' + entry.action) }}</strong>
                  <span>{{ entry.actorName }}</span>
                  <small>{{ formatDate(entry.createdAt) }}</small>
                </div>
              </article>
            </div>
          </template>
        </aside>

        <main class="admin-panel-editor">
          <div
            v-if="admin.loading && !admin.initialized"
            class="admin-panel-loading"
          >
            <LoaderCircle
              :size="26"
              style="--admin-icon-size: 26"
              class="is-spinning"
            />
            <span>{{ t('loading') }}</span>
          </div>

          <section
            v-else-if="tab === 'overview'"
            class="admin-panel-editor__scroll"
          >
            <div class="admin-panel-page-heading">
              <div>
                <span>{{ t('overview.eyebrow') }}</span>
                <h1>{{ t('overview.title') }}</h1>
                <p>{{ t('overview.body') }}</p>
              </div>
            </div>

            <div class="admin-panel-stat-grid">
              <article>
                <UsersRound :size="18" style="--admin-icon-size: 18" />
                <span>{{ t('overview.online') }}</span>
                <strong>{{ formatStatistic(admin.stats.online) }}</strong>
              </article>
              <article>
                <Smartphone :size="18" style="--admin-icon-size: 18" />
                <span>{{ t('overview.devices') }}</span>
                <strong>{{ formatStatistic(admin.stats.devices) }}</strong>
              </article>
              <article>
                <Database :size="18" style="--admin-icon-size: 18" />
                <span>{{ t('overview.accounts') }}</span>
                <strong>{{ formatStatistic(admin.stats.accounts) }}</strong>
              </article>
              <article>
                <ScrollText :size="18" style="--admin-icon-size: 18" />
                <span>{{ t('overview.audit') }}</span>
                <strong>{{ formatStatistic(admin.stats.auditEntries) }}</strong>
              </article>
            </div>

            <article
              class="admin-panel-section-card admin-panel-section-card--compact"
            >
              <div class="admin-panel-section-card__heading">
                <div>
                  <span>{{ t('statistics.eyebrow') }}</span>
                  <h2>{{ t('statistics.title') }}</h2>
                  <p>{{ t('statistics.body') }}</p>
                </div>
                <ChartNoAxesCombined :size="20" style="--admin-icon-size: 20" />
              </div>
              <div class="admin-panel-statistics-layout">
                <section class="admin-panel-activity-statistics">
                  <div class="admin-panel-statistics-heading">
                    <div>
                      <strong>{{ t('statistics.today') }}</strong>
                      <small>{{ t('statistics.todayBody') }}</small>
                    </div>
                  </div>
                  <div class="admin-panel-activity-grid">
                    <article>
                      <MessageSquare :size="17" style="--admin-icon-size: 17" />
                      <strong>{{
                        formatStatistic(admin.stats.messagesToday)
                      }}</strong>
                      <span>{{ t('statistics.messagesToday') }}</span>
                    </article>
                    <article>
                      <PhoneCall :size="17" style="--admin-icon-size: 17" />
                      <strong>{{
                        formatStatistic(admin.stats.callsToday)
                      }}</strong>
                      <span>{{ t('statistics.callsToday') }}</span>
                    </article>
                    <article>
                      <ScrollText :size="17" style="--admin-icon-size: 17" />
                      <strong>{{
                        formatStatistic(admin.stats.auditToday)
                      }}</strong>
                      <span>{{ t('statistics.auditToday') }}</span>
                    </article>
                  </div>
                </section>

                <section class="admin-panel-coverage-statistics">
                  <div class="admin-panel-statistics-heading">
                    <div>
                      <strong>{{ t('statistics.coverage') }}</strong>
                      <small>{{ t('statistics.coverageBody') }}</small>
                    </div>
                  </div>
                  <div class="admin-panel-coverage-list">
                    <article
                      v-for="metric in [
                        {
                          key: 'linkedDevices',
                          value: admin.stats.linkedDevices,
                        },
                        {
                          key: 'simDevices',
                          value: admin.stats.simDevices,
                        },
                        {
                          key: 'activeDevices',
                          value: admin.stats.activeDevices,
                        },
                      ]"
                      :key="metric.key"
                    >
                      <div>
                        <strong>{{ t(`statistics.${metric.key}`) }}</strong>
                        <span>{{
                          t('statistics.ofDevices', {
                            count: formatStatistic(metric.value),
                            total: formatStatistic(admin.stats.devices),
                          })
                        }}</span>
                      </div>
                      <div
                        class="admin-panel-statistics-progress"
                        role="progressbar"
                        :aria-label="t(`statistics.${metric.key}`)"
                        :aria-valuemin="0"
                        :aria-valuemax="100"
                        :aria-valuenow="
                          statisticPercentage(metric.value, admin.stats.devices)
                        "
                      >
                        <span
                          :style="{
                            width: `${statisticPercentage(metric.value, admin.stats.devices)}%`,
                          }"
                        ></span>
                      </div>
                    </article>
                  </div>
                </section>
              </div>
            </article>
          </section>

          <section
            v-else-if="tab === 'tones'"
            class="admin-panel-editor__scroll"
          >
            <div class="admin-panel-page-heading">
              <div class="admin-panel-heading-icon">
                <BellRing :size="23" style="--admin-icon-size: 23" />
              </div>
              <div>
                <span>{{ t('configurator.customTones.eyebrow') }}</span>
                <h1>{{ t('configurator.customTones.title') }}</h1>
                <p>{{ t('configurator.customTones.body') }}</p>
              </div>
            </div>
            <AdminCustomToneManager @toast="showToast" />
          </section>

          <section
            v-else-if="tab === 'configurator'"
            class="admin-panel-editor__scroll"
          >
            <div
              v-if="admin.configuratorLoading && !admin.configurator"
              class="admin-panel-loading"
            >
              <LoaderCircle
                :size="26"
                style="--admin-icon-size: 26"
                class="is-spinning"
              />
              <span>{{ t('configurator.loading') }}</span>
            </div>

            <template v-else-if="admin.configurator">
              <div class="admin-panel-page-heading">
                <div class="admin-panel-heading-icon">
                  <Settings2 :size="23" style="--admin-icon-size: 23" />
                </div>
                <div class="admin-panel-config-heading-copy">
                  <span>{{ t('configurator.eyebrow') }}</span>
                  <h1>{{ t('configurator.title') }}</h1>
                  <p>{{ t('configurator.body') }}</p>
                </div>
              </div>

              <article
                v-if="!admin.configurator.enabled"
                class="admin-panel-config-disabled"
              >
                <TriangleAlert :size="20" style="--admin-icon-size: 20" />
                <div>
                  <strong>{{ t('configurator.disabledTitle') }}</strong>
                  <p>{{ t('configurator.disabledBody') }}</p>
                  <code>Config.PhoneConfigurator.Enabled = true</code>
                </div>
              </article>

              <article class="admin-panel-config-notice">
                <Save :size="18" style="--admin-icon-size: 18" />
                <div>
                  <strong>{{ t('configurator.manualSave') }}</strong>
                  <p>{{ t('configurator.refreshNotice') }}</p>
                </div>
              </article>

              <section
                v-if="activeConfiguratorSection"
                class="admin-panel-config-workspace"
              >
                <header>
                  <div>
                    <span>{{
                      activeConfiguratorSection.scope === 'media'
                        ? t('configurator.mediaScope')
                        : t('configurator.configScope')
                    }}</span>
                    <h2>{{ activeConfiguratorSection.label }}</h2>
                  </div>
                  <strong>{{
                    t('configurator.fieldCount', {
                      count: String(
                        configuratorSectionCount(
                          activeConfiguratorSection.fields,
                        ),
                      ),
                    })
                  }}</strong>
                </header>

                <div class="admin-panel-config-fields">
                  <div
                    v-for="field in activeConfiguratorSection.fields"
                    :key="configuratorFieldKey(field)"
                    class="admin-panel-config-field"
                    :class="{
                      'is-structured': field.type === 'json',
                      'is-dirty': Object.prototype.hasOwnProperty.call(
                        configuratorDrafts,
                        configuratorFieldKey(field),
                      ),
                    }"
                  >
                    <span
                      v-if="!configuratorFieldRepeatsSection(field)"
                      class="admin-panel-config-field__copy"
                    >
                      <strong>{{ field.label }}</strong>
                      <small
                        :title="
                          configuratorDescription(
                            field.path,
                            configuratorFieldValue(field),
                            field.structure,
                            field.label,
                          )
                        "
                      >
                        {{
                          configuratorDescription(
                            field.path,
                            configuratorFieldValue(field),
                            field.structure,
                            field.label,
                          )
                        }}
                      </small>
                      <code>{{ field.path }}</code>
                    </span>

                    <span
                      v-if="field.type === 'boolean'"
                      class="admin-panel-config-toggle"
                    >
                      <input
                        type="checkbox"
                        :aria-label="`${field.label} ${field.path}`"
                        :checked="Boolean(configuratorFieldValue(field))"
                        :disabled="!admin.configurator.enabled"
                        @change="updateConfiguratorToggle(field, $event)"
                      />
                      <i></i>
                    </span>

                    <AdminConfigValueEditor
                      v-else-if="field.type === 'json'"
                      :model-value="configuratorFieldValue(field)"
                      :structure="field.structure"
                      :aria-label="`${field.label} ${field.path}`"
                      :describe="configuratorDescription"
                      :labels="configuratorEditorLabels"
                      :disabled="!admin.configurator.enabled"
                      :path="field.path"
                      :tab-label="configuratorSubtabLabel"
                      @update:model-value="
                        updateConfiguratorField(field, $event)
                      "
                    />

                    <span
                      v-else-if="field.type === 'stringOrFalse'"
                      class="admin-panel-config-optional"
                    >
                      <input
                        v-config-input-width
                        type="text"
                        :aria-label="`${field.label} ${field.path}`"
                        :value="
                          configuratorFieldValue(field) === false
                            ? ''
                            : String(configuratorFieldValue(field) ?? '')
                        "
                        :disabled="
                          !admin.configurator.enabled ||
                          configuratorFieldValue(field) === false
                        "
                        autocomplete="off"
                        @input="updateConfiguratorInput(field, $event)"
                      />
                      <span class="admin-panel-config-toggle">
                        <input
                          type="checkbox"
                          :aria-label="`${field.label} ${field.path}`"
                          :checked="configuratorFieldValue(field) !== false"
                          :disabled="!admin.configurator.enabled"
                          @change="updateOptionalStringToggle(field, $event)"
                        />
                        <i></i>
                      </span>
                    </span>

                    <input
                      v-else
                      v-config-input-width
                      :aria-label="`${field.label} ${field.path}`"
                      :type="
                        field.sensitive
                          ? 'password'
                          : field.type === 'number'
                            ? 'number'
                            : 'text'
                      "
                      :value="String(configuratorFieldValue(field) ?? '')"
                      :placeholder="
                        field.sensitive && field.configured
                          ? t('configurator.secretConfigured')
                          : ''
                      "
                      :disabled="!admin.configurator.enabled"
                      :autocomplete="field.sensitive ? 'new-password' : 'off'"
                      @input="updateConfiguratorInput(field, $event)"
                    />
                  </div>
                </div>
              </section>
            </template>
          </section>

          <section
            v-else-if="tab === 'audit'"
            class="admin-panel-editor__scroll"
          >
            <div class="admin-panel-page-heading">
              <div class="admin-panel-heading-icon">
                <ScrollText :size="23" style="--admin-icon-size: 23" />
              </div>
              <div>
                <span>{{ t('audit.eyebrow') }}</span>
                <h1>{{ t('audit.title') }}</h1>
                <p>{{ t('audit.body') }}</p>
              </div>
            </div>
            <div v-if="admin.audit.length" class="admin-panel-audit-grid">
              <article v-for="entry in admin.audit" :key="entry.id">
                <div class="admin-panel-audit-grid__topline">
                  <span>{{ t('audit.actions.' + entry.action) }}</span>
                  <time>{{ formatDate(entry.createdAt) }}</time>
                </div>
                <strong>{{ auditDescription(entry) }}</strong>
                <p>
                  {{
                    t('audit.by', {
                      actor: entry.actorName,
                      target: String(entry.targetSource ?? '—'),
                    })
                  }}
                </p>
              </article>
            </div>
            <div v-else class="admin-panel-empty-editor">
              <ScrollText :size="34" style="--admin-icon-size: 34" />
              <h2>{{ t('audit.empty') }}</h2>
              <p>{{ t('audit.emptyBody') }}</p>
            </div>
          </section>

          <section
            v-else-if="admin.selectedPlayer"
            class="admin-panel-editor__scroll"
          >
            <div class="admin-panel-profile-heading">
              <span class="admin-panel-profile-avatar">
                {{ initials(admin.selectedPlayer.name) }}
              </span>
              <div>
                <span>{{ t('detail.character') }}</span>
                <h1>{{ admin.selectedPlayer.name }}</h1>
                <p>{{ admin.selectedPlayer.serverName }}</p>
              </div>
              <div v-if="selectedDevice" class="admin-panel-player-actions">
                <button
                  type="button"
                  :disabled="
                    !selectedDevice.security.enabled || !!admin.actionKey
                  "
                  @click="openDeviceAction('reset-passcode')"
                >
                  <KeyRound :size="15" style="--admin-icon-size: 15" />{{
                    t('moderation.resetPasscode')
                  }}
                </button>
                <button
                  type="button"
                  :disabled="!selectedDevice.number || !!admin.actionKey"
                  @click="openDeviceAction('change-number')"
                >
                  <PhoneForwarded :size="15" style="--admin-icon-size: 15" />{{
                    t('moderation.changeNumber')
                  }}
                </button>
                <button
                  type="button"
                  class="is-danger"
                  :disabled="hasChanges || !!admin.actionKey"
                  :title="hasChanges ? t('moderation.saveFirst') : ''"
                  @click="openDeviceAction('factory-reset')"
                >
                  <Trash2 :size="15" style="--admin-icon-size: 15" />{{
                    t('moderation.factoryReset')
                  }}
                </button>
              </div>
            </div>

            <div
              v-if="
                tab === 'devices' ||
                tab === 'apps' ||
                tab === 'accounts' ||
                tab === 'messages' ||
                tab === 'calls' ||
                tab === 'moderation'
              "
              class="admin-panel-device-tabs"
              :aria-label="t('devices.choose')"
            >
              <button
                v-for="device in admin.selectedPlayer.devices"
                :key="device.imei"
                type="button"
                :class="{
                  'is-active': device.imei === selectedDevice?.imei,
                  'is-dirty': Boolean(
                    Object.keys(drafts[device.imei] ?? {}).length,
                  ),
                }"
                @click="selectedImei = device.imei"
              >
                <Smartphone :size="16" style="--admin-icon-size: 16" />
                <span>{{ device.name }}</span>
                <small>{{ device.number || device.imei.slice(-4) }}</small>
              </button>
            </div>

            <div v-if="tab === 'players'" class="admin-panel-stat-grid">
              <article>
                <WalletCards :size="18" style="--admin-icon-size: 18" />
                <span>{{ t('detail.cash') }}</span>
                <strong>{{
                  formatMoney(
                    admin.selectedPlayer.money.cash,
                    admin.selectedPlayer.money.currency,
                  )
                }}</strong>
              </article>
              <article>
                <BadgeDollarSign :size="18" style="--admin-icon-size: 18" />
                <span>{{ t('detail.bank') }}</span>
                <strong>{{
                  formatMoney(
                    admin.selectedPlayer.money.bank,
                    admin.selectedPlayer.money.currency,
                  )
                }}</strong>
              </article>
              <article>
                <BriefcaseBusiness :size="18" style="--admin-icon-size: 18" />
                <span>{{ t('detail.job') }}</span>
                <strong>{{
                  admin.selectedPlayer.job.label ||
                  admin.selectedPlayer.job.name
                }}</strong>
              </article>
              <article>
                <Wifi :size="18" style="--admin-icon-size: 18" />
                <span>{{ t('detail.duty') }}</span>
                <strong>{{
                  admin.selectedPlayer.job.onDuty
                    ? t('detail.onDuty')
                    : t('detail.offDuty')
                }}</strong>
              </article>
            </div>

            <div v-if="tab === 'players'" class="admin-panel-section-grid">
              <article class="admin-panel-section-card">
                <div class="admin-panel-section-card__heading">
                  <div>
                    <span>{{ t('editor.profile') }}</span>
                    <h2>{{ t('detail.playerData') }}</h2>
                  </div>
                  <CircleUserRound :size="20" style="--admin-icon-size: 20" />
                </div>
                <dl class="admin-panel-field-list">
                  <div>
                    <dt>{{ t('detail.identifier') }}</dt>
                    <dd>{{ admin.selectedPlayer.identifier }}</dd>
                  </div>
                  <div>
                    <dt>{{ t('detail.birthdate') }}</dt>
                    <dd>
                      {{
                        admin.selectedPlayer.birthdate || t('detail.unknown')
                      }}
                    </dd>
                  </div>
                  <div>
                    <dt>{{ t('detail.grade') }}</dt>
                    <dd>
                      {{ admin.selectedPlayer.job.grade }} ·
                      {{
                        admin.selectedPlayer.job.gradeLabel ||
                        t('detail.unknown')
                      }}
                    </dd>
                  </div>
                </dl>
              </article>

              <article class="admin-panel-section-card">
                <div class="admin-panel-section-card__heading">
                  <div>
                    <span>{{ t('editor.device') }}</span>
                    <h2>{{ t('devices.title') }}</h2>
                  </div>
                  <HardDrive :size="20" style="--admin-icon-size: 20" />
                </div>
                <div v-if="selectedDevice" class="admin-panel-device-summary">
                  <span class="admin-panel-device-summary__icon">
                    <Smartphone :size="23" style="--admin-icon-size: 23" />
                  </span>
                  <div>
                    <strong>{{ selectedDevice.name }}</strong>
                    <span>{{
                      selectedDevice.number || t('devices.noNumber')
                    }}</span>
                  </div>
                  <small>{{
                    selectedDevice.simType || t('devices.noSim')
                  }}</small>
                </div>
                <dl v-if="selectedDevice" class="admin-panel-field-list">
                  <div>
                    <dt>{{ t('devices.imei') }}</dt>
                    <dd>{{ selectedDevice.imei }}</dd>
                  </div>
                  <div>
                    <dt>{{ t('devices.updated') }}</dt>
                    <dd>{{ formatDate(selectedDevice.updatedAt) }}</dd>
                  </div>
                </dl>
                <div v-else class="admin-panel-inline-empty">
                  {{ t('devices.emptyBody') }}
                </div>
              </article>
            </div>

            <article
              v-if="tab === 'devices'"
              class="admin-panel-section-card admin-panel-section-card--focused"
            >
              <div class="admin-panel-section-card__heading">
                <div>
                  <span>{{ t('editor.device') }}</span>
                  <h2>{{ t('devices.title') }}</h2>
                  <p>{{ t('devices.body') }}</p>
                </div>
                <HardDrive :size="20" style="--admin-icon-size: 20" />
              </div>
              <div v-if="selectedDevice" class="admin-panel-device-summary">
                <span class="admin-panel-device-summary__icon">
                  <Smartphone :size="23" style="--admin-icon-size: 23" />
                </span>
                <div>
                  <strong>{{ selectedDevice.name }}</strong>
                  <span>{{
                    selectedDevice.number || t('devices.noNumber')
                  }}</span>
                </div>
                <small>{{
                  selectedDevice.simType || t('devices.noSim')
                }}</small>
              </div>
              <dl v-if="selectedDevice" class="admin-panel-field-list">
                <div>
                  <dt>{{ t('devices.imei') }}</dt>
                  <dd>{{ selectedDevice.imei }}</dd>
                </div>
                <div>
                  <dt>{{ t('devices.updated') }}</dt>
                  <dd>{{ formatDate(selectedDevice.updatedAt) }}</dd>
                </div>
                <div>
                  <dt>{{ t('devices.apps') }}</dt>
                  <dd>{{ selectedDevice.apps.claimed.length }}</dd>
                </div>
                <div>
                  <dt>{{ t('devices.account') }}</dt>
                  <dd>
                    {{
                      selectedDevice.account?.email ||
                      t('credentials.noAccount')
                    }}
                  </dd>
                </div>
              </dl>
              <div v-else class="admin-panel-inline-empty">
                {{ t('devices.emptyBody') }}
              </div>
            </article>

            <article
              v-if="tab === 'messages' && selectedDevice"
              class="admin-panel-section-card admin-panel-section-card--focused"
            >
              <div class="admin-panel-section-card__heading">
                <div>
                  <span>{{ t('activity.protected') }}</span>
                  <h2>{{ t('activity.messagesTitle') }}</h2>
                  <p>{{ t('activity.messagesBody') }}</p>
                </div>
                <MessageSquare :size="20" style="--admin-icon-size: 20" />
              </div>
              <div
                v-if="admin.activityKey === selectedDevice.imei + ':messages'"
                class="admin-panel-inline-empty"
              >
                <LoaderCircle
                  :size="20"
                  style="--admin-icon-size: 20"
                  class="is-spinning"
                />
                {{ t('activity.loading') }}
              </div>
              <div
                v-else-if="selectedMessages.length"
                class="admin-panel-activity-list"
              >
                <article v-for="entry in selectedMessages" :key="entry.id">
                  <span class="admin-panel-activity-icon">
                    <MessageSquare :size="17" style="--admin-icon-size: 17" />
                  </span>
                  <div>
                    <span class="admin-panel-activity-meta">
                      {{ t('activity.' + entry.direction) }} ·
                      {{ entry.otherNumber }}
                    </span>
                    <strong>{{
                      entry.body ||
                      t('activity.mediaMessage', { type: entry.messageType })
                    }}</strong>
                    <small>{{ formatDate(entry.createdAt) }}</small>
                  </div>
                </article>
              </div>
              <div v-else class="admin-panel-inline-empty">
                {{ t('activity.noMessages') }}
              </div>
            </article>

            <article
              v-if="tab === 'calls' && selectedDevice"
              class="admin-panel-section-card admin-panel-section-card--focused"
            >
              <div class="admin-panel-section-card__heading">
                <div>
                  <span>{{ t('activity.protected') }}</span>
                  <h2>{{ t('activity.callsTitle') }}</h2>
                  <p>{{ t('activity.callsBody') }}</p>
                </div>
                <PhoneCall :size="20" style="--admin-icon-size: 20" />
              </div>
              <div
                v-if="admin.activityKey === selectedDevice.imei + ':calls'"
                class="admin-panel-inline-empty"
              >
                <LoaderCircle
                  :size="20"
                  style="--admin-icon-size: 20"
                  class="is-spinning"
                />
                {{ t('activity.loading') }}
              </div>
              <div
                v-else-if="selectedCalls.length"
                class="admin-panel-activity-list"
              >
                <article v-for="entry in selectedCalls" :key="entry.id">
                  <span class="admin-panel-activity-icon">
                    <PhoneCall :size="17" style="--admin-icon-size: 17" />
                  </span>
                  <div>
                    <span class="admin-panel-activity-meta">
                      {{ t('activity.' + entry.direction) }} ·
                      {{ entry.otherNumber }}
                    </span>
                    <strong>
                      {{ t('activity.status.' + entry.status) }} ·
                      {{ formatDuration(entry.durationSeconds) }}
                    </strong>
                    <small>{{ formatDate(entry.startedAt) }}</small>
                  </div>
                </article>
              </div>
              <div v-else class="admin-panel-inline-empty">
                {{ t('activity.noCalls') }}
              </div>
            </article>

            <article
              v-if="tab === 'moderation' && selectedDevice"
              class="admin-panel-section-card admin-panel-section-card--focused"
            >
              <div class="admin-panel-section-card__heading">
                <div>
                  <span>{{ t('moderation.eyebrow') }}</span>
                  <h2>{{ t('moderation.title') }}</h2>
                  <p>{{ t('moderation.body') }}</p>
                </div>
                <ShieldAlert :size="20" style="--admin-icon-size: 20" />
              </div>
              <div class="admin-panel-moderation-grid">
                <button
                  type="button"
                  :disabled="
                    !selectedDevice.security.enabled || !!admin.actionKey
                  "
                  @click="openDeviceAction('reset-passcode')"
                >
                  <KeyRound :size="20" style="--admin-icon-size: 20" />
                  <span>
                    <strong>{{ t('moderation.resetPasscode') }}</strong>
                    <small>{{ t('moderation.resetPasscodeBody') }}</small>
                  </span>
                  <ChevronRight :size="15" style="--admin-icon-size: 15" />
                </button>
                <button
                  type="button"
                  :disabled="!selectedDevice.number || !!admin.actionKey"
                  @click="openDeviceAction('change-number')"
                >
                  <PhoneForwarded :size="20" style="--admin-icon-size: 20" />
                  <span>
                    <strong>{{ t('moderation.changeNumber') }}</strong>
                    <small>{{ t('moderation.changeNumberBody') }}</small>
                  </span>
                  <ChevronRight :size="15" style="--admin-icon-size: 15" />
                </button>
                <button
                  type="button"
                  class="is-danger"
                  :disabled="hasChanges || !!admin.actionKey"
                  @click="openDeviceAction('factory-reset')"
                >
                  <Trash2 :size="20" style="--admin-icon-size: 20" />
                  <span>
                    <strong>{{ t('moderation.factoryReset') }}</strong>
                    <small>{{ t('moderation.factoryResetBody') }}</small>
                  </span>
                  <ChevronRight :size="15" style="--admin-icon-size: 15" />
                </button>
              </div>
            </article>

            <article
              v-if="tab === 'accounts' && selectedDevice"
              class="admin-panel-section-card admin-panel-section-card--focused"
            >
              <div class="admin-panel-section-card__heading">
                <div>
                  <span>{{ t('editor.security') }}</span>
                  <h2>{{ t('credentials.title') }}</h2>
                </div>
                <KeyRound :size="20" style="--admin-icon-size: 20" />
              </div>
              <div class="admin-panel-security-grid">
                <div class="admin-panel-credential-box">
                  <span>{{ t('credentials.email') }}</span>
                  <strong>{{
                    selectedDevice.account?.email || t('credentials.noAccount')
                  }}</strong>
                </div>
                <div class="admin-panel-credential-box">
                  <span>{{ t('credentials.password') }}</span>
                  <strong class="admin-panel-password">
                    {{ revealedCredential?.password || '••••••••••••' }}
                  </strong>
                  <button
                    v-if="selectedDevice.account && !revealedCredential"
                    type="button"
                    :disabled="
                      admin.actionKey === selectedDevice.imei + ':password'
                    "
                    @click="revealDialogImei = selectedDevice.imei"
                  >
                    <Eye :size="15" style="--admin-icon-size: 15" />{{
                      t('credentials.reveal')
                    }}
                  </button>
                  <button
                    v-else-if="revealedCredential"
                    type="button"
                    @click="copyPassword"
                  >
                    <Clipboard :size="15" style="--admin-icon-size: 15" />{{
                      t('credentials.copy')
                    }}
                  </button>
                </div>
                <div
                  class="admin-panel-credential-box admin-panel-credential-box--pin"
                >
                  <LockKeyhole :size="18" style="--admin-icon-size: 18" />
                  <div>
                    <span>{{ t('credentials.passcode') }}</span>
                    <strong>{{
                      selectedDevice.security.enabled
                        ? t('credentials.passcodeHashed', {
                            length: String(selectedDevice.security.length ?? 0),
                          })
                        : t('credentials.passcodeDisabled')
                    }}</strong>
                  </div>
                </div>
              </div>
            </article>

            <article
              v-if="tab === 'apps' && selectedDevice"
              class="admin-panel-section-card admin-panel-section-card--focused"
            >
              <div
                class="admin-panel-section-card__heading admin-panel-app-heading"
              >
                <div>
                  <span>{{ t('apps.eyebrow') }}</span>
                  <h2>{{ t('apps.title') }}</h2>
                  <p>{{ t('apps.description') }}</p>
                </div>
                <div class="admin-panel-app-heading__actions">
                  <span v-if="selectedDeviceChanges">
                    {{
                      t('apps.changes', {
                        count: String(selectedDeviceChanges),
                      })
                    }}
                  </span>
                  <label class="admin-panel-search admin-panel-search--apps">
                    <Search :size="15" style="--admin-icon-size: 15" />
                    <input
                      v-model="appQuery"
                      type="search"
                      :placeholder="t('search.apps')"
                      :aria-label="t('search.apps')"
                    />
                  </label>
                </div>
              </div>

              <div class="admin-panel-manual-save-note">
                <Save :size="17" style="--admin-icon-size: 17" />
                <div>
                  <strong>{{ t('editor.noAutoSave') }}</strong>
                  <span>{{ t('editor.noAutoSaveBody') }}</span>
                </div>
              </div>

              <div class="admin-panel-app-grid">
                <button
                  v-for="app in manageableApps"
                  :key="app.id"
                  type="button"
                  :class="{
                    'is-enabled': isInstalled(selectedDevice, app),
                    'is-dirty': Object.prototype.hasOwnProperty.call(
                      drafts[selectedDevice.imei] ?? {},
                      app.id,
                    ),
                  }"
                  :disabled="
                    isInstalled(selectedDevice, app) &&
                    !isPhoneAppRemovable(app)
                  "
                  @click="toggleApp(app)"
                >
                  <span class="admin-panel-app-icon" :class="app.iconClass">
                    <component
                      :is="app.icon"
                      :size="18"
                      style="--admin-icon-size: 18"
                    />
                  </span>
                  <span class="admin-panel-app-copy">
                    <strong>{{ getPhoneAppLabel(app, phone.t) }}</strong>
                    <small>{{
                      !isPhoneAppRemovable(app)
                        ? t('apps.protected')
                        : isInstalled(selectedDevice, app)
                          ? t('apps.installed')
                          : t('apps.available')
                    }}</small>
                  </span>
                  <span class="admin-panel-switch" aria-hidden="true">
                    <span></span>
                  </span>
                </button>
              </div>
            </article>

            <article
              v-if="
                (tab === 'apps' ||
                  tab === 'accounts' ||
                  tab === 'messages' ||
                  tab === 'calls' ||
                  tab === 'moderation') &&
                !selectedDevice
              "
              class="admin-panel-section-card admin-panel-section-card--focused"
            >
              <div class="admin-panel-inline-empty">
                {{ t('devices.emptyBody') }}
              </div>
            </article>
          </section>

          <section v-else class="admin-panel-empty-editor">
            <span class="admin-panel-empty-editor__icon">
              <LayoutDashboard :size="34" style="--admin-icon-size: 34" />
            </span>
            <span>{{ t('overview.eyebrow') }}</span>
            <h1>{{ t('overview.title') }}</h1>
            <p>{{ t('editor.selectPlayer') }}</p>
            <div class="admin-panel-empty-stats">
              <article>
                <UsersRound :size="18" style="--admin-icon-size: 18" />
                <strong>{{ admin.stats.online }}</strong>
                <span>{{ t('overview.online') }}</span>
              </article>
              <article>
                <Smartphone :size="18" style="--admin-icon-size: 18" />
                <strong>{{ admin.stats.devices }}</strong>
                <span>{{ t('overview.devices') }}</span>
              </article>
              <article>
                <Database :size="18" style="--admin-icon-size: 18" />
                <strong>{{ admin.stats.accounts }}</strong>
                <span>{{ t('overview.accounts') }}</span>
              </article>
            </div>
          </section>
        </main>
      </div>
    </div>

    <Transition name="admin-toast">
      <div v-if="toast" class="admin-panel-toast" :class="`is-${toastTone}`">
        <Check
          v-if="toastTone === 'success'"
          :size="17"
          style="--admin-icon-size: 17"
        />
        <TriangleAlert v-else :size="17" style="--admin-icon-size: 17" />
        {{ toast }}
      </div>
    </Transition>

    <div v-if="revealDialogImei" class="admin-panel-dialog-backdrop">
      <section class="admin-panel-dialog" role="alertdialog">
        <span class="admin-panel-dialog__icon"
          ><KeyRound :size="21" style="--admin-icon-size: 21"
        /></span>
        <div>
          <h2>{{ t('credentials.revealTitle') }}</h2>
          <p>{{ t('credentials.revealBody') }}</p>
        </div>
        <div class="admin-panel-dialog__actions">
          <SkyButton variant="secondary" @click="revealDialogImei = ''">
            {{ t('credentials.cancel') }}
          </SkyButton>
          <SkyButton class="is-primary" @click="revealPassword">
            <Eye :size="15" style="--admin-icon-size: 15" />{{
              t('credentials.confirmReveal')
            }}
          </SkyButton>
        </div>
      </section>
    </div>

    <div v-if="deviceAction" class="admin-panel-dialog-backdrop">
      <section class="admin-panel-dialog" role="alertdialog">
        <span
          class="admin-panel-dialog__icon"
          :class="{ 'is-warning': deviceAction === 'factory-reset' }"
        >
          <Trash2
            v-if="deviceAction === 'factory-reset'"
            :size="21"
            style="--admin-icon-size: 21"
          />
          <PhoneForwarded
            v-else-if="deviceAction === 'change-number'"
            :size="21"
            style="--admin-icon-size: 21"
          />
          <KeyRound v-else :size="21" style="--admin-icon-size: 21" />
        </span>
        <div>
          <h2>{{ t(`moderation.dialogs.${deviceAction}Title`) }}</h2>
          <p>{{ t(`moderation.dialogs.${deviceAction}Body`) }}</p>
        </div>
        <label
          v-if="deviceAction === 'change-number'"
          class="admin-panel-action-input"
        >
          <span>{{ t('moderation.phoneNumber') }}</span>
          <input
            v-model="deviceActionInput"
            type="text"
            maxlength="24"
            :placeholder="t('moderation.phoneNumberPlaceholder')"
          />
        </label>
        <label
          v-else-if="deviceAction === 'factory-reset'"
          class="admin-panel-action-input"
        >
          <span>{{
            t('moderation.typeToConfirm', {
              word: t('moderation.confirmWord'),
            })
          }}</span>
          <input
            v-model="deviceActionInput"
            type="text"
            maxlength="16"
            :placeholder="t('moderation.confirmWord')"
          />
        </label>
        <div class="admin-panel-dialog__actions">
          <SkyButton variant="secondary" @click="cancelDeviceAction">
            {{ t('moderation.cancel') }}
          </SkyButton>
          <SkyButton
            :class="{ 'is-danger': deviceAction === 'factory-reset' }"
            :variant="deviceAction === 'factory-reset' ? 'danger' : 'primary'"
            :disabled="
              !!admin.actionKey ||
              (deviceAction === 'change-number' && !deviceActionInput.trim()) ||
              (deviceAction === 'factory-reset' &&
                deviceActionInput !== t('moderation.confirmWord'))
            "
            @click="confirmDeviceAction"
          >
            <LoaderCircle
              v-if="admin.actionKey"
              :size="15"
              style="--admin-icon-size: 15"
              class="is-spinning"
            />
            {{ t(`moderation.confirm.${deviceAction}`) }}
          </SkyButton>
        </div>
      </section>
    </div>

    <div v-if="discardDialog" class="admin-panel-dialog-backdrop">
      <section class="admin-panel-dialog" role="alertdialog">
        <span class="admin-panel-dialog__icon is-warning">
          <TriangleAlert :size="21" style="--admin-icon-size: 21" />
        </span>
        <div>
          <h2>{{ t('editor.discardTitle') }}</h2>
          <p>{{ t('editor.discardBody') }}</p>
        </div>
        <div class="admin-panel-dialog__actions">
          <SkyButton variant="secondary" @click="cancelDiscard">
            {{ t('editor.keepEditing') }}
          </SkyButton>
          <SkyButton
            class="is-danger"
            variant="danger"
            @click="discardAndContinue"
          >
            {{ t('editor.discard') }}
          </SkyButton>
        </div>
      </section>
    </div>
  </div>
</template>

<style scoped>
.admin-panel-overlay {
  /* One design pixel at 1080p, proportional growth on taller displays. */
  --admin-unit: max(1px, 0.0925926vh);
  --admin-bg: #070908;
  --admin-panel: #0d0f0e;
  --admin-panel-raised: #131514;
  --admin-panel-hover: #191b1a;
  --admin-nav-active: #202220;
  --admin-border: rgba(255, 255, 255, 0.045);
  --admin-border-strong: rgba(255, 255, 255, 0.085);
  --admin-text: #f0f3f0;
  --admin-muted: #818781;
  --admin-dim: #555b55;
  --admin-accent: #00b8e4;
  --admin-green: var(--admin-accent);
  --admin-green-soft: color-mix(in srgb, var(--admin-green) 9%, transparent);
  --admin-toggle-on: #63d471;
  --admin-row-hover: linear-gradient(
    90deg,
    #1a1c1b 0%,
    rgba(24, 26, 25, 0.52) 48%,
    transparent 100%
  );
  --admin-row-active: linear-gradient(
    90deg,
    #212321 0%,
    #171918 45%,
    transparent 100%
  );
  --admin-red: #ef6969;
  position: fixed;
  z-index: 10000;
  inset: 0;
  display: grid;
  place-items: center;
  padding: 2.5vh 2.5vw;
  color: var(--admin-text);
  background: transparent;
  font-family: var(--sky-font-family, Inter, sans-serif);
  pointer-events: auto;
}

.admin-panel-overlay :deep(svg.lucide) {
  width: calc(var(--admin-icon-size, 16) * var(--admin-unit));
  height: calc(var(--admin-icon-size, 16) * var(--admin-unit));
  flex-shrink: 0;
}

.admin-panel-window {
  width: min(76vw, calc(1220 * var(--admin-unit)));
  height: min(74vh, calc(700 * var(--admin-unit)));
  overflow: hidden;
  border: calc(1 * var(--admin-unit)) solid rgba(255, 255, 255, 0.065);
  border-radius: calc(4 * var(--admin-unit));
  background: var(--admin-bg);
  box-shadow:
    0 calc(20 * var(--admin-unit)) calc(56 * var(--admin-unit))
      rgba(0, 0, 0, 0.72),
    inset 0 calc(1 * var(--admin-unit)) rgba(255, 255, 255, 0.018);
}

.admin-panel-header {
  height: calc(50 * var(--admin-unit));
  display: grid;
  grid-template-columns: calc(320 * var(--admin-unit)) 1fr auto;
  align-items: center;
  border-bottom: calc(1 * var(--admin-unit)) solid var(--admin-border);
  background: #0b0d0c;
}

.admin-panel-brand,
.admin-panel-context,
.admin-panel-actions,
.admin-panel-profile-heading,
.admin-panel-section-card__heading,
.admin-panel-device-summary,
.admin-panel-manual-save-note,
.admin-panel-dialog__actions {
  display: flex;
  align-items: center;
}

.admin-panel-brand {
  height: 100%;
  padding: 0 calc(17 * var(--admin-unit));
  border-right: calc(1 * var(--admin-unit)) solid var(--admin-border);
}

.admin-panel-brand div,
.admin-panel-profile-heading > div:nth-child(2),
.admin-panel-device-summary div,
.admin-panel-manual-save-note div {
  display: grid;
  min-width: 0;
}

.admin-panel-brand strong {
  font-size: calc(11 * var(--admin-unit));
  letter-spacing: 0.13em;
}

.admin-panel-brand span:last-child {
  color: var(--admin-muted);
  font-size: calc(9 * var(--admin-unit));
  letter-spacing: 0.11em;
}

.admin-panel-context {
  gap: calc(7 * var(--admin-unit));
  min-width: 0;
  padding: 0 calc(16 * var(--admin-unit));
  color: var(--admin-dim);
  font-size: calc(11 * var(--admin-unit));
}

.admin-panel-context strong {
  overflow: hidden;
  color: #bfc4bf;
  font-weight: 550;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.admin-panel-actions {
  gap: calc(6 * var(--admin-unit));
  padding-right: calc(10 * var(--admin-unit));
}

.admin-panel-dirty {
  display: flex;
  align-items: center;
  gap: calc(7 * var(--admin-unit));
  margin-right: calc(5 * var(--admin-unit));
  color: #d2a861;
  font-size: calc(10 * var(--admin-unit));
}

.admin-panel-dirty > span,
.admin-panel-online-dot {
  width: calc(6 * var(--admin-unit));
  height: calc(6 * var(--admin-unit));
  border-radius: 50%;
  background: var(--admin-green);
  box-shadow: 0 0 calc(8 * var(--admin-unit))
    color-mix(in srgb, var(--admin-green) 75%, transparent);
}

.admin-panel-dirty > span {
  background: #d8aa5e;
  box-shadow: 0 0 calc(8 * var(--admin-unit)) rgba(216, 170, 94, 0.65);
}

.admin-panel-icon-button,
.admin-panel-save,
.admin-panel-rail button {
  border: 0;
  color: var(--admin-muted);
  background: transparent;
}

.admin-panel-icon-button,
.admin-panel-save {
  width: calc(40 * var(--admin-unit));
  height: calc(40 * var(--admin-unit));
  display: grid;
  place-items: center;
  border-radius: calc(6 * var(--admin-unit));
  cursor: pointer;
}

.admin-panel-icon-button:hover:not(:disabled) {
  color: var(--admin-text);
  background: var(--admin-panel-hover);
}

.admin-panel-save {
  border: 0;
  color: #555b55;
  background: transparent;
  box-shadow: none;
}

.admin-panel-save.is-ready {
  color: var(--admin-green);
  background: transparent;
  filter: drop-shadow(
    0 0 calc(5 * var(--admin-unit))
      color-mix(in srgb, var(--admin-green) 42%, transparent)
  );
}

.admin-panel-save.is-ready:hover:not(:disabled) {
  color: color-mix(in srgb, var(--admin-green) 82%, white);
  background: transparent;
  filter: drop-shadow(
    0 0 calc(7 * var(--admin-unit))
      color-mix(in srgb, var(--admin-green) 65%, transparent)
  );
}

.admin-panel-close:hover {
  color: var(--admin-red) !important;
  background: rgba(239, 105, 105, 0.09) !important;
}

button:disabled {
  cursor: not-allowed !important;
  opacity: 0.5;
}

.admin-panel-body {
  height: calc(100% - calc(50 * var(--admin-unit)));
  display: grid;
  grid-template-columns:
    calc(50 * var(--admin-unit)) calc(270 * var(--admin-unit))
    minmax(0, 1fr);
}

.admin-panel-rail {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: calc(5 * var(--admin-unit));
  padding: calc(8 * var(--admin-unit)) 0;
  border-right: calc(1 * var(--admin-unit)) solid var(--admin-border);
  background: #111311;
}

.admin-panel-rail button {
  width: calc(38 * var(--admin-unit));
  height: calc(38 * var(--admin-unit));
  display: grid;
  place-items: center;
  border-radius: calc(6 * var(--admin-unit));
  cursor: pointer;
}

.admin-panel-rail button:hover,
.admin-panel-rail button.is-active {
  color: var(--admin-text);
  background: #222522;
}

.admin-panel-rail .admin-panel-rail__configurator {
  margin-top: auto;
}

.admin-panel-rail button.is-active {
  color: #f4f6f4;
  background: var(--admin-nav-active);
}

.admin-panel-directory {
  min-width: 0;
  overflow: hidden;
  border-right: calc(1 * var(--admin-unit)) solid var(--admin-border);
  background: #101210;
}

.admin-panel-directory__header {
  height: calc(62 * var(--admin-unit));
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 calc(16 * var(--admin-unit));
}

.admin-panel-directory__header div,
.admin-panel-section-card__heading > div:first-child,
.admin-panel-app-heading > div:first-child,
.admin-panel-page-heading > div:last-child {
  display: grid;
  gap: calc(2 * var(--admin-unit));
}

.admin-panel-directory__header span,
.admin-panel-section-card__heading span,
.admin-panel-page-heading span,
.admin-panel-profile-heading > div > span {
  color: var(--admin-muted);
  font-size: calc(9 * var(--admin-unit));
  font-weight: 650;
  letter-spacing: 0.08em;
}

.admin-panel-directory__header h2,
.admin-panel-section-card__heading h2,
.admin-panel-page-heading h1,
.admin-panel-profile-heading h1,
.admin-panel-empty-editor h1,
.admin-panel-dialog h2 {
  margin: 0;
  font-weight: 600;
}

.admin-panel-directory__header h2 {
  font-size: calc(14 * var(--admin-unit));
}

.admin-panel-directory__header > strong {
  min-width: calc(28 * var(--admin-unit));
  padding: calc(4 * var(--admin-unit)) calc(7 * var(--admin-unit));
  border-radius: calc(5 * var(--admin-unit));
  color: #b7bcb7;
  background: #1b1e1b;
  font-size: calc(10 * var(--admin-unit));
  text-align: center;
}

.admin-panel-overview-directory {
  height: calc(100% - calc(62 * var(--admin-unit)));
  display: grid;
  align-content: start;
  gap: 0;
  overflow-y: auto;
  margin: 0 calc(14 * var(--admin-unit));
}

.admin-panel-overview-directory button,
.admin-panel-feature-grid button {
  display: grid;
  grid-template-columns: calc(30 * var(--admin-unit)) minmax(0, 1fr) auto;
  align-items: center;
  gap: calc(9 * var(--admin-unit));
  min-height: calc(47 * var(--admin-unit));
  padding: calc(7 * var(--admin-unit)) calc(4 * var(--admin-unit));
  border: 0;
  border-radius: calc(3 * var(--admin-unit));
  color: var(--admin-muted);
  background: transparent;
  text-align: left;
  cursor: pointer;
}

.admin-panel-overview-directory button:hover,
.admin-panel-feature-grid button:hover {
  color: var(--admin-green);
  background: var(--admin-row-hover);
}

.admin-panel-overview-directory button > svg:first-child,
.admin-panel-feature-grid button > svg:first-child {
  color: var(--admin-green);
}

.admin-panel-overview-directory button > span,
.admin-panel-feature-grid button > span {
  display: grid;
  min-width: 0;
  gap: calc(2 * var(--admin-unit));
}

.admin-panel-overview-directory strong,
.admin-panel-feature-grid strong {
  overflow: hidden;
  color: var(--admin-text);
  font-size: calc(10 * var(--admin-unit));
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.admin-panel-overview-directory small,
.admin-panel-feature-grid small {
  overflow: hidden;
  color: var(--admin-muted);
  font-size: calc(8 * var(--admin-unit));
  text-overflow: ellipsis;
  white-space: nowrap;
}

.admin-panel-search {
  height: calc(38 * var(--admin-unit));
  display: flex;
  align-items: center;
  gap: calc(8 * var(--admin-unit));
  margin: 0 calc(12 * var(--admin-unit)) calc(11 * var(--admin-unit));
  padding: 0 calc(10 * var(--admin-unit));
  border: calc(1 * var(--admin-unit)) solid var(--admin-border);
  border-radius: calc(6 * var(--admin-unit));
  color: var(--admin-dim);
  background: #161816;
}

.admin-panel-search:focus-within {
  border-color: color-mix(in srgb, var(--admin-green) 30%, transparent);
  color: var(--admin-green);
}

.admin-panel-search input {
  width: 100%;
  min-width: 0;
  border: 0;
  outline: 0;
  color: var(--admin-text);
  background: transparent;
  font: inherit;
  font-size: calc(11 * var(--admin-unit));
}

.admin-panel-search input::placeholder {
  color: #5f655f;
}

.admin-panel-config-scopes {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: calc(2 * var(--admin-unit));
  margin: 0 calc(12 * var(--admin-unit)) calc(8 * var(--admin-unit));
  padding: calc(3 * var(--admin-unit));
  border-radius: calc(4 * var(--admin-unit));
  background: #171917;
}

.admin-panel-config-scopes button {
  min-width: 0;
  height: calc(27 * var(--admin-unit));
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: calc(6 * var(--admin-unit));
  padding: 0 calc(8 * var(--admin-unit));
  border: 0;
  border-radius: calc(3 * var(--admin-unit));
  color: var(--admin-muted);
  background: transparent;
  font: inherit;
  font-size: calc(8 * var(--admin-unit));
  cursor: pointer;
}

.admin-panel-config-scopes button:hover,
.admin-panel-config-scopes button.is-active {
  color: var(--admin-text);
  background: var(--admin-row-active);
}

.admin-panel-config-scopes button.is-active {
  box-shadow: inset 0 -1px var(--admin-green);
}

.admin-panel-config-scopes em {
  color: var(--admin-dim);
  font-size: calc(7 * var(--admin-unit));
  font-style: normal;
}

.admin-panel-player-list,
.admin-panel-audit-mini-list,
.admin-panel-config-sections {
  height: calc(100% - calc(115 * var(--admin-unit)));
  overflow-y: auto;
  padding: 0 calc(8 * var(--admin-unit)) calc(16 * var(--admin-unit));
  scrollbar-color: #343834 transparent;
  scrollbar-width: thin;
}

.admin-panel-config-sections {
  height: calc(100% - calc(149 * var(--admin-unit)));
  overflow-y: auto;
  padding: 0 calc(8 * var(--admin-unit)) calc(16 * var(--admin-unit));
  scrollbar-color: #343834 transparent;
  scrollbar-width: thin;
}

.admin-panel-config-sections > button {
  width: 100%;
  min-height: calc(44 * var(--admin-unit));
  display: grid;
  grid-template-columns: calc(28 * var(--admin-unit)) minmax(0, 1fr) auto;
  align-items: center;
  gap: calc(8 * var(--admin-unit));
  padding: calc(7 * var(--admin-unit)) calc(9 * var(--admin-unit));
  border: 0;
  border-radius: calc(3 * var(--admin-unit));
  color: var(--admin-muted);
  background: transparent;
  text-align: left;
  cursor: pointer;
}

.admin-panel-config-sections > button:hover {
  color: var(--admin-text);
  background: var(--admin-row-hover);
}

.admin-panel-config-sections > button.is-active {
  color: var(--admin-green);
  background: var(--admin-row-active);
  box-shadow: inset calc(2 * var(--admin-unit)) 0 var(--admin-green);
}

.admin-panel-config-sections > button > svg {
  color: var(--admin-green);
}

.admin-panel-config-sections > button > span {
  display: grid;
  min-width: 0;
  gap: calc(2 * var(--admin-unit));
}

.admin-panel-config-sections strong,
.admin-panel-config-sections small {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.admin-panel-config-sections strong {
  color: var(--admin-text);
  font-size: calc(10 * var(--admin-unit));
  font-weight: 600;
}

.admin-panel-config-sections small,
.admin-panel-config-sections em {
  color: var(--admin-muted);
  font-size: calc(8 * var(--admin-unit));
  font-style: normal;
}

.admin-panel-config-sections em {
  min-width: calc(23 * var(--admin-unit));
  padding: calc(3 * var(--admin-unit)) calc(5 * var(--admin-unit));
  border-radius: calc(4 * var(--admin-unit));
  background: #1d201d;
  text-align: center;
}

.admin-panel-player-list > button {
  width: 100%;
  display: grid;
  grid-template-columns: calc(34 * var(--admin-unit)) minmax(0, 1fr) auto;
  align-items: center;
  gap: calc(10 * var(--admin-unit));
  padding: calc(9 * var(--admin-unit)) calc(9 * var(--admin-unit));
  border: 0;
  border-radius: calc(3 * var(--admin-unit));
  color: var(--admin-text);
  background: transparent;
  text-align: left;
  cursor: pointer;
}

.admin-panel-player-list > button:hover {
  background: var(--admin-row-hover);
}

.admin-panel-player-list > button.is-active {
  background: var(--admin-row-active);
  box-shadow: inset calc(2 * var(--admin-unit)) 0 var(--admin-green);
}

.admin-panel-avatar,
.admin-panel-profile-avatar {
  display: grid;
  place-items: center;
  flex: 0 0 auto;
  border: 0;
  border-radius: calc(7 * var(--admin-unit));
  color: #c7e8c4;
  background: linear-gradient(145deg, #263126, #182018);
  font-size: calc(10 * var(--admin-unit));
  font-weight: 700;
}

.admin-panel-avatar {
  width: calc(32 * var(--admin-unit));
  height: calc(32 * var(--admin-unit));
}

.admin-panel-player-list__copy {
  display: grid;
  min-width: 0;
  gap: calc(2 * var(--admin-unit));
}

.admin-panel-player-list__copy strong,
.admin-panel-player-list__copy small {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.admin-panel-player-list__copy strong {
  font-size: calc(11 * var(--admin-unit));
  font-weight: 580;
}

.admin-panel-player-list__copy small,
.admin-panel-player-list__meta {
  color: var(--admin-muted);
  font-size: calc(9 * var(--admin-unit));
}

.admin-panel-player-list__meta {
  display: flex;
  align-items: center;
  gap: calc(6 * var(--admin-unit));
}

.admin-panel-empty-list,
.admin-panel-empty-editor,
.admin-panel-loading {
  display: grid;
  place-items: center;
  align-content: center;
  text-align: center;
}

.admin-panel-empty-list {
  gap: calc(5 * var(--admin-unit));
  padding: calc(40 * var(--admin-unit)) calc(22 * var(--admin-unit));
  color: var(--admin-muted);
}

.admin-panel-empty-list strong {
  color: var(--admin-text);
  font-size: calc(12 * var(--admin-unit));
}

.admin-panel-empty-list span {
  font-size: calc(10 * var(--admin-unit));
  line-height: 1.5;
}

.admin-panel-audit-mini-list {
  height: calc(100% - calc(62 * var(--admin-unit)));
  padding-inline: calc(10 * var(--admin-unit));
}

.admin-panel-audit-mini-list article {
  display: grid;
  grid-template-columns: calc(28 * var(--admin-unit)) 1fr;
  gap: calc(9 * var(--admin-unit));
  padding: calc(10 * var(--admin-unit)) calc(5 * var(--admin-unit));
  border-radius: calc(3 * var(--admin-unit));
}

.admin-panel-audit-mini-list article:hover {
  background: var(--admin-row-hover);
}

.admin-panel-tone-directory {
  display: grid;
  gap: calc(1 * var(--admin-unit));
  margin-top: calc(8 * var(--admin-unit));
  background: var(--admin-border);
}

.admin-panel-tone-directory article {
  min-height: calc(52 * var(--admin-unit));
  display: grid;
  grid-template-columns: calc(30 * var(--admin-unit)) minmax(0, 1fr);
  align-items: center;
  gap: calc(9 * var(--admin-unit));
  padding: calc(8 * var(--admin-unit)) calc(10 * var(--admin-unit));
  background: #111311;
}

.admin-panel-tone-directory article > span {
  width: calc(30 * var(--admin-unit));
  height: calc(30 * var(--admin-unit));
  display: grid;
  place-items: center;
  border-radius: calc(5 * var(--admin-unit));
  color: var(--admin-accent);
  background: var(--admin-green-soft);
}

.admin-panel-tone-directory article > div {
  display: grid;
  gap: calc(3 * var(--admin-unit));
}

.admin-panel-tone-directory strong {
  font-size: calc(10 * var(--admin-unit));
}

.admin-panel-tone-directory small {
  color: var(--admin-muted);
  font-size: calc(9 * var(--admin-unit));
}

.admin-panel-audit-icon {
  width: calc(27 * var(--admin-unit));
  height: calc(27 * var(--admin-unit));
  display: grid;
  place-items: center;
  border-radius: calc(5 * var(--admin-unit));
  color: var(--admin-green);
  background: var(--admin-green-soft);
}

.admin-panel-audit-mini-list div {
  display: grid;
  gap: calc(2 * var(--admin-unit));
  min-width: 0;
}

.admin-panel-audit-mini-list strong {
  font-size: calc(10 * var(--admin-unit));
}

.admin-panel-audit-mini-list span,
.admin-panel-audit-mini-list small {
  color: var(--admin-muted);
  font-size: calc(9 * var(--admin-unit));
}

.admin-panel-editor {
  min-width: 0;
  overflow: hidden;
  background: #0b0d0c;
}

.admin-panel-editor__scroll {
  height: 100%;
  overflow-y: auto;
  padding: calc(14 * var(--admin-unit));
  scrollbar-color: #343834 transparent;
  scrollbar-width: thin;
}

.admin-panel-loading,
.admin-panel-empty-editor {
  height: 100%;
  gap: calc(9 * var(--admin-unit));
  color: var(--admin-muted);
}

.admin-panel-profile-heading {
  gap: calc(13 * var(--admin-unit));
  min-height: calc(64 * var(--admin-unit));
  padding: calc(2 * var(--admin-unit)) calc(3 * var(--admin-unit))
    calc(12 * var(--admin-unit));
}

.admin-panel-profile-avatar {
  width: calc(42 * var(--admin-unit));
  height: calc(42 * var(--admin-unit));
  border-radius: calc(6 * var(--admin-unit));
  font-size: calc(12 * var(--admin-unit));
}

.admin-panel-profile-heading h1 {
  font-size: calc(18 * var(--admin-unit));
  letter-spacing: -0.025em;
}

.admin-panel-profile-heading p,
.admin-panel-section-card__heading p,
.admin-panel-page-heading p,
.admin-panel-empty-editor p,
.admin-panel-dialog p {
  margin: 0;
  color: var(--admin-muted);
  font-size: calc(10 * var(--admin-unit));
  line-height: 1.55;
}

.admin-panel-player-actions {
  display: flex;
  align-items: center;
  gap: calc(5 * var(--admin-unit));
  margin-left: auto;
}

.admin-panel-player-actions button {
  min-height: calc(38 * var(--admin-unit));
  display: flex;
  align-items: center;
  gap: calc(6 * var(--admin-unit));
  padding: 0 calc(9 * var(--admin-unit));
  border: calc(1 * var(--admin-unit)) solid var(--admin-border);
  border-radius: calc(5 * var(--admin-unit));
  color: #b9beb9;
  background: #181a18;
  font-size: calc(8 * var(--admin-unit));
  font-weight: 600;
  cursor: pointer;
}

.admin-panel-player-actions button:hover:not(:disabled) {
  border-color: var(--admin-border-strong);
  color: var(--admin-text);
  background: var(--admin-panel-hover);
}

.admin-panel-player-actions button.is-danger {
  border-color: rgba(239, 105, 105, 0.22);
  color: #efaaaa;
  background: rgba(239, 105, 105, 0.08);
}

.admin-panel-device-tabs {
  display: flex;
  gap: calc(6 * var(--admin-unit));
  overflow-x: auto;
  margin-bottom: calc(12 * var(--admin-unit));
  padding-bottom: calc(2 * var(--admin-unit));
}

.admin-panel-device-tabs button {
  min-width: calc(155 * var(--admin-unit));
  display: grid;
  grid-template-columns: calc(20 * var(--admin-unit)) 1fr;
  grid-template-rows: auto auto;
  align-items: center;
  gap: calc(1 * var(--admin-unit)) calc(7 * var(--admin-unit));
  padding: calc(8 * var(--admin-unit)) calc(10 * var(--admin-unit));
  border: 0;
  border-radius: calc(3 * var(--admin-unit));
  color: var(--admin-muted);
  background: #121412;
  text-align: left;
  cursor: pointer;
}

.admin-panel-device-tabs button svg {
  grid-row: 1 / 3;
}

.admin-panel-device-tabs button span {
  color: #c8cdc8;
  font-size: calc(10 * var(--admin-unit));
}

.admin-panel-device-tabs button small {
  font-size: calc(8 * var(--admin-unit));
}

.admin-panel-device-tabs button.is-active {
  color: var(--admin-green);
  background: var(--admin-row-active);
  box-shadow: inset calc(2 * var(--admin-unit)) 0 var(--admin-green);
}

.admin-panel-device-tabs button:hover:not(.is-active) {
  background: var(--admin-row-hover);
}

.admin-panel-device-tabs button.is-dirty::after {
  content: '';
  width: calc(5 * var(--admin-unit));
  height: calc(5 * var(--admin-unit));
  grid-column: 2;
  grid-row: 1 / 3;
  align-self: center;
  justify-self: end;
  border-radius: 50%;
  background: #d8aa5e;
}

.admin-panel-stat-grid,
.admin-panel-section-grid,
.admin-panel-security-grid,
.admin-panel-app-grid,
.admin-panel-audit-grid,
.admin-panel-empty-stats {
  display: grid;
  gap: calc(10 * var(--admin-unit));
}

.admin-panel-stat-grid {
  grid-template-columns: repeat(4, minmax(0, 1fr));
  margin-bottom: calc(10 * var(--admin-unit));
  gap: calc(2 * var(--admin-unit));
  overflow: hidden;
  border-radius: calc(3 * var(--admin-unit));
  background: transparent;
}

.admin-panel-stat-grid article {
  display: grid;
  grid-template-columns: calc(26 * var(--admin-unit)) 1fr;
  align-items: center;
  gap: calc(1 * var(--admin-unit)) calc(8 * var(--admin-unit));
  min-width: 0;
  padding: calc(10 * var(--admin-unit)) calc(12 * var(--admin-unit));
  border: 0;
  border-right: 0;
  border-radius: 0;
  background: var(--admin-panel);
}

.admin-panel-stat-grid svg {
  grid-row: 1 / 3;
  color: var(--admin-muted);
}

.admin-panel-stat-grid span {
  color: var(--admin-muted);
  font-size: calc(8 * var(--admin-unit));
  text-transform: uppercase;
}

.admin-panel-stat-grid strong {
  overflow: hidden;
  font-size: calc(12 * var(--admin-unit));
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.admin-panel-section-grid {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.admin-panel-section-card {
  margin-bottom: calc(10 * var(--admin-unit));
  padding: calc(13 * var(--admin-unit));
  border: 0;
  border-radius: calc(3 * var(--admin-unit));
  background: #0f110f;
}

.admin-panel-section-card--compact {
  padding: calc(11 * var(--admin-unit)) calc(12 * var(--admin-unit));
}

.admin-panel-section-card--focused {
  min-height: calc(210 * var(--admin-unit));
}

.admin-panel-feature-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: calc(8 * var(--admin-unit));
}

.admin-panel-statistics-layout {
  display: grid;
  grid-template-columns: minmax(0, 0.9fr) minmax(0, 1.1fr);
  gap: calc(8 * var(--admin-unit));
}

.admin-panel-activity-statistics,
.admin-panel-coverage-statistics {
  min-width: 0;
  padding: calc(10 * var(--admin-unit));
  border-radius: calc(3 * var(--admin-unit));
  background: #0b0d0c;
}

.admin-panel-statistics-heading {
  margin-bottom: calc(9 * var(--admin-unit));
}

.admin-panel-statistics-heading > div {
  display: grid;
  gap: calc(2 * var(--admin-unit));
}

.admin-panel-statistics-heading strong {
  color: #d9ddd9;
  font-size: calc(9 * var(--admin-unit));
  font-weight: 600;
}

.admin-panel-statistics-heading small {
  color: var(--admin-muted);
  font-size: calc(8 * var(--admin-unit));
  line-height: 1.35;
}

.admin-panel-activity-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: calc(3 * var(--admin-unit));
}

.admin-panel-activity-grid article {
  min-width: 0;
  display: grid;
  grid-template-columns: calc(20 * var(--admin-unit)) minmax(0, 1fr);
  align-items: center;
  gap: calc(2 * var(--admin-unit)) calc(6 * var(--admin-unit));
  padding: calc(10 * var(--admin-unit));
  background: #121412;
}

.admin-panel-activity-grid svg {
  color: var(--admin-green);
}

.admin-panel-activity-grid strong {
  overflow: hidden;
  font-size: calc(13 * var(--admin-unit));
  font-weight: 620;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.admin-panel-activity-grid span {
  grid-column: 1 / -1;
  overflow: hidden;
  color: var(--admin-muted);
  font-size: calc(7 * var(--admin-unit));
  text-overflow: ellipsis;
  text-transform: uppercase;
  white-space: nowrap;
}

.admin-panel-coverage-list {
  display: grid;
  gap: calc(8 * var(--admin-unit));
}

.admin-panel-coverage-list article {
  display: grid;
  gap: calc(5 * var(--admin-unit));
}

.admin-panel-coverage-list article > div:first-child {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: calc(10 * var(--admin-unit));
}

.admin-panel-coverage-list strong,
.admin-panel-coverage-list span {
  overflow: hidden;
  font-size: calc(8 * var(--admin-unit));
  text-overflow: ellipsis;
  white-space: nowrap;
}

.admin-panel-coverage-list strong {
  color: #d9ddd9;
  font-weight: 560;
}

.admin-panel-coverage-list span {
  color: var(--admin-muted);
}

.admin-panel-statistics-progress {
  height: calc(3 * var(--admin-unit));
  overflow: hidden;
  border-radius: calc(999 * var(--admin-unit));
  background: #1d201e;
}

.admin-panel-statistics-progress > span {
  height: 100%;
  display: block;
  border-radius: inherit;
  background: var(--admin-green);
  box-shadow: 0 0 calc(8 * var(--admin-unit))
    color-mix(in srgb, var(--admin-green) 52%, transparent);
  transition: width 180ms ease;
}

.admin-panel-section-card__heading {
  justify-content: space-between;
  gap: calc(12 * var(--admin-unit));
  margin-bottom: calc(12 * var(--admin-unit));
  padding-bottom: calc(10 * var(--admin-unit));
  border-bottom: calc(1 * var(--admin-unit)) solid var(--admin-border);
}

.admin-panel-section-card__heading h2 {
  font-size: calc(12 * var(--admin-unit));
}

.admin-panel-section-card__heading > svg {
  color: var(--admin-muted);
}

.admin-panel-field-list {
  display: grid;
  gap: calc(7 * var(--admin-unit));
  margin: 0;
}

.admin-panel-field-list > div {
  display: grid;
  grid-template-columns: minmax(calc(110 * var(--admin-unit)), 0.75fr) minmax(
      0,
      1.25fr
    );
  align-items: center;
  gap: calc(10 * var(--admin-unit));
}

.admin-panel-field-list dt {
  color: var(--admin-muted);
  font-size: calc(9 * var(--admin-unit));
}

.admin-panel-field-list dd {
  min-width: 0;
  overflow: hidden;
  margin: 0;
  padding: calc(7 * var(--admin-unit)) calc(9 * var(--admin-unit));
  border: calc(1 * var(--admin-unit)) solid var(--admin-border);
  border-radius: calc(5 * var(--admin-unit));
  color: #d8dcd8;
  background: #191b19;
  font-size: calc(9 * var(--admin-unit));
  text-overflow: ellipsis;
  white-space: nowrap;
}

.admin-panel-device-summary {
  gap: calc(9 * var(--admin-unit));
  margin-bottom: calc(10 * var(--admin-unit));
}

.admin-panel-device-summary__icon,
.admin-panel-heading-icon,
.admin-panel-empty-editor__icon {
  display: grid;
  place-items: center;
  border: calc(1 * var(--admin-unit)) solid
    color-mix(in srgb, var(--admin-green) 16%, transparent);
  color: var(--admin-green);
  background: var(--admin-green-soft);
}

.admin-panel-device-summary__icon {
  width: calc(38 * var(--admin-unit));
  height: calc(38 * var(--admin-unit));
  border-radius: calc(7 * var(--admin-unit));
}

.admin-panel-device-summary strong {
  font-size: calc(11 * var(--admin-unit));
}

.admin-panel-device-summary span,
.admin-panel-device-summary small {
  color: var(--admin-muted);
  font-size: calc(9 * var(--admin-unit));
}

.admin-panel-device-summary small {
  margin-left: auto;
  padding: calc(4 * var(--admin-unit)) calc(7 * var(--admin-unit));
  border-radius: calc(4 * var(--admin-unit));
  background: #1b1e1b;
}

.admin-panel-inline-empty {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: calc(8 * var(--admin-unit));
  padding: calc(18 * var(--admin-unit));
  color: var(--admin-muted);
  font-size: calc(10 * var(--admin-unit));
  text-align: center;
}

.admin-panel-security-grid {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.admin-panel-credential-box {
  position: relative;
  display: grid;
  align-content: center;
  min-height: calc(66 * var(--admin-unit));
  gap: calc(5 * var(--admin-unit));
  padding: calc(9 * var(--admin-unit)) calc(10 * var(--admin-unit));
  border: calc(1 * var(--admin-unit)) solid var(--admin-border);
  border-radius: calc(5 * var(--admin-unit));
  background: #181a18;
}

.admin-panel-credential-box > span,
.admin-panel-credential-box--pin div span {
  color: var(--admin-muted);
  font-size: calc(8 * var(--admin-unit));
  text-transform: uppercase;
}

.admin-panel-credential-box > strong,
.admin-panel-credential-box--pin strong {
  overflow: hidden;
  padding-right: calc(82 * var(--admin-unit));
  font-size: calc(10 * var(--admin-unit));
  font-weight: 550;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.admin-panel-credential-box button {
  position: absolute;
  right: calc(7 * var(--admin-unit));
  bottom: calc(8 * var(--admin-unit));
  display: flex;
  align-items: center;
  gap: calc(5 * var(--admin-unit));
  padding: calc(5 * var(--admin-unit)) calc(7 * var(--admin-unit));
  border: calc(1 * var(--admin-unit)) solid var(--admin-border-strong);
  border-radius: calc(4 * var(--admin-unit));
  color: #bbc0bb;
  background: #242724;
  font-size: calc(8 * var(--admin-unit));
  cursor: pointer;
  min-height: calc(44 * var(--admin-unit));
}

.admin-panel-password {
  font-family: ui-monospace, SFMono-Regular, Consolas, monospace;
  letter-spacing: 0.06em;
}

.admin-panel-credential-box--pin {
  grid-column: 1 / -1;
  grid-template-columns: calc(24 * var(--admin-unit)) 1fr;
  align-items: center;
  min-height: calc(46 * var(--admin-unit));
}

.admin-panel-credential-box--pin > svg {
  color: var(--admin-muted);
}

.admin-panel-credential-box--pin div {
  display: grid;
  gap: calc(3 * var(--admin-unit));
}

.admin-panel-credential-box--pin strong {
  padding: 0;
  color: #b8bdb8;
  font-size: calc(9 * var(--admin-unit));
}

.admin-panel-app-heading {
  align-items: flex-end;
}

.admin-panel-app-heading__actions {
  display: flex;
  align-items: center;
  gap: calc(10 * var(--admin-unit));
}

.admin-panel-app-heading__actions > span {
  color: #d8aa5e;
  font-size: calc(9 * var(--admin-unit));
}

.admin-panel-search--apps {
  width: calc(190 * var(--admin-unit));
  height: calc(44 * var(--admin-unit));
  margin: 0;
}

.admin-panel-manual-save-note {
  gap: calc(9 * var(--admin-unit));
  margin-bottom: calc(10 * var(--admin-unit));
  padding: calc(8 * var(--admin-unit)) calc(10 * var(--admin-unit));
  border: 0;
  border-radius: calc(5 * var(--admin-unit));
  color: var(--admin-green);
  background: color-mix(in srgb, var(--admin-green) 5.5%, transparent);
}

.admin-panel-manual-save-note strong {
  font-size: calc(9 * var(--admin-unit));
}

.admin-panel-manual-save-note span {
  color: #849184;
  font-size: calc(8 * var(--admin-unit));
}

.admin-panel-app-grid {
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

.admin-panel-app-grid > button {
  display: grid;
  grid-template-columns: calc(32 * var(--admin-unit)) minmax(0, 1fr) auto;
  align-items: center;
  gap: calc(8 * var(--admin-unit));
  min-width: 0;
  padding: calc(8 * var(--admin-unit));
  border: 0;
  border-radius: calc(3 * var(--admin-unit));
  color: var(--admin-text);
  background: #161816;
  text-align: left;
  cursor: pointer;
}

.admin-panel-app-grid > button:hover:not(:disabled) {
  background: var(--admin-row-hover);
}

.admin-panel-app-grid > button.is-dirty {
  background: linear-gradient(
    90deg,
    rgba(216, 170, 94, 0.19) 0%,
    rgba(216, 170, 94, 0.04) 52%,
    transparent 100%
  );
  box-shadow: inset calc(2 * var(--admin-unit)) 0 #d8aa5e;
}

.admin-panel-app-icon {
  width: calc(30 * var(--admin-unit));
  height: calc(30 * var(--admin-unit));
  display: grid;
  place-items: center;
  border-radius: calc(7 * var(--admin-unit));
  color: white;
  background: #292c29;
}

.admin-panel-app-copy {
  display: grid;
  min-width: 0;
  gap: calc(2 * var(--admin-unit));
}

.admin-panel-app-copy strong,
.admin-panel-app-copy small {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.admin-panel-app-copy strong {
  font-size: calc(9 * var(--admin-unit));
  font-weight: 550;
}

.admin-panel-app-copy small {
  color: var(--admin-muted);
  font-size: calc(8 * var(--admin-unit));
}

.admin-panel-switch {
  width: calc(27 * var(--admin-unit));
  height: calc(15 * var(--admin-unit));
  padding: calc(2 * var(--admin-unit));
  border-radius: calc(999 * var(--admin-unit));
  background: #353935;
  transition: background 150ms ease;
}

.admin-panel-switch span {
  width: calc(11 * var(--admin-unit));
  height: calc(11 * var(--admin-unit));
  display: block;
  border-radius: 50%;
  background: #c8cdc8;
  transition: transform 150ms ease;
}

.admin-panel-app-grid > button.is-enabled .admin-panel-switch {
  background: var(--admin-green);
}

.admin-panel-app-grid > button.is-enabled .admin-panel-switch span {
  transform: translateX(calc(12 * var(--admin-unit)));
  background: #0b100b;
}

.admin-panel-activity-list {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: calc(2 * var(--admin-unit));
  overflow: hidden;
  border: 0;
  border-radius: calc(3 * var(--admin-unit));
}

.admin-panel-activity-list article {
  display: grid;
  grid-template-columns: calc(34 * var(--admin-unit)) minmax(0, 1fr);
  align-items: center;
  gap: calc(9 * var(--admin-unit));
  min-width: 0;
  padding: calc(9 * var(--admin-unit)) calc(10 * var(--admin-unit));
  border: 0;
  border-bottom: 0;
  border-radius: calc(3 * var(--admin-unit));
  background: #141614;
}

.admin-panel-activity-list article:hover {
  background: var(--admin-row-hover);
}

.admin-panel-activity-icon {
  width: calc(32 * var(--admin-unit));
  height: calc(32 * var(--admin-unit));
  display: grid;
  place-items: center;
  border-radius: calc(6 * var(--admin-unit));
  color: var(--admin-green);
  background: var(--admin-green-soft);
}

.admin-panel-activity-list article > div {
  display: grid;
  min-width: 0;
  gap: calc(3 * var(--admin-unit));
}

.admin-panel-activity-list strong,
.admin-panel-activity-list small,
.admin-panel-activity-meta {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.admin-panel-activity-list strong {
  font-size: calc(10 * var(--admin-unit));
  font-weight: 550;
}

.admin-panel-activity-list small,
.admin-panel-activity-meta {
  color: var(--admin-muted);
  font-size: calc(8 * var(--admin-unit));
}

.admin-panel-moderation-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: calc(8 * var(--admin-unit));
}

.admin-panel-moderation-grid button {
  min-height: calc(84 * var(--admin-unit));
  display: grid;
  grid-template-columns: calc(28 * var(--admin-unit)) minmax(0, 1fr) auto;
  align-items: center;
  gap: calc(9 * var(--admin-unit));
  padding: calc(11 * var(--admin-unit));
  border: calc(1 * var(--admin-unit)) solid var(--admin-border);
  border-radius: calc(5 * var(--admin-unit));
  color: var(--admin-green);
  background: #161816;
  text-align: left;
  cursor: pointer;
}

.admin-panel-moderation-grid button:hover:not(:disabled) {
  border-color: color-mix(in srgb, var(--admin-green) 30%, transparent);
  background: var(--admin-green-soft);
}

.admin-panel-moderation-grid button > span {
  display: grid;
  min-width: 0;
  gap: calc(4 * var(--admin-unit));
}

.admin-panel-moderation-grid strong {
  color: var(--admin-text);
  font-size: calc(10 * var(--admin-unit));
}

.admin-panel-moderation-grid small {
  color: var(--admin-muted);
  font-size: calc(8 * var(--admin-unit));
  line-height: 1.4;
}

.admin-panel-moderation-grid button.is-danger {
  border-color: rgba(239, 105, 105, 0.22);
  color: #ef6969;
  background: rgba(239, 105, 105, 0.07);
}

.admin-panel-page-heading {
  display: flex;
  align-items: center;
  gap: calc(12 * var(--admin-unit));
  margin-bottom: calc(12 * var(--admin-unit));
  padding: calc(2 * var(--admin-unit)) 0;
}

.admin-panel-config-heading-copy {
  display: grid;
  gap: calc(2 * var(--admin-unit));
}

.admin-panel-config-disabled,
.admin-panel-config-notice {
  display: grid;
  grid-template-columns: calc(26 * var(--admin-unit)) minmax(0, 1fr);
  align-items: start;
  gap: calc(9 * var(--admin-unit));
  margin-bottom: calc(8 * var(--admin-unit));
  padding: calc(10 * var(--admin-unit)) calc(11 * var(--admin-unit));
  border-radius: calc(3 * var(--admin-unit));
  background: linear-gradient(90deg, rgba(240, 162, 75, 0.13), transparent 80%);
}

.admin-panel-config-notice {
  background: linear-gradient(
    90deg,
    color-mix(in srgb, var(--admin-green) 11%, transparent),
    transparent 82%
  );
}

.admin-panel-config-disabled > svg {
  color: #f0a24b;
}

.admin-panel-config-notice > svg {
  color: var(--admin-green);
}

.admin-panel-config-disabled div,
.admin-panel-config-notice div {
  display: grid;
  gap: calc(3 * var(--admin-unit));
}

.admin-panel-config-disabled strong,
.admin-panel-config-notice strong {
  font-size: calc(10 * var(--admin-unit));
}

.admin-panel-config-disabled p,
.admin-panel-config-notice p {
  margin: 0;
  color: var(--admin-muted);
  font-size: calc(9 * var(--admin-unit));
  line-height: 1.45;
}

.admin-panel-config-disabled code {
  width: fit-content;
  margin-top: calc(3 * var(--admin-unit));
  padding: calc(4 * var(--admin-unit)) calc(6 * var(--admin-unit));
  border-radius: calc(3 * var(--admin-unit));
  color: #f6c889;
  background: rgba(0, 0, 0, 0.25);
  font-size: calc(9 * var(--admin-unit));
}

.admin-panel-config-workspace {
  margin-top: calc(10 * var(--admin-unit));
  overflow: hidden;
  border-radius: calc(3 * var(--admin-unit));
  background: #111311;
}

.admin-panel-config-workspace > header {
  min-height: calc(52 * var(--admin-unit));
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: calc(12 * var(--admin-unit));
  padding: calc(9 * var(--admin-unit)) calc(12 * var(--admin-unit));
  background: #171917;
}

.admin-panel-config-workspace > header > div {
  display: grid;
  gap: calc(2 * var(--admin-unit));
}

.admin-panel-config-workspace > header span,
.admin-panel-config-workspace > header > strong {
  color: var(--admin-muted);
  font-size: calc(8 * var(--admin-unit));
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.admin-panel-config-workspace h2 {
  margin: 0;
  font-size: calc(13 * var(--admin-unit));
  font-weight: 600;
}

.admin-panel-config-fields {
  display: grid;
  gap: calc(1 * var(--admin-unit));
  background: #0b0d0c;
}

.admin-panel-config-field {
  min-height: calc(51 * var(--admin-unit));
  display: grid;
  grid-template-columns: minmax(calc(220 * var(--admin-unit)), 0.9fr) minmax(
      calc(210 * var(--admin-unit)),
      1.1fr
    );
  align-items: center;
  gap: calc(14 * var(--admin-unit));
  padding: calc(8 * var(--admin-unit)) calc(12 * var(--admin-unit));
  background: #121412;
}

.admin-panel-config-field.is-structured {
  grid-template-columns: minmax(0, 1fr);
  align-items: stretch;
  gap: calc(7 * var(--admin-unit));
}

.admin-panel-config-field:hover {
  background: var(--admin-row-hover);
}

.admin-panel-config-field.is-dirty {
  background: var(--admin-row-active);
  box-shadow: inset calc(2 * var(--admin-unit)) 0 var(--admin-green);
}

.admin-panel-config-field__copy {
  display: grid;
  min-width: 0;
  gap: calc(3 * var(--admin-unit));
}

.admin-panel-config-field__copy strong,
.admin-panel-config-field__copy small,
.admin-panel-config-field__copy code {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.admin-panel-config-field__copy strong {
  font-size: calc(10 * var(--admin-unit));
  font-weight: 600;
}

.admin-panel-config-field__copy small {
  color: var(--admin-muted);
  font-size: calc(8 * var(--admin-unit));
  line-height: 1.25;
}

.admin-panel-config-field__copy code {
  color: var(--admin-dim);
  font-family: ui-monospace, SFMono-Regular, Consolas, monospace;
  font-size: calc(7 * var(--admin-unit));
}

.admin-panel-config-field > input,
.admin-panel-config-optional > input {
  max-width: 100%;
  min-width: 0;
  border: 0;
  border-radius: calc(4 * var(--admin-unit));
  outline: calc(1 * var(--admin-unit)) solid rgba(255, 255, 255, 0.07);
  color: var(--admin-text);
  background: #1b1e1b;
  font: inherit;
  font-size: calc(10 * var(--admin-unit));
}

.admin-panel-config-field > input {
  justify-self: start;
}

.admin-panel-config-field > input[type='number'] {
  appearance: textfield;
}

.admin-panel-config-field > input[type='number']::-webkit-inner-spin-button,
.admin-panel-config-field > input[type='number']::-webkit-outer-spin-button {
  margin: 0;
  appearance: none;
}

.admin-panel-config-field > input,
.admin-panel-config-optional > input {
  height: calc(31 * var(--admin-unit));
  padding: 0 calc(9 * var(--admin-unit));
}

.admin-panel-config-field > input:focus,
.admin-panel-config-optional > input:focus {
  outline-color: color-mix(in srgb, var(--admin-green) 45%, transparent);
}

.admin-panel-config-field > input:disabled,
.admin-panel-config-optional > input:disabled {
  opacity: 0.45;
}

.admin-panel-config-optional {
  min-width: 0;
  max-width: 100%;
  display: flex;
  align-items: center;
  justify-self: start;
  gap: calc(8 * var(--admin-unit));
}

.admin-panel-config-toggle {
  position: relative;
  justify-self: start;
  width: calc(32 * var(--admin-unit));
  height: calc(18 * var(--admin-unit));
}

.admin-panel-config-toggle input {
  position: absolute;
  inset: 0;
  z-index: 1;
  margin: 0;
  opacity: 0;
  cursor: pointer;
}

.admin-panel-config-toggle i {
  position: absolute;
  inset: 0;
  border-radius: calc(999 * var(--admin-unit));
  background: #393d39;
  transition: background 150ms ease;
}

.admin-panel-config-toggle i::after {
  content: '';
  position: absolute;
  top: calc(3 * var(--admin-unit));
  left: calc(3 * var(--admin-unit));
  width: calc(12 * var(--admin-unit));
  height: calc(12 * var(--admin-unit));
  border-radius: 50%;
  background: #c7ccc7;
  transition: transform 150ms ease;
}

.admin-panel-config-toggle input:checked + i {
  background: var(--admin-toggle-on);
}

.admin-panel-config-toggle input:checked + i::after {
  transform: translateX(calc(14 * var(--admin-unit)));
  background: #f4f7f4;
}

.admin-panel-config-toggle input:disabled + i {
  opacity: 0.45;
}

.admin-panel-heading-icon,
.admin-panel-empty-editor__icon {
  width: calc(44 * var(--admin-unit));
  height: calc(44 * var(--admin-unit));
  border-radius: calc(8 * var(--admin-unit));
}

.admin-panel-page-heading h1,
.admin-panel-empty-editor h1 {
  font-size: calc(17 * var(--admin-unit));
}

.admin-panel-audit-grid {
  grid-template-columns: minmax(0, 1fr);
  gap: calc(2 * var(--admin-unit));
  overflow: hidden;
  border: 0;
  border-radius: calc(3 * var(--admin-unit));
}

.admin-panel-audit-grid article {
  display: grid;
  gap: calc(5 * var(--admin-unit));
  padding: calc(10 * var(--admin-unit)) calc(11 * var(--admin-unit));
  border: 0;
  border-bottom: 0;
  border-radius: calc(3 * var(--admin-unit));
  background: #141614;
}

.admin-panel-audit-grid article:hover {
  background: var(--admin-row-hover);
}

.admin-panel-audit-grid__topline {
  display: flex;
  justify-content: space-between;
  gap: calc(10 * var(--admin-unit));
  color: var(--admin-green);
  font-size: calc(9 * var(--admin-unit));
}

.admin-panel-audit-grid time,
.admin-panel-audit-grid p {
  color: var(--admin-muted);
  font-size: calc(8 * var(--admin-unit));
}

.admin-panel-audit-grid strong {
  font-size: calc(11 * var(--admin-unit));
}

.admin-panel-empty-editor {
  padding: calc(30 * var(--admin-unit));
}

.admin-panel-empty-editor > p {
  max-width: calc(430 * var(--admin-unit));
}

.admin-panel-empty-stats {
  grid-template-columns: repeat(3, calc(130 * var(--admin-unit)));
  margin-top: calc(14 * var(--admin-unit));
}

.admin-panel-empty-stats article {
  display: grid;
  grid-template-columns: calc(28 * var(--admin-unit)) 1fr;
  align-items: center;
  padding: calc(10 * var(--admin-unit));
  border: calc(1 * var(--admin-unit)) solid var(--admin-border);
  border-radius: calc(6 * var(--admin-unit));
  background: var(--admin-panel);
  text-align: left;
}

.admin-panel-empty-stats svg {
  grid-row: 1 / 3;
  color: var(--admin-muted);
}

.admin-panel-empty-stats strong {
  font-size: calc(13 * var(--admin-unit));
}

.admin-panel-empty-stats span {
  color: var(--admin-muted);
  font-size: calc(8 * var(--admin-unit));
}

.admin-panel-toast {
  position: fixed;
  z-index: 10002;
  right: 4vw;
  bottom: 4vh;
  display: flex;
  align-items: center;
  gap: calc(8 * var(--admin-unit));
  max-width: calc(390 * var(--admin-unit));
  padding: calc(10 * var(--admin-unit)) calc(13 * var(--admin-unit));
  border: calc(1 * var(--admin-unit)) solid
    color-mix(in srgb, var(--admin-green) 25%, transparent);
  border-radius: calc(6 * var(--admin-unit));
  color: #d7ecd5;
  background: #152015;
  box-shadow: 0 calc(16 * var(--admin-unit)) calc(40 * var(--admin-unit))
    rgba(0, 0, 0, 0.45);
  font-size: calc(10 * var(--admin-unit));
}

.admin-panel-toast.is-error {
  border-color: rgba(239, 105, 105, 0.3);
  color: #f2c4c4;
  background: #241414;
}

.admin-panel-dialog-backdrop {
  position: fixed;
  z-index: 10001;
  inset: 0;
  display: grid;
  place-items: center;
  background: rgba(0, 0, 0, 0.66);
  backdrop-filter: blur(calc(3 * var(--admin-unit)));
}

.admin-panel-dialog {
  width: min(calc(420 * var(--admin-unit)), 90vw);
  display: grid;
  grid-template-columns: calc(38 * var(--admin-unit)) 1fr;
  gap: calc(12 * var(--admin-unit));
  padding: calc(16 * var(--admin-unit));
  border: calc(1 * var(--admin-unit)) solid var(--admin-border-strong);
  border-radius: calc(8 * var(--admin-unit));
  background: #121412;
  box-shadow: 0 calc(25 * var(--admin-unit)) calc(75 * var(--admin-unit))
    rgba(0, 0, 0, 0.65);
}

.admin-panel-dialog__icon {
  width: calc(36 * var(--admin-unit));
  height: calc(36 * var(--admin-unit));
  display: grid;
  place-items: center;
  border-radius: calc(7 * var(--admin-unit));
  color: var(--admin-green);
  background: var(--admin-green-soft);
}

.admin-panel-dialog__icon.is-warning {
  color: #e0ad5f;
  background: rgba(224, 173, 95, 0.12);
}

.admin-panel-dialog h2 {
  margin-bottom: calc(5 * var(--admin-unit));
  font-size: calc(14 * var(--admin-unit));
}

.admin-panel-dialog__actions {
  grid-column: 1 / -1;
  justify-content: flex-end;
  gap: calc(7 * var(--admin-unit));
  margin-top: calc(5 * var(--admin-unit));
}

.admin-panel-action-input {
  grid-column: 1 / -1;
  display: grid;
  gap: calc(6 * var(--admin-unit));
}

.admin-panel-action-input span {
  color: var(--admin-muted);
  font-size: calc(9 * var(--admin-unit));
}

.admin-panel-action-input input {
  width: 100%;
  height: calc(44 * var(--admin-unit));
  padding: 0 calc(11 * var(--admin-unit));
  border: calc(1 * var(--admin-unit)) solid var(--admin-border-strong);
  border-radius: calc(5 * var(--admin-unit));
  outline: 0;
  color: var(--admin-text);
  background: #1a1c1a;
  font: inherit;
  font-size: calc(10 * var(--admin-unit));
}

.admin-panel-action-input input:focus {
  border-color: color-mix(in srgb, var(--admin-green) 45%, transparent);
}

.admin-panel-dialog__actions button {
  display: flex;
  align-items: center;
  gap: calc(6 * var(--admin-unit));
  padding: calc(7 * var(--admin-unit)) calc(10 * var(--admin-unit));
  border: calc(1 * var(--admin-unit)) solid var(--admin-border-strong);
  border-radius: calc(5 * var(--admin-unit));
  color: #c6cbc6;
  background: #202320;
  font-size: calc(9 * var(--admin-unit));
  cursor: pointer;
}

.admin-panel-overlay button:focus-visible,
.admin-panel-overlay input:focus-visible {
  outline: calc(2 * var(--admin-unit)) solid var(--admin-green);
  outline-offset: calc(2 * var(--admin-unit));
}

.admin-panel-overlay .admin-panel-rail button:focus-visible {
  outline: 0;
  box-shadow: inset 0 0 0 calc(1 * var(--admin-unit)) rgba(255, 255, 255, 0.13);
}

.admin-panel-dialog__actions button.is-primary {
  border-color: color-mix(in srgb, var(--admin-green) 30%, transparent);
  color: #d9eed7;
  background: var(--admin-green-soft);
}

.admin-panel-dialog__actions button.is-danger {
  border-color: rgba(239, 105, 105, 0.3);
  color: #efaaaa;
  background: rgba(239, 105, 105, 0.1);
}

.is-spinning {
  animation: admin-spin 800ms linear infinite;
}

.admin-toast-enter-active,
.admin-toast-leave-active {
  transition:
    opacity 160ms ease,
    transform 160ms ease;
}

.admin-toast-enter-from,
.admin-toast-leave-to {
  opacity: 0;
  transform: translateY(calc(8 * var(--admin-unit)));
}

@keyframes admin-spin {
  to {
    transform: rotate(360deg);
  }
}

@media (max-width: 1100px) {
  .admin-panel-window {
    width: 97vw;
    height: 94vh;
  }

  .admin-panel-body {
    grid-template-columns:
      calc(50 * var(--admin-unit)) calc(250 * var(--admin-unit))
      minmax(0, 1fr);
  }

  .admin-panel-header {
    grid-template-columns: calc(225 * var(--admin-unit)) 1fr auto;
  }

  .admin-panel-stat-grid,
  .admin-panel-app-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (prefers-reduced-motion: reduce) {
  .admin-panel-overlay *,
  .admin-panel-overlay *::before,
  .admin-panel-overlay *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
</style>
