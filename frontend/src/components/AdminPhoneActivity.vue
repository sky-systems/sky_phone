<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue'
import { ChevronDown, ScrollText } from 'lucide-vue-next'

import { useAdminQuery } from '@/composables/useAdminQuery'
import { useAdminStore } from '@/stores/admin'
import { usePhoneStore } from '@/stores/phone'
import type { AdminPhoneActivities, AdminPhoneActivity } from '@/types/admin'
import {
  SkyButton,
  SkyEmptyState,
  SkyField,
  SkyAdminRecords,
  SkyProvider,
} from '@/ui'
import {
  adminActivityPreview,
  adminErrorText,
  formatAdminTimestamp,
} from '@/utils/adminRecords'

const props = defineProps<{ targetSource?: number; targetName?: string }>()
const phone = usePhoneStore()
const admin = useAdminStore()
const scope = ref(props.targetSource ? 'player' : 'all')
const category = ref('')
const page = ref(0)
const failedPage = ref(0)
const pageCursors = ref<Array<string | undefined>>([undefined])
const heading = ref<HTMLElement | null>(null)
const formattedDetails = ref<Record<string, string>>({})
const records = useAdminQuery<AdminPhoneActivities>()
const { data, loading, error } = records
const errorText = computed(() => adminErrorText(error.value, phone.t))
const target = computed(() =>
  scope.value === 'player' ? props.targetSource : undefined,
)
const t = (key: string) => phone.t(`AdminPanel.activity.${key}`)
const categories = [
  'Account',
  'Admin',
  'Banking',
  'Billing',
  'Calendar',
  'Calls',
  'CityWarn',
  'Companies',
  'Contacts',
  'CrewLink',
  'Crypto',
  'CustomApps',
  'DarkChat',
  'Device',
  'EasyShare',
  'Feather',
  'Flare',
  'FlipTok',
  'Gallery',
  'Garage',
  'Health',
  'Housing',
  'Mail',
  'Map',
  'Marketplace',
  'Memos',
  'Messages',
  'Music',
  'Notes',
  'Pages',
  'Picstagram',
  'Radio',
  'Security',
  'Sim',
  'SkyPic',
  'SkyRide',
  'Uploads',
  'WeazelNews',
]
const categoryLabel = (value: string) =>
  phone.t(`AdminPanel.webhooks.categoryLabels.${value}`)
const categoryOptions = computed(() => [
  { value: '', label: t('allApps') },
  ...categories.map((value) => ({ value, label: categoryLabel(value) })),
])
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
function stateLabel(status: string): string {
  const key = `AdminPanel.activity.states.${status}`
  const label = phone.t(key)
  return label === key ? t('states.changed') : label
}
function formatDetails(entry: AdminPhoneActivity, event: Event): void {
  if (
    (event.target as HTMLDetailsElement).open &&
    !formattedDetails.value[entry.id]
  ) {
    formattedDetails.value[entry.id] = JSON.stringify(entry.details, null, 2)
  }
}
async function load(nextPage = page.value): Promise<void> {
  const beforeId = pageCursors.value[nextPage]
  failedPage.value = nextPage
  const loaded = await records.load(() =>
    admin.loadPhoneActivity({
      source: target.value,
      category: category.value || undefined,
      beforeId,
    }),
  )
  if (!loaded || !data.value) return
  page.value = nextPage
  pageCursors.value = [
    ...pageCursors.value.slice(0, nextPage + 1),
    ...(data.value.hasMore && data.value.nextBeforeId
      ? [data.value.nextBeforeId]
      : []),
  ]
  formattedDetails.value = {}
  await nextTick()
  heading.value?.scrollIntoView({ block: 'start' })
}

watch(
  [target, category],
  () => {
    records.invalidate()
    page.value = 0
    pageCursors.value = [undefined]
    formattedDetails.value = {}
    void load(0)
  },
  { immediate: true },
)
</script>

<template>
  <SkyProvider
    class="admin-activity"
    dark
    :safe-areas="false"
    accent="var(--admin-accent)"
  >
    <header ref="heading" class="admin-activity__heading">
      <h1>{{ t('title') }}</h1>
      <p>{{ t('intro') }}</p>
    </header>
    <div class="admin-activity__filters">
      <SkyField
        v-model="scope"
        component="div"
        type="select"
        variant="admin"
        dropdown
        :label="t('scope')"
        :options="scopeOptions"
      />
      <SkyField
        v-model="category"
        component="div"
        type="select"
        variant="admin"
        dropdown
        :label="t('app')"
        :options="categoryOptions"
      />
    </div>
    <details class="admin-activity__help">
      <summary>{{ t('about') }}</summary>
      <p>{{ t('body') }}</p>
    </details>
    <SkyEmptyState v-if="error" tone="danger" :title="errorText"
      ><template #actions
        ><SkyButton :disabled="loading" @click="load(failedPage)">{{
          t('retry')
        }}</SkyButton></template
      ></SkyEmptyState
    >
    <p v-if="loading" role="status">{{ phone.t('Common.loading') }}</p>
    <SkyEmptyState
      v-else-if="!error && !data?.items.length"
      :title="t('empty')"
      :body="t('emptyBody')"
    />
    <SkyAdminRecords
      v-if="data?.items.length"
      class="admin-activity__list"
      :aria-busy="loading"
    >
      <li
        v-for="entry in data.items"
        :key="entry.id"
        class="admin-activity__entry"
      >
        <details @toggle="formatDetails(entry, $event)">
          <summary class="sky-admin-records__summary">
            <span class="sky-admin-records__icon"
              ><ScrollText :size="15"
            /></span>
            <span class="sky-admin-records__copy">
              <span class="sky-admin-records__title"
                ><strong
                  >{{ categoryLabel(entry.category) }} ·
                  {{ stateLabel(entry.status) }}</strong
                ><time>{{
                  formatAdminTimestamp(entry.createdAt, phone.lang)
                }}</time></span
              >
              <span class="sky-admin-records__meta"
                >{{ entry.actorName }} · {{ t('playerId') }}
                {{ entry.actorSource }}</span
              >
              <span
                v-if="adminActivityPreview(entry.details)"
                class="sky-admin-records__preview"
                >{{ adminActivityPreview(entry.details) }}</span
              >
            </span>
            <ChevronDown class="sky-admin-records__chevron" :size="14" />
          </summary>
          <div class="sky-admin-records__details">
            <p v-if="adminActivityPreview(entry.details)">
              {{ adminActivityPreview(entry.details) }}
            </p>
            <dl>
              <dt>{{ t('action') }}</dt>
              <dd>
                <code>{{ entry.action }}</code>
              </dd>
              <template v-if="entry.imei"
                ><dt>{{ t('device') }}</dt>
                <dd>{{ entry.imei }}</dd></template
              >
              <template v-if="entry.phoneNumber"
                ><dt>{{ t('number') }}</dt>
                <dd>{{ entry.phoneNumber }}</dd></template
              >
            </dl>
            <pre v-if="formattedDetails[entry.id]">{{
              formattedDetails[entry.id]
            }}</pre>
          </div>
        </details>
      </li>
    </SkyAdminRecords>
    <nav
      v-if="data"
      class="admin-activity__pagination"
      :aria-label="t('pagination')"
    >
      <SkyButton
        inline
        variant="plain"
        :disabled="page === 0 || loading"
        @click="load(page - 1)"
        >{{ phone.t('AdminPanel.social.previous') }}</SkyButton
      >
      <span>{{ page + 1 }}</span>
      <SkyButton
        inline
        variant="plain"
        :disabled="!data.hasMore || loading"
        @click="load(page + 1)"
        >{{ t('older') }}</SkyButton
      >
    </nav>
  </SkyProvider>
</template>

<style scoped>
.admin-activity {
  display: grid;
  gap: 12px;
  padding: 0;
  color: var(--admin-text, var(--sky-text));
}
.admin-activity__heading {
  display: grid;
  gap: 4px;
}
.admin-activity h1,
.admin-activity p {
  margin: 0;
}
.admin-activity h1 {
  font-size: calc(20 * var(--admin-unit, 1px));
  font-weight: 600;
}
.admin-activity__heading p,
.admin-activity__help {
  color: var(--admin-muted, var(--sky-text));
  font-size: 12px;
  line-height: 1.5;
}
.admin-activity__help summary {
  display: inline-flex;
  align-items: center;
  min-height: var(--sky-touch-target);
  cursor: pointer;
}
.admin-activity__help p {
  max-width: 80ch;
  padding-bottom: 8px;
}
.admin-activity__filters {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
  gap: 12px;
}
.admin-activity__pagination {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  font-size: 12px;
}
.admin-activity__pagination :deep(.sky-button) {
  color: var(--sky-button-text, #fff);
  border-radius: 3px;
  min-height: var(--sky-touch-target);
  font-size: 12px;
}
@media (max-width: 600px) {
  .admin-activity__filters {
    grid-template-columns: 1fr;
  }
}
</style>
