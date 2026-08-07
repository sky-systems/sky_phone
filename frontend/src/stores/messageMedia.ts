import { defineStore } from 'pinia'

import type { MediaType, PhoneMedia } from '@/types/media'

type MessageMediaRequest = {
  mediaType: MediaType
  returnPath: string
  target: string
}

type MessageMediaResult = MessageMediaRequest & {
  media: PhoneMedia
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
    ): void {
      this.request = { mediaType, returnPath, target }
      this.result = null
    },
    cancel(): string {
      const returnPath = this.request?.returnPath ?? '/apps/messages'
      this.request = null
      return returnPath
    },
    complete(media: PhoneMedia): string | null {
      if (!this.request || this.request.mediaType !== media.mediaType) return null
      const returnPath = this.request.returnPath
      this.result = { ...this.request, media }
      this.request = null
      return returnPath
    },
    consume(target: string): PhoneMedia | null {
      if (!this.result || this.result.target !== target) return null
      const media = this.result.media
      this.result = null
      return media
    },
  },
})
