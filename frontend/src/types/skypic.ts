import type { MediaType } from '@/types/media'

export type SkyPicStoryPrivacy = 'everyone' | 'friends'
export type SkyPicDirection = 'received' | 'sent'
export type SkyPicSnapType = 'snap_photo' | 'snap_video'
export type SkyPicFriendshipStatus =
  | 'friends'
  | 'incoming'
  | 'none'
  | 'outgoing'

export type SkyPicProfileSummary = {
  avatarSeed: number
  avatarUrl: string | null
  displayName: string
  friendshipId?: string | null
  friendshipStatus: SkyPicFriendshipStatus
  handle: string
  id: string
  snapScore: number
}

export type SkyPicProfile = SkyPicProfileSummary & {
  allowStoryReplies: boolean
  avatarMediaId: number | null
  bio: string
  friendCount: number
  showInQuickAdd: boolean
  storyPrivacy: SkyPicStoryPrivacy
}

export type SkyPicCreateProfileInput = {
  avatarMediaId?: number
  avatarSeed?: number
  displayName: string
  handle: string
}

export type SkyPicUpdateProfileInput = {
  allowStoryReplies: boolean
  avatarMediaId?: number | null
  avatarSeed?: number
  bio: string
  displayName: string
  handle: string
  showInQuickAdd: boolean
  storyPrivacy: SkyPicStoryPrivacy
}

export type SkyPicFriend = {
  bestStreak: number
  createdAt: string
  friendshipId: string
  profile: SkyPicProfileSummary
  streakCount: number
}

export type SkyPicFriendRequest = {
  createdAt: string
  direction: 'incoming' | 'outgoing'
  friendshipId: string
  profile: SkyPicProfileSummary
}

export type SkyPicConversationLastItem = {
  body?: string
  createdAt: string
  direction: SkyPicDirection
  id: string
  openedAt: string | null
  type: 'snap_photo' | 'snap_video' | 'text'
}

export type SkyPicConversation = {
  bestStreak: number
  friendshipId: string
  lastItem: SkyPicConversationLastItem | null
  profile: SkyPicProfileSummary
  streakCount: number
  unreadCount: number
}

/** Direct snap lists intentionally contain no media URL or editor contents. */
export type SkyPicSnap = {
  allowReplay: boolean
  createdAt: string
  direction: SkyPicDirection
  durationSeconds: number
  expiresAt: string
  friendshipId: string
  id: string
  openedAt: string | null
  replayedAt: string | null
  sender: SkyPicProfileSummary
  type: SkyPicSnapType
}

/** Media and editor contents are released only by open/replay callbacks. */
export type SkyPicOpenedSnap = {
  allowReplay: boolean
  caption: string
  durationSeconds: number
  expiresAt: string
  id: string
  mediaType: MediaType
  mimeType: string | null
  openedAt: string
  overlayColor: string
  replayedAt: string | null
  textOverlay: string
  url: string
}

/** Bootstrap returns story metadata only; URLs are released by view-story. */
export type SkyPicStory = {
  author: SkyPicProfileSummary
  createdAt: string
  durationSeconds: number
  expiresAt: string
  id: string
  isOwner: boolean
  seen: boolean
  viewCount: number
}

export type SkyPicViewedStory = {
  author: SkyPicProfileSummary
  canReply: boolean
  caption: string
  durationSeconds: number
  expiresAt: string
  id: string
  mediaType: MediaType
  mimeType: string | null
  overlayColor: string
  textOverlay: string
  url: string
  viewedAt: string
}

export type SkyPicStoryViewer = SkyPicProfileSummary & {
  viewedAt: string
}

export type SkyPicMessageDeliveryStatus = 'delivered' | 'failed' | 'sending'

export type SkyPicMessage = {
  body: string
  clientId?: string
  createdAt: string
  deliveryStatus?: SkyPicMessageDeliveryStatus
  direction: SkyPicDirection
  friendshipId: string
  id: string
  readAt: string | null
  savedAt: string | null
  type: 'text'
}

export type SkyPicThread = {
  messages: SkyPicMessage[]
  snaps: SkyPicSnap[]
}

export type SkyPicBootstrap = {
  blockedProfiles: SkyPicProfileSummary[]
  conversations: SkyPicConversation[]
  friends: SkyPicFriend[]
  inbox: SkyPicSnap[]
  profile: SkyPicProfile | null
  requests: SkyPicFriendRequest[]
  stories: SkyPicStory[]
  suggestions: SkyPicProfileSummary[]
  unreadCount: number
}

export type SkyPicDraftPurpose = 'snap' | 'story'

export type SkyPicMediaDraftContext = {
  purpose: SkyPicDraftPurpose
  recipientIds: string[]
}

export type SkyPicSendSnapInput = {
  allowReplay: boolean
  caption: string
  durationSeconds: number
  mediaId: number
  mediaType: MediaType
  overlayColor: string
  recipientIds: string[]
  textOverlay: string
}

export type SkyPicPublishStoryInput = Omit<
  SkyPicSendSnapInput,
  'allowReplay' | 'recipientIds'
>
