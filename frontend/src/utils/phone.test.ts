import { describe, expect, it } from 'vitest'

import { formatPhoneNumber, normalizePhoneNumber } from './phone'

describe('phone numbers', () => {
  it('normalizes formatted ten digit values', () => {
    expect(normalizePhoneNumber('(555) 123-4567')).toBe('5551234567')
    expect(normalizePhoneNumber('123')).toBeNull()
  })

  it('formats keypad input incrementally', () => {
    expect(formatPhoneNumber('5551234567')).toBe('555 123 4567')
    expect(formatPhoneNumber('5551')).toBe('555 1')
  })
})
