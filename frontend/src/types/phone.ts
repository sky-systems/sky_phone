export type SimType = 'registered' | 'anonymous'

export type PhoneSim = {
  id: string
  number: string
  removable: boolean
  registered: boolean
  type: SimType
}

export type PhoneContact = {
  avatar_media_id?: number | null
  avatar_url?: string | null
  canCall?: boolean
  canMessage?: boolean
  companyId?: string
  created_at?: string
  email?: string | null
  favorite?: boolean | number
  id: string
  name: string
  notes?: string | null
  organization?: string | null
  phone_number: string
  readonly?: boolean
  source?: 'personal' | 'company'
  updated_at?: string
  verified?: boolean
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
  muted?: boolean
  muteSupported?: boolean
  otherNumber: string
  speakerEnabled?: boolean
  speakerSupported?: boolean
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
