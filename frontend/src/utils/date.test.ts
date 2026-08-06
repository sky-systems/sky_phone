import { describe, expect, it } from 'vitest'

import { parseDatabaseDate } from './date'

describe('database dates', () => {
  it('parses SQL date strings', () => {
    expect(parseDatabaseDate('2026-08-06 17:30:00').getTime()).toBe(
      new Date('2026-08-06T17:30:00').getTime(),
    )
  })

  it('parses Unix timestamps in seconds and milliseconds', () => {
    expect(parseDatabaseDate(1_786_034_600).getTime()).toBe(1_786_034_600_000)
    expect(parseDatabaseDate(1_786_034_600_000).getTime()).toBe(
      1_786_034_600_000,
    )
  })
})
