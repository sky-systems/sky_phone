import type { Directive } from 'vue'

const inputListeners = new WeakMap<HTMLInputElement, () => void>()
const MINIMUM_INPUT_WIDTH = 42

function syncInputWidth(input: HTMLInputElement): void {
  input.style.width = '1px'
  input.style.width = `${Math.max(MINIMUM_INPUT_WIDTH, Math.ceil(input.scrollWidth) + 2)}px`
}

export const vConfigInputWidth: Directive<HTMLInputElement> = {
  mounted(input) {
    const listener = () => syncInputWidth(input)
    inputListeners.set(input, listener)
    input.addEventListener('input', listener)
    syncInputWidth(input)
  },
  updated(input) {
    syncInputWidth(input)
  },
  beforeUnmount(input) {
    const listener = inputListeners.get(input)
    if (listener) input.removeEventListener('input', listener)
    inputListeners.delete(input)
  },
}
