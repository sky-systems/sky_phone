<script setup lang="ts">
import {
  kBlockTitle,
  kList,
  kListItem,
  kNavbar,
  kNavbarBackLink,
  kPage,
  kRange,
  kToggle,
} from 'konsta/vue'
import {
  BellRing,
  Check,
  ChevronRight,
  EyeOff,
  Monitor,
  Plane,
  Search,
  Settings,
  Sun,
  UserRound,
  Volume1,
  Volume2,
} from 'lucide-vue-next'
import { computed, ref } from 'vue'

import { PHONE_FRAME_IMAGES } from '@/config/appearance'
import { PHONE_APPS } from '@/config/apps'
import { usePhoneStore } from '@/stores/phone'
import type { PhoneAppDefinition, PhoneAppId } from '@/types/apps'
import {
  APPEARANCE_MODE_IDS,
  NOTIFICATION_SOUND_IDS,
  PHONE_FRAME_IDS,
  RINGTONE_IDS,
  WALLPAPER_IDS,
  type AppearanceMode,
  type NotificationSoundId,
  type PhoneFrameId,
  type RingtoneId,
} from '@/utils/preferences'

type SettingsView =
  | 'root'
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

const toggleRows = [
  { key: 'airplaneMode' as const, icon: Plane, color: '#ff9500' },
  { key: 'streamerMode' as const, icon: EyeOff, color: '#af52de' },
]
const serviceRows = [
  {
    key: 'notifications',
    view: 'notifications' as const,
    icon: BellRing,
    color: '#ff453a',
  },
  {
    key: 'sounds',
    view: 'sounds' as const,
    icon: Volume2,
    color: '#ff2d55',
  },
]
const preferenceRows = [
  {
    key: 'general',
    view: 'general' as const,
    icon: Settings,
    color: '#8e8e93',
  },
  {
    key: 'appearance',
    view: 'appearance' as const,
    icon: Sun,
    color: '#0a84ff',
  },
  {
    key: 'wallpaper',
    view: 'wallpaper' as const,
    icon: Monitor,
    color: '#64d2ff',
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

function openView(view: SubmenuView): void {
  activeView.value = view
}

function openNotificationApp(app: PhoneAppDefinition): void {
  selectedNotificationAppId.value = app.id
  activeView.value = 'notification-detail'
}

function goBack(): void {
  activeView.value =
    activeView.value === 'notification-detail' ? 'notifications' : 'root'
}

function toggleRootSetting(key: RootToggleKey): void {
  phone.setPreference(key, !phone.preferences.settings[key])
}

function updateVolume(
  key: 'notificationVolume' | 'phoneScale' | 'ringtoneVolume',
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
  <k-page class="native-app konsta-settings">
    <section v-if="activeView === 'root'" class="settings-scroll">
      <h1>{{ phone.t('Apps.settings.name') }}</h1>
      <div class="settings-search">
        <Search :size="17" />
        <input
          v-model="query"
          :placeholder="phone.t('Apps.settings.searchPlaceholder')"
          type="search"
        />
      </div>

      <article class="settings-account">
        <span><UserRound :size="34" /></span>
        <div>
          <strong>{{ phone.t('Apps.settings.accountName') }}</strong>
          <small>{{ phone.t('Apps.settings.accountDetail') }}</small>
        </div>
        <ChevronRight :size="19" />
      </article>

      <k-list
        v-if="visibleToggleRows.length"
        strong
        inset
        class="settings-konsta-list"
      >
        <k-list-item
          v-for="row in visibleToggleRows"
          :key="row.key"
          :title="phone.t(`Apps.settings.${row.key}`)"
        >
          <template #media>
            <span class="settings-symbol" :style="{ background: row.color }">
              <component :is="row.icon" :size="16" />
            </span>
          </template>
          <template #after>
            <k-toggle
              component="div"
              :checked="phone.preferences.settings[row.key]"
              :aria-label="phone.t(`Apps.settings.toggle.${row.key}`)"
              @change="toggleRootSetting(row.key)"
            />
          </template>
        </k-list-item>
      </k-list>

      <k-list
        v-if="visibleServiceRows.length"
        strong
        inset
        class="settings-konsta-list"
      >
        <k-list-item
          v-for="row in visibleServiceRows"
          :key="row.key"
          link
          link-component="button"
          :title="phone.t(`Apps.settings.${row.key}`)"
          @click="openView(row.view)"
        >
          <template #media>
            <span class="settings-symbol" :style="{ background: row.color }">
              <component :is="row.icon" :size="16" />
            </span>
          </template>
        </k-list-item>
      </k-list>

      <k-list
        v-if="visiblePreferenceRows.length"
        strong
        inset
        class="settings-konsta-list"
      >
        <k-list-item
          v-for="row in visiblePreferenceRows"
          :key="row.key"
          link
          link-component="button"
          :title="phone.t(`Apps.settings.${row.key}`)"
          @click="openView(row.view)"
        >
          <template #media>
            <span class="settings-symbol" :style="{ background: row.color }">
              <component :is="row.icon" :size="16" />
            </span>
          </template>
        </k-list-item>
      </k-list>
    </section>

    <template v-else>
      <k-navbar :title="activeTitle" class="settings-konsta-navbar">
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

      <section class="settings-subpage-scroll">
        <template v-if="activeView === 'notifications'">
          <k-list strong inset class="settings-konsta-list">
            <k-list-item
              v-for="app in notificationApps"
              :key="app.id"
              link
              link-component="button"
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
                  class="settings-app-icon"
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
          <div class="settings-notification-app">
            <img
              :src="selectedNotificationApp.iconImage"
              alt=""
              draggable="false"
            />
            <strong>{{ phone.t(selectedNotificationApp.labelKey) }}</strong>
          </div>
          <k-list strong inset class="settings-konsta-list">
            <k-list-item :title="phone.t('Apps.settings.allowNotifications')">
              <template #after>
                <k-toggle
                  component="div"
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
                  component="div"
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
            {{ phone.t('Apps.settings.ringtoneVolume') }}
          </k-block-title>
          <k-list strong inset class="settings-konsta-list settings-range-list">
            <k-list-item>
              <template #inner>
                <div class="settings-range-row">
                  <Volume1 :size="17" />
                  <k-range
                    :value="phone.preferences.settings.ringtoneVolume"
                    :min="0"
                    :max="100"
                    @input="updateVolume('ringtoneVolume', $event)"
                  />
                  <Volume2 :size="19" />
                </div>
              </template>
            </k-list-item>
          </k-list>

          <k-block-title>
            {{ phone.t('Apps.settings.notificationVolume') }}
          </k-block-title>
          <k-list strong inset class="settings-konsta-list settings-range-list">
            <k-list-item>
              <template #inner>
                <div class="settings-range-row">
                  <Volume1 :size="17" />
                  <k-range
                    :value="phone.preferences.settings.notificationVolume"
                    :min="0"
                    :max="100"
                    @input="updateVolume('notificationVolume', $event)"
                  />
                  <Volume2 :size="19" />
                </div>
              </template>
            </k-list-item>
          </k-list>

          <k-block-title>{{ phone.t('Apps.settings.ringtone') }}</k-block-title>
          <k-list strong inset class="settings-konsta-list">
            <k-list-item
              v-for="ringtone in RINGTONE_IDS"
              :key="ringtone"
              link
              link-component="button"
              :chevron="false"
              :title="phone.t(`Apps.settings.ringtones.${ringtone}`)"
              @click="selectRingtone(ringtone)"
            >
              <template #after>
                <Check
                  v-if="phone.preferences.settings.ringtone === ringtone"
                  :size="19"
                  class="settings-check"
                />
              </template>
            </k-list-item>
          </k-list>

          <k-block-title>
            {{ phone.t('Apps.settings.notificationSound') }}
          </k-block-title>
          <k-list strong inset class="settings-konsta-list">
            <k-list-item
              v-for="sound in NOTIFICATION_SOUND_IDS"
              :key="sound"
              link
              link-component="button"
              :chevron="false"
              :title="phone.t(`Apps.settings.notificationSoundsList.${sound}`)"
              @click="selectNotificationSound(sound)"
            >
              <template #after>
                <Check
                  v-if="phone.preferences.settings.notificationSound === sound"
                  :size="19"
                  class="settings-check"
                />
              </template>
            </k-list-item>
          </k-list>
        </template>

        <template v-else-if="activeView === 'general'">
          <k-block-title>{{ phone.t('Apps.settings.about') }}</k-block-title>
          <k-list strong inset class="settings-konsta-list">
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
          <k-list strong inset class="settings-konsta-list">
            <k-list-item
              v-for="mode in APPEARANCE_MODE_IDS"
              :key="mode"
              link
              link-component="button"
              :chevron="false"
              :title="phone.t(`Apps.settings.${mode}`)"
              @click="selectAppearanceMode(mode)"
            >
              <template #after>
                <Check
                  v-if="phone.preferences.settings.appearanceMode === mode"
                  :size="19"
                  class="settings-check"
                />
              </template>
            </k-list-item>
          </k-list>

          <k-block-title>
            {{ phone.t('Apps.settings.phoneScale') }} ·
            {{ phone.preferences.settings.phoneScale }}%
          </k-block-title>
          <k-list strong inset class="settings-konsta-list settings-range-list">
            <k-list-item>
              <template #inner>
                <div class="settings-scale-row">
                  <span>A</span>
                  <k-range
                    :value="phone.preferences.settings.phoneScale"
                    :min="85"
                    :max="115"
                    :step="5"
                    @input="updateVolume('phoneScale', $event)"
                  />
                  <strong>A</strong>
                </div>
              </template>
            </k-list-item>
          </k-list>

          <k-block-title>
            {{ phone.t('Apps.settings.phoneFrame') }}
          </k-block-title>
          <div class="settings-frame-picker">
            <button
              v-for="frame in PHONE_FRAME_IDS"
              :key="frame"
              type="button"
              :class="{
                active: phone.preferences.settings.frame === frame,
              }"
              :aria-label="phone.t(`Apps.settings.frames.${frame}`)"
              @click="selectFrame(frame)"
            >
              <img :src="PHONE_FRAME_IMAGES[frame]" alt="" draggable="false" />
              <span>{{ phone.t(`Apps.settings.frames.${frame}`) }}</span>
            </button>
          </div>
        </template>

        <template v-else-if="activeView === 'wallpaper'">
          <k-block-title>
            {{ phone.t('Apps.settings.wallpaperPicker') }}
          </k-block-title>
          <section class="wallpaper-picker settings-wallpaper-picker">
            <button
              v-for="wallpaper in WALLPAPER_IDS"
              :key="wallpaper"
              type="button"
              :class="[
                `wallpaper--${wallpaper}`,
                {
                  active: phone.preferences.settings.wallpaper === wallpaper,
                },
              ]"
              :aria-label="phone.t(`Apps.settings.wallpapers.${wallpaper}`)"
              @click="phone.setWallpaper(wallpaper)"
            />
          </section>
        </template>
      </section>
    </template>
  </k-page>
</template>
