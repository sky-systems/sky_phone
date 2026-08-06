import type { Component } from 'vue'

export type PhoneAppId =
  | 'phone'
  | 'calculator'
  | 'camera'
  | 'clock'
  | 'weather'
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
