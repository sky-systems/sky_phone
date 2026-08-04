import { describe, expect, it } from 'vitest'
import {
  elapsedMilliseconds,
  formatStopwatch,
  formatTimer,
  remainingMilliseconds,
  timerProgressRatio,
  timerPickerMilliseconds,
  timerPickerValue,
} from './clock'
describe('timestamp clocks', () => {
  it('derives elapsed and remaining time without an interval state', () => {
    expect(elapsedMilliseconds(500, 1000, 2500)).toBe(2000)
    expect(remainingMilliseconds(5000, 1000, 2500)).toBe(3500)
    expect(remainingMilliseconds(100, 1000, 2500)).toBe(0)
  })

  it('formats and parses timer durations with hours, minutes, and seconds', () => {
    expect(formatTimer(3_661_000)).toBe('01:01:01')
    expect(timerPickerValue(3_661_000)).toBe('01:01:01')
    expect(timerPickerMilliseconds('01:01:01')).toBe(3_661_000)
  })

  it('formats stopwatch durations with hundredths of a second', () => {
    expect(formatStopwatch(61_234)).toBe('01:01.23')
  })

  it('calculates bounded timer progress from remaining duration', () => {
    expect(timerProgressRatio(7_500, 10_000)).toBe(0.75)
    expect(timerProgressRatio(-1, 10_000)).toBe(0)
    expect(timerProgressRatio(12_000, 10_000)).toBe(1)
    expect(timerProgressRatio(0, 0)).toBe(0)
  })
})
