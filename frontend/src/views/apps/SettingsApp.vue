<script setup lang="ts">
import {
  Accessibility,
  BatteryMedium,
  BellRing,
  Bluetooth,
  ChevronRight,
  Clock3,
  Focus,
  Globe2,
  Grid2X2,
  KeyRound,
  LockKeyhole,
  Monitor,
  Plane,
  Radio,
  Search,
  Settings,
  Smartphone,
  Sun,
  UserRound,
  Volume2,
  Wifi,
} from 'lucide-vue-next'
import { computed, ref } from 'vue'

import { usePhoneStore } from '@/stores/phone'
import { WALLPAPER_IDS } from '@/utils/preferences'

const phone = usePhoneStore()
const query = ref('')
const groups = [
  [
    { key: 'airplaneMode', icon: Plane, color: '#ff9500', toggle: true },
    {
      key: 'wifi',
      icon: Wifi,
      color: '#0a84ff',
      value: 'SkyNet 5G',
      toggle: true,
    },
    {
      key: 'bluetooth',
      icon: Bluetooth,
      color: '#0a84ff',
      valueKey: 'Apps.settings.on',
      toggle: true,
    },
    { key: 'mobileServices', icon: Radio, color: '#30d158' },
    { key: 'personalHotspot', icon: Smartphone, color: '#30d158' },
    { key: 'vpn', icon: Globe2, color: '#0a84ff' },
  ],
  [
    { key: 'notifications', icon: BellRing, color: '#ff453a' },
    { key: 'sounds', icon: Volume2, color: '#ff2d55' },
    { key: 'focus', icon: Focus, color: '#5e5ce6' },
    { key: 'screenTime', icon: Clock3, color: '#5e5ce6' },
  ],
  [
    { key: 'general', icon: Settings, color: '#8e8e93' },
    { key: 'display', icon: Sun, color: '#0a84ff' },
    { key: 'homeScreen', icon: Grid2X2, color: '#5e5ce6' },
    { key: 'accessibility', icon: Accessibility, color: '#0a84ff' },
    { key: 'wallpaper', icon: Monitor, color: '#64d2ff' },
    { key: 'battery', icon: BatteryMedium, color: '#30d158' },
    { key: 'privacy', icon: LockKeyhole, color: '#0a84ff' },
  ],
  [{ key: 'passwords', icon: KeyRound, color: '#636366' }],
]
const filteredGroups = computed(() =>
  groups
    .map((group) =>
      group.filter((row) =>
        phone
          .t(`Apps.settings.${row.key}`)
          .toLowerCase()
          .includes(query.value.toLowerCase()),
      ),
    )
    .filter((group) => group.length),
)
</script>

<template>
  <main class="native-app reference-settings">
    <section class="settings-scroll">
      <h1>{{ phone.t('Apps.settings.name') }}</h1>
      <div class="settings-search">
        <Search :size="17" /><input
          v-model="query"
          :placeholder="phone.t('Apps.settings.searchPlaceholder')"
        />
      </div>
      <article class="settings-account">
        <span><UserRound :size="34" /></span>
        <div>
          <strong>{{ phone.t('Apps.settings.accountName') }}</strong
          ><small>{{ phone.t('Apps.settings.accountDetail') }}</small>
        </div>
        <ChevronRight :size="19" />
      </article>
      <section
        v-for="(group, groupIndex) in filteredGroups"
        :key="groupIndex"
        class="reference-settings-group"
      >
        <article v-for="row in group" :key="row.key">
          <span class="settings-symbol" :style="{ background: row.color }"
            ><component :is="row.icon" :size="16"
          /></span>
          <div>
            <strong>{{ phone.t(`Apps.settings.${row.key}`) }}</strong
            ><small v-if="row.value">{{ row.value }}</small
            ><small v-else-if="row.valueKey">{{ phone.t(row.valueKey) }}</small>
          </div>
          <button
            v-if="row.toggle"
            class="ios-switch"
            :class="{
              active:
                phone.preferences.settings[
                  row.key as 'airplaneMode' | 'wifi' | 'bluetooth'
                ],
            }"
            type="button"
            :aria-label="phone.t(`Apps.settings.toggle.${row.key}`)"
            @click="
              phone.setSetting(
                row.key as 'airplaneMode' | 'wifi' | 'bluetooth',
                !phone.preferences.settings[
                  row.key as 'airplaneMode' | 'wifi' | 'bluetooth'
                ],
              )
            "
          >
            <span /></button
          ><ChevronRight v-else :size="18" class="settings-chevron" />
        </article>
      </section>
      <h2 class="settings-section-title">
        {{ phone.t('Apps.settings.wallpaperPicker') }}
      </h2>
      <section class="wallpaper-picker">
        <button
          v-for="wallpaper in WALLPAPER_IDS"
          :key="wallpaper"
          type="button"
          :class="[
            `wallpaper--${wallpaper}`,
            { active: phone.preferences.settings.wallpaper === wallpaper },
          ]"
          :aria-label="phone.t(`Apps.settings.wallpapers.${wallpaper}`)"
          @click="phone.setWallpaper(wallpaper)"
        />
      </section>
    </section>
  </main>
</template>
