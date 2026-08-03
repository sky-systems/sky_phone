<script setup lang="ts">
import {
  Gamepad2,
  Grid2X2,
  Rocket,
  Search,
  Sparkles,
  UserRound,
} from 'lucide-vue-next'
import { computed, ref } from 'vue'

import { useMediaStore } from '@/stores/media'
import { usePhoneStore } from '@/stores/phone'

const phone = usePhoneStore()
const media = useMediaStore()
const tab = ref<'today' | 'apps' | 'games' | 'arcade' | 'search'>('today')
const query = ref('')
const tabs = [
  { id: 'today', icon: Sparkles },
  { id: 'apps', icon: Grid2X2 },
  { id: 'games', icon: Gamepad2 },
  { id: 'arcade', icon: Rocket },
  { id: 'search', icon: Search },
] as const
const catalog = [
  {
    id: 'orbit',
    title: 'Orbit',
    subtitle: 'Apps.appStore.catalog.orbit',
    gradient: 'linear-gradient(145deg,#453bd1,#75e8ff)',
  },
  {
    id: 'studio',
    title: 'Studio',
    subtitle: 'Apps.appStore.catalog.studio',
    gradient: 'linear-gradient(145deg,#ff8b4a,#ff2d75)',
  },
  {
    id: 'trail',
    title: 'Trail',
    subtitle: 'Apps.appStore.catalog.trail',
    gradient: 'linear-gradient(145deg,#4bd37b,#147ec1)',
  },
  {
    id: 'prism',
    title: 'Prism',
    subtitle: 'Apps.appStore.catalog.prism',
    gradient: 'linear-gradient(145deg,#ffd84d,#7b36dc)',
  },
]
const shown = computed(() =>
  catalog.filter((item) =>
    item.title.toLowerCase().includes(query.value.toLowerCase()),
  ),
)
const date = new Intl.DateTimeFormat(phone.lang, {
  day: 'numeric',
  month: 'long',
}).format(new Date())
</script>

<template>
  <main class="native-app reference-store">
    <section class="store-scroll">
      <header class="store-title">
        <div>
          <h1>{{ phone.t(`Apps.appStore.tabs.${tab}`) }}</h1>
          <strong v-if="tab === 'today'">{{ date }}</strong>
        </div>
        <span><UserRound :size="22" /></span>
      </header>
      <div v-if="tab === 'search'" class="app-search">
        <Search :size="17" /><input
          v-model="query"
          :placeholder="phone.t('Apps.appStore.searchPlaceholder')"
        />
      </div>
      <template v-if="tab === 'today'">
        <article class="editorial-card editorial-card--sky">
          <small>{{ phone.t('Apps.appStore.card.oneEyebrow') }}</small>
          <h2>{{ phone.t('Apps.appStore.card.oneTitle') }}</h2>
          <p>{{ phone.t('Apps.appStore.card.oneBody') }}</p>
          <div class="editorial-orbit">✦</div>
        </article>
        <article class="editorial-card editorial-card--music">
          <small>{{ phone.t('Apps.appStore.card.twoEyebrow') }}</small>
          <h2>{{ phone.t('Apps.appStore.card.twoTitle') }}</h2>
          <p>{{ phone.t('Apps.appStore.card.twoBody') }}</p>
          <div class="editorial-wave" />
        </article>
        <div class="store-section-title">
          <h2>{{ phone.t('Apps.appStore.communityTitle') }}</h2>
          <p>{{ phone.t('Apps.appStore.communityBody') }}</p>
        </div>
        <article class="editorial-card editorial-card--play">
          <small>{{ phone.t('Apps.appStore.card.threeEyebrow') }}</small>
          <h2>{{ phone.t('Apps.appStore.card.threeTitle') }}</h2>
          <p>{{ phone.t('Apps.appStore.card.threeBody') }}</p>
        </article>
      </template>
      <template v-else>
        <article v-if="tab !== 'search'" class="store-feature">
          <p>{{ phone.t('Apps.appStore.featured') }}</p>
          <h2>{{ phone.t('Apps.appStore.heroTitle') }}</h2>
          <span>{{ phone.t('Apps.appStore.heroBody') }}</span>
        </article>
        <div class="store-section-title">
          <h2>
            {{
              phone.t(
                tab === 'games'
                  ? 'Apps.appStore.playing'
                  : 'Apps.appStore.recommended',
              )
            }}
          </h2>
          <p>{{ phone.t('Apps.appStore.selected') }}</p>
        </div>
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
      </template>
    </section>
    <nav class="reference-tabbar">
      <button
        v-for="item in tabs"
        :key="item.id"
        :class="{ active: tab === item.id }"
        type="button"
        @click="tab = item.id"
      >
        <component :is="item.icon" :size="21" /><span>{{
          phone.t(`Apps.appStore.tabs.${item.id}`)
        }}</span>
      </button>
    </nav>
  </main>
</template>
