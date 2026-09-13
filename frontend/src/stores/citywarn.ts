import { defineStore } from 'pinia'

import {
  parseCityWarnColors,
  parseCityWarnMapBlip,
} from '@/utils/citywarnPresentation'
import { usePhoneStore } from '@/stores/phone'
import type {
  CityWarnAlert,
  CityWarnBootstrap,
  CityWarnCategory,
  CityWarnEventData,
  CityWarnPreferences,
  CityWarnPublishInput,
  CityWarnSeverity,
} from '@/types/citywarn'
import { nuiCall, type NuiResponse } from '@/utils/nui'

export const CITYWARN_CATEGORIES: CityWarnCategory[] = [
  'public_safety',
  'police',
  'fire',
  'medical',
  'infrastructure',
  'evacuation',
]

export const CITYWARN_SEVERITIES: CityWarnSeverity[] = [
  'information',
  'warning',
  'danger',
  'extreme',
]

const severityRank: Record<CityWarnSeverity, number> = {
  danger: 2,
  extreme: 3,
  information: 0,
  warning: 1,
}

export const DEFAULT_CITYWARN_PREFERENCES: CityWarnPreferences = {
  categories: Object.fromEntries(
    CITYWARN_CATEGORIES.map((category) => [category, true]),
  ) as Record<CityWarnCategory, boolean>,
  locationAlerts: true,
  minimumSeverity: 'information',
}

function parsePreferences(value: unknown): CityWarnPreferences {
  const candidate =
    value && typeof value === 'object'
      ? (value as Partial<CityWarnPreferences>)
      : {}
  const minimumSeverity = CITYWARN_SEVERITIES.includes(
    candidate.minimumSeverity as CityWarnSeverity,
  )
    ? (candidate.minimumSeverity as CityWarnSeverity)
    : DEFAULT_CITYWARN_PREFERENCES.minimumSeverity

  return {
    categories: Object.fromEntries(
      CITYWARN_CATEGORIES.map((category) => [
        category,
        candidate.categories?.[category] !== false,
      ]),
    ) as Record<CityWarnCategory, boolean>,
    locationAlerts: candidate.locationAlerts !== false,
    minimumSeverity,
  }
}

function acceptsAlert(
  preferences: CityWarnPreferences,
  alert: CityWarnAlert,
): boolean {
  if (!preferences.categories[alert.category]) return false
  if (
    severityRank[alert.severity] < severityRank[preferences.minimumSeverity]
  ) {
    return false
  }
  return preferences.locationAlerts || alert.area.type === 'city'
}

export const useCityWarnStore = defineStore('citywarn', {
  state: () => ({
    active: [] as CityWarnAlert[],
    archive: [] as CityWarnAlert[],
    context: null as CityWarnBootstrap['context'] | null,
    categoryColors: parseCityWarnColors(null),
    mapBlip: parseCityWarnMapBlip(null),
    error: '',
    initialized: false,
    isLoading: false,
    onlinePlayers: 0,
    preferences: parsePreferences(null),
  }),
  getters: {
    visibleActive(state): CityWarnAlert[] {
      return state.active.filter((alert) =>
        acceptsAlert(state.preferences, alert),
      )
    },
  },
  actions: {
    hydratePreferences(): void {
      const phone = usePhoneStore()
      this.preferences = parsePreferences(
        phone.device?.data.citywarn?.payload ?? null,
      )
    },
    savePreferences(): void {
      usePhoneStore().saveDeviceNamespace('citywarn', this.preferences)
    },
    setCategory(category: CityWarnCategory, enabled: boolean): void {
      this.preferences.categories[category] = enabled
      this.savePreferences()
    },
    setLocationAlerts(enabled: boolean): void {
      this.preferences.locationAlerts = enabled
      this.savePreferences()
    },
    setMinimumSeverity(severity: CityWarnSeverity): void {
      this.preferences.minimumSeverity = severity
      this.savePreferences()
    },
    accepts(alert: CityWarnAlert): boolean {
      return acceptsAlert(this.preferences, alert)
    },
    async load(): Promise<boolean> {
      this.isLoading = true
      this.hydratePreferences()
      const response = await nuiCall<CityWarnBootstrap>('citywarn:bootstrap')
      this.isLoading = false
      if (response.success && response.data) {
        this.active = response.data.active
        this.archive = response.data.archive
        this.context = response.data.context
        this.categoryColors = parseCityWarnColors(response.data.categoryColors)
        this.mapBlip = parseCityWarnMapBlip(response.data.mapBlip)
        this.onlinePlayers = response.data.onlinePlayers
        this.error = ''
        this.initialized = true
        return true
      }
      this.error = response.error ?? 'request_failed'
      return false
    },
    async refresh(): Promise<boolean> {
      return this.load()
    },
    applyEvent(data: CityWarnEventData): void {
      if (data.mapBlip) this.mapBlip = parseCityWarnMapBlip(data.mapBlip)
      if (data.categoryColors)
        this.categoryColors = parseCityWarnColors(data.categoryColors)
      const alert = data.alert
      if (!alert) return
      this.active = this.active.filter((item) => item.id !== alert.id)
      this.archive = this.archive.filter((item) => item.id !== alert.id)
      if (alert.status === 'active') this.active.unshift(alert)
      else this.archive.unshift(alert)
    },
    async publish(
      input: CityWarnPublishInput,
    ): Promise<NuiResponse<{ alert: CityWarnAlert; recipients: number }>> {
      const response = await nuiCall<{
        alert: CityWarnAlert
        recipients: number
      }>('citywarn:publish', input)
      if (response.success && response.data) {
        this.applyEvent({ alert: response.data.alert })
        this.error = ''
      } else this.error = response.error ?? 'request_failed'
      return response
    },
    async addUpdate(
      alert: CityWarnAlert,
      message: string,
    ): Promise<NuiResponse<{ alert: CityWarnAlert }>> {
      const response = await nuiCall<{ alert: CityWarnAlert }>(
        'citywarn:update',
        { id: alert.id, message, revision: alert.revision },
      )
      if (response.success && response.data) {
        this.applyEvent({ alert: response.data.alert })
        this.error = ''
      } else this.error = response.error ?? 'request_failed'
      return response
    },
    async resolve(
      alert: CityWarnAlert,
      message: string,
    ): Promise<NuiResponse<{ alert: CityWarnAlert }>> {
      const response = await nuiCall<{ alert: CityWarnAlert }>(
        'citywarn:resolve',
        { id: alert.id, message, revision: alert.revision },
      )
      if (response.success && response.data) {
        this.applyEvent({ alert: response.data.alert })
        this.error = ''
      } else this.error = response.error ?? 'request_failed'
      return response
    },
  },
})
