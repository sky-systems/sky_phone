export type SimType = 'registered' | 'anonymous'

export type PhoneSim = {
  id: string
  number: string
  registered: boolean
  type: SimType
}

export type PhoneContact = {
  created_at?: string
  id: string
  name: string
  phone_number: string
  updated_at?: string
}

export type CallDirection = 'incoming' | 'outgoing'
export type CallState =
  | 'ringing'
  | 'connected'
  | 'completed'
  | 'missed'
  | 'declined'
  | 'busy'
  | 'unavailable'
  | 'no_answer'
  | 'cancelled'
  | 'disconnected'
  | 'sim_removed'

export type PhoneCall = {
  answeredAt?: number
  channel?: number
  device?: { imei: string; name: string }
  direction: CallDirection
  id: string
  otherNumber: string
  startedAt: number
  state: CallState
}

export type RecentCall = {
  call_id: string
  created_at: string
  direction: CallDirection
  duration_seconds: number
  id: number
  other_number: string
  status: CallState
}
