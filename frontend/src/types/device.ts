import type { Note } from '@/utils/notes'
import type { PhoneSim } from '@/types/phone'

export type DeviceDataEntry<T = unknown> = {
  payload: T
  revision: number
}

export type PhoneDevice = {
  data: Record<string, DeviceDataEntry | undefined>
  imei: string
  name: string
  sim: PhoneSim | null
}

export type PhoneNotificationDevicePayload = {
  imei: string
  name: string
  settings?: string | null
}

export type DeviceSecurity = {
  enabled: boolean
  length: 4 | 6 | null
  lockedUntil: number
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
  security: DeviceSecurity
  token: string
}
