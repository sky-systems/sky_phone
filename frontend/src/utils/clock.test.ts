import { describe, expect, it } from 'vitest'
import { elapsedMilliseconds, remainingMilliseconds } from './clock'
describe('timestamp clocks', () => {
  it('derives elapsed and remaining time without an interval state', () => {
    expect(elapsedMilliseconds(500, 1000, 2500)).toBe(2000)
    expect(remainingMilliseconds(5000, 1000, 2500)).toBe(3500)
    expect(remainingMilliseconds(100, 1000, 2500)).toBe(0)
  })
})
