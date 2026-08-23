import type { Component } from 'vue'

export type BuiltinPhoneAppId =
  | 'phone'
  | 'messages'
  | 'darkchat'
  | 'calculator'
  | 'camera'
  | 'clock'
  | 'calendar'
  | 'weather'
  | 'health'
  | 'banking'
  | 'crypto'
  | 'billing'
  | 'garage'
  | 'house'
  | 'mail'
  | 'map'
  | 'notes'
  | 'memos'
  | 'radio'
  | 'music'
  | 'photos'
  | 'app-store'
  | 'settings'
  | 'snake'
  | 'memory'
  | 'number-merge'
  | 'minesweeper'
  | 'tower-stack'
  | 'sky-flappy'
  | 'neon-drop'
  | 'citymarkt'
  | 'local-pages'
  | 'flare'
  | 'fliptok'
  | 'picstagram'
  | 'skyride'
  | 'feather'
  | 'crewlink'
  | 'companies'
  | 'weazel-news'
  | 'citywarn'

declare const externalPhoneAppId: unique symbol

export type ExternalPhoneAppId = string & {
  readonly [externalPhoneAppId]: true
}

export type PhoneAppId = BuiltinPhoneAppId | ExternalPhoneAppId
export type LaunchablePhoneAppId = PhoneAppId

export type PhoneAppCategory =
  | 'games'
  | 'productivity'
  | 'shopping'
  | 'social'
  | 'utilities'

export type AppLaunchOrigin = {
  borderRadius: number
  scaleX: number
  scaleY: number
  x: number
  y: number
}

type PhoneAppDefinitionBase = {
  adminOnly?: boolean
  category: PhoneAppCategory
  dockOrder: number | null
  gridOrder: number
  icon: Component
  iconClass: string
  iconImage: string
}

export type BuiltinPhoneAppDefinition = PhoneAppDefinitionBase & {
  component: Component
  id: BuiltinPhoneAppId
  kind?: 'builtin'
  labelKey: string
  route: `/apps/${BuiltinPhoneAppId}`
}

export type CustomAppBridgeMode = 'legacy' | 'sky'

export type ExternalPhoneAppDefinition = PhoneAppDefinitionBase & {
  bridgeMode: CustomAppBridgeMode
  bundled: boolean
  capabilities: string[]
  compatibility: Record<string, unknown>
  component: null
  defaultInstalled: boolean
  description: string
  developer: string
  iconBackground?: string
  id: ExternalPhoneAppId
  kind: 'external'
  name: string
  orientation: 'landscape' | 'portrait'
  ownerResource: string
  readyTimeoutMs: number
  removable: boolean
  route: `/apps/${ExternalPhoneAppId}`
  ui: string
}

export type PhoneAppDefinition =
  | BuiltinPhoneAppDefinition
  | ExternalPhoneAppDefinition

export type LaunchablePhoneAppDefinition = PhoneAppDefinition

export type CustomAppCatalogPayload = {
  apps: unknown[]
}

export type CustomAppHostMessage = {
  payload: unknown
  sequence: number
}

export type CustomAppOpenRequest = {
  data?: unknown
  sequence: number
}

export type SkyPhoneAppCapability =
  | 'app.close'
  | 'app.open'
  | 'device.storage.get'
  | 'device.storage.set'
  | 'locale.read'
  | 'notification.create'
  | 'theme.read'

export type SkyPhoneAppBridgeMethod =
  | 'app.close'
  | 'app.open'
  | 'device.storage.get'
  | 'device.storage.set'
  | 'notification.create'

export type SkyPhoneAppBridgeRequest = {
  method: string
  payload?: unknown
  requestId: string
}

export type SkyPhoneAppBridgeResponse = {
  data?: unknown
  error?: string
  requestId: string
  success: boolean
}

export type SkyPhoneAppContextV1 = {
  appId: string
  capabilities: SkyPhoneAppCapability[]
  colorScheme?: 'dark' | 'light'
  language?: string
  locale?: Record<string, unknown>
  phoneScale: number
  protocolVersion: 1
  safeArea: {
    bottom: number
    left: number
    right: number
    top: number
  }
}
