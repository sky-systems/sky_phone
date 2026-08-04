export const ALARM_SOUND_IDS = [
  'radar',
  'beacon',
  'chimes',
  'apex',
  'aurora',
  'circuit',
  'constellation',
  'daybreak',
  'uplift',
] as const
export const WEEKDAY_IDS = [1, 2, 3, 4, 5, 6, 0] as const

export type AlarmSoundId = (typeof ALARM_SOUND_IDS)[number]

export type Alarm = {
  enabled: boolean
  id: string
  lastTriggeredMinute: string | null
  note: string
  sound: AlarmSoundId
  time: string
  weekdays: number[]
}

export type AlarmDraft = Pick<Alarm, 'note' | 'sound' | 'time' | 'weekdays'>

export const DEFAULT_ALARMS: Alarm[] = [
  {
    enabled: true,
    id: 'weekday',
    lastTriggeredMinute: null,
    note: '',
    sound: 'radar',
    time: '07:30',
    weekdays: [1, 2, 3, 4, 5],
  },
  {
    enabled: false,
    id: 'weekend',
    lastTriggeredMinute: null,
    note: '',
    sound: 'chimes',
    time: '09:00',
    weekdays: [0, 6],
  },
]

function isAlarmSound(value: unknown): value is AlarmSoundId {
  return (
    typeof value === 'string' && ALARM_SOUND_IDS.includes(value as AlarmSoundId)
  )
}

function readAlarm(value: unknown): Alarm | null {
  if (!value || typeof value !== 'object') return null
  const alarm = value as Partial<Alarm>
  if (
    typeof alarm.id !== 'string' ||
    typeof alarm.enabled !== 'boolean' ||
    typeof alarm.time !== 'string' ||
    !/^([01]\d|2[0-3]):[0-5]\d$/.test(alarm.time) ||
    typeof alarm.note !== 'string' ||
    !isAlarmSound(alarm.sound) ||
    !Array.isArray(alarm.weekdays)
  ) {
    return null
  }

  return {
    enabled: alarm.enabled,
    id: alarm.id,
    lastTriggeredMinute:
      typeof alarm.lastTriggeredMinute === 'string'
        ? alarm.lastTriggeredMinute
        : null,
    note: alarm.note.slice(0, 80),
    sound: alarm.sound,
    time: alarm.time,
    weekdays: [
      ...new Set(
        alarm.weekdays.filter(
          (weekday): weekday is number =>
            Number.isInteger(weekday) && weekday >= 0 && weekday <= 6,
        ),
      ),
    ],
  }
}

export function parseAlarms(value: unknown): Alarm[] {
  if (!Array.isArray(value)) return structuredClone(DEFAULT_ALARMS)
  return value.map(readAlarm).filter((alarm): alarm is Alarm => !!alarm)
}

export function alarmMinuteKey(date: Date): string {
  return [
    date.getFullYear(),
    String(date.getMonth() + 1).padStart(2, '0'),
    String(date.getDate()).padStart(2, '0'),
    String(date.getHours()).padStart(2, '0'),
    String(date.getMinutes()).padStart(2, '0'),
  ].join('-')
}

export function isAlarmDue(alarm: Alarm, date: Date): boolean {
  if (!alarm.enabled) return false
  const currentTime = `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`
  if (alarm.time !== currentTime) return false
  if (alarm.weekdays.length && !alarm.weekdays.includes(date.getDay())) {
    return false
  }
  return alarm.lastTriggeredMinute !== alarmMinuteKey(date)
}
