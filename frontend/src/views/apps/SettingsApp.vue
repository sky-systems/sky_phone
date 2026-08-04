<script setup lang="ts">
import {
  kBlockTitle,
  kList,
  kListItem,
  kNavbar,
  kNavbarBackLink,
  kPage,
  kRange,
  kSearchbar,
  kToggle,
} from 'konsta/vue'
import {
  BellRing,
  Check,
  EyeOff,
  Monitor,
  Plane,
  Settings,
  Sun,
  UserRound,
  Volume2,
} from 'lucide-vue-next'
import { computed, nextTick, ref, type ComponentPublicInstance } from 'vue'

import { PHONE_FRAME_IMAGES } from '@/config/appearance'
import { PHONE_APPS } from '@/config/apps'
import { usePhoneStore } from '@/stores/phone'
import type { PhoneAppDefinition, PhoneAppId } from '@/types/apps'
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

const phone = usePhoneStore()
const query = ref('')
const activeView = ref<SettingsView>('root')
const selectedNotificationAppId = ref<PhoneAppId>('calculator')
const settingsPage = ref<ComponentPublicInstance | null>(null)

const toggleRows = [
  {
    key: 'airplaneMode' as const,
    icon: Plane,
    iconClass: 'bg-linear-to-br from-orange-400 to-orange-500',
  },
  {
    key: 'streamerMode' as const,
    icon: EyeOff,
    iconClass: 'bg-linear-to-br from-purple-400 to-purple-500',
  },
]
const serviceRows = [
  {
    key: 'notifications',
    view: 'notifications' as const,
    icon: BellRing,
    iconClass: 'bg-linear-to-br from-red-400 to-red-500',
  },
  {
    key: 'sounds',
    view: 'sounds' as const,
    icon: Volume2,
    iconClass: 'bg-linear-to-br from-rose-400 to-rose-500',
  },
]
const preferenceRows = [
  {
    key: 'general',
    view: 'general' as const,
    icon: Settings,
    iconClass: 'bg-linear-to-br from-slate-400 to-slate-500',
  },
  {
    key: 'appearance',
    view: 'appearance' as const,
    icon: Sun,
    iconClass: 'bg-linear-to-br from-blue-400 to-blue-500',
  },
  {
    key: 'wallpaper',
    view: 'wallpaper' as const,
    icon: Monitor,
    iconClass: 'bg-linear-to-br from-sky-400 to-sky-500',
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
  [...PHONE_APPS].sort((left, right) => left.gridOrder - right.gridOrder),
)
const selectedNotificationApp = computed(
  () =>
    PHONE_APPS.find((app) => app.id === selectedNotificationAppId.value) ??
    PHONE_APPS[0],
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

function openNotificationApp(app: PhoneAppDefinition): void {
  selectedNotificationAppId.value = app.id
  activeView.value = 'notification-detail'
  scrollPageToTop()
}

function goBack(): void {
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
}

function selectRingtone(ringtone: RingtoneId): void {
  phone.setPreference('ringtone', ringtone)
}

function selectNotificationSound(sound: NotificationSoundId): void {
  phone.setPreference('notificationSound', sound)
}
</script>

<template>
  <k-page ref="settingsPage" class="!pt-[44px] !pb-[24px]">
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
              :class="[
                'flex h-7 w-7 shrink-0 items-center justify-center rounded-[7px] text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.35),0_1px_2px_rgba(0,0,0,0.25)]',
                row.iconClass,
              ]"
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
              :class="[
                'flex h-7 w-7 shrink-0 items-center justify-center rounded-[7px] text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.35),0_1px_2px_rgba(0,0,0,0.25)]',
                row.iconClass,
              ]"
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
              :class="[
                'flex h-7 w-7 shrink-0 items-center justify-center rounded-[7px] text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.35),0_1px_2px_rgba(0,0,0,0.25)]',
                row.iconClass,
              ]"
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
      </k-navbar>

      <template v-if="activeView === 'account'">
        <k-list strong inset>
          <k-list-item
            :title="phone.t('Apps.settings.accountName')"
            :subtitle="phone.t('Apps.settings.accountLocalDetail')"
          >
            <template #media>
              <UserRound class="w-12 h-12 text-primary" />
            </template>
          </k-list-item>
        </k-list>

        <k-block-title>
          {{ phone.t('Apps.settings.accountInformation') }}
        </k-block-title>
        <k-list strong inset>
          <k-list-item
            :title="phone.t('Apps.settings.accountStatus')"
            :after="phone.t('Apps.settings.accountStatusValue')"
          />
          <k-list-item
            :title="phone.t('Apps.settings.accountStorage')"
            :after="phone.t('Apps.settings.accountStorageValue')"
          />
          <k-list-item
            :title="phone.t('Apps.settings.accountPurchases')"
            :after="phone.t('Apps.settings.accountPurchasesValue')"
          />
        </k-list>
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
            v-for="frame in PHONE_FRAME_IDS"
            :key="frame"
            link
            :chevron="false"
            :title="phone.t(`Apps.settings.frames.${frame}`)"
            @click="selectFrame(frame)"
          >
            <template #media>
              <img
                class="w-6 h-12 object-fill"
                :src="PHONE_FRAME_IMAGES[frame]"
                alt=""
                draggable="false"
              />
            </template>
            <template #after>
              <Check
                v-if="phone.preferences.settings.frame === frame"
                class="w-5 h-5 text-primary"
              />
            </template>
          </k-list-item>
        </k-list>
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
</template>
