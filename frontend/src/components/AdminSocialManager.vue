<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { ChevronDown, MessageSquare, Trash2 } from 'lucide-vue-next'

import { useAdminQuery } from '@/composables/useAdminQuery'
import { useAdminStore } from '@/stores/admin'
import { usePhoneStore } from '@/stores/phone'
import type {
  AdminSocialPlatform,
  AdminSocialPost,
  AdminSocialPosts,
} from '@/types/admin'
import {
  SkyButton,
  SkyDialog,
  SkyDialogButton,
  SkyEmptyState,
  SkyField,
  SkyAdminRecords,
  SkyProvider,
} from '@/ui'
import {
  adminErrorText,
  adminMediaUrl,
  formatAdminTimestamp,
} from '@/utils/adminRecords'

const props = defineProps<{
  targetSource?: number
  targetName?: string
  initialPlatform?: AdminSocialPlatform
}>()
const admin = useAdminStore()
const phone = usePhoneStore()
const platform = ref<AdminSocialPlatform>(props.initialPlatform ?? 'feather')
const scope = ref(props.targetSource ? 'player' : 'all')
const query = ref('')
const page = ref(0)
const failedPage = ref(0)
const records = useAdminQuery<AdminSocialPosts>()
const { data, loading, error } = records
const errorText = computed(() => adminErrorText(error.value, phone.t))
let disposed = false
onBeforeUnmount(() => {
  disposed = true
})
const deleting = ref(false)
const pending = ref<{
  platform: AdminSocialPlatform
  post: AdminSocialPost
  targetSource?: number
} | null>(null)
const failedMedia = ref(new Set<string>())
const target = computed(() =>
  scope.value === 'player' ? props.targetSource : undefined,
)
const t = (key: string) => phone.t(`AdminPanel.social.${key}`)
const scopeOptions = computed(() => [
  { value: 'all', label: t('allPlayers') },
  ...(props.targetSource
    ? [
        {
          value: 'player',
          label: props.targetName ?? String(props.targetSource),
        },
      ]
    : []),
])
const options = computed(() => [
  { value: 'feather', label: phone.t('Apps.feather.name') },
  { value: 'fliptok', label: phone.t('Apps.fliptok.name') },
  { value: 'picstagram', label: phone.t('Apps.picstagram.name') },
  { value: 'skypic', label: t('skyPicSpotlight') },
  { value: 'skypic-stories', label: t('skyPicStories') },
  { value: 'weazel-news', label: phone.t('Apps.weazelNews.name') },
])

async function load(nextPage = 0): Promise<void> {
  failedPage.value = nextPage
  const requestPlatform = platform.value
  const requestTarget = target.value
  const loaded = await records.load(() =>
    admin.loadSocialPosts(
      requestPlatform,
      query.value.trim(),
      nextPage,
      requestTarget,
    ),
  )
  if (loaded) page.value = nextPage
}

async function remove(): Promise<void> {
  if (!pending.value || deleting.value) return
  const request = pending.value
  deleting.value = true
  error.value = ''
  try {
    const response = await admin.deleteSocialPost(
      request.platform,
      request.post.id,
      request.targetSource,
    )
    if (
      disposed ||
      request.platform !== platform.value ||
      request.targetSource !== target.value
    )
      return
    if (!response.success) {
      error.value = response.error ?? 'request_failed'
      return
    }
    pending.value = null
    if (
      request.platform === platform.value &&
      request.targetSource === target.value
    ) {
      await load(page.value)
      if (data.value?.items.length === 0 && page.value > 0)
        await load(page.value - 1)
    }
  } finally {
    deleting.value = false
  }
}

watch(
  [platform, target],
  () => {
    records.invalidate()
    page.value = 0
    pending.value = null
    failedMedia.value = new Set()
    void load()
  },
  { immediate: true },
)
</script>

<template>
  <SkyProvider
    class="admin-social"
    dark
    :safe-areas="false"
    accent="var(--admin-accent)"
  >
    <header class="admin-social__heading">
      <h1>{{ t('title') }}</h1>
      <p>{{ t('intro') }}</p>
    </header>
    <form class="admin-social__search" @submit.prevent="load()">
      <SkyField
        v-model="scope"
        component="div"
        variant="admin"
        dropdown
        type="select"
        :label="t('scope')"
        :options="scopeOptions"
        :disabled="deleting"
      />
      <SkyField
        v-model="platform"
        component="div"
        variant="admin"
        dropdown
        type="select"
        :label="t('platform')"
        :options="options"
        :disabled="deleting"
      />
      <SkyField
        v-model="query"
        component="div"
        variant="admin"
        type="search"
        :label="t('search')"
        :maxlength="100"
        :disabled="deleting"
      />
      <SkyButton type="submit" :disabled="loading || deleting">{{
        t('searchButton')
      }}</SkyButton>
    </form>
    <section
      v-if="target && data"
      class="admin-social__accounts"
      :aria-label="t('accounts')"
    >
      <h2>{{ t('accounts') }}</h2>
      <ul v-if="data.accounts?.length">
        <li v-for="account in data.accounts" :key="account.id">
          <strong>{{ account.displayName }}</strong>
          <span>@{{ account.handle }}</span>
        </li>
      </ul>
      <p v-else>{{ t('noAccounts') }}</p>
      <details class="admin-social__help">
        <summary>{{ t('about') }}</summary>
        <p>{{ t('accountScope') }}</p>
      </details>
    </section>
    <SkyEmptyState v-if="error" tone="danger" :title="errorText"
      ><template #actions
        ><SkyButton :disabled="loading || deleting" @click="load(failedPage)">{{
          phone.t('AdminPanel.activity.retry')
        }}</SkyButton></template
      ></SkyEmptyState
    >
    <p v-if="loading" role="status">{{ phone.t('Common.loading') }}</p>
    <SkyEmptyState
      v-else-if="!error && !data?.items.length"
      :title="t('empty')"
    />
    <SkyAdminRecords
      v-if="data?.items.length"
      class="admin-social__posts"
      :aria-busy="loading"
    >
      <li v-for="post in data.items" :key="post.id" class="admin-social__post">
        <div class="admin-social__row">
          <details>
            <summary class="sky-admin-records__summary">
              <img
                v-if="
                  post.media?.[0]?.type === 'photo' &&
                  adminMediaUrl(post.media[0].url) &&
                  !failedMedia.has(post.media[0].url)
                "
                class="admin-social__thumbnail"
                :src="adminMediaUrl(post.media[0].url)"
                :alt="t('attachment')"
                loading="lazy"
                @error="failedMedia.add(post.media[0].url)"
              />
              <span v-else class="sky-admin-records__icon"
                ><MessageSquare :size="15"
              /></span>
              <span class="sky-admin-records__copy">
                <span class="sky-admin-records__title"
                  ><strong>{{ post.displayName || post.author }}</strong
                  ><time>{{
                    formatAdminTimestamp(post.createdAt, phone.lang)
                  }}</time></span
                >
                <span class="sky-admin-records__meta"
                  >@{{ post.author }} ·
                  {{
                    phone.t(
                      `AdminPanel.activity.states.${post.status || 'published'}`,
                    )
                  }}</span
                >
                <strong v-if="post.title" class="admin-social__post-title">{{
                  post.title
                }}</strong>
                <span class="sky-admin-records__preview">{{
                  post.body || t('mediaPost')
                }}</span>
              </span>
              <ChevronDown class="sky-admin-records__chevron" :size="14" />
            </summary>
            <div class="sky-admin-records__details">
              <p>{{ post.body || t('mediaPost') }}</p>
              <span v-if="post.expiresAt" class="sky-admin-records__meta"
                >{{ t('expires') }}
                {{ formatAdminTimestamp(post.expiresAt, phone.lang) }}</span
              >
              <small>{{ post.id }}</small>
              <div v-if="post.media?.length" class="admin-social__media">
                <template
                  v-for="(media, index) in post.media"
                  :key="`${post.id}:${index}`"
                >
                  <p
                    v-if="
                      !adminMediaUrl(media.url) || failedMedia.has(media.url)
                    "
                    role="status"
                  >
                    {{ t('mediaUnavailable') }}
                  </p>
                  <img
                    v-else-if="media.type === 'photo'"
                    :src="adminMediaUrl(media.url)"
                    :alt="t('attachment')"
                    loading="lazy"
                    @error="failedMedia.add(media.url)"
                  />
                  <video
                    v-else-if="media.type === 'video'"
                    :src="adminMediaUrl(media.url)"
                    controls
                    playsinline
                    preload="none"
                    :aria-label="t('attachment')"
                    @error="failedMedia.add(media.url)"
                  />
                  <audio
                    v-else
                    :src="adminMediaUrl(media.url)"
                    controls
                    preload="none"
                    :aria-label="t('attachment')"
                    @error="failedMedia.add(media.url)"
                  />
                </template>
              </div>
            </div>
          </details>
          <SkyButton
            variant="plain"
            icon-only
            class="admin-social__remove"
            :aria-label="t('delete')"
            :title="t('delete')"
            :disabled="
              loading ||
              deleting ||
              post.status === 'removed' ||
              post.status === 'deleted'
            "
            @click="pending = { platform, post, targetSource: target }"
            ><Trash2 :size="15"
          /></SkyButton>
        </div>
      </li>
    </SkyAdminRecords>
    <nav class="admin-social__pagination" :aria-label="t('pagination')">
      <SkyButton
        inline
        variant="plain"
        :disabled="page === 0 || loading || deleting"
        @click="load(page - 1)"
        >{{ t('previous') }}</SkyButton
      ><span>{{ page + 1 }}</span
      ><SkyButton
        inline
        variant="plain"
        :disabled="!data?.hasMore || loading || deleting"
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
      <template #buttons
        ><SkyDialogButton :disabled="deleting" @click="pending = null">{{
          t('cancel')
        }}</SkyDialogButton
        ><SkyDialogButton :disabled="deleting" @click="remove">{{
          t('delete')
        }}</SkyDialogButton></template
      >
    </SkyDialog>
  </SkyProvider>
</template>

<style scoped>
.admin-social {
  display: grid;
  gap: 12px;
  padding: 0;
  color: var(--admin-text, var(--sky-text));
}
.admin-social h1,
.admin-social h2,
.admin-social p {
  margin: 0;
}
.admin-social__heading {
  display: grid;
  gap: 4px;
}
.admin-social h1 {
  font-size: calc(20 * var(--admin-unit, 1px));
  font-weight: 600;
}
.admin-social h2 {
  font-size: 13px;
  font-weight: 550;
}
.admin-social__heading p,
.admin-social__accounts p,
.admin-social__help {
  font-size: 12px;
  line-height: 1.5;
  color: var(--admin-muted, var(--sky-text));
}
.admin-social__search {
  display: grid;
  grid-template-columns: 1fr 1fr 2fr auto;
  gap: 12px;
  align-items: end;
}
.admin-social__search :deep(.sky-button),
.admin-social__pagination :deep(.sky-button) {
  color: var(--sky-button-text, #fff);
  min-height: var(--sky-touch-target);
  border-radius: 3px;
  font-size: 12px;
}
.admin-social__accounts {
  display: grid;
  gap: 6px;
  padding: 10px 0;
  border-bottom: 1px solid var(--admin-border-strong, var(--sky-hairline));
}
.admin-social__accounts ul {
  display: flex;
  flex-wrap: wrap;
  gap: 8px 20px;
  list-style: none;
  margin: 0;
  padding: 0;
  font-size: 12px;
}
.admin-social__accounts li {
  display: flex;
  gap: 6px;
}
.admin-social__accounts li span {
  color: var(--admin-muted, var(--sky-text));
}
.admin-social__help summary {
  display: inline-flex;
  align-items: center;
  min-height: var(--sky-touch-target);
  cursor: pointer;
}
.admin-social__help p {
  max-width: 80ch;
}
.admin-social__row {
  display: flex;
  align-items: start;
}
.admin-social__row > details {
  flex: 1;
  min-width: 0;
}
.admin-social__thumbnail {
  width: 30px;
  height: 30px;
  border-radius: 3px;
  object-fit: cover;
}
.admin-social__post-title {
  font-size: 12px;
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
}
.admin-social__remove {
  flex: none;
  min-width: var(--sky-touch-target);
  min-height: var(--sky-touch-target);
  color: #fff;
  margin-top: 8px;
}
.admin-social__media {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
  gap: 10px;
}
.admin-social__media img,
.admin-social__media video {
  width: 100%;
  max-height: 300px;
  object-fit: contain;
  border-radius: 3px;
}
.admin-social__media audio {
  width: 100%;
}
.admin-social__pagination {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  font-size: 12px;
}
@media (max-width: 900px) {
  .admin-social__search {
    grid-template-columns: 1fr 1fr;
  }
}
@media (max-width: 600px) {
  .admin-social__search {
    grid-template-columns: 1fr;
  }
}
</style>
