<script setup lang="ts">
import {
  BellRing,
  Check,
  ChevronLeft,
  Cloud,
  Gauge,
  LockKeyhole,
  Palette,
  ShieldCheck,
  Signal,
  Smartphone,
  Sparkles,
  Wifi,
} from 'lucide-vue-next'
import { computed, ref } from 'vue'

import PhonePasscode from '@/components/PhonePasscode.vue'
import { getPhoneApp, getPhoneAppLabel } from '@/config/apps'
import { useAccountStore } from '@/stores/account'
import { useAppStoreStore } from '@/stores/app-store'
import { usePhoneStore } from '@/stores/phone'
import type { BuiltinPhoneAppId } from '@/types/apps'
import { SkyButton, SkyField, SkySpinner } from '@/ui'
import { filterMailAddressInput, normalizeMailAddress } from '@/utils/mail'
import {
  PHONE_SETUP_LAST_STEP,
  WALLPAPER_IDS,
  type AppearanceMode,
  type GraphicsMode,
  type WallpaperId,
} from '@/utils/preferences'

const emit = defineEmits<{
  appearanceSelected: [selected: boolean]
  complete: []
  skip: []
}>()

const phone = usePhoneStore()
const account = useAccountStore()
const appStore = useAppStoreStore()
const step = ref(
  Math.min(PHONE_SETUP_LAST_STEP, phone.preferences.settings.setupStep),
)
const appearanceSelected = ref(step.value > 4)
if (step.value === 4) {
  phone.setPreference('appearanceMode', 'light')
}
const direction = ref<'back' | 'forward'>('forward')
const accountMode = ref<'login' | 'register'>('login')
const email = ref('')
const password = ref('')
const passwordConfirm = ref('')
const accountBusy = ref(false)
const accountError = ref('')
const passcodeStage = ref<'create' | 'confirm' | null>(null)
const passcodeFirst = ref('')
const passcodeResetKey = ref(0)
const passcodeError = ref('')
const passcodeLength = ref<4 | 6>(phone.security.length === 4 ? 4 : 6)
const notificationsEnabled = ref(true)
const notificationSounds = ref(true)
const selectedApps = ref<BuiltinPhoneAppId[]>(
  (['banking', 'garage', 'skyride'] as const).filter((id) =>
    appStore.isAvailable(id),
  ),
)
const setupCompleteBusy = ref(false)
const setupCompleteError = ref('')

const setupApps = computed(() =>
  (
    ['banking', 'garage', 'skyride', 'citymarkt', 'picstagram', 'snake'] as const
  ).flatMap((id) => {
    const app = getPhoneApp(id)
    return app && appStore.isAvailable(id) ? [app] : []
  }),
)
const wallpaperChoices = WALLPAPER_IDS
const progress = computed(() => `${((step.value + 1) / 10) * 100}%`)
const displayName = computed(() => {
  const name = [phone.player.firstName, phone.player.lastName]
    .map((part) => part.trim())
    .filter(Boolean)
    .join(' ')
  return name || phone.t('Setup.ownerFallback')
})
const normalizedAccountEmail = computed(() => normalizeMailAddress(email.value))
const accountInitial = computed(() =>
  (email.value.trim()[0] ?? displayName.value[0] ?? 'S').toUpperCase(),
)
const passwordStrength = computed(() => {
  const value = password.value
  if (!value) return 0
  return [
    value.length >= 6,
    value.length >= 10,
    /[a-z]/i.test(value) && /\d/.test(value),
    /[^a-z0-9]/i.test(value),
  ].filter(Boolean).length
})
const currentWallpaperStyle = computed(() => ({
  '--setup-wallpaper': `var(--phone-wallpaper-${phone.preferences.settings.wallpaper})`,
}))
const showDevelopmentSkip = import.meta.env.DEV

function moveTo(nextStep: number): void {
  direction.value = nextStep < step.value ? 'back' : 'forward'
  step.value = Math.min(PHONE_SETUP_LAST_STEP, Math.max(0, nextStep))
  if (step.value < 4) {
    appearanceSelected.value = false
    emit('appearanceSelected', false)
  }
  if (step.value === 4 && !appearanceSelected.value) {
    phone.setPreference('appearanceMode', 'light')
  }
  phone.setSetupStep(step.value)
}

function continueSetup(): void {
  if (step.value === 7) {
    phone.setAllAppNotifications(
      notificationsEnabled.value,
      notificationSounds.value,
    )
  }
  if (step.value === 8) {
    for (const appId of selectedApps.value) appStore.claimApp(appId)
    void finish()
    return
  }
  moveTo(step.value + 1)
}

function chooseAppearance(mode: AppearanceMode): void {
  appearanceSelected.value = true
  phone.setPreference('appearanceMode', mode)
  emit('appearanceSelected', true)
}

function choosePerformance(mode: GraphicsMode): void {
  phone.setPreference('graphicsMode', mode)
}

function chooseWallpaper(wallpaper: Exclude<WallpaperId, 'custom'>): void {
  phone.setWallpaper(wallpaper, null, 'both')
}

function toggleApp(appId: BuiltinPhoneAppId): void {
  selectedApps.value = selectedApps.value.includes(appId)
    ? selectedApps.value.filter((id) => id !== appId)
    : [...selectedApps.value, appId]
}

async function submitAccount(): Promise<void> {
  if (!normalizedAccountEmail.value || password.value.length < 6) {
    accountError.value = phone.t('Setup.cloud.invalid')
    return
  }
  if (
    accountMode.value === 'register' &&
    password.value !== passwordConfirm.value
  ) {
    accountError.value = phone.t('Setup.cloud.passwordMismatch')
    return
  }
  accountBusy.value = true
  accountError.value = ''
  const response =
    accountMode.value === 'login'
      ? await account.login(normalizedAccountEmail.value, password.value)
      : await account.register(normalizedAccountEmail.value, password.value)
  accountBusy.value = false
  if (!response.success) {
    accountError.value = phone.t(
      `Setup.cloud.errors.${response.error ?? 'request_failed'}`,
    )
    return
  }
  continueSetup()
}

function selectAccountMode(mode: 'login' | 'register'): void {
  if (accountMode.value === mode) return
  accountMode.value = mode
  password.value = ''
  passwordConfirm.value = ''
  accountError.value = ''
}

function updateAccountName(event: Event): void {
  const input = event.target as HTMLInputElement
  const localPart = filterMailAddressInput(input.value)
    .split('@')[0]
    .slice(0, 32)
    .toLocaleLowerCase('en-US')
  input.value = localPart
  email.value = localPart
}

function submitPasscode(passcode: string): void {
  if (passcodeStage.value === 'create') {
    passcodeFirst.value = passcode
    passcodeStage.value = 'confirm'
    passcodeResetKey.value += 1
    return
  }
  if (passcode !== passcodeFirst.value) {
    passcodeError.value = phone.t('Setup.security.mismatch')
    passcodeStage.value = 'create'
    passcodeFirst.value = ''
    passcodeResetKey.value += 1
    return
  }
  void phone.setPasscode(passcode).then((response) => {
    if (!response.success) {
      passcodeError.value = phone.t('Setup.security.failed')
      passcodeStage.value = 'create'
      passcodeResetKey.value += 1
      return
    }
    passcodeStage.value = null
    continueSetup()
  })
}

function choosePasscodeLength(length: 4 | 6): void {
  passcodeLength.value = length
  passcodeFirst.value = ''
  passcodeError.value = ''
  passcodeResetKey.value += 1
}

async function finish(): Promise<void> {
  if (setupCompleteBusy.value) return
  setupCompleteBusy.value = true
  setupCompleteError.value = ''
  const completed = await phone.completeSetup()
  setupCompleteBusy.value = false
  if (!completed) {
    setupCompleteError.value = phone.t('Setup.ready.saveFailed')
    return
  }
  emit('complete')
}

function skipSetupForDevelopment(): void {
  emit('skip')
}
</script>

<template>
  <section
    class="setup-assistant"
    :class="[
      `setup-assistant--step-${step}`,
      {
        'setup-assistant--dark':
          (appearanceSelected || step > 4) && phone.isDarkMode,
        'setup-assistant--performance':
          phone.preferences.settings.graphicsMode === 'performance',
        'setup-assistant--ultimate':
          phone.preferences.settings.graphicsMode === 'ultimate',
      },
    ]"
    :style="currentWallpaperStyle"
    :aria-label="phone.t('Setup.title')"
  >
    <button
      v-if="showDevelopmentSkip && step === 0"
      type="button"
      class="setup-assistant__development-skip"
      @click="skipSetupForDevelopment"
    >
      {{ phone.t('Setup.development.skip') }}
    </button>
    <header v-if="step > 0 && step < 9" class="setup-assistant__chrome">
      <button
        type="button"
        class="setup-assistant__back"
        :aria-label="phone.t('Common.back')"
        @click="moveTo(step - 1)"
      >
        <ChevronLeft :size="23" :stroke-width="2.2" />
      </button>
      <div class="setup-assistant__progress" aria-hidden="true">
        <span :style="{ width: progress }"></span>
      </div>
      <span class="setup-assistant__counter">{{ step + 1 }}/10</span>
    </header>

    <Transition
      :name="direction === 'forward' ? 'setup-forward' : 'setup-back'"
      mode="out-in"
    >
      <main :key="step" class="setup-assistant__page">
        <template v-if="step === 0">
          <div class="setup-welcome__hero" aria-hidden="true">
            <div class="setup-welcome__device">
              <Smartphone :size="43" :stroke-width="1.55" />
            </div>
          </div>
          <div class="setup-welcome__copy">
            <p class="setup-welcome__eyebrow">
              {{ phone.t('Setup.welcome.eyebrow') }}
            </p>
            <h1>{{ phone.t('Setup.welcome.title') }}</h1>
            <p class="setup-assistant__lead">
              {{ phone.t('Setup.welcome.body', { name: displayName }) }}
            </p>
          </div>
          <footer class="setup-welcome__footer">
            <SkyButton class="setup-assistant__primary" @click="continueSetup">
              {{ phone.t('Setup.getStarted') }}
            </SkyButton>
            <div class="setup-welcome__home-indicator" aria-hidden="true"></div>
          </footer>
        </template>

        <template v-else-if="step === 1">
          <div class="setup-assistant__icon setup-assistant__icon--signal">
            <Signal :size="44" />
          </div>
          <p class="setup-assistant__eyebrow">
            {{ phone.t('Setup.connection.eyebrow') }}
          </p>
          <h1>{{ phone.t('Setup.connection.title') }}</h1>
          <p class="setup-assistant__lead">
            {{ phone.t('Setup.connection.body') }}
          </p>
          <div class="setup-connectivity-card">
            <div
              class="setup-connectivity-card__waves"
              aria-hidden="true"
            ></div>
            <span class="setup-connectivity-card__label">Sky SIM</span>
            <strong>{{
              phone.device?.sim?.number ?? phone.t('Setup.connection.noSim')
            }}</strong>
            <span>{{
              phone.device?.sim
                ? phone.t('Setup.connection.ready')
                : phone.t('Setup.connection.offline')
            }}</span>
            <Wifi :size="25" />
          </div>
          <div class="setup-assistant__notice">
            <ShieldCheck :size="19" />
            <p>{{ phone.t('Setup.connection.preserved') }}</p>
          </div>
          <SkyButton class="setup-assistant__primary" @click="continueSetup">
            {{ phone.t('Common.continue') }}
          </SkyButton>
        </template>

        <template v-else-if="step === 2">
          <div class="setup-cloud-hero" aria-hidden="true">
            <span class="setup-cloud-hero__orbit"></span>
            <span class="setup-cloud-hero__glow"></span>
            <Cloud :size="45" :stroke-width="1.45" />
            <i></i><i></i><i></i>
          </div>
          <p class="setup-assistant__eyebrow">
            {{ phone.t('Setup.cloud.eyebrow') }}
          </p>
          <Transition name="setup-account-copy" mode="out-in">
            <div :key="accountMode" class="setup-cloud-heading">
              <h1>
                {{
                  phone.t(
                    accountMode === 'login'
                      ? 'Setup.cloud.signInTitle'
                      : 'Setup.cloud.createTitle',
                  )
                }}
              </h1>
              <p class="setup-assistant__lead">
                {{
                  phone.t(
                    accountMode === 'login'
                      ? 'Setup.cloud.signInBody'
                      : 'Setup.cloud.createBody',
                  )
                }}
              </p>
            </div>
          </Transition>
          <div v-if="!account.email" class="setup-cloud-form">
            <div class="setup-assistant__selector" role="group">
              <span
                class="setup-assistant__selector-indicator"
                :class="{
                  'setup-assistant__selector-indicator--register':
                    accountMode === 'register',
                }"
                aria-hidden="true"
              ></span>
              <button
                :class="{ active: accountMode === 'login' }"
                :aria-pressed="accountMode === 'login'"
                @click="selectAccountMode('login')"
              >
                {{ phone.t('Setup.cloud.signIn') }}
              </button>
              <button
                :class="{ active: accountMode === 'register' }"
                :aria-pressed="accountMode === 'register'"
                @click="selectAccountMode('register')"
              >
                {{ phone.t('Setup.cloud.create') }}
              </button>
            </div>

            <div class="setup-cloud-identity">
              <span>{{ accountInitial }}</span>
              <div>
                <small>{{ phone.t('Setup.cloud.accountPreview') }}</small>
                <strong
                  >{{ email || phone.t('Setup.cloud.addressPlaceholder')
                  }}<em>@ifruit.com</em></strong
                >
              </div>
              <Check v-if="normalizedAccountEmail" :size="17" />
            </div>

            <div class="setup-cloud-fields">
              <SkyField
                id="setup-cloud-name"
                :model-value="email"
                :label="phone.t('Setup.cloud.accountName')"
                :placeholder="phone.t('Setup.cloud.addressPlaceholder')"
                autocomplete="username"
                autocapitalize="none"
                autocorrect="off"
                :spellcheck="false"
                @input="updateAccountName"
              >
                <template #trailing>
                  <span class="setup-cloud-suffix">@ifruit.com</span>
                </template>
              </SkyField>
              <SkyField
                id="setup-cloud-password"
                v-model="password"
                type="password"
                :label="phone.t('Setup.cloud.password')"
                :autocomplete="
                  accountMode === 'login' ? 'current-password' : 'new-password'
                "
              />
              <Transition name="setup-account-field">
                <SkyField
                  v-if="accountMode === 'register'"
                  id="setup-cloud-password-confirm"
                  v-model="passwordConfirm"
                  type="password"
                  :label="phone.t('Setup.cloud.confirmPassword')"
                  autocomplete="new-password"
                />
              </Transition>
            </div>

            <Transition name="setup-account-strength">
              <div
                v-if="accountMode === 'register'"
                class="setup-cloud-strength"
              >
                <div>
                  <span
                    v-for="level in 4"
                    :key="level"
                    :class="{ active: level <= passwordStrength }"
                  ></span>
                </div>
                <small>{{
                  phone.t(`Setup.cloud.strength${passwordStrength}`)
                }}</small>
              </div>
            </Transition>
            <p v-if="accountError" class="setup-assistant__error" role="alert">
              {{ accountError }}
            </p>
            <SkyButton
              class="setup-assistant__primary"
              :disabled="accountBusy"
              @click="submitAccount"
            >
              <SkySpinner v-if="accountBusy" />
              <Transition v-else name="setup-account-action" mode="out-in">
                <span :key="accountMode">{{
                  phone.t(
                    accountMode === 'login'
                      ? 'Setup.cloud.signInAction'
                      : 'Setup.cloud.createAction',
                  )
                }}</span>
              </Transition>
            </SkyButton>
            <div class="setup-cloud-security-note">
              <LockKeyhole :size="13" />
              <span>{{ phone.t('Setup.cloud.securityNote') }}</span>
            </div>
            <button
              type="button"
              class="setup-assistant__later"
              @click="continueSetup"
            >
              {{ phone.t('Setup.setUpLater') }}
            </button>
          </div>
          <div v-else class="setup-cloud-connected">
            <Check :size="31" />
            <strong>{{ phone.t('Setup.cloud.connected') }}</strong>
            <span>{{ account.email }}</span>
            <SkyButton
              class="setup-assistant__primary"
              @click="continueSetup"
              >{{ phone.t('Common.continue') }}</SkyButton
            >
          </div>
        </template>

        <template v-else-if="step === 3">
          <div class="setup-assistant__icon setup-assistant__icon--security">
            <LockKeyhole :size="43" />
          </div>
          <p class="setup-assistant__eyebrow">
            {{ phone.t('Setup.security.eyebrow') }}
          </p>
          <h1>{{ phone.t('Setup.security.title') }}</h1>
          <p class="setup-assistant__lead">
            {{ phone.t('Setup.security.body') }}
          </p>
          <div class="setup-security-visual" aria-hidden="true">
            <div>
              <span v-for="dot in passcodeLength" :key="dot"></span>
            </div>
            <ShieldCheck :size="40" />
          </div>
          <div
            class="setup-passcode-length"
            role="group"
            :aria-label="phone.t('Setup.security.lengthTitle')"
          >
            <button
              v-for="length in [4, 6] as const"
              :key="length"
              type="button"
              :class="{ selected: passcodeLength === length }"
              @click="choosePasscodeLength(length)"
            >
              <span>
                <b>{{ length }}</b>
                <small>{{
                  phone.t(
                    `Setup.security.${length === 4 ? 'fourDigit' : 'sixDigit'}`,
                  )
                }}</small>
              </span>
              <Check
                v-if="passcodeLength === length"
                :size="16"
                :stroke-width="3"
              />
            </button>
          </div>
          <div class="setup-assistant__notice">
            <ShieldCheck :size="19" />
            <p>{{ phone.t('Setup.security.local') }}</p>
          </div>
          <SkyButton
            class="setup-assistant__primary"
            @click="passcodeStage = 'create'"
            >{{
              phone.t('Setup.security.createSelected', {
                count: String(passcodeLength),
              })
            }}</SkyButton
          >
          <button
            type="button"
            class="setup-assistant__later"
            @click="continueSetup"
          >
            {{ phone.t('Setup.setUpLater') }}
          </button>
        </template>

        <template v-else-if="step === 4">
          <div class="setup-assistant__icon setup-assistant__icon--appearance">
            <Palette :size="43" />
          </div>
          <p class="setup-assistant__eyebrow">
            {{ phone.t('Setup.appearance.eyebrow') }}
          </p>
          <h1>{{ phone.t('Setup.appearance.title') }}</h1>
          <p class="setup-assistant__lead">
            {{ phone.t('Setup.appearance.body') }}
          </p>
          <div class="setup-choice-grid setup-choice-grid--appearance">
            <button
              v-for="mode in ['automatic', 'light', 'dark'] as AppearanceMode[]"
              :key="mode"
              :class="{
                selected: phone.preferences.settings.appearanceMode === mode,
              }"
              @click="chooseAppearance(mode)"
            >
              <span
                class="setup-appearance-preview"
                :class="`setup-appearance-preview--${mode}`"
                ><i></i><i></i><i></i
              ></span>
              <strong>{{ phone.t(`Apps.settings.${mode}`) }}</strong>
              <Check
                v-if="phone.preferences.settings.appearanceMode === mode"
                :size="18"
              />
            </button>
          </div>
          <SkyButton class="setup-assistant__primary" @click="continueSetup">{{
            phone.t('Common.continue')
          }}</SkyButton>
        </template>

        <template v-else-if="step === 5">
          <div class="setup-assistant__icon setup-assistant__icon--performance">
            <Gauge :size="44" />
          </div>
          <p class="setup-assistant__eyebrow">
            {{ phone.t('Setup.performance.eyebrow') }}
          </p>
          <h1>{{ phone.t('Setup.performance.title') }}</h1>
          <p class="setup-assistant__lead">
            {{ phone.t('Setup.performance.body') }}
          </p>
          <div class="setup-mode-stack">
            <button
              v-for="mode in ['performance', 'ultimate'] as GraphicsMode[]"
              :key="mode"
              :class="{
                selected: phone.preferences.settings.graphicsMode === mode,
              }"
              @click="choosePerformance(mode)"
            >
              <span
                class="setup-mode-stack__orb"
                :class="`setup-mode-stack__orb--${mode}`"
                aria-hidden="true"
              >
                <i class="setup-mode-preview__backdrop"></i>
                <i
                  class="setup-mode-preview__card setup-mode-preview__card--back"
                ></i>
                <i
                  class="setup-mode-preview__card setup-mode-preview__card--front"
                ></i>
                <i
                  class="setup-mode-preview__line setup-mode-preview__line--wide"
                ></i>
                <i class="setup-mode-preview__line"></i>
              </span>
              <span
                ><strong>{{ phone.t(`Apps.settings.${mode}Mode`) }}</strong
                ><small>{{ phone.t(`Setup.performance.${mode}`) }}</small></span
              >
              <span class="setup-mode-stack__check"
                ><Check
                  v-if="phone.preferences.settings.graphicsMode === mode"
                  :size="17"
              /></span>
            </button>
          </div>
          <div class="setup-assistant__notice">
            <Gauge :size="19" />
            <p>{{ phone.t('Setup.performance.changeLater') }}</p>
          </div>
          <SkyButton class="setup-assistant__primary" @click="continueSetup">{{
            phone.t('Common.continue')
          }}</SkyButton>
        </template>

        <template v-else-if="step === 6">
          <div class="setup-assistant__icon setup-assistant__icon--wallpaper">
            <Sparkles :size="43" />
          </div>
          <p class="setup-assistant__eyebrow">
            {{ phone.t('Setup.wallpaper.eyebrow') }}
          </p>
          <h1>{{ phone.t('Setup.wallpaper.title') }}</h1>
          <p class="setup-assistant__lead">
            {{ phone.t('Setup.wallpaper.body') }}
          </p>
          <div class="setup-wallpapers">
            <button
              v-for="wallpaper in wallpaperChoices"
              :key="wallpaper"
              :class="[
                `wallpaper--${wallpaper}`,
                {
                  selected: phone.preferences.settings.wallpaper === wallpaper,
                },
              ]"
              :aria-label="wallpaper"
              @click="chooseWallpaper(wallpaper)"
            >
              <Check
                v-if="phone.preferences.settings.wallpaper === wallpaper"
                :size="17"
              />
            </button>
          </div>
          <SkyButton class="setup-assistant__primary" @click="continueSetup">{{
            phone.t('Common.continue')
          }}</SkyButton>
        </template>

        <template v-else-if="step === 7">
          <div
            class="setup-assistant__icon setup-assistant__icon--notifications"
          >
            <BellRing :size="43" />
          </div>
          <p class="setup-assistant__eyebrow">
            {{ phone.t('Setup.notifications.eyebrow') }}
          </p>
          <h1>{{ phone.t('Setup.notifications.title') }}</h1>
          <p class="setup-assistant__lead">
            {{ phone.t('Setup.notifications.body') }}
          </p>
          <div class="setup-toggle-card">
            <button @click="notificationsEnabled = !notificationsEnabled">
              <span
                ><strong>{{ phone.t('Setup.notifications.allow') }}</strong
                ><small>{{
                  phone.t('Setup.notifications.allowBody')
                }}</small></span
              ><i :class="{ on: notificationsEnabled }"><b></b></i>
            </button>
            <button
              :disabled="!notificationsEnabled"
              @click="notificationSounds = !notificationSounds"
            >
              <span
                ><strong>{{ phone.t('Setup.notifications.sounds') }}</strong
                ><small>{{
                  phone.t('Setup.notifications.soundsBody')
                }}</small></span
              ><i :class="{ on: notificationsEnabled && notificationSounds }"
                ><b></b
              ></i>
            </button>
          </div>
          <SkyButton class="setup-assistant__primary" @click="continueSetup">{{
            phone.t('Common.continue')
          }}</SkyButton>
        </template>

        <template v-else-if="step === 8">
          <div class="setup-assistant__icon setup-assistant__icon--apps">
            <Sparkles :size="43" />
          </div>
          <p class="setup-assistant__eyebrow">
            {{ phone.t('Setup.apps.eyebrow') }}
          </p>
          <h1>{{ phone.t('Setup.apps.title') }}</h1>
          <p class="setup-assistant__lead">{{ phone.t('Setup.apps.body') }}</p>
          <div class="setup-app-list">
            <button
              v-for="app in setupApps"
              :key="app.id"
              :class="{
                selected: selectedApps.includes(app.id as BuiltinPhoneAppId),
              }"
              @click="toggleApp(app.id as BuiltinPhoneAppId)"
            >
              <img :src="app.iconImage" alt="" />
              <span
                ><strong>{{ getPhoneAppLabel(app, phone.t) }}</strong
                ><small>{{
                  phone.t(`Setup.apps.descriptions.${app.id}`)
                }}</small></span
              >
              <i
                ><Check
                  v-if="selectedApps.includes(app.id as BuiltinPhoneAppId)"
                  :size="16"
              /></i>
            </button>
          </div>
          <SkyButton class="setup-assistant__primary" @click="continueSetup">{{
            phone.t('Setup.apps.install', {
              count: String(selectedApps.length),
            })
          }}</SkyButton>
        </template>

        <template v-else>
          <div class="setup-ready__halo" aria-hidden="true">
            <Check :size="66" />
          </div>
          <p class="setup-assistant__eyebrow">
            {{ phone.t('Setup.ready.eyebrow') }}
          </p>
          <h1>
            {{
              phone.t('Setup.ready.title', {
                name: phone.player.firstName || displayName,
              })
            }}
          </h1>
          <p class="setup-assistant__lead">{{ phone.t('Setup.ready.body') }}</p>
          <div class="setup-ready__summary">
            <span
              ><Cloud :size="18" /><b>{{
                account.email || phone.t('Setup.ready.localOnly')
              }}</b></span
            >
            <span
              ><Gauge :size="18" /><b>{{
                phone.t(
                  `Apps.settings.${phone.preferences.settings.graphicsMode}Mode`,
                )
              }}</b></span
            >
            <span
              ><Palette :size="18" /><b>{{
                phone.t(
                  `Apps.settings.${phone.preferences.settings.appearanceMode}`,
                )
              }}</b></span
            >
          </div>
          <SkyButton
            class="setup-assistant__primary"
            :disabled="setupCompleteBusy"
            @click="finish"
          >
            <SkySpinner
              v-if="setupCompleteBusy"
              :label="phone.t('Setup.ready.saving')"
              :size="18"
            />
            <span v-else>{{ phone.t('Setup.ready.enter') }}</span>
          </SkyButton>
          <p
            v-if="setupCompleteError"
            class="setup-assistant__error"
            role="alert"
          >
            {{ setupCompleteError }}
          </p>
          <button
            type="button"
            class="setup-assistant__later"
            :disabled="setupCompleteBusy"
            @click="moveTo(0)"
          >
            {{ phone.t('Setup.ready.review') }}
          </button>
        </template>
      </main>
    </Transition>

    <PhonePasscode
      v-if="passcodeStage"
      :length="passcodeLength"
      :reset-key="passcodeResetKey"
      :error="passcodeError"
      :title="
        phone.t(
          passcodeStage === 'create'
            ? 'Setup.security.enter'
            : 'Setup.security.confirm',
        )
      "
      :subtitle="
        phone.t(
          passcodeLength === 4
            ? 'Setup.security.fourDigitHint'
            : 'Setup.security.sixDigitHint',
        )
      "
      @cancel="passcodeStage = null"
      @complete="submitPasscode"
    />
  </section>
</template>

<style scoped>
.setup-assistant {
  position: absolute;
  inset: 0;
  z-index: 90;
  overflow: clip;
  color: #f8fbff;
  background: #05070d;
  font-family: var(--sky-font-family);
  user-select: none;
}
.setup-assistant__aurora {
  position: absolute;
  inset: -28%;
  background:
    radial-gradient(circle at 30% 20%, rgb(40 116 255/32%), transparent 28%),
    radial-gradient(circle at 75% 65%, rgb(161 67 255/20%), transparent 27%),
    radial-gradient(circle at 40% 92%, rgb(0 214 184/13%), transparent 25%);
  filter: blur(28px);
  animation: setup-aurora 12s ease-in-out infinite alternate;
}
.setup-assistant__development-skip {
  position: absolute;
  z-index: 3;
  top: 20px;
  right: 18px;
  min-height: 44px;
  padding: 0 12px;
  border: 1px solid rgb(255 255 255 / 16%);
  border-radius: 12px;
  color: rgb(255 255 255 / 82%);
  background: rgb(10 16 31 / 72%);
  font-size: 11px;
  font-weight: 700;
}
.setup-assistant__development-skip:focus-visible {
  outline: 2px solid #72b5ff;
  outline-offset: 2px;
}
.setup-assistant__chrome {
  position: absolute;
  z-index: 2;
  top: 54px;
  left: 18px;
  right: 18px;
  display: grid;
  grid-template-columns: 34px 1fr 34px;
  align-items: center;
  gap: 12px;
}
.setup-assistant__back {
  display: grid;
  width: 34px;
  height: 34px;
  padding: 0;
  place-items: center;
  border: 1px solid rgb(255 255 255/10%);
  border-radius: 50%;
  color: white;
  background: rgb(255 255 255/8%);
  backdrop-filter: blur(18px);
}
.setup-assistant__progress {
  height: 4px;
  overflow: hidden;
  border-radius: 99px;
  background: rgb(255 255 255/12%);
}
.setup-assistant__progress span {
  display: block;
  height: 100%;
  border-radius: inherit;
  background: linear-gradient(90deg, #58aaff, #7b76ff);
  transition: width 0.35s cubic-bezier(0.2, 0.8, 0.2, 1);
}
.setup-assistant__counter {
  color: rgb(255 255 255/48%);
  font-size: 11px;
  font-weight: 650;
  text-align: right;
}
.setup-assistant__page {
  position: relative;
  z-index: 1;
  display: flex;
  box-sizing: border-box;
  width: 100%;
  height: 100%;
  padding: 70px 27px 25px;
  flex-direction: column;
  align-items: center;
  overflow-y: auto;
  scrollbar-width: none;
  text-align: center;
}
.setup-assistant:not(.setup-assistant--step-0):not(.setup-assistant--step-9)
  .setup-assistant__page {
  padding-top: 103px;
}
.setup-assistant__page::-webkit-scrollbar {
  display: none;
}
.setup-assistant__page h1 {
  max-width: 340px;
  margin: 10px 0 9px;
  font-size: 34px;
  font-weight: 730;
  line-height: 1.02;
  letter-spacing: -0.045em;
}
.setup-assistant__lead {
  max-width: 325px;
  margin: 0;
  color: rgb(230 237 250/66%);
  font-size: 14px;
  line-height: 1.45;
}
.setup-assistant__eyebrow {
  margin: 13px 0 0;
  color: #65aaff;
  font-size: 10px;
  font-weight: 750;
  letter-spacing: 0.13em;
  text-transform: uppercase;
}
.setup-assistant__icon {
  display: grid;
  width: 80px;
  height: 80px;
  flex: none;
  place-items: center;
  border: 1px solid rgb(255 255 255/18%);
  border-radius: 25px;
  box-shadow:
    inset 0 1px rgb(255 255 255/22%),
    0 22px 50px rgb(0 0 0/28%);
  background: linear-gradient(
    145deg,
    rgb(255 255 255/18%),
    rgb(255 255 255/5%)
  );
  backdrop-filter: blur(18px);
}
.setup-assistant__icon--signal {
  color: #6fafff;
}
.setup-assistant__icon--cloud {
  color: #87bfff;
}
.setup-assistant__icon--security {
  color: #76e3aa;
}
.setup-assistant__icon--appearance {
  color: #c396ff;
}
.setup-assistant__icon--performance {
  color: #ffba61;
}
.setup-assistant__icon--wallpaper {
  color: #ef8cff;
}
.setup-assistant__icon--notifications {
  color: #ff7b72;
}
.setup-assistant__icon--apps {
  color: #79baff;
}
.setup-assistant__primary {
  width: 100%;
  min-height: 48px;
  margin-top: auto;
  border-radius: 16px !important;
  font-weight: 700;
}
.setup-assistant__later {
  padding: 12px;
  border: 0;
  color: #6eb0ff;
  background: transparent;
  font-size: 13px;
  font-weight: 650;
}
.setup-assistant__notice {
  display: flex;
  width: 100%;
  box-sizing: border-box;
  margin: 15px 0;
  padding: 13px;
  gap: 10px;
  align-items: flex-start;
  border: 1px solid rgb(255 255 255/8%);
  border-radius: 16px;
  color: #87b8ff;
  background: rgb(255 255 255/5%);
  text-align: left;
}
.setup-assistant__notice p {
  margin: 0;
  color: rgb(240 245 255/62%);
  font-size: 12px;
  line-height: 1.38;
}
.setup-assistant__error {
  margin: 4px 0;
  color: #ff8f88;
  font-size: 12px;
}
.setup-assistant--step-0 {
  background:
    radial-gradient(circle at 50% 24%, rgb(29 91 188 / 26%), transparent 31%),
    linear-gradient(180deg, #02050b 0%, #050712 58%, #02060c 100%);
}
.setup-assistant--step-0 .setup-assistant__aurora {
  inset: -20%;
  background:
    radial-gradient(circle at 21% 42%, rgb(24 106 255 / 22%), transparent 23%),
    radial-gradient(circle at 83% 36%, rgb(154 70 255 / 16%), transparent 24%),
    radial-gradient(circle at 50% 80%, rgb(0 211 177 / 10%), transparent 25%);
  filter: blur(40px);
}
.setup-assistant--step-0 .setup-assistant__page {
  padding: 64px 24px 0;
  overflow: hidden;
}
.setup-welcome__hero {
  position: relative;
  display: grid;
  width: 286px;
  height: 274px;
  flex: none;
  place-items: center;
  isolation: isolate;
}
.setup-welcome__hero::before {
  position: absolute;
  z-index: -1;
  top: 48px;
  right: 12px;
  bottom: 44px;
  left: 12px;
  background:
    linear-gradient(
      90deg,
      transparent,
      rgb(55 122 255 / 13%) 28%,
      rgb(121 91 255 / 11%) 72%,
      transparent
    ),
    linear-gradient(180deg, transparent, rgb(39 126 255 / 9%) 48%, transparent);
  filter: blur(22px);
  content: '';
  animation: setup-welcome-breathe 5s ease-in-out infinite;
}
.setup-welcome__hero::after {
  position: absolute;
  top: 51px;
  right: 28px;
  bottom: 47px;
  left: 28px;
  border-top: 1px solid rgb(142 184 255 / 9%);
  border-bottom: 1px solid rgb(142 184 255 / 9%);
  content: '';
}
.setup-welcome__greetings {
  position: relative;
  width: 100%;
  height: 104px;
  filter: drop-shadow(0 16px 30px rgb(15 89 255 / 20%));
}
.setup-welcome__greetings span {
  position: absolute;
  inset: 0;
  display: grid;
  color: #ffffff;
  font-family: 'Snell Roundhand', 'Segoe Script', 'Brush Script MT', cursive;
  font-size: 68px;
  font-weight: 500;
  letter-spacing: -0.06em;
  opacity: 0;
  place-items: center;
  transform: translateY(12px) scale(0.94);
  animation: setup-welcome-language 9s cubic-bezier(0.22, 1, 0.36, 1) infinite;
}
.setup-welcome__greetings span:nth-child(2) {
  animation-delay: 3s;
}
.setup-welcome__greetings span:nth-child(3) {
  animation-delay: 6s;
}
.setup-welcome__signature {
  position: absolute;
  bottom: 66px;
  display: flex;
  align-items: center;
  gap: 5px;
}
.setup-welcome__signature span {
  width: 22px;
  height: 2px;
  background: rgb(109 170 255 / 20%);
}
.setup-welcome__signature span:nth-child(2) {
  width: 42px;
  background: linear-gradient(90deg, #4b9fff, #9677ff);
  box-shadow: 0 0 12px rgb(73 148 255 / 34%);
}
.setup-welcome__copy {
  position: relative;
  z-index: 1;
  margin-top: -13px;
}
.setup-welcome__copy h1 {
  margin-top: 8px;
  font-size: 31px;
}
.setup-welcome__eyebrow {
  margin: 0;
  color: #67aaff;
  font-size: 10px;
  font-weight: 760;
  letter-spacing: 0.16em;
  text-transform: uppercase;
}
.setup-welcome__copy .setup-assistant__lead {
  max-width: 300px;
  margin-inline: auto;
}
.setup-welcome__footer {
  display: flex;
  width: calc(100% + 48px);
  box-sizing: border-box;
  margin: auto -24px 0;
  padding: 17px 24px 13px;
  flex-direction: column;
  align-items: center;
  border-top: 1px solid rgb(255 255 255 / 7%);
  background: linear-gradient(
    180deg,
    rgb(7 10 20 / 30%),
    rgb(4 7 13 / 94%) 28%
  );
  backdrop-filter: blur(24px);
}
.setup-welcome__privacy {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 9px;
  color: rgb(226 235 250 / 56%);
  font-size: 9px;
  font-weight: 600;
}
.setup-welcome__privacy span {
  display: inline-flex;
  align-items: center;
  gap: 5px;
}
.setup-welcome__privacy i {
  width: 2px;
  height: 2px;
  border-radius: 50%;
  background: rgb(255 255 255 / 28%);
}
.setup-welcome__footer .setup-assistant__primary {
  min-height: 51px;
  margin-top: 14px;
  border-radius: 15px !important;
  box-shadow: 0 12px 30px rgb(0 105 255 / 24%);
}
.setup-welcome__home-indicator {
  width: 112px;
  height: 4px;
  margin-top: 12px;
  border-radius: 99px;
  background: rgb(255 255 255 / 92%);
}
@keyframes setup-welcome-language {
  0% {
    opacity: 0;
    transform: translateY(12px) scale(0.94);
    filter: blur(5px);
  }
  8%,
  27% {
    opacity: 1;
    transform: translateY(0) scale(1);
    filter: blur(0);
  }
  34%,
  100% {
    opacity: 0;
    transform: translateY(-10px) scale(1.03);
    filter: blur(4px);
  }
}
@keyframes setup-welcome-breathe {
  0%,
  100% {
    transform: scaleX(0.92);
    opacity: 0.58;
  }
  50% {
    transform: scaleX(1.04);
    opacity: 1;
  }
}
.setup-connectivity-card {
  position: relative;
  width: 100%;
  min-height: 150px;
  box-sizing: border-box;
  margin-top: 22px;
  padding: 20px;
  overflow: hidden;
  border: 1px solid rgb(255 255 255/14%);
  border-radius: 25px;
  background: linear-gradient(135deg, #18345f, #0a1730 68%);
  box-shadow: 0 25px 55px rgb(0 0 0/25%);
  text-align: left;
}
.setup-connectivity-card__waves {
  position: absolute;
  width: 200px;
  height: 200px;
  right: -90px;
  top: -90px;
  border: 32px solid rgb(104 171 255/8%);
  border-radius: 50%;
  box-shadow:
    0 0 0 28px rgb(104 171 255/6%),
    0 0 0 58px rgb(104 171 255/4%);
}
.setup-connectivity-card__label {
  display: block;
  color: #8dc0ff;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.1em;
}
.setup-connectivity-card strong {
  display: block;
  margin-top: 28px;
  font-size: 22px;
  letter-spacing: -0.03em;
}
.setup-connectivity-card > span:last-of-type {
  color: rgb(255 255 255/55%);
  font-size: 12px;
}
.setup-connectivity-card svg {
  position: absolute;
  right: 20px;
  bottom: 20px;
  color: #7fb7ff;
}
.setup-cloud-form,
.setup-cloud-connected {
  display: flex;
  width: 100%;
  margin-top: 19px;
  gap: 10px;
  flex-direction: column;
}
.setup-assistant--step-2 .setup-assistant__page {
  padding-right: 24px;
  padding-bottom: 16px;
  padding-left: 24px;
}
.setup-assistant--step-2 .setup-assistant__page h1 {
  max-width: 315px;
  margin: 7px 0 6px;
  font-size: 29px;
}
.setup-cloud-heading {
  display: flex;
  width: 100%;
  flex-direction: column;
  align-items: center;
}
.setup-assistant--step-2 .setup-assistant__lead {
  max-width: 310px;
  font-size: 12px;
  line-height: 1.35;
}
.setup-assistant--step-2 .setup-assistant__eyebrow {
  margin-top: 8px;
}
.setup-cloud-hero {
  position: relative;
  display: grid;
  width: 70px;
  height: 70px;
  flex: none;
  margin-top: -2px;
  place-items: center;
  color: #b8d7ff;
}
.setup-cloud-hero__orbit {
  position: absolute;
  inset: 0;
  border: 1px solid rgb(112 174 255 / 26%);
  border-radius: 50%;
  box-shadow: inset 0 0 22px rgb(50 131 255 / 12%);
  animation: setup-cloud-orbit 9s linear infinite;
}
.setup-cloud-hero__orbit::before,
.setup-cloud-hero__orbit::after {
  position: absolute;
  inset: 7px -7px;
  border: 1px solid rgb(130 104 255 / 16%);
  border-radius: 50%;
  content: '';
  transform: rotate(58deg);
}
.setup-cloud-hero__orbit::after {
  transform: rotate(-58deg);
}
.setup-cloud-hero__glow {
  position: absolute;
  inset: 13px;
  border-radius: 50%;
  background: rgb(38 125 255 / 22%);
  box-shadow: 0 0 35px 10px rgb(39 115 255 / 22%);
}
.setup-cloud-hero svg {
  position: relative;
  filter: drop-shadow(0 6px 12px rgb(25 102 255 / 42%));
}
.setup-cloud-hero i {
  position: absolute;
  width: 3px;
  height: 3px;
  border-radius: 50%;
  background: #8ac1ff;
  box-shadow: 0 0 8px #479eff;
}
.setup-cloud-hero i:nth-of-type(1) {
  top: 2px;
  left: 23px;
}
.setup-cloud-hero i:nth-of-type(2) {
  right: -1px;
  bottom: 25px;
}
.setup-cloud-hero i:nth-of-type(3) {
  bottom: 3px;
  left: 11px;
}
.setup-cloud-form {
  margin-top: 11px;
  gap: 7px;
}
.setup-cloud-identity {
  display: flex;
  min-height: 47px;
  padding: 6px 10px;
  box-sizing: border-box;
  align-items: center;
  gap: 10px;
  border: 1px solid rgb(113 170 255 / 12%);
  border-radius: 16px;
  background: linear-gradient(
    135deg,
    rgb(49 115 213 / 14%),
    rgb(255 255 255 / 4%)
  );
  text-align: left;
}
.setup-cloud-identity > span {
  display: grid;
  width: 32px;
  height: 32px;
  flex: none;
  border: 1px solid rgb(255 255 255 / 16%);
  border-radius: 50%;
  background: linear-gradient(145deg, #398ff6, #6d5bea);
  box-shadow:
    inset 0 1px rgb(255 255 255 / 28%),
    0 8px 18px rgb(27 91 208 / 20%);
  color: white;
  font-size: 15px;
  font-style: normal;
  font-weight: 750;
  place-items: center;
}
.setup-cloud-identity div {
  min-width: 0;
  flex: 1;
}
.setup-cloud-identity small,
.setup-cloud-identity strong {
  display: block;
}
.setup-cloud-identity small {
  color: rgb(255 255 255 / 43%);
  font-size: 8px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}
.setup-cloud-identity strong {
  margin-top: 2px;
  overflow: hidden;
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.setup-cloud-identity em {
  color: #8dbdff;
  font-style: normal;
  font-weight: 600;
}
.setup-cloud-identity > svg {
  color: #67d99d;
}
.setup-cloud-fields {
  overflow: hidden;
  border: 1px solid rgb(255 255 255 / 9%);
  border-radius: 17px;
  background: rgb(255 255 255 / 5%);
}
.setup-account-field-enter-active,
.setup-account-field-leave-active {
  overflow: hidden;
  transition:
    max-height 280ms cubic-bezier(0.32, 0.72, 0, 1),
    opacity 180ms ease,
    transform 280ms cubic-bezier(0.32, 0.72, 0, 1);
}
.setup-account-field-enter-from,
.setup-account-field-leave-to {
  max-height: 0;
  opacity: 0;
  transform: translateY(-8px);
}
.setup-account-field-enter-to,
.setup-account-field-leave-from {
  max-height: 58px;
  opacity: 1;
  transform: translateY(0);
}
.setup-cloud-fields :deep(.sky-field) {
  border: 0;
  border-radius: 0;
  background: transparent;
}
.setup-cloud-fields :deep(.sky-field__inner) {
  padding: 0;
}
.setup-cloud-fields :deep(.sky-field + .sky-field) {
  border-top: 1px solid rgb(255 255 255 / 8%);
}
.setup-cloud-fields :deep(.sky-field) {
  padding: 3px 12px;
}
.setup-cloud-fields :deep(.sky-field__control),
.setup-cloud-fields :deep(.sky-field__input) {
  min-height: 43px;
}
.setup-cloud-fields :deep(.sky-field--floating-label .sky-field__control) {
  min-height: 52px;
}
.setup-cloud-fields :deep(.sky-field--floating-label .sky-field__label) {
  top: 6px;
  left: 12px;
}
.setup-cloud-fields :deep(.sky-field__label) {
  color: rgb(255 255 255 / 52%);
}
.setup-cloud-fields :deep(.sky-field__input) {
  color: #ffffff;
  caret-color: #5ba9ff;
}
.setup-cloud-fields :deep(.sky-field__input::placeholder) {
  color: rgb(255 255 255 / 24%);
}
.setup-cloud-suffix {
  color: #82b8ff;
  font-size: 11px;
  font-weight: 650;
  white-space: nowrap;
}
.setup-cloud-strength {
  display: flex;
  align-items: center;
  gap: 9px;
  color: rgb(255 255 255 / 42%);
  font-size: 9px;
}
.setup-cloud-strength > div {
  display: flex;
  flex: 1;
  gap: 4px;
}
.setup-cloud-strength span {
  height: 3px;
  flex: 1;
  border-radius: 99px;
  background: rgb(255 255 255 / 10%);
}
.setup-cloud-strength span.active {
  background: linear-gradient(90deg, #318bff, #66c0ff);
  box-shadow: 0 0 7px rgb(49 139 255 / 34%);
}
.setup-account-strength-enter-active,
.setup-account-strength-leave-active {
  transition:
    opacity 180ms ease,
    transform 240ms cubic-bezier(0.32, 0.72, 0, 1);
}
.setup-account-strength-enter-from,
.setup-account-strength-leave-to {
  opacity: 0;
  transform: translateY(-5px);
}
.setup-cloud-security-note {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
  color: rgb(199 215 238 / 46%);
  font-size: 9px;
}
.setup-assistant--step-2 .setup-assistant__primary {
  min-height: 46px;
}
.setup-assistant--step-2 .setup-assistant__later {
  padding: 7px;
}
@keyframes setup-cloud-orbit {
  to {
    transform: rotate(360deg);
  }
}
.setup-assistant__selector {
  position: relative;
  display: grid;
  padding: 3px;
  grid-template-columns: 1fr 1fr;
  border-radius: 13px;
  background: rgb(255 255 255/8%);
}
.setup-assistant__selector-indicator {
  position: absolute;
  z-index: 0;
  top: 3px;
  bottom: 3px;
  left: 3px;
  width: calc(50% - 3px);
  border: 1px solid rgb(255 255 255 / 7%);
  border-radius: 10px;
  background: rgb(255 255 255 / 13%);
  box-shadow:
    0 3px 12px rgb(0 0 0 / 20%),
    inset 0 1px rgb(255 255 255 / 7%);
  transition: transform 320ms cubic-bezier(0.32, 0.72, 0, 1);
}
.setup-assistant__selector-indicator--register {
  transform: translateX(100%);
}
.setup-assistant__selector button {
  position: relative;
  z-index: 1;
  height: 34px;
  border: 0;
  border-radius: 10px;
  color: rgb(255 255 255/55%);
  background: transparent;
  font-weight: 650;
  transition: color 220ms ease;
}
.setup-assistant__selector button.active {
  color: white;
}
.setup-account-copy-enter-active,
.setup-account-copy-leave-active {
  transition:
    opacity 170ms ease,
    transform 230ms cubic-bezier(0.32, 0.72, 0, 1);
}
.setup-account-copy-enter-from {
  opacity: 0;
  transform: translateY(7px);
}
.setup-account-copy-leave-to {
  opacity: 0;
  transform: translateY(-5px);
}
.setup-account-action-enter-active,
.setup-account-action-leave-active {
  transition:
    opacity 140ms ease,
    transform 180ms ease;
}
.setup-account-action-enter-from {
  opacity: 0;
  transform: translateY(5px);
}
.setup-account-action-leave-to {
  opacity: 0;
  transform: translateY(-5px);
}
.setup-cloud-connected {
  align-items: center;
  padding-top: 35px;
  color: #7ee2ad;
}
.setup-cloud-connected strong {
  color: white;
  font-size: 18px;
}
.setup-cloud-connected span {
  color: rgb(255 255 255/55%);
  font-size: 13px;
}
.setup-security-visual {
  position: relative;
  display: grid;
  width: 100%;
  height: 108px;
  margin-top: 17px;
  place-items: center;
  border: 1px solid rgb(255 255 255/9%);
  border-radius: 24px;
  background: linear-gradient(145deg, rgb(46 187 120/15%), rgb(255 255 255/4%));
}
.setup-security-visual > div {
  display: flex;
  gap: 9px;
}
.setup-security-visual span {
  width: 11px;
  height: 11px;
  border-radius: 50%;
  background: #8fe4b6;
  box-shadow: 0 0 15px rgb(88 222 149/38%);
}
.setup-security-visual svg {
  position: absolute;
  right: 18px;
  bottom: 15px;
  color: rgb(126 226 173/32%);
}
.setup-passcode-length {
  display: grid;
  width: 100%;
  margin-top: 12px;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
}
.setup-passcode-length button {
  display: flex;
  min-height: 57px;
  padding: 9px 11px;
  align-items: center;
  justify-content: space-between;
  border: 1px solid rgb(255 255 255 / 9%);
  border-radius: 16px;
  color: #ffffff;
  background: rgb(255 255 255 / 5%);
  text-align: left;
  transition:
    border-color 160ms ease,
    background 160ms ease,
    transform 120ms ease;
}
.setup-passcode-length button:active {
  transform: scale(0.975);
}
.setup-passcode-length button.selected {
  border-color: rgb(94 172 255 / 72%);
  background: linear-gradient(
    145deg,
    rgb(42 132 245 / 23%),
    rgb(64 96 210 / 10%)
  );
  box-shadow:
    inset 0 1px rgb(255 255 255 / 9%),
    0 9px 22px rgb(23 91 193 / 12%);
}
.setup-passcode-length button > span,
.setup-passcode-length b,
.setup-passcode-length small {
  display: block;
}
.setup-passcode-length b {
  font-size: 18px;
  line-height: 1;
}
.setup-passcode-length small {
  margin-top: 4px;
  color: rgb(255 255 255 / 48%);
  font-size: 9px;
}
.setup-passcode-length svg {
  padding: 3px;
  border-radius: 50%;
  background: #318cf5;
}
.setup-assistant--step-3 .setup-assistant__notice {
  margin: 12px 0;
}
.setup-choice-grid {
  display: grid;
  width: 100%;
  margin-top: 22px;
  grid-template-columns: repeat(3, 1fr);
  gap: 8px;
}
.setup-choice-grid button {
  position: relative;
  padding: 9px 7px 12px;
  border: 1px solid rgb(255 255 255/9%);
  border-radius: 19px;
  color: white;
  background: rgb(255 255 255/5%);
}
.setup-choice-grid button.selected {
  border-color: #559eff;
  background: rgb(57 125 235/15%);
}
.setup-choice-grid button > svg {
  position: absolute;
  top: 7px;
  right: 7px;
  padding: 2px;
  border-radius: 50%;
  background: #398cf5;
}
.setup-choice-grid strong {
  display: block;
  margin-top: 9px;
  font-size: 11px;
}
.setup-appearance-preview {
  display: flex;
  height: 92px;
  padding: 8px;
  gap: 5px;
  flex-direction: column;
  border-radius: 12px;
  background: #f5f6f8;
}
.setup-appearance-preview i {
  display: block;
  height: 14px;
  border-radius: 4px;
  background: #d8dbe0;
}
.setup-appearance-preview i:first-child {
  width: 58%;
  height: 25px;
  background: #18191d;
}
.setup-appearance-preview--dark {
  background: #17181c;
}
.setup-appearance-preview--dark i {
  background: #31333a;
}
.setup-appearance-preview--dark i:first-child {
  background: #f6f7fa;
}
.setup-appearance-preview--automatic {
  background: linear-gradient(135deg, #f5f6f8 50%, #17181c 50%);
}
.setup-appearance-preview--automatic i {
  background: rgb(120 122 130/40%);
}
.setup-mode-stack {
  display: flex;
  width: 100%;
  margin-top: 22px;
  gap: 10px;
  flex-direction: column;
}
.setup-mode-stack button {
  display: grid;
  min-height: 95px;
  padding: 13px;
  grid-template-columns: 65px 1fr 25px;
  gap: 13px;
  align-items: center;
  border: 1px solid rgb(255 255 255/9%);
  border-radius: 21px;
  color: white;
  background: rgb(255 255 255/5%);
  text-align: left;
}
.setup-mode-stack button.selected {
  border-color: rgb(96 166 255/75%);
  background: linear-gradient(100deg, rgb(41 110 204/22%), rgb(255 255 255/5%));
}
.setup-mode-stack__orb {
  width: 62px;
  height: 62px;
  border-radius: 20px;
  background: linear-gradient(145deg, #3e82e8, #172a4c);
  box-shadow: inset 0 1px rgb(255 255 255/25%);
}
.setup-mode-stack__orb--ultimate {
  background: radial-gradient(
    circle at 28% 25%,
    #f2a7ff,
    #6755d5 40%,
    #142544 80%
  );
  box-shadow:
    0 8px 25px rgb(139 82 238/25%),
    inset 0 1px rgb(255 255 255/45%);
}
.setup-mode-stack strong,
.setup-mode-stack small {
  display: block;
}
.setup-mode-stack strong {
  font-size: 15px;
}
.setup-mode-stack small {
  margin-top: 4px;
  color: rgb(255 255 255/48%);
  font-size: 11px;
  line-height: 1.3;
}
.setup-mode-stack__check {
  display: grid;
  width: 22px;
  height: 22px;
  place-items: center;
  border: 1px solid rgb(255 255 255/20%);
  border-radius: 50%;
}
.selected .setup-mode-stack__check {
  border-color: #4b9aff;
  background: #398cf5;
}
.setup-wallpapers {
  display: grid;
  width: 100%;
  margin: 19px 0 15px;
  grid-template-columns: repeat(4, 1fr);
  gap: 9px;
}
.setup-wallpapers button {
  position: relative;
  height: 82px;
  overflow: hidden;
  border: 2px solid transparent;
  border-radius: 17px;
  box-shadow: inset 0 0 0 1px rgb(255 255 255/12%);
}
.setup-wallpapers button.selected {
  border-color: white;
  box-shadow: 0 0 0 2px #328aff;
}
.setup-wallpapers svg {
  position: absolute;
  right: 5px;
  bottom: 5px;
  padding: 3px;
  border-radius: 50%;
  background: #2585f5;
}
.setup-toggle-card {
  width: 100%;
  margin-top: 25px;
  overflow: hidden;
  border: 1px solid rgb(255 255 255/9%);
  border-radius: 22px;
  background: rgb(255 255 255/5%);
}
.setup-toggle-card button {
  display: flex;
  width: 100%;
  min-height: 82px;
  padding: 14px;
  align-items: center;
  justify-content: space-between;
  border: 0;
  color: white;
  background: transparent;
  text-align: left;
}
.setup-toggle-card button + button {
  border-top: 1px solid rgb(255 255 255/8%);
}
.setup-toggle-card button:disabled {
  opacity: 0.4;
}
.setup-toggle-card strong,
.setup-toggle-card small {
  display: block;
}
.setup-toggle-card strong {
  font-size: 14px;
}
.setup-toggle-card small {
  max-width: 245px;
  margin-top: 3px;
  color: rgb(255 255 255/48%);
  font-size: 11px;
}
.setup-toggle-card i {
  position: relative;
  width: 45px;
  height: 27px;
  flex: none;
  border-radius: 99px;
  background: #3b3d43;
  transition: 0.2s;
}
.setup-toggle-card i b {
  position: absolute;
  width: 23px;
  height: 23px;
  left: 2px;
  top: 2px;
  border-radius: 50%;
  background: white;
  box-shadow: 0 2px 6px rgb(0 0 0/30%);
  transition: 0.2s;
}
.setup-toggle-card i.on {
  background: #34c759;
}
.setup-toggle-card i.on b {
  transform: translateX(18px);
}
.setup-app-list {
  display: grid;
  width: 100%;
  margin: 16px 0 14px;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
}
.setup-app-list button {
  display: grid;
  min-height: 79px;
  padding: 10px;
  grid-template-columns: 42px 1fr;
  gap: 9px;
  align-items: center;
  border: 1px solid rgb(255 255 255/8%);
  border-radius: 17px;
  color: white;
  background: rgb(255 255 255/5%);
  text-align: left;
}
.setup-app-list button.selected {
  border-color: rgb(75 149 249/65%);
  background: rgb(52 123 222/13%);
}
.setup-app-list img {
  width: 42px;
  height: 42px;
  border-radius: 12px;
}
.setup-app-list strong,
.setup-app-list small {
  display: block;
}
.setup-app-list strong {
  overflow: hidden;
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.setup-app-list small {
  margin-top: 2px;
  color: rgb(255 255 255/45%);
  font-size: 9px;
  line-height: 1.2;
}
.setup-app-list i {
  position: absolute;
}
.setup-app-list button {
  position: relative;
}
.setup-app-list button > i {
  display: grid;
  width: 18px;
  height: 18px;
  right: 6px;
  top: 6px;
  place-items: center;
  border: 1px solid rgb(255 255 255/23%);
  border-radius: 50%;
}
.setup-app-list button.selected > i {
  border-color: #3d95ff;
  background: #3388ee;
}
.setup-ready__halo {
  display: grid;
  width: 144px;
  height: 144px;
  margin-top: 70px;
  place-items: center;
  border: 1px solid rgb(255 255 255/20%);
  border-radius: 50%;
  color: white;
  background: radial-gradient(
    circle,
    #418df0,
    #2852b2 48%,
    rgb(61 85 192/12%) 70%
  );
  box-shadow:
    0 0 90px rgb(45 111 255/45%),
    inset 0 1px rgb(255 255 255/45%);
}
.setup-ready__summary {
  display: flex;
  width: 100%;
  margin: 28px 0 20px;
  gap: 8px;
  flex-direction: column;
}
.setup-ready__summary span {
  display: flex;
  padding: 12px 14px;
  gap: 10px;
  align-items: center;
  border: 1px solid rgb(255 255 255/8%);
  border-radius: 14px;
  color: #7db7ff;
  background: rgb(255 255 255/5%);
  text-align: left;
}
.setup-ready__summary b {
  overflow: hidden;
  color: rgb(255 255 255/74%);
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
@keyframes setup-aurora {
  to {
    transform: translate3d(8%, -5%, 0) rotate(8deg);
  }
}
.setup-forward-enter-active,
.setup-forward-leave-active,
.setup-back-enter-active,
.setup-back-leave-active {
  transition:
    opacity 0.22s ease,
    transform 0.28s cubic-bezier(0.2, 0.8, 0.2, 1);
}
.setup-forward-enter-from {
  opacity: 0;
  transform: translateX(24px);
}
.setup-forward-leave-to {
  opacity: 0;
  transform: translateX(-16px);
}
.setup-back-enter-from {
  opacity: 0;
  transform: translateX(-24px);
}
.setup-back-leave-to {
  opacity: 0;
  transform: translateX(16px);
}

/* Minimal system setup language, matching the restrained iOS setup hierarchy. */
.setup-assistant,
.setup-assistant--step-0 {
  --setup-background: #ffffff;
  --setup-text: #1d1d1f;
  --setup-secondary: #6e6e73;
  --setup-tertiary: #8e8e93;
  --setup-muted: #aeaeb2;
  --setup-surface: #f2f2f7;
  --setup-selected-surface: #eef6ff;
  --setup-control: #e9e9eb;
  --setup-control-fill: #ffffff;
  --setup-separator: #d1d1d6;
  --setup-blue: #007aff;
  --setup-green: #34c759;
  --setup-red: #ff3b30;
  --setup-orb: #dcecff;
  --setup-orb-ultimate: #e7e2ff;
  --setup-home-indicator: #1d1d1f;
  color: var(--setup-text);
  background: var(--setup-background);
}
.setup-assistant--dark,
.setup-assistant--dark.setup-assistant--step-0 {
  --setup-background: #000000;
  --setup-text: #f5f5f7;
  --setup-secondary: #98989d;
  --setup-tertiary: #8e8e93;
  --setup-muted: #636366;
  --setup-surface: #1c1c1e;
  --setup-selected-surface: #102a43;
  --setup-control: #2c2c2e;
  --setup-control-fill: #636366;
  --setup-separator: #38383a;
  --setup-blue: #0a84ff;
  --setup-green: #30d158;
  --setup-red: #ff453a;
  --setup-orb: #102a43;
  --setup-orb-ultimate: #28203d;
  --setup-home-indicator: #ffffff;
}
.setup-assistant__development-skip {
  top: 48px;
  right: 13px;
  border: 0;
  color: var(--setup-blue);
  background: transparent;
  font-size: 11px;
  font-weight: 600;
}
.setup-assistant__chrome {
  gap: 10px;
}
.setup-assistant__back {
  border: 0;
  color: var(--setup-blue);
  background: transparent;
  backdrop-filter: none;
}
.setup-assistant__progress {
  height: 3px;
  background: var(--setup-separator);
}
.setup-assistant__progress span {
  background: var(--setup-blue);
}
.setup-assistant__counter {
  color: var(--setup-tertiary);
  font-weight: 600;
}
.setup-assistant__page h1 {
  margin: 12px 0 10px;
  color: var(--setup-text);
  font-size: 31px;
  font-weight: 700;
  line-height: 1.08;
  letter-spacing: -0.04em;
}
.setup-assistant__lead {
  color: var(--setup-secondary);
  font-size: 14px;
  line-height: 1.42;
}
.setup-assistant__eyebrow,
.setup-welcome__eyebrow {
  display: none;
}
.setup-assistant__icon {
  width: 72px;
  height: 72px;
  border: 0;
  border-radius: 50%;
  color: var(--setup-blue);
  background: var(--setup-surface);
  box-shadow: none;
  backdrop-filter: none;
}
.setup-assistant__icon--signal,
.setup-assistant__icon--cloud,
.setup-assistant__icon--security,
.setup-assistant__icon--appearance,
.setup-assistant__icon--performance,
.setup-assistant__icon--wallpaper,
.setup-assistant__icon--notifications,
.setup-assistant__icon--apps {
  color: var(--setup-blue);
}
.setup-assistant__primary {
  min-height: 50px;
  border-radius: 14px !important;
  background: var(--setup-blue) !important;
  box-shadow: none !important;
  font-weight: 650;
}
.setup-assistant__later {
  color: var(--setup-blue);
  font-weight: 500;
}
.setup-assistant__notice {
  padding: 5px 4px;
  border: 0;
  color: var(--setup-blue);
  background: transparent;
}
.setup-assistant__notice p {
  color: var(--setup-secondary);
}
.setup-assistant__error {
  color: var(--setup-red);
}
.setup-assistant--step-0 .setup-assistant__page {
  padding: 105px 28px 0;
}
.setup-welcome__hero {
  width: 94px;
  height: 94px;
  border-radius: 50%;
  background: var(--setup-surface);
}
.setup-welcome__hero::before,
.setup-welcome__hero::after {
  content: none;
}
.setup-welcome__device {
  display: grid;
  width: 94px;
  height: 94px;
  color: var(--setup-blue);
  place-items: center;
}
.setup-welcome__copy {
  margin-top: 31px;
}
.setup-welcome__copy h1 {
  margin-top: 0;
  font-size: 32px;
}
.setup-welcome__footer {
  width: calc(100% + 56px);
  margin-right: -28px;
  margin-left: -28px;
  padding: 0 28px 13px;
  border: 0;
  background: var(--setup-background);
  backdrop-filter: none;
}
.setup-welcome__footer .setup-assistant__primary {
  margin-top: 0;
  box-shadow: none;
}
.setup-welcome__home-indicator {
  background: var(--setup-home-indicator);
}
.setup-connectivity-card {
  min-height: 142px;
  border: 0;
  border-radius: 22px;
  color: var(--setup-text);
  background: var(--setup-surface);
  box-shadow: none;
}
.setup-connectivity-card__waves {
  display: none;
}
.setup-connectivity-card__label,
.setup-connectivity-card svg {
  color: var(--setup-blue);
}
.setup-connectivity-card > span:last-of-type {
  color: var(--setup-tertiary);
}
.setup-cloud-hero {
  width: 72px;
  height: 72px;
  border-radius: 50%;
  color: var(--setup-blue);
  background: var(--setup-surface);
}
.setup-cloud-hero__orbit,
.setup-cloud-hero__glow,
.setup-cloud-hero i {
  display: none;
}
.setup-cloud-hero svg {
  filter: none;
}
.setup-cloud-identity {
  border: 0;
  background: var(--setup-surface);
}
.setup-cloud-identity > span {
  border: 0;
  background: var(--setup-blue);
  box-shadow: none;
}
.setup-cloud-identity small,
.setup-cloud-strength,
.setup-cloud-security-note {
  color: var(--setup-tertiary);
}
.setup-cloud-identity strong,
.setup-cloud-connected strong {
  color: var(--setup-text);
}
.setup-cloud-identity em,
.setup-cloud-suffix {
  color: var(--setup-blue);
}
.setup-cloud-fields {
  border: 0;
  background: var(--setup-surface);
}
.setup-cloud-fields :deep(.sky-field + .sky-field) {
  border-top-color: var(--setup-separator);
}
.setup-cloud-fields :deep(.sky-field__label) {
  color: var(--setup-tertiary);
}
.setup-cloud-fields :deep(.sky-field__input) {
  color: var(--setup-text);
  caret-color: var(--setup-blue);
}
.setup-cloud-fields :deep(.sky-field__input::placeholder) {
  color: var(--setup-muted);
}
.setup-cloud-strength span {
  background: var(--setup-separator);
}
.setup-cloud-strength span.active {
  background: var(--setup-blue);
  box-shadow: none;
}
.setup-assistant__selector {
  background: var(--setup-control);
}
.setup-assistant__selector-indicator {
  border: 0;
  background: var(--setup-control-fill);
  box-shadow: 0 1px 4px rgb(0 0 0 / 14%);
}
.setup-assistant__selector button {
  color: var(--setup-secondary);
}
.setup-assistant__selector button.active {
  color: var(--setup-text);
}
.setup-cloud-connected {
  color: var(--setup-green);
}
.setup-cloud-connected span {
  color: var(--setup-secondary);
}
.setup-security-visual {
  border: 0;
  background: var(--setup-surface);
}
.setup-security-visual span {
  background: var(--setup-text);
  box-shadow: none;
}
.setup-security-visual svg {
  color: var(--setup-muted);
}
.setup-passcode-length button,
.setup-choice-grid button,
.setup-mode-stack button,
.setup-toggle-card,
.setup-app-list button,
.setup-ready__summary span {
  border-color: transparent;
  color: var(--setup-text);
  background: var(--setup-surface);
  box-shadow: none;
}
.setup-passcode-length button.selected,
.setup-choice-grid button.selected,
.setup-mode-stack button.selected,
.setup-app-list button.selected {
  border-color: var(--setup-blue);
  background: var(--setup-selected-surface);
  box-shadow: none;
}
.setup-passcode-length small,
.setup-mode-stack small,
.setup-toggle-card small,
.setup-app-list small {
  color: var(--setup-secondary);
}
.setup-mode-stack__orb {
  position: relative;
  overflow: hidden;
  isolation: isolate;
  border-radius: 18px;
  background: var(--setup-orb);
  box-shadow: none;
}
.setup-mode-stack__orb--ultimate {
  background: var(--setup-orb-ultimate);
  box-shadow: none;
}
.setup-mode-preview__backdrop,
.setup-mode-preview__card,
.setup-mode-preview__line {
  position: absolute;
  display: block;
  pointer-events: none;
}
.setup-mode-preview__backdrop {
  inset: 0;
  background: linear-gradient(145deg, #d9eaff 0%, #b9d8ff 100%);
}
.setup-mode-preview__card {
  width: 37px;
  height: 26px;
  border-radius: 8px;
}
.setup-mode-preview__card--back {
  top: 11px;
  left: 9px;
  background: #ffffff;
}
.setup-mode-preview__card--front {
  right: 8px;
  bottom: 10px;
  background: #e7f1ff;
}
.setup-mode-preview__line {
  z-index: 2;
  right: 15px;
  bottom: 17px;
  width: 17px;
  height: 3px;
  border-radius: 999px;
  background: #5d80ad;
}
.setup-mode-preview__line--wide {
  bottom: 23px;
  width: 24px;
}
.setup-mode-stack__orb--ultimate .setup-mode-preview__backdrop {
  background:
    radial-gradient(circle at 20% 25%, #f4c7ff 0 12%, transparent 35%),
    linear-gradient(145deg, #776de4 0%, #342760 100%);
}
.setup-mode-stack__orb--ultimate .setup-mode-preview__card {
  border: 1px solid rgb(255 255 255 / 38%);
  background: rgb(255 255 255 / 25%);
  box-shadow: 0 7px 14px rgb(31 18 70 / 24%);
  backdrop-filter: blur(5px);
}
.setup-mode-stack__orb--ultimate .setup-mode-preview__card--back {
  transform: rotate(-8deg);
}
.setup-mode-stack__orb--ultimate .setup-mode-preview__card--front {
  background: rgb(255 255 255 / 34%);
  transform: rotate(5deg);
}
.setup-mode-stack__orb--ultimate .setup-mode-preview__line {
  background: rgb(255 255 255 / 72%);
}
.setup-assistant--dark
  .setup-mode-stack__orb--performance
  .setup-mode-preview__backdrop {
  background: linear-gradient(145deg, #203147 0%, #142133 100%);
}
.setup-assistant--dark
  .setup-mode-stack__orb--performance
  .setup-mode-preview__card--back {
  background: #334965;
}
.setup-assistant--dark
  .setup-mode-stack__orb--performance
  .setup-mode-preview__card--front {
  background: #29405d;
}
.setup-assistant--dark
  .setup-mode-stack__orb--performance
  .setup-mode-preview__line {
  background: #a9c7e9;
}
.setup-mode-stack__check,
.setup-app-list button > i {
  border-color: var(--setup-muted);
}
.selected .setup-mode-stack__check,
.setup-app-list button.selected > i {
  border-color: var(--setup-blue);
  background: var(--setup-blue);
}
.setup-wallpapers button.selected {
  border-color: var(--setup-background);
  box-shadow: 0 0 0 2px var(--setup-blue);
}
.setup-toggle-card {
  border: 0;
}
.setup-toggle-card button {
  color: var(--setup-text);
}
.setup-toggle-card button + button {
  border-top-color: var(--setup-separator);
}
.setup-toggle-card i {
  background: var(--setup-separator);
}
.setup-ready__halo {
  width: 112px;
  height: 112px;
  border: 0;
  color: var(--setup-blue);
  background: var(--setup-surface);
  box-shadow: none;
}
.setup-ready__summary span {
  color: var(--setup-blue);
}
.setup-ready__summary b {
  color: var(--setup-text);
}
.setup-assistant--performance .setup-forward-enter-active,
.setup-assistant--performance .setup-forward-leave-active,
.setup-assistant--performance .setup-back-enter-active,
.setup-assistant--performance .setup-back-leave-active,
.setup-assistant--performance .setup-assistant__progress span,
.setup-assistant--performance .setup-mode-stack button,
.setup-assistant--performance .setup-mode-stack__orb {
  transition-duration: 0.01ms;
}
.setup-assistant--ultimate .setup-mode-stack button,
.setup-assistant--ultimate .setup-mode-stack__orb {
  transition:
    border-color 0.2s ease,
    background-color 0.2s ease,
    transform 0.2s cubic-bezier(0.2, 0.8, 0.2, 1);
}
@media (prefers-reduced-motion: reduce) {
  .setup-assistant,
  .setup-assistant *,
  .setup-assistant *::before,
  .setup-assistant *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    scroll-behavior: auto !important;
    transition-duration: 0.01ms !important;
  }

  .setup-assistant__aurora,
  .setup-welcome__hero::before,
  .setup-cloud-hero__orbit {
    animation: none;
  }

  .setup-welcome__greetings span {
    opacity: 0;
    animation: none;
    transform: none;
  }

  .setup-welcome__greetings span:first-child {
    opacity: 1;
  }

  .setup-forward-enter-active,
  .setup-forward-leave-active,
  .setup-back-enter-active,
  .setup-back-leave-active {
    transition-duration: 0.01ms;
  }

  .setup-forward-enter-from,
  .setup-forward-leave-to,
  .setup-back-enter-from,
  .setup-back-leave-to,
  .setup-account-field-enter-from,
  .setup-account-field-leave-to,
  .setup-account-strength-enter-from,
  .setup-account-strength-leave-to,
  .setup-account-copy-enter-from,
  .setup-account-copy-leave-to,
  .setup-account-action-enter-from,
  .setup-account-action-leave-to,
  .setup-passcode-length button:active {
    transform: none;
  }
}
</style>
