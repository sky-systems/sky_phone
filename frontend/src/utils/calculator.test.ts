import { describe, expect, it } from 'vitest'
import {
  calculate,
  chooseCalculatorOperator,
  clearCalculator,
  inputDigit,
  resolveCalculator,
} from './calculator'

describe('calculator', () => {
  it('calculates all four operations', () => {
    expect(calculate(8, 2, 'add')).toBe(10)
    expect(calculate(8, 2, 'subtract')).toBe(6)
    expect(calculate(8, 2, 'multiply')).toBe(16)
    expect(calculate(8, 2, 'divide')).toBe(4)
  })
  it('chains operations and handles division by zero', () => {
    let state = inputDigit(clearCalculator(), '8')
    state = chooseCalculatorOperator(state, 'add')
    state = inputDigit(state, '2')
    state = chooseCalculatorOperator(state, 'multiply')
    expect(state.display).toBe('10')
    state = inputDigit(state, '3')
    expect(resolveCalculator(state).display).toBe('30')
    expect(calculate(4, 0, 'divide')).toBeNull()
  })
})
