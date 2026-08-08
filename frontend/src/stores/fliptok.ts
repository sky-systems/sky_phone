import { defineStore } from 'pinia'

import type {
  FlipTokActivity,
  FlipTokComment,
  FlipTokMusicTrack,
  FlipTokPage,
  FlipTokProfile,
  FlipTokProfilePage,
  FlipTokReport,
  FlipTokVideo,
} from '@/types/fliptok'
import { nuiCall, type NuiResponse } from '@/utils/nui'

export const useFlipTokStore = defineStore('fliptok', {
  state: () => ({
    activities: [] as FlipTokActivity[],
    comments: [] as FlipTokComment[],
    feed: [] as FlipTokVideo[],
    isAdmin: false,
    loading: false,
    musicTracks: [] as FlipTokMusicTrack[],
    mode: 'for-you' as 'for-you' | 'following',
    profile: null as FlipTokProfile | null,
    profileVideos: [] as FlipTokVideo[],
    reports: [] as FlipTokReport[],
    searchResults: [] as FlipTokVideo[],
    viewedProfile: null as FlipTokProfile | null,
  }),
  actions: {
    applyVerification(profileId: number, verified: boolean): void {
      if (this.profile?.id === profileId) this.profile.verified = verified
      if (this.viewedProfile?.id === profileId)
        this.viewedProfile.verified = verified
      this.feed
        .filter((video) => video.profile_id === profileId)
        .forEach((video) => {
          video.verified = verified
        })
      this.searchResults
        .filter((video) => video.profile_id === profileId)
        .forEach((video) => {
          video.verified = verified
        })
      this.profileVideos
        .filter((video) => video.profile_id === profileId)
        .forEach((video) => {
          video.verified = verified
        })
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
        feed: FlipTokPage
        isAdmin: boolean
        musicTracks: FlipTokMusicTrack[]
        profile: FlipTokProfile
      }>('fliptok:bootstrap')
      this.loading = false
      if (!response.success || !response.data) return false
      this.profile = response.data.profile
      this.feed = response.data.feed.items
      this.isAdmin = response.data.isAdmin === true
      this.musicTracks = response.data.musicTracks ?? []
      return true
    },
    async loadFeed(mode?: 'for-you' | 'following'): Promise<boolean> {
      mode ??= this.mode
      this.mode = mode
      this.loading = true
      const response = await nuiCall<FlipTokPage>('fliptok:feed', {
        mode,
        offset: 0,
      })
      this.loading = false
      if (!response.success || !response.data) return false
      this.feed = response.data.items
      return true
    },
    async discover(search: string): Promise<FlipTokVideo[]> {
      const response = await nuiCall<FlipTokVideo[]>('fliptok:discover', {
        search,
      })
      this.searchResults =
        response.success && response.data ? response.data : []
      return this.searchResults
    },
    async react(video: FlipTokVideo, kind: 'like' | 'save'): Promise<void> {
      const key = kind === 'like' ? 'is_liked' : 'is_saved'
      const next = !video[key]
      video[key] = next
      if (kind === 'like') video.like_count += next ? 1 : -1
      const response = await nuiCall('fliptok:react', {
        active: next,
        id: video.id,
        kind,
      })
      if (!response.success) {
        video[key] = !next
        if (kind === 'like') video.like_count += next ? -1 : 1
      }
    },
    async follow(video: FlipTokVideo): Promise<void> {
      const next = !video.is_following
      const response = await nuiCall('fliptok:follow', {
        active: next,
        profileId: video.profile_id,
      })
      if (response.success)
        this.feed
          .filter((item) => item.profile_id === video.profile_id)
          .forEach((item) => {
            item.is_following = next
          })
    },
    async followProfile(profile: FlipTokProfile): Promise<void> {
      const next = !profile.is_following
      const response = await nuiCall('fliptok:follow', {
        active: next,
        profileId: profile.id,
      })
      if (!response.success) return
      profile.is_following = next
      profile.followers += next ? 1 : -1
      this.feed
        .filter((item) => item.profile_id === profile.id)
        .forEach((item) => {
          item.is_following = next
        })
    },
    async loadProfile(query: {
      handle?: string
      profileId?: number
    }): Promise<boolean> {
      const response = await nuiCall<FlipTokProfilePage>(
        'fliptok:profile',
        query,
      )
      if (!response.success || !response.data) return false
      this.viewedProfile = response.data.profile
      this.profileVideos = response.data.videos
      return true
    },
    showOwnProfile(): void {
      this.viewedProfile = null
      this.profileVideos = this.feed.filter((item) => item.is_owner)
    },
    async blockProfile(profileId: number): Promise<boolean> {
      const response = await nuiCall('fliptok:block', { profileId })
      if (!response.success) return false
      this.feed = this.feed.filter((video) => video.profile_id !== profileId)
      this.searchResults = this.searchResults.filter(
        (video) => video.profile_id !== profileId,
      )
      this.comments = this.comments.filter(
        (comment) => comment.profile_id !== profileId,
      )
      this.activities = this.activities.filter(
        (activity) => activity.profile_id !== profileId,
      )
      this.profileVideos = this.profileVideos.filter(
        (video) => video.profile_id !== profileId,
      )
      if (this.viewedProfile?.id === profileId) this.viewedProfile = null
      return true
    },
    async loadComments(id: string): Promise<void> {
      const response = await nuiCall<FlipTokComment[]>('fliptok:comments', {
        id,
      })
      this.comments = response.success && response.data ? response.data : []
    },
    async comment(id: string, body: string): Promise<NuiResponse> {
      return nuiCall('fliptok:comment', { body, id })
    },
    async loadActivities(): Promise<void> {
      const response = await nuiCall<FlipTokActivity[]>('fliptok:activities')
      this.activities = response.success && response.data ? response.data : []
      if (response.success) await nuiCall('fliptok:mark-activities')
    },
    async loadReports(): Promise<boolean> {
      const response = await nuiCall<FlipTokReport[]>('fliptok:admin-reports')
      this.reports = response.success && response.data ? response.data : []
      return response.success
    },
    async resolveReport(
      id: string,
      action: 'dismiss' | 'remove',
    ): Promise<boolean> {
      const response = await nuiCall('fliptok:admin-resolve-report', {
        action,
        id,
      })
      if (response.success) await this.loadReports()
      return response.success
    },
  },
})
