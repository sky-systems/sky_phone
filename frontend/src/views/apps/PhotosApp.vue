<script setup lang="ts">
import { computed, ref } from 'vue'
import { Search } from 'lucide-vue-next'
import { useMediaStore } from '@/stores/media'
import { usePhoneStore } from '@/stores/phone'
const media = useMediaStore()
const phone = usePhoneStore()
const tab = ref('library')
const query = ref('')
const tabs = ['library', 'forYou', 'albums', 'search']
const photos = computed(() =>
  media.photos.filter((photo) =>
    phone.t(photo.titleKey).toLowerCase().includes(query.value.toLowerCase()),
  ),
)
</script>
<template>
  <main class="native-app photos-app">
    <header class="app-header">
      <h1>{{ phone.t(`Apps.photos.tabs.${tab}`) }}</h1>
    </header>
    <div v-if="tab === 'search'" class="app-search">
      <Search :size="17" /><input
        v-model="query"
        :placeholder="phone.t('Apps.photos.searchPlaceholder')"
      />
    </div>
    <section v-if="tab === 'albums'" class="album-cards">
      <article>
        <div
          class="photo-tile"
          :style="{ background: media.photos[0]?.gradient }"
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
    </section>
    <section v-else-if="tab === 'forYou'" class="featured-photo">
      <p>{{ phone.t('Apps.photos.memories') }}</p>
      <div :style="{ background: media.photos[1]?.gradient }">
        <span>{{ phone.t('Apps.photos.featured') }}</span>
      </div>
    </section>
    <section v-else class="photo-grid">
      <article
        v-for="photo in photos"
        :key="photo.id"
        class="photo-tile"
        :style="{ background: photo.gradient }"
        :aria-label="phone.t(photo.titleKey)"
      />
    </section>
    <nav class="app-tabs">
      <button
        v-for="item in tabs"
        :key="item"
        :class="{ active: tab === item }"
        type="button"
        @click="tab = item"
      >
        {{ phone.t(`Apps.photos.tabs.${item}`) }}
      </button>
    </nav>
  </main>
</template>
