import { describe, expect, it } from 'vitest'

import {
  KEYBOARD_MAPPING_KEYS,
  keyboardMappingFromEvent,
} from './keyboardMapping'

describe('FiveM keyboard capture', () => {
  it.each([
    ['ü', 'BracketLeft', 186, 'OEM_1'],
    ['ö', 'Semicolon', 192, 'OEM_3'],
    ['ä', 'Quote', 222, 'OEM_7'],
    ['ß', 'Minus', 219, 'OEM_4'],
    ['Dead', 'Backquote', 220, 'OEM_5'],
    ['<', 'IntlBackslash', 226, 'OEM_102'],
    ['z', 'KeyY', 90, 'Z'],
    ['y', 'KeyZ', 89, 'Y'],
    [';', 'Semicolon', 186, 'OEM_1'],
    ['Enter', 'Enter', 13, 'RETURN'],
    ['Enter', 'NumpadEnter', 13, 'NUMPADENTER'],
    ['5', 'Digit5', 53, '5'],
    ['5', 'Numpad5', 101, 'NUMPAD5'],
    ['Clear', 'Numpad5', 12, 'NUMPAD5'],
    [',', 'NumpadDecimal', 110, 'DECIMAL'],
    ['F10', 'F10', 121, 'F10'],
    ['Alt', 'AltRight', 18, 'RMENU'],
  ])('maps %s (%s, VK %s) to %s', (key, code, keyCode, expected) => {
    const actual = keyboardMappingFromEvent({
      key,
      code,
      keyCode,
      isComposing: false,
    })
    expect(actual).toBe(expected)
    expect(KEYBOARD_MAPPING_KEYS).toContain(actual)
  })

  it('rejects ambiguous characters, IME composition and unsupported keys', () => {
    for (const key of ['ü', 'Dead', 'Unidentified', 'MediaPlayPause']) {
      expect(
        keyboardMappingFromEvent({
          key,
          code: 'BracketLeft',
          keyCode: 0,
          isComposing: false,
        }),
      ).toBeNull()
    }
    expect(
      keyboardMappingFromEvent({
        key: 'a',
        code: 'KeyA',
        keyCode: 65,
        isComposing: true,
      }),
    ).toBeNull()
  })
})
