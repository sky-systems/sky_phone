import { defineStore } from 'pinia'
import { computed, ref } from 'vue'

import type {
  GifSearchPage,
  SmsConversation,
  SmsMedia,
  SmsMessage,
  SmsOutgoingMessage,
} from '@/types/messages'
import { nuiCall, type NuiResponse } from '@/utils/nui'

export const useMessagesStore = defineStore('messages', () => {
  const conversations = ref<SmsConversation[]>([])
  const messages = ref<SmsMessage[]>([])
  const mediaSources = ref<Record<string, string>>({})
  const activeNumber = ref<string | null>(null)
  const loading = ref(false)
  const unreadCount = computed(() =>
    conversations.value.reduce((total, item) => total + item.unread, 0),
  )

  async function loadConversations(): Promise<boolean> {
    const response = await nuiCall<SmsConversation[]>('messages:conversations')
    if (response.success && response.data) {
      conversations.value = response.data.map((conversation) => ({
        ...conversation,
        phoneNumber: String(conversation.phoneNumber),
      }))
    }
    else if (!response.success) conversations.value = []
    return response.success
  }

  async function openThread(phoneNumber: string): Promise<boolean> {
    loading.value = true
    const response = await nuiCall<SmsMessage[]>('messages:thread', {
      phoneNumber,
    })
    loading.value = false
    if (!response.success || !response.data) return false
    activeNumber.value = phoneNumber
    messages.value = response.data.map((message) => ({
      ...message,
      delivery_status:
        message.direction === 'sent' ? 'delivered' : undefined,
      recipient_number: String(message.recipient_number),
      sender_number: String(message.sender_number),
    }))
    await loadConversations()
    return true
  }

  async function send(
    outgoing: SmsOutgoingMessage,
  ): Promise<NuiResponse<SmsMessage>> {
    if (!activeNumber.value) return { success: false, error: 'invalid_number' }
    const clientId = `pending-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`
    const optimistic: SmsMessage = {
      body: outgoing.messageType === 'text' ? outgoing.body.trim() : '',
      client_id: clientId,
      created_at: new Date().toISOString().slice(0, 19).replace('T', ' '),
      delivery_status: 'sending',
      direction: 'sent',
      id: clientId,
      media_asset_id:
        outgoing.messageType === 'image' ||
        outgoing.messageType === 'gif' ||
        outgoing.messageType === 'video'
          ? outgoing.mediaAssetId
          : null,
      media_duration_ms:
        outgoing.messageType === 'voice' || outgoing.messageType === 'video'
          ? outgoing.mediaDurationMs ?? null
          : null,
      media_mime:
        outgoing.messageType === 'voice' ? outgoing.mediaMime : null,
      media_waveform:
        outgoing.messageType === 'voice' ? outgoing.mediaWaveform : null,
      message_type: outgoing.messageType,
      read_at: null,
      recipient_number: activeNumber.value,
      sender_number: '',
    }
    messages.value.push(optimistic)
    if (outgoing.messageType === 'voice') {
      mediaSources.value[clientId] =
        `data:${outgoing.mediaMime};base64,${outgoing.mediaPayload}`
    }

    const response = await nuiCall<SmsMessage>('messages:send', {
      ...outgoing,
      phoneNumber: activeNumber.value,
    })
    const index = messages.value.findIndex(
      (message) => message.client_id === clientId,
    )
    if (!response.success || !response.data) {
      if (index >= 0) messages.value[index].delivery_status = 'failed'
      return response
    }

    const source = mediaSources.value[clientId]
    delete mediaSources.value[clientId]
    if (source) mediaSources.value[response.data.id] = source
    if (index >= 0) {
      messages.value[index] = {
        ...response.data,
        client_id: clientId,
        delivery_status: 'delivered',
      }
    }
    await loadConversations()
    return response
  }

  async function loadMedia(id: string): Promise<boolean> {
    if (mediaSources.value[id]) return true
    const response = await nuiCall<SmsMedia>('messages:media', { id })
    if (!response.success || !response.data) return false
    mediaSources.value[id] =
      `data:${response.data.mime};base64,${response.data.payload}`
    return true
  }

  async function deleteConversations(phoneNumbers: string[]): Promise<boolean> {
    if (!phoneNumbers.length) return false
    const response = await nuiCall('messages:delete', { phoneNumbers })
    if (!response.success) return false
    if (activeNumber.value && phoneNumbers.includes(activeNumber.value)) {
      closeThread()
    }
    await loadConversations()
    return true
  }

  async function searchGifs(
    query: string,
    offset = 0,
  ): Promise<NuiResponse<GifSearchPage>> {
    return nuiCall<GifSearchPage>('messages:gifs', { offset, query })
  }

  function closeThread(): void {
    activeNumber.value = null
    messages.value = []
    mediaSources.value = {}
  }

  return {
    activeNumber,
    closeThread,
    conversations,
    deleteConversations,
    loadConversations,
    loadMedia,
    loading,
    mediaSources,
    messages,
    openThread,
    searchGifs,
    send,
    unreadCount,
  }
})
