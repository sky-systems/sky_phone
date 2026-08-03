import type { Component } from 'vue'

export type PhoneAppId =
  | 'calculator'
  | 'camera'
  | 'clock'
  | 'photos'
  | 'app-store'
  | 'settings'

export type AppLaunchOrigin = {
  height: number
  scaleX: number
  scaleY: number
  width: number
  x: number
  y: number
}

export type PhoneAppDefinition = {
  component: Component
  dockOrder: number | null
  gridOrder: number
  icon: Component
  iconClass: string
  id: PhoneAppId
  labelKey: string
  route: `/apps/${PhoneAppId}`
}
