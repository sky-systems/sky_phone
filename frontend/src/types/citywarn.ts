export type CityWarnCategory =
  | 'public_safety'
  | 'police'
  | 'fire'
  | 'medical'
  | 'infrastructure'
  | 'evacuation'

export type CityWarnSeverity = 'information' | 'warning' | 'danger' | 'extreme'

export type CityWarnStatus = 'active' | 'resolved' | 'expired'
export type CityWarnAreaType = 'radius' | 'district' | 'city'
export type CityWarnUpdateKind = 'published' | 'update' | 'resolved'

export type CityWarnArea = {
  centerX: number | null
  centerY: number | null
  label: string
  radius: number | null
  type: CityWarnAreaType
}

export type CityWarnUpdate = {
  actorName: string
  createdAt: number
  id: string
  kind: CityWarnUpdateKind
  message: string
}

export type CityWarnAlert = {
  area: CityWarnArea
  authorName: string
  body: string
  category: CityWarnCategory
  createdAt: number
  expiresAt: number
  id: string
  instructions: string
  revision: number
  severity: CityWarnSeverity
  sourceLabel: string
  startsAt: number
  status: CityWarnStatus
  title: string
  updatedAt: number
  updates: CityWarnUpdate[]
}

export type CityWarnPublisherContext = {
  allowedCategories: CityWarnCategory[]
  canCityWide: boolean
  canPublish: boolean
  gradeLabel: string | null
  jobLabel: string | null
  maximumSeverity: CityWarnSeverity | null
  onDuty: boolean
  requiresDuty: boolean
}

export type CityWarnBootstrap = {
  categoryColors?: Partial<Record<CityWarnCategory, string>>
  active: CityWarnAlert[]
  archive: CityWarnAlert[]
  context: CityWarnPublisherContext
  onlinePlayers: number
}

export type CityWarnPreferences = {
  categories: Record<CityWarnCategory, boolean>
  locationAlerts: boolean
  minimumSeverity: CityWarnSeverity
}

export type CityWarnPublishInput = {
  area: CityWarnArea
  body: string
  category: CityWarnCategory
  durationMinutes: number
  instructions: string
  severity: CityWarnSeverity
  title: string
}

export type CityWarnEventData = {
  categoryColors?: Partial<Record<CityWarnCategory, string>>
  alert?: CityWarnAlert
  alertId?: string
  kind?: CityWarnUpdateKind
  severity?: CityWarnSeverity
  sourceLabel?: string
  text?: string
  title?: string
}
