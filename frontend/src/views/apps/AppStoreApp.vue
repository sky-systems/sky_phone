<script setup lang="ts">
import { computed, ref } from 'vue'
import { Search } from 'lucide-vue-next'
import { useMediaStore } from '@/stores/media'
import { usePhoneStore } from '@/stores/phone'
const phone = usePhoneStore()
const media = useMediaStore()
const tab = ref('today')
const query = ref('')
const tabs = ['today', 'apps', 'games', 'arcade', 'search']
const catalog = [
  {
    id: 'orbit',
    title: 'Orbit',
    subtitle: 'Apps.appStore.catalog.orbit',
    gradient: 'linear-gradient(135deg,#6f5cff,#29d3c2)',
  },
  {
    id: 'studio',
    title: 'Studio',
    subtitle: 'Apps.appStore.catalog.studio',
    gradient: 'linear-gradient(135deg,#ff8b4a,#ff2d75)',
  },
  {
    id: 'trail',
    title: 'Trail',
    subtitle: 'Apps.appStore.catalog.trail',
    gradient: 'linear-gradient(135deg,#4bd37b,#147ec1)',
  },
  {
    id: 'puzzle',
    title: 'Prism',
    subtitle: 'Apps.appStore.catalog.prism',
    gradient: 'linear-gradient(135deg,#ffd84d,#7b36dc)',
  },
]
const shown = computed(() =>
  catalog.filter((item) =>
    item.title.toLowerCase().includes(query.value.toLowerCase()),
  ),
)
</script>
<template>
  <main class="native-app store-app">
    <header class="app-header">
      <small>{{ phone.t('Apps.appStore.eyebrow') }}</small>
      <h1>{{ phone.t(`Apps.appStore.tabs.${tab}`) }}</h1>
    </header>
    <div v-if="tab === 'search'" class="app-search">
      <Search :size="17" /><input
        v-model="query"
        :placeholder="phone.t('Apps.appStore.searchPlaceholder')"
      />
    </div>
    <section class="store-feature">
      <p>{{ phone.t('Apps.appStore.featured') }}</p>
      <h2>{{ phone.t('Apps.appStore.heroTitle') }}</h2>
      <span>{{ phone.t('Apps.appStore.heroBody') }}</span>
    </section>
    <section class="store-list">
      <article v-for="item in shown" :key="item.id">
        <div class="store-icon" :style="{ background: item.gradient }">
          {{ item.title[0] }}
        </div>
        <div>
          <strong>{{ item.title }}</strong
          ><small>{{ phone.t(item.subtitle) }}</small>
        </div>
        <button type="button" @click="media.claimApp(item.id)">
          {{
            phone.t(
              media.claimedApps.includes(item.id)
                ? 'Apps.appStore.open'
                : 'Apps.appStore.get',
            )
          }}
        </button>
      </article>
    </section>
    <nav class="app-tabs">
      <button
        v-for="item in tabs"
        :key="item"
        :class="{ active: tab === item }"
        type="button"
        @click="tab = item"
      >
        {{ phone.t(`Apps.appStore.tabs.${item}`) }}
      </button>
    </nav>
  </main>
</template>
