import { describe, expect, it } from 'vitest'
import {
  elapsedMilliseconds,
  formatStopwatch,
  formatTimer,
  remainingMilliseconds,
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

  it('formats stopwatch durations with actual milliseconds', () => {
    expect(formatStopwatch(61_234)).toBe('01:01.234')
  })
})
