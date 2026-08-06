export type SmsDirection = 'sent' | 'received'
export type SmsAttachmentType = 'image' | 'gif' | 'video'
export type SmsMessageType = 'text' | 'voice' | SmsAttachmentType
export type SmsDeliveryStatus = 'sending' | 'delivered' | 'failed'

export type SmsConversation = {
  lastMessage: string
  lastMessageAt: string
  lastMessageType: SmsMessageType
  phoneNumber: string
  unread: number
}

export type SmsMessage = {
  body: string
  client_id?: string
  created_at: string
  delivery_status?: SmsDeliveryStatus
  direction: SmsDirection
  id: string
  media_asset_id: string | null
  media_duration_ms: number | null
  media_mime: string | null
  media_waveform: number[] | null
  message_type: SmsMessageType
  read_at: string | null
  recipient_number: string
  sender_number: string
}

export type SmsOutgoingMessage =
  | { body: string; messageType: 'text' }
  | {
      mediaDurationMs: number
      mediaMime: string
      mediaPayload: string
      mediaWaveform: number[]
      messageType: 'voice'
    }
  | {
      mediaAssetId: string
      mediaDurationMs?: number
      messageType: SmsAttachmentType
    }

export type SmsMedia = {
  mime: string
  payload: string
}

export type GifSearchResult = {
  height: number
  id: string
  previewUrl: string
  title: string
  url: string
  width: number
}

export type GifSearchPage = {
  hasMore: boolean
  nextOffset: number
  results: GifSearchResult[]
}
