<script setup lang="ts">
import { computed, ref } from 'vue'

import { useAdminStore } from '@/stores/admin'
import { usePhoneStore } from '@/stores/phone'
import type {
  AdminWebhookEndpoint,
  AdminWebhookMode,
  AdminWebhookOptions,
} from '@/types/admin'
import { SkyButton, SkyField, SkyToggle } from '@/ui'

defineProps<{ disabled?: boolean }>()
const emit = defineEmits<{ reload: [] }>()
const admin = useAdminStore()
const phone = usePhoneStore()
const query = ref('')
const category = ref('all')
const scope = ref('categories')
const t = (key: string) => phone.t(`AdminPanel.webhooks.${key}`)
const modes = computed(() =>
  (['file', 'inherit', 'disabled', 'custom'] as const).map((value) => ({
    value,
    label: t(`modes.${value}`),
  })),
)
const categoryOptions = computed(() => [
  { value: 'all', label: t('allCategories') },
  ...[...new Set(admin.webhooks?.endpoints.map((row) => row.category) ?? [])]
    .filter((value) => value !== 'Default')
    .sort()
    .map((value) => ({ value, label: value })),
])
const endpoints = computed(() =>
  (admin.webhooks?.endpoints ?? []).filter((row) => {
    const isAction = row.path.startsWith('Actions.')
    return (
      (scope.value === 'actions' ? isAction : !isAction) &&
      (category.value === 'all' ||
        row.category === category.value ||
        row.path === 'Default') &&
      row.path
        .toLocaleLowerCase()
        .includes(query.value.trim().toLocaleLowerCase())
    )
  }),
)

function option<K extends keyof AdminWebhookOptions>(
  key: K,
): AdminWebhookOptions[K] {
  const draft = admin.webhookDrafts[key]
  if (draft?.mode === 'file') return admin.webhooks!.defaults[key]
  return (draft?.value ??
    admin.webhooks!.settings[key]) as AdminWebhookOptions[K]
}

function updateOption(
  key: keyof AdminWebhookOptions,
  value: boolean | number | string,
): void {
  if (value === admin.webhooks?.settings[key]) delete admin.webhookDrafts[key]
  else admin.webhookDrafts[key] = { path: key, value }
}

function mode(row: AdminWebhookEndpoint): AdminWebhookMode {
  return admin.webhookDrafts[row.path]?.mode ?? row.mode
}

function updateEndpoint(
  row: AdminWebhookEndpoint,
  nextMode: string,
  url = '',
): void {
  if (nextMode === row.mode && !url) delete admin.webhookDrafts[row.path]
  else
    admin.webhookDrafts[row.path] = {
      path: row.path,
      mode: nextMode as AdminWebhookMode,
      ...(nextMode === 'custom' && url ? { url: url.trim() } : {}),
    }
}
</script>

<template>
  <div class="admin-webhooks">
    <header class="admin-webhooks__heading">
      <div>
        <h1>{{ t('title') }}</h1>
        <p>{{ t('body') }}</p>
      </div>
      <SkyButton
        inline
        variant="secondary"
        :disabled="disabled || admin.webhooksLoading"
        @click="emit('reload')"
      >
        {{ t('reload') }}
      </SkyButton>
    </header>
    <p v-if="admin.webhooksLoading" role="status">{{ t('loading') }}</p>
    <template v-else-if="admin.webhooks">
      <fieldset :disabled="disabled" class="admin-webhooks__options">
        <legend>{{ t('general') }}</legend>
        <SkyToggle
          :model-value="option('Enabled')"
          @update:model-value="updateOption('Enabled', $event)"
        >
          {{ t('enabled') }}
        </SkyToggle>
        <SkyField
          outline
          component="div"
          :label="t('username')"
          :model-value="option('Username')"
          :maxlength="80"
          @update:model-value="updateOption('Username', $event)"
        />
        <SkyField
          outline
          component="div"
          type="url"
          :label="t('avatarUrl')"
          :help="t('avatarHelp')"
          :model-value="option('AvatarUrl')"
          :maxlength="2048"
          @update:model-value="updateOption('AvatarUrl', $event)"
        />
        <SkyField
          outline
          component="div"
          type="number"
          :label="t('queueLimit')"
          :model-value="option('QueueLimit')"
          :min="1"
          :max="10000"
          :step="1"
          @update:model-value="updateOption('QueueLimit', Number($event))"
        />
        <SkyField
          outline
          component="div"
          type="number"
          :label="t('maxAttempts')"
          :model-value="option('MaxAttempts')"
          :min="1"
          :max="10"
          :step="1"
          @update:model-value="updateOption('MaxAttempts', Number($event))"
        />
        <SkyButton
          variant="secondary"
          @click="
            Object.keys(admin.webhooks.settings).forEach(
              (path) => (admin.webhookDrafts[path] = { path, mode: 'file' }),
            )
          "
        >
          {{ t('resetGeneral') }}
        </SkyButton>
      </fieldset>
      <div class="admin-webhooks__filters">
        <SkyField
          outline
          v-model="scope"
          component="div"
          type="select"
          :label="t('scope')"
          :options="[
            { value: 'categories', label: t('categories') },
            { value: 'actions', label: t('actions') },
          ]"
        />
        <SkyField
          outline
          v-model="category"
          component="div"
          type="select"
          :label="t('category')"
          :options="categoryOptions"
        />
        <SkyField
          outline
          v-model="query"
          component="div"
          type="search"
          :label="t('search')"
        />
      </div>
      <p class="admin-webhooks__hint">{{ t('routingHelp') }}</p>
      <p v-if="!endpoints.length">{{ t('empty') }}</p>
      <fieldset
        v-for="row in endpoints"
        :key="row.path"
        :disabled="disabled"
        class="admin-webhooks__endpoint"
      >
        <legend>
          {{
            row.path === 'Default'
              ? t('default')
              : row.path.replace(/^Actions\./, '')
          }}
        </legend>
        <p>
          {{ t(row.configured ? 'configured' : 'notConfigured') }} ·
          {{ t(`modes.${row.effectiveMode}`) }}
        </p>
        <SkyField
          outline
          component="div"
          type="select"
          :label="t('destination')"
          :options="modes"
          :model-value="mode(row)"
          @update:model-value="updateEndpoint(row, $event)"
        />
        <SkyField
          outline
          v-if="mode(row) === 'custom'"
          component="div"
          type="password"
          inputmode="url"
          autocomplete="new-password"
          autocapitalize="none"
          autocorrect="off"
          :spellcheck="false"
          :label="t('url')"
          :maxlength="512"
          :placeholder="t(row.configured ? 'keepExisting' : 'enterUrl')"
          :help="t('secretHelp')"
          :model-value="admin.webhookDrafts[row.path]?.url ?? ''"
          @update:model-value="updateEndpoint(row, 'custom', $event)"
        />
      </fieldset>
    </template>
  </div>
</template>

<style scoped>
.admin-webhooks {
  --sky-text: var(--admin-text);
  --sky-muted: var(--admin-muted);
  --sky-surface: var(--admin-panel-raised);
  --sky-surface-variant: var(--admin-panel-hover);
  --sky-hairline: var(--admin-border-strong);
  --sky-field-placeholder: var(--admin-muted);
  --sky-native-select-option-background: var(--admin-panel-raised);
  --sky-native-select-option-text: var(--admin-text);
  color-scheme: dark;
  display: grid;
  gap: var(--sky-space-4, 16px);
  color: var(--sky-text);
}
.admin-webhooks__heading {
  display: flex;
  gap: var(--sky-space-4, 16px);
  align-items: flex-start;
  justify-content: space-between;
}
.admin-webhooks__heading > .sky-button {
  flex: 0 0 auto;
  width: auto;
}
.admin-webhooks .admin-webhooks__options {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}
.admin-webhooks__options > .sky-toggle,
.admin-webhooks__options > .sky-button {
  grid-column: 1 / -1;
}
.admin-webhooks h1 {
  font-size: 22px;
  font-weight: 700;
}
.admin-webhooks p {
  color: var(--sky-muted);
  font-size: 13px;
  line-height: 1.5;
  overflow-wrap: anywhere;
}
.admin-webhooks fieldset {
  display: grid;
  min-width: 0;
  gap: var(--sky-space-3, 12px);
  padding: var(--sky-space-4, 16px);
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-control);
  background: var(--sky-surface);
}
.admin-webhooks legend {
  padding-inline: var(--sky-space-2, 8px);
  font-weight: 600;
  overflow-wrap: anywhere;
}
.admin-webhooks__filters {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: var(--sky-space-3, 12px);
}
.admin-webhooks :deep(.sky-field__input),
.admin-webhooks :deep(.sky-button),
.admin-webhooks :deep(.sky-toggle) {
  min-height: 44px;
}
@media (max-width: 900px) {
  .admin-webhooks__heading {
    flex-wrap: wrap;
  }
  .admin-webhooks__filters {
    grid-template-columns: 1fr;
  }
  .admin-webhooks .admin-webhooks__options {
    grid-template-columns: 1fr;
  }
}
</style>
