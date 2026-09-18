<script setup lang="ts">
import { computed, nextTick, ref, watch, type Component } from 'vue'
import {
  Calculator,
  Delete,
  Divide,
  Equal,
  History,
  Minus,
  Plus,
  Trash2,
  X,
} from 'lucide-vue-next'

import {
  useCalculatorStore,
  type CalculatorHistoryEntry,
} from '@/stores/calculator'
import { usePhoneStore } from '@/stores/phone'
import { SkyButton, SkyNavbar, SkySheet } from '@/ui'
import type {
  CalculatorOperator,
  CalculatorUnaryOperation,
} from '@/utils/calculator'

type CalculatorKey = {
  label: string
  action: () => void
  kind?: 'operator' | 'utility'
  operator?: CalculatorOperator
  icon?: Component
  disabled?: () => boolean
}

const calculator = useCalculatorStore()
const phone = usePhoneStore()
const historyOpened = ref(false)
const editingHistory = ref(false)
const scientificOpened = ref(false)
const resultDisplay = ref<HTMLElement | null>(null)
const expressionDisplay = ref<HTMLElement | null>(null)

const expression = computed(() =>
  calculator.calculation
    .replace(/\s*=\s*$/, '')
    .split(' ')
    .join(''),
)

function formatDisplayValue(value: string): string {
  if (value === 'Error') return value

  const exponentIndex = value.search(/e/i)
  const mantissa = exponentIndex === -1 ? value : value.slice(0, exponentIndex)
  const exponent = exponentIndex === -1 ? '' : value.slice(exponentIndex)
  const negative = mantissa.startsWith('-')
  const unsigned = negative ? mantissa.slice(1) : mantissa
  const [integer, fraction] = unsigned.split('.')
  const groupedInteger = integer.replace(/\B(?=(\d{3})+(?!\d))/g, '.')

  return `${negative ? '−' : ''}${groupedInteger}${fraction ? `,${fraction}` : ''}${exponent}`
}

const scientificKeys = computed<CalculatorKey[]>(() => [
  { label: '(', action: calculator.openParenthesis },
  {
    label: ')',
    action: calculator.closeParenthesis,
    disabled: () => calculator.parentFrames.length === 0,
  },
  {
    label: 'mc',
    action: calculator.memoryClear,
    disabled: () => calculator.memory === 0,
  },
  { label: 'm+', action: calculator.memoryAdd },
  { label: 'm−', action: calculator.memorySubtract },
  {
    label: 'mr',
    action: calculator.memoryRecall,
    disabled: () => calculator.memory === 0,
  },
  { label: '2ⁿᵈ', action: calculator.toggleSecond },
  {
    label: calculator.second ? '√x' : 'x²',
    action: () => calculator.unary(calculator.second ? 'sqrt' : 'square'),
  },
  {
    label: calculator.second ? '∛x' : 'x³',
    action: () => calculator.unary(calculator.second ? 'cbrt' : 'cube'),
  },
  {
    label: 'xʸ',
    action: () => calculator.chooseOperator('power'),
    operator: 'power',
  },
  {
    label: 'eˣ',
    action: () => calculator.unary('exp'),
  },
  {
    label: '10ˣ',
    action: () => calculator.unary('tenPower'),
  },
  {
    label: '¹/x',
    action: () => calculator.unary('reciprocal'),
  },
  { label: '²√x', action: () => calculator.unary('sqrt') },
  { label: '³√x', action: () => calculator.unary('cbrt') },
  {
    label: 'ʸ√x',
    action: () => calculator.chooseOperator('root'),
    operator: 'root',
  },
  { label: 'ln', action: () => calculator.unary('ln') },
  { label: 'log₁₀', action: () => calculator.unary('log10') },
  { label: 'x!', action: () => calculator.unary('factorial') },
  {
    label: calculator.second ? 'sin⁻¹' : 'sin',
    action: () =>
      calculator.unary(
        calculator.second ? 'asin' : ('sin' as CalculatorUnaryOperation),
      ),
  },
  {
    label: calculator.second ? 'cos⁻¹' : 'cos',
    action: () =>
      calculator.unary(
        calculator.second ? 'acos' : ('cos' as CalculatorUnaryOperation),
      ),
  },
  {
    label: calculator.second ? 'tan⁻¹' : 'tan',
    action: () =>
      calculator.unary(
        calculator.second ? 'atan' : ('tan' as CalculatorUnaryOperation),
      ),
  },
  { label: 'e', action: () => calculator.constant(Math.E) },
  { label: 'EE', action: () => calculator.chooseOperator('power') },
  { label: 'Rand', action: calculator.random },
  { label: 'sinh', action: () => calculator.unary('sinh') },
  { label: 'cosh', action: () => calculator.unary('cosh') },
  { label: 'tanh', action: () => calculator.unary('tanh') },
  { label: 'π', action: () => calculator.constant(Math.PI) },
  {
    label: calculator.angleUnit === 'radians' ? 'Deg' : 'Rad',
    action: calculator.toggleAngleUnit,
  },
])

const basicKeys: CalculatorKey[] = [
  { label: 'delete', action: calculator.backspace, kind: 'utility' },
  { label: 'C', action: calculator.clear, kind: 'utility' },
  { label: '%', action: calculator.percent, kind: 'utility' },
  {
    label: '÷',
    action: () => calculator.chooseOperator('divide'),
    kind: 'operator',
    operator: 'divide',
    icon: Divide,
  },
  ...['7', '8', '9'].map((value) => ({
    label: value,
    action: () => calculator.digit(value),
  })),
  {
    label: '×',
    action: () => calculator.chooseOperator('multiply'),
    kind: 'operator',
    operator: 'multiply',
    icon: X,
  },
  ...['4', '5', '6'].map((value) => ({
    label: value,
    action: () => calculator.digit(value),
  })),
  {
    label: '−',
    action: () => calculator.chooseOperator('subtract'),
    kind: 'operator',
    operator: 'subtract',
    icon: Minus,
  },
  ...['1', '2', '3'].map((value) => ({
    label: value,
    action: () => calculator.digit(value),
  })),
  {
    label: '+',
    action: () => calculator.chooseOperator('add'),
    kind: 'operator',
    operator: 'add',
    icon: Plus,
  },
  { label: '+/−', action: calculator.toggleSign },
  { label: '0', action: () => calculator.digit('0') },
  { label: ',', action: calculator.decimal },
  {
    label: '=',
    action: calculator.equals,
    kind: 'operator',
    icon: Equal,
  },
]

const historyGroups = computed(() => {
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  const yesterday = today.getTime() - 86_400_000
  const groups: Array<{ label: string; entries: CalculatorHistoryEntry[] }> = []
  const todayEntries = calculator.history.filter(
    (entry) => entry.createdAt >= today.getTime(),
  )
  const yesterdayEntries = calculator.history.filter(
    (entry) =>
      entry.createdAt >= yesterday && entry.createdAt < today.getTime(),
  )
  const olderEntries = calculator.history.filter(
    (entry) => entry.createdAt < yesterday,
  )
  if (todayEntries.length)
    groups.push({
      label: phone.t('Apps.calculator.today'),
      entries: todayEntries,
    })
  if (yesterdayEntries.length)
    groups.push({
      label: phone.t('Apps.calculator.yesterday'),
      entries: yesterdayEntries,
    })
  if (olderEntries.length)
    groups.push({
      label: phone.t('Apps.calculator.earlier'),
      entries: olderEntries,
    })
  return groups
})

function scrollDisplay(event: WheelEvent): void {
  const display = event.currentTarget as HTMLElement
  if (display.scrollWidth <= display.clientWidth) return
  event.preventDefault()
  display.scrollLeft +=
    Math.abs(event.deltaX) > Math.abs(event.deltaY)
      ? event.deltaX
      : event.deltaY
}

function useHistoryEntry(entry: CalculatorHistoryEntry): void {
  if (editingHistory.value) {
    calculator.removeHistory(entry.id)
    return
  }
  calculator.useHistory(entry)
  historyOpened.value = false
}

watch([() => calculator.display, expression], async () => {
  await nextTick()
  for (const display of [resultDisplay.value, expressionDisplay.value]) {
    if (display) display.scrollLeft = display.scrollWidth
  }
})
</script>

<template>
  <main
    class="native-app calculator-app"
    :class="{
      'calculator-app--light': !phone.isDarkMode,
      'calculator-app--scientific': scientificOpened,
    }"
    :aria-label="phone.t('Apps.calculator.name')"
  >
    <header class="calculator-toolbar">
      <button
        type="button"
        :aria-label="phone.t('Apps.calculator.history')"
        @click="historyOpened = true"
      >
        <History :size="24" :stroke-width="1.8" />
      </button>
      <button
        type="button"
        :aria-label="phone.t('Apps.calculator.changeMode')"
        @click="scientificOpened = !scientificOpened"
      >
        <Calculator :size="23" :stroke-width="1.8" />
      </button>
    </header>

    <section class="calculator-display" aria-live="polite">
      <div
        v-if="expression"
        ref="expressionDisplay"
        class="calculator-expression"
        @wheel="scrollDisplay"
      >
        {{ expression }}
      </div>
      <div ref="resultDisplay" class="calculator-result" @wheel="scrollDisplay">
        {{ formatDisplayValue(calculator.display) }}
      </div>
    </section>

    <div v-if="scientificOpened" class="calculator-angle">
      {{ calculator.angleUnit === 'radians' ? 'Rad' : 'Deg' }}
    </div>

    <section
      v-if="scientificOpened"
      class="calculator-scientific-pad"
      :aria-label="phone.t('Apps.calculator.scientificFunctions')"
    >
      <button
        v-for="key in scientificKeys"
        :key="key.label"
        type="button"
        class="calculator-key calculator-key--scientific"
        :class="{
          'calculator-key--selected':
            (key.operator === calculator.pendingOperator &&
              calculator.waitingForOperand) ||
            (key.label === '2ⁿᵈ' && calculator.second),
        }"
        :disabled="key.disabled?.()"
        @click="key.action"
      >
        {{ key.label }}
      </button>
    </section>

    <section class="calculator-basic-pad">
      <button
        v-for="key in basicKeys"
        :key="key.label"
        type="button"
        class="calculator-key calculator-key--basic"
        :class="[
          key.kind && `calculator-key--${key.kind}`,
          {
            'calculator-key--selected':
              key.operator === calculator.pendingOperator &&
              calculator.waitingForOperand,
          },
        ]"
        :aria-label="key.icon ? key.label : undefined"
        @click="key.action"
      >
        <component
          :is="key.icon"
          v-if="key.icon"
          class="calculator-key__operator-icon"
          :size="24"
          :stroke-width="2"
          aria-hidden="true"
        />
        <Delete v-else-if="key.label === 'delete'" :size="23" />
        <span v-else>{{ key.label }}</span>
      </button>
    </section>

    <SkySheet
      class="calculator-history-sheet"
      :opened="historyOpened"
      :aria-label="phone.t('Apps.calculator.history')"
      @backdropclick="historyOpened = false"
      @escape="historyOpened = false"
    >
      <section class="calculator-history sky-ui-provider sky-ui-provider--dark">
        <div class="calculator-history__handle"></div>
        <SkyNavbar
          class="calculator-history__navbar"
          :scroll-el="null"
          title=""
        >
          <template #left>
            <SkyButton
              glass
              class="calculator-history__nav-button calculator-history__nav-button--edit"
              inline
              rounded
              type="button"
              @click="editingHistory = !editingHistory"
            >
              <span class="calculator-history__edit-label">
                {{
                  phone.t(
                    editingHistory
                      ? 'Apps.calculator.done'
                      : 'Apps.calculator.edit',
                  )
                }}
              </span>
            </SkyButton>
          </template>
          <template #right>
            <SkyButton
              glass
              class="calculator-history__nav-button calculator-history__nav-button--close"
              icon-only
              rounded
              type="button"
              :aria-label="phone.t('Apps.calculator.closeHistory')"
              @click="historyOpened = false"
            >
              <X :size="23" />
            </SkyButton>
          </template>
        </SkyNavbar>

        <div v-if="historyGroups.length" class="calculator-history__scroll">
          <section v-for="group in historyGroups" :key="group.label">
            <h2>{{ group.label }}</h2>
            <button
              v-for="entry in group.entries"
              :key="entry.id"
              type="button"
              class="calculator-history__entry"
              @click="useHistoryEntry(entry)"
            >
              <Trash2 v-if="editingHistory" :size="18" />
              <span>
                <small>{{ entry.expression.split(' ').join('') }}</small>
                <strong>{{ formatDisplayValue(entry.result) }}</strong>
              </span>
            </button>
          </section>
        </div>
        <div v-else class="calculator-history__empty">
          <History :size="34" />
          <strong>{{ phone.t('Apps.calculator.noHistory') }}</strong>
        </div>

        <button
          v-if="editingHistory && calculator.history.length"
          type="button"
          class="calculator-history__clear"
          @click="calculator.clearHistory"
        >
          {{ phone.t('Apps.calculator.clearHistory') }}
        </button>
      </section>
    </SkySheet>
  </main>
</template>

<style scoped>
.calculator-app {
  --calculator-orange: #ff9500;
  padding: calc(var(--sky-safe-area-top) + 5px) 15px
    calc(var(--sky-safe-area-bottom) + 4px);
  display: flex;
  flex-direction: column;
  gap: 8px;
  background: #000;
  color: #fff;
}

.calculator-toolbar {
  min-height: 44px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.calculator-toolbar button {
  width: 44px;
  height: 44px;
  border: 1px solid rgb(255 255 255 / 10%);
  border-radius: 50%;
  display: grid;
  place-items: center;
  background: linear-gradient(145deg, #202022, #101011);
  box-shadow: inset 0 1px rgb(255 255 255 / 9%);
  color: #f5f5f7;
}

.calculator-display {
  min-height: 132px;
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  justify-content: flex-end;
  overflow: hidden;
}

.calculator-expression,
.calculator-result {
  width: 100%;
  overflow-x: auto;
  overflow-y: hidden;
  text-align: right;
  white-space: nowrap;
  scrollbar-width: none;
}

.calculator-expression::-webkit-scrollbar,
.calculator-result::-webkit-scrollbar {
  display: none;
}

.calculator-expression {
  color: #8e8e93;
  font-size: 19px;
}

.calculator-result {
  font-size: 54px;
  font-weight: 280;
  letter-spacing: -2px;
  line-height: 1.05;
}

.calculator-angle {
  height: 20px;
  display: flex;
  align-items: center;
  color: #dedee2;
  font-size: 13px;
}

.calculator-scientific-pad,
.calculator-basic-pad {
  display: grid;
  gap: 6px;
}

.calculator-scientific-pad {
  grid-template-columns: repeat(6, minmax(0, 1fr));
}

.calculator-basic-pad {
  flex: 1;
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.calculator-key {
  min-width: 0;
  border: 1px solid rgb(255 255 255 / 10%);
  display: grid;
  place-items: center;
  background: linear-gradient(145deg, #29292b, #1a1a1c);
  box-shadow: inset 0 1px rgb(255 255 255 / 7%);
  color: #f5f5f7;
  font: inherit;
  cursor: pointer;
  transition:
    transform 130ms ease,
    filter 150ms ease,
    border-color 150ms ease;
}

.calculator-key--scientific {
  min-height: 38px;
  border-radius: 999px;
  font-size: 15px;
}

.calculator-key--basic {
  min-height: 45px;
  border-radius: 999px;
  font-size: 25px;
  font-weight: 390;
}

.calculator-key--utility {
  background: linear-gradient(145deg, #79797c, #58585b);
}

.calculator-key--operator {
  border-color: #ffb23b;
  background: linear-gradient(180deg, #ffa20c, var(--calculator-orange));
  box-shadow: inset 0 1px rgb(255 255 255 / 28%);
}

.calculator-app--light {
  background: var(--sky-bg);
  color: var(--sky-text);
}

.calculator-app--light .calculator-toolbar button,
.calculator-app--light .calculator-key {
  border-color: var(--sky-hairline);
  background: linear-gradient(145deg, #ffffff, #e5e5ea);
  box-shadow: inset 0 1px rgb(255 255 255 / 80%);
  color: var(--sky-text);
}

.calculator-app--light .calculator-expression,
.calculator-app--light .calculator-angle {
  color: var(--sky-muted);
}

.calculator-app--light .calculator-key--utility {
  background: linear-gradient(145deg, #d1d1d6, #aeaeb2);
  color: #111114;
}

.calculator-app--light .calculator-key--operator {
  border-color: #ffb23b;
  background: linear-gradient(180deg, #ffa20c, var(--calculator-orange));
  color: #ffffff;
}

.calculator-key__operator-icon {
  width: 24px;
  height: 24px;
  display: block;
  margin: 0;
  pointer-events: none;
}

.calculator-key--selected {
  background: #f5f5f7;
  color: var(--calculator-orange);
}

.calculator-key--operator.calculator-key--selected {
  border-color: #ffc05c;
  background: linear-gradient(180deg, #e98700, #c96800);
  box-shadow:
    inset 0 1px rgb(255 255 255 / 22%),
    inset 0 0 0 1px rgb(255 255 255 / 12%);
  color: #fff;
}

.calculator-key:disabled {
  opacity: 0.35;
}

@media (hover: hover) {
  .calculator-key:hover:not(:disabled),
  .calculator-toolbar button:hover,
  .calculator-history button:hover {
    transform: translateY(-1px);
    filter: brightness(1.1);
  }
}

.calculator-key:active:not(:disabled),
.calculator-toolbar button:active,
.calculator-history button:active {
  transform: scale(0.96);
  filter: brightness(0.88);
}

.calculator-key:focus-visible,
.calculator-toolbar button:focus-visible,
.calculator-history button:focus-visible {
  outline: 2px solid #ffd08a;
  outline-offset: 2px;
}

.calculator-app:not(.calculator-app--scientific) .calculator-display {
  min-height: 250px;
}

.calculator-app:not(.calculator-app--scientific) .calculator-basic-pad {
  flex: none;
  gap: 11px 14px;
}

.calculator-app:not(.calculator-app--scientific) .calculator-key--basic {
  width: 100%;
  min-height: 0;
  aspect-ratio: 1;
  border-radius: 50%;
  font-size: 29px;
}

:deep(.calculator-history-sheet .sky-overlay-backdrop) {
  background: rgb(0 0 0 / 60%);
}

:deep(.calculator-history-sheet .sky-sheet__panel) {
  height: 72%;
  max-height: 72%;
  overflow: hidden;
  border-color: rgb(255 255 255 / 15%);
  border-radius: 31px 31px 0 0;
  background: rgb(25 25 27 / 97%);
  color: #f5f5f7;
  box-shadow: 0 -10px 40px rgb(0 0 0 / 48%);
}

.calculator-history {
  height: 100%;
  padding: 8px 18px calc(var(--sky-safe-area-bottom) + 8px);
  display: flex;
  flex-direction: column;
}

.calculator-history__handle {
  width: 40px;
  height: 5px;
  margin: 0 auto 8px;
  border-radius: 999px;
  background: #77777b;
}

.calculator-history__navbar {
  --sky-navbar-glass: transparent;
  --sky-navbar-safe-area-top: 0px;
  min-height: var(--sky-navbar-height);
  padding-top: 0;
}

.calculator-history__navbar :deep(.sky-navbar__inner) {
  grid-template-columns: 106px minmax(0, 1fr) 44px;
  padding-inline: 0;
  margin-bottom: 6px;
}

.calculator-history__navbar :deep(.sky-navbar__left),
.calculator-history__navbar :deep(.sky-navbar__right) {
  background: transparent;
  box-shadow: none;
  -webkit-backdrop-filter: none;
  backdrop-filter: none;
}

.calculator-history__navbar :deep(.calculator-history__nav-button) {
  --sky-glass: rgb(44 44 46 / 62%);
  --sky-hairline: rgb(255 255 255 / 14%);
  height: 44px;
  min-height: 44px;
  color: #fff;
}

.calculator-history__navbar :deep(.calculator-history__nav-button:active) {
  filter: brightness(0.94);
}

.calculator-history__navbar :deep(.calculator-history__nav-button--edit) {
  width: 106px;
  min-width: 106px;
  position: relative;
  padding: 0;
}

.calculator-history__navbar :deep(.calculator-history__edit-label) {
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
  line-height: 1;
  text-align: center;
  pointer-events: none;
}

.calculator-history__navbar :deep(.calculator-history__nav-button--close) {
  min-width: 44px;
}

@media (hover: hover) {
  .calculator-history__navbar
    :deep(.calculator-history__nav-button:hover:not(:disabled)) {
    transform: none;
    filter: brightness(1.08);
  }
}

.calculator-history__navbar :deep(.sky-navbar__background),
.calculator-history__navbar :deep(.sky-navbar__blur) {
  display: none;
}

.calculator-history__scroll {
  min-height: 0;
  margin-top: 18px;
  flex: 1;
  overflow-y: auto;
  scrollbar-width: none;
}

.calculator-history__scroll::-webkit-scrollbar {
  display: none;
}

.calculator-history__scroll section + section {
  margin-top: 18px;
}

.calculator-history h2 {
  margin: 0;
  padding: 0 2px 10px;
  border-bottom: 1px solid rgb(255 255 255 / 16%);
  color: #a5a5aa;
  font-size: 18px;
}

.calculator-history__entry {
  width: 100%;
  min-height: 66px;
  border: 0;
  border-bottom: 1px solid rgb(255 255 255 / 14%);
  padding: 10px 2px;
  display: flex;
  align-items: center;
  gap: 12px;
  background: transparent;
  color: #fff;
  text-align: left;
}

.calculator-history__entry span,
.calculator-history__entry small,
.calculator-history__entry strong {
  display: block;
}

.calculator-history__entry small {
  margin-bottom: 4px;
  color: #a5a5aa;
  font-size: 13px;
}

.calculator-history__entry strong {
  font-size: 18px;
  font-weight: 450;
}

.calculator-history__entry > svg {
  color: #ff453a;
}

.calculator-history__empty {
  flex: 1;
  display: grid;
  place-content: center;
  justify-items: center;
  gap: 10px;
  color: #8e8e93;
}

.calculator-history__clear {
  min-height: 44px;
  border: 0;
  background: transparent;
  color: #ff453a;
  font: inherit;
}

@media (prefers-reduced-motion: reduce) {
  .calculator-key,
  .calculator-toolbar button,
  .calculator-history button {
    transition: none;
  }
}
</style>
