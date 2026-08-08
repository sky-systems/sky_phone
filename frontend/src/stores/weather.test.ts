import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useWeatherStore } from '@/stores/weather'
import type { RawWeatherSnapshot } from '@/types/weather'
import { nuiCall } from '@/utils/nui'

vi.mock('@/utils/nui', () => ({ nuiCall: vi.fn() }))

const rawWeather: RawWeatherSnapshot = {
  clock: { day: 5, hour: 17, minute: 20, month: 8, year: 2026 },
  condition: 'sunny',
  nextCondition: 'clear',
  rainLevel: 0,
  region: 'los_santos',
  windSpeed: 2,
}

describe('weather store', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    setActivePinia(createPinia())
  })

  it('loads and normalizes the current GTA weather', async () => {
    vi.mocked(nuiCall).mockResolvedValueOnce({
      data: rawWeather,
      success: true,
    })
    const weather = useWeatherStore()

    await weather.refresh(true)

    expect(nuiCall).toHaveBeenCalledWith('weather:get')
    expect(weather.forecast?.condition).toBe('sunny')
    expect(weather.forecast?.hourly).toHaveLength(6)
    expect(weather.error).toBeNull()
  })

  it('throttles non-forced refreshes', async () => {
    vi.mocked(nuiCall).mockResolvedValue({ data: rawWeather, success: true })
    const weather = useWeatherStore()

    await weather.refresh()
    await weather.refresh()

    expect(nuiCall).toHaveBeenCalledTimes(1)
  })

  it('keeps the last valid forecast when a refresh fails', async () => {
    vi.mocked(nuiCall)
      .mockResolvedValueOnce({ data: rawWeather, success: true })
      .mockResolvedValueOnce({ error: 'offline', success: false })
    const weather = useWeatherStore()

    await weather.refresh(true)
    const previous = weather.forecast
    await weather.refresh(true)

    expect(weather.forecast).toBe(previous)
    expect(weather.error).toBe('offline')
  })
})
