<script setup lang="ts">
import {
  ChevronDown,
  Plus,
  Rows3,
  TableProperties,
  Trash2,
} from 'lucide-vue-next'
import { computed, ref } from 'vue'

import { vConfigInputWidth } from '@/directives/configInputWidth'
import type { AdminConfiguratorStructure } from '@/types/admin'
import {
  blankFromConfiguratorStructure,
  createMutableTableEntry,
} from '@/utils/adminConfiguratorDefaults'
import type { AdminConfiguratorDescribe } from '@/utils/adminConfiguratorDescription'

export type AdminConfigEditorLabels = {
  addField: string
  addRow: string
  configuredSecret: string
  convertToList: string
  convertToMap: string
  convertToTable: string
  emptyList: string
  emptyTable: string
  entry: string
  general: string
  keyPlaceholder: string
  list: string
  remove: string
  table: string
  types: {
    boolean: string
    list: string
    number: string
    string: string
    table: string
  }
  vector: string
}

defineOptions({ name: 'AdminConfigValueEditor' })

const props = withDefaults(
  defineProps<{
    ariaLabel?: string
    depth?: number
    describe: AdminConfiguratorDescribe
    disabled?: boolean
    labels: AdminConfigEditorLabels
    modelValue: unknown
    path?: string
    structure?: AdminConfiguratorStructure
    tabLabel?: (key: string, value: unknown) => string
  }>(),
  { ariaLabel: '', depth: 0, disabled: false, path: '' },
)
const emit = defineEmits<{ 'update:modelValue': [value: unknown] }>()

type ValueKind = 'boolean' | 'list' | 'number' | 'string' | 'table'
type MapKeyKind = 'number' | 'string'
type SerializedMapEntry = {
  key: number | string
  keyType: MapKeyKind
  value: unknown
}
type RootTableTab = { count: number; id: string; key?: string; label: string }

const newArrayKind = ref<ValueKind>('string')
const newObjectKey = ref('')
const newObjectKind = ref<ValueKind>('string')
const newMapKey = ref('')
const newMapKeyKind = ref<MapKeyKind>('string')
const newMapValueKind = ref<ValueKind>('string')
const expandedEntry = ref<string | null>(null)
const selectedTableTab = ref('')

const isList = computed(
  () =>
    props.structure?.kind === 'list' ||
    (props.structure?.kind !== 'map' &&
      props.structure?.kind !== 'table' &&
      Array.isArray(props.modelValue)),
)
const listValue = computed<unknown[]>(() =>
  Array.isArray(props.modelValue) ? props.modelValue : [],
)
const isTable = computed(
  () =>
    props.structure?.kind === 'map' ||
    props.structure?.kind === 'table' ||
    props.structure?.kind === 'vector' ||
    (props.modelValue !== null &&
      typeof props.modelValue === 'object' &&
      !Array.isArray(props.modelValue)),
)
const tableValue = computed<Record<string, unknown>>(() =>
  isTable.value && !Array.isArray(props.modelValue)
    ? (props.modelValue as Record<string, unknown>)
    : {},
)
const vectorType = computed(() => {
  const value = tableValue.value.__skyType
  return typeof value === 'string' && /^vector[234]$/.test(value) ? value : ''
})
const mapType = computed(
  () => props.structure?.kind === 'map' || tableValue.value.__skyType === 'map',
)
const mapEntries = computed<SerializedMapEntry[]>(() => {
  const entries = tableValue.value.entries
  if (!mapType.value || !Array.isArray(entries)) return []
  return entries.filter(
    (entry): entry is SerializedMapEntry =>
      entry !== null &&
      typeof entry === 'object' &&
      (entry.keyType === 'number' || entry.keyType === 'string'),
  )
})
const listStructure = computed(() =>
  props.structure?.kind === 'list' ? props.structure : null,
)
const listTemplate = computed(
  () => listStructure.value?.template ?? listStructure.value?.items[0],
)
const tableStructure = computed(() =>
  props.structure?.kind === 'table' ? props.structure : null,
)
const mapStructure = computed(() =>
  props.structure?.kind === 'map' ? props.structure : null,
)
const mapTemplate = computed(() => mapStructure.value?.template)
const newMapEntryKeyKind = computed<MapKeyKind>(
  () => mapStructure.value?.keyType ?? newMapKeyKind.value,
)
const canAddTableField = computed(() => {
  const key = newObjectKey.value.trim()
  if (
    !key ||
    key === '__skyType' ||
    Object.prototype.hasOwnProperty.call(tableValue.value, key)
  )
    return false
  return !tableStructure.value?.mutableKeys || /^[a-z0-9_-]+$/.test(key)
})
const canExtendTable = computed(
  () =>
    !vectorType.value &&
    (!tableStructure.value || tableStructure.value.mutableKeys === true),
)
const usesFixedTableLayout = computed(
  () =>
    Boolean(tableStructure.value) && tableStructure.value?.mutableKeys !== true,
)
const tableEntries = computed(() =>
  Object.entries(tableValue.value).filter(
    ([key]) => key !== '__skyType' && (!mapType.value || key !== 'entries'),
  ),
)
const rootTableTabs = computed<RootTableTab[]>(() => {
  if (props.depth !== 0 || !tableStructure.value || mapType.value) return []
  const structuredEntries = tableEntries.value.filter(([key, value]) =>
    isStructuredValue(value, tableFieldStructure(key)),
  )
  if (!structuredEntries.length) return []
  const scalarCount = tableEntries.value.length - structuredEntries.length
  return [
    ...(scalarCount
      ? [{ count: scalarCount, id: 'general', label: props.labels.general }]
      : []),
    ...structuredEntries.map(([key]) => ({
      count: configuratorStructureSize(tableFieldStructure(key)),
      id: `field:${key}`,
      key,
      label: props.tabLabel?.(key, tableValue.value[key]) ?? key,
    })),
  ]
})
const activeRootTableTab = computed(
  () =>
    rootTableTabs.value.find((tab) => tab.id === selectedTableTab.value) ??
    rootTableTabs.value[0] ??
    null,
)
const activeRootTableField = computed(() => {
  const key = activeRootTableTab.value?.key
  if (!key) return null
  const entry = tableEntries.value.find(([candidate]) => candidate === key)
  return entry ? { key: entry[0], value: entry[1] } : null
})
const visibleTableEntries = computed(() => {
  if (!rootTableTabs.value.length) return tableEntries.value
  if (activeRootTableField.value) return []
  return tableEntries.value.filter(
    ([key, value]) => !isStructuredValue(value, tableFieldStructure(key)),
  )
})
const isMaskedSecret = computed(() => props.modelValue === '***REDACTED***')
const parsedNewMapKey = computed(() => {
  const key = newMapKey.value.trim()
  if (!key) return null
  if (newMapEntryKeyKind.value === 'string') return key
  const numeric = Number(key)
  return Number.isFinite(numeric) ? numeric : null
})
const canAddMapEntry = computed(() => {
  const key = parsedNewMapKey.value
  if (key === null) return false
  return !mapEntries.value.some(
    (entry) => entry.keyType === newMapEntryKeyKind.value && entry.key === key,
  )
})

function blankValue(kind: ValueKind): unknown {
  if (kind === 'boolean') return false
  if (kind === 'number') return 0
  if (kind === 'list') return []
  if (kind === 'table') return {}
  return ''
}

function blankLike(value: unknown): unknown {
  if (Array.isArray(value)) return []
  if (value !== null && typeof value === 'object') {
    const blank: Record<string, unknown> = {}
    for (const [key, child] of Object.entries(value)) {
      blank[key] = key === '__skyType' ? child : blankLike(child)
    }
    return blank
  }
  if (typeof value === 'boolean') return false
  if (typeof value === 'number') return 0
  return ''
}

function blankCollectionValue(kind: ValueKind, siblings: unknown[]): unknown {
  const template = siblings.find((value) => {
    if (kind === 'list') return Array.isArray(value)
    if (kind === 'table') {
      return (
        value !== null && typeof value === 'object' && !Array.isArray(value)
      )
    }
    return typeof value === kind
  })
  return template === undefined ? blankValue(kind) : blankLike(template)
}

function isStructuredValue(
  value: unknown,
  structure?: AdminConfiguratorStructure,
): boolean {
  if (
    structure?.kind === 'list' ||
    structure?.kind === 'map' ||
    structure?.kind === 'table' ||
    structure?.kind === 'vector'
  )
    return true
  return value !== null && typeof value === 'object'
}

function structuredValueLabel(
  value: unknown,
  structure?: AdminConfiguratorStructure,
): string {
  if (structure?.kind === 'vector') {
    return `${props.labels.vector} ${structure.vectorType.slice(-1)}`
  }
  if (structure?.kind === 'list' || Array.isArray(value)) {
    return props.labels.list
  }
  return props.labels.table
}

function structureTypeLabel(structure: AdminConfiguratorStructure): string {
  if (structure.kind === 'optionalString') return props.labels.types.string
  if (structure.kind === 'value') return props.labels.types[structure.valueType]
  if (structure.kind === 'list') return props.labels.types.list
  if (structure.kind === 'vector') {
    return `${props.labels.vector} ${structure.vectorType.slice(-1)}`
  }
  return props.labels.types.table
}

function configuratorStructureSize(
  structure: AdminConfiguratorStructure | undefined,
): number {
  if (
    !structure ||
    structure.kind === 'optionalString' ||
    structure.kind === 'value'
  ) {
    return 1
  }
  if (structure.kind === 'vector') {
    return Number(structure.vectorType.slice(-1))
  }
  if (structure.kind === 'list') {
    return Math.max(
      1,
      structure.items.reduce(
        (total, item) => total + configuratorStructureSize(item),
        0,
      ),
    )
  }
  if (structure.kind === 'map') {
    return Math.max(
      1,
      structure.entries.reduce(
        (total, entry) => total + configuratorStructureSize(entry.structure),
        0,
      ),
    )
  }
  return Math.max(
    1,
    Object.values(structure.fields).reduce(
      (total, field) => total + configuratorStructureSize(field),
      0,
    ),
  )
}

function toggleStructuredEntry(entry: string): void {
  expandedEntry.value = expandedEntry.value === entry ? null : entry
}

function tableEntryPath(key: string): string {
  return props.path ? `${props.path}.${key}` : key
}

function listEntryPath(index: number): string {
  return `${props.path || props.ariaLabel}[${index + 1}]`
}

function listItemStructure(
  index: number,
): AdminConfiguratorStructure | undefined {
  return listStructure.value?.items[index] ?? listTemplate.value
}

function mapValuePath(entry: SerializedMapEntry): string {
  return props.path ? `${props.path}.${entry.key}` : String(entry.key)
}

function updateScalar(event: Event): void {
  const target = event.target
  if (!(target instanceof HTMLInputElement)) return
  if (typeof props.modelValue === 'number') {
    const value = Number(target.value)
    if (Number.isFinite(value)) emit('update:modelValue', value)
    return
  }
  emit('update:modelValue', target.value)
}

function updateBoolean(event: Event): void {
  const target = event.target
  if (target instanceof HTMLInputElement) {
    emit('update:modelValue', target.checked)
  }
}

function updateOptionalString(event: Event): void {
  const target = event.target
  if (target instanceof HTMLInputElement) {
    emit('update:modelValue', target.value)
  }
}

function toggleOptionalString(event: Event): void {
  const target = event.target
  if (!(target instanceof HTMLInputElement)) return
  emit('update:modelValue', target.checked ? '' : false)
}

function addListRow(): void {
  const rows = Array.isArray(props.modelValue) ? [...props.modelValue] : []
  const index = rows.length
  const value = listTemplate.value
    ? blankFromConfiguratorStructure(listTemplate.value)
    : rows.length
      ? blankLike(rows[0])
      : blankValue(newArrayKind.value)
  rows.push(value)
  emit('update:modelValue', rows)
  if (isStructuredValue(value, listTemplate.value)) {
    expandedEntry.value = `list:${index}`
  }
}

function updateListRow(index: number, value: unknown): void {
  const rows = Array.isArray(props.modelValue) ? [...props.modelValue] : []
  rows[index] = value
  emit('update:modelValue', rows)
}

function removeListRow(index: number): void {
  if (listStructure.value?.items[index]) return
  const rows = Array.isArray(props.modelValue) ? [...props.modelValue] : []
  rows.splice(index, 1)
  emit('update:modelValue', rows)
  expandedEntry.value = null
}

function updateTableField(key: string, value: unknown): void {
  emit('update:modelValue', { ...tableValue.value, [key]: value })
}

function tableFieldStructure(
  key: string,
): AdminConfiguratorStructure | undefined {
  if (!tableStructure.value) return undefined
  return (
    tableStructure.value.fields[key] ??
    (tableStructure.value.mutableKeys
      ? tableStructure.value.template
      : undefined)
  )
}

function isFixedTableField(key: string): boolean {
  return (
    tableStructure.value?.mutableKeys !== true &&
    Object.prototype.hasOwnProperty.call(
      tableStructure.value?.fields ?? {},
      key,
    )
  )
}

function removeTableField(key: string): void {
  if (isFixedTableField(key)) return
  const next = { ...tableValue.value }
  delete next[key]
  emit('update:modelValue', next)
  if (expandedEntry.value === `table:${key}`) expandedEntry.value = null
}

function addTableField(): void {
  const key = newObjectKey.value.trim()
  if (!canAddTableField.value) return
  const template = tableStructure.value?.mutableKeys
    ? tableStructure.value.template
    : undefined
  const structuredValue = tableStructure.value?.mutableKeys
    ? createMutableTableEntry(
        tableStructure.value,
        props.path,
        key,
        tableValue.value,
      )
    : undefined
  const value =
    structuredValue !== undefined
      ? structuredValue
      : blankCollectionValue(
          newObjectKind.value,
          Object.values(tableValue.value).filter((_, index) => index < 50),
        )
  emit('update:modelValue', {
    ...tableValue.value,
    [key]: value,
  })
  if (isStructuredValue(value, template)) {
    expandedEntry.value = `table:${key}`
    if (props.depth === 0) selectedTableTab.value = `field:${key}`
  }
  newObjectKey.value = ''
}

function emitMap(entries: SerializedMapEntry[]): void {
  emit('update:modelValue', { __skyType: 'map', entries })
}

function convertTableToMap(): void {
  emitMap(
    Object.entries(tableValue.value)
      .filter(([key]) => key !== '__skyType')
      .map(([key, value]) => ({ key, keyType: 'string', value })),
  )
}

function updateMapKey(index: number, event: Event): void {
  const target = event.target
  if (!(target instanceof HTMLInputElement)) return
  const current = mapEntries.value[index]
  if (!current) return
  if (fixedMapEntryStructure(current)) {
    target.value = String(current.key)
    return
  }
  const key =
    current.keyType === 'number' ? Number(target.value) : target.value.trim()
  if (
    key === '' ||
    (typeof key === 'number' && !Number.isFinite(key)) ||
    mapEntries.value.some(
      (entry, candidateIndex) =>
        candidateIndex !== index &&
        entry.keyType === current.keyType &&
        entry.key === key,
    )
  ) {
    target.value = String(current.key)
    return
  }
  const entries = mapEntries.value.map((entry, candidateIndex) =>
    candidateIndex === index ? { ...entry, key } : entry,
  )
  emitMap(entries)
}

function updateMapValue(index: number, value: unknown): void {
  emitMap(
    mapEntries.value.map((entry, candidateIndex) =>
      candidateIndex === index ? { ...entry, value } : entry,
    ),
  )
}

function removeMapEntry(index: number): void {
  const entry = mapEntries.value[index]
  if (!entry || fixedMapEntryStructure(entry)) return
  emitMap(
    mapEntries.value.filter((_, candidateIndex) => candidateIndex !== index),
  )
  expandedEntry.value = null
}

function addMapEntry(): void {
  if (!canAddMapEntry.value || parsedNewMapKey.value === null) return
  const key = parsedNewMapKey.value
  const value = mapTemplate.value
    ? blankFromConfiguratorStructure(mapTemplate.value)
    : blankCollectionValue(
        newMapValueKind.value,
        mapEntries.value.slice(0, 50).map((entry) => entry.value),
      )
  emitMap([
    ...mapEntries.value,
    {
      key,
      keyType: newMapEntryKeyKind.value,
      value,
    },
  ])
  if (isStructuredValue(value, mapTemplate.value)) {
    expandedEntry.value = `map:${newMapEntryKeyKind.value}:${key}`
  }
  newMapKey.value = ''
}

function fixedMapEntryStructure(
  entry: SerializedMapEntry,
): AdminConfiguratorStructure | undefined {
  return mapStructure.value?.entries.find(
    (candidate) =>
      candidate.keyType === entry.keyType && candidate.key === entry.key,
  )?.structure
}

function mapEntryStructure(
  entry: SerializedMapEntry,
): AdminConfiguratorStructure | undefined {
  return fixedMapEntryStructure(entry) ?? mapTemplate.value
}
</script>

<template>
  <div
    v-if="isList"
    class="config-structured-editor"
    :class="{
      'has-structure': Boolean(structure),
      'is-nested': depth > 0,
    }"
  >
    <header class="config-structured-editor__bar">
      <span><Rows3 :size="14" />{{ labels.list }}</span>
      <div class="config-structured-editor__actions">
        <button
          v-if="!listValue.length && !structure"
          type="button"
          :disabled="disabled"
          :title="labels.convertToTable"
          @click="emit('update:modelValue', {})"
        >
          <TableProperties :size="13" />
        </button>
      </div>
    </header>

    <div v-if="listValue.length" class="config-structured-editor__rows">
      <div
        v-for="(row, index) in listValue"
        :key="index"
        class="config-structured-editor__row"
        :class="{
          'has-structured-value': isStructuredValue(
            row,
            listItemStructure(index),
          ),
          'is-expanded': expandedEntry === `list:${index}`,
        }"
      >
        <span class="config-structured-editor__index">{{ index + 1 }}</span>
        <button
          v-if="isStructuredValue(row, listItemStructure(index))"
          type="button"
          class="config-structured-editor__section-toggle"
          :aria-label="`${ariaLabel} ${index + 1}`"
          :aria-expanded="expandedEntry === `list:${index}`"
          @click="toggleStructuredEntry(`list:${index}`)"
        >
          <span class="config-structured-editor__field-copy">
            <strong>{{ labels.entry }} {{ index + 1 }}</strong>
            <small
              :title="
                describe(listEntryPath(index), row, listItemStructure(index))
              "
            >
              {{
                describe(listEntryPath(index), row, listItemStructure(index))
              }}
            </small>
          </span>
          <em>{{ structuredValueLabel(row, listItemStructure(index)) }}</em>
          <ChevronDown :size="14" />
        </button>
        <span v-else class="config-structured-editor__field-copy is-list-entry">
          <strong>{{ labels.entry }} {{ index + 1 }}</strong>
          <small
            :title="
              describe(listEntryPath(index), row, listItemStructure(index))
            "
          >
            {{ describe(listEntryPath(index), row, listItemStructure(index)) }}
          </small>
        </span>
        <AdminConfigValueEditor
          v-if="
            !isStructuredValue(row, listItemStructure(index)) ||
            expandedEntry === `list:${index}`
          "
          :model-value="row"
          :structure="listItemStructure(index)"
          :aria-label="`${ariaLabel} ${index + 1}`"
          :describe="describe"
          :labels="labels"
          :tab-label="tabLabel"
          :disabled="disabled"
          :depth="depth + 1"
          :path="listEntryPath(index)"
          @update:model-value="updateListRow(index, $event)"
        />
        <button
          v-if="!listStructure?.items[index]"
          type="button"
          class="config-structured-editor__remove"
          :disabled="disabled"
          :title="labels.remove"
          @click="removeListRow(index)"
        >
          <Trash2 :size="13" />
        </button>
      </div>
    </div>
    <div v-else class="config-structured-editor__empty">
      {{ labels.emptyList }}
    </div>

    <form
      class="config-structured-editor__add-field is-list"
      @submit.prevent="addListRow"
    >
      <select
        v-if="!listValue.length && !listTemplate"
        v-model="newArrayKind"
        :disabled="disabled"
      >
        <option value="string">{{ labels.types.string }}</option>
        <option value="number">{{ labels.types.number }}</option>
        <option value="boolean">{{ labels.types.boolean }}</option>
        <option value="table">{{ labels.types.table }}</option>
      </select>
      <span
        v-else-if="listTemplate"
        class="config-structured-editor__fixed-type"
      >
        {{ structureTypeLabel(listTemplate) }}
      </span>
      <button type="submit" :disabled="disabled">
        <Plus :size="13" />{{ labels.addRow }}
      </button>
    </form>
  </div>

  <div
    v-else-if="isTable"
    class="config-structured-editor"
    :class="{
      'has-structure': Boolean(structure),
      'is-fixed-table': usesFixedTableLayout,
      'is-nested': depth > 0,
    }"
  >
    <header v-if="!usesFixedTableLayout" class="config-structured-editor__bar">
      <span>
        <TableProperties :size="14" />
        {{
          vectorType ? `${labels.vector} ${vectorType.slice(-1)}` : labels.table
        }}
      </span>
      <div
        v-if="!structure && !mapType && !vectorType"
        class="config-structured-editor__actions"
      >
        <button
          type="button"
          :disabled="disabled"
          :title="labels.convertToMap"
          @click="convertTableToMap"
        >
          <TableProperties :size="13" />{{ labels.convertToMap }}
        </button>
        <button
          v-if="!tableEntries.length"
          type="button"
          :disabled="disabled"
          :title="labels.convertToList"
          @click="emit('update:modelValue', [])"
        >
          <Rows3 :size="13" />{{ labels.convertToList }}
        </button>
      </div>
    </header>

    <nav
      v-if="rootTableTabs.length"
      class="config-structured-editor__tabs"
      role="tablist"
      :aria-label="ariaLabel"
    >
      <button
        v-for="tableTab in rootTableTabs"
        :key="tableTab.id"
        type="button"
        role="tab"
        :class="{ 'is-active': activeRootTableTab?.id === tableTab.id }"
        :aria-selected="activeRootTableTab?.id === tableTab.id"
        @click="selectedTableTab = tableTab.id"
      >
        <span>{{ tableTab.label }}</span>
        <em>{{ tableTab.count }}</em>
      </button>
    </nav>

    <div
      v-if="activeRootTableField"
      class="config-structured-editor__tab-panel"
      role="tabpanel"
    >
      <div
        v-if="!isFixedTableField(activeRootTableField.key)"
        class="config-structured-editor__tab-panel-actions"
      >
        <strong>{{ activeRootTableField.key }}</strong>
        <button
          type="button"
          :disabled="disabled"
          :title="labels.remove"
          @click="removeTableField(activeRootTableField.key)"
        >
          <Trash2 :size="13" />{{ labels.remove }}
        </button>
      </div>
      <AdminConfigValueEditor
        :model-value="activeRootTableField.value"
        :structure="tableFieldStructure(activeRootTableField.key)"
        :aria-label="`${ariaLabel} ${activeRootTableField.key}`"
        :describe="describe"
        :labels="labels"
        :tab-label="tabLabel"
        :disabled="disabled"
        :depth="depth + 1"
        :path="tableEntryPath(activeRootTableField.key)"
        @update:model-value="updateTableField(activeRootTableField.key, $event)"
      />
    </div>

    <div
      v-else-if="mapType"
      class="config-structured-editor__properties is-map"
    >
      <div
        v-for="(entry, index) in mapEntries"
        :key="`${entry.keyType}:${entry.key}`"
        class="config-structured-editor__property is-map"
        :class="{
          'has-structured-value': isStructuredValue(
            entry.value,
            mapEntryStructure(entry),
          ),
          'is-expanded': expandedEntry === `map:${entry.keyType}:${entry.key}`,
        }"
      >
        <span class="config-structured-editor__index">{{ index + 1 }}</span>
        <span class="config-structured-editor__map-key">
          <small>{{ labels.types[entry.keyType] }}</small>
          <input
            :type="entry.keyType === 'number' ? 'number' : 'text'"
            :value="entry.key"
            :aria-label="`${ariaLabel} ${labels.types[entry.keyType]} ${index + 1}`"
            :disabled="disabled || Boolean(fixedMapEntryStructure(entry))"
            @change="updateMapKey(index, $event)"
          />
          <em
            :title="
              describe(
                mapValuePath(entry),
                entry.value,
                mapEntryStructure(entry),
              )
            "
          >
            {{
              describe(
                mapValuePath(entry),
                entry.value,
                mapEntryStructure(entry),
              )
            }}
          </em>
        </span>
        <button
          v-if="isStructuredValue(entry.value, mapEntryStructure(entry))"
          type="button"
          class="config-structured-editor__section-toggle is-map"
          :aria-label="`${ariaLabel} ${entry.key}`"
          :aria-expanded="expandedEntry === `map:${entry.keyType}:${entry.key}`"
          @click="toggleStructuredEntry(`map:${entry.keyType}:${entry.key}`)"
        >
          <small>{{
            structuredValueLabel(entry.value, mapEntryStructure(entry))
          }}</small>
          <ChevronDown :size="14" />
        </button>
        <AdminConfigValueEditor
          v-if="
            !isStructuredValue(entry.value, mapEntryStructure(entry)) ||
            expandedEntry === `map:${entry.keyType}:${entry.key}`
          "
          :model-value="entry.value"
          :structure="mapEntryStructure(entry)"
          :aria-label="`${ariaLabel} ${entry.key}`"
          :describe="describe"
          :labels="labels"
          :tab-label="tabLabel"
          :disabled="disabled"
          :depth="depth + 1"
          :path="mapValuePath(entry)"
          @update:model-value="updateMapValue(index, $event)"
        />
        <button
          v-if="!fixedMapEntryStructure(entry)"
          type="button"
          class="config-structured-editor__remove"
          :disabled="disabled"
          :title="labels.remove"
          @click="removeMapEntry(index)"
        >
          <Trash2 :size="13" />
        </button>
      </div>
      <div v-if="!mapEntries.length" class="config-structured-editor__empty">
        {{ labels.emptyTable }}
      </div>
    </div>

    <div
      v-else-if="visibleTableEntries.length"
      class="config-structured-editor__properties"
      :role="rootTableTabs.length ? 'tabpanel' : undefined"
    >
      <div
        v-for="([key, value], index) in visibleTableEntries"
        :key="key"
        class="config-structured-editor__property"
        :class="{
          'has-structured-value': isStructuredValue(
            value,
            tableFieldStructure(key),
          ),
          'is-expanded': expandedEntry === `table:${key}`,
        }"
      >
        <span class="config-structured-editor__index">{{ index + 1 }}</span>
        <button
          v-if="isStructuredValue(value, tableFieldStructure(key))"
          type="button"
          class="config-structured-editor__section-toggle"
          :aria-label="`${ariaLabel} ${key}`"
          :aria-expanded="expandedEntry === `table:${key}`"
          @click="toggleStructuredEntry(`table:${key}`)"
        >
          <span class="config-structured-editor__field-copy">
            <strong>{{ key }}</strong>
            <small
              :title="
                describe(tableEntryPath(key), value, tableFieldStructure(key))
              "
            >
              {{
                describe(tableEntryPath(key), value, tableFieldStructure(key))
              }}
            </small>
          </span>
          <em>{{ structuredValueLabel(value, tableFieldStructure(key)) }}</em>
          <ChevronDown :size="14" />
        </button>
        <span v-else class="config-structured-editor__field-copy">
          <strong>{{ key }}</strong>
          <small
            :title="
              describe(tableEntryPath(key), value, tableFieldStructure(key))
            "
          >
            {{ describe(tableEntryPath(key), value, tableFieldStructure(key)) }}
          </small>
        </span>
        <AdminConfigValueEditor
          v-if="
            !isStructuredValue(value, tableFieldStructure(key)) ||
            expandedEntry === `table:${key}`
          "
          :model-value="value"
          :structure="tableFieldStructure(key)"
          :aria-label="`${ariaLabel} ${key}`"
          :describe="describe"
          :labels="labels"
          :tab-label="tabLabel"
          :disabled="disabled"
          :depth="depth + 1"
          :path="tableEntryPath(key)"
          @update:model-value="updateTableField(key, $event)"
        />
        <button
          v-if="!vectorType && !isFixedTableField(key)"
          type="button"
          class="config-structured-editor__remove"
          :disabled="disabled"
          :title="labels.remove"
          @click="removeTableField(key)"
        >
          <Trash2 :size="13" />
        </button>
      </div>
    </div>
    <div
      v-else-if="!rootTableTabs.length"
      class="config-structured-editor__empty"
    >
      {{ labels.emptyTable }}
    </div>

    <form
      v-if="mapType"
      class="config-structured-editor__add-field is-map"
      @submit.prevent="addMapEntry"
    >
      <select
        v-if="!mapStructure?.keyType"
        v-model="newMapKeyKind"
        :disabled="disabled"
      >
        <option value="string">{{ labels.types.string }}</option>
        <option value="number">{{ labels.types.number }}</option>
      </select>
      <span v-else class="config-structured-editor__fixed-type is-key-type">
        {{ labels.types[mapStructure.keyType] }}
      </span>
      <input
        v-model="newMapKey"
        :type="newMapEntryKeyKind === 'number' ? 'number' : 'text'"
        :disabled="disabled"
        :placeholder="labels.keyPlaceholder"
        :aria-label="labels.keyPlaceholder"
      />
      <select
        v-if="!mapTemplate"
        v-model="newMapValueKind"
        :disabled="disabled"
      >
        <option value="string">{{ labels.types.string }}</option>
        <option value="number">{{ labels.types.number }}</option>
        <option value="boolean">{{ labels.types.boolean }}</option>
        <option value="list">{{ labels.types.list }}</option>
        <option value="table">{{ labels.types.table }}</option>
      </select>
      <span v-else class="config-structured-editor__fixed-type">
        {{ structureTypeLabel(mapTemplate) }}
      </span>
      <button type="submit" :disabled="disabled || !canAddMapEntry">
        <Plus :size="13" />{{ labels.addField }}
      </button>
    </form>

    <form
      v-else-if="canExtendTable"
      class="config-structured-editor__add-field"
      @submit.prevent="addTableField"
    >
      <input
        v-model="newObjectKey"
        type="text"
        :disabled="disabled"
        :placeholder="labels.keyPlaceholder"
        :aria-label="labels.keyPlaceholder"
      />
      <select
        v-if="!tableStructure"
        v-model="newObjectKind"
        :disabled="disabled"
      >
        <option value="string">{{ labels.types.string }}</option>
        <option value="number">{{ labels.types.number }}</option>
        <option value="boolean">{{ labels.types.boolean }}</option>
        <option value="list">{{ labels.types.list }}</option>
        <option value="table">{{ labels.types.table }}</option>
      </select>
      <span
        v-else-if="tableStructure.template"
        class="config-structured-editor__fixed-type"
      >
        {{ structureTypeLabel(tableStructure.template) }}
      </span>
      <button type="submit" :disabled="disabled || !canAddTableField">
        <Plus :size="13" />{{ labels.addField }}
      </button>
    </form>
  </div>

  <span
    v-else-if="structure?.kind === 'optionalString'"
    class="config-value-optional"
  >
    <input
      v-config-input-width
      class="config-value-input"
      type="text"
      :aria-label="ariaLabel"
      :value="modelValue === false ? '' : String(modelValue ?? '')"
      :disabled="disabled || modelValue === false"
      autocomplete="off"
      @input="updateOptionalString"
    />
    <label class="config-value-toggle">
      <input
        type="checkbox"
        :aria-label="ariaLabel"
        :checked="modelValue !== false"
        :disabled="disabled"
        @change="toggleOptionalString"
      />
      <i></i>
    </label>
  </span>

  <label
    v-else-if="typeof modelValue === 'boolean'"
    class="config-value-toggle"
  >
    <input
      type="checkbox"
      :aria-label="ariaLabel"
      :checked="modelValue"
      :disabled="disabled"
      @change="updateBoolean"
    />
    <i></i>
  </label>

  <input
    v-else
    v-config-input-width
    class="config-value-input"
    :aria-label="ariaLabel"
    :type="
      isMaskedSecret
        ? 'password'
        : typeof modelValue === 'number'
          ? 'number'
          : 'text'
    "
    :value="isMaskedSecret ? '' : String(modelValue ?? '')"
    :placeholder="isMaskedSecret ? labels.configuredSecret : ''"
    :disabled="disabled"
    :autocomplete="isMaskedSecret ? 'new-password' : 'off'"
    @input="updateScalar"
  />
</template>

<style scoped>
.config-structured-editor {
  min-width: 0;
  overflow: hidden;
  border-radius: 4px;
  background: #121413;
  outline: 1px solid rgba(255, 255, 255, 0.065);
}

.config-structured-editor.is-nested {
  background: #0f1110;
}

.config-structured-editor.is-fixed-table {
  overflow: visible;
  border-radius: 0;
  outline: 0;
  background: transparent;
}

.config-structured-editor.is-fixed-table
  > .config-structured-editor__properties {
  background: transparent;
}

.config-structured-editor.is-nested.has-structure
  > .config-structured-editor__bar {
  display: none;
}

.config-structured-editor__bar {
  min-height: 32px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 5px 7px;
  background: rgba(255, 255, 255, 0.025);
}

.config-structured-editor__bar > span,
.config-structured-editor__bar > div {
  display: flex;
  align-items: center;
  gap: 6px;
}

.config-structured-editor__actions:empty {
  display: none;
}

.config-structured-editor__bar > span {
  color: var(--admin-muted);
  font-size: 8px;
  font-weight: 650;
  letter-spacing: 0.05em;
  text-transform: uppercase;
}

.config-structured-editor__tabs {
  display: flex;
  gap: 3px;
  overflow-x: auto;
  padding: 6px 7px 0;
  background: #0c0e0d;
  scrollbar-width: thin;
}

.config-structured-editor .config-structured-editor__tabs > button {
  min-width: max-content;
  min-height: 29px;
  display: inline-flex;
  align-items: center;
  gap: 7px;
  padding: 0 10px;
  border-radius: 3px 3px 0 0;
  outline: 0;
  color: var(--admin-muted);
  background: transparent;
  font-size: 8px;
}

.config-structured-editor .config-structured-editor__tabs > button:hover,
.config-structured-editor .config-structured-editor__tabs > button.is-active {
  color: var(--admin-text);
  background: #171918;
}

.config-structured-editor .config-structured-editor__tabs > button.is-active {
  box-shadow: inset 0 -1px var(--admin-green);
}

.config-structured-editor__tabs em {
  color: var(--admin-dim);
  font-size: 7px;
  font-style: normal;
}

.config-structured-editor__tab-panel {
  min-width: 0;
  background: #0f1110;
}

.config-structured-editor__tab-panel > .config-structured-editor {
  border-radius: 0;
  outline: 0;
}

.config-structured-editor__tab-panel-actions {
  min-height: 34px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 5px 7px;
  background: #141615;
}

.config-structured-editor__tab-panel-actions strong {
  color: var(--admin-text);
  font-size: 9px;
}

.config-structured-editor .config-structured-editor__tab-panel-actions button {
  color: #b66a6a;
}

.config-structured-editor button,
.config-structured-editor select,
.config-structured-editor input,
.config-value-input {
  border: 0;
  border-radius: 3px;
  outline: 1px solid rgba(255, 255, 255, 0.075);
  color: var(--admin-text);
  background: #1a1c1b;
  font: inherit;
  font-size: 9px;
}

.config-structured-editor button {
  min-height: 23px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 4px;
  padding: 0 7px;
  color: var(--admin-green);
  cursor: pointer;
}

.config-structured-editor button:hover:not(:disabled) {
  background: #222423;
}

.config-structured-editor button:disabled,
.config-structured-editor input:disabled,
.config-structured-editor select:disabled,
.config-value-input:disabled {
  opacity: 0.45;
  cursor: default;
}

.config-structured-editor select {
  height: 23px;
  padding: 0 5px;
}

.config-structured-editor__rows,
.config-structured-editor__properties {
  display: grid;
  gap: 1px;
  background: #0d0f0d;
}

.config-structured-editor__row,
.config-structured-editor__property {
  display: grid;
  grid-template-columns: 24px minmax(180px, 0.82fr) minmax(140px, 1.18fr) 27px;
  align-items: center;
  gap: 6px;
  padding: 5px 6px;
  background: #151716;
}

.config-structured-editor__property {
  grid-template-columns: 24px minmax(200px, 0.9fr) minmax(150px, 1.1fr) 27px;
}

.config-structured-editor__property.is-map {
  grid-template-columns: 24px minmax(180px, 0.82fr) minmax(150px, 1.18fr) 27px;
}

.config-structured-editor__row.has-structured-value,
.config-structured-editor__property.has-structured-value {
  align-items: start;
  background: linear-gradient(
    90deg,
    rgba(255, 255, 255, 0.022),
    rgba(255, 255, 255, 0.008)
  );
}

.config-structured-editor__row.has-structured-value.is-expanded,
.config-structured-editor__property.has-structured-value.is-expanded {
  background: linear-gradient(
    90deg,
    color-mix(in srgb, var(--admin-green) 7%, #1a1d1a),
    #181b18 58%
  );
}

.config-structured-editor__row.has-structured-value > .config-structured-editor,
.config-structured-editor__property.has-structured-value
  > .config-structured-editor {
  grid-column: 1 / -1;
  grid-row: 2;
  width: calc(100% + 12px);
  margin-inline: -6px;
}

.config-structured-editor__row.has-structured-value
  > .config-structured-editor__index,
.config-structured-editor__property.has-structured-value
  > .config-structured-editor__index {
  grid-column: 1;
  grid-row: 1;
  align-self: center;
}

.config-structured-editor__property.has-structured-value > strong,
.config-structured-editor__property.has-structured-value
  > .config-structured-editor__section-toggle {
  grid-column: 2 / 4;
  grid-row: 1;
  align-self: center;
}

.config-structured-editor__row.has-structured-value
  > .config-structured-editor__section-toggle {
  grid-column: 2 / 4;
  grid-row: 1;
}

.config-structured-editor__property.is-map.has-structured-value
  > .config-structured-editor__map-key {
  grid-column: 2;
  grid-row: 1;
  align-self: center;
}

.config-structured-editor__property.is-map.has-structured-value
  > .config-structured-editor__section-toggle {
  grid-column: 3;
}

.config-structured-editor__row.has-structured-value
  > .config-structured-editor__remove {
  grid-column: 4;
  grid-row: 1;
}

.config-structured-editor__property.has-structured-value
  > .config-structured-editor__remove {
  grid-column: 4;
  grid-row: 1;
}

.config-structured-editor .config-structured-editor__section-toggle {
  width: 100%;
  min-width: 0;
  min-height: 27px;
  justify-content: flex-start;
  padding: 0 7px;
  outline: 0;
  color: #c9cec9;
  background: transparent;
}

.config-structured-editor
  .config-structured-editor__section-toggle:hover:not(:disabled) {
  background: rgba(255, 255, 255, 0.025);
}

.config-structured-editor__field-copy {
  min-width: 0;
  display: grid;
  gap: 2px;
  text-align: left;
}

.config-structured-editor__field-copy strong {
  overflow: hidden;
  min-width: 0;
  color: #c9cec9;
  font-size: 9px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.config-structured-editor__field-copy small {
  overflow: hidden;
  color: var(--admin-muted);
  font-size: 7.5px;
  font-weight: 450;
  line-height: 1.25;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.config-structured-editor__section-toggle
  > .config-structured-editor__field-copy {
  flex: 1 1 auto;
}

.config-structured-editor__section-toggle > em {
  margin-left: auto;
  color: var(--admin-muted);
  font-size: 7px;
  font-weight: 600;
  font-style: normal;
  letter-spacing: 0.05em;
  text-transform: uppercase;
}

.config-structured-editor__section-toggle svg {
  flex: 0 0 auto;
  color: var(--admin-muted);
  transition: transform 150ms ease;
}

.config-structured-editor__row.is-expanded
  > .config-structured-editor__section-toggle
  svg,
.config-structured-editor__property.is-expanded
  > .config-structured-editor__section-toggle
  svg {
  transform: rotate(180deg);
}

.config-structured-editor__section-toggle:focus-visible {
  outline: 1px solid color-mix(in srgb, var(--admin-green) 55%, transparent);
}

@media (prefers-reduced-motion: reduce) {
  .config-structured-editor__section-toggle svg {
    transition: none;
  }
}

.config-structured-editor__map-key {
  min-width: 0;
  display: grid;
  gap: 3px;
}

.config-structured-editor__map-key > small {
  color: var(--admin-dim);
  font-size: 7px;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.config-structured-editor__map-key > em {
  overflow: hidden;
  color: var(--admin-muted);
  font-size: 7px;
  font-style: normal;
  line-height: 1.2;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.config-structured-editor__map-key input {
  width: 100%;
  min-width: 0;
  height: 25px;
  padding: 0 7px;
}

.config-structured-editor__index {
  color: var(--admin-dim);
  font-family: ui-monospace, SFMono-Regular, Consolas, monospace;
  font-size: 8px;
  text-align: center;
}

.config-structured-editor .config-structured-editor__remove {
  width: 25px;
  padding: 0;
  color: #b66a6a;
}

.config-value-optional {
  min-width: 0;
  max-width: 100%;
  display: flex;
  align-items: center;
  justify-self: start;
  gap: 7px;
}

.config-structured-editor__empty {
  padding: 13px 10px;
  color: var(--admin-dim);
  font-size: 9px;
  text-align: center;
}

.config-structured-editor__add-field {
  min-height: 37px;
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 6px;
  padding: 6px;
  background: linear-gradient(
    90deg,
    rgba(255, 255, 255, 0.012),
    rgba(255, 255, 255, 0.035)
  );
}

.config-structured-editor__add-field input {
  min-width: 0;
  flex: 1 1 120px;
  height: 25px;
  padding: 0 7px;
}

.config-structured-editor__add-field select {
  width: 90px;
  flex: 0 0 90px;
}

.config-structured-editor__fixed-type {
  width: 90px;
  height: 23px;
  flex: 0 0 90px;
  display: inline-flex;
  align-items: center;
  padding: 0 7px;
  border-radius: 3px;
  outline: 1px solid rgba(255, 255, 255, 0.055);
  color: var(--admin-muted);
  background: rgba(255, 255, 255, 0.025);
  font-size: 8px;
}

.config-structured-editor__fixed-type.is-key-type {
  width: 76px;
  flex-basis: 76px;
}

.config-structured-editor__add-field button {
  min-width: 74px;
  flex: 0 0 auto;
}

.config-structured-editor__add-field.is-map select:first-child {
  width: 76px;
  flex-basis: 76px;
}

.config-structured-editor__add-field.is-map select:nth-of-type(2) {
  width: 82px;
  flex-basis: 82px;
}

.config-structured-editor__add-field.is-list select,
.config-structured-editor__add-field.is-list
  .config-structured-editor__fixed-type {
  margin-left: auto;
}

.config-value-input {
  max-width: 100%;
  min-width: 0;
  height: 29px;
  justify-self: start;
  padding: 0 8px;
}

.config-value-input[type='number'] {
  appearance: textfield;
}

.config-structured-editor input[type='number']::-webkit-inner-spin-button,
.config-structured-editor input[type='number']::-webkit-outer-spin-button {
  margin: 0;
  appearance: none;
}

.config-value-input:focus,
.config-structured-editor input:focus,
.config-structured-editor select:focus {
  outline-color: color-mix(in srgb, var(--admin-green) 45%, transparent);
}

.config-value-toggle {
  position: relative;
  justify-self: start;
  width: 32px;
  height: 18px;
}

.config-value-toggle input {
  position: absolute;
  inset: 0;
  z-index: 1;
  margin: 0;
  opacity: 0;
  cursor: pointer;
}

.config-value-toggle i {
  position: absolute;
  inset: 0;
  border-radius: 999px;
  background: #393d39;
}

.config-value-toggle i::after {
  content: '';
  position: absolute;
  top: 3px;
  left: 3px;
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: #c7ccc7;
  transition: transform 150ms ease;
}

.config-value-toggle input:checked + i {
  background: var(--admin-toggle-on);
}

.config-value-toggle input:checked + i::after {
  transform: translateX(14px);
  background: #f4f7f4;
}
</style>
