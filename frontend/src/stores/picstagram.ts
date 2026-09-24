import { defineStore } from 'pinia'

import type {
  PicstagramActivity,
  PicstagramComment,
  PicstagramPage,
  PicstagramPost,
  PicstagramProfile,
  PicstagramProfilePage,
  PicstagramReport,
  PicstagramReportReason,
  PicstagramReportTarget,
  PicstagramSearchResult,
  PicstagramStory,
  PicstagramStoryViewer,
} from '@/types/picstagram'
import { nuiCall, type NuiResponse } from '@/utils/nui'

function replaceProfileState(
  posts: PicstagramPost[],
  profileId: string,
  update: (post: PicstagramPost) => void,
): void {
  posts.filter((post) => post.profile_id === profileId).forEach(update)
}

export const usePicstagramStore = defineStore('picstagram', {
  state: () => ({
    activities: [] as PicstagramActivity[],
    authenticated: false,
    comments: [] as PicstagramComment[],
    connections: [] as PicstagramProfile[],
    explore: [] as PicstagramPost[],
    exploreCursor: null as string | null,
    feed: [] as PicstagramPost[],
    feedCursor: null as string | null,
    isAdmin: false,
    loading: false,
    profile: null as PicstagramProfile | null,
    profilePosts: [] as PicstagramPost[],
    reports: [] as PicstagramReport[],
    saved: [] as PicstagramPost[],
    searchPosts: [] as PicstagramPost[],
    searchProfiles: [] as PicstagramProfile[],
    searchRevision: 0,
    searchLoading: false,
    searchError: false,
    stories: [] as PicstagramStory[],
    storyViewers: [] as PicstagramStoryViewer[],
    viewedProfile: null as PicstagramProfile | null,
  }),
  actions: {
    allPostCollections(): PicstagramPost[][] {
      return [
        this.feed,
        this.explore,
        this.profilePosts,
        this.saved,
        this.searchPosts,
      ]
    },
    applyVerification(profileId: string, verified: boolean): void {
      if (this.profile?.id === profileId) this.profile.verified = verified
      if (this.viewedProfile?.id === profileId)
        this.viewedProfile.verified = verified
      this.allPostCollections().forEach((posts) =>
        replaceProfileState(posts, profileId, (post) => {
          post.verified = verified
        }),
      )
      this.comments
        .filter((comment) => comment.profile_id === profileId)
        .forEach((comment) => {
          comment.verified = verified
        })
      this.activities
        .filter((activity) => activity.profile_id === profileId)
        .forEach((activity) => {
          activity.verified = verified
        })
    },
    async bootstrap(): Promise<boolean> {
      this.loading = true
      const response = await nuiCall<{
        authenticated: boolean
        feed?: PicstagramPage
        isAdmin: boolean
        profile?: PicstagramProfile
      }>('picstagram:bootstrap')
      this.loading = false
      if (!response.success || !response.data) return false
      this.authenticated = response.data.authenticated
      this.isAdmin = response.data.isAdmin
      this.profile = response.data.profile ?? null
      this.feed = response.data.feed?.items ?? []
      this.feedCursor = response.data.feed?.nextCursor ?? null
      if (this.authenticated) await this.loadStories()
      return true
    },
    async login(handle: string, password: string): Promise<NuiResponse> {
      const response = await nuiCall('picstagram:login', { handle, password })
      if (response.success) await this.bootstrap()
      return response
    },
    async register(
      displayName: string,
      handle: string,
      password: string,
    ): Promise<NuiResponse> {
      const response = await nuiCall('picstagram:register', {
        displayName,
        handle,
        password,
      })
      if (response.success) await this.bootstrap()
      return response
    },
    async logout(): Promise<NuiResponse> {
      const response = await nuiCall('picstagram:logout')
      if (response.success) this.$reset()
      return response
    },
    async loadFeed(append = false): Promise<boolean> {
      const response = await nuiCall<PicstagramPage>('picstagram:feed', {
        cursor: append ? this.feedCursor : undefined,
      })
      if (!response.success || !response.data) return false
      this.feed = append
        ? [...this.feed, ...response.data.items]
        : response.data.items
      this.feedCursor = response.data.nextCursor
      return true
    },
    async loadPost(id: string): Promise<PicstagramPost | null> {
      const response = await nuiCall<PicstagramPost>('picstagram:post', { id })
      return response.success && response.data ? response.data : null
    },
    async loadExplore(append = false): Promise<boolean> {
      const response = await nuiCall<PicstagramPage>('picstagram:explore', {
        cursor: append ? this.exploreCursor : undefined,
      })
      if (!response.success || !response.data) return false
      this.explore = append
        ? [...this.explore, ...response.data.items]
        : response.data.items
      this.exploreCursor = response.data.nextCursor
      return true
    },
    async search(search: string): Promise<boolean> {
      const revision = ++this.searchRevision
      this.searchLoading = true
      this.searchError = false
      const response = await nuiCall<PicstagramSearchResult>(
        'picstagram:search',
        { search },
      )
      if (revision !== this.searchRevision) return false
      this.searchLoading = false
      if (!response.success || !response.data) {
        this.searchProfiles = []
        this.searchPosts = []
        this.searchError = true
        return false
      }
      this.searchPosts = response.data.posts
      this.searchProfiles = response.data.profiles
      return true
    },
    async loadSaved(): Promise<boolean> {
      const response = await nuiCall<PicstagramPage>('picstagram:saved')
      if (!response.success || !response.data) return false
      this.saved = response.data.items
      return true
    },
    async loadProfile(query: {
      handle?: string
      profileId?: string
    }): Promise<boolean> {
      const response = await nuiCall<PicstagramProfilePage>(
        'picstagram:profile',
        query,
      )
      if (!response.success || !response.data) return false
      this.viewedProfile = response.data.profile
      this.profilePosts = response.data.posts.items
      return true
    },
    showOwnProfile(): void {
      this.viewedProfile = null
      this.profilePosts = this.feed.filter((post) => post.is_owner)
    },
    async updateProfile(payload: {
      avatarMediaId: number
      bio: string
      displayName: string
      handle: string
      private: boolean
    }): Promise<NuiResponse<PicstagramProfile>> {
      const response = await nuiCall<PicstagramProfile>(
        'picstagram:update-profile',
        payload,
      )
      if (response.success && response.data) this.profile = response.data
      return response
    },
    async publishPost(payload: {
      caption: string
      commentsEnabled: boolean
      location: string
      mediaIds: number[]
      mediaType: 'photo' | 'video'
    }): Promise<NuiResponse<{ id: string }>> {
      const response = await nuiCall<{ id: string }>(
        'picstagram:publish-post',
        payload,
      )
      if (response.success) await this.loadFeed()
      return response
    },
    async setPostStatus(
      post: PicstagramPost,
      status: 'archived' | 'published' | 'removed',
    ): Promise<boolean> {
      const response = await nuiCall('picstagram:set-post-status', {
        id: post.id,
        status,
      })
      if (!response.success) return false
      this.allPostCollections().forEach((posts) => {
        const index = posts.findIndex((item) => item.id === post.id)
        if (index >= 0) posts.splice(index, 1)
      })
      return true
    },
    async react(post: PicstagramPost, kind: 'like' | 'save'): Promise<boolean> {
      const key = kind === 'like' ? 'is_liked' : 'is_saved'
      const next = !post[key]
      const matching = this.allPostCollections()
        .flat()
        .filter((item) => item.id === post.id)
      matching.forEach((item) => {
        item[key] = next
        if (kind === 'like') item.like_count += next ? 1 : -1
      })
      const response = await nuiCall('picstagram:react', {
        active: next,
        id: post.id,
        kind,
      })
      if (response.success) return true
      matching.forEach((item) => {
        item[key] = !next
        if (kind === 'like') item.like_count += next ? -1 : 1
      })
      return false
    },
    async followProfile(profile: PicstagramProfile): Promise<boolean> {
      const active = !profile.is_following && !profile.is_requested
      const response = await nuiCall<{
        status: 'accepted' | 'pending' | false
      }>('picstagram:follow', { active, profileId: profile.id })
      if (!response.success || !response.data) return false
      const previousFollowing = profile.is_following
      profile.follow_status = response.data.status || null
      profile.is_following = response.data.status === 'accepted'
      profile.is_requested = response.data.status === 'pending'
      if (previousFollowing !== profile.is_following)
        profile.followers += profile.is_following ? 1 : -1
      return true
    },
    async respondFollow(profileId: string, accept: boolean): Promise<boolean> {
      const response = await nuiCall('picstagram:respond-follow', {
        accept,
        profileId,
      })
      if (response.success)
        this.activities = this.activities.filter(
          (activity) =>
            activity.kind !== 'follow_request' ||
            activity.profile_id !== profileId,
        )
      if (response.success && accept && this.profile)
        this.profile.followers += 1
      return response.success
    },
    async loadComments(id: string): Promise<boolean> {
      const response = await nuiCall<PicstagramComment[]>(
        'picstagram:comments',
        { id },
      )
      this.comments = response.success && response.data ? response.data : []
      return response.success
    },
    async comment(
      id: string,
      body: string,
      parentId?: string,
      replyToId?: string,
    ): Promise<NuiResponse> {
      return nuiCall('picstagram:comment', { body, id, parentId, replyToId })
    },
    async removeComment(id: string): Promise<boolean> {
      const response = await nuiCall('picstagram:remove-comment', { id })
      if (response.success)
        this.comments = this.comments.filter((comment) => comment.id !== id)
      return response.success
    },
    async reactComment(comment: PicstagramComment): Promise<void> {
      const active = !comment.is_liked
      comment.is_liked = active
      comment.like_count += active ? 1 : -1
      const response = await nuiCall('picstagram:comment-react', {
        active,
        id: comment.id,
      })
      if (response.success) return
      comment.is_liked = !active
      comment.like_count += active ? -1 : 1
    },
    async loadConnections(
      profileId: string,
      mode: 'followers' | 'following',
    ): Promise<boolean> {
      const response = await nuiCall<PicstagramProfile[]>(
        'picstagram:connections',
        { mode, profileId },
      )
      this.connections = response.success && response.data ? response.data : []
      return response.success
    },
    async loadStories(): Promise<boolean> {
      const response = await nuiCall<PicstagramStory[]>('picstagram:stories')
      this.stories = response.success && response.data ? response.data : []
      return response.success
    },
    async publishStory(
      mediaId: number,
      body: string,
      mediaType: 'photo' | 'video',
    ): Promise<NuiResponse<{ id: string }>> {
      const response = await nuiCall<{ id: string }>(
        'picstagram:publish-story',
        { body, mediaId, mediaType },
      )
      if (response.success) await this.loadStories()
      return response
    },
    async viewStory(story: PicstagramStory): Promise<void> {
      if (!story.seen && !story.is_owner) {
        const response = await nuiCall('picstagram:view-story', {
          id: story.id,
        })
        if (response.success) story.seen = true
      }
    },
    async loadStoryViewers(id: string): Promise<boolean> {
      const response = await nuiCall<PicstagramStoryViewer[]>(
        'picstagram:story-viewers',
        { id },
      )
      this.storyViewers = response.success && response.data ? response.data : []
      return response.success
    },
    async removeStory(id: string): Promise<boolean> {
      const response = await nuiCall('picstagram:remove-story', { id })
      if (response.success)
        this.stories = this.stories.filter((story) => story.id !== id)
      return response.success
    },
    async loadActivities(): Promise<boolean> {
      const response = await nuiCall<PicstagramActivity[]>(
        'picstagram:activities',
      )
      this.activities = response.success && response.data ? response.data : []
      return response.success
    },
    async markActivities(): Promise<boolean> {
      const response = await nuiCall('picstagram:mark-activities')
      if (response.success)
        this.activities.forEach((activity) => {
          activity.read_at ??= new Date().toISOString()
        })
      return response.success
    },
    async blockProfile(profileId: string): Promise<boolean> {
      const response = await nuiCall('picstagram:block', {
        active: true,
        profileId,
      })
      if (!response.success) return false
      this.allPostCollections().forEach((posts) => {
        for (let index = posts.length - 1; index >= 0; index -= 1)
          if (posts[index].profile_id === profileId) posts.splice(index, 1)
      })
      this.comments = this.comments.filter(
        (comment) => comment.profile_id !== profileId,
      )
      this.activities = this.activities.filter(
        (activity) => activity.profile_id !== profileId,
      )
      this.stories = this.stories.filter(
        (story) => story.profile_id !== profileId,
      )
      if (this.viewedProfile?.id === profileId) this.viewedProfile = null
      return true
    },
    async report(
      targetType: PicstagramReportTarget,
      targetId: string,
      reason: PicstagramReportReason,
      details: string,
    ): Promise<NuiResponse> {
      return nuiCall('picstagram:report', {
        details,
        reason,
        targetId,
        targetType,
      })
    },
    async loadReports(): Promise<boolean> {
      const response = await nuiCall<PicstagramReport[]>(
        'picstagram:admin-reports',
      )
      this.reports = response.success && response.data ? response.data : []
      return response.success
    },
    async resolveReport(
      id: string,
      action: 'dismiss' | 'hide' | 'remove' | 'restore',
    ): Promise<boolean> {
      const response = await nuiCall('picstagram:admin-resolve-report', {
        action,
        id,
      })
      if (response.success)
        this.reports = this.reports.filter((report) => report.id !== id)
      return response.success
    },
  },
})
