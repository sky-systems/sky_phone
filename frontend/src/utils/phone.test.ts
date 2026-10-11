import { describe, expect, it } from 'vitest'

import {
  configurePhoneNumberFormat,
  formatPhoneNumber,
  normalizePhoneNumber,
  PHONE_NUMBER_MAX_LENGTH,
} from './phone'

describe('phone numbers', () => {
  it('normalizes formatted ten digit values', () => {
    expect(normalizePhoneNumber('(555) 123-4567')).toBe('5551234567')
    expect(normalizePhoneNumber('123')).toBe('123')
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
    expect(normalizePhoneNumber('0298822')).toBe('0298822')
    expect(normalizePhoneNumber('0298822123456')).toBe('0298822123456')
    expect(formatPhoneNumber('0298822123456')).toBe('0298 822 123 456')

    configurePhoneNumberFormat()
  })

  it('keeps raw digit strings within the storage limit', () => {
    expect(normalizePhoneNumber('029 8822')).toBe('0298822')
    expect(normalizePhoneNumber('0')).toBe('0')
    expect(normalizePhoneNumber('0'.repeat(PHONE_NUMBER_MAX_LENGTH))).toBe(
      '0'.repeat(PHONE_NUMBER_MAX_LENGTH),
    )
    expect(
      normalizePhoneNumber('0'.repeat(PHONE_NUMBER_MAX_LENGTH + 1)),
    ).toBeNull()
    expect(normalizePhoneNumber('')).toBeNull()
    expect(normalizePhoneNumber('abc')).toBeNull()
  })

  it('formats shorter and longer numbers without losing digits', () => {
    for (const number of ['0', '0298822', '0298822123456', '0'.repeat(24)]) {
      expect(formatPhoneNumber(number).replace(/\D/g, '')).toBe(number)
    }
  })
})
