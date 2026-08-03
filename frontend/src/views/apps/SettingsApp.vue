<script setup lang="ts">
import { computed, ref } from 'vue'
import { Bluetooth, Search, Wifi, Radio } from 'lucide-vue-next'
import { usePhoneStore } from '@/stores/phone'
import { WALLPAPER_IDS } from '@/utils/preferences'
const phone = usePhoneStore()
const query = ref('')
const rows = [
  { key: 'wifi', icon: Wifi, color: '#1677ff' },
  { key: 'bluetooth', icon: Bluetooth, color: '#1677ff' },
  { key: 'airplaneMode', icon: Radio, color: '#ff9500' },
] as const
const shown = computed(() =>
  rows.filter((row) =>
    phone
      .t(`Apps.settings.${row.key}`)
      .toLowerCase()
      .includes(query.value.toLowerCase()),
  ),
)
</script>
<template>
  <main class="native-app settings-app">
    <header class="app-header">
      <h1>{{ phone.t('Apps.settings.name') }}</h1>
    </header>
    <div class="app-search">
      <Search :size="17" /><input
        v-model="query"
        :placeholder="phone.t('Apps.settings.searchPlaceholder')"
      />
    </div>
    <section class="settings-list">
      <div v-for="row in shown" :key="row.key" class="settings-row">
        <span class="settings-symbol" :style="{ background: row.color }"
          ><component :is="row.icon" :size="16" /></span
        ><span>{{ phone.t(`Apps.settings.${row.key}`) }}</span
        ><button
          class="ios-switch"
          :class="{ active: phone.preferences.settings[row.key] }"
          type="button"
          :aria-label="phone.t(`Apps.settings.toggle.${row.key}`)"
          @click="
            phone.setSetting(row.key, !phone.preferences.settings[row.key])
          "
        >
          <span />
        </button>
      </div>
    </section>
    <h2 class="settings-section-title">
      {{ phone.t('Apps.settings.wallpaper') }}
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
  </main>
</template>
