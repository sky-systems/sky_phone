export type CalculatorOperator = 'add' | 'subtract' | 'multiply' | 'divide'

export type CalculatorState = {
  accumulator: number | null
  display: string
  error: boolean
  pendingOperator: CalculatorOperator | null
  waitingForOperand: boolean
}

export const INITIAL_CALCULATOR_STATE: CalculatorState = {
  accumulator: null,
  display: '0',
  error: false,
  pendingOperator: null,
  waitingForOperand: false,
}

function formatNumber(value: number): string {
  if (!Number.isFinite(value)) return 'Error'
  const rounded = Number(value.toPrecision(12))
  const rendered = String(rounded)
  return rendered.length <= 12 ? rendered : rounded.toExponential(6)
}

export function calculate(
  left: number,
  right: number,
  operator: CalculatorOperator,
): number | null {
  if (operator === 'add') return left + right
  if (operator === 'subtract') return left - right
  if (operator === 'multiply') return left * right
  if (right === 0) return null
  return left / right
}

export function clearCalculator(): CalculatorState {
  return { ...INITIAL_CALCULATOR_STATE }
}

export function inputDigit(
  state: CalculatorState,
  digit: string,
): CalculatorState {
  if (!/^\d$/.test(digit)) return state
  if (state.error || state.waitingForOperand) {
    return { ...state, display: digit, error: false, waitingForOperand: false }
  }
  if (state.display === '0') return { ...state, display: digit }
  if (state.display.replace('-', '').replace('.', '').length >= 10) return state
  return { ...state, display: `${state.display}${digit}` }
}

export function inputDecimal(state: CalculatorState): CalculatorState {
  if (state.error || state.waitingForOperand) {
    return { ...state, display: '0.', error: false, waitingForOperand: false }
  }
  return state.display.includes('.')
    ? state
    : { ...state, display: `${state.display}.` }
}

export function toggleCalculatorSign(state: CalculatorState): CalculatorState {
  if (state.error || state.display === '0') return state
  return {
    ...state,
    display: state.display.startsWith('-')
      ? state.display.slice(1)
      : `-${state.display}`,
  }
}

export function calculatorPercent(state: CalculatorState): CalculatorState {
  if (state.error) return state
  return { ...state, display: formatNumber(Number(state.display) / 100) }
}

export function chooseCalculatorOperator(
  state: CalculatorState,
  operator: CalculatorOperator,
): CalculatorState {
  if (state.error) return clearCalculator()
  const input = Number(state.display)
  let accumulator = state.accumulator

  if (
    accumulator !== null &&
    state.pendingOperator &&
    !state.waitingForOperand
  ) {
    const result = calculate(accumulator, input, state.pendingOperator)
    if (result === null)
      return { ...clearCalculator(), display: 'Error', error: true }
    accumulator = result
  } else if (accumulator === null) {
    accumulator = input
  }

  return {
    accumulator,
    display: formatNumber(accumulator),
    error: false,
    pendingOperator: operator,
    waitingForOperand: true,
  }
}

export function resolveCalculator(state: CalculatorState): CalculatorState {
  if (state.error || state.accumulator === null || !state.pendingOperator)
    return state
  const result = calculate(
    state.accumulator,
    Number(state.display),
    state.pendingOperator,
  )
  if (result === null)
    return { ...clearCalculator(), display: 'Error', error: true }
  return {
    accumulator: null,
    display: formatNumber(result),
    error: false,
    pendingOperator: null,
    waitingForOperand: true,
  }
}
