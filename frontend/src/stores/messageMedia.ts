import { defineStore } from 'pinia'

import type { MediaType, PhoneMedia } from '@/types/media'

type MessageMediaRequest = {
  context?: unknown
  maxSelection: number
  mediaType: MediaType
  returnPath: string
  target: string
}

type MessageMediaResult = MessageMediaRequest & {
  media: PhoneMedia[]
}

export type MediaSelectionResult<T = unknown> = {
  context?: T
  media: PhoneMedia[]
}

export const useMessageMediaStore = defineStore('message-media', {
  state: () => ({
    request: null as MessageMediaRequest | null,
    result: null as MessageMediaResult | null,
  }),
  actions: {
    begin(
      target: string,
      mediaType: MediaType,
      returnPath = '/apps/messages',
      maxSelection = 1,
      context?: unknown,
    ): void {
      this.request = {
        context,
        maxSelection: Math.max(1, Math.floor(maxSelection)),
        mediaType,
        returnPath,
        target,
      }
      this.result = null
    },
    cancel(): string {
      const returnPath = this.request?.returnPath ?? '/apps/messages'
      if (this.request) this.result = { ...this.request, media: [] }
      this.request = null
      return returnPath
    },
    complete(media: PhoneMedia): string | null {
      if (!this.request || this.request.mediaType !== media.mediaType) return null
      return this.completeMany([media])
    },
    completeMany(media: PhoneMedia[]): string | null {
      if (
        !this.request ||
        media.length < 1 ||
        media.length > this.request.maxSelection ||
        media.some((entry) => entry.mediaType !== this.request?.mediaType)
      ) {
        return null
      }
      const returnPath = this.request.returnPath
      this.result = { ...this.request, media }
      this.request = null
      return returnPath
    },
    consume(target: string): PhoneMedia | null {
      if (!this.result || this.result.target !== target) return null
      const media = this.result.media[0] ?? null
      this.result = null
      return media
    },
    consumeMany<T = unknown>(target: string): MediaSelectionResult<T> | null {
      if (!this.result || this.result.target !== target) return null
      const result = {
        context: this.result.context as T | undefined,
        media: [...this.result.media],
      }
      this.result = null
      return result
    },
  },
})
