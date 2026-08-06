<script setup lang="ts">
import { Heart, Images, Library, Search } from 'lucide-vue-next'
import { computed, ref } from 'vue'

import { useMediaStore } from '@/stores/media'
import { usePhoneStore } from '@/stores/phone'
import type { PhonePhoto } from '@/stores/media'

const media = useMediaStore()
const phone = usePhoneStore()
const tab = ref<'library' | 'forYou' | 'albums' | 'search'>('library')
const query = ref('')
const tabs = [
  { id: 'library', icon: Library },
  { id: 'forYou', icon: Heart },
  { id: 'albums', icon: Images },
  { id: 'search', icon: Search },
] as const
const gallery = computed(() =>
  Array.from(
    { length: 54 },
    (_, index) => media.photos[index % media.photos.length],
  ),
)
const filtered = computed(() =>
  media.photos.filter((photo) =>
    phone.t(photo.titleKey).toLowerCase().includes(query.value.toLowerCase()),
  ),
)

function photoStyle(photo?: PhonePhoto): Record<string, string> {
  if (!photo) return {}
  return {
    background: photo.gradient,
    ...(photo.url
      ? {
          backgroundImage: `url(${photo.url})`,
          backgroundPosition: 'center',
          backgroundSize: 'cover',
        }
      : {}),
  }
}
</script>

<template>
  <main class="native-app reference-photos">
    <section v-if="tab === 'library'" class="photos-library">
      <header class="photos-floating-header">
        <div>
          <strong>{{ phone.t('Apps.photos.dateRange') }}</strong
          ><span>{{ phone.t('Apps.photos.place') }}</span>
        </div>
        <button type="button">{{ phone.t('Apps.photos.select') }}</button
        ><button type="button">•••</button>
      </header>
      <div class="reference-photo-grid">
        <article
          v-for="(photo, index) in gallery"
          :key="`${photo.id}-${index}`"
          :style="photoStyle(photo)"
        />
      </div>
      <p class="photos-count">{{ phone.t('Apps.photos.count') }}</p>
      <div class="photos-period">
        <button>{{ phone.t('Apps.photos.years') }}</button
        ><button>{{ phone.t('Apps.photos.months') }}</button
        ><button>{{ phone.t('Apps.photos.days') }}</button
        ><button class="active">{{ phone.t('Apps.photos.allPhotos') }}</button>
      </div>
    </section>
    <section v-else-if="tab === 'forYou'" class="photos-scroll">
      <h1>{{ phone.t('Apps.photos.tabs.forYou') }}</h1>
      <div class="photos-section-title">
        <h2>{{ phone.t('Apps.photos.memories') }}</h2>
        <button>{{ phone.t('Apps.photos.seeAll') }}</button>
      </div>
      <article
        class="memory-card"
        :style="photoStyle(media.photos[1])"
      >
        <Heart :size="25" />
        <div>
          <strong>{{ phone.t('Apps.photos.onThisDay') }}</strong
          ><span>{{ phone.t('Apps.photos.trip') }}</span>
        </div>
      </article>
      <div class="photos-section-title">
        <h2>{{ phone.t('Apps.photos.featuredPhotos') }}</h2>
      </div>
      <div class="featured-row">
        <article v-for="photo in media.photos.slice(0, 2)" :key="photo.id">
          <div :style="photoStyle(photo)" />
          <strong>{{ phone.t(photo.titleKey) }}</strong
          ><span>{{ phone.t('Apps.photos.featuredDate') }}</span>
        </article>
      </div>
    </section>
    <section v-else-if="tab === 'albums'" class="photos-scroll">
      <h1>{{ phone.t('Apps.photos.tabs.albums') }}</h1>
      <div class="album-cards">
        <article>
          <div
            class="photo-tile"
            :style="photoStyle(media.photos[0])"
          />
          <strong>{{ phone.t('Apps.photos.recents') }}</strong
          ><small
            >{{ media.photos.length }} {{ phone.t('Apps.photos.items') }}</small
          >
        </article>
        <article>
          <div class="photo-tile favorites" />
          <strong>{{ phone.t('Apps.photos.favorites') }}</strong
          ><small>2 {{ phone.t('Apps.photos.items') }}</small>
        </article>
      </div>
    </section>
    <section v-else class="photos-scroll">
      <h1>{{ phone.t('Apps.photos.tabs.search') }}</h1>
      <div class="app-search">
        <Search :size="17" /><input
          v-model="query"
          :placeholder="phone.t('Apps.photos.searchPlaceholder')"
        />
      </div>
      <div class="photo-grid">
        <article
          v-for="photo in filtered"
          :key="photo.id"
          class="photo-tile"
          :style="photoStyle(photo)"
        />
      </div>
    </section>
    <nav class="reference-tabbar">
      <button
        v-for="item in tabs"
        :key="item.id"
        :class="{ active: tab === item.id }"
        type="button"
        @click="tab = item.id"
      >
        <component :is="item.icon" :size="22" /><span>{{
          phone.t(`Apps.photos.tabs.${item.id}`)
        }}</span>
      </button>
    </nav>
  </main>
</template>
