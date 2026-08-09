import type { DatabaseDateValue } from '@/utils/date'

export type FlareGender = 'woman' | 'man' | 'nonbinary'
export type FlareInterest = FlareGender | 'everyone'
export type FlareMessageType = 'text' | 'image' | 'gif' | 'video'

export type FlareProfile = {
  age: number
  avatar: number
  bio: string
  gender: FlareGender
  id: number
  interests: string[]
  lookingFor: string
  name: string
  photoUrls: string[]
}

export type FlareLike = FlareProfile & { superLiked: boolean }

export type FlareMatch = {
  id: string
  lastMessage: string
  lastMessageAt: DatabaseDateValue | null
  lastMessageType: FlareMessageType | null
  profile: FlareProfile
  unread: number
}

export type FlareOwnProfile = FlareProfile & {
  discoverable: boolean
  interestedIn: FlareInterest
  maxAge: number
  minAge: number
  photoMediaIds: number[]
}

export type FlareMessage = {
  body: string
  createdAt: DatabaseDateValue
  direction: 'received' | 'sent'
  id: string
  mediaDurationMs: number | null
  mediaUrl: string | null
  messageType: FlareMessageType
}

export type FlareOutgoingMessage =
  | { body: string; messageType: 'text' }
  | {
      mediaAssetId: string
      mediaDurationMs?: number
      messageType: Exclude<FlareMessageType, 'text'>
    }

export type FlareProfileDraft = Omit<
  FlareOwnProfile,
  'discoverable' | 'id' | 'photoUrls'
>

export type FlareBootstrap = {
  likes: FlareLike[]
  matches: FlareMatch[]
  profile: FlareOwnProfile | null
  suggestions: FlareProfile[]
}
