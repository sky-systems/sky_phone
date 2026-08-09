export type FlareGender = 'woman' | 'man' | 'nonbinary'
export type FlareInterest = FlareGender | 'everyone'

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
  lastMessageAt: string | null
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
  createdAt: string
  direction: 'received' | 'sent'
  id: string
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
