import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import {
  isValidSkyPicHandle,
  normalizeSkyPicHandle,
  useSkyPicStore,
} from '@/stores/skypic'
import type {
  SkyPicBootstrap,
  SkyPicConversation,
  SkyPicFriend,
  SkyPicFriendRequest,
  SkyPicMessage,
  SkyPicOpenedSnap,
  SkyPicProfile,
  SkyPicProfileSummary,
  SkyPicSnap,
  SkyPicStory,
  SkyPicStoryViewer,
  SkyPicThread,
  SkyPicViewedStory,
} from '@/types/skypic'
import { nuiCall, type NuiResponse } from '@/utils/nui'

vi.mock('@/utils/nui', () => ({ nuiCall: vi.fn() }))

const mockNuiCall = vi.mocked(nuiCall)
const now = '2026-08-19T12:00:00.000Z'
const later = '2026-08-19T13:00:00.000Z'

function deferred<T>(): {
  promise: Promise<T>
  resolve: (value: T | PromiseLike<T>) => void
} {
  let resolve!: (value: T | PromiseLike<T>) => void
  const promise = new Promise<T>((promiseResolve) => {
    resolve = promiseResolve
  })
  return { promise, resolve }
}

const self: SkyPicProfile = {
  allowStoryReplies: true,
  avatarMediaId: null,
  avatarSeed: 212,
  avatarUrl: null,
  bio: 'Night rides and city lights.',
  displayName: 'Nova',
  friendCount: 1,
  friendshipStatus: 'none',
  handle: 'nova',
  id: 'profile-self',
  showInQuickAdd: true,
  snapScore: 140,
  storyPrivacy: 'friends',
}

const maya: SkyPicProfileSummary = {
  avatarSeed: 318,
  avatarUrl: null,
  displayName: 'Maya',
  friendshipId: 'friendship-maya',
  friendshipStatus: 'friends',
  handle: 'maya',
  id: 'profile-maya',
  snapScore: 98,
}

const theo: SkyPicProfileSummary = {
  avatarSeed: 72,
  avatarUrl: null,
  displayName: 'Theo',
  friendshipStatus: 'none',
  handle: 'theo',
  id: 'profile-theo',
  snapScore: 61,
}

const friend: SkyPicFriend = {
  bestStreak: 12,
  createdAt: now,
  friendshipId: 'friendship-maya',
  profile: maya,
  streakCount: 5,
}

const request: SkyPicFriendRequest = {
  createdAt: now,
  direction: 'incoming',
  friendshipId: 'friendship-theo',
  profile: {
    ...theo,
    friendshipId: 'friendship-theo',
    friendshipStatus: 'incoming',
  },
}

const conversation: SkyPicConversation = {
  bestStreak: 12,
  friendshipId: friend.friendshipId,
  lastItem: {
    body: 'Meet at the pier?',
    createdAt: now,
    direction: 'received',
    id: 'message-last',
    openedAt: null,
    type: 'text',
  },
  profile: maya,
  streakCount: 5,
  unreadCount: 1,
}

const snap: SkyPicSnap = {
  allowReplay: true,
  createdAt: now,
  direction: 'received',
  durationSeconds: 5,
  expiresAt: later,
  friendshipId: friend.friendshipId,
  id: 'snap-1',
  openedAt: null,
  replayedAt: null,
  sender: maya,
  type: 'snap_photo',
}

const story: SkyPicStory = {
  author: maya,
  createdAt: now,
  durationSeconds: 6,
  expiresAt: later,
  id: 'story-1',
  isOwner: false,
  seen: false,
  viewCount: 4,
}

const bootstrap: SkyPicBootstrap = {
  blockedProfiles: [],
  conversations: [conversation],
  friends: [friend],
  inbox: [snap],
  profile: self,
  requests: [request],
  stories: [story],
  suggestions: [theo],
  unreadCount: 2,
}

const openedSnap: SkyPicOpenedSnap = {
  allowReplay: true,
  caption: 'Downtown',
  durationSeconds: 5,
  expiresAt: later,
  id: snap.id,
  mediaType: 'photo',
  mimeType: 'image/webp',
  openedAt: now,
  overlayColor: '#ffffff',
  replayedAt: null,
  textOverlay: 'Tonight',
  url: 'https://media.example.test/snap.webp',
}

describe('SkyPic store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    mockNuiCall.mockReset()
  })

  it('matches the server handle rule including leading and trailing separators', () => {
    expect(normalizeSkyPicHandle(' _Morgan ')).toBe('_morgan')
    expect(isValidSkyPicHandle('_morgan')).toBe(true)
    expect(isValidSkyPicHandle('morgan_')).toBe(true)
    expect(isValidSkyPicHandle('.mo')).toBe(true)
    expect(isValidSkyPicHandle('mo.')).toBe(true)
    expect(isValidSkyPicHandle('ab')).toBe(false)
    expect(isValidSkyPicHandle('a'.repeat(25))).toBe(false)
    expect(isValidSkyPicHandle('morgan-')).toBe(false)
  })

  it('hydrates the account-bound bootstrap without exposing direct media URLs', async () => {
    mockNuiCall.mockResolvedValueOnce({
      data: { ...bootstrap, blockedProfiles: [theo] },
      success: true,
    })
    const store = useSkyPicStore()

    expect(await store.bootstrap()).toBe(true)
    expect(store.profile?.handle).toBe('nova')
    expect(store.friends).toEqual([friend])
    expect(store.incomingRequests).toEqual([request])
    expect(store.blockedProfiles).toEqual([theo])
    expect(store.unreadCount).toBe(2)
    expect(store.inbox[0]).not.toHaveProperty('url')
    expect(store.inbox[0]).not.toHaveProperty('caption')
    expect(mockNuiCall).toHaveBeenCalledWith('skypic:bootstrap', {})
  })

  it('normalizes profile payloads and keeps the server profile authoritative', async () => {
    mockNuiCall
      .mockResolvedValueOnce({ data: self, success: true })
      .mockResolvedValueOnce({
        data: { ...self, bio: 'Updated', showInQuickAdd: false },
        success: true,
      })
    const store = useSkyPicStore()

    await store.createProfile({
      avatarSeed: 212,
      displayName: ' Nova ',
      handle: ' NOVA ',
    })
    expect(mockNuiCall).toHaveBeenNthCalledWith(1, 'skypic:create-profile', {
      avatarSeed: 212,
      displayName: 'Nova',
      handle: 'nova',
    })

    await store.updateProfile({
      allowStoryReplies: false,
      avatarMediaId: null,
      avatarSeed: 212,
      bio: ' Updated ',
      displayName: ' Nova ',
      handle: ' NOVA ',
      showInQuickAdd: false,
      storyPrivacy: 'everyone',
    })
    expect(mockNuiCall).toHaveBeenNthCalledWith(2, 'skypic:update-profile', {
      allowStoryReplies: false,
      avatarMediaId: null,
      avatarSeed: 212,
      bio: 'Updated',
      displayName: 'Nova',
      handle: 'nova',
      showInQuickAdd: false,
      storyPrivacy: 'everyone',
    })
    expect(store.profile?.showInQuickAdd).toBe(false)
  })

  it('deletes only the SkyPic account after explicit confirmation and clears local state', async () => {
    mockNuiCall.mockResolvedValueOnce({ success: true })
    const store = useSkyPicStore()
    store.profile = { ...self }
    store.friends = [{ ...friend }]
    store.conversations = [{ ...conversation }]

    await expect(store.deleteAccount()).resolves.toBe(true)

    expect(mockNuiCall).toHaveBeenCalledWith('skypic:delete-account', {
      confirmed: true,
    })
    expect(store.profile).toBeNull()
    expect(store.friends).toEqual([])
    expect(store.conversations).toEqual([])
  })

  it('keeps its own changed refresh from aborting an in-flight account deletion', async () => {
    const pendingDelete = deferred<NuiResponse<unknown>>()
    mockNuiCall.mockReturnValueOnce(pendingDelete.promise)
    const store = useSkyPicStore()
    store.profile = { ...self }

    const deletion = store.deleteAccount()
    expect(store.accountDeletePending).toBe(true)
    await expect(store.bootstrap()).resolves.toBe(false)
    expect(mockNuiCall).toHaveBeenCalledTimes(1)

    pendingDelete.resolve({ success: true })
    await expect(deletion).resolves.toBe(true)
    expect(store.accountDeletePending).toBe(false)
    expect(store.profile).toBeNull()
  })

  it('signals a server-confirmed missing profile without conflating local resets', async () => {
    mockNuiCall.mockResolvedValueOnce({
      data: { ...bootstrap, profile: null },
      success: true,
    })
    const store = useSkyPicStore()

    const discovery = store.bootstrap()
    expect(store.bootstrapPending).toBe(true)
    await expect(discovery).resolves.toBe(true)
    expect(store.bootstrapPending).toBe(false)
    expect(store.profileAbsentRevision).toBe(1)

    store.resetSession()
    expect(store.profileAbsentRevision).toBe(1)
  })

  it('updates outgoing relation state and accepts a friend request', async () => {
    const outgoing: SkyPicFriendRequest = {
      createdAt: now,
      direction: 'outgoing',
      friendshipId: 'friendship-theo',
      profile: {
        ...theo,
        friendshipId: 'friendship-theo',
        friendshipStatus: 'outgoing',
      },
    }
    const accepted: SkyPicFriend = {
      bestStreak: 0,
      createdAt: later,
      friendshipId: request.friendshipId,
      profile: {
        ...request.profile,
        friendshipStatus: 'friends',
      },
      streakCount: 0,
    }
    mockNuiCall
      .mockResolvedValueOnce({ data: outgoing, success: true })
      .mockResolvedValueOnce({ data: accepted, success: true })
    const store = useSkyPicStore()
    store.profile = { ...self }
    store.suggestions = [{ ...theo }, { ...request.profile }]
    store.searchResults = [{ ...theo }, { ...request.profile }]
    store.requests = [{ ...request }]

    expect((await store.addFriend(theo.id)).success).toBe(true)
    expect(store.suggestions[0].friendshipStatus).toBe('outgoing')
    expect(store.searchResults[0].friendshipId).toBe('friendship-theo')
    expect(store.outgoingRequests).toEqual([outgoing])
    expect(mockNuiCall).toHaveBeenNthCalledWith(1, 'skypic:add-friend', {
      profileId: theo.id,
    })

    expect(
      (await store.respondFriend(request.friendshipId, true)).success,
    ).toBe(true)
    expect(store.requests).toEqual([])
    expect(store.friends).toEqual([accepted])
    expect(store.profile.friendCount).toBe(2)
    expect(store.suggestions[1]).toMatchObject({
      friendshipId: accepted.friendshipId,
      friendshipStatus: 'friends',
    })
    expect(store.searchResults[1]).toMatchObject({
      friendshipId: accepted.friendshipId,
      friendshipStatus: 'friends',
    })
    expect(mockNuiCall).toHaveBeenNthCalledWith(2, 'skypic:respond-friend', {
      accept: true,
      friendshipId: request.friendshipId,
    })
  })

  it('returns declined incoming profiles to a neutral relationship state', async () => {
    mockNuiCall.mockResolvedValueOnce({ success: true })
    const store = useSkyPicStore()
    store.requests = [{ ...request }]
    store.suggestions = [{ ...request.profile }]
    store.searchResults = [{ ...request.profile }]

    expect(
      (await store.respondFriend(request.friendshipId, false)).success,
    ).toBe(true)
    expect(store.requests).toEqual([])
    expect(store.suggestions[0]).toMatchObject({
      friendshipId: null,
      friendshipStatus: 'none',
    })
    expect(store.searchResults[0]).toMatchObject({
      friendshipId: null,
      friendshipStatus: 'none',
    })
  })

  it('cancels an outgoing request without decrementing the friend count', async () => {
    const outgoing: SkyPicFriendRequest = {
      createdAt: now,
      direction: 'outgoing',
      friendshipId: 'friendship-theo',
      profile: {
        ...theo,
        friendshipId: 'friendship-theo',
        friendshipStatus: 'outgoing',
      },
    }
    mockNuiCall.mockResolvedValueOnce({ success: true })
    const store = useSkyPicStore()
    store.profile = { ...self }
    store.requests = [outgoing]
    store.suggestions = [{ ...outgoing.profile }]
    store.searchResults = [{ ...outgoing.profile }]

    expect(await store.removeFriend(outgoing.friendshipId)).toBe(true)
    expect(store.outgoingRequests).toEqual([])
    expect(store.profile.friendCount).toBe(self.friendCount)
    expect(store.suggestions[0]).toMatchObject({
      friendshipId: null,
      friendshipStatus: 'none',
    })
    expect(mockNuiCall).toHaveBeenCalledWith('skypic:remove-friend', {
      friendshipId: outgoing.friendshipId,
    })
  })

  it('removes a blocked profile from every local surface', async () => {
    mockNuiCall.mockResolvedValueOnce({ success: true })
    const store = useSkyPicStore()
    store.profile = { ...self }
    store.friends = [{ ...friend }]
    store.requests = [
      {
        ...request,
        friendshipId: friend.friendshipId,
        profile: { ...maya, friendshipStatus: 'incoming' },
      },
    ]
    store.conversations = [{ ...conversation }]
    store.inbox = [{ ...snap }]
    store.stories = [{ ...story }]
    store.suggestions = [{ ...maya }]
    store.searchResults = [{ ...maya }]
    store.activeFriendshipId = friend.friendshipId
    store.threadSnaps = [{ ...snap }]

    expect(await store.block(maya.id)).toBe(true)
    expect(store.friends).toEqual([])
    expect(store.requests).toEqual([])
    expect(store.conversations).toEqual([])
    expect(store.inbox).toEqual([])
    expect(store.stories).toEqual([])
    expect(store.suggestions).toEqual([])
    expect(store.searchResults).toEqual([])
    expect(store.activeFriendshipId).toBeNull()
    expect(store.profile.friendCount).toBe(0)
    expect(store.blockedProfiles).toEqual([
      expect.objectContaining({
        friendshipId: null,
        friendshipStatus: 'none',
        id: maya.id,
      }),
    ])
    expect(mockNuiCall).toHaveBeenCalledWith('skypic:block', {
      blocked: true,
      profileId: maya.id,
    })
  })

  it('does not decrement the friend count when blocking a request-only profile', async () => {
    mockNuiCall.mockResolvedValueOnce({ success: true })
    const store = useSkyPicStore()
    store.profile = { ...self }
    store.requests = [{ ...request }]

    expect(await store.block(theo.id)).toBe(true)
    expect(store.requests).toEqual([])
    expect(store.profile.friendCount).toBe(self.friendCount)
  })

  it('removes a profile from the blocked list when unblocking', async () => {
    mockNuiCall.mockResolvedValueOnce({ success: true })
    const store = useSkyPicStore()
    store.blockedProfiles = [{ ...theo }]

    expect(await store.block(theo.id, false)).toBe(true)
    expect(store.blockedProfiles).toEqual([])
    expect(mockNuiCall).toHaveBeenCalledWith('skypic:block', {
      blocked: false,
      profileId: theo.id,
    })
  })

  it('releases direct media only through open and replay and updates unread state', async () => {
    mockNuiCall
      .mockResolvedValueOnce({ data: openedSnap, success: true })
      .mockResolvedValueOnce({
        data: { ...openedSnap, replayedAt: later },
        success: true,
      })
    const store = useSkyPicStore()
    store.inbox = [{ ...snap }]
    store.conversations = [{ ...conversation }]
    store.profile = { ...self }
    store.unreadCount = 2

    expect((await store.openSnap(snap.id)).success).toBe(true)
    expect(store.openedSnap?.url).toBe(openedSnap.url)
    expect(store.inbox[0]).not.toHaveProperty('url')
    expect(store.inbox[0].openedAt).toBe(now)
    expect(store.unreadCount).toBe(1)
    expect(store.conversations[0].unreadCount).toBe(0)
    expect(store.profile.snapScore).toBe(self.snapScore + 1)
    expect(mockNuiCall).toHaveBeenNthCalledWith(1, 'skypic:open-snap', {
      snapId: snap.id,
    })

    store.clearOpenedSnap()
    expect(store.openedSnap).toBeNull()
    expect((await store.replaySnap(snap.id)).success).toBe(true)
    expect(store.inbox[0].replayedAt).toBe(later)
    expect(mockNuiCall).toHaveBeenNthCalledWith(2, 'skypic:replay-snap', {
      snapId: snap.id,
    })
  })

  it('allows only one direct snap open or replay request at a time', async () => {
    const pending = deferred<NuiResponse<SkyPicOpenedSnap>>()
    mockNuiCall.mockReturnValueOnce(pending.promise)
    const store = useSkyPicStore()

    const firstOpen = store.openSnap(snap.id)
    expect(store.snapOpening).toBe(true)
    await expect(store.openSnap('snap-2')).resolves.toEqual({
      error: 'snap_open_in_progress',
      success: false,
    })
    await expect(store.replaySnap(snap.id)).resolves.toEqual({
      error: 'snap_open_in_progress',
      success: false,
    })
    expect(mockNuiCall).toHaveBeenCalledTimes(1)

    pending.resolve({ data: openedSnap, success: true })
    await expect(firstOpen).resolves.toMatchObject({ success: true })
    expect(store.snapOpening).toBe(false)
  })

  it('bounds composer data, deduplicates recipients and appends sent snaps', async () => {
    const sent: SkyPicSnap = {
      ...snap,
      createdAt: later,
      direction: 'sent',
      id: 'snap-sent',
      openedAt: null,
      sender: { ...self, snapScore: self.snapScore + 1 },
    }
    mockNuiCall.mockResolvedValueOnce({ data: [sent], success: true })
    const store = useSkyPicStore()
    store.activeFriendshipId = friend.friendshipId
    store.conversations = [{ ...conversation }]
    store.friends = [{ ...friend }]
    store.profile = { ...self }

    const response = await store.sendSnap({
      allowReplay: true,
      caption: '  Hello  ',
      durationSeconds: 99,
      mediaId: 42,
      mediaType: 'photo',
      overlayColor: 'not-a-color',
      recipientIds: [maya.id, maya.id],
      textOverlay: '  Tonight  ',
    })

    expect(response.success).toBe(true)
    expect(mockNuiCall).toHaveBeenCalledWith('skypic:send-snap', {
      allowReplay: true,
      caption: 'Hello',
      durationSeconds: 10,
      mediaId: 42,
      mediaType: 'photo',
      overlayColor: '#ffffff',
      recipientIds: [maya.id],
      textOverlay: 'Tonight',
    })
    expect(store.threadSnaps).toEqual([sent])
    expect(store.conversations[0].lastItem).toMatchObject({
      id: sent.id,
      type: sent.type,
    })
    expect(store.friends[0]).toMatchObject({
      bestStreak: friend.bestStreak,
      streakCount: friend.streakCount,
    })
    expect(store.conversations[0]).toMatchObject({
      bestStreak: conversation.bestStreak,
      streakCount: conversation.streakCount,
    })
    expect(store.profile.snapScore).toBe(self.snapScore + 1)
  })

  it('reconciles one authoritative streak value across an atomic snap batch', async () => {
    const sentBatch = [1, 2, 3].map(
      (index): SkyPicSnap => ({
        ...snap,
        bestStreak: 18,
        direction: 'sent',
        id: `snap-batch-${index}`,
        sender: { ...self, snapScore: self.snapScore + 3 },
        streakCount: 1,
      }),
    )
    mockNuiCall.mockResolvedValueOnce({ data: sentBatch, success: true })
    const store = useSkyPicStore()
    store.activeFriendshipId = friend.friendshipId
    store.conversations = [{ ...conversation }]
    store.friends = [{ ...friend }]
    store.profile = { ...self }

    await store.sendSnap({
      allowReplay: false,
      caption: '',
      durationSeconds: 5,
      mediaIds: [1, 2, 3],
      overlayColor: '#ffffff',
      recipientIds: [maya.id],
      textOverlay: '',
    })

    expect(store.threadSnaps).toHaveLength(3)
    expect(store.friends[0]).toMatchObject({
      bestStreak: 18,
      streakCount: 1,
    })
    expect(store.conversations[0]).toMatchObject({
      bestStreak: 18,
      streakCount: 1,
    })
    expect(store.profile.snapScore).toBe(self.snapScore + 3)
  })

  it('does not let an older send response overwrite streaks from a newer bootstrap', async () => {
    const pendingSend = deferred<NuiResponse<SkyPicSnap[]>>()
    const refreshedProfile = { ...self, snapScore: self.snapScore + 5 }
    const refreshedFriend = {
      ...friend,
      bestStreak: 20,
      streakCount: 9,
    }
    const refreshedConversation: SkyPicConversation = {
      ...conversation,
      bestStreak: 20,
      lastItem: {
        body: 'Authoritative newer item',
        createdAt: '2026-08-19T14:00:00.000Z',
        direction: 'received',
        id: 'message-newer-hydration',
        openedAt: null,
        type: 'text',
      },
      streakCount: 9,
    }
    const refreshedBootstrap: SkyPicBootstrap = {
      ...bootstrap,
      conversations: [refreshedConversation],
      friends: [refreshedFriend],
      profile: refreshedProfile,
    }
    mockNuiCall
      .mockReturnValueOnce(pendingSend.promise)
      .mockResolvedValueOnce({ data: refreshedBootstrap, success: true })
      .mockResolvedValueOnce({ data: refreshedBootstrap, success: true })
    const store = useSkyPicStore()

    const sending = store.sendSnap({
      allowReplay: false,
      caption: '',
      durationSeconds: 5,
      mediaId: 42,
      mediaType: 'photo',
      overlayColor: '#ffffff',
      recipientIds: [maya.id],
      textOverlay: '',
    })
    await expect(store.bootstrap()).resolves.toBe(true)

    const staleSent: SkyPicSnap = {
      ...snap,
      bestStreak: 18,
      direction: 'sent',
      id: 'snap-stale-streak',
      sender: refreshedProfile,
      streakCount: 1,
    }
    pendingSend.resolve({ data: [staleSent], success: true })
    await expect(sending).resolves.toMatchObject({ success: true })

    expect(store.friends[0]).toMatchObject({
      bestStreak: 20,
      streakCount: 9,
    })
    expect(store.conversations[0]).toMatchObject({
      bestStreak: 20,
      lastItem: { id: 'message-newer-hydration' },
      streakCount: 9,
    })
    expect(mockNuiCall).toHaveBeenNthCalledWith(3, 'skypic:bootstrap', {})
  })

  it('waits for a pending pre-commit bootstrap before its causal refresh', async () => {
    const pendingSend = deferred<NuiResponse<SkyPicSnap[]>>()
    const pendingBootstrap = deferred<NuiResponse<SkyPicBootstrap>>()
    const committedSent: SkyPicSnap = {
      ...snap,
      bestStreak: 12,
      createdAt: later,
      direction: 'sent',
      id: 'snap-after-pending-bootstrap',
      sender: { ...self, snapScore: self.snapScore + 1 },
      streakCount: 6,
    }
    const authoritativeConversation: SkyPicConversation = {
      ...conversation,
      bestStreak: 12,
      lastItem: {
        createdAt: committedSent.createdAt,
        direction: 'sent',
        id: committedSent.id,
        openedAt: null,
        type: committedSent.type,
      },
      streakCount: 6,
    }
    const postCommitBootstrap: SkyPicBootstrap = {
      ...bootstrap,
      conversations: [authoritativeConversation],
      friends: [{ ...friend, streakCount: 6 }],
      profile: { ...self, snapScore: self.snapScore + 1 },
    }
    mockNuiCall
      .mockReturnValueOnce(pendingSend.promise)
      .mockReturnValueOnce(pendingBootstrap.promise)
      .mockResolvedValueOnce({ data: postCommitBootstrap, success: true })
    const store = useSkyPicStore()

    const sending = store.sendSnap({
      allowReplay: false,
      caption: '',
      durationSeconds: 5,
      mediaId: 42,
      mediaType: 'photo',
      overlayColor: '#ffffff',
      recipientIds: [maya.id],
      textOverlay: '',
    })
    const staleRefresh = store.bootstrap()
    pendingSend.resolve({ data: [committedSent], success: true })
    await Promise.resolve()
    await Promise.resolve()
    pendingBootstrap.resolve({ data: bootstrap, success: true })

    await expect(staleRefresh).resolves.toBe(true)
    await expect(sending).resolves.toMatchObject({ success: true })
    expect(store.friends[0]).toMatchObject({
      bestStreak: 12,
      streakCount: 6,
    })
    expect(store.conversations[0]).toMatchObject({
      bestStreak: 12,
      lastItem: { id: committedSent.id },
      streakCount: 6,
    })
    expect(store.profile?.snapScore).toBe(self.snapScore + 1)
    expect(mockNuiCall).toHaveBeenNthCalledWith(3, 'skypic:bootstrap', {})
  })

  it('refreshes after a bootstrap that read before the pending send committed', async () => {
    const pendingSend = deferred<NuiResponse<SkyPicSnap[]>>()
    const pendingPreCommitBootstrap = deferred<NuiResponse<SkyPicBootstrap>>()
    const staleHydration: SkyPicBootstrap = {
      ...bootstrap,
      conversations: [{ ...conversation }],
      friends: [{ ...friend }],
      profile: { ...self },
    }
    const committedSent: SkyPicSnap = {
      ...snap,
      bestStreak: 12,
      createdAt: later,
      direction: 'sent',
      id: 'snap-committed-after-bootstrap-read',
      sender: { ...self, snapScore: self.snapScore + 1 },
      streakCount: 6,
    }
    const committedConversation: SkyPicConversation = {
      ...conversation,
      bestStreak: 12,
      lastItem: {
        createdAt: committedSent.createdAt,
        direction: 'sent',
        id: committedSent.id,
        openedAt: null,
        type: committedSent.type,
      },
      streakCount: 6,
    }
    const postCommitBootstrap: SkyPicBootstrap = {
      ...bootstrap,
      conversations: [committedConversation],
      friends: [{ ...friend, streakCount: 6 }],
      profile: { ...self, snapScore: self.snapScore + 1 },
    }
    mockNuiCall
      .mockReturnValueOnce(pendingSend.promise)
      .mockResolvedValueOnce({ data: staleHydration, success: true })
      .mockReturnValueOnce(pendingPreCommitBootstrap.promise)
      .mockResolvedValueOnce({ data: postCommitBootstrap, success: true })
    const store = useSkyPicStore()

    const sending = store.sendSnap({
      allowReplay: false,
      caption: '',
      durationSeconds: 5,
      mediaId: 42,
      mediaType: 'photo',
      overlayColor: '#ffffff',
      recipientIds: [maya.id],
      textOverlay: '',
    })
    await expect(store.bootstrap()).resolves.toBe(true)
    expect(store.friends[0].streakCount).toBe(friend.streakCount)

    const overlappingPreCommitRefresh = store.bootstrap()
    pendingSend.resolve({ data: [committedSent], success: true })
    pendingPreCommitBootstrap.resolve({
      data: staleHydration,
      success: true,
    })
    await expect(overlappingPreCommitRefresh).resolves.toBe(true)
    await expect(sending).resolves.toMatchObject({ success: true })

    expect(store.friends[0]).toMatchObject({
      bestStreak: 12,
      streakCount: 6,
    })
    expect(store.conversations[0]).toMatchObject({
      bestStreak: 12,
      lastItem: { id: committedSent.id },
      streakCount: 6,
    })
    expect(mockNuiCall).toHaveBeenNthCalledWith(4, 'skypic:bootstrap', {})
  })

  it('does not refresh an obsolete session after a pending send resolves', async () => {
    const pendingSend = deferred<NuiResponse<SkyPicSnap[]>>()
    mockNuiCall.mockReturnValueOnce(pendingSend.promise)
    const store = useSkyPicStore()

    const sending = store.sendSnap({
      allowReplay: false,
      caption: '',
      durationSeconds: 5,
      mediaId: 42,
      mediaType: 'photo',
      overlayColor: '#ffffff',
      recipientIds: [maya.id],
      textOverlay: '',
    })
    store.resetSession()
    pendingSend.resolve({ data: [snap], success: true })

    await expect(sending).resolves.toEqual({
      error: 'request_aborted',
      success: false,
    })
    expect(mockNuiCall).toHaveBeenCalledTimes(1)
  })

  it('deduplicates and caps a multi-photo snap batch without legacy media fields', async () => {
    mockNuiCall.mockResolvedValueOnce({ data: [], success: true })
    const store = useSkyPicStore()
    const mediaIds = [1, 2, 2, 0, -1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]

    await store.sendSnap({
      allowReplay: true,
      caption: '',
      durationSeconds: 5,
      mediaIds,
      overlayColor: '#ffffff',
      recipientIds: [maya.id],
      textOverlay: '',
    })

    expect(mockNuiCall).toHaveBeenCalledWith('skypic:send-snap', {
      allowReplay: true,
      caption: '',
      durationSeconds: 5,
      mediaIds: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      overlayColor: '#ffffff',
      recipientIds: [maya.id],
      textOverlay: '',
    })
    const payload = mockNuiCall.mock.calls[0]?.[1]
    expect(payload).not.toHaveProperty('mediaId')
    expect(payload).not.toHaveProperty('mediaType')
  })

  it('caps snap recipients and chat bodies at the server limits', async () => {
    const recipientIds = Array.from(
      { length: 22 },
      (_, index) => 'profile-' + index,
    )
    const longBody = 'x'.repeat(2_000) + 'tail'
    const message: SkyPicMessage = {
      body: 'x'.repeat(2_000),
      createdAt: later,
      direction: 'sent',
      friendshipId: friend.friendshipId,
      id: 'message-capped',
      readAt: null,
      savedAt: null,
      type: 'text',
    }
    mockNuiCall
      .mockResolvedValueOnce({ data: [], success: true })
      .mockResolvedValueOnce({ data: message, success: true })
    const store = useSkyPicStore()

    await store.sendSnap({
      allowReplay: false,
      caption: '',
      durationSeconds: 5,
      mediaId: 42,
      mediaType: 'photo',
      overlayColor: '#ffffff',
      recipientIds,
      textOverlay: 'y'.repeat(161),
    })
    expect(mockNuiCall).toHaveBeenNthCalledWith(
      1,
      'skypic:send-snap',
      expect.objectContaining({ recipientIds: recipientIds.slice(0, 20) }),
    )
    const snapPayload = mockNuiCall.mock.calls[0]?.[1]
    expect(Array.from(String(snapPayload?.textOverlay))).toHaveLength(160)

    await store.sendMessage(friend.friendshipId, longBody)
    const sentPayload = mockNuiCall.mock.calls[1]?.[1]
    expect(Array.from(String(sentPayload?.body))).toHaveLength(2_000)
    expect(sentPayload).toMatchObject({
      friendshipId: friend.friendshipId,
    })
  })

  it('releases story media through view-story and keeps bootstrap metadata clean', async () => {
    const viewed: SkyPicViewedStory = {
      author: maya,
      canReply: true,
      caption: 'Pier lights',
      durationSeconds: 6,
      expiresAt: later,
      id: story.id,
      mediaType: 'video',
      mimeType: 'video/webm',
      overlayColor: '#42e8ff',
      textOverlay: 'Los Santos',
      url: 'https://media.example.test/story.webm',
      viewedAt: now,
    }
    mockNuiCall
      .mockResolvedValueOnce({ data: viewed, success: true })
      .mockResolvedValueOnce({ success: true })
    const store = useSkyPicStore()
    store.stories = [{ ...story }]

    expect((await store.viewStory(story.id)).success).toBe(true)
    expect(store.viewedStory?.url).toBe(viewed.url)
    expect(store.stories[0]).not.toHaveProperty('url')
    expect(store.stories[0].seen).toBe(true)
    expect(store.stories[0].viewCount).toBe(5)
    expect(mockNuiCall).toHaveBeenNthCalledWith(1, 'skypic:view-story', {
      storyId: story.id,
    })

    expect(await store.removeStory(story.id)).toBe(true)
    expect(store.stories).toEqual([])
    expect(store.viewedStory).toBeNull()
    expect(mockNuiCall).toHaveBeenNthCalledWith(2, 'skypic:remove-story', {
      storyId: story.id,
    })
  })

  it('allows only one story release request and invalidates it on reset', async () => {
    const viewed: SkyPicViewedStory = {
      author: maya,
      canReply: true,
      caption: '',
      durationSeconds: 6,
      expiresAt: later,
      id: story.id,
      mediaType: 'photo',
      mimeType: 'image/webp',
      overlayColor: '#ffffff',
      textOverlay: '',
      url: 'https://media.example.test/story.webp',
      viewedAt: now,
    }
    const pendingStory = deferred<NuiResponse<SkyPicViewedStory>>()
    mockNuiCall.mockReturnValueOnce(pendingStory.promise)
    const store = useSkyPicStore()

    const first = store.viewStory(story.id)
    expect(store.storyViewing).toBe(true)
    await expect(store.viewStory('story-2')).resolves.toEqual({
      error: 'story_view_in_progress',
      success: false,
    })
    expect(mockNuiCall).toHaveBeenCalledTimes(1)

    store.resetSession()
    pendingStory.resolve({ data: viewed, success: true })
    await expect(first).resolves.toEqual({
      error: 'request_aborted',
      success: false,
    })
    expect(store.viewedStory).toBeNull()
    expect(store.storyViewing).toBe(false)
  })

  it('keeps only the newest story-viewer request and cancels it on reset', async () => {
    const firstViewers = deferred<NuiResponse<SkyPicStoryViewer[]>>()
    const secondViewers = deferred<NuiResponse<SkyPicStoryViewer[]>>()
    mockNuiCall
      .mockReturnValueOnce(firstViewers.promise)
      .mockReturnValueOnce(secondViewers.promise)
    const store = useSkyPicStore()

    const first = store.loadStoryViewers('story-a')
    const second = store.loadStoryViewers('story-b')
    secondViewers.resolve({
      data: [{ ...maya, viewedAt: now }],
      success: true,
    })
    await expect(second).resolves.toBe(true)
    firstViewers.resolve({
      data: [{ ...theo, viewedAt: later }],
      success: true,
    })
    await expect(first).resolves.toBe(false)
    expect(store.storyViewers).toEqual([{ ...maya, viewedAt: now }])

    const pendingAfterReset = deferred<NuiResponse<SkyPicStoryViewer[]>>()
    mockNuiCall.mockReturnValueOnce(pendingAfterReset.promise)
    const refresh = store.loadStoryViewers('story-c')
    store.resetSession()
    pendingAfterReset.resolve({
      data: [{ ...theo, viewedAt: later }],
      success: true,
    })
    await expect(refresh).resolves.toBe(false)
    expect(store.storyViewers).toEqual([])
  })

  it('publishes story metadata and reconciles the authoritative score', async () => {
    const published: SkyPicStory = {
      ...story,
      author: { ...self, snapScore: self.snapScore + 1 },
      id: 'story-own',
      isOwner: true,
      seen: true,
      viewCount: 0,
    }
    mockNuiCall.mockResolvedValueOnce({ data: published, success: true })
    const store = useSkyPicStore()
    store.profile = { ...self }

    expect(
      (
        await store.publishStory({
          caption: ' New story ',
          durationSeconds: 6,
          mediaId: 44,
          mediaType: 'photo',
          overlayColor: '#42e8ff',
          textOverlay: ' Sky ',
        })
      ).success,
    ).toBe(true)
    expect(store.stories).toEqual([published])
    expect(store.profile.snapScore).toBe(self.snapScore + 1)
    expect(mockNuiCall).toHaveBeenCalledWith('skypic:publish-story', {
      caption: 'New story',
      durationSeconds: 6,
      mediaId: 44,
      mediaType: 'photo',
      overlayColor: '#42e8ff',
      textOverlay: 'Sky',
    })
  })

  it('loads a thread, sends text optimistically, marks, saves and deletes it', async () => {
    const received: SkyPicMessage = {
      body: 'Hey',
      createdAt: now,
      direction: 'received',
      friendshipId: friend.friendshipId,
      id: 'message-received',
      readAt: null,
      savedAt: null,
      type: 'text',
    }
    const sent: SkyPicMessage = {
      ...received,
      body: 'On my way',
      createdAt: later,
      direction: 'sent',
      id: 'message-sent',
    }
    const previousSnap: SkyPicSnap = {
      ...snap,
      createdAt: '2026-08-19T12:30:00.000Z',
    }
    mockNuiCall
      .mockResolvedValueOnce({
        data: { messages: [received], snaps: [previousSnap] },
        success: true,
      })
      .mockResolvedValueOnce({ success: true })
      .mockResolvedValueOnce({ data: sent, success: true })
      .mockResolvedValueOnce({
        data: { ...sent, savedAt: later },
        success: true,
      })
      .mockResolvedValueOnce({ success: true })
    const store = useSkyPicStore()
    store.conversations = [
      {
        ...conversation,
        friendshipId: 'friendship-other',
        profile: {
          ...theo,
          friendshipId: 'friendship-other',
          friendshipStatus: 'friends',
        },
        unreadCount: 0,
      },
      { ...conversation, unreadCount: 2 },
    ]
    store.unreadCount = 2

    expect(await store.openThread(friend.friendshipId)).toBe(true)
    expect(store.threadMessages).toEqual([received])
    expect(store.threadSnaps).toEqual([previousSnap])
    expect(mockNuiCall).toHaveBeenNthCalledWith(1, 'skypic:thread', {
      friendshipId: friend.friendshipId,
    })

    expect(await store.markThread(friend.friendshipId)).toBe(true)
    expect(store.threadMessages[0].readAt).not.toBeNull()
    expect(store.unreadCount).toBe(1)
    expect(
      store.conversations.find(
        (item) => item.friendshipId === friend.friendshipId,
      )?.unreadCount,
    ).toBe(1)
    expect(mockNuiCall).toHaveBeenNthCalledWith(2, 'skypic:mark-thread', {
      friendshipId: friend.friendshipId,
    })

    expect(
      (await store.sendMessage(friend.friendshipId, '  On my way  ')).success,
    ).toBe(true)
    expect(mockNuiCall).toHaveBeenNthCalledWith(3, 'skypic:send-message', {
      body: 'On my way',
      friendshipId: friend.friendshipId,
    })
    expect(store.threadMessages.at(-1)?.deliveryStatus).toBe('delivered')
    expect(store.conversations[0].friendshipId).toBe(friend.friendshipId)
    expect(store.conversations[0].lastItem?.id).toBe(sent.id)

    expect(await store.saveMessage(sent.id, true)).toBe(true)
    expect(store.threadMessages.at(-1)?.savedAt).toBe(later)
    expect(mockNuiCall).toHaveBeenNthCalledWith(4, 'skypic:save-message', {
      messageId: sent.id,
      saved: true,
    })

    expect(await store.deleteMessage(sent.id, true)).toBe(true)
    expect(store.threadMessages.some((message) => message.id === sent.id)).toBe(
      false,
    )
    expect(store.conversations[0].lastItem).toMatchObject({
      id: previousSnap.id,
      type: previousSnap.type,
    })
    expect(mockNuiCall).toHaveBeenNthCalledWith(5, 'skypic:delete-message', {
      forEveryone: true,
      messageId: sent.id,
    })
  })

  it('clears the conversation preview when its only thread item is deleted', async () => {
    const onlyMessage: SkyPicMessage = {
      body: 'Only message',
      createdAt: later,
      direction: 'sent',
      friendshipId: friend.friendshipId,
      id: 'message-only',
      readAt: null,
      savedAt: null,
      type: 'text',
    }
    mockNuiCall.mockResolvedValueOnce({ success: true })
    const store = useSkyPicStore()
    store.conversations = [
      {
        ...conversation,
        lastItem: {
          body: onlyMessage.body,
          createdAt: onlyMessage.createdAt,
          direction: onlyMessage.direction,
          id: onlyMessage.id,
          openedAt: null,
          type: 'text',
        },
      },
    ]
    store.threadMessages = [onlyMessage]

    expect(await store.deleteMessage(onlyMessage.id)).toBe(true)
    expect(store.threadMessages).toEqual([])
    expect(store.conversations[0].lastItem).toBeNull()
    expect(mockNuiCall).toHaveBeenCalledWith('skypic:delete-message', {
      forEveryone: false,
      messageId: onlyMessage.id,
    })
  })

  it('links a story reply to the exact story in the send-message payload', async () => {
    const reply: SkyPicMessage = {
      body: 'Looks great',
      createdAt: later,
      direction: 'sent',
      friendshipId: friend.friendshipId,
      id: 'message-story-reply',
      readAt: null,
      savedAt: null,
      type: 'text',
    }
    mockNuiCall.mockResolvedValueOnce({ data: reply, success: true })
    const store = useSkyPicStore()

    expect(
      (await store.sendMessage(friend.friendshipId, ' Looks great ', story.id))
        .success,
    ).toBe(true)
    expect(mockNuiCall).toHaveBeenCalledWith('skypic:send-message', {
      body: 'Looks great',
      friendshipId: friend.friendshipId,
      storyId: story.id,
    })
  })

  it('keeps the newest thread when overlapping requests resolve out of order', async () => {
    const firstThread = deferred<NuiResponse<SkyPicThread>>()
    const secondThread = deferred<NuiResponse<SkyPicThread>>()
    const refreshedMessage: SkyPicMessage = {
      body: 'Latest',
      createdAt: later,
      direction: 'received',
      friendshipId: 'friendship-b',
      id: 'message-b',
      readAt: null,
      savedAt: null,
      type: 'text',
    }
    mockNuiCall
      .mockReturnValueOnce(firstThread.promise)
      .mockReturnValueOnce(secondThread.promise)
      .mockResolvedValueOnce({
        data: { messages: [refreshedMessage], snaps: [] },
        success: true,
      })
    const store = useSkyPicStore()

    const first = store.openThread('friendship-a')
    const second = store.openThread('friendship-b')
    secondThread.resolve({ data: { messages: [], snaps: [] }, success: true })
    await expect(second).resolves.toBe(true)
    firstThread.resolve({
      data: { messages: [], snaps: [snap] },
      success: true,
    })
    await expect(first).resolves.toBe(false)
    expect(store.activeFriendshipId).toBe('friendship-b')
    expect(store.threadSnaps).toEqual([])

    await expect(store.refreshActiveThread()).resolves.toBe(true)
    expect(store.threadMessages).toEqual([refreshedMessage])
    expect(mockNuiCall).toHaveBeenNthCalledWith(3, 'skypic:thread', {
      friendshipId: 'friendship-b',
    })
  })

  it('resets every account-bound surface and ignores an older bootstrap response', async () => {
    const pendingBootstrap = deferred<NuiResponse<SkyPicBootstrap>>()
    mockNuiCall.mockReturnValueOnce(pendingBootstrap.promise)
    const store = useSkyPicStore()
    store.profile = { ...self }
    store.blockedProfiles = [{ ...theo }]
    store.friends = [{ ...friend }]
    store.requests = [{ ...request }]
    store.conversations = [{ ...conversation }]
    store.inbox = [{ ...snap }]
    store.stories = [{ ...story }]
    store.suggestions = [{ ...theo }]
    store.searchResults = [{ ...maya }]
    store.unreadCount = 7
    store.activeFriendshipId = friend.friendshipId
    store.threadSnaps = [{ ...snap }]
    store.openedSnap = { ...openedSnap }

    const refresh = store.bootstrap()
    store.resetSession()
    pendingBootstrap.resolve({ data: bootstrap, success: true })

    await expect(refresh).resolves.toBe(false)
    expect(store.profile).toBeNull()
    expect(store.blockedProfiles).toEqual([])
    expect(store.friends).toEqual([])
    expect(store.requests).toEqual([])
    expect(store.conversations).toEqual([])
    expect(store.inbox).toEqual([])
    expect(store.stories).toEqual([])
    expect(store.suggestions).toEqual([])
    expect(store.searchResults).toEqual([])
    expect(store.unreadCount).toBe(0)
    expect(store.activeFriendshipId).toBeNull()
    expect(store.threadSnaps).toEqual([])
    expect(store.openedSnap).toBeNull()
    expect(store.loading).toBe(false)
  })

  it('deduplicates concurrent bootstrap requests in the same session', async () => {
    const pendingBootstrap = deferred<NuiResponse<SkyPicBootstrap>>()
    mockNuiCall.mockReturnValueOnce(pendingBootstrap.promise)
    const store = useSkyPicStore()

    const first = store.bootstrap()
    const second = store.bootstrap()
    expect(mockNuiCall).toHaveBeenCalledTimes(1)

    pendingBootstrap.resolve({ data: bootstrap, success: true })
    await expect(Promise.all([first, second])).resolves.toEqual([true, true])
    expect(store.profile).toEqual(self)
    expect(store.loading).toBe(false)
  })

  it('paginates stories and viewer lists with offsets and ID deduplication', async () => {
    const firstStories = Array.from({ length: 30 }, (_, index) => ({
      ...story,
      id: 'story-' + index,
    }))
    const moreStories = [
      { ...story, id: 'story-29' },
      { ...story, id: 'story-30' },
    ]
    const firstViewers: SkyPicStoryViewer[] = Array.from(
      { length: 30 },
      (_, index) => ({
        ...maya,
        handle: 'viewer-' + index,
        id: 'viewer-' + index,
        viewedAt: now,
      }),
    )
    const moreViewers: SkyPicStoryViewer[] = [
      { ...firstViewers[29] },
      { ...theo, id: 'viewer-30', viewedAt: later },
    ]
    mockNuiCall
      .mockResolvedValueOnce({ data: firstStories, success: true })
      .mockResolvedValueOnce({ data: moreStories, success: true })
      .mockResolvedValueOnce({ data: firstViewers, success: true })
      .mockResolvedValueOnce({ data: moreViewers, success: true })
    const store = useSkyPicStore()

    expect(await store.loadStories()).toBe(true)
    expect(store.storiesHasMore).toBe(true)
    expect(await store.loadMoreStories()).toBe(true)
    expect(store.stories).toHaveLength(31)
    expect(store.storiesHasMore).toBe(false)
    expect(mockNuiCall).toHaveBeenNthCalledWith(1, 'skypic:stories', {
      offset: 0,
    })
    expect(mockNuiCall).toHaveBeenNthCalledWith(2, 'skypic:stories', {
      offset: 30,
    })

    expect(await store.loadStoryViewers(story.id)).toBe(true)
    expect(store.storyViewersHasMore).toBe(true)
    expect(await store.loadMoreStoryViewers(story.id)).toBe(true)
    expect(store.storyViewers).toHaveLength(31)
    expect(store.storyViewersHasMore).toBe(false)
    expect(mockNuiCall).toHaveBeenNthCalledWith(3, 'skypic:story-viewers', {
      offset: 0,
      storyId: story.id,
    })
    expect(mockNuiCall).toHaveBeenNthCalledWith(4, 'skypic:story-viewers', {
      offset: 30,
      storyId: story.id,
    })
  })

  it('keeps stale data when a refresh fails', async () => {
    mockNuiCall.mockResolvedValueOnce({
      error: 'request_timeout',
      success: false,
    })
    const store = useSkyPicStore()
    store.profile = { ...self }
    store.friends = [{ ...friend }]

    expect(await store.bootstrap()).toBe(false)
    expect(store.profile).toEqual(self)
    expect(store.friends).toEqual([friend])
    expect(store.error).toBe('request_timeout')
  })
})
