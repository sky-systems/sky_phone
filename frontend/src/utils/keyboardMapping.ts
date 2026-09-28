// Cfx KEYBOARD mapper IDs, not GTA control indices. See docs/phone-configurator.md.
const CODE_KEYS: Record<string, string> = {
  Backspace: 'BACK',
  Tab: 'TAB',
  Enter: 'RETURN',
  Pause: 'PAUSE',
  CapsLock: 'CAPITAL',
  Escape: 'ESCAPE',
  Space: 'SPACE',
  PageUp: 'PAGEUP',
  PageDown: 'PAGEDOWN',
  End: 'END',
  Home: 'HOME',
  ArrowLeft: 'LEFT',
  ArrowUp: 'UP',
  ArrowRight: 'RIGHT',
  ArrowDown: 'DOWN',
  PrintScreen: 'SYSRQ',
  Insert: 'INSERT',
  Delete: 'DELETE',
  MetaLeft: 'LWIN',
  MetaRight: 'RWIN',
  ContextMenu: 'APPS',
  NumpadMultiply: 'MULTIPLY',
  NumpadAdd: 'ADD',
  NumpadSubtract: 'SUBTRACT',
  NumpadDecimal: 'DECIMAL',
  NumpadDivide: 'DIVIDE',
  NumpadEqual: 'NUMPADEQUALS',
  NumpadEnter: 'NUMPADENTER',
  NumLock: 'NUMLOCK',
  ScrollLock: 'SCROLL',
  ShiftLeft: 'LSHIFT',
  ShiftRight: 'RSHIFT',
  ControlLeft: 'LCONTROL',
  ControlRight: 'RCONTROL',
  AltLeft: 'LMENU',
  AltRight: 'RMENU',
}

const CHARACTER_KEYS: Record<string, string> = {
  ';': 'SEMICOLON',
  '=': 'EQUALS',
  '+': 'PLUS',
  ',': 'COMMA',
  '-': 'MINUS',
  '.': 'PERIOD',
  '/': 'SLASH',
  '`': 'GRAVE',
  '[': 'LBRACKET',
  '\\': 'BACKSLASH',
  ']': 'RBRACKET',
  "'": 'APOSTROPHE',
}

// CEF supplies Windows virtual-key codes on raw keydown. OEM keys depend on the
// active Windows layout: e.g. German Ü has VK_OEM_1 (186), despite code=BracketLeft.
// Never infer OEM IDs from event.code's US position or the displayed character.
const OEM_VIRTUAL_KEYS: Record<number, string> = {
  186: 'OEM_1',
  187: 'EQUALS',
  188: 'COMMA',
  189: 'MINUS',
  190: 'PERIOD',
  191: 'OEM_2',
  192: 'OEM_3',
  219: 'OEM_4',
  220: 'OEM_5',
  221: 'OEM_6',
  222: 'OEM_7',
  226: 'OEM_102',
}

export const KEYBOARD_MAPPING_KEYS = [
  ...Array.from({ length: 24 }, (_, index) => `F${index + 1}`),
  ...'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
  ...Array.from({ length: 10 }, (_, index) => `NUMPAD${index}`),
  ...Object.values(CODE_KEYS),
  ...Object.values(CHARACTER_KEYS),
  'PRIOR',
  'NEXT',
  'SNAPSHOT',
  'OEM_1',
  'OEM_2',
  'OEM_3',
  'OEM_4',
  'OEM_5',
  'OEM_6',
  'OEM_7',
  'OEM_102',
  'RAGE_EXTRA1',
  'RAGE_EXTRA2',
  'RAGE_EXTRA3',
  'RAGE_EXTRA4',
  'CHATPAD_GREEN_SHIFT',
  'CHATPAD_ORANGE_SHIFT',
]

export function keyboardMappingFromEvent(
  event: Pick<KeyboardEvent, 'code' | 'key' | 'keyCode' | 'isComposing'>,
): string | null {
  if (event.isComposing || event.key === 'Unidentified') return null
  if (/^Numpad[0-9]$/.test(event.code)) return event.code.toUpperCase()
  if (CODE_KEYS[event.code]) return CODE_KEYS[event.code]!
  if (OEM_VIRTUAL_KEYS[event.keyCode]) return OEM_VIRTUAL_KEYS[event.keyCode]!
  if (
    (event.keyCode >= 48 && event.keyCode <= 57) ||
    (event.keyCode >= 65 && event.keyCode <= 90)
  )
    return String.fromCharCode(event.keyCode)
  // Use the typed letter, so Z/Y follow the user's layout, not US physical positions.
  if (/^[a-z0-9]$/i.test(event.key)) return event.key.toUpperCase()
  if (/^F(?:[1-9]|1[0-9]|2[0-4])$/.test(event.key)) return event.key
  return null
}
