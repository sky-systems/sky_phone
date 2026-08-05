export type WeatherConditionId =
  | 'sunny'
  | 'clear'
  | 'partly_cloudy'
  | 'cloudy'
  | 'rain'
  | 'thunder'
  | 'fog'
  | 'snow'

export type WeatherRegionId =
  | 'los_santos'
  | 'blaine_county'
  | 'cayo_perico'

export type WeatherClock = {
  day: number
  hour: number
  minute: number
  month: number
  year: number
}

export type RawWeatherSnapshot = {
  clock: WeatherClock
  condition: WeatherConditionId
  rainLevel: number
  region: WeatherRegionId
  windSpeed: number
}

export type HourlyWeather = {
  condition: WeatherConditionId
  rainChance: number
  temperature: number
  timestamp: number
}

export type DailyWeather = {
  condition: WeatherConditionId
  high: number
  low: number
  rainChance: number
  timestamp: number
}

export type WeatherForecast = {
  condition: WeatherConditionId
  daily: DailyWeather[]
  feelsLike: number
  hourly: HourlyWeather[]
  humidity: number
  rainChance: number
  region: WeatherRegionId
  temperature: number
  timestamp: number
  windSpeed: number
}
