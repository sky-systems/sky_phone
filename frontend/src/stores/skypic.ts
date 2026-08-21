import { computed, ref } from 'vue'
import { defineStore } from 'pinia'

import type {
  SkyPicBootstrap,
  SkyPicConversation,
  SkyPicConversationLastItem,
  SkyPicCreateProfileInput,
  SkyPicFriend,
  SkyPicFriendRequest,
  SkyPicMessage,
  SkyPicOpenedSnap,
  SkyPicProfile,
  SkyPicProfileSummary,
  SkyPicPublishSpotlightInput,
  SkyPicPublishStoryInput,
  SkyPicSendSnapInput,
  SkyPicSnap,
  SkyPicSpotlight,
  SkyPicSpotlightComment,
  SkyPicSpotlightReportReason,
  SkyPicStory,
  SkyPicStoryViewer,
  SkyPicThread,
  SkyPicUpdateProfileInput,
  SkyPicViewedStory,
} from '@/types/skypic'
import { nuiCall, type NuiResponse } from '@/utils/nui'

const MAX_MESSAGE_CHARACTERS = 2_000
const MAX_SNAP_MEDIA = 10
const MAX_TEXT_OVERLAY_CHARACTERS = 160
const STORY_PAGE_SIZE = 30
const SPOTLIGHT_PAGE_SIZE = 12
const SPOTLIGHT_COMMENT_PAGE_SIZE = 50

export function normalizeSkyPicHandle(value: string): string {
  return value.trim().toLowerCase()
}

export function isValidSkyPicHandle(value: string): boolean {
  const handle = normalizeSkyPicHandle(value)
  return (
    handle.length >= 3 && handle.length <= 24 && /^[a-z0-9._]+$/.test(handle)
  )
}

function arrayOrEmpty<T>(value: T[] | null | undefined): T[] {
  return Array.isArray(value) ? value : []
}

function clampDuration(value: number): number {
  return Math.max(1, Math.min(10, Math.round(Number(value) || 1)))
}

function normalizeColor(value: string): string {
  return /^#[0-9a-f]{6}$/i.test(value) ? value : '#ffffff'
}

function uniqueById<T extends { id: string }>(items: T[]): T[] {
  return [...new Map(items.map((item) => [item.id, item])).values()]
}

function messageTime(value: string | null | undefined): number {
  const parsed = value ? Date.parse(value) : 0
  return Number.isFinite(parsed) ? parsed : 0
}

function sortByLastItem(items: SkyPicConversation[]): SkyPicConversation[] {
  return [...items].sort(
    (a, b) =>
      messageTime(b.lastItem?.createdAt) - messageTime(a.lastItem?.createdAt),
  )
}

export const useSkyPicStore = defineStore('skypic', () => {
  const profile = ref<SkyPicProfile | null>(null)
  const blockedProfiles = ref<SkyPicProfileSummary[]>([])
  const friends = ref<SkyPicFriend[]>([])
  const requests = ref<SkyPicFriendRequest[]>([])
  const conversations = ref<SkyPicConversation[]>([])
  const inbox = ref<SkyPicSnap[]>([])
  const stories = ref<SkyPicStory[]>([])
  const spotlights = ref<SkyPicSpotlight[]>([])
  const spotlightComments = ref<SkyPicSpotlightComment[]>([])
  const suggestions = ref<SkyPicProfileSummary[]>([])
  const searchResults = ref<SkyPicProfileSummary[]>([])
  const unreadCount = ref(0)

  const activeFriendshipId = ref<string | null>(null)
  const threadMessages = ref<SkyPicMessage[]>([])
  const threadSnaps = ref<SkyPicSnap[]>([])
  const openedSnap = ref<SkyPicOpenedSnap | null>(null)
  const viewedStory = ref<SkyPicViewedStory | null>(null)
  const storyViewers = ref<SkyPicStoryViewer[]>([])
  const storiesHasMore = ref(true)
  const storyViewersHasMore = ref(true)
  const spotlightsHasMore = ref(true)
  const spotlightCommentsHasMore = ref(true)

  const loading = ref(false)
  const bootstrapPending = ref(false)
  const accountDeletePending = ref(false)
  const profileAbsentRevision = ref(0)
  const threadLoading = ref(false)
  const searchLoading = ref(false)
  const snapOpening = ref(false)
  const storyViewing = ref(false)
  const storiesLoadingMore = ref(false)
  const storyViewersLoadingMore = ref(false)
  const spotlightsLoading = ref(false)
  const spotlightsLoadingMore = ref(false)
  const spotlightCommentsLoading = ref(false)
  const error = ref<string | null>(null)
  let bootstrapRequest = 0
  let bootstrapGeneration = 0
  let searchRequest = 0
  let snapRequest = 0
  let storyRequest = 0
  let storyViewersRequest = 0
  let threadRequest = 0
  let sessionVersion = 0
  let hydrationRevision = 0
  let storyViewersStoryId: string | null = null
  let spotlightCommentsSpotlightId: string | null = null
  const viewedSpotlightIds = new Set<string>()
  let bootstrapInFlight: {
    promise: Promise<boolean>
    session: number
    token: symbol
  } | null = null

  const hasProfile = computed(() => profile.value !== null)
  const incomingRequests = computed(() =>
    requests.value.filter((request) => request.direction === 'incoming'),
  )
  const outgoingRequests = computed(() =>
    requests.value.filter((request) => request.direction === 'outgoing'),
  )
  const activeConversation = computed(
    () =>
      conversations.value.find(
        (conversation) =>
          conversation.friendshipId === activeFriendshipId.value,
      ) ?? null,
  )

  function upsertConversationLastItem(
    friendshipId: string,
    lastItem: SkyPicConversationLastItem,
  ): void {
    let conversation = conversations.value.find(
      (item) => item.friendshipId === friendshipId,
    )
    if (!conversation) {
      const friend = friends.value.find(
        (item) => item.friendshipId === friendshipId,
      )
      if (!friend) return
      conversation = {
        bestStreak: friend.bestStreak,
        friendshipId,
        lastItem: null,
        profile: friend.profile,
        streakCount: friend.streakCount,
        unreadCount: 0,
      }
      conversations.value.push(conversation)
    }
    conversation.lastItem = lastItem
    conversations.value = sortByLastItem(conversations.value)
  }

  function reconcileFriendshipStreak(snap: SkyPicSnap): void {
    const streakCount = Number(snap.streakCount)
    const bestStreak = Number(snap.bestStreak)
    if (
      !Number.isInteger(streakCount) ||
      streakCount < 0 ||
      !Number.isInteger(bestStreak) ||
      bestStreak < streakCount
    ) {
      return
    }
    friends.value = friends.value.map((friend) =>
      friend.friendshipId === snap.friendshipId
        ? { ...friend, bestStreak, streakCount }
        : friend,
    )
    conversations.value = conversations.value.map((conversation) =>
      conversation.friendshipId === snap.friendshipId
        ? { ...conversation, bestStreak, streakCount }
        : conversation,
    )
  }

  function setError(response: NuiResponse<unknown>): void {
    if (response.error === 'request_aborted') return
    error.value = response.success ? null : (response.error ?? 'unknown_error')
  }

  async function sessionCall<T = unknown>(
    endpoint: string,
    data: Record<string, unknown> = {},
  ): Promise<NuiResponse<T>> {
    const requestSession = sessionVersion
    const response = await nuiCall<T>(endpoint, data)
    return requestSession === sessionVersion
      ? response
      : { error: 'request_aborted', success: false }
  }

  function resetSession(): void {
    sessionVersion += 1
    hydrationRevision += 1
    bootstrapInFlight = null
    bootstrapPending.value = false
    bootstrapRequest += 1
    searchRequest += 1
    snapRequest += 1
    storyRequest += 1
    storyViewersRequest += 1
    threadRequest += 1
    storyViewersStoryId = null
    spotlightCommentsSpotlightId = null
    viewedSpotlightIds.clear()
    profile.value = null
    blockedProfiles.value = []
    friends.value = []
    requests.value = []
    conversations.value = []
    inbox.value = []
    stories.value = []
    spotlights.value = []
    spotlightComments.value = []
    suggestions.value = []
    searchResults.value = []
    unreadCount.value = 0
    activeFriendshipId.value = null
    threadMessages.value = []
    threadSnaps.value = []
    openedSnap.value = null
    viewedStory.value = null
    storyViewers.value = []
    storiesHasMore.value = true
    storyViewersHasMore.value = true
    spotlightsHasMore.value = true
    spotlightCommentsHasMore.value = true
    loading.value = false
    threadLoading.value = false
    searchLoading.value = false
    snapOpening.value = false
    storyViewing.value = false
    storiesLoadingMore.value = false
    storyViewersLoadingMore.value = false
    spotlightsLoading.value = false
    spotlightsLoadingMore.value = false
    spotlightCommentsLoading.value = false
    error.value = null
  }

  function hydrate(data: SkyPicBootstrap): void {
    profile.value = data.profile ?? null
    if (!profile.value) {
      resetSession()
      profileAbsentRevision.value += 1
      return
    }

    hydrationRevision += 1

    blockedProfiles.value = arrayOrEmpty(data.blockedProfiles)
    friends.value = arrayOrEmpty(data.friends)
    requests.value = arrayOrEmpty(data.requests)
    conversations.value = sortByLastItem(arrayOrEmpty(data.conversations))
    inbox.value = arrayOrEmpty(data.inbox)
    stories.value = arrayOrEmpty(data.stories)
    storiesHasMore.value = stories.value.length >= STORY_PAGE_SIZE
    suggestions.value = arrayOrEmpty(data.suggestions)
    unreadCount.value = Math.max(0, Number(data.unreadCount) || 0)
  }

  function bootstrap(): Promise<boolean> {
    if (accountDeletePending.value) return Promise.resolve(false)
    const requestSession = sessionVersion
    if (bootstrapInFlight?.session === requestSession) {
      return bootstrapInFlight.promise
    }
    bootstrapGeneration += 1
    const requestId = ++bootstrapRequest
    loading.value = true
    bootstrapPending.value = true
    const token = Symbol('skypic-bootstrap')
    const promise = (async () => {
      try {
        const response = await sessionCall<SkyPicBootstrap>('skypic:bootstrap')
        if (requestId !== bootstrapRequest) return false
        loading.value = false
        setError(response)
        if (!response.success || !response.data) return false
        hydrate(response.data)
        return true
      } finally {
        if (bootstrapInFlight?.token === token) {
          bootstrapInFlight = null
          bootstrapPending.value = false
        }
      }
    })()
    bootstrapInFlight = { promise, session: requestSession, token }
    return promise
  }

  async function refreshAfterMutation(expectedSession: number): Promise<void> {
    const pendingBootstrap = bootstrapInFlight
    if (pendingBootstrap?.session === expectedSession) {
      await pendingBootstrap.promise
    }
    if (expectedSession !== sessionVersion) return
    await bootstrap()
  }

  async function createProfile(
    input: SkyPicCreateProfileInput,
  ): Promise<NuiResponse<SkyPicProfile>> {
    const payload: SkyPicCreateProfileInput = {
      ...(input.avatarMediaId === undefined
        ? {}
        : { avatarMediaId: input.avatarMediaId }),
      ...(input.avatarSeed === undefined
        ? {}
        : { avatarSeed: input.avatarSeed }),
      displayName: input.displayName.trim(),
      handle: normalizeSkyPicHandle(input.handle),
    }
    const response = await sessionCall<SkyPicProfile>(
      'skypic:create-profile',
      payload,
    )
    setError(response)
    if (response.success && response.data) profile.value = response.data
    return response
  }

  async function updateProfile(
    input: SkyPicUpdateProfileInput,
  ): Promise<NuiResponse<SkyPicProfile>> {
    const payload: SkyPicUpdateProfileInput = {
      ...input,
      bio: input.bio.trim(),
      displayName: input.displayName.trim(),
      handle: normalizeSkyPicHandle(input.handle),
    }
    const response = await sessionCall<SkyPicProfile>(
      'skypic:update-profile',
      payload,
    )
    setError(response)
    if (response.success && response.data) profile.value = response.data
    return response
  }

  async function deleteAccount(): Promise<boolean> {
    if (accountDeletePending.value) return false
    accountDeletePending.value = true
    try {
      const response = await sessionCall('skypic:delete-account', {
        confirmed: true,
      })
      setError(response)
      if (!response.success) return false
      resetSession()
      return true
    } finally {
      accountDeletePending.value = false
    }
  }

  async function search(query: string): Promise<boolean> {
    const normalized = query.trim()
    const requestId = ++searchRequest
    if (!normalized) {
      searchResults.value = []
      searchLoading.value = false
      return true
    }

    searchLoading.value = true
    const response = await sessionCall<SkyPicProfileSummary[]>(
      'skypic:search',
      {
        query: normalized,
      },
    )
    if (requestId !== searchRequest) return false
    searchLoading.value = false
    setError(response)
    if (!response.success || !response.data) {
      searchResults.value = []
      return false
    }
    searchResults.value = response.data
    return true
  }

  async function addFriend(
    profileId: string,
  ): Promise<NuiResponse<SkyPicFriendRequest>> {
    const response = await sessionCall<SkyPicFriendRequest>(
      'skypic:add-friend',
      {
        profileId,
      },
    )
    setError(response)
    if (!response.success) return response

    const markOutgoing = (item: SkyPicProfileSummary): SkyPicProfileSummary =>
      item.id === profileId
        ? {
            ...item,
            friendshipId: response.data?.friendshipId ?? item.friendshipId,
            friendshipStatus: 'outgoing',
          }
        : item
    suggestions.value = suggestions.value.map(markOutgoing)
    searchResults.value = searchResults.value.map(markOutgoing)
    if (response.data) {
      requests.value = [
        response.data,
        ...requests.value.filter(
          (request) => request.friendshipId !== response.data?.friendshipId,
        ),
      ]
    }
    return response
  }

  async function respondFriend(
    friendshipId: string,
    accept: boolean,
  ): Promise<NuiResponse<SkyPicFriend>> {
    const response = await sessionCall<SkyPicFriend>('skypic:respond-friend', {
      accept,
      friendshipId,
    })
    setError(response)
    if (!response.success) return response

    const pendingRequest = requests.value.find(
      (request) => request.friendshipId === friendshipId,
    )
    requests.value = requests.value.filter(
      (request) => request.friendshipId !== friendshipId,
    )
    if (accept && response.data) {
      friends.value = [
        ...friends.value.filter(
          (friend) => friend.friendshipId !== response.data?.friendshipId,
        ),
        response.data,
      ]
      if (profile.value) profile.value.friendCount += 1
    }
    const relatedProfileId =
      response.data?.profile.id ?? pendingRequest?.profile.id
    if (relatedProfileId) {
      const updateRelationship = (
        item: SkyPicProfileSummary,
      ): SkyPicProfileSummary =>
        item.id === relatedProfileId
          ? {
              ...item,
              friendshipId:
                accept && response.data ? response.data.friendshipId : null,
              friendshipStatus: accept && response.data ? 'friends' : 'none',
            }
          : item
      suggestions.value = suggestions.value.map(updateRelationship)
      searchResults.value = searchResults.value.map(updateRelationship)
    }
    return response
  }

  async function removeFriend(friendshipId: string): Promise<boolean> {
    const response = await sessionCall('skypic:remove-friend', { friendshipId })
    setError(response)
    if (!response.success) return false

    const removedFriend = friends.value.find(
      (friend) => friend.friendshipId === friendshipId,
    )
    const removedRequest = requests.value.find(
      (request) => request.friendshipId === friendshipId,
    )
    const profileId = removedFriend?.profile.id ?? removedRequest?.profile.id
    friends.value = friends.value.filter(
      (friend) => friend.friendshipId !== friendshipId,
    )
    requests.value = requests.value.filter(
      (request) => request.friendshipId !== friendshipId,
    )
    conversations.value = conversations.value.filter(
      (conversation) => conversation.friendshipId !== friendshipId,
    )
    inbox.value = inbox.value.filter(
      (snap) => snap.friendshipId !== friendshipId,
    )
    const clearRelation = (item: SkyPicProfileSummary): SkyPicProfileSummary =>
      item.id === profileId
        ? { ...item, friendshipId: null, friendshipStatus: 'none' }
        : item
    suggestions.value = suggestions.value.map(clearRelation)
    searchResults.value = searchResults.value.map(clearRelation)
    if (activeFriendshipId.value === friendshipId) closeThread()
    if (profile.value && removedFriend) {
      profile.value.friendCount = Math.max(0, profile.value.friendCount - 1)
    }
    return true
  }

  async function block(profileId: string, blocked = true): Promise<boolean> {
    const response = await sessionCall('skypic:block', { blocked, profileId })
    setError(response)
    if (!response.success) return false
    if (!blocked) {
      blockedProfiles.value = blockedProfiles.value.filter(
        (item) => item.id !== profileId,
      )
      return true
    }

    const removedFriend = friends.value.some(
      (friend) => friend.profile.id === profileId,
    )
    const blockedProfile =
      friends.value.find((friend) => friend.profile.id === profileId)
        ?.profile ??
      requests.value.find((request) => request.profile.id === profileId)
        ?.profile ??
      conversations.value.find(
        (conversation) => conversation.profile.id === profileId,
      )?.profile ??
      suggestions.value.find((item) => item.id === profileId) ??
      searchResults.value.find((item) => item.id === profileId)
    const friendshipIds = new Set([
      ...friends.value
        .filter((friend) => friend.profile.id === profileId)
        .map((friend) => friend.friendshipId),
      ...requests.value
        .filter((request) => request.profile.id === profileId)
        .map((request) => request.friendshipId),
      ...conversations.value
        .filter((conversation) => conversation.profile.id === profileId)
        .map((conversation) => conversation.friendshipId),
    ])
    friends.value = friends.value.filter(
      (friend) => friend.profile.id !== profileId,
    )
    requests.value = requests.value.filter(
      (request) => request.profile.id !== profileId,
    )
    conversations.value = conversations.value.filter(
      (conversation) => conversation.profile.id !== profileId,
    )
    suggestions.value = suggestions.value.filter(
      (item) => item.id !== profileId,
    )
    searchResults.value = searchResults.value.filter(
      (item) => item.id !== profileId,
    )
    stories.value = stories.value.filter(
      (story) => story.author.id !== profileId,
    )
    inbox.value = inbox.value.filter(
      (snap) =>
        snap.sender.id !== profileId && !friendshipIds.has(snap.friendshipId),
    )
    threadSnaps.value = threadSnaps.value.filter(
      (snap) =>
        snap.sender.id !== profileId && !friendshipIds.has(snap.friendshipId),
    )
    if (
      activeFriendshipId.value &&
      friendshipIds.has(activeFriendshipId.value)
    ) {
      closeThread()
    }
    if (profile.value && removedFriend) {
      profile.value.friendCount = Math.max(0, profile.value.friendCount - 1)
    }
    if (blockedProfile) {
      blockedProfiles.value = uniqueById([
        {
          ...blockedProfile,
          friendshipId: null,
          friendshipStatus: 'none',
        },
        ...blockedProfiles.value,
      ])
    }
    return true
  }

  function updateSnapMetadata(
    snapId: string,
    fields: Pick<SkyPicSnap, 'openedAt' | 'replayedAt'>,
  ): SkyPicSnap | null {
    let previous: SkyPicSnap | null = null
    const update = (snap: SkyPicSnap): SkyPicSnap => {
      if (snap.id !== snapId) return snap
      previous ??= snap
      return { ...snap, ...fields }
    }
    inbox.value = inbox.value.map(update)
    threadSnaps.value = threadSnaps.value.map(update)
    return previous
  }

  async function sendSnap(
    input: SkyPicSendSnapInput,
  ): Promise<NuiResponse<SkyPicSnap[]>> {
    const common = {
      allowReplay: input.allowReplay,
      caption: input.caption.trim(),
      durationSeconds: clampDuration(input.durationSeconds),
      overlayColor: normalizeColor(input.overlayColor),
      recipientIds: [...new Set(input.recipientIds.filter(Boolean))].slice(
        0,
        20,
      ),
      textOverlay: Array.from(input.textOverlay.trim())
        .slice(0, MAX_TEXT_OVERLAY_CHARACTERS)
        .join(''),
    }
    const payload: SkyPicSendSnapInput = Array.isArray(input.mediaIds)
      ? {
          ...common,
          mediaIds: [...new Set(input.mediaIds)]
            .filter(
              (mediaId) => Number.isInteger(mediaId) && Number(mediaId) > 0,
            )
            .slice(0, MAX_SNAP_MEDIA),
        }
      : {
          ...common,
          mediaId: input.mediaId!,
          mediaType: input.mediaType!,
        }
    const requestHydrationRevision = hydrationRevision
    const requestBootstrapGeneration = bootstrapGeneration
    const requestSession = sessionVersion
    const response = await sessionCall<SkyPicSnap[]>(
      'skypic:send-snap',
      payload,
    )
    setError(response)
    if (response.success && response.data) {
      const active = activeFriendshipId.value
      const canReconcileResponse =
        requestSession === sessionVersion &&
        requestHydrationRevision === hydrationRevision &&
        requestBootstrapGeneration === bootstrapGeneration &&
        bootstrapInFlight?.session !== requestSession
      threadSnaps.value = uniqueById([
        ...threadSnaps.value,
        ...response.data.filter((snap) => snap.friendshipId === active),
      ])
      if (canReconcileResponse) {
        for (const snap of response.data) {
          upsertConversationLastItem(snap.friendshipId, {
            createdAt: snap.createdAt,
            direction: snap.direction,
            id: snap.id,
            openedAt: snap.openedAt,
            type: snap.type,
          })
          reconcileFriendshipStreak(snap)
        }
        if (profile.value && response.data.length) {
          const serverScore = response.data.find(
            (snap) => snap.sender.id === profile.value?.id,
          )?.sender.snapScore
          profile.value.snapScore =
            serverScore ?? profile.value.snapScore + response.data.length
        }
      } else if (requestSession === sessionVersion) {
        await refreshAfterMutation(requestSession)
      }
    }
    return response
  }

  async function openSnap(
    snapId: string,
  ): Promise<NuiResponse<SkyPicOpenedSnap>> {
    if (snapOpening.value) {
      return { error: 'snap_open_in_progress', success: false }
    }
    const requestId = ++snapRequest
    snapOpening.value = true
    try {
      const response = await sessionCall<SkyPicOpenedSnap>('skypic:open-snap', {
        snapId,
      })
      if (requestId !== snapRequest) {
        return { error: 'request_aborted', success: false }
      }
      setError(response)
      if (!response.success || !response.data) return response

      const previous = updateSnapMetadata(snapId, {
        openedAt: response.data.openedAt,
        replayedAt: response.data.replayedAt,
      })
      if (previous && !previous.openedAt && previous.direction === 'received') {
        unreadCount.value = Math.max(0, unreadCount.value - 1)
        const conversation = conversations.value.find(
          (item) => item.friendshipId === previous.friendshipId,
        )
        if (conversation) {
          conversation.unreadCount = Math.max(0, conversation.unreadCount - 1)
          if (conversation.lastItem?.id === snapId) {
            conversation.lastItem.openedAt = response.data.openedAt
          }
        }
        if (profile.value) profile.value.snapScore += 1
      }
      openedSnap.value = response.data
      return response
    } finally {
      if (requestId === snapRequest) snapOpening.value = false
    }
  }

  async function replaySnap(
    snapId: string,
  ): Promise<NuiResponse<SkyPicOpenedSnap>> {
    if (snapOpening.value) {
      return { error: 'snap_open_in_progress', success: false }
    }
    const requestId = ++snapRequest
    snapOpening.value = true
    try {
      const response = await sessionCall<SkyPicOpenedSnap>(
        'skypic:replay-snap',
        {
          snapId,
        },
      )
      if (requestId !== snapRequest) {
        return { error: 'request_aborted', success: false }
      }
      setError(response)
      if (response.success && response.data) {
        updateSnapMetadata(snapId, {
          openedAt: response.data.openedAt,
          replayedAt: response.data.replayedAt,
        })
        openedSnap.value = response.data
      }
      return response
    } finally {
      if (requestId === snapRequest) snapOpening.value = false
    }
  }

  function clearOpenedSnap(): void {
    openedSnap.value = null
  }

  async function loadStories(): Promise<boolean> {
    const response = await sessionCall<SkyPicStory[]>('skypic:stories', {
      offset: 0,
    })
    setError(response)
    if (!response.success || !response.data) return false
    stories.value = response.data
    storiesHasMore.value = response.data.length >= STORY_PAGE_SIZE
    return true
  }

  async function loadMoreStories(): Promise<boolean> {
    if (!storiesHasMore.value || storiesLoadingMore.value) return true
    storiesLoadingMore.value = true
    const response = await sessionCall<SkyPicStory[]>('skypic:stories', {
      offset: stories.value.length,
    })
    storiesLoadingMore.value = false
    setError(response)
    if (!response.success || !response.data) return false
    stories.value = uniqueById([...stories.value, ...response.data])
    storiesHasMore.value = response.data.length >= STORY_PAGE_SIZE
    return true
  }

  async function publishStory(
    input: SkyPicPublishStoryInput,
  ): Promise<NuiResponse<SkyPicStory>> {
    const payload: SkyPicPublishStoryInput = {
      ...input,
      caption: input.caption.trim(),
      durationSeconds: clampDuration(input.durationSeconds),
      overlayColor: normalizeColor(input.overlayColor),
      textOverlay: Array.from(input.textOverlay.trim())
        .slice(0, MAX_TEXT_OVERLAY_CHARACTERS)
        .join(''),
    }
    const response = await sessionCall<SkyPicStory>(
      'skypic:publish-story',
      payload,
    )
    setError(response)
    if (response.success && response.data) {
      stories.value = uniqueById([response.data, ...stories.value])
      if (profile.value) {
        profile.value.snapScore =
          response.data.author.id === profile.value.id
            ? response.data.author.snapScore
            : profile.value.snapScore + 1
      }
    }
    return response
  }

  async function loadSpotlights(): Promise<boolean> {
    spotlightsLoading.value = true
    const response = await sessionCall<SkyPicSpotlight[]>(
      'skypic:spotlight-feed',
      { offset: 0 },
    )
    spotlightsLoading.value = false
    setError(response)
    if (!response.success || !response.data) return false
    spotlights.value = response.data
    spotlightsHasMore.value = response.data.length >= SPOTLIGHT_PAGE_SIZE
    return true
  }

  async function loadMoreSpotlights(): Promise<boolean> {
    if (!spotlightsHasMore.value || spotlightsLoadingMore.value) return true
    spotlightsLoadingMore.value = true
    const response = await sessionCall<SkyPicSpotlight[]>(
      'skypic:spotlight-feed',
      { offset: spotlights.value.length },
    )
    spotlightsLoadingMore.value = false
    setError(response)
    if (!response.success || !response.data) return false
    spotlights.value = uniqueById([...spotlights.value, ...response.data])
    spotlightsHasMore.value = response.data.length >= SPOTLIGHT_PAGE_SIZE
    return true
  }

  async function publishSpotlight(
    input: SkyPicPublishSpotlightInput,
  ): Promise<NuiResponse<SkyPicSpotlight>> {
    const payload: SkyPicPublishSpotlightInput = {
      ...input,
      adHeadline: Array.from(input.adHeadline.trim()).slice(0, 80).join(''),
      caption: input.caption.trim(),
      durationSeconds: clampDuration(input.durationSeconds),
      mediaType: 'video',
      overlayColor: normalizeColor(input.overlayColor),
      textOverlay: Array.from(input.textOverlay.trim())
        .slice(0, MAX_TEXT_OVERLAY_CHARACTERS)
        .join(''),
    }
    const response = await sessionCall<SkyPicSpotlight>(
      'skypic:publish-spotlight',
      payload,
    )
    setError(response)
    if (response.success && response.data) {
      spotlights.value = uniqueById([response.data, ...spotlights.value])
    }
    return response
  }

  async function viewSpotlight(spotlightId: string): Promise<boolean> {
    if (viewedSpotlightIds.has(spotlightId)) return true
    viewedSpotlightIds.add(spotlightId)
    const response = await sessionCall<{ viewCount: number }>(
      'skypic:view-spotlight',
      { spotlightId },
    )
    setError(response)
    if (!response.success || !response.data) {
      viewedSpotlightIds.delete(spotlightId)
      return false
    }
    spotlights.value = spotlights.value.map((spotlight) =>
      spotlight.id === spotlightId
        ? {
            ...spotlight,
            isViewed: true,
            viewCount: Math.max(
              0,
              Number(response.data?.viewCount) || spotlight.viewCount,
            ),
          }
        : spotlight,
    )
    return true
  }

  async function likeSpotlight(
    spotlightId: string,
    active: boolean,
  ): Promise<boolean> {
    const response = await sessionCall<{ active: boolean; likeCount: number }>(
      'skypic:like-spotlight',
      { active, spotlightId },
    )
    setError(response)
    if (!response.success || !response.data) return false
    spotlights.value = spotlights.value.map((spotlight) =>
      spotlight.id === spotlightId
        ? {
            ...spotlight,
            isLiked: response.data?.active ?? active,
            likeCount: Math.max(0, Number(response.data?.likeCount) || 0),
          }
        : spotlight,
    )
    return true
  }

  async function loadSpotlightComments(spotlightId: string): Promise<boolean> {
    spotlightCommentsLoading.value = true
    const response = await sessionCall<SkyPicSpotlightComment[]>(
      'skypic:spotlight-comments',
      { offset: 0, spotlightId },
    )
    spotlightCommentsLoading.value = false
    setError(response)
    if (!response.success || !response.data) return false
    spotlightCommentsSpotlightId = spotlightId
    spotlightComments.value = response.data
    spotlightCommentsHasMore.value =
      response.data.length >= SPOTLIGHT_COMMENT_PAGE_SIZE
    return true
  }

  async function loadMoreSpotlightComments(
    spotlightId: string,
  ): Promise<boolean> {
    if (
      spotlightCommentsSpotlightId !== spotlightId ||
      !spotlightCommentsHasMore.value ||
      spotlightCommentsLoading.value
    ) {
      return true
    }
    spotlightCommentsLoading.value = true
    const response = await sessionCall<SkyPicSpotlightComment[]>(
      'skypic:spotlight-comments',
      { offset: spotlightComments.value.length, spotlightId },
    )
    spotlightCommentsLoading.value = false
    setError(response)
    if (!response.success || !response.data) return false
    spotlightComments.value = uniqueById([
      ...spotlightComments.value,
      ...response.data,
    ])
    spotlightCommentsHasMore.value =
      response.data.length >= SPOTLIGHT_COMMENT_PAGE_SIZE
    return true
  }

  async function commentSpotlight(
    spotlightId: string,
    body: string,
  ): Promise<boolean> {
    const response = await sessionCall<SkyPicSpotlightComment>(
      'skypic:comment-spotlight',
      { body: Array.from(body.trim()).slice(0, 500).join(''), spotlightId },
    )
    setError(response)
    if (!response.success || !response.data) return false
    spotlightCommentsSpotlightId = spotlightId
    spotlightComments.value = uniqueById([
      response.data,
      ...spotlightComments.value,
    ])
    spotlights.value = spotlights.value.map((spotlight) =>
      spotlight.id === spotlightId
        ? { ...spotlight, commentCount: spotlight.commentCount + 1 }
        : spotlight,
    )
    return true
  }

  async function deleteSpotlightComment(commentId: string): Promise<boolean> {
    const comment = spotlightComments.value.find(
      (item) => item.id === commentId,
    )
    const response = await sessionCall('skypic:delete-spotlight-comment', {
      commentId,
    })
    setError(response)
    if (!response.success) return false
    spotlightComments.value = spotlightComments.value.filter(
      (item) => item.id !== commentId,
    )
    if (comment) {
      spotlights.value = spotlights.value.map((spotlight) =>
        spotlight.id === comment.spotlightId
          ? {
              ...spotlight,
              commentCount: Math.max(0, spotlight.commentCount - 1),
            }
          : spotlight,
      )
    }
    return true
  }

  async function removeSpotlight(spotlightId: string): Promise<boolean> {
    const response = await sessionCall('skypic:remove-spotlight', {
      spotlightId,
    })
    setError(response)
    if (!response.success) return false
    spotlights.value = spotlights.value.filter(
      (spotlight) => spotlight.id !== spotlightId,
    )
    return true
  }

  async function reportSpotlight(
    spotlightId: string,
    reason: SkyPicSpotlightReportReason,
    details = '',
  ): Promise<boolean> {
    const response = await sessionCall('skypic:report-spotlight', {
      details: Array.from(details.trim()).slice(0, 500).join(''),
      reason,
      spotlightId,
    })
    setError(response)
    if (!response.success) return false
    spotlights.value = spotlights.value.filter(
      (spotlight) => spotlight.id !== spotlightId,
    )
    return true
  }

  async function viewStory(
    storyId: string,
  ): Promise<NuiResponse<SkyPicViewedStory>> {
    if (storyViewing.value) {
      return { error: 'story_view_in_progress', success: false }
    }
    const requestId = ++storyRequest
    storyViewing.value = true
    try {
      const response = await sessionCall<SkyPicViewedStory>(
        'skypic:view-story',
        { storyId },
      )
      if (requestId !== storyRequest) {
        return { error: 'request_aborted', success: false }
      }
      setError(response)
      if (!response.success || !response.data) return response

      stories.value = stories.value.map((story) =>
        story.id === storyId
          ? {
              ...story,
              seen: true,
              viewCount:
                story.isOwner || story.seen
                  ? story.viewCount
                  : story.viewCount + 1,
            }
          : story,
      )
      viewedStory.value = response.data
      return response
    } finally {
      if (requestId === storyRequest) storyViewing.value = false
    }
  }

  function clearViewedStory(): void {
    storyRequest += 1
    storyViewing.value = false
    viewedStory.value = null
  }

  async function loadStoryViewers(storyId: string): Promise<boolean> {
    const requestId = ++storyViewersRequest
    const response = await sessionCall<SkyPicStoryViewer[]>(
      'skypic:story-viewers',
      { offset: 0, storyId },
    )
    if (requestId !== storyViewersRequest) return false
    setError(response)
    if (!response.success || !response.data) return false
    storyViewers.value = response.data
    storyViewersStoryId = storyId
    storyViewersHasMore.value = response.data.length >= STORY_PAGE_SIZE
    return true
  }

  async function loadMoreStoryViewers(storyId: string): Promise<boolean> {
    if (
      storyViewersStoryId !== storyId ||
      !storyViewersHasMore.value ||
      storyViewersLoadingMore.value
    ) {
      return true
    }
    storyViewersLoadingMore.value = true
    const requestId = storyViewersRequest
    const response = await sessionCall<SkyPicStoryViewer[]>(
      'skypic:story-viewers',
      { offset: storyViewers.value.length, storyId },
    )
    storyViewersLoadingMore.value = false
    if (requestId !== storyViewersRequest || storyViewersStoryId !== storyId) {
      return false
    }
    setError(response)
    if (!response.success || !response.data) return false
    storyViewers.value = uniqueById([...storyViewers.value, ...response.data])
    storyViewersHasMore.value = response.data.length >= STORY_PAGE_SIZE
    return true
  }

  async function removeStory(storyId: string): Promise<boolean> {
    const response = await sessionCall('skypic:remove-story', { storyId })
    setError(response)
    if (!response.success) return false
    stories.value = stories.value.filter((story) => story.id !== storyId)
    if (viewedStory.value?.id === storyId) clearViewedStory()
    storyViewers.value = []
    return true
  }

  async function openThread(friendshipId: string): Promise<boolean> {
    const requestId = ++threadRequest
    threadLoading.value = true
    const response = await sessionCall<SkyPicThread>('skypic:thread', {
      friendshipId,
    })
    if (requestId !== threadRequest) return false
    threadLoading.value = false
    setError(response)
    if (!response.success || !response.data) return false
    activeFriendshipId.value = friendshipId
    threadMessages.value = arrayOrEmpty(response.data.messages)
    threadSnaps.value = arrayOrEmpty(response.data.snaps)
    return true
  }

  async function refreshActiveThread(): Promise<boolean> {
    const friendshipId = activeFriendshipId.value
    if (!friendshipId) return false
    return openThread(friendshipId)
  }

  function closeThread(): void {
    threadRequest += 1
    activeFriendshipId.value = null
    threadMessages.value = []
    threadSnaps.value = []
    threadLoading.value = false
  }

  async function sendMessage(
    friendshipId: string,
    body: string,
    storyId?: string,
  ): Promise<NuiResponse<SkyPicMessage>> {
    const trimmed = Array.from(body.trim())
      .slice(0, MAX_MESSAGE_CHARACTERS)
      .join('')
    if (!trimmed) return { error: 'message_empty', success: false }
    const clientId = `pending-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`
    const optimistic: SkyPicMessage = {
      body: trimmed,
      clientId,
      createdAt: new Date().toISOString(),
      deliveryStatus: 'sending',
      direction: 'sent',
      friendshipId,
      id: clientId,
      readAt: null,
      savedAt: null,
      type: 'text',
    }
    if (activeFriendshipId.value === friendshipId) {
      threadMessages.value.push(optimistic)
    }

    const response = await sessionCall<SkyPicMessage>('skypic:send-message', {
      body: trimmed,
      friendshipId,
      ...(storyId ? { storyId } : {}),
    })
    setError(response)
    const index = threadMessages.value.findIndex(
      (message) => message.clientId === clientId,
    )
    if (!response.success || !response.data) {
      if (index >= 0) threadMessages.value[index].deliveryStatus = 'failed'
      return response
    }

    if (index >= 0) {
      threadMessages.value[index] = {
        ...response.data,
        clientId,
        deliveryStatus: 'delivered',
      }
    }
    upsertConversationLastItem(friendshipId, {
      body: response.data.body,
      createdAt: response.data.createdAt,
      direction: response.data.direction,
      id: response.data.id,
      openedAt: null,
      type: 'text',
    })
    return response
  }

  async function markThread(friendshipId: string): Promise<boolean> {
    const response = await sessionCall('skypic:mark-thread', { friendshipId })
    setError(response)
    if (!response.success) return false
    const conversation = conversations.value.find(
      (item) => item.friendshipId === friendshipId,
    )
    if (conversation) {
      const unopenedSnapIds = new Set(
        [...inbox.value, ...threadSnaps.value]
          .filter(
            (snap) =>
              snap.friendshipId === friendshipId &&
              snap.direction === 'received' &&
              !snap.openedAt,
          )
          .map((snap) => snap.id),
      )
      const remainingSnapCount = unopenedSnapIds.size
      const markedTextCount = Math.max(
        0,
        conversation.unreadCount - remainingSnapCount,
      )
      unreadCount.value = Math.max(0, unreadCount.value - markedTextCount)
      conversation.unreadCount = remainingSnapCount
    }
    const readAt = new Date().toISOString()
    threadMessages.value = threadMessages.value.map((message) =>
      message.direction === 'received' && !message.readAt
        ? { ...message, readAt }
        : message,
    )
    return true
  }

  async function saveMessage(
    messageId: string,
    saved: boolean,
  ): Promise<boolean> {
    const response = await sessionCall<SkyPicMessage>('skypic:save-message', {
      messageId,
      saved,
    })
    setError(response)
    if (!response.success) return false
    threadMessages.value = threadMessages.value.map((message) =>
      message.id === messageId
        ? (response.data ?? {
            ...message,
            savedAt: saved ? new Date().toISOString() : null,
          })
        : message,
    )
    return true
  }

  async function deleteMessage(
    messageId: string,
    forEveryone = false,
  ): Promise<boolean> {
    const response = await sessionCall('skypic:delete-message', {
      forEveryone,
      messageId,
    })
    setError(response)
    if (!response.success) return false
    const deletedMessage = threadMessages.value.find(
      (message) => message.id === messageId,
    )
    threadMessages.value = threadMessages.value.filter(
      (message) => message.id !== messageId,
    )
    if (!deletedMessage) return true

    const conversation = conversations.value.find(
      (item) => item.friendshipId === deletedMessage.friendshipId,
    )
    if (conversation?.lastItem?.id === messageId) {
      const remainingItems: SkyPicConversationLastItem[] = [
        ...threadMessages.value
          .filter(
            (message) => message.friendshipId === deletedMessage.friendshipId,
          )
          .map((message) => ({
            body: message.body,
            createdAt: message.createdAt,
            direction: message.direction,
            id: message.id,
            openedAt: null,
            type: 'text' as const,
          })),
        ...threadSnaps.value
          .filter((snap) => snap.friendshipId === deletedMessage.friendshipId)
          .map((snap) => ({
            createdAt: snap.createdAt,
            direction: snap.direction,
            id: snap.id,
            openedAt: snap.openedAt,
            type: snap.type,
          })),
      ]
      conversation.lastItem =
        remainingItems.sort(
          (a, b) => messageTime(b.createdAt) - messageTime(a.createdAt),
        )[0] ?? null
      conversations.value = sortByLastItem(conversations.value)
    }
    return true
  }

  return {
    accountDeletePending,
    activeConversation,
    activeFriendshipId,
    addFriend,
    block,
    blockedProfiles,
    bootstrap,
    bootstrapPending,
    clearOpenedSnap,
    clearViewedStory,
    closeThread,
    conversations,
    commentSpotlight,
    createProfile,
    deleteAccount,
    deleteMessage,
    deleteSpotlightComment,
    error,
    friends,
    hasProfile,
    inbox,
    incomingRequests,
    loadStories,
    loadSpotlights,
    loadMoreSpotlights,
    loadSpotlightComments,
    loadMoreSpotlightComments,
    loadStoryViewers,
    loadMoreStories,
    loadMoreStoryViewers,
    loading,
    markThread,
    openSnap,
    openedSnap,
    openThread,
    outgoingRequests,
    profile,
    profileAbsentRevision,
    publishSpotlight,
    publishStory,
    refreshActiveThread,
    removeFriend,
    removeSpotlight,
    removeStory,
    reportSpotlight,
    replaySnap,
    resetSession,
    requests,
    respondFriend,
    saveMessage,
    search,
    searchLoading,
    searchResults,
    sendMessage,
    sendSnap,
    snapOpening,
    spotlights,
    spotlightsHasMore,
    spotlightsLoading,
    spotlightsLoadingMore,
    spotlightComments,
    spotlightCommentsHasMore,
    spotlightCommentsLoading,
    stories,
    storiesHasMore,
    storiesLoadingMore,
    storyViewers,
    storyViewersHasMore,
    storyViewersLoadingMore,
    storyViewing,
    suggestions,
    threadLoading,
    threadMessages,
    threadSnaps,
    unreadCount,
    updateProfile,
    likeSpotlight,
    viewSpotlight,
    viewedStory,
    viewStory,
  }
})
