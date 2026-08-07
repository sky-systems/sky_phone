<script setup lang="ts">
import {
  kBlock,
  kBlockTitle,
  kButton,
  kDialog,
  kDialogButton,
  kLink,
  kList,
  kListButton,
  kListInput,
  kListItem,
  kNavbar,
  kNavbarBackLink,
  kPage,
  kPopover,
  kPreloader,
  kRange,
  kSearchbar,
  kToast,
  kToggle,
} from 'konsta/vue'
import {
  BellRing,
  Check,
  EyeOff,
  KeyRound,
  Monitor,
  Plane,
  RotateCcw,
  Settings,
  Smartphone,
  Sun,
  UserRound,
  Volume2,
} from 'lucide-vue-next'
import {
  computed,
  nextTick,
  onBeforeUnmount,
  ref,
  type ComponentPublicInstance,
} from 'vue'

import { PHONE_FRAME_COLORS } from '@/config/appearance'
import { isLaunchablePhoneApp, PHONE_APPS } from '@/config/apps'
import { usePhoneStore } from '@/stores/phone'
import { useAccountStore } from '@/stores/account'
import type {
  LaunchablePhoneAppDefinition,
  LaunchablePhoneAppId,
} from '@/types/apps'
import {
  filterMailAddressInput,
  MAIL_ADDRESS_INPUT_MAX_LENGTH,
} from '@/utils/mail'
import { nuiCall } from '@/utils/nui'
import { formatPhoneNumber } from '@/utils/phone'
import {
  APPEARANCE_MODE_IDS,
  NOTIFICATION_SOUND_IDS,
  PHONE_FRAME_IDS,
  PHONE_SCALE_MAX,
  PHONE_SCALE_MIN,
  PHONE_SCALE_STEP,
  RINGTONE_IDS,
  WALLPAPER_IDS,
  type AppearanceMode,
  type NotificationSoundId,
  type PhoneFrameId,
  type RingtoneId,
} from '@/utils/preferences'

type SettingsView =
  | 'root'
  | 'account'
  | 'notifications'
  | 'notification-detail'
  | 'sounds'
  | 'general'
  | 'appearance'
  | 'wallpaper'
type RootToggleKey = 'airplaneMode' | 'streamerMode'
type SubmenuView = Exclude<SettingsView, 'root' | 'notification-detail'>

const FACTORY_RESET_DURATION_MS = 60_000
const FACTORY_RESET_CIRCUMFERENCE = 2 * Math.PI * 48
const FRAME_PICKER_WIDTH = 240
const FRAME_PICKER_HEIGHT = 140
const FRAME_PICKER_INSET = 8
const FRAME_PICKER_GAP = 8

const phone = usePhoneStore()
const account = useAccountStore()
const query = ref('')
const activeView = ref<SettingsView>('root')
const selectedNotificationAppId = ref<LaunchablePhoneAppId>('calculator')
const settingsPage = ref<ComponentPublicInstance | null>(null)
const framePickerButton = ref<ComponentPublicInstance | null>(null)
const framePickerOpened = ref(false)
const framePickerTarget = computed(
  () => framePickerButton.value?.$el as HTMLElement | undefined,
)
const framePickerPortalTarget = computed(() =>
  framePickerTarget.value?.closest<HTMLElement>('.phone-screen'),
)
const accountMode = ref<'login' | 'register'>('login')
const accountEmail = ref('')
const accountPassword = ref('')
const accountConfirm = ref('')
const accountSubmitting = ref(false)
const accountToast = ref('')
const removeDeviceImei = ref('')
const removeDevicePassword = ref('')
const removeDeviceOpened = ref(false)
const resetOpened = ref(false)
const simEjectOpened = ref(false)
const factoryResetting = ref(false)
const factoryResetProgress = ref(0)
const factoryResetDashOffset = computed(
  () => FACTORY_RESET_CIRCUMFERENCE * (1 - factoryResetProgress.value / 100),
)
const selectedFrameColor = computed(
  () => PHONE_FRAME_COLORS[phone.preferences.settings.frame],
)
let factoryResetAnimationFrame: number | undefined

const toggleRows = [
  {
    key: 'airplaneMode' as const,
    icon: Plane,
    iconColor: '#ff9500',
  },
  {
    key: 'streamerMode' as const,
    icon: EyeOff,
    iconColor: '#af52de',
  },
]
const serviceRows = [
  {
    key: 'notifications',
    view: 'notifications' as const,
    icon: BellRing,
    iconColor: '#ff3b30',
  },
  {
    key: 'sounds',
    view: 'sounds' as const,
    icon: Volume2,
    iconColor: '#ff2d55',
  },
]
const preferenceRows = [
  {
    key: 'general',
    view: 'general' as const,
    icon: Settings,
    iconColor: '#8e8e93',
  },
  {
    key: 'appearance',
    view: 'appearance' as const,
    icon: Sun,
    iconColor: '#007aff',
  },
  {
    key: 'wallpaper',
    view: 'wallpaper' as const,
    icon: Monitor,
    iconColor: '#32ade6',
  },
]

const normalizedQuery = computed(() => query.value.trim().toLowerCase())
const visibleToggleRows = computed(() =>
  toggleRows.filter((row) => matchesSearch(row.key)),
)
const visibleServiceRows = computed(() =>
  serviceRows.filter((row) => matchesSearch(row.key)),
)
const visiblePreferenceRows = computed(() =>
  preferenceRows.filter((row) => matchesSearch(row.key)),
)
const notificationApps = computed(() =>
  PHONE_APPS.filter(isLaunchablePhoneApp).sort(
    (left, right) => left.gridOrder - right.gridOrder,
  ),
)
const selectedNotificationApp = computed(
  () =>
    notificationApps.value.find(
      (app) => app.id === selectedNotificationAppId.value,
    ) ?? notificationApps.value[0],
)
const activeTitle = computed(() => {
  if (activeView.value === 'account') {
    return phone.t('Apps.settings.accountName')
  }
  if (activeView.value === 'notification-detail') {
    return selectedNotificationApp.value
      ? phone.t(selectedNotificationApp.value.labelKey)
      : phone.t('Apps.settings.notifications')
  }
  return phone.t(`Apps.settings.${activeView.value}`)
})

function matchesSearch(key: string): boolean {
  return (
    !normalizedQuery.value ||
    phone
      .t(`Apps.settings.${key}`)
      .toLowerCase()
      .includes(normalizedQuery.value)
  )
}

function updateSearch(event: Event): void {
  query.value = (event.target as HTMLInputElement).value
}

function openView(view: SubmenuView): void {
  activeView.value = view
  scrollPageToTop()
}

function openNotificationApp(app: LaunchablePhoneAppDefinition): void {
  selectedNotificationAppId.value = app.id
  activeView.value = 'notification-detail'
  scrollPageToTop()
}

function goBack(): void {
  framePickerOpened.value = false
  activeView.value =
    activeView.value === 'notification-detail' ? 'notifications' : 'root'
  scrollPageToTop()
}

function scrollPageToTop(): void {
  void nextTick(() => {
    const pageElement = settingsPage.value?.$el as HTMLElement | undefined
    pageElement?.scrollTo({ top: 0 })
  })
}

function toggleRootSetting(key: RootToggleKey): void {
  phone.setPreference(key, !phone.preferences.settings[key])
}

function updateNumberPreference(
  key:
    | 'notificationDurationSeconds'
    | 'notificationVolume'
    | 'phoneScale'
    | 'ringtoneVolume',
  event: Event,
): void {
  phone.setPreference(
    key,
    Number.parseInt((event.target as HTMLInputElement).value, 10),
  )
}

function selectAppearanceMode(mode: AppearanceMode): void {
  phone.setPreference('appearanceMode', mode)
}

function selectFrame(frame: PhoneFrameId): void {
  phone.setPreference('frame', frame)
  framePickerOpened.value = false
}

function openFramePicker(): void {
  const target = framePickerTarget.value
  const screen = framePickerPortalTarget.value
  if (!target || !screen) {
    console.error('Unable to position the Settings frame color picker')
    return
  }

  const screenRect = screen.getBoundingClientRect()
  const targetRect = target.getBoundingClientRect()
  const screenScale = screenRect.width / screen.offsetWidth
  const targetLeft = (targetRect.left - screenRect.left) / screenScale
  const targetTop = (targetRect.top - screenRect.top) / screenScale
  const targetWidth = targetRect.width / screenScale
  const targetHeight = targetRect.height / screenScale
  const desiredLeft = targetLeft + targetWidth / 2 - FRAME_PICKER_WIDTH / 2
  const aboveTop = targetTop - FRAME_PICKER_HEIGHT - FRAME_PICKER_GAP
  const desiredTop =
    aboveTop >= FRAME_PICKER_INSET
      ? aboveTop
      : targetTop + targetHeight + FRAME_PICKER_GAP

  screen.style.setProperty(
    '--settings-frame-picker-left',
    `${Math.max(
      FRAME_PICKER_INSET,
      Math.min(
        desiredLeft,
        screen.offsetWidth - FRAME_PICKER_WIDTH - FRAME_PICKER_INSET,
      ),
    )}px`,
  )
  screen.style.setProperty(
    '--settings-frame-picker-top',
    `${Math.max(
      FRAME_PICKER_INSET,
      Math.min(
        desiredTop,
        screen.offsetHeight - FRAME_PICKER_HEIGHT - FRAME_PICKER_INSET,
      ),
    )}px`,
  )

  framePickerOpened.value = true
}

function selectRingtone(ringtone: RingtoneId): void {
  phone.setPreference('ringtone', ringtone)
}

function selectNotificationSound(sound: NotificationSoundId): void {
  phone.setPreference('notificationSound', sound)
}

function eventValue(event: Event): string {
  return (event.target as HTMLInputElement).value
}

function updateAccountEmail(event: Event): void {
  const input = event.target as HTMLInputElement
  const original = input.value
  const selectionStart = input.selectionStart ?? original.length
  const filtered = filterMailAddressInput(original)

  if (filtered !== original) {
    const nextSelection = filterMailAddressInput(
      original.slice(0, selectionStart),
    ).length
    input.value = filtered
    input.setSelectionRange(nextSelection, nextSelection)
  }

  accountEmail.value = filtered
}

function accountError(error?: string): string {
  const known = [
    'invalid_email',
    'invalid_password',
    'invalid_credentials',
    'email_taken',
    'rate_limited',
    'current_device',
    'device_not_found',
  ]
  return phone.t(
    `Apps.settings.accountErrors.${error && known.includes(error) ? error : 'default'}`,
  )
}

async function submitAccount(): Promise<void> {
  if (
    accountMode.value === 'register' &&
    accountPassword.value !== accountConfirm.value
  ) {
    accountToast.value = phone.t('Apps.mail.passwordsMismatch')
    return
  }
  accountSubmitting.value = true
  const response =
    accountMode.value === 'login'
      ? await account.login(accountEmail.value, accountPassword.value)
      : await account.register(accountEmail.value, accountPassword.value)
  accountSubmitting.value = false
  if (!response.success) accountToast.value = accountError(response.error)
  else {
    accountPassword.value = ''
    accountConfirm.value = ''
  }
}

async function logoutAccount(): Promise<void> {
  if (!(await account.logout())) accountToast.value = accountError()
}

function requestRemoveDevice(imei: string): void {
  removeDeviceImei.value = imei
  removeDevicePassword.value = ''
  removeDeviceOpened.value = true
}

async function confirmRemoveDevice(): Promise<void> {
  const response = await account.removeDevice(
    removeDeviceImei.value,
    removeDevicePassword.value,
  )
  if (!response.success) accountToast.value = accountError(response.error)
  else removeDeviceOpened.value = false
}

async function confirmFactoryReset(): Promise<void> {
  resetOpened.value = false
  factoryResetting.value = true
  factoryResetProgress.value = 0
  const startedAt = performance.now()

  const animateProgress = (now: number): void => {
    factoryResetProgress.value = Math.min(
      100,
      ((now - startedAt) / FACTORY_RESET_DURATION_MS) * 100,
    )
    if (factoryResetProgress.value < 100) {
      factoryResetAnimationFrame = requestAnimationFrame(animateProgress)
    }
  }
  factoryResetAnimationFrame = requestAnimationFrame(animateProgress)

  const [success] = await Promise.all([
    account.factoryReset(),
    new Promise<void>((resolve) =>
      window.setTimeout(resolve, FACTORY_RESET_DURATION_MS),
    ),
  ])

  if (factoryResetAnimationFrame !== undefined) {
    cancelAnimationFrame(factoryResetAnimationFrame)
    factoryResetAnimationFrame = undefined
  }
  factoryResetProgress.value = 100
  factoryResetting.value = false
  if (!success) accountToast.value = accountError()
}

async function confirmSimEject(): Promise<void> {
  const response = await nuiCall('sim:eject')
  simEjectOpened.value = false
  if (!response.success) {
    accountToast.value = phone.t(
      `Apps.phone.errors.${response.error ?? 'default'}`,
    )
  }
}

onBeforeUnmount(() => {
  if (factoryResetAnimationFrame !== undefined) {
    cancelAnimationFrame(factoryResetAnimationFrame)
  }
})
</script>

<template>
  <k-page
    ref="settingsPage"
    :class="['!pb-[24px]', { '!pt-[44px]': activeView !== 'root' }]"
  >
    <template v-if="activeView === 'root'">
      <k-navbar
        large
        transparent
        :title="phone.t('Apps.settings.name')"
        class="top-0 sticky"
      >
        <template #subnavbar>
          <k-searchbar
            :value="query"
            :placeholder="phone.t('Apps.settings.searchPlaceholder')"
            @input="updateSearch"
            @clear="query = ''"
          />
        </template>
      </k-navbar>

      <k-list strong inset>
        <k-list-item
          link
          :title="phone.t('Apps.settings.accountName')"
          :subtitle="phone.t('Apps.settings.accountDetail')"
          @click="openView('account')"
        >
          <template #media>
            <UserRound class="w-9 h-9 text-primary" />
          </template>
        </k-list-item>
      </k-list>

      <k-list v-if="visibleToggleRows.length" strong inset>
        <k-list-item
          v-for="row in visibleToggleRows"
          :key="row.key"
          :title="phone.t(`Apps.settings.${row.key}`)"
          title-font-size-ios="text-[16px]"
          title-wrap-class="whitespace-nowrap"
        >
          <template #media>
            <span
              class="flex h-7 w-7 shrink-0 items-center justify-center rounded-[7px] text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.35),0_1px_2px_rgba(0,0,0,0.25)]"
              :style="{ backgroundColor: row.iconColor }"
            >
              <component :is="row.icon" :size="17" :stroke-width="2.25" />
            </span>
          </template>
          <template #after>
            <k-toggle
              :checked="phone.preferences.settings[row.key]"
              :aria-label="phone.t(`Apps.settings.toggle.${row.key}`)"
              @change="toggleRootSetting(row.key)"
            />
          </template>
        </k-list-item>
      </k-list>

      <k-list v-if="visibleServiceRows.length" strong inset>
        <k-list-item
          v-for="row in visibleServiceRows"
          :key="row.key"
          link
          :title="phone.t(`Apps.settings.${row.key}`)"
          title-font-size-ios="text-[16px]"
          title-wrap-class="whitespace-nowrap"
          @click="openView(row.view)"
        >
          <template #media>
            <span
              class="flex h-7 w-7 shrink-0 items-center justify-center rounded-[7px] text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.35),0_1px_2px_rgba(0,0,0,0.25)]"
              :style="{ backgroundColor: row.iconColor }"
            >
              <component :is="row.icon" :size="17" :stroke-width="2.25" />
            </span>
          </template>
        </k-list-item>
      </k-list>

      <k-list v-if="visiblePreferenceRows.length" strong inset>
        <k-list-item
          v-for="row in visiblePreferenceRows"
          :key="row.key"
          link
          :title="phone.t(`Apps.settings.${row.key}`)"
          title-font-size-ios="text-[16px]"
          title-wrap-class="whitespace-nowrap"
          @click="openView(row.view)"
        >
          <template #media>
            <span
              class="flex h-7 w-7 shrink-0 items-center justify-center rounded-[7px] text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.35),0_1px_2px_rgba(0,0,0,0.25)]"
              :style="{ backgroundColor: row.iconColor }"
            >
              <component :is="row.icon" :size="17" :stroke-width="2.25" />
            </span>
          </template>
        </k-list-item>
      </k-list>
    </template>

    <template v-else>
      <k-navbar :title="activeTitle" class="top-0 sticky z-20">
        <template #left>
          <k-navbar-back-link
            component="button"
            :show-text="false"
            :text="phone.t('Apps.settings.back')"
            :aria-label="phone.t('Apps.settings.back')"
            @click="goBack"
          />
        </template>
        <template #right>
          <k-link
            v-if="activeView === 'account' && !account.email"
            component="button"
            @click="
              accountMode = accountMode === 'login' ? 'register' : 'login'
            "
          >
            {{
              phone.t(
                accountMode === 'login'
                  ? 'Apps.mail.registerLink'
                  : 'Apps.mail.login',
              )
            }}
          </k-link>
        </template>
      </k-navbar>

      <template v-if="activeView === 'account'">
        <template v-if="!account.email">
          <k-block-title>
            {{
              phone.t(
                accountMode === 'login'
                  ? 'Apps.settings.accountLoginBody'
                  : 'Apps.mail.passwordWarning',
              )
            }}
          </k-block-title>
          <k-list>
            <k-list-input
              class="relative"
              :value="accountEmail"
              :label="
                phone.t(
                  accountMode === 'login'
                    ? 'Apps.mail.email'
                    : 'Apps.mail.localPart',
                )
              "
              outline
              floating-label
              :input-class="accountMode === 'register' ? 'pr-20' : undefined"
              autocomplete="username"
              autocapitalize="none"
              autocorrect="off"
              inputmode="email"
              :maxlength="MAIL_ADDRESS_INPUT_MAX_LENGTH"
              pattern="[A-Za-z0-9@._-]*"
              spellcheck="false"
              :clear-button="accountMode === 'login'"
              @input="updateAccountEmail"
              @clear="accountEmail = ''"
            >
              <span
                v-if="accountMode === 'register'"
                class="pointer-events-none absolute right-8 top-1/2 -translate-y-1/2 text-sm opacity-50"
              >
                @ifruit.com
              </span>
            </k-list-input>
            <k-list-input
              type="password"
              :value="accountPassword"
              :label="phone.t('Apps.mail.password')"
              outline
              floating-label
              autocomplete="current-password"
              @input="accountPassword = eventValue($event)"
            >
              <template #media><KeyRound :size="20" /></template>
            </k-list-input>
            <k-list-input
              v-if="accountMode === 'register'"
              type="password"
              :value="accountConfirm"
              :label="phone.t('Apps.mail.confirmPassword')"
              outline
              floating-label
              autocomplete="new-password"
              @input="accountConfirm = eventValue($event)"
            >
              <template #media><KeyRound :size="20" /></template>
            </k-list-input>
          </k-list>
          <k-block>
            <k-button
              large
              rounded
              :disabled="accountSubmitting"
              @click="submitAccount"
            >
              <k-preloader v-if="accountSubmitting" />
              <template v-else>
                {{
                  phone.t(
                    accountMode === 'login'
                      ? 'Apps.mail.login'
                      : 'Apps.mail.register',
                  )
                }}
              </template>
            </k-button>
          </k-block>
        </template>

        <template v-else>
          <k-list strong inset>
            <k-list-item
              :title="account.email"
              :subtitle="phone.t('Apps.settings.accountCloudDetail')"
            >
              <template #media>
                <UserRound class="w-12 h-12 text-primary" />
              </template>
            </k-list-item>
          </k-list>

          <k-block-title>{{
            phone.t('Apps.settings.linkedDevices')
          }}</k-block-title>
          <k-list strong inset>
            <k-list-item
              v-for="device in account.devices"
              :key="device.imei"
              :title="device.device_name"
              :subtitle="device.imei"
              :after="
                device.current ? phone.t('Apps.settings.thisDevice') : undefined
              "
            >
              <template #media><Smartphone :size="22" /></template>
              <template v-if="!device.current" #footer>
                <k-list-button @click="requestRemoveDevice(device.imei)">
                  {{ phone.t('Apps.settings.removeDevice') }}
                </k-list-button>
              </template>
            </k-list-item>
          </k-list>

          <k-list strong inset>
            <k-list-button @click="logoutAccount">
              {{ phone.t('Apps.settings.signOut') }}
            </k-list-button>
          </k-list>
        </template>
      </template>

      <template v-else-if="activeView === 'notifications'">
        <k-list strong inset>
          <k-list-item
            v-for="app in notificationApps"
            :key="app.id"
            link
            :title="phone.t(app.labelKey)"
            :after="
              phone.t(
                phone.preferences.settings.notifications[app.id].enabled
                  ? 'Apps.settings.on'
                  : 'Apps.settings.off',
              )
            "
            @click="openNotificationApp(app)"
          >
            <template #media>
              <img
                class="w-8 h-8 object-contain"
                :src="app.iconImage"
                alt=""
                draggable="false"
              />
            </template>
          </k-list-item>
        </k-list>
      </template>

      <template
        v-else-if="
          activeView === 'notification-detail' && selectedNotificationApp
        "
      >
        <k-list strong inset>
          <k-list-item :title="phone.t(selectedNotificationApp.labelKey)">
            <template #media>
              <img
                class="w-12 h-12 object-contain"
                :src="selectedNotificationApp.iconImage"
                alt=""
                draggable="false"
              />
            </template>
          </k-list-item>
        </k-list>
        <k-list strong inset>
          <k-list-item :title="phone.t('Apps.settings.allowNotifications')">
            <template #after>
              <k-toggle
                :checked="
                  phone.preferences.settings.notifications[
                    selectedNotificationApp.id
                  ].enabled
                "
                :aria-label="
                  phone.t('Apps.settings.toggle.notifications', {
                    app: phone.t(selectedNotificationApp.labelKey),
                  })
                "
                @change="
                  phone.setAppNotification(
                    selectedNotificationApp.id,
                    'enabled',
                    !phone.preferences.settings.notifications[
                      selectedNotificationApp.id
                    ].enabled,
                  )
                "
              />
            </template>
          </k-list-item>
          <k-list-item :title="phone.t('Apps.settings.notificationSounds')">
            <template #after>
              <k-toggle
                :disabled="
                  !phone.preferences.settings.notifications[
                    selectedNotificationApp.id
                  ].enabled
                "
                :checked="
                  phone.preferences.settings.notifications[
                    selectedNotificationApp.id
                  ].sounds
                "
                :aria-label="
                  phone.t('Apps.settings.toggle.notificationSounds', {
                    app: phone.t(selectedNotificationApp.labelKey),
                  })
                "
                @change="
                  phone.setAppNotification(
                    selectedNotificationApp.id,
                    'sounds',
                    !phone.preferences.settings.notifications[
                      selectedNotificationApp.id
                    ].sounds,
                  )
                "
              />
            </template>
          </k-list-item>
        </k-list>
      </template>

      <template v-else-if="activeView === 'sounds'">
        <k-block-title>
          {{ phone.t('Apps.settings.ringtoneVolume') }} ·
          {{ phone.preferences.settings.ringtoneVolume }}%
        </k-block-title>
        <k-list strong inset>
          <k-list-item>
            <template #inner>
              <k-range
                class="w-full"
                :value="phone.preferences.settings.ringtoneVolume"
                :min="0"
                :max="100"
                :aria-label="phone.t('Apps.settings.ringtoneVolume')"
                @input="updateNumberPreference('ringtoneVolume', $event)"
              />
            </template>
          </k-list-item>
        </k-list>

        <k-block-title>
          {{ phone.t('Apps.settings.notificationVolume') }} ·
          {{ phone.preferences.settings.notificationVolume }}%
        </k-block-title>
        <k-list strong inset>
          <k-list-item>
            <template #inner>
              <k-range
                class="w-full"
                :value="phone.preferences.settings.notificationVolume"
                :min="0"
                :max="100"
                :aria-label="phone.t('Apps.settings.notificationVolume')"
                @input="updateNumberPreference('notificationVolume', $event)"
              />
            </template>
          </k-list-item>
        </k-list>

        <k-block-title>{{ phone.t('Apps.settings.ringtone') }}</k-block-title>
        <k-list strong inset>
          <k-list-item
            v-for="ringtone in RINGTONE_IDS"
            :key="ringtone"
            link
            :chevron="false"
            :title="phone.t(`Apps.settings.ringtones.${ringtone}`)"
            @click="selectRingtone(ringtone)"
          >
            <template #after>
              <Check
                v-if="phone.preferences.settings.ringtone === ringtone"
                class="w-5 h-5 text-primary"
              />
            </template>
          </k-list-item>
        </k-list>

        <k-block-title>
          {{ phone.t('Apps.settings.notificationSound') }}
        </k-block-title>
        <k-list strong inset>
          <k-list-item
            v-for="sound in NOTIFICATION_SOUND_IDS"
            :key="sound"
            link
            :chevron="false"
            :title="phone.t(`Apps.settings.notificationSoundsList.${sound}`)"
            @click="selectNotificationSound(sound)"
          >
            <template #after>
              <Check
                v-if="phone.preferences.settings.notificationSound === sound"
                class="w-5 h-5 text-primary"
              />
            </template>
          </k-list-item>
        </k-list>
      </template>

      <template v-else-if="activeView === 'general'">
        <k-block-title>
          {{ phone.t('Apps.settings.notificationDuration') }} ·
          {{
            phone.t('Apps.settings.seconds', {
              seconds: String(
                phone.preferences.settings.notificationDurationSeconds,
              ),
            })
          }}
        </k-block-title>
        <k-list strong inset>
          <k-list-item>
            <template #inner>
              <k-range
                class="w-full"
                :value="phone.preferences.settings.notificationDurationSeconds"
                :min="3"
                :max="30"
                :step="1"
                :aria-label="phone.t('Apps.settings.notificationDuration')"
                @input="
                  updateNumberPreference('notificationDurationSeconds', $event)
                "
              />
            </template>
          </k-list-item>
        </k-list>

        <k-block-title>{{ phone.t('Apps.settings.about') }}</k-block-title>
        <k-list strong inset>
          <k-list-item
            :title="phone.t('Apps.settings.deviceName')"
            :after="phone.t('Apps.settings.deviceNameValue')"
          />
          <k-list-item
            :title="phone.t('Apps.settings.softwareVersion')"
            after="0.1.0"
          />
          <k-list-item
            :title="phone.t('Apps.settings.language')"
            :after="phone.t('Apps.settings.languageValue')"
          />
          <k-list-item
            :title="phone.t('Apps.settings.localStorage')"
            :after="phone.t('Apps.settings.localStorageValue')"
          />
        </k-list>

        <k-block-title>{{
          phone.t('Apps.settings.deviceInformation')
        }}</k-block-title>
        <k-list strong inset>
          <k-list-item
            :title="phone.t('Apps.settings.imei')"
            :after="phone.device?.imei ?? '—'"
          />
          <k-list-item
            :title="phone.t('Apps.settings.simNumber')"
            :after="
              phone.device?.sim
                ? formatPhoneNumber(phone.device.sim.number)
                : phone.t('Apps.settings.noSim')
            "
          />
          <k-list-item
            v-if="phone.device?.sim"
            :title="phone.t('Apps.settings.simType')"
            :after="
              phone.t(
                phone.device.sim.type === 'registered'
                  ? 'Apps.settings.registeredSim'
                  : 'Apps.settings.anonymousSim',
              )
            "
          />
          <k-list-button
            v-if="phone.device?.sim"
            @click="simEjectOpened = true"
          >
            {{ phone.t('Apps.settings.ejectSim') }}
          </k-list-button>
          <k-list-button @click="resetOpened = true">
            <RotateCcw :size="18" />
            {{ phone.t('Apps.settings.factoryReset') }}
          </k-list-button>
        </k-list>
      </template>

      <template v-else-if="activeView === 'appearance'">
        <k-block-title>
          {{ phone.t('Apps.settings.appearanceMode') }}
        </k-block-title>
        <k-list strong inset>
          <k-list-item
            v-for="mode in APPEARANCE_MODE_IDS"
            :key="mode"
            link
            :chevron="false"
            :title="phone.t(`Apps.settings.${mode}`)"
            @click="selectAppearanceMode(mode)"
          >
            <template #after>
              <Check
                v-if="phone.preferences.settings.appearanceMode === mode"
                class="w-5 h-5 text-primary"
              />
            </template>
          </k-list-item>
        </k-list>

        <k-block-title>
          {{ phone.t('Apps.settings.phoneScale') }} ·
          {{ phone.preferences.settings.phoneScale }}%
        </k-block-title>
        <k-list strong inset>
          <k-list-item>
            <template #inner>
              <k-range
                class="w-full"
                :value="phone.preferences.settings.phoneScale"
                :min="PHONE_SCALE_MIN"
                :max="PHONE_SCALE_MAX"
                :step="PHONE_SCALE_STEP"
                :aria-label="phone.t('Apps.settings.phoneScale')"
                @input="updateNumberPreference('phoneScale', $event)"
              />
            </template>
          </k-list-item>
        </k-list>

        <k-block-title>{{ phone.t('Apps.settings.phoneFrame') }}</k-block-title>
        <k-list strong inset>
          <k-list-item
            ref="framePickerButton"
            link
            :title="phone.t('Apps.settings.phoneFrame')"
            @click="openFramePicker"
          >
            <template #after>
              <span
                class="h-7 w-7 rounded-full border border-black/15 shadow-sm"
                :style="{ backgroundColor: selectedFrameColor }"
                aria-hidden="true"
              />
            </template>
          </k-list-item>
        </k-list>

        <Teleport v-if="framePickerPortalTarget" :to="framePickerPortalTarget">
          <k-popover
            :opened="framePickerOpened"
            :class="[
              'settings-frame-popover !absolute !z-[200] !left-[var(--settings-frame-picker-left)] !top-[var(--settings-frame-picker-top)]',
              { dark: phone.isDarkMode },
            ]"
            @backdropclick="framePickerOpened = false"
          >
            <div
              class="grid grid-cols-3 gap-5 p-5"
              role="group"
              :aria-label="phone.t('Apps.settings.phoneFrame')"
            >
              <button
                v-for="frame in PHONE_FRAME_IDS"
                :key="frame"
                type="button"
                class="h-10 w-10 rounded-full border border-black/15 shadow-sm"
                :style="{ backgroundColor: PHONE_FRAME_COLORS[frame] }"
                :aria-label="phone.t(`Apps.settings.frames.${frame}`)"
                :aria-pressed="phone.preferences.settings.frame === frame"
                @click="selectFrame(frame)"
              />
            </div>
          </k-popover>
        </Teleport>
      </template>

      <template v-else-if="activeView === 'wallpaper'">
        <k-block-title>
          {{ phone.t('Apps.settings.wallpaperPicker') }}
        </k-block-title>
        <k-list strong inset>
          <k-list-item
            v-for="wallpaper in WALLPAPER_IDS"
            :key="wallpaper"
            link
            :chevron="false"
            :title="phone.t(`Apps.settings.wallpapers.${wallpaper}`)"
            @click="phone.setWallpaper(wallpaper)"
          >
            <template #after>
              <Check
                v-if="phone.preferences.settings.wallpaper === wallpaper"
                class="w-5 h-5 text-primary"
              />
            </template>
          </k-list-item>
        </k-list>
      </template>
    </template>
  </k-page>

  <div
    v-if="factoryResetting"
    class="fixed inset-0 z-[100] flex flex-col items-center justify-center bg-black px-8 text-center text-white"
  >
    <div
      class="relative flex h-28 w-28 items-center justify-center"
      role="progressbar"
      :aria-label="phone.t('Apps.settings.factoryResetProgress')"
      aria-valuemin="0"
      aria-valuemax="100"
      :aria-valuenow="Math.floor(factoryResetProgress)"
    >
      <svg
        class="h-28 w-28 -rotate-90"
        viewBox="0 0 112 112"
        aria-hidden="true"
      >
        <circle
          cx="56"
          cy="56"
          r="48"
          fill="none"
          stroke="currentColor"
          stroke-width="6"
          class="text-white/15"
        />
        <circle
          cx="56"
          cy="56"
          r="48"
          fill="none"
          stroke="currentColor"
          stroke-width="6"
          stroke-linecap="round"
          :stroke-dasharray="FACTORY_RESET_CIRCUMFERENCE"
          :stroke-dashoffset="factoryResetDashOffset"
          class="text-white"
        />
      </svg>
      <span class="absolute text-xl font-semibold tabular-nums">
        {{ Math.floor(factoryResetProgress) }}%
      </span>
    </div>
    <h2 class="mt-8 text-xl font-semibold">
      {{ phone.t('Apps.settings.factoryResetProgress') }}
    </h2>
    <p class="mt-3 max-w-64 text-sm leading-5 text-white/55">
      {{ phone.t('Apps.settings.factoryResetWarning') }}
    </p>
  </div>

  <k-dialog
    :opened="removeDeviceOpened"
    @backdropclick="removeDeviceOpened = false"
  >
    <template #title>{{ phone.t('Apps.settings.removeDevice') }}</template>
    <p>{{ phone.t('Apps.settings.removeDeviceBody') }}</p>
    <k-list>
      <k-list-input
        type="password"
        :value="removeDevicePassword"
        :label="phone.t('Apps.mail.password')"
        @input="removeDevicePassword = eventValue($event)"
      />
    </k-list>
    <template #buttons>
      <k-dialog-button @click="removeDeviceOpened = false">
        {{ phone.t('Common.cancel') }}
      </k-dialog-button>
      <k-dialog-button strong @click="confirmRemoveDevice">
        {{ phone.t('Apps.settings.removeDevice') }}
      </k-dialog-button>
    </template>
  </k-dialog>

  <k-dialog :opened="simEjectOpened" @backdropclick="simEjectOpened = false">
    <template #title>{{ phone.t('Apps.settings.ejectSim') }}</template>
    <p>{{ phone.t('Apps.settings.ejectSimBody') }}</p>
    <template #buttons>
      <k-dialog-button @click="simEjectOpened = false">{{
        phone.t('Common.cancel')
      }}</k-dialog-button>
      <k-dialog-button strong @click="confirmSimEject">{{
        phone.t('Apps.settings.ejectSim')
      }}</k-dialog-button>
    </template>
  </k-dialog>

  <k-dialog :opened="resetOpened" @backdropclick="resetOpened = false">
    <template #title>{{ phone.t('Apps.settings.factoryReset') }}</template>
    <p>{{ phone.t('Apps.settings.factoryResetBody') }}</p>
    <template #buttons>
      <k-dialog-button @click="resetOpened = false">
        {{ phone.t('Common.cancel') }}
      </k-dialog-button>
      <k-dialog-button strong @click="confirmFactoryReset">
        {{ phone.t('Common.reset') }}
      </k-dialog-button>
    </template>
  </k-dialog>

  <k-toast
    :opened="Boolean(accountToast)"
    position="center"
    @click="accountToast = ''"
  >
    {{ accountToast }}
  </k-toast>
</template>
