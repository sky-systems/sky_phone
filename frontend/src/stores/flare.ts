import { defineStore } from 'pinia'

import type {
  FlareBootstrap,
  FlareMatch,
  FlareMessage,
  FlareProfile,
  FlareProfileDraft,
} from '@/types/flare'
import { nuiCall } from '@/utils/nui'

export const useFlareStore = defineStore('flare', {
  state: () => ({
    activeMatchId: '' as string,
    error: '' as string,
    loading: false,
    likes: [] as FlareBootstrap['likes'],
    matches: [] as FlareMatch[],
    messages: [] as FlareMessage[],
    profile: null as FlareBootstrap['profile'],
    sending: false,
    suggestions: [] as FlareProfile[],
  }),
  actions: {
    async bootstrap(): Promise<boolean> {
      this.loading = true
      const response = await nuiCall<FlareBootstrap>('flare:bootstrap')
      this.loading = false
      this.error = response.success ? '' : (response.error ?? 'default')
      if (response.success && response.data) {
        this.applyBootstrap(response.data)
      }
      return response.success
    },
    async loadThread(matchId: string): Promise<boolean> {
      this.activeMatchId = matchId
      const response = await nuiCall<{ messages: FlareMessage[] }>(
        'flare:thread',
        { matchId },
      )
      this.error = response.success ? '' : (response.error ?? 'default')
      if (response.success) {
        this.messages = response.data?.messages ?? []
        const match = this.matches.find((item) => item.id === matchId)
        if (match) match.unread = 0
      }
      return response.success
    },
    async saveProfile(draft: FlareProfileDraft): Promise<boolean> {
      const response = await nuiCall<FlareBootstrap>(
        'flare:save-profile',
        draft,
      )
      this.error = response.success ? '' : (response.error ?? 'default')
      if (response.success && response.data) {
        this.applyBootstrap(response.data)
      }
      return response.success
    },
    async send(matchId: string, body: string): Promise<boolean> {
      this.sending = true
      const response = await nuiCall<FlareMessage>('flare:send', {
        body,
        matchId,
      })
      this.sending = false
      this.error = response.success ? '' : (response.error ?? 'default')
      if (response.success && response.data) {
        this.messages.push(response.data)
        const match = this.matches.find((item) => item.id === matchId)
        if (match) {
          match.lastMessage = response.data.body
          match.lastMessageAt = response.data.createdAt
        }
      }
      return response.success
    },
    async swipe(
      targetId: number,
      choice: 'like' | 'pass' | 'superlike',
    ): Promise<FlareMatch | null> {
      const response = await nuiCall<{ match: FlareMatch | null }>(
        'flare:swipe',
        { choice, targetId },
      )
      this.error = response.success ? '' : (response.error ?? 'default')
      if (!response.success) return null
      this.suggestions = this.suggestions.filter(
        (profile) => profile.id !== targetId,
      )
      this.likes = this.likes.filter((profile) => profile.id !== targetId)
      const match = response.data?.match ?? null
      if (match) {
        this.matches = [
          match,
          ...this.matches.filter((item) => item.id !== match.id),
        ]
      }
      return match
    },
    async rewind(): Promise<boolean> {
      const response = await nuiCall<FlareBootstrap>('flare:rewind')
      this.error = response.success ? '' : (response.error ?? 'default')
      if (response.success && response.data) this.applyBootstrap(response.data)
      return response.success
    },
    async setDiscovery(enabled: boolean): Promise<boolean> {
      const response = await nuiCall<FlareBootstrap>('flare:set-discovery', {
        enabled,
      })
      this.error = response.success ? '' : (response.error ?? 'default')
      if (response.success && response.data) this.applyBootstrap(response.data)
      return response.success
    },
    async unmatch(matchId: string): Promise<boolean> {
      const response = await nuiCall<{ matches: FlareMatch[] }>(
        'flare:unmatch',
        {
          matchId,
        },
      )
      this.error = response.success ? '' : (response.error ?? 'default')
      if (response.success) {
        this.matches = response.data?.matches ?? []
        this.messages = []
        if (this.activeMatchId === matchId) this.activeMatchId = ''
      }
      return response.success
    },
    applyBootstrap(data: FlareBootstrap): void {
      this.profile = data.profile
      this.likes = data.likes
      this.matches = data.matches
      this.suggestions = data.suggestions
    },
  },
})
