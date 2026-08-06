import type { Component } from 'vue'

export type PhoneAppId =
  | 'phone'
  | 'calculator'
  | 'camera'
  | 'clock'
  | 'calendar'
  | 'weather'
  | 'banking'
  | 'mail'
  | 'map'
  | 'notes'
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

export type LaunchablePhoneAppId = PhoneAppId

export type AppLaunchOrigin = {
  borderRadius: number
  scaleX: number
  scaleY: number
  x: number
  y: number
}

export type PhoneAppDefinition = {
  component: Component | null
  dockOrder: number | null
  gridOrder: number
  icon: Component
  iconClass: string
  iconImage: string
  id: PhoneAppId
  labelKey: string
  route: `/apps/${LaunchablePhoneAppId}` | null
}

export type LaunchablePhoneAppDefinition = PhoneAppDefinition & {
  component: Component
  id: LaunchablePhoneAppId
  route: `/apps/${LaunchablePhoneAppId}`
}
