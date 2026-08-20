<script setup lang="ts">
import {
  BadgeDollarSign,
  Check,
  ChevronRight,
  CircleUserRound,
  Clipboard,
  Database,
  HardDrive,
  KeyRound,
  LockKeyhole,
  RefreshCw,
  SearchX,
  ShieldCheck,
  ShieldEllipsis,
  Smartphone,
  UserRoundCog,
  UsersRound,
  Wifi,
} from 'lucide-vue-next'
import { computed, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'

import {
  DEFAULT_INSTALLED_PHONE_APP_IDS,
  getPhoneApp,
  getPhoneAppLabel,
  isExternalPhoneApp,
  isLaunchablePhoneApp,
  isPhoneAppRemovable,
  PHONE_APPS,
} from '@/config/apps'
import { useAdminStore } from '@/stores/admin'
import { usePhoneStore } from '@/stores/phone'
import type { AdminAuditEntry, AdminDevice } from '@/types/admin'
import type { LaunchablePhoneAppDefinition } from '@/types/apps'
import {
  SkyAppPage,
  SkyButton,
  SkyCard,
  SkyDialog,
  SkyDialogButton,
  SkyEmptyState,
  SkyNavbar,
  SkyScrollArea,
  SkySearchbar,
  SkySpinner,
} from '@/ui'
import { copyText } from '@/utils/clipboard'
import { parseDatabaseDate } from '@/utils/date'

type AdminTab = 'players' | 'audit'

const admin = useAdminStore()
const phone = usePhoneStore()
const router = useRouter()
const tab = ref<AdminTab>('players')
const playerQuery = ref('')
const appQuery = ref('')
const selectedImei = ref('')
const revealDialogImei = ref('')
const toast = ref('')
let toastTimer: number | undefined

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
      isLaunchablePhoneApp(app) && !app.adminOnly,
  )
    .filter((app) => {
      if (!needle) return true
      return getPhoneAppLabel(app, phone.t)
        .toLocaleLowerCase(phone.lang)
        .includes(needle)
    })
    .sort((left, right) => {
      const leftInstalled = selectedDevice.value
        ? isInstalled(selectedDevice.value, left)
        : false
      const rightInstalled = selectedDevice.value
        ? isInstalled(selectedDevice.value, right)
        : false
      if (leftInstalled !== rightInstalled) return leftInstalled ? -1 : 1
      return getPhoneAppLabel(left, phone.t).localeCompare(
        getPhoneAppLabel(right, phone.t),
        phone.lang,
      )
    })
})

const revealedCredential = computed(() =>
  selectedDevice.value
    ? admin.revealedCredentials[selectedDevice.value.imei]
    : undefined,
)

watch(
  () => admin.selectedPlayer,
  (player) => {
    if (!player?.devices.some((device) => device.imei === selectedImei.value)) {
      selectedImei.value = player?.devices[0]?.imei ?? ''
    }
  },
)

function t(key: string, params?: Record<string, string>): string {
  return phone.t('Apps.admin.' + key, params)
}

function showToast(message: string): void {
  if (toastTimer) window.clearTimeout(toastTimer)
  toast.value = message
  toastTimer = window.setTimeout(() => (toast.value = ''), 2600)
}

function formatMoney(value: number): string {
  return new Intl.NumberFormat(phone.lang, {
    maximumFractionDigits: 0,
  }).format(value)
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

function isInstalled(
  device: AdminDevice,
  app: LaunchablePhoneAppDefinition,
): boolean {
  if (device.apps.uninstalled.includes(app.id)) return false
  if (device.apps.claimed.includes(app.id)) return true
  return isExternalPhoneApp(app)
    ? app.defaultInstalled
    : DEFAULT_INSTALLED_PHONE_APP_IDS.has(app.id)
}

function errorText(error = admin.error): string {
  return t('errors.' + (error || 'default'))
}

async function openPlayer(source: number): Promise<void> {
  if (await admin.openPlayer(source)) return
  showToast(errorText())
}

async function toggleApp(app: LaunchablePhoneAppDefinition): Promise<void> {
  const player = admin.selectedPlayer
  const device = selectedDevice.value
  if (!player || !device) return
  const installed = isInstalled(device, app)
  const response = await admin.setApp(
    player.source,
    device.imei,
    app.id,
    !installed,
  )
  if (!response.success) {
    showToast(errorText(response.error))
    return
  }
  showToast(t(installed ? 'apps.revoked' : 'apps.granted'))
}

async function revealPassword(): Promise<void> {
  const player = admin.selectedPlayer
  const imei = revealDialogImei.value
  revealDialogImei.value = ''
  if (!player || !imei) return
  const response = await admin.revealPassword(player.source, imei)
  if (!response.success) showToast(errorText(response.error))
}

async function copyPassword(): Promise<void> {
  if (!revealedCredential.value) return
  if (await copyText(revealedCredential.value.password)) {
    showToast(t('credentials.copied'))
  }
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

async function refresh(): Promise<void> {
  if (!(await admin.load())) showToast(errorText())
}

function closeDetail(): void {
  admin.closePlayer()
  selectedImei.value = ''
  appQuery.value = ''
}

onMounted(() => {
  if (!phone.permissions.adminPanel) {
    void router.replace('/')
    return
  }
  void refresh()
})
</script>

<template>
  <SkyAppPage
    dark
    accent="#8b7bff"
    accent-soft="rgba(139, 123, 255, 0.2)"
    class="admin-page"
    :label="t('name')"
  >
    <template v-if="admin.selectedPlayer">
      <SkyNavbar
        :back-label="t('players.title')"
        show-back
        :subtitle="'ID ' + admin.selectedPlayer.source"
        :title="admin.selectedPlayer.name"
        @back="closeDetail"
      />

      <SkyScrollArea padded class="admin-scroll admin-detail-scroll">
        <section class="admin-identity-card">
          <div class="admin-avatar admin-avatar--large" aria-hidden="true">
            <CircleUserRound :size="34" />
          </div>
          <div>
            <span class="admin-kicker">{{ t('detail.character') }}</span>
            <h2>{{ admin.selectedPlayer.name }}</h2>
            <p>{{ admin.selectedPlayer.serverName }}</p>
          </div>
          <span class="admin-live-dot" :aria-label="t('players.online')"></span>
        </section>

        <section class="admin-info-grid" :aria-label="t('detail.data')">
          <SkyCard>
            <BadgeDollarSign :size="18" />
            <span>{{ t('detail.cash') }}</span>
            <strong>{{
              '$' + formatMoney(admin.selectedPlayer.money.cash)
            }}</strong>
          </SkyCard>
          <SkyCard>
            <Database :size="18" />
            <span>{{ t('detail.bank') }}</span>
            <strong>{{
              '$' + formatMoney(admin.selectedPlayer.money.bank)
            }}</strong>
          </SkyCard>
          <SkyCard>
            <UserRoundCog :size="18" />
            <span>{{ t('detail.job') }}</span>
            <strong>{{
              admin.selectedPlayer.job.label || admin.selectedPlayer.job.name
            }}</strong>
          </SkyCard>
          <SkyCard>
            <Wifi :size="18" />
            <span>{{ t('detail.duty') }}</span>
            <strong>{{
              admin.selectedPlayer.job.onDuty
                ? t('detail.onDuty')
                : t('detail.offDuty')
            }}</strong>
          </SkyCard>
        </section>

        <section class="admin-data-panel">
          <div class="admin-section-heading">
            <div>
              <span>{{ t('detail.identity') }}</span>
              <h2>{{ t('detail.playerData') }}</h2>
            </div>
            <ShieldCheck :size="22" />
          </div>
          <dl class="admin-data-list">
            <div>
              <dt>{{ t('detail.identifier') }}</dt>
              <dd>{{ admin.selectedPlayer.identifier }}</dd>
            </div>
            <div>
              <dt>{{ t('detail.birthdate') }}</dt>
              <dd>
                {{ admin.selectedPlayer.birthdate || t('detail.unknown') }}
              </dd>
            </div>
            <div>
              <dt>{{ t('detail.grade') }}</dt>
              <dd>
                {{ admin.selectedPlayer.job.grade }} ·
                {{ admin.selectedPlayer.job.gradeLabel || t('detail.unknown') }}
              </dd>
            </div>
          </dl>
        </section>

        <section class="admin-data-panel admin-devices-panel">
          <div class="admin-section-heading">
            <div>
              <span>{{ t('devices.eyebrow') }}</span>
              <h2>{{ t('devices.title') }}</h2>
            </div>
            <strong>{{ admin.selectedPlayer.devices.length }}</strong>
          </div>

          <div
            v-if="admin.selectedPlayer.devices.length > 1"
            class="admin-device-picker"
            :aria-label="t('devices.choose')"
          >
            <button
              v-for="device in admin.selectedPlayer.devices"
              :key="device.imei"
              type="button"
              :class="{ 'is-active': device.imei === selectedDevice?.imei }"
              @click="selectedImei = device.imei"
            >
              <Smartphone :size="17" />
              <span>{{ device.number || device.imei.slice(-4) }}</span>
            </button>
          </div>

          <SkyEmptyState
            v-if="!selectedDevice"
            :body="t('devices.emptyBody')"
            :title="t('devices.empty')"
          />

          <template v-else>
            <div class="admin-device-hero">
              <div class="admin-device-glyph" aria-hidden="true">
                <Smartphone :size="28" />
              </div>
              <div>
                <h3>{{ selectedDevice.name }}</h3>
                <p>{{ selectedDevice.number || t('devices.noNumber') }}</p>
              </div>
              <span>{{ selectedDevice.simType || t('devices.noSim') }}</span>
            </div>

            <dl class="admin-data-list admin-data-list--compact">
              <div>
                <dt>{{ t('devices.imei') }}</dt>
                <dd>{{ selectedDevice.imei }}</dd>
              </div>
              <div>
                <dt>{{ t('devices.updated') }}</dt>
                <dd>{{ formatDate(selectedDevice.updatedAt) }}</dd>
              </div>
            </dl>

            <div class="admin-credential-card">
              <div class="admin-section-heading admin-section-heading--small">
                <div>
                  <span>{{ t('credentials.eyebrow') }}</span>
                  <h3>{{ t('credentials.title') }}</h3>
                </div>
                <KeyRound :size="21" />
              </div>

              <template v-if="selectedDevice.account">
                <div class="admin-secret-row">
                  <div>
                    <span>{{ t('credentials.email') }}</span>
                    <strong>{{ selectedDevice.account.email }}</strong>
                  </div>
                </div>
                <div class="admin-secret-row">
                  <div>
                    <span>{{ t('credentials.password') }}</span>
                    <strong class="admin-password">{{
                      revealedCredential?.password || '••••••••••••'
                    }}</strong>
                  </div>
                  <SkyButton
                    v-if="!revealedCredential"
                    :disabled="
                      admin.actionKey === selectedDevice.imei + ':password'
                    "
                    small
                    tonal
                    @click="revealDialogImei = selectedDevice.imei"
                  >
                    {{ t('credentials.reveal') }}
                  </SkyButton>
                  <SkyButton
                    v-else
                    :aria-label="t('credentials.copy')"
                    icon-only
                    tonal
                    @click="copyPassword"
                  >
                    <Clipboard :size="18" />
                  </SkyButton>
                </div>
              </template>
              <p v-else class="admin-muted-note">
                {{ t('credentials.noAccount') }}
              </p>

              <div class="admin-pin-state">
                <LockKeyhole :size="19" />
                <div>
                  <strong>{{ t('credentials.passcode') }}</strong>
                  <span>{{
                    selectedDevice.security.enabled
                      ? t('credentials.passcodeHashed', {
                          length: String(selectedDevice.security.length ?? 0),
                        })
                      : t('credentials.passcodeDisabled')
                  }}</span>
                </div>
              </div>
            </div>
          </template>
        </section>

        <section v-if="selectedDevice" class="admin-data-panel admin-app-panel">
          <div class="admin-section-heading">
            <div>
              <span>{{ t('apps.eyebrow') }}</span>
              <h2>{{ t('apps.title') }}</h2>
            </div>
            <HardDrive :size="22" />
          </div>
          <SkySearchbar
            v-model="appQuery"
            :clear-label="t('search.clear')"
            :label="t('apps.search')"
            :placeholder="t('apps.search')"
          />
          <div class="admin-app-list">
            <article v-for="app in manageableApps" :key="app.id">
              <div class="admin-mini-app-icon" :class="app.iconClass">
                <component :is="app.icon" :size="20" />
              </div>
              <div>
                <strong>{{ getPhoneAppLabel(app, phone.t) }}</strong>
                <span>{{
                  isInstalled(selectedDevice, app)
                    ? t('apps.installed')
                    : t('apps.available')
                }}</span>
              </div>
              <SkyButton
                :disabled="
                  admin.actionKey === selectedDevice.imei + ':' + app.id ||
                  (isInstalled(selectedDevice, app) &&
                    !isPhoneAppRemovable(app))
                "
                small
                :tonal="isInstalled(selectedDevice, app)"
                :variant="
                  isInstalled(selectedDevice, app) ? 'secondary' : 'primary'
                "
                @click="toggleApp(app)"
              >
                <Check
                  v-if="
                    isInstalled(selectedDevice, app) &&
                    !isPhoneAppRemovable(app)
                  "
                  :size="16"
                />
                <template v-else>{{
                  t(
                    isInstalled(selectedDevice, app)
                      ? 'apps.revoke'
                      : 'apps.grant',
                  )
                }}</template>
              </SkyButton>
            </article>
          </div>
        </section>
      </SkyScrollArea>
    </template>

    <template v-else>
      <SkyNavbar
        :title="t('name')"
        :subtitle="t('subtitle')"
        show-back
        @back="router.push('/')"
      >
        <template #right>
          <button
            class="admin-navbar-action"
            type="button"
            :aria-label="t('refresh')"
            :disabled="admin.loading"
            @click="refresh"
          >
            <RefreshCw :size="19" :class="{ 'is-spinning': admin.loading }" />
          </button>
        </template>
      </SkyNavbar>

      <nav class="admin-tabs" :aria-label="t('navigation')">
        <button
          type="button"
          :class="{ 'is-active': tab === 'players' }"
          @click="tab = 'players'"
        >
          <UsersRound :size="17" />
          {{ t('tabs.players') }}
        </button>
        <button
          type="button"
          :class="{ 'is-active': tab === 'audit' }"
          @click="tab = 'audit'"
        >
          <ShieldEllipsis :size="17" />
          {{ t('tabs.audit') }}
        </button>
      </nav>

      <SkyScrollArea padded class="admin-scroll admin-overview-scroll">
        <div v-if="admin.loading && !admin.initialized" class="admin-loading">
          <SkySpinner />
          <span>{{ t('loading') }}</span>
        </div>

        <template v-else-if="tab === 'players'">
          <section class="admin-command-hero">
            <div class="admin-command-icon" aria-hidden="true">
              <ShieldCheck :size="34" />
            </div>
            <div>
              <span>{{ t('overview.eyebrow') }}</span>
              <h1>{{ t('overview.title') }}</h1>
              <p>{{ t('overview.body') }}</p>
            </div>
          </section>

          <section class="admin-stat-grid" :aria-label="t('overview.stats')">
            <SkyCard>
              <UsersRound :size="19" />
              <strong>{{ admin.stats.online }}</strong>
              <span>{{ t('overview.online') }}</span>
            </SkyCard>
            <SkyCard>
              <Smartphone :size="19" />
              <strong>{{ admin.stats.devices }}</strong>
              <span>{{ t('overview.devices') }}</span>
            </SkyCard>
            <SkyCard>
              <Database :size="19" />
              <strong>{{ admin.stats.accounts }}</strong>
              <span>{{ t('overview.accounts') }}</span>
            </SkyCard>
          </section>

          <section class="admin-player-section">
            <div class="admin-section-heading">
              <div>
                <span>{{ t('players.eyebrow') }}</span>
                <h2>{{ t('players.title') }}</h2>
              </div>
              <strong>{{ filteredPlayers.length }}</strong>
            </div>
            <SkySearchbar
              v-model="playerQuery"
              :clear-label="t('search.clear')"
              :label="t('search.players')"
              :placeholder="t('search.players')"
            />

            <div v-if="filteredPlayers.length" class="admin-player-list">
              <button
                v-for="player in filteredPlayers"
                :key="player.source"
                type="button"
                @click="openPlayer(player.source)"
              >
                <span class="admin-avatar" aria-hidden="true">{{
                  player.name.charAt(0).toLocaleUpperCase(phone.lang)
                }}</span>
                <span class="admin-player-copy">
                  <strong>{{ player.name }}</strong>
                  <small>
                    ID {{ player.source }} ·
                    {{ player.job || t('detail.unknown') }}
                  </small>
                </span>
                <span class="admin-device-count">
                  <Smartphone :size="14" />
                  {{ player.deviceCount }}
                </span>
                <ChevronRight :size="18" />
              </button>
            </div>

            <SkyEmptyState
              v-else
              :body="t('players.emptyBody')"
              :title="t('players.empty')"
            >
              <template #icon>
                <SearchX :size="24" />
              </template>
            </SkyEmptyState>
          </section>
        </template>

        <section v-else class="admin-audit-section">
          <div class="admin-audit-hero">
            <ShieldEllipsis :size="28" />
            <div>
              <span>{{ t('audit.eyebrow') }}</span>
              <h2>{{ t('audit.title') }}</h2>
              <p>{{ t('audit.body') }}</p>
            </div>
          </div>
          <div v-if="admin.audit.length" class="admin-audit-list">
            <article v-for="entry in admin.audit" :key="entry.id">
              <span class="admin-audit-line" aria-hidden="true"></span>
              <div class="admin-audit-icon" aria-hidden="true">
                <ShieldCheck :size="17" />
              </div>
              <div>
                <span>{{ formatDate(entry.createdAt) }}</span>
                <strong>{{ t('audit.actions.' + entry.action) }}</strong>
                <p>{{ auditDescription(entry) }}</p>
                <small>{{
                  t('audit.by', {
                    actor: entry.actorName,
                    target: String(entry.targetSource ?? '—'),
                  })
                }}</small>
              </div>
            </article>
          </div>
          <SkyEmptyState
            v-else
            :body="t('audit.emptyBody')"
            :title="t('audit.empty')"
          />
        </section>
      </SkyScrollArea>
    </template>

    <SkyDialog
      :content="t('credentials.revealBody')"
      :opened="Boolean(revealDialogImei)"
      :title="t('credentials.revealTitle')"
      @backdropclick="revealDialogImei = ''"
      @escape="revealDialogImei = ''"
    >
      <template #buttons>
        <SkyDialogButton @click="revealDialogImei = ''">
          {{ t('credentials.cancel') }}
        </SkyDialogButton>
        <SkyDialogButton strong @click="revealPassword">
          {{ t('credentials.confirmReveal') }}
        </SkyDialogButton>
      </template>
    </SkyDialog>

    <Transition name="admin-toast">
      <div v-if="toast" class="admin-toast" role="status">{{ toast }}</div>
    </Transition>
  </SkyAppPage>
</template>

<style scoped>
.admin-page {
  --admin-violet: #8b7bff;
  --admin-cyan: #39d9ff;
  --admin-green: #46e6a8;
  --admin-surface: #111118;
  --admin-surface-raised: #191923;
  position: absolute;
  inset: 0;
  overflow: hidden;
  background:
    radial-gradient(
      circle at 85% -5%,
      rgba(122, 92, 255, 0.26),
      transparent 34%
    ),
    radial-gradient(
      circle at -8% 35%,
      rgba(57, 217, 255, 0.1),
      transparent 32%
    ),
    #07070b;
  color: var(--sky-text);
}

.admin-page :deep(.sky-app-page__backdrop) {
  background: transparent;
}

.admin-page :deep(.sky-navbar__background) {
  background: rgba(7, 7, 11, 0.96);
}

.admin-page :deep(.sky-navbar__blur) {
  display: none;
}

.admin-scroll {
  position: absolute;
  inset: var(--sky-safe-area-top) 0 var(--sky-safe-area-bottom);
  overflow-x: hidden;
  overflow-y: auto;
  overscroll-behavior: contain;
  scrollbar-width: none;
}

.admin-scroll::-webkit-scrollbar {
  display: none;
}

.admin-overview-scroll {
  top: calc(var(--sky-safe-area-top) + var(--sky-navbar-height) + 58px);
}

.admin-detail-scroll {
  top: calc(var(--sky-safe-area-top) + var(--sky-navbar-height));
  display: grid;
  align-content: start;
  gap: var(--sky-space-4);
}

.admin-navbar-action {
  width: var(--sky-touch-target);
  height: var(--sky-touch-target);
  display: grid;
  place-items: center;
  border: 0;
  border-radius: var(--sky-radius-pill);
  background: var(--sky-app-accent-soft);
  color: var(--admin-violet);
}

.admin-tabs {
  position: absolute;
  z-index: 3;
  top: calc(var(--sky-safe-area-top) + var(--sky-navbar-height) + 7px);
  left: var(--sky-page-gutter);
  right: var(--sky-page-gutter);
  height: 44px;
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: var(--sky-space-1);
  padding: 4px;
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-pill);
  background: #111116;
}

.admin-tabs button {
  min-height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--sky-space-2);
  border: 0;
  border-radius: var(--sky-radius-pill);
  background: transparent;
  color: var(--sky-muted);
  font: inherit;
  font-size: var(--sky-font-caption);
  font-weight: 700;
}

.admin-tabs button.is-active {
  background: linear-gradient(135deg, #6f5cff, #9588ff);
  color: #fff;
  box-shadow: 0 5px 18px rgba(111, 92, 255, 0.32);
}

.admin-command-hero,
.admin-audit-hero,
.admin-identity-card {
  display: flex;
  align-items: center;
  gap: var(--sky-space-4);
  padding: var(--sky-space-5);
  border: 1px solid rgba(139, 123, 255, 0.3);
  border-radius: var(--sky-radius-card);
  background: linear-gradient(
    145deg,
    rgba(34, 31, 56, 0.96),
    rgba(16, 16, 24, 0.98)
  );
  box-shadow: 0 18px 50px rgba(0, 0, 0, 0.3);
}

.admin-command-hero h1,
.admin-audit-hero h2,
.admin-identity-card h2,
.admin-section-heading h2,
.admin-section-heading h3 {
  margin: 3px 0 0;
  font-size: 20px;
  line-height: 1.12;
}

.admin-command-hero p,
.admin-audit-hero p,
.admin-identity-card p {
  margin: 6px 0 0;
  color: var(--sky-muted);
  font-size: 13px;
  line-height: 1.4;
}

.admin-command-hero span,
.admin-audit-hero span,
.admin-kicker,
.admin-section-heading span {
  color: var(--admin-cyan);
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.admin-command-icon,
.admin-device-glyph {
  width: 58px;
  height: 58px;
  flex: none;
  display: grid;
  place-items: center;
  border-radius: 18px;
  background: linear-gradient(145deg, #7864ff, #4431c4);
  color: #fff;
  box-shadow: 0 10px 30px rgba(91, 70, 232, 0.35);
}

.admin-stat-grid,
.admin-info-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--sky-space-2);
  margin-top: var(--sky-space-3);
}

.admin-stat-grid :deep(.sky-card),
.admin-info-grid :deep(.sky-card) {
  min-width: 0;
  border: 1px solid var(--sky-hairline);
  background: rgba(20, 20, 29, 0.96);
}

.admin-stat-grid :deep(.sky-card__content),
.admin-info-grid :deep(.sky-card__content) {
  display: grid;
  gap: 5px;
  padding: var(--sky-space-3);
}

.admin-stat-grid svg,
.admin-info-grid svg {
  color: var(--admin-violet);
}

.admin-stat-grid strong {
  font-size: 23px;
}

.admin-stat-grid span,
.admin-info-grid span {
  overflow: hidden;
  color: var(--sky-muted);
  font-size: 10px;
  text-overflow: ellipsis;
}

.admin-info-grid {
  grid-template-columns: repeat(2, 1fr);
  margin: 0;
}

.admin-info-grid strong {
  overflow: hidden;
  font-size: 13px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.admin-player-section,
.admin-audit-section {
  margin-top: var(--sky-space-5);
}

.admin-section-heading {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--sky-space-3);
  margin-bottom: var(--sky-space-3);
}

.admin-section-heading > strong {
  min-width: 32px;
  padding: 5px 9px;
  border-radius: var(--sky-radius-pill);
  background: var(--sky-app-accent-soft);
  color: var(--admin-violet);
  font-size: 12px;
  text-align: center;
}

.admin-section-heading > svg {
  color: var(--admin-violet);
}

.admin-player-list,
.admin-app-list,
.admin-audit-list {
  display: grid;
  gap: var(--sky-space-2);
  margin-top: var(--sky-space-3);
}

.admin-player-list > button,
.admin-app-list article {
  min-height: 66px;
  display: flex;
  align-items: center;
  gap: var(--sky-space-3);
  width: 100%;
  padding: 10px 12px;
  border: 1px solid var(--sky-hairline);
  border-radius: 18px;
  background: var(--admin-surface);
  color: inherit;
  font: inherit;
  text-align: left;
}

.admin-player-list > button:active {
  background: var(--admin-surface-raised);
  transform: scale(0.985);
}

.admin-avatar {
  width: 44px;
  height: 44px;
  flex: none;
  display: grid;
  place-items: center;
  border: 1px solid rgba(139, 123, 255, 0.4);
  border-radius: 15px;
  background: linear-gradient(145deg, #332c59, #191727);
  color: #bcb2ff;
  font-size: 17px;
  font-weight: 800;
}

.admin-avatar--large {
  width: 60px;
  height: 60px;
  border-radius: 20px;
}

.admin-player-copy,
.admin-app-list article > div:nth-child(2) {
  min-width: 0;
  flex: 1;
  display: grid;
  gap: 4px;
}

.admin-player-copy strong,
.admin-player-copy small,
.admin-app-list strong,
.admin-app-list span {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.admin-player-copy small,
.admin-app-list span {
  color: var(--sky-muted);
  font-size: 11px;
}

.admin-device-count {
  display: flex;
  align-items: center;
  gap: 4px;
  color: var(--sky-muted);
  font-size: 11px;
}

.admin-identity-card {
  position: relative;
  min-height: 100px;
}

.admin-live-dot {
  position: absolute;
  top: 18px;
  right: 18px;
  width: 10px;
  height: 10px;
  border: 2px solid #211e35;
  border-radius: 50%;
  background: var(--admin-green);
  box-shadow: 0 0 12px rgba(70, 230, 168, 0.7);
}

.admin-data-panel {
  padding: var(--sky-space-4);
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-card);
  background: rgba(17, 17, 24, 0.96);
}

.admin-data-list {
  display: grid;
  gap: 1px;
  margin: 0;
  overflow: hidden;
  border: 1px solid var(--sky-hairline);
  border-radius: 16px;
  background: var(--sky-hairline);
}

.admin-data-list > div {
  display: grid;
  gap: 5px;
  padding: 12px 13px;
  background: var(--admin-surface-raised);
}

.admin-data-list dt {
  color: var(--sky-muted);
  font-size: 10px;
  text-transform: uppercase;
}

.admin-data-list dd {
  margin: 0;
  overflow-wrap: anywhere;
  font-size: 12px;
}

.admin-device-picker {
  display: flex;
  gap: var(--sky-space-2);
  margin-bottom: var(--sky-space-3);
  overflow-x: auto;
  scrollbar-width: none;
}

.admin-device-picker button {
  min-width: 94px;
  min-height: var(--sky-touch-target);
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  padding: 8px 12px;
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-pill);
  background: var(--admin-surface-raised);
  color: var(--sky-muted);
}

.admin-device-picker button.is-active {
  border-color: var(--admin-violet);
  background: var(--sky-app-accent-soft);
  color: #c8c0ff;
}

.admin-device-hero {
  display: flex;
  align-items: center;
  gap: var(--sky-space-3);
  padding: var(--sky-space-3) 0;
}

.admin-device-glyph {
  width: 48px;
  height: 48px;
  border-radius: 15px;
}

.admin-device-hero > div:nth-child(2) {
  min-width: 0;
  flex: 1;
}

.admin-device-hero h3,
.admin-device-hero p {
  margin: 0;
}

.admin-device-hero p,
.admin-device-hero > span {
  margin-top: 4px;
  color: var(--sky-muted);
  font-size: 11px;
}

.admin-data-list--compact {
  grid-template-columns: repeat(2, 1fr);
  margin-top: var(--sky-space-2);
}

.admin-credential-card {
  margin-top: var(--sky-space-4);
  padding: var(--sky-space-4);
  border: 1px solid rgba(57, 217, 255, 0.2);
  border-radius: 19px;
  background: linear-gradient(
    145deg,
    rgba(17, 29, 36, 0.95),
    rgba(17, 17, 25, 0.98)
  );
}

.admin-section-heading--small {
  margin-bottom: var(--sky-space-2);
}

.admin-secret-row {
  min-height: 58px;
  display: flex;
  align-items: center;
  gap: var(--sky-space-2);
  border-bottom: 1px solid var(--sky-hairline);
}

.admin-secret-row > div {
  min-width: 0;
  flex: 1;
  display: grid;
  gap: 4px;
}

.admin-secret-row span,
.admin-pin-state span,
.admin-muted-note {
  color: var(--sky-muted);
  font-size: 11px;
}

.admin-secret-row strong {
  overflow: hidden;
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.admin-password {
  color: var(--admin-cyan);
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
}

.admin-pin-state {
  display: flex;
  align-items: center;
  gap: var(--sky-space-3);
  padding-top: var(--sky-space-3);
}

.admin-pin-state > svg {
  color: var(--admin-green);
}

.admin-pin-state > div {
  display: grid;
  gap: 4px;
}

.admin-app-panel :deep(.sky-searchbar) {
  margin-bottom: var(--sky-space-3);
}

.admin-mini-app-icon {
  width: 42px;
  height: 42px;
  flex: none;
  display: grid;
  place-items: center;
  border-radius: 13px;
  background: linear-gradient(145deg, #2f2f3c, #17171e);
  color: #fff;
}

.admin-app-list :deep(.sky-button) {
  min-width: 72px;
}

.admin-audit-hero {
  margin-bottom: var(--sky-space-4);
}

.admin-audit-hero > svg {
  flex: none;
  color: var(--admin-violet);
}

.admin-audit-list article {
  position: relative;
  display: grid;
  grid-template-columns: 38px 1fr;
  gap: var(--sky-space-3);
  min-height: 96px;
}

.admin-audit-icon {
  z-index: 1;
  width: 38px;
  height: 38px;
  display: grid;
  place-items: center;
  border: 1px solid rgba(139, 123, 255, 0.38);
  border-radius: 13px;
  background: #201d32;
  color: #a99dff;
}

.admin-audit-line {
  position: absolute;
  top: 38px;
  bottom: -10px;
  left: 18px;
  width: 1px;
  background: linear-gradient(var(--admin-violet), transparent);
}

.admin-audit-list article:last-child .admin-audit-line {
  display: none;
}

.admin-audit-list article > div:last-child {
  display: grid;
  align-content: start;
  gap: 4px;
  padding: 2px 0 var(--sky-space-4);
}

.admin-audit-list span,
.admin-audit-list small {
  color: var(--sky-muted);
  font-size: 10px;
}

.admin-audit-list p {
  margin: 0;
  color: #c8c8d2;
  font-size: 12px;
  overflow-wrap: anywhere;
}

.admin-loading {
  min-height: 280px;
  display: grid;
  place-items: center;
  align-content: center;
  gap: var(--sky-space-3);
  color: var(--sky-muted);
}

.admin-toast {
  position: absolute;
  z-index: 20;
  left: 50%;
  bottom: calc(var(--sky-safe-area-bottom) + var(--sky-space-4));
  max-width: calc(100% - 32px);
  padding: 11px 16px;
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: var(--sky-radius-pill);
  background: #262331;
  box-shadow: 0 12px 32px rgba(0, 0, 0, 0.45);
  color: #fff;
  font-size: 12px;
  transform: translateX(-50%);
}

.is-spinning {
  animation: admin-spin 0.8s linear infinite;
}

.admin-toast-enter-active,
.admin-toast-leave-active {
  transition:
    opacity var(--sky-transition-normal) ease,
    transform var(--sky-transition-normal) ease;
}

.admin-toast-enter-from,
.admin-toast-leave-to {
  opacity: 0;
  transform: translate(-50%, 8px);
}

@keyframes admin-spin {
  to {
    transform: rotate(360deg);
  }
}

@media (prefers-reduced-motion: reduce) {
  .admin-page *,
  .admin-page *::before,
  .admin-page *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
</style>
