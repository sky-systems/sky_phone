export type HousingAccess = 'owner' | 'keyholder'

export type HousingCapabilities = {
  cctv: boolean
  garageStatus: boolean
  keyGrant?: boolean
  keys: boolean
  lock: boolean
  waypoint: boolean
}

export type HousingKey = {
  identifier: string
  name: string
  online: boolean
  revocable?: boolean
}

export type HousingKeyCandidate = {
  id: number
  name: string
}

export type HousingProperty = {
  access: HousingAccess
  capabilities: HousingCapabilities
  cctv: { enabled: boolean }
  entrance?: { x: number; y: number; z: number }
  garage: { enabled: boolean; storedVehicles: number } | null
  id: string
  keys?: HousingKey[]
  locked: boolean
  name: string
  providerId: string
}

export type HousingOverview = {
  available: boolean
  properties: HousingProperty[]
  provider: string | null
}

export type HousingCommand =
  | 'grant_key'
  | 'open_cctv'
  | 'revoke_key'
  | 'set_waypoint'
  | 'toggle_lock'
