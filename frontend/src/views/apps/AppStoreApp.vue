<script setup lang="ts">
import { kPreloader } from 'konsta/vue'
import { Gamepad2, Grid2X2, Search } from 'lucide-vue-next'
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'

import { PHONE_APPS } from '@/config/apps'
import { useAppStoreStore } from '@/stores/app-store'
import { usePhoneStore } from '@/stores/phone'
import type { PhoneAppDefinition } from '@/types/apps'

const phone = usePhoneStore()
const appStore = useAppStoreStore()
const router = useRouter()
const tab = ref<'apps' | 'games' | 'search'>('apps')
const query = ref('')
const tabs = [
  { id: 'apps', icon: Grid2X2 },
  { id: 'games', icon: Gamepad2 },
  { id: 'search', icon: Search },
] as const
const catalog = PHONE_APPS.filter((app) => app.id !== 'app-store').sort(
  (a, b) => a.gridOrder - b.gridOrder,
)
const shownApps = computed(() => {
  if (tab.value === 'games') {
    return catalog.filter((app) => app.category === 'games')
  }
  if (tab.value === 'apps') {
    return catalog.filter((app) => app.category !== 'games')
  }

  const search = query.value.trim().toLocaleLowerCase(phone.lang)
  if (!search) return catalog
  return catalog.filter((app) =>
    phone.t(app.labelKey).toLocaleLowerCase(phone.lang).includes(search),
  )
})

function isInstalled(app: PhoneAppDefinition): boolean {
  return app.category !== 'games' || appStore.claimedApps.includes(app.id)
}

function handleApp(app: PhoneAppDefinition): void {
  if (isInstalled(app)) {
    if (app.route) void router.push(app.route)
    return
  }

  appStore.installApp(app.id)
}
</script>

<template>
  <main class="native-app reference-store">
    <section class="store-scroll">
      <header class="store-title">
        <h1>{{ phone.t(`Apps.appStore.tabs.${tab}`) }}</h1>
      </header>

      <div v-if="tab === 'search'" class="app-search">
        <Search :size="17" />
        <input
          v-model="query"
          :placeholder="phone.t('Apps.appStore.searchPlaceholder')"
        />
      </div>

      <div class="store-section-title">
        <h2>
          {{
            phone.t(
              tab === 'games'
                ? 'Apps.appStore.gamesTitle'
                : 'Apps.appStore.appsTitle',
            )
          }}
        </h2>
        <p>{{ phone.t('Apps.appStore.selected') }}</p>
      </div>

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
              appStore.installingApps[app.id]
                ? 'Apps.appStore.installing'
                : isInstalled(app)
                  ? 'Apps.appStore.open'
                  : 'Apps.appStore.get',
            )}`"
            @click="handleApp(app)"
          >
            <k-preloader
              v-if="appStore.installingApps[app.id]"
              class="store-installing"
              :size="16"
            />
            <template v-else>
              {{
                phone.t(
                  isInstalled(app) ? 'Apps.appStore.open' : 'Apps.appStore.get',
                )
              }}
            </template>
          </button>
        </article>
        <p v-if="shownApps.length === 0" class="store-empty">
          {{ phone.t('Home.noApps') }}
        </p>
      </section>
    </section>

    <nav class="reference-tabbar">
      <button
        v-for="item in tabs"
        :key="item.id"
        :class="{ active: tab === item.id }"
        type="button"
        @click="tab = item.id"
      >
        <component :is="item.icon" :size="21" />
        <span>{{ phone.t(`Apps.appStore.tabs.${item.id}`) }}</span>
      </button>
    </nav>
  </main>
</template>
