import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { usePicstagramStore } from '@/stores/picstagram'
import type {
  PicstagramActivity,
  PicstagramComment,
  PicstagramPost,
  PicstagramProfile,
  PicstagramStory,
} from '@/types/picstagram'
import { nuiCall } from '@/utils/nui'

vi.mock('@/utils/nui', () => ({
  nuiCall: vi.fn(),
}))

const profile: PicstagramProfile = {
  avatar_media_id: null,
  avatar_url: null,
  bio: 'City light collector.',
  display_name: 'Nova',
  follow_status: null,
  followers: 12,
  following: 4,
  handle: 'nova',
  id: 'profile-1',
  is_following: false,
  is_owner: true,
  is_requested: false,
  locked: false,
  post_count: 1,
  private: false,
  status: 'active',
  verified: false,
}

const post: PicstagramPost = {
  avatar_url: null,
  caption: 'Los Santos after rain.',
  comment_count: 1,
  comments_enabled: true,
  created_at: 1,
  display_name: 'Nova',
  handle: 'nova',
  id: 'post-1',
  is_liked: false,
  is_owner: true,
  is_saved: false,
  like_count: 2,
  location: 'Downtown',
  media: [
    {
      id: 1,
      media_type: 'photo',
      position: 0,
      url: 'https://example.com/photo.webp',
    },
  ],
  private: false,
  profile_id: profile.id,
  verified: false,
}

const comment: PicstagramComment = {
  avatar_url: null,
  body: 'Beautiful.',
  created_at: 1,
  display_name: 'Nova',
  handle: 'nova',
  id: 'comment-1',
  is_liked: false,
  is_owner: true,
  like_count: 0,
  parent_id: null,
  profile_id: profile.id,
  reply_to_handle: null,
  verified: false,
}

const activity: PicstagramActivity = {
  avatar_url: null,
  created_at: 1,
  display_name: 'Nova',
  handle: 'nova',
  id: 'activity-1',
  kind: 'follow',
  post_id: null,
  post_url: null,
  profile_id: profile.id,
  read_at: null,
  verified: false,
}

const story: PicstagramStory = {
  avatar_url: null,
  body: 'Tonight.',
  created_at: 1,
  display_name: 'Nova',
  expires_at: 2,
  handle: 'nova',
  id: 'story-1',
  is_owner: true,
  media_type: 'photo',
  profile_id: profile.id,
  seen: true,
  url: 'https://example.com/story.webp',
  verified: false,
  view_count: 3,
}

describe('Picstagram store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.mocked(nuiCall).mockReset()
  })

  it('loads people suggestions even without a search term', async () => {
    vi.mocked(nuiCall).mockResolvedValueOnce({
      success: true,
      data: { profiles: [profile], posts: [] },
    })
    const store = usePicstagramStore()
    expect(await store.search('')).toBe(true)
    expect(nuiCall).toHaveBeenCalledWith('picstagram:search', { search: '' })
    expect(store.searchProfiles).toEqual([profile])
  })

  it('keeps newer search results when an older request finishes late', async () => {
    const store = usePicstagramStore()
    let finish!: (value: Awaited<ReturnType<typeof nuiCall>>) => void
    vi.mocked(nuiCall).mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          finish = resolve
        }),
    )
    const older = store.search('old')
    vi.mocked(nuiCall).mockResolvedValueOnce({
      success: true,
      data: { profiles: [profile], posts: [] },
    })
    await store.search('Nova')
    finish({ success: true, data: { profiles: [], posts: [] } })
    await older
    expect(store.searchProfiles).toEqual([profile])
  })

  it('updates verification on every visible surface', () => {
    const store = usePicstagramStore()
    store.profile = { ...profile }
    store.feed = [{ ...post }]
    store.explore = [{ ...post }]
    store.profilePosts = [{ ...post }]
    store.saved = [{ ...post }]
    store.searchPosts = [{ ...post }]
    store.comments = [{ ...comment }]
    store.activities = [{ ...activity }]

    store.applyVerification(profile.id, true)

    expect(store.profile.verified).toBe(true)
    expect(
      store
        .allPostCollections()
        .flat()
        .every((item) => item.verified),
    ).toBe(true)
    expect(store.comments[0].verified).toBe(true)
    expect(store.activities[0].verified).toBe(true)
  })

  it('rolls back an optimistic like when the server rejects it', async () => {
    vi.mocked(nuiCall).mockResolvedValue({ success: false })
    const store = usePicstagramStore()
    store.feed = [{ ...post }]
    store.explore = [{ ...post }]

    expect(await store.react(store.feed[0], 'like')).toBe(false)
    expect(store.feed[0].is_liked).toBe(false)
    expect(store.feed[0].like_count).toBe(2)
    expect(store.explore[0].is_liked).toBe(false)
    expect(store.explore[0].like_count).toBe(2)
  })

  it('accepts a private follow request from activity and updates followers', async () => {
    vi.mocked(nuiCall).mockResolvedValue({ success: true })
    const store = usePicstagramStore()
    store.profile = { ...profile, followers: 4 }
    store.activities = [{ ...activity, kind: 'follow_request' }]

    expect(await store.respondFollow(profile.id, true)).toBe(true)
    expect(store.activities).toEqual([])
    expect(store.profile.followers).toBe(5)
    expect(nuiCall).toHaveBeenCalledWith('picstagram:respond-follow', {
      accept: true,
      profileId: profile.id,
    })
  })

  it('removes a blocked profile from all local surfaces', async () => {
    vi.mocked(nuiCall).mockResolvedValue({ success: true })
    const store = usePicstagramStore()
    store.feed = [{ ...post }]
    store.explore = [{ ...post }]
    store.profilePosts = [{ ...post }]
    store.saved = [{ ...post }]
    store.searchPosts = [{ ...post }]
    store.comments = [{ ...comment }]
    store.activities = [{ ...activity }]
    store.stories = [{ ...story }]
    store.viewedProfile = { ...profile, is_owner: false }

    expect(await store.blockProfile(profile.id)).toBe(true)
    expect(store.allPostCollections().flat()).toEqual([])
    expect(store.comments).toEqual([])
    expect(store.activities).toEqual([])
    expect(store.stories).toEqual([])
    expect(store.viewedProfile).toBeNull()
  })

  it('keeps the app signed out when no Picstagram session exists', async () => {
    vi.mocked(nuiCall).mockResolvedValue({
      success: true,
      data: { authenticated: false, isAdmin: false },
    })
    const store = usePicstagramStore()

    expect(await store.bootstrap()).toBe(true)
    expect(store.authenticated).toBe(false)
    expect(store.profile).toBeNull()
    expect(store.feed).toEqual([])
  })

  it('hydrates the profile and stories after login', async () => {
    vi.mocked(nuiCall)
      .mockResolvedValueOnce({ success: true })
      .mockResolvedValueOnce({
        success: true,
        data: {
          authenticated: true,
          feed: { hasMore: false, items: [{ ...post }], nextCursor: null },
          isAdmin: false,
          profile: { ...profile },
        },
      })
      .mockResolvedValueOnce({ success: true, data: [{ ...story }] })
    const store = usePicstagramStore()

    expect((await store.login('nova', 'password123')).success).toBe(true)
    expect(store.profile?.handle).toBe('nova')
    expect(store.stories).toHaveLength(1)
    expect(nuiCall).toHaveBeenNthCalledWith(1, 'picstagram:login', {
      handle: 'nova',
      password: 'password123',
    })
  })

  it('clears all local state after logout', async () => {
    vi.mocked(nuiCall).mockResolvedValue({ success: true })
    const store = usePicstagramStore()
    store.authenticated = true
    store.profile = { ...profile }
    store.feed = [{ ...post }]
    store.stories = [{ ...story }]

    expect((await store.logout()).success).toBe(true)
    expect(store.authenticated).toBe(false)
    expect(store.profile).toBeNull()
    expect(store.feed).toEqual([])
    expect(store.stories).toEqual([])
  })

  it('loads an exact shared post by id', async () => {
    vi.mocked(nuiCall).mockResolvedValue({ success: true, data: { ...post } })
    const store = usePicstagramStore()

    expect(await store.loadPost(post.id)).toEqual(post)
    expect(nuiCall).toHaveBeenCalledWith('picstagram:post', { id: post.id })
  })
})
