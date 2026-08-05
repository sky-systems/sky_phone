import { defineStore } from 'pinia'

import type { RawWeatherSnapshot, WeatherForecast } from '@/types/weather'
import { nuiCall } from '@/utils/nui'
import { buildWeatherForecast } from '@/utils/weather'

const REFRESH_INTERVAL = 30_000

export const useWeatherStore = defineStore('weather', {
  state: () => ({
    error: null as string | null,
    forecast: null as WeatherForecast | null,
    intervalId: undefined as number | undefined,
    isLoading: false,
    lastFetchedAt: 0,
  }),
  actions: {
    async refresh(force = false): Promise<void> {
      if (this.isLoading) return
      if (!force && Date.now() - this.lastFetchedAt < REFRESH_INTERVAL) return
      this.isLoading = true
      const response = await nuiCall<RawWeatherSnapshot>('weather:get')
      this.isLoading = false
      if (!response.success || !response.data) {
        this.error = response.error ?? 'request_failed'
        return
      }
      this.forecast = buildWeatherForecast(response.data)
      this.lastFetchedAt = Date.now()
      this.error = null
    },
    start(): void {
      void this.refresh(true)
      if (this.intervalId !== undefined) return
      this.intervalId = window.setInterval(() => void this.refresh(true), REFRESH_INTERVAL)
    },
    stop(): void {
      if (this.intervalId !== undefined) window.clearInterval(this.intervalId)
      this.intervalId = undefined
    },
  },
})
