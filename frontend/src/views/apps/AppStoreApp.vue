<script setup lang="ts">
import {
  kNavbar,
  kPage,
  kPreloader,
  kSearchbar,
  kSegmented,
  kSegmentedButton,
} from 'konsta/vue'
import { Gamepad2, Grid2X2, Search } from 'lucide-vue-next'
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'

import { PHONE_APPS } from '@/config/apps'
import { useAppStoreStore } from '@/stores/app-store'
import { usePhoneStore } from '@/stores/phone'
import type {
  LaunchablePhoneAppDefinition,
  LaunchablePhoneAppId,
} from '@/types/apps'

const phone = usePhoneStore()
const appStore = useAppStoreStore()
const router = useRouter()
const tab = ref<'apps' | 'games' | 'search'>('apps')
const query = ref('')
const installedDuringVisit = ref<LaunchablePhoneAppId[]>([])
const tabs = [
  { id: 'apps', icon: Grid2X2 },
  { id: 'games', icon: Gamepad2 },
  { id: 'search', icon: Search },
] as const
const tabBarColors = {
  strongHighlightBgIos: 'bg-[#e5e5ea] dark:bg-[#2c2c2e]',
}
const catalog = computed(() =>
  PHONE_APPS.filter((app): app is LaunchablePhoneAppDefinition => {
    if (
      app.component === null ||
      app.route === null ||
      app.id === 'app-store'
    ) {
      return false
    }

    const installed =
      app.category !== 'games' || appStore.claimedApps.includes(app.id)
    return (
      !installed ||
      appStore.homeLayout.hidden.includes(app.id) ||
      installedDuringVisit.value.includes(app.id)
    )
  }).sort((a, b) => a.gridOrder - b.gridOrder),
)
const shownApps = computed(() => {
  if (tab.value === 'games') {
    return catalog.value.filter((app) => app.category === 'games')
  }
  if (tab.value === 'apps') {
    return catalog.value.filter((app) => app.category !== 'games')
  }

  const search = query.value.trim().toLocaleLowerCase(phone.lang)
  if (!search) return catalog.value
  return catalog.value.filter((app) =>
    phone.t(app.labelKey).toLocaleLowerCase(phone.lang).includes(search),
  )
})

function updateSearch(event: Event): void {
  query.value = (event.target as HTMLInputElement).value
}

function appAction(
  app: LaunchablePhoneAppDefinition,
): 'get' | 'installing' | 'open' {
  if (appStore.installingApps[app.id]) return 'installing'

  const installed =
    app.category !== 'games' || appStore.claimedApps.includes(app.id)
  if (
    installed &&
    !appStore.homeLayout.hidden.includes(app.id) &&
    installedDuringVisit.value.includes(app.id)
  ) {
    return 'open'
  }

  return 'get'
}

function handleApp(app: LaunchablePhoneAppDefinition): void {
  if (appAction(app) === 'open') {
    void router.push(app.route)
    return
  }

  if (!installedDuringVisit.value.includes(app.id)) {
    installedDuringVisit.value.push(app.id)
  }
  appStore.installApp(app.id)
}
</script>

<template>
  <k-page component="main" class="native-app app-store-page">
    <k-navbar
      large
      transparent
      :title="phone.t('Apps.appStore.name')"
      class="top-0 sticky"
    >
      <template v-if="tab === 'search'" #subnavbar>
        <k-searchbar
          :value="query"
          :placeholder="phone.t('Apps.appStore.searchPlaceholder')"
          @input="updateSearch"
          @clear="query = ''"
        />
      </template>
    </k-navbar>

    <section class="store-scroll">
      <section class="store-list">
        <article v-for="app in shownApps" :key="app.id">
          <img
            class="store-icon"
            :src="app.iconImage"
            alt=""
            draggable="false"
          />
          <div>
            <strong>{{ phone.t(app.labelKey) }}</strong>
            <small>{{ phone.t(`Home.groups.${app.category}`) }}</small>
          </div>
          <button
            type="button"
            :disabled="appStore.installingApps[app.id]"
            :aria-label="`${phone.t(app.labelKey)} ${phone.t(
              `Apps.appStore.${appAction(app)}`,
            )}`"
            @click="handleApp(app)"
          >
            <k-preloader
              v-if="appStore.installingApps[app.id]"
              class="store-installing"
            />
            <template v-else>
              {{ phone.t(`Apps.appStore.${appAction(app)}`) }}
            </template>
          </button>
        </article>
        <p v-if="shownApps.length === 0" class="store-empty">
          {{ phone.t('Home.noApps') }}
        </p>
      </section>
    </section>

    <k-navbar component="nav" :aria-label="phone.t('Apps.appStore.name')">
      <template #subnavbar>
        <k-segmented
          strong
          rounded
          :colors="tabBarColors"
          :data-active-tab="tab"
        >
          <k-segmented-button
            v-for="item in tabs"
            :key="item.id"
            large
            :active="tab === item.id"
            :class="tab === item.id ? 'text-primary' : 'text-[#8e8e93]'"
            :aria-label="phone.t(`Apps.appStore.tabs.${item.id}`)"
            :aria-pressed="tab === item.id"
            @click="tab = item.id"
          >
            <span
              class="flex flex-col items-center gap-0.5 text-[10px] leading-none"
            >
              <component :is="item.icon" class="h-5 w-5" aria-hidden="true" />
              <span>{{ phone.t(`Apps.appStore.tabs.${item.id}`) }}</span>
            </span>
          </k-segmented-button>
        </k-segmented>
      </template>
    </k-navbar>
  </k-page>
</template>
