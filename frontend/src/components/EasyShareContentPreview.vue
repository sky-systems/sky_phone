<script setup lang="ts">
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { SkySheet, SkyButton } from '@/ui'
import { usePhoneStore } from '@/stores/phone'
const route = useRoute(),
  router = useRouter(),
  phone = usePhoneStore()
const profile = computed(() => {
  if (
    typeof route.query.sharedContent !== 'string' ||
    route.query.sharedContent.length > 65536
  )
    return null
  try {
    const data = JSON.parse(route.query.sharedContent) as Record<
      string,
      unknown
    >
    if (typeof data.title !== 'string' || typeof data.body !== 'string')
      return null
    const items = Array.isArray(data.items)
      ? data.items.slice(0, 20).flatMap((item: unknown) => {
          if (!item || typeof item !== 'object') return []
          const media = item as Record<string, unknown>
          return typeof media.url === 'string' &&
            /^https:\/\//.test(media.url) &&
            ['photo', 'video'].includes(String(media.mediaType))
            ? [{ url: media.url, video: media.mediaType === 'video' }]
            : []
        })
      : []
    return {
      items,
      title: data.title,
      body: data.body,
      imageUrl:
        typeof data.imageUrl === 'string' && /^https:\/\//.test(data.imageUrl)
          ? data.imageUrl
          : null,
    }
  } catch {
    return null
  }
})
function close(): void {
  const query = { ...route.query }
  delete query.sharedContent
  void router.replace({ path: route.path, query })
}
</script>
<template>
  <SkySheet
    :opened="Boolean(profile)"
    :aria-label="phone.t('Apps.easyShare.share')"
    @backdropclick="close"
    @escape="close"
    @swipeclose="close"
    @grabberclick="close"
  >
    <section v-if="profile" class="shared-profile-preview">
      <img
        v-if="profile.imageUrl && !profile.items.length"
        :src="profile.imageUrl"
        alt=""
      />
      <template v-for="item in profile.items" :key="item.url">
        <video
          v-if="item.video"
          :src="item.url"
          controls
          playsinline
          preload="metadata"
        />
        <img v-else :src="item.url" alt="" />
      </template>
      <h2>{{ profile.title }}</h2>
      <p>{{ profile.body }}</p>
      <SkyButton glass rounded @click="close">{{
        phone.t('Common.close')
      }}</SkyButton>
    </section>
  </SkySheet>
</template>
<style scoped>
.shared-profile-preview {
  padding: var(--sky-space-4);
  overflow-y: auto;
  max-height: 75cqh;
}
.shared-profile-preview img,
.shared-profile-preview video {
  width: 100%;
  max-height: 35cqh;
  object-fit: cover;
  border-radius: var(--sky-radius-card);
}
.shared-profile-preview p {
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}
</style>
