import { describe, expect, it } from 'vitest'

import { isTextInputElement } from '@/utils/textInputFocus'

function element(
  tagName: string,
  attributes: Record<string, string> = {},
  isContentEditable = false,
) {
  return {
    getAttribute(name: string) {
      return attributes[name] ?? null
    },
    isContentEditable,
    tagName,
  }
}

describe('text input focus', () => {
  it('recognizes fields that accept typed text', () => {
    expect(isTextInputElement(element('INPUT'))).toBe(true)
    expect(isTextInputElement(element('INPUT', { type: 'number' }))).toBe(true)
    expect(isTextInputElement(element('TEXTAREA'))).toBe(true)
    expect(isTextInputElement(element('DIV', {}, true))).toBe(true)
    expect(isTextInputElement(element('DIV', { role: 'textbox' }))).toBe(true)
  })

  it('ignores non-text and read-only controls', () => {
    expect(isTextInputElement(element('INPUT', { type: 'checkbox' }))).toBe(
      false,
    )
    expect(isTextInputElement(element('INPUT', { type: 'range' }))).toBe(false)
    expect(isTextInputElement(element('INPUT', { readonly: '' }))).toBe(false)
    expect(isTextInputElement(element('BUTTON'))).toBe(false)
  })
})
