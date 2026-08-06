import { defineStore } from 'pinia'

import type { MediaType, PhoneMedia } from '@/types/media'

type MessageMediaRequest = {
  mediaType: MediaType
  phoneNumber: string
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
    begin(phoneNumber: string, mediaType: MediaType): void {
      this.request = { mediaType, phoneNumber }
      this.result = null
    },
    cancel(): void {
      this.request = null
    },
    complete(media: PhoneMedia): void {
      if (!this.request || this.request.mediaType !== media.mediaType) return
      this.result = { ...this.request, media }
      this.request = null
    },
    consume(phoneNumber: string): PhoneMedia | null {
      if (!this.result || this.result.phoneNumber !== phoneNumber) return null
      const media = this.result.media
      this.result = null
      return media
    },
  },
})
