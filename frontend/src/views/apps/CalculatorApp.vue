<script setup lang="ts">
import { useCalculatorStore } from '@/stores/calculator'
import { usePhoneStore } from '@/stores/phone'

const calculator = useCalculatorStore()
const phone = usePhoneStore()
const keys: Array<{ label: string; action: () => void; kind?: string }> = [
  { label: 'AC', action: calculator.clear, kind: 'utility' },
  { label: '+/−', action: calculator.toggleSign, kind: 'utility' },
  { label: '%', action: calculator.percent, kind: 'utility' },
  {
    label: '÷',
    action: () => calculator.chooseOperator('divide'),
    kind: 'operator',
  },
  ...['7', '8', '9'].map((value) => ({
    label: value,
    action: () => calculator.digit(value),
  })),
  {
    label: '×',
    action: () => calculator.chooseOperator('multiply'),
    kind: 'operator',
  },
  ...['4', '5', '6'].map((value) => ({
    label: value,
    action: () => calculator.digit(value),
  })),
  {
    label: '−',
    action: () => calculator.chooseOperator('subtract'),
    kind: 'operator',
  },
  ...['1', '2', '3'].map((value) => ({
    label: value,
    action: () => calculator.digit(value),
  })),
  {
    label: '+',
    action: () => calculator.chooseOperator('add'),
    kind: 'operator',
  },
  { label: '0', action: () => calculator.digit('0'), kind: 'zero' },
  { label: '.', action: calculator.decimal },
  { label: '=', action: calculator.equals, kind: 'operator' },
]
</script>

<template>
  <main
    class="native-app calculator-app"
    :aria-label="phone.t('Apps.calculator.name')"
  >
    <div class="calculator-display" aria-live="polite">
      {{ calculator.display }}
    </div>
    <div class="calculator-pad">
      <button
        v-for="key in keys"
        :key="key.label"
        type="button"
        :class="key.kind"
        @click="key.action"
      >
        {{ key.label }}
      </button>
    </div>
  </main>
</template>
