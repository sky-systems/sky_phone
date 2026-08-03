import { defineStore } from 'pinia'

import { elapsedMilliseconds, remainingMilliseconds } from '@/utils/clock'

export const useClockStore = defineStore('clock', {
  state: () => ({
    alarms: [
      {
        enabled: true,
        id: 'weekday',
        labelKey: 'Apps.clock.alarm.weekday',
        time: '07:30',
      },
      {
        enabled: false,
        id: 'weekend',
        labelKey: 'Apps.clock.alarm.weekend',
        time: '09:00',
      },
    ],
    laps: [] as number[],
    stopwatchAccumulated: 0,
    stopwatchStartedAt: null as number | null,
    timerDuration: 5 * 60 * 1000,
    timerRemainingAtStart: 5 * 60 * 1000,
    timerStartedAt: null as number | null,
  }),
  actions: {
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
    resetStopwatch(): void {
      this.stopwatchAccumulated = 0
      this.stopwatchStartedAt = null
      this.laps = []
    },
    resetTimer(): void {
      this.timerRemainingAtStart = this.timerDuration
      this.timerStartedAt = null
    },
    setTimerMinutes(minutes: number): void {
      this.timerDuration =
        Math.max(1, Math.min(60, Math.round(minutes))) * 60 * 1000
      this.resetTimer()
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
    toggleAlarm(id: string): void {
      const alarm = this.alarms.find((candidate) => candidate.id === id)
      if (alarm) alarm.enabled = !alarm.enabled
    },
  },
})
