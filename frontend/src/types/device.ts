import type { Note } from '@/utils/notes'

export type DeviceDataEntry<T = unknown> = {
  payload: T
  revision: number
}

export type PhoneDevice = {
  data: Record<string, DeviceDataEntry | undefined>
  imei: string
  name: string
}

export type AccountDevice = {
  created_at: string
  current: boolean
  device_name: string
  imei: string
  updated_at: string
}

export type IfruitAccount = {
  devices: AccountDevice[]
  email: string
  id?: number
}

export type DeviceBootstrap = {
  account: IfruitAccount | null
  device: PhoneDevice
  notes: Note[]
  token: string
}
