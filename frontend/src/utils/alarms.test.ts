import { describe, expect, it } from 'vitest'

import { alarmMinuteKey, isAlarmDue, type Alarm } from './alarms'

const alarm: Alarm = {
  enabled: true,
  id: 'test',
  lastTriggeredMinute: null,
  note: '',
  sound: 'radar',
  time: '07:30',
  weekdays: [1, 2, 3, 4, 5],
}

describe('alarm scheduling', () => {
  it('fires once in the matching local minute and weekday', () => {
    const monday = new Date(2026, 7, 3, 7, 30)
    expect(isAlarmDue(alarm, monday)).toBe(true)
    expect(
      isAlarmDue(
        { ...alarm, lastTriggeredMinute: alarmMinuteKey(monday) },
        monday,
      ),
    ).toBe(false)
    expect(isAlarmDue(alarm, new Date(2026, 7, 2, 7, 30))).toBe(false)
  })

  it('treats an empty repeat selection as a one-time daily match', () => {
    expect(
      isAlarmDue(
        { ...alarm, time: '09:00', weekdays: [] },
        new Date(2026, 7, 2, 9, 0),
      ),
    ).toBe(true)
  })
})
