<script setup lang="ts">
import { Plus, Rows3, TableProperties, Trash2 } from 'lucide-vue-next'
import { computed, ref } from 'vue'

export type AdminConfigEditorLabels = {
  addField: string
  addRow: string
  configuredSecret: string
  convertToList: string
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
  }>(),
  { ariaLabel: '', depth: 0, disabled: false },
)
const emit = defineEmits<{ 'update:modelValue': [value: unknown] }>()

type ValueKind = 'boolean' | 'list' | 'number' | 'string' | 'table'

const newArrayKind = ref<ValueKind>('string')
const newObjectKey = ref('')
const newObjectKind = ref<ValueKind>('string')

const isList = computed(() => Array.isArray(props.modelValue))
const listValue = computed<unknown[]>(() =>
  Array.isArray(props.modelValue) ? props.modelValue : [],
)
const isTable = computed(
  () =>
    props.modelValue !== null &&
    typeof props.modelValue === 'object' &&
    !Array.isArray(props.modelValue),
)
const tableValue = computed<Record<string, unknown>>(() =>
  isTable.value ? (props.modelValue as Record<string, unknown>) : {},
)
const vectorType = computed(() => {
  const value = tableValue.value.__skyType
  return typeof value === 'string' && /^vector[234]$/.test(value) ? value : ''
})
const tableEntries = computed(() =>
  Object.entries(tableValue.value).filter(([key]) => key !== '__skyType'),
)
const isMaskedSecret = computed(() => props.modelValue === '***REDACTED***')

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
  const rows = Array.isArray(props.modelValue) ? [...props.modelValue] : []
  rows.splice(index, 1)
  emit('update:modelValue', rows)
}

function updateTableField(key: string, value: unknown): void {
  emit('update:modelValue', { ...tableValue.value, [key]: value })
}

function removeTableField(key: string): void {
  const next = { ...tableValue.value }
  delete next[key]
  emit('update:modelValue', next)
}

function addTableField(): void {
  const key = newObjectKey.value.trim()
  if (!key || Object.prototype.hasOwnProperty.call(tableValue.value, key))
    return
  emit('update:modelValue', {
    ...tableValue.value,
    [key]: blankValue(newObjectKind.value),
  })
  newObjectKey.value = ''
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
      <div>
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
        <button
          v-if="!listValue.length"
          type="button"
          :disabled="disabled"
          :title="labels.convertToTable"
          @click="emit('update:modelValue', {})"
        >
          <TableProperties :size="13" />
        </button>
        <button type="button" :disabled="disabled" @click="addListRow">
          <Plus :size="13" />{{ labels.addRow }}
        </button>
      </div>
    </header>

    <div v-if="listValue.length" class="config-structured-editor__rows">
      <div
        v-for="(row, index) in listValue"
        :key="index"
        class="config-structured-editor__row"
      >
        <span class="config-structured-editor__index">{{ index + 1 }}</span>
        <AdminConfigValueEditor
          :model-value="row"
          :aria-label="`${ariaLabel} ${index + 1}`"
          :labels="labels"
          :disabled="disabled"
          :depth="depth + 1"
          @update:model-value="updateListRow(index, $event)"
        />
        <button
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
      <button
        v-if="!tableEntries.length && !vectorType"
        type="button"
        :disabled="disabled"
        :title="labels.convertToList"
        @click="emit('update:modelValue', [])"
      >
        <Rows3 :size="13" />{{ labels.convertToList }}
      </button>
    </header>

    <div
      v-if="tableEntries.length"
      class="config-structured-editor__properties"
    >
      <div
        v-for="([key, value], index) in tableEntries"
        :key="key"
        class="config-structured-editor__property"
      >
        <span class="config-structured-editor__index">{{ index + 1 }}</span>
        <strong>{{ key }}</strong>
        <AdminConfigValueEditor
          :model-value="value"
          :aria-label="`${ariaLabel} ${key}`"
          :labels="labels"
          :disabled="disabled"
          :depth="depth + 1"
          @update:model-value="updateTableField(key, $event)"
        />
        <button
          v-if="!vectorType"
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
      v-if="!vectorType"
      class="config-structured-editor__add-field"
      @submit.prevent="addTableField"
    >
      <input
        v-model="newObjectKey"
        type="text"
        :disabled="disabled"
        :placeholder="labels.keyPlaceholder"
      />
      <select v-model="newObjectKind" :disabled="disabled">
        <option value="string">{{ labels.types.string }}</option>
        <option value="number">{{ labels.types.number }}</option>
        <option value="boolean">{{ labels.types.boolean }}</option>
        <option value="list">{{ labels.types.list }}</option>
        <option value="table">{{ labels.types.table }}</option>
      </select>
      <button type="submit" :disabled="disabled || !newObjectKey.trim()">
        <Plus :size="13" />{{ labels.addField }}
      </button>
    </form>
  </div>

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

.config-structured-editor__empty {
  padding: 13px 10px;
  color: var(--admin-dim);
  font-size: 9px;
  text-align: center;
}

.config-structured-editor__add-field {
  display: grid;
  grid-template-columns: minmax(100px, 1fr) 90px auto;
  gap: 6px;
  padding: 6px;
  background: #151715;
}

.config-structured-editor__add-field input {
  min-width: 0;
  height: 25px;
  padding: 0 7px;
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
