<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useAdminStore } from '@/stores/admin'
import { usePhoneStore } from '@/stores/phone'
import type { AdminSocialPlatform, AdminSocialPost } from '@/types/admin'
import {
  SkyButton,
  SkyDialog,
  SkyDialogButton,
  SkyEmptyState,
  SkyField,
  SkyListCard,
} from '@/ui'

const admin = useAdminStore()
const phone = usePhoneStore()
const platform = ref<AdminSocialPlatform>('feather')
const query = ref('')
const page = ref(0)
const posts = ref<AdminSocialPost[]>([])
const hasMore = ref(false)
const loading = ref(false)
const deleting = ref(false)
const error = ref('')
const pending = ref<{
  platform: AdminSocialPlatform
  post: AdminSocialPost
} | null>(null)
let requestId = 0
const t = (key: string) => phone.t(`AdminPanel.social.${key}`)
const options = computed(() => [
  { value: 'feather', label: phone.t('Apps.feather.name') },
  { value: 'fliptok', label: phone.t('Apps.fliptok.name') },
  { value: 'picstagram', label: phone.t('Apps.picstagram.name') },
  { value: 'weazel-news', label: phone.t('Apps.weazelNews.name') },
])

async function load(nextPage = 0): Promise<void> {
  const request = ++requestId
  loading.value = true
  posts.value = []
  hasMore.value = false
  error.value = ''
  const response = await admin.loadSocialPosts(
    platform.value,
    query.value.trim(),
    nextPage,
  )
  if (request !== requestId) return
  loading.value = false
  if (!response.success || !response.data) {
    error.value = phone.t(
      `AdminPanel.errors.${response.error ?? 'request_failed'}`,
    )
    return
  }
  posts.value = response.data.items
  hasMore.value = response.data.hasMore
  page.value = nextPage
}

async function remove(): Promise<void> {
  if (!pending.value || deleting.value) return
  const target = pending.value
  deleting.value = true
  error.value = ''
  const response = await admin.deleteSocialPost(target.platform, target.post.id)
  deleting.value = false
  if (!response.success) {
    error.value = phone.t(
      `AdminPanel.errors.${response.error ?? 'request_failed'}`,
    )
    return
  }
  pending.value = null
  await load(page.value)
}

onMounted(() => void load())
</script>

<template>
  <div class="admin-social">
    <header>
      <h1>{{ t('title') }}</h1>
      <p>{{ t('body') }}</p>
    </header>
    <form class="admin-social__search" @submit.prevent="load()">
      <SkyField
        v-model="platform"
        component="div"
        outline
        dropdown
        type="select"
        :label="t('platform')"
        :options="options"
        :disabled="loading || deleting"
        @change="load()"
      />
      <SkyField
        v-model="query"
        component="div"
        outline
        type="search"
        :label="t('search')"
        :maxlength="100"
        :disabled="loading || deleting"
      />
      <SkyButton type="submit" :disabled="loading || deleting">{{
        t('searchButton')
      }}</SkyButton>
    </form>
    <p v-if="error" role="alert">{{ error }}</p>
    <p v-if="loading" role="status">{{ phone.t('Common.loading') }}</p>
    <SkyEmptyState v-else-if="posts.length === 0" :title="t('empty')" />
    <SkyListCard v-for="post in posts" :key="post.id">
      <article class="admin-social__post">
        <header>
          <strong>{{ post.author }}</strong
          ><time>{{ post.createdAt }}</time>
        </header>
        <h2 v-if="post.title">{{ post.title }}</h2>
        <p>{{ post.body || t('mediaPost') }}</p>
        <small>{{ post.id }}</small>
        <SkyButton
          :disabled="loading || deleting"
          @click="pending = { platform, post }"
          >{{ t('delete') }}</SkyButton
        >
      </article>
    </SkyListCard>
    <nav class="admin-social__pagination" :aria-label="t('pagination')">
      <SkyButton
        :disabled="page === 0 || loading || deleting"
        @click="load(page - 1)"
        >{{ t('previous') }}</SkyButton
      >
      <span>{{ page + 1 }}</span>
      <SkyButton
        :disabled="!hasMore || loading || deleting"
        @click="load(page + 1)"
        >{{ t('next') }}</SkyButton
      >
    </nav>
    <SkyDialog
      :opened="pending !== null"
      :title="t('confirmTitle')"
      :content="t('confirmBody')"
      @escape="!deleting && (pending = null)"
      @backdropclick="!deleting && (pending = null)"
    >
      <p v-if="pending">{{ pending.post.author }} · {{ pending.post.id }}</p>
      <template #buttons>
        <SkyDialogButton :disabled="deleting" @click="pending = null">{{
          t('cancel')
        }}</SkyDialogButton>
        <SkyDialogButton :disabled="deleting" @click="remove">{{
          t('delete')
        }}</SkyDialogButton>
      </template>
    </SkyDialog>
  </div>
</template>

<style scoped>
.admin-social {
  display: grid;
  gap: var(--sky-space-5);
  padding: var(--sky-space-6);
}
.admin-social__search {
  display: grid;
  grid-template-columns: 1fr 2fr auto;
  gap: 12px;
  align-items: end;
}
.admin-social__post {
  display: grid;
  gap: 12px;
  padding: 16px;
  overflow-wrap: anywhere;
}
.admin-social__post header,
.admin-social__pagination {
  display: flex;
  gap: 16px;
  align-items: center;
  justify-content: space-between;
}
.admin-social__post p {
  white-space: pre-wrap;
}
.admin-social__post :deep(button),
.admin-social__pagination :deep(button) {
  min-height: 44px;
}
@media (max-width: 700px) {
  .admin-social__search {
    grid-template-columns: 1fr;
  }
}
</style>
