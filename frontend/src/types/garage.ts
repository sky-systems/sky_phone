export type GarageVehicleStatus = 'garaged' | 'out' | 'impounded'
export type GarageVehicleKind = 'car' | 'bike' | 'boat' | 'plane' | 'helicopter'
export type GarageValetStatus =
  | 'ordering'
  | 'preparing'
  | 'en_route'
  | 'arriving'
  | 'delivered'
  | 'cancelled'
  | 'failed'

export type GarageVehicle = {
  body: number | null
  engine: number | null
  fuel: number | null
  id: string
  kind: GarageVehicleKind
  location: string
  model: number | string | null
  name?: string
  nickname: string
  plate: string
  status: GarageVehicleStatus
  vin: string
}

export type GarageValetConfig = {
  account: string
  enabled: boolean
  price: number
  vehicleTypes: Record<GarageVehicleKind, boolean>
}

export type GarageValetState = {
  canCancel: boolean
  cost: number
  distance: number | null
  etaSeconds: number | null
  orderId: string
  plate: string
  status: GarageValetStatus
  vehicleName: string
}

export type GarageOverview = {
  system: string
  valet: GarageValetConfig
  vehicles: GarageVehicle[]
}
