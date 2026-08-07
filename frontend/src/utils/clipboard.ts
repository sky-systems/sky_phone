export function copyText(value: string): boolean {
  const activeElement =
    document.activeElement instanceof HTMLElement
      ? document.activeElement
      : undefined
  const textarea = document.createElement('textarea')

  textarea.value = value
  textarea.readOnly = true
  textarea.style.position = 'fixed'
  textarea.style.left = '-9999px'
  textarea.style.opacity = '0'
  document.body.appendChild(textarea)
  textarea.select()
  textarea.setSelectionRange(0, value.length)

  try {
    return document.execCommand('copy')
  } finally {
    textarea.remove()
    activeElement?.focus({ preventScroll: true })
  }
}
