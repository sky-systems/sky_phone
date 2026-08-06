export type RadioHistoryEntry = {
  primary: number
  secondary: number
}

export type RadioMember = {
  id: number
  joinTime: number
  name: string
  rank: string
  rankNumber: number
}

export type RadioSettings = {
  autoRejoin: boolean
  notifications: boolean
}

export type RadioData = {
  badge: string
  badgeEnabled: boolean
  badgeMaxLength: number
  connected: boolean
  displayName: string
  displayNameAllowed: boolean
  displayNameEnabled: boolean
  displayNameMaxLength: number
  frequency: number
  frequencyMax: number
  frequencyMin: number
  frequencyStep: number
  history: RadioHistoryEntry[]
  members: RadioMember[]
  provider: string | null
  secondaryFrequency: number
  secondarySupported: boolean
  settings: RadioSettings
  volume: number
}
