import type { Directive } from 'vue'

const inputListeners = new WeakMap<HTMLInputElement, () => void>()
const MINIMUM_INPUT_WIDTH_EM = 4.2

function syncInputWidth(input: HTMLInputElement): void {
  const style = getComputedStyle(input)
  const fontSize = Number.parseFloat(style.fontSize) || 10
  const borderWidth =
    (Number.parseFloat(style.borderLeftWidth) || 0) +
    (Number.parseFloat(style.borderRightWidth) || 0)
  input.style.width = '1px'
  // Follow the panel's viewport-scaled font, including after a resolution change.
  input.style.width = `${Math.max(MINIMUM_INPUT_WIDTH_EM, (Math.ceil(input.scrollWidth) + borderWidth) / fontSize)}em`
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
