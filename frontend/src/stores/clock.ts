import { defineStore } from 'pinia'

import {
  alarmMinuteKey,
  type Alarm,
  type AlarmDraft,
  type AlarmSoundId,
  isAlarmDue,
  readAlarms,
  writeAlarms,
} from '@/utils/alarms'
import { elapsedMilliseconds, remainingMilliseconds } from '@/utils/clock'

export const useClockStore = defineStore('clock', {
  state: () => ({
    alarms: readAlarms(),
    laps: [] as number[],
    stopwatchAccumulated: 0,
    stopwatchStartedAt: null as number | null,
    timerDuration: 5 * 60 * 1000,
    timerNote: '',
    timerRemainingAtStart: 5 * 60 * 1000,
    timerSound: 'radar' as AlarmSoundId,
    timerStartedAt: null as number | null,
  }),
  actions: {
    createAlarm(draft: AlarmDraft): Alarm {
      const alarm: Alarm = {
        ...structuredClone(draft),
        enabled: true,
        id: `alarm-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`,
        lastTriggeredMinute: null,
      }
      this.alarms.push(alarm)
      this.persistAlarms()
      return alarm
    },
    deleteAlarm(id: string): void {
      this.alarms = this.alarms.filter((alarm) => alarm.id !== id)
      this.persistAlarms()
    },
    dueAlarms(now: number): Alarm[] {
      const date = new Date(now)
      const due = this.alarms.filter((alarm) => isAlarmDue(alarm, date))
      if (!due.length) return due

      const minuteKey = alarmMinuteKey(date)
      for (const alarm of due) {
        alarm.lastTriggeredMinute = minuteKey
        if (!alarm.weekdays.length) alarm.enabled = false
      }
      this.persistAlarms()
      return due
    },
    addLap(now: number): void {
      if (this.stopwatchStartedAt === null) return
      this.laps.unshift(
        elapsedMilliseconds(
          this.stopwatchAccumulated,
          this.stopwatchStartedAt,
          now,
        ),
      )
    },
    pauseStopwatch(now: number): void {
      if (this.stopwatchStartedAt === null) return
      this.stopwatchAccumulated = elapsedMilliseconds(
        this.stopwatchAccumulated,
        this.stopwatchStartedAt,
        now,
      )
      this.stopwatchStartedAt = null
    },
    pauseTimer(now: number): void {
      if (this.timerStartedAt === null) return
      this.timerRemainingAtStart = remainingMilliseconds(
        this.timerRemainingAtStart,
        this.timerStartedAt,
        now,
      )
      this.timerStartedAt = null
    },
    persistAlarms(): void {
      writeAlarms(this.alarms)
    },
    resetStopwatch(): void {
      this.stopwatchAccumulated = 0
      this.stopwatchStartedAt = null
      this.laps = []
    },
    resetTimer(): void {
      this.timerRemainingAtStart = this.timerDuration
      this.timerStartedAt = null
    },
    setTimerDuration(milliseconds: number): void {
      this.timerDuration = Math.max(
        0,
        Math.min(24 * 60 * 60 * 1000 - 1000, milliseconds),
      )
      this.resetTimer()
    },
    setTimerNote(note: string): void {
      this.timerNote = note
    },
    setTimerSound(sound: AlarmSoundId): void {
      this.timerSound = sound
    },
    startStopwatch(now: number): void {
      if (this.stopwatchStartedAt !== null) return
      this.stopwatchStartedAt = now
    },
    startTimer(now: number): void {
      if (this.timerStartedAt !== null || this.timerRemainingAtStart <= 0)
        return
      this.timerStartedAt = now
    },
    consumeDueTimer(now: number): { note: string; sound: AlarmSoundId } | null {
      if (
        this.timerStartedAt === null ||
        remainingMilliseconds(
          this.timerRemainingAtStart,
          this.timerStartedAt,
          now,
        ) > 0
      ) {
        return null
      }

      this.timerRemainingAtStart = 0
      this.timerStartedAt = null
      return { note: this.timerNote, sound: this.timerSound }
    },
    toggleAlarm(id: string): void {
      const alarm = this.alarms.find((candidate) => candidate.id === id)
      if (!alarm) return
      alarm.enabled = !alarm.enabled
      alarm.lastTriggeredMinute = null
      this.persistAlarms()
    },
    updateAlarm(id: string, draft: AlarmDraft): void {
      const alarm = this.alarms.find((candidate) => candidate.id === id)
      if (!alarm) return
      Object.assign(alarm, structuredClone(draft), {
        lastTriggeredMinute: null,
      })
      this.persistAlarms()
    },
  },
})
