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
    expect(state.calculation).toBe('8 +')
    state = inputDigit(state, '2')
    state = chooseCalculatorOperator(state, 'multiply')
    expect(state.display).toBe('10')
    expect(state.calculation).toBe('8 + 2 ×')
    state = inputDigit(state, '3')
    state = resolveCalculator(state)
    expect(state.display).toBe('30')
    expect(state.calculation).toBe('8 + 2 × 3 =')
    expect(calculate(4, 0, 'divide')).toBeNull()
  })

  it('replaces a pending operator and clears completed history on new input', () => {
    let state = inputDigit(clearCalculator(), '9')
    state = chooseCalculatorOperator(state, 'add')
    state = chooseCalculatorOperator(state, 'subtract')
    expect(state.calculation).toBe('9 −')

    state = inputDigit(state, '3')
    state = resolveCalculator(state)
    expect(state.calculation).toBe('9 − 3 =')
    expect(inputDigit(state, '4').calculation).toBe('')
  })
})
