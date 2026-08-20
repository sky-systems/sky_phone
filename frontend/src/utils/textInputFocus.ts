const nonTextInputTypes = new Set([
  'button',
  'checkbox',
  'color',
  'file',
  'hidden',
  'image',
  'radio',
  'range',
  'reset',
  'submit',
])

type FocusableElement = Pick<
  HTMLElement,
  'getAttribute' | 'isContentEditable' | 'tagName'
>

export function isTextInputElement(element: FocusableElement): boolean {
  if (
    element.getAttribute('readonly') !== null ||
    element.getAttribute('aria-readonly') === 'true'
  ) {
    return false
  }
  if (element.isContentEditable || element.getAttribute('role') === 'textbox') {
    return true
  }
  if (element.tagName === 'TEXTAREA') return true
  if (element.tagName !== 'INPUT') return false

  const inputType = element.getAttribute('type')?.toLowerCase() ?? 'text'
  return !nonTextInputTypes.has(inputType)
}
