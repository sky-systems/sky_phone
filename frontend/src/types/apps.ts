import type { Component } from 'vue'

export type PhoneAppId =
  | 'calculator'
  | 'camera'
  | 'clock'
  | 'mail'
  | 'map'
  | 'notes'
  | 'photos'
  | 'app-store'
  | 'settings'

export type AppLaunchOrigin = {
  borderRadius: number
  scaleX: number
  scaleY: number
  x: number
  y: number
}

export type PhoneAppDefinition = {
  component: Component
  dockOrder: number | null
  gridOrder: number
  icon: Component
  iconClass: string
  iconImage: string
  id: PhoneAppId
  labelKey: string
  route: `/apps/${PhoneAppId}`
}
