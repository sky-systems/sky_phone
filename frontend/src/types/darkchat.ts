import type { DatabaseDateValue } from '@/utils/date'

export type DarkChatMessageType =
  | 'text'
  | 'emoji'
  | 'gif'
  | 'voice'
  | 'image'
  | 'video'
  | 'system'
export type DarkChatNotificationMode = 'full' | 'private' | 'hidden'

export type DarkChatIdentity = {
  id: number
  darkId: string
  alias: string
  originalAlias?: string
  avatarSeed: number
  activityVisible?: boolean
  isContact?: boolean
  blocked?: boolean
}

export type DarkChatProfile = DarkChatIdentity & {
  inviteCode: string
  notificationMode: DarkChatNotificationMode
  activityVisible: boolean
  createdAt: DatabaseDateValue
}

export type DarkChatContact = DarkChatIdentity & {
  createdAt: DatabaseDateValue
}

export type DarkChatConversationSummary = {
  id: string
  peer: DarkChatIdentity
  disappearingSeconds: number
  blocked: boolean
  lastMessage: string
  lastMessageType: DarkChatMessageType
  lastMessageAt: DatabaseDateValue
  unread: number
}

export type DarkChatConversation = {
  id: string
  peer: DarkChatIdentity
  disappearingSeconds: number
  notificationsEnabled: boolean
  readReceipts: boolean
  blockedByPeer: boolean
  createdAt: DatabaseDateValue
}

export type DarkChatMessage = {
  id: string
  clientId?: string
  conversationId: string
  direction: 'sent' | 'received'
  senderProfileId?: number
  messageType: DarkChatMessageType
  body: string
  mediaMime?: string | null
  mediaPayload?: string | null
  mediaDurationMs?: number | null
  mediaWaveform?: number[] | null
  replyToId?: string | null
  replyBody?: string | null
  reactions: Record<string, string>
  expiresAt?: DatabaseDateValue | null
  createdAt: DatabaseDateValue
  readAt?: DatabaseDateValue | null
  deletedForEveryone?: boolean
  deliveryStatus?: 'sending' | 'delivered' | 'failed'
}

export type DarkChatBootstrap = {
  profile: DarkChatProfile
  contacts: DarkChatContact[]
  conversations: DarkChatConversationSummary[]
}

export type DarkChatThread = {
  conversation: DarkChatConversation
  messages: DarkChatMessage[]
}

export type DarkChatOutgoing = {
  body?: string
  messageType: 'text' | 'emoji' | 'gif' | 'voice' | 'image' | 'video'
  mediaAssetId?: string
  mediaPayload?: string
  mediaPreviewUrl?: string
  mediaMime?: string
  mediaDurationMs?: number
  mediaWaveform?: number[]
  replyToId?: string
}
