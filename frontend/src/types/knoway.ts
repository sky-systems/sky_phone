export type KnowayCoordinates = { x: number; y: number; z: number }

export type KnowayLocation = {
  coords: KnowayCoordinates
  label: string
}

export type KnowayRefundPolicy = {
  beforeStart: boolean
  afterStart: boolean
  technical: boolean
}

export type KnowayRideStatus =
  | 'approaching'
  | 'waiting'
  | 'driving'
  | 'stopping'
  | 'arrived'
  | 'cancelled'
  | 'failed'

export type KnowayQuote = {
  id: string
  expiresAt: number
  pickup: KnowayLocation
  destination: KnowayLocation
  price: number
  currency: string
  distanceMeters: number
  durationSeconds: number
  refundPolicy: KnowayRefundPolicy
}

export type KnowayRide = Omit<KnowayQuote, 'expiresAt'> & {
  status: KnowayRideStatus
  vehicle: {
    model: string
    plate: string
    netId: number
    driverNetId: number
  }
  createdAt: number
  expiresAt?: number
  position?: KnowayCoordinates
  reason?: string
  refundStatus?: string
}

export type KnowayState = {
  activeRide: KnowayRide | null
  available: boolean
  currency: string
  refundPolicy: KnowayRefundPolicy
}

export type KnowayStateUpdate = Partial<KnowayState>

export function isKnowayRideTerminal(status: KnowayRideStatus): boolean {
  return status === 'arrived' || status === 'cancelled' || status === 'failed'
}
