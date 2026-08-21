<script setup lang="ts">
import { Plus, Rows3, TableProperties, Trash2 } from 'lucide-vue-next'
import { computed, ref } from 'vue'

import type { AdminConfiguratorStructure } from '@/types/admin'

export type AdminConfigEditorLabels = {
  addField: string
  addRow: string
  configuredSecret: string
  convertToList: string
  convertToMap: string
  convertToTable: string
  emptyList: string
  emptyTable: string
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
    disabled?: boolean
    labels: AdminConfigEditorLabels
    modelValue: unknown
    structure?: AdminConfiguratorStructure
  }>(),
  { ariaLabel: '', depth: 0, disabled: false },
)
const emit = defineEmits<{ 'update:modelValue': [value: unknown] }>()

type ValueKind = 'boolean' | 'list' | 'number' | 'string' | 'table'
type MapKeyKind = 'number' | 'string'
type SerializedMapEntry = {
  key: number | string
  keyType: MapKeyKind
  value: unknown
}

const newArrayKind = ref<ValueKind>('string')
const newObjectKey = ref('')
const newObjectKind = ref<ValueKind>('string')
const newMapKey = ref('')
const newMapKeyKind = ref<MapKeyKind>('string')
const newMapValueKind = ref<ValueKind>('string')

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
const tableStructure = computed(() =>
  props.structure?.kind === 'table' ? props.structure : null,
)
const mapStructure = computed(() =>
  props.structure?.kind === 'map' ? props.structure : null,
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
const tableEntries = computed(() =>
  Object.entries(tableValue.value).filter(
    ([key]) => key !== '__skyType' && (!mapType.value || key !== 'entries'),
  ),
)
const isMaskedSecret = computed(() => props.modelValue === '***REDACTED***')
const parsedNewMapKey = computed(() => {
  const key = newMapKey.value.trim()
  if (!key) return null
  if (newMapKeyKind.value === 'string') return key
  const numeric = Number(key)
  return Number.isFinite(numeric) ? numeric : null
})
const canAddMapEntry = computed(() => {
  const key = parsedNewMapKey.value
  if (key === null) return false
  return !mapEntries.value.some(
    (entry) => entry.keyType === newMapKeyKind.value && entry.key === key,
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

function blankFromStructure(structure: AdminConfiguratorStructure): unknown {
  if (structure.kind === 'optionalString') return ''
  if (structure.kind === 'value') return blankValue(structure.valueType)
  if (structure.kind === 'vector') {
    const axes = ['x', 'y', 'z', 'w'].slice(
      0,
      Number(structure.vectorType.slice(-1)),
    )
    return Object.fromEntries([
      ['__skyType', structure.vectorType],
      ...axes.map((axis) => [axis, 0]),
    ])
  }
  if (structure.kind === 'list') {
    return structure.items.map(blankFromStructure)
  }
  if (structure.kind === 'map') {
    return {
      __skyType: 'map',
      entries: structure.entries.map((entry) => ({
        key: entry.key,
        keyType: entry.keyType,
        value: blankFromStructure(entry.structure),
      })),
    }
  }
  return Object.fromEntries(
    Object.entries(structure.fields).map(([key, field]) => [
      key,
      blankFromStructure(field),
    ]),
  )
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
  rows.push(rows.length ? blankLike(rows[0]) : blankValue(newArrayKind.value))
  emit('update:modelValue', rows)
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
}

function addTableField(): void {
  const key = newObjectKey.value.trim()
  if (!canAddTableField.value) return
  const template = tableStructure.value?.mutableKeys
    ? tableStructure.value.template
    : undefined
  emit('update:modelValue', {
    ...tableValue.value,
    [key]: template
      ? blankFromStructure(template)
      : blankCollectionValue(
          newObjectKind.value,
          Object.values(tableValue.value).filter((_, index) => index < 50),
        ),
  })
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
  if (mapEntryStructure(current)) {
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
  if (!entry || mapEntryStructure(entry)) return
  emitMap(
    mapEntries.value.filter((_, candidateIndex) => candidateIndex !== index),
  )
}

function addMapEntry(): void {
  if (!canAddMapEntry.value || parsedNewMapKey.value === null) return
  emitMap([
    ...mapEntries.value,
    {
      key: parsedNewMapKey.value,
      keyType: newMapKeyKind.value,
      value: blankCollectionValue(
        newMapValueKind.value,
        mapEntries.value.slice(0, 50).map((entry) => entry.value),
      ),
    },
  ])
  newMapKey.value = ''
}

function mapEntryStructure(
  entry: SerializedMapEntry,
): AdminConfiguratorStructure | undefined {
  return mapStructure.value?.entries.find(
    (candidate) =>
      candidate.keyType === entry.keyType && candidate.key === entry.key,
  )?.structure
}
</script>

<template>
  <div
    v-if="isList"
    class="config-structured-editor"
    :class="{ 'is-nested': depth > 0 }"
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
            listStructure?.items[index],
          ),
        }"
      >
        <span class="config-structured-editor__index">{{ index + 1 }}</span>
        <AdminConfigValueEditor
          :model-value="row"
          :structure="listStructure?.items[index]"
          :aria-label="`${ariaLabel} ${index + 1}`"
          :labels="labels"
          :disabled="disabled"
          :depth="depth + 1"
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
        v-if="!listValue.length"
        v-model="newArrayKind"
        :disabled="disabled"
      >
        <option value="string">{{ labels.types.string }}</option>
        <option value="number">{{ labels.types.number }}</option>
        <option value="boolean">{{ labels.types.boolean }}</option>
        <option value="table">{{ labels.types.table }}</option>
      </select>
      <button type="submit" :disabled="disabled">
        <Plus :size="13" />{{ labels.addRow }}
      </button>
    </form>
  </div>

  <div
    v-else-if="isTable"
    class="config-structured-editor"
    :class="{ 'is-nested': depth > 0 }"
  >
    <header class="config-structured-editor__bar">
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

    <div v-if="mapType" class="config-structured-editor__properties is-map">
      <div
        v-for="(entry, index) in mapEntries"
        :key="`${entry.keyType}:${entry.key}`"
        class="config-structured-editor__property is-map"
        :class="{
          'has-structured-value': isStructuredValue(
            entry.value,
            mapEntryStructure(entry),
          ),
        }"
      >
        <span class="config-structured-editor__index">{{ index + 1 }}</span>
        <span class="config-structured-editor__map-key">
          <small>{{ labels.types[entry.keyType] }}</small>
          <input
            :type="entry.keyType === 'number' ? 'number' : 'text'"
            :value="entry.key"
            :aria-label="`${ariaLabel} ${labels.types[entry.keyType]} ${index + 1}`"
            :disabled="disabled || Boolean(mapEntryStructure(entry))"
            @change="updateMapKey(index, $event)"
          />
        </span>
        <AdminConfigValueEditor
          :model-value="entry.value"
          :structure="mapEntryStructure(entry)"
          :aria-label="`${ariaLabel} ${entry.key}`"
          :labels="labels"
          :disabled="disabled"
          :depth="depth + 1"
          @update:model-value="updateMapValue(index, $event)"
        />
        <button
          v-if="!mapEntryStructure(entry)"
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
      v-else-if="tableEntries.length"
      class="config-structured-editor__properties"
    >
      <div
        v-for="([key, value], index) in tableEntries"
        :key="key"
        class="config-structured-editor__property"
        :class="{
          'has-structured-value': isStructuredValue(
            value,
            tableFieldStructure(key),
          ),
        }"
      >
        <span class="config-structured-editor__index">{{ index + 1 }}</span>
        <strong>{{ key }}</strong>
        <AdminConfigValueEditor
          :model-value="value"
          :structure="tableFieldStructure(key)"
          :aria-label="`${ariaLabel} ${key}`"
          :labels="labels"
          :disabled="disabled"
          :depth="depth + 1"
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
    <div v-else class="config-structured-editor__empty">
      {{ labels.emptyTable }}
    </div>

    <form
      v-if="mapType"
      class="config-structured-editor__add-field is-map"
      @submit.prevent="addMapEntry"
    >
      <select v-model="newMapKeyKind" :disabled="disabled">
        <option value="string">{{ labels.types.string }}</option>
        <option value="number">{{ labels.types.number }}</option>
      </select>
      <input
        v-model="newMapKey"
        :type="newMapKeyKind === 'number' ? 'number' : 'text'"
        :disabled="disabled"
        :placeholder="labels.keyPlaceholder"
        :aria-label="labels.keyPlaceholder"
      />
      <select v-model="newMapValueKind" :disabled="disabled">
        <option value="string">{{ labels.types.string }}</option>
        <option value="number">{{ labels.types.number }}</option>
        <option value="boolean">{{ labels.types.boolean }}</option>
        <option value="list">{{ labels.types.list }}</option>
        <option value="table">{{ labels.types.table }}</option>
      </select>
      <button type="submit" :disabled="disabled || !canAddMapEntry">
        <Plus :size="13" />{{ labels.addField }}
      </button>
    </form>

    <form
      v-else-if="!vectorType"
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
        v-if="!tableStructure?.mutableKeys"
        v-model="newObjectKind"
        :disabled="disabled"
      >
        <option value="string">{{ labels.types.string }}</option>
        <option value="number">{{ labels.types.number }}</option>
        <option value="boolean">{{ labels.types.boolean }}</option>
        <option value="list">{{ labels.types.list }}</option>
        <option value="table">{{ labels.types.table }}</option>
      </select>
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
  background: #181b18;
  outline: 1px solid rgba(255, 255, 255, 0.065);
}

.config-structured-editor.is-nested {
  background: #151715;
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

.config-structured-editor button,
.config-structured-editor select,
.config-structured-editor input,
.config-value-input {
  border: 0;
  border-radius: 3px;
  outline: 1px solid rgba(255, 255, 255, 0.075);
  color: var(--admin-text);
  background: #212421;
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
  background: color-mix(in srgb, var(--admin-green) 12%, #212421);
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
  grid-template-columns: 24px minmax(0, 1fr) 27px;
  align-items: center;
  gap: 6px;
  padding: 5px 6px;
  background: #1a1d1a;
}

.config-structured-editor__property {
  grid-template-columns: 24px minmax(80px, 0.35fr) minmax(150px, 1fr) 27px;
}

.config-structured-editor__property.is-map {
  grid-template-columns: 24px minmax(105px, 0.42fr) minmax(150px, 1fr) 27px;
}

.config-structured-editor__row.has-structured-value,
.config-structured-editor__property.has-structured-value {
  align-items: start;
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
.config-structured-editor__property.is-map.has-structured-value
  > .config-structured-editor__map-key {
  grid-column: 2 / 4;
  grid-row: 1;
  align-self: center;
}

.config-structured-editor__row.has-structured-value
  > .config-structured-editor__remove {
  grid-column: 3;
  grid-row: 1;
}

.config-structured-editor__property.has-structured-value
  > .config-structured-editor__remove {
  grid-column: 4;
  grid-row: 1;
}

.config-structured-editor__map-key {
  min-width: 0;
  display: grid;
  gap: 3px;
}

.config-structured-editor__map-key small {
  color: var(--admin-dim);
  font-size: 7px;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.config-structured-editor__map-key input {
  width: 100%;
  min-width: 0;
  height: 25px;
  padding: 0 7px;
}

.config-structured-editor__property > strong {
  overflow: hidden;
  color: #c9cec9;
  font-size: 9px;
  font-weight: 550;
  text-overflow: ellipsis;
  white-space: nowrap;
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
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  align-items: center;
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

.config-structured-editor__add-field.is-list select {
  margin-left: auto;
}

.config-value-input {
  width: 100%;
  min-width: 0;
  height: 29px;
  padding: 0 8px;
}

.config-value-input:focus,
.config-structured-editor input:focus,
.config-structured-editor select:focus {
  outline-color: color-mix(in srgb, var(--admin-green) 45%, transparent);
}

.config-value-toggle {
  position: relative;
  justify-self: end;
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
  background: color-mix(in srgb, var(--admin-green) 72%, #1f321f);
}

.config-value-toggle input:checked + i::after {
  transform: translateX(14px);
  background: #f4f7f4;
}
</style>
