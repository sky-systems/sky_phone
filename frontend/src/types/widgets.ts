export type WidgetKind =
  | 'clock'
  | 'date'
  | 'weather'
  | 'music'
  | 'wallet'
  | 'transactions'
  | 'contacts'

export type WidgetSize = 'small' | 'medium' | 'large'

export type WidgetSettings = {
  balanceSource?: 'bank' | 'cash'
  contactIds?: string[]
  showDate?: boolean
}

export type WidgetInstance = {
  column: number
  id: string
  kind: WidgetKind
  page: number
  row: number
  settings: WidgetSettings
  size: WidgetSize
}

export type WidgetLayout = {
  instances: WidgetInstance[]
  version: 1
}

export type WidgetDefinition = {
  categoryKey: string
  configurable: boolean
  defaultSize: WidgetSize
  descriptionKey: string
  kind: WidgetKind
  labelKey: string
  supportedSizes: WidgetSize[]
}
