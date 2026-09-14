import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useFlipTokStore } from '@/stores/fliptok'
import type {
  FlipTokActivity,
  FlipTokComment,
  FlipTokProfile,
  FlipTokVideo,
} from '@/types/fliptok'
import { nuiCall } from '@/utils/nui'

vi.mock('@/utils/nui', () => ({
  nuiCall: vi.fn(),
}))

const profile: FlipTokProfile = {
  account_type: 'person',
  avatar_media_id: null,
  avatar_url: null,
  bio: '',
  display_name: 'Nova',
  followers: 1,
  following: 2,
  handle: 'nova',
  id: 7,
  is_following: false,
  is_owner: true,
  verified: false,
  video_count: 1,
}

const video: FlipTokVideo = {
  avatar_url: null,
  caption: 'Los Santos',
  comment_count: 1,
  comments_enabled: true,
  created_at: 1,
  display_name: 'Nova',
  handle: 'nova',
  id: 'video-1',
  is_following: false,
  is_liked: false,
  is_owner: true,
  is_saved: false,
  like_count: 2,
  location: '',
  cover_time_ms: 0,
  music_artist: '',
  music_source: '',
  music_title: '',
  music_track: '',
  music_url: '',
  music_video_id: '',
  music_volume: 0,
  original_volume: 100,
  profile_id: 7,
  share_count: 0,
  trim_end_ms: null,
  trim_start_ms: 0,
  url: 'https://example.com/video.webm',
  verified: false,
  view_count: 3,
}

const comment: FlipTokComment = {
  avatar_url: null,
  body: 'Nice',
  created_at: 1,
  display_name: 'Nova',
  handle: 'nova',
  id: 'comment-1',
  is_liked: false,
  like_count: 0,
  parent_id: null,
  profile_id: 7,
  reply_to_handle: null,
  verified: false,
}

const activity: FlipTokActivity = {
  avatar_url: null,
  created_at: 1,
  display_name: 'Nova',
  handle: 'nova',
  id: 'activity-1',
  kind: 'follow',
  profile_id: 7,
  read_at: null,
  verified: false,
  video_id: null,
}

describe('FlipTok verification updates', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.mocked(nuiCall).mockReset()
  })

  it('discovers profiles even when there are no published videos', async () => {
    vi.mocked(nuiCall)
      .mockResolvedValueOnce({ success: true, data: [] })
      .mockResolvedValueOnce({ success: true, data: [profile] })
    const store = useFlipTokStore()
    await store.discover('')
    expect(nuiCall).toHaveBeenCalledWith('fliptok:profiles', { search: '' })
    expect(store.searchProfiles).toEqual([profile])
    expect(store.searchResults).toEqual([])
    expect(store.searchError).toBe(false)
  })

  it('updates the badge everywhere the profile is already visible', () => {
    const store = useFlipTokStore()
    store.profile = { ...profile }
    store.feed = [{ ...video }]
    store.searchResults = [{ ...video }]
    store.comments = [{ ...comment }]
    store.activities = [{ ...activity }]

    store.applyVerification(7, true)

    expect(store.profile.verified).toBe(true)
    expect(store.feed[0].verified).toBe(true)
    expect(store.searchResults[0].verified).toBe(true)
    expect(store.comments[0].verified).toBe(true)
    expect(store.activities[0].verified).toBe(true)
  })

  it('does not alter another profile', () => {
    const store = useFlipTokStore()
    store.feed = [{ ...video }]

    store.applyVerification(99, true)

    expect(store.feed[0].verified).toBe(false)
  })

  it('removes a blocked creator from every visible surface', async () => {
    vi.mocked(nuiCall).mockResolvedValue({ success: true })
    const store = useFlipTokStore()
    store.feed = [{ ...video }]
    store.searchResults = [{ ...video }]
    store.profileVideos = [{ ...video }]
    store.comments = [{ ...comment }]
    store.activities = [{ ...activity }]
    store.viewedProfile = { ...profile }

    expect(await store.blockProfile(7)).toBe(true)
    expect(store.feed).toEqual([])
    expect(store.searchResults).toEqual([])
    expect(store.profileVideos).toEqual([])
    expect(store.comments).toEqual([])
    expect(store.activities).toEqual([])
    expect(store.viewedProfile).toBeNull()
  })

  it('keeps the app signed out when bootstrap has no FlipTok session', async () => {
    vi.mocked(nuiCall).mockResolvedValue({
      success: true,
      data: { authenticated: false, musicTracks: [] },
    })
    const store = useFlipTokStore()

    expect(await store.bootstrap()).toBe(true)
    expect(store.authenticated).toBe(false)
    expect(store.profile).toBeNull()
    expect(store.feed).toEqual([])
  })

  it('loads the profile after a successful login', async () => {
    vi.mocked(nuiCall)
      .mockResolvedValueOnce({ success: true })
      .mockResolvedValueOnce({
        success: true,
        data: {
          authenticated: true,
          feed: { hasMore: false, items: [{ ...video }], offset: 0 },
          isAdmin: false,
          musicTracks: [],
          profile: { ...profile },
        },
      })
    const store = useFlipTokStore()

    expect((await store.login('nova', 'password123')).success).toBe(true)
    expect(store.authenticated).toBe(true)
    expect(store.profile?.handle).toBe('nova')
    expect(nuiCall).toHaveBeenNthCalledWith(1, 'fliptok:login', {
      handle: 'nova',
      password: 'password123',
    })
  })

  it('clears the complete local session after logout', async () => {
    vi.mocked(nuiCall).mockResolvedValue({ success: true })
    const store = useFlipTokStore()
    store.authenticated = true
    store.profile = { ...profile }
    store.feed = [{ ...video }]
    store.activities = [{ ...activity }]

    expect((await store.logout()).success).toBe(true)
    expect(nuiCall).toHaveBeenCalledWith('fliptok:logout')
    expect(store.authenticated).toBe(false)
    expect(store.profile).toBeNull()
    expect(store.feed).toEqual([])
    expect(store.activities).toEqual([])
  })

  it('loads an exact shared video by id', async () => {
    vi.mocked(nuiCall).mockResolvedValue({ success: true, data: { ...video } })
    const store = useFlipTokStore()

    expect(await store.loadVideo(video.id)).toEqual(video)
    expect(nuiCall).toHaveBeenCalledWith('fliptok:video', { id: video.id })
  })

  it('likes comments optimistically and restores them on failure', async () => {
    vi.mocked(nuiCall).mockResolvedValue({ success: false })
    const store = useFlipTokStore()
    const visibleComment = { ...comment }

    await store.reactComment(visibleComment)

    expect(nuiCall).toHaveBeenCalledWith('fliptok:comment-react', {
      active: true,
      id: visibleComment.id,
    })
    expect(visibleComment.is_liked).toBe(false)
    expect(visibleComment.like_count).toBe(0)
  })

  it('loads the selected follower list', async () => {
    const follower = { ...profile, id: 8, is_owner: false }
    vi.mocked(nuiCall).mockResolvedValue({
      success: true,
      data: [follower],
    })
    const store = useFlipTokStore()

    expect(await store.loadConnections(profile.id, 'followers')).toBe(true)
    expect(store.connections).toEqual([follower])
    expect(nuiCall).toHaveBeenCalledWith('fliptok:connections', {
      mode: 'followers',
      profileId: profile.id,
    })
  })

  it('marks every account in the own following list as already followed', async () => {
    const followedProfile = {
      ...profile,
      id: 8,
      is_following: false,
      is_owner: false,
    }
    vi.mocked(nuiCall).mockResolvedValue({
      success: true,
      data: [followedProfile],
    })
    const store = useFlipTokStore()
    store.profile = { ...profile }

    expect(await store.loadConnections(profile.id, 'following')).toBe(true)
    expect(store.connections[0]?.is_following).toBe(true)
  })

  it('does not show a follow state when the server rejects it', async () => {
    vi.mocked(nuiCall).mockResolvedValue({ success: false })
    const store = useFlipTokStore()
    const creatorVideo = { ...video, is_owner: false, profile_id: 8 }
    store.feed = [creatorVideo]

    expect(await store.follow(creatorVideo)).toBe(false)
    expect(creatorVideo.is_following).toBe(false)
  })

  it('removes an owned video from every local surface after deletion', async () => {
    vi.mocked(nuiCall).mockResolvedValue({ success: true })
    const store = useFlipTokStore()
    store.profile = { ...profile, video_count: 1 }
    store.feed = [{ ...video }]
    store.searchResults = [{ ...video }]
    store.profileVideos = [{ ...video }]

    expect(await store.deleteVideo(video.id)).toBe(true)
    expect(nuiCall).toHaveBeenCalledWith('fliptok:delete', { id: video.id })
    expect(store.feed).toEqual([])
    expect(store.searchResults).toEqual([])
    expect(store.profileVideos).toEqual([])
    expect(store.profile.video_count).toBe(0)
  })
})
