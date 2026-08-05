import type {
  DailyWeather,
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

const TRANSITIONS: Record<WeatherConditionId, WeatherConditionId[]> = {
  sunny: ['sunny', 'sunny', 'clear', 'partly_cloudy'],
  clear: ['clear', 'sunny', 'partly_cloudy', 'cloudy'],
  partly_cloudy: ['partly_cloudy', 'clear', 'cloudy', 'rain'],
  cloudy: ['cloudy', 'partly_cloudy', 'rain', 'fog'],
  rain: ['rain', 'cloudy', 'partly_cloudy', 'thunder'],
  thunder: ['rain', 'cloudy', 'thunder', 'partly_cloudy'],
  fog: ['fog', 'cloudy', 'partly_cloudy', 'clear'],
  snow: ['snow', 'cloudy', 'snow', 'partly_cloudy'],
}

function clamp(value: number, minimum: number, maximum: number): number {
  return Math.min(maximum, Math.max(minimum, value))
}

function seedFrom(value: string): number {
  let hash = 2166136261
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index)
    hash = Math.imul(hash, 16777619)
  }
  return hash >>> 0
}

function random(seed: number): number {
  let value = seed + 0x6d2b79f5
  value = Math.imul(value ^ (value >>> 15), value | 1)
  value ^= value + Math.imul(value ^ (value >>> 7), value | 61)
  return ((value ^ (value >>> 14)) >>> 0) / 4294967296
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

function nextCondition(
  condition: WeatherConditionId,
  seed: number,
): WeatherConditionId {
  const choices = TRANSITIONS[condition]
  return choices[Math.floor(random(seed) * choices.length)] ?? condition
}

function snapshotTimestamp(snapshot: RawWeatherSnapshot): number {
  const { year, month, day, hour, minute } = snapshot.clock
  return Date.UTC(year, month - 1, day, hour, minute)
}

export function buildWeatherForecast(
  input: RawWeatherSnapshot,
): WeatherForecast {
  const condition = normalizedCondition(input.condition)
  const region = input.region in REGION_BASE_TEMPERATURE
    ? input.region
    : 'los_santos'
  const timestamp = snapshotTimestamp(input)
  const hourSeed = seedFrom(`${region}:${timestamp}:${condition}`)
  const hourly: HourlyWeather[] = []
  let forecastCondition = condition

  for (let index = 0; index < 24; index += 1) {
    if (index > 0 && index % 3 === 0) {
      forecastCondition = nextCondition(forecastCondition, hourSeed + index)
    }
    const itemTimestamp = timestamp + index * 3_600_000
    const itemHour = new Date(itemTimestamp).getUTCHours()
    hourly.push({
      condition: forecastCondition,
      rainChance: clamp(
        RAIN_CHANCE[forecastCondition] + Math.round(random(hourSeed + index) * 12 - 6),
        0,
        100,
      ),
      temperature: temperatureAt(
        region,
        forecastCondition,
        itemHour,
        random(hourSeed + index + 100) * 3 - 1.5,
      ),
      timestamp: itemTimestamp,
    })
  }

  const daily: DailyWeather[] = []
  let dailyCondition = condition
  for (let index = 0; index < 7; index += 1) {
    if (index > 0) dailyCondition = nextCondition(dailyCondition, hourSeed + index * 97)
    const itemTimestamp = timestamp + index * 86_400_000
    const variation = random(hourSeed + index * 31) * 4 - 2
    daily.push({
      condition: dailyCondition,
      high: temperatureAt(region, dailyCondition, 14, variation),
      low: temperatureAt(region, dailyCondition, 4, variation - 1),
      rainChance: clamp(
        RAIN_CHANCE[dailyCondition] + Math.round(random(hourSeed + index * 43) * 10 - 5),
        0,
        100,
      ),
      timestamp: itemTimestamp,
    })
  }

  const currentVariation = random(hourSeed) * 2 - 1
  const temperature = temperatureAt(
    region,
    condition,
    input.clock.hour + input.clock.minute / 60,
    currentVariation,
  )
  const windSpeed = Math.round(Math.max(0, input.windSpeed) * 3.6)
  const nativeRainChance = clamp(Math.round(input.rainLevel * 100), 0, 100)
  const rainChance = Math.max(RAIN_CHANCE[condition], nativeRainChance)

  return {
    condition,
    daily,
    feelsLike: temperature - Math.round(windSpeed / 18) - (rainChance > 60 ? 1 : 0),
    hourly,
    humidity: clamp(HUMIDITY[condition] + Math.round(input.rainLevel * 8), 0, 100),
    rainChance,
    region,
    temperature,
    timestamp,
    windSpeed,
  }
}
