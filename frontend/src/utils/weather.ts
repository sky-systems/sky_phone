import type {
  HourlyWeather,
  RawWeatherSnapshot,
  WeatherConditionId,
  WeatherForecast,
  WeatherRegionId,
} from '@/types/weather'

const CONDITIONS: WeatherConditionId[] = [
  'sunny',
  'clear',
  'partly_cloudy',
  'cloudy',
  'rain',
  'thunder',
  'fog',
  'snow',
]

const REGION_BASE_TEMPERATURE: Record<WeatherRegionId, number> = {
  los_santos: 20,
  blaine_county: 17,
  cayo_perico: 26,
}

const CONDITION_TEMPERATURE_OFFSET: Record<WeatherConditionId, number> = {
  sunny: 3,
  clear: 2,
  partly_cloudy: 0,
  cloudy: -2,
  rain: -4,
  thunder: -5,
  fog: -3,
  snow: -16,
}

const RAIN_CHANCE: Record<WeatherConditionId, number> = {
  sunny: 2,
  clear: 4,
  partly_cloudy: 18,
  cloudy: 34,
  rain: 82,
  thunder: 96,
  fog: 24,
  snow: 68,
}

const HUMIDITY: Record<WeatherConditionId, number> = {
  sunny: 38,
  clear: 42,
  partly_cloudy: 52,
  cloudy: 64,
  rain: 82,
  thunder: 88,
  fog: 92,
  snow: 76,
}

function clamp(value: number, minimum: number, maximum: number): number {
  return Math.min(maximum, Math.max(minimum, value))
}

function normalizedCondition(value: string): WeatherConditionId {
  return CONDITIONS.includes(value as WeatherConditionId)
    ? (value as WeatherConditionId)
    : 'clear'
}

function temperatureAt(
  region: WeatherRegionId,
  condition: WeatherConditionId,
  hour: number,
  variation: number,
): number {
  const dayCurve = Math.cos(((hour - 14) / 24) * Math.PI * 2) * 5.5
  return Math.round(
    REGION_BASE_TEMPERATURE[region] +
      CONDITION_TEMPERATURE_OFFSET[condition] +
      dayCurve +
      variation,
  )
}

function snapshotTimestamp(snapshot: RawWeatherSnapshot): number {
  const { year, month, day, hour, minute } = snapshot.clock
  return Date.UTC(year, month - 1, day, hour, minute)
}

export function buildWeatherForecast(
  input: RawWeatherSnapshot,
): WeatherForecast {
  const condition = normalizedCondition(input.condition)
  const nextCondition = normalizedCondition(input.nextCondition)
  const region =
    input.region in REGION_BASE_TEMPERATURE ? input.region : 'los_santos'
  const timestamp = snapshotTimestamp(input)
  const hourly: HourlyWeather[] = []

  for (let index = 0; index < 6; index += 1) {
    const forecastCondition = index === 0 ? condition : nextCondition
    const itemTimestamp = timestamp + index * 3_600_000
    const itemHour = new Date(itemTimestamp).getUTCHours()
    hourly.push({
      condition: forecastCondition,
      rainChance: RAIN_CHANCE[forecastCondition],
      temperature: temperatureAt(region, forecastCondition, itemHour, 0),
      timestamp: itemTimestamp,
    })
  }

  const temperature = temperatureAt(
    region,
    condition,
    input.clock.hour + input.clock.minute / 60,
    0,
  )
  const windSpeed = Math.round(Math.max(0, input.windSpeed) * 3.6)
  const nativeRainChance = clamp(Math.round(input.rainLevel * 100), 0, 100)
  const rainChance = Math.max(RAIN_CHANCE[condition], nativeRainChance)

  return {
    condition,
    feelsLike:
      temperature - Math.round(windSpeed / 18) - (rainChance > 60 ? 1 : 0),
    hourly,
    humidity: clamp(
      HUMIDITY[condition] + Math.round(input.rainLevel * 8),
      0,
      100,
    ),
    rainChance,
    region,
    temperature,
    timestamp,
    windSpeed,
  }
}
