import { defineStore } from 'pinia'

import {
  calculatorPercent,
  chooseCalculatorOperator,
  clearCalculator,
  inputDecimal,
  inputDigit,
  resolveCalculator,
  toggleCalculatorSign,
  type CalculatorOperator,
  type CalculatorState,
} from '@/utils/calculator'

export const useCalculatorStore = defineStore('calculator', {
  state: (): CalculatorState => clearCalculator(),
  actions: {
    chooseOperator(operator: CalculatorOperator): void {
      Object.assign(this, chooseCalculatorOperator(this.$state, operator))
    },
    clear(): void {
      Object.assign(this, clearCalculator())
    },
    decimal(): void {
      Object.assign(this, inputDecimal(this.$state))
    },
    digit(value: string): void {
      Object.assign(this, inputDigit(this.$state, value))
    },
    equals(): void {
      Object.assign(this, resolveCalculator(this.$state))
    },
    percent(): void {
      Object.assign(this, calculatorPercent(this.$state))
    },
    toggleSign(): void {
      Object.assign(this, toggleCalculatorSign(this.$state))
    },
  },
})
