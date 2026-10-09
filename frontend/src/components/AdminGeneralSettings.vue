<script setup lang="ts">
import { computed } from 'vue'

import { usePhoneStore } from '@/stores/phone'
import type {
  AdminConfiguratorField,
  AdminConfiguratorSection,
} from '@/types/admin'
import { SkyField, SkySettingsGroup, SkySettingsRow } from '@/ui'
import {
  GENERAL_CONFIGURATOR_GROUPS,
  patchGeneralConfiguratorValue,
  resolveGeneralConfiguratorField,
} from '@/utils/adminConfiguratorGeneral'

import AdminConfigKeybind from './AdminConfigKeybind.vue'

const props = defineProps<{
  sections: AdminConfiguratorSection[]
  drafts: Record<string, unknown>
  disabled: boolean
  query: string
}>()
const emit = defineEmits<{
  update: [field: AdminConfiguratorField, value: unknown]
}>()
const phone = usePhoneStore()
const t = (key: string) => phone.t(`AdminPanel.configurator.general.${key}`)
const groups = computed(() => {
  const needle = props.query.trim().toLocaleLowerCase(phone.lang)
  return GENERAL_CONFIGURATOR_GROUPS.map((group) => ({
    ...group,
    fields: group.paths.flatMap((path) => {
      const resolved = resolveGeneralConfiguratorField(
        props.sections,
        props.drafts,
        path,
      )
      if (!resolved) return []
      const label = t(`fields.${path}.label`)
      const description = t(`fields.${path}.description`)
      if (
        needle &&
        !`${label} ${description} ${path} ${t(`groups.${group.id}`)}`
          .toLocaleLowerCase(phone.lang)
          .includes(needle)
      )
        return []
      return [{ path, label, description, ...resolved }]
    }),
  })).filter((group) => group.fields.length)
})

function update(path: string, next: unknown): void {
  if (props.disabled) return
  const resolved = resolveGeneralConfiguratorField(
    props.sections,
    props.drafts,
    path,
  )
  if (!resolved)
    throw new Error(
      `[sky_phone] General configuration field is unavailable: ${path}`,
    )
  emit(
    'update',
    resolved.field,
    patchGeneralConfiguratorValue(resolved.rootValue, resolved.parts, next),
  )
}

const inventoryOptions = [
  'auto',
  'ak47',
  'codem',
  'core',
  'jaksam',
  'jpr',
  'lj',
  'mf',
  'one',
  'origen',
  'ox',
  'ps',
  'qb',
  'qs',
  'smx',
  'tgiann',
  'hex',
  'esx',
  'qb-inv',
  'qbox',
]
const choices: Record<string, string[]> = {
  'Bridge.Framework': ['auto', 'esx', 'qbox', 'qb'],
  'Bridge.Inventory': inventoryOptions,
  'Bridge.Locale': [
    'ar',
    'cn',
    'cz',
    'de',
    'en',
    'es',
    'fi',
    'fr',
    'it',
    'nl',
    'pl',
    'pt',
    'rs',
    'ru',
    'se',
  ],
  'Calls.VoiceProvider': [
    'auto',
    'pma',
    'saltychat',
    'yaca',
    'pma-voice',
    'salty',
    'yaca-voice',
  ],
}

function options(
  path: string,
  value: unknown,
): { label: string; value: string }[] | undefined {
  const values = choices[path]
  if (!values) return undefined
  const current = String(value)
  return (values.includes(current) ? values : [current, ...values]).map(
    (entry) => ({ value: entry, label: entry }),
  )
}

const metadataFree = computed(() => {
  const inventory = resolveGeneralConfiguratorField(
    props.sections,
    props.drafts,
    'Bridge.Inventory',
  )?.value
  return inventory === 'hex' || inventory === 'esx'
})
</script>

<template>
  <div class="admin-general-settings">
    <p class="admin-general-settings__intro">{{ t('body') }}</p>
    <p v-if="metadataFree" class="admin-general-settings__notice" role="status">
      {{ t('metadataFree') }}
    </p>
    <SkySettingsGroup
      v-for="group in groups"
      :key="group.id"
      :title="t(`groups.${group.id}`)"
    >
      <SkySettingsRow
        v-for="field in group.fields"
        :key="field.path"
        :data-config-path="field.path"
        :title="field.label"
        :description="field.description"
        :kind="
          typeof field.value === 'boolean' && field.path !== 'Phone.Keybind'
            ? 'toggle'
            : 'custom'
        "
        :model-value="field.value === true"
        :disabled="disabled"
        @update:model-value="update(field.path, $event)"
      >
        <template
          v-if="
            typeof field.value !== 'boolean' || field.path === 'Phone.Keybind'
          "
          #trailing
        >
          <AdminConfigKeybind
            v-if="
              field.path === 'Phone.Keybind' ||
              field.path === 'CrewLink.QuickPing.DefaultKey'
            "
            :label="field.label"
            :model-value="field.value"
            :optional="field.path === 'Phone.Keybind'"
            :disabled="disabled"
            @update:model-value="update(field.path, $event)"
          />
          <SkyField
            v-else
            component="div"
            variant="control"
            :dropdown="Boolean(choices[field.path])"
            :aria-label="field.label"
            :type="
              choices[field.path]
                ? 'select'
                : typeof field.value === 'number'
                  ? 'number'
                  : 'text'
            "
            :options="options(field.path, field.value)"
            :model-value="
              typeof field.value === 'number'
                ? field.value
                : String(field.value ?? '')
            "
            :disabled="disabled"
            autocomplete="off"
            @update:model-value="
              update(
                field.path,
                typeof field.value === 'number' ? Number($event) : $event,
              )
            "
          />
        </template>
      </SkySettingsRow>
    </SkySettingsGroup>
    <p v-if="!groups.length">
      {{ phone.t('AdminPanel.configurator.noResults') }}
    </p>
    <p class="admin-general-settings__notice">{{ t('fileOwned') }}</p>
  </div>
</template>

<style scoped>
.admin-general-settings {
  display: grid;
  gap: calc(18 * var(--admin-unit));
  padding: calc(12 * var(--admin-unit));
  min-width: 0;
}
.admin-general-settings__intro,
.admin-general-settings__notice {
  margin: 0;
  color: var(--sky-muted);
  font-size: var(--sky-font-caption);
  line-height: 1.6;
}
.admin-general-settings :deep(.sky-settings-group) {
  margin: 0;
}
</style>
