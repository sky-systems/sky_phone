import { describe, expect, it } from 'vitest'

import type { RawWeatherSnapshot, WeatherRegionId } from '@/types/weather'
import { buildWeatherForecast } from './weather'

function snapshot(
  region: WeatherRegionId = 'los_santos',
): RawWeatherSnapshot {
  return {
    clock: { day: 31, hour: 23, minute: 30, month: 12, year: 2026 },
    condition: 'partly_cloudy',
    rainLevel: 0.1,
    region,
    windSpeed: 4,
  }
}

describe('weather forecast', () => {
  it('builds deterministic 24-hour and seven-day forecasts', () => {
    const first = buildWeatherForecast(snapshot())
    const second = buildWeatherForecast(snapshot())

    expect(first).toEqual(second)
    expect(first.hourly).toHaveLength(24)
    expect(first.daily).toHaveLength(7)
  })

  it('rolls hourly timestamps into the next year', () => {
    const forecast = buildWeatherForecast(snapshot())
    const nextHour = new Date(forecast.hourly[1].timestamp)

    expect(nextHour.getUTCFullYear()).toBe(2027)
    expect(nextHour.getUTCMonth()).toBe(0)
    expect(nextHour.getUTCDate()).toBe(1)
  })

  it('applies a distinct climate to every supported region', () => {
    const losSantos = buildWeatherForecast(snapshot('los_santos'))
    const blaineCounty = buildWeatherForecast(snapshot('blaine_county'))
    const cayoPerico = buildWeatherForecast(snapshot('cayo_perico'))

    expect(cayoPerico.temperature).toBeGreaterThan(losSantos.temperature)
    expect(losSantos.temperature).toBeGreaterThan(blaineCounty.temperature)
  })

  it('keeps native rain and wind values in the current conditions', () => {
    const input = snapshot()
    input.condition = 'rain'
    input.rainLevel = 0.95
    input.windSpeed = 5
    const forecast = buildWeatherForecast(input)

    expect(forecast.rainChance).toBe(95)
    expect(forecast.windSpeed).toBe(18)
    expect(forecast.humidity).toBeGreaterThanOrEqual(82)
  })
})
