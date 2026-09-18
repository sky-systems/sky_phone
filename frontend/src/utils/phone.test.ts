import { describe, expect, it } from 'vitest'

import {
  configurePhoneNumberFormat,
  formatPhoneNumber,
  normalizePhoneNumber,
} from './phone'

describe('phone numbers', () => {
  it('normalizes formatted ten digit values', () => {
    expect(normalizePhoneNumber('(555) 123-4567')).toBe('5551234567')
    expect(normalizePhoneNumber('123')).toBeNull()
  })

  it('formats keypad input incrementally', () => {
    expect(formatPhoneNumber('5551234567')).toBe('555 123 4567')
    expect(formatPhoneNumber('5551')).toBe('555 1')
    expect(formatPhoneNumber(5551234567)).toBe('555 123 4567')
  })

  it('uses the server-provided number length and display groups', () => {
    configurePhoneNumberFormat({ groups: [4, 3, 3], length: 10 })

    expect(formatPhoneNumber('0171234567')).toBe('0171 234 567')
    expect(normalizePhoneNumber('0171 234 567')).toBe('0171234567')

    configurePhoneNumberFormat()
  })
})
