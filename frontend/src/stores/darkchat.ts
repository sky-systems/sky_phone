import { computed, ref } from 'vue'
import { defineStore } from 'pinia'

import type {
  DarkChatBootstrap,
  DarkChatContact,
  DarkChatConversation,
  DarkChatConversationSummary,
  DarkChatMessage,
  DarkChatOutgoing,
  DarkChatProfile,
  DarkChatThread,
} from '@/types/darkchat'
import { nuiCall, type NuiResponse } from '@/utils/nui'

export const useDarkChatStore = defineStore('darkchat', () => {
  const profile = ref<DarkChatProfile | null>(null)
  const contacts = ref<DarkChatContact[]>([])
  const conversations = ref<DarkChatConversationSummary[]>([])
  const activeConversation = ref<DarkChatConversation | null>(null)
  const messages = ref<DarkChatMessage[]>([])
  const mediaSources = ref<Record<string, string>>({})
  const loading = ref(false)
  const lastError = ref<string | null>(null)
  const unreadCount = computed(() =>
    conversations.value.reduce((total, conversation) => total + conversation.unread, 0),
  )

  async function bootstrap(): Promise<boolean> {
    loading.value = true
    const response = await nuiCall<DarkChatBootstrap>('darkchat:bootstrap')
    loading.value = false
    lastError.value = response.error ?? null
    if (!response.success || !response.data) {
      profile.value = null
      contacts.value = []
      conversations.value = []
      return false
    }
    profile.value = response.data.profile
    contacts.value = response.data.contacts
    conversations.value = response.data.conversations
    return true
  }

  async function openThread(conversationId: string): Promise<boolean> {
    loading.value = true
    const response = await nuiCall<DarkChatThread>('darkchat:thread', { conversationId })
    loading.value = false
    lastError.value = response.error ?? null
    if (!response.success || !response.data) return false
    activeConversation.value = response.data.conversation
    messages.value = response.data.messages.map((message) => ({
      ...message,
      deliveryStatus: message.direction === 'sent' ? 'delivered' : undefined,
    }))
    await refreshInbox()
    return true
  }

  async function refreshInbox(): Promise<boolean> {
    const response = await nuiCall<DarkChatBootstrap>('darkchat:bootstrap')
    if (!response.success || !response.data) return false
    profile.value = response.data.profile
    contacts.value = response.data.contacts
    conversations.value = response.data.conversations
    return true
  }

  async function start(identifier: string): Promise<NuiResponse<{ conversationId: string }>> {
    const response = await nuiCall<{ conversationId: string }>('darkchat:start', { identifier })
    if (response.success) await refreshInbox()
    return response
  }

  async function send(outgoing: DarkChatOutgoing): Promise<NuiResponse<DarkChatMessage>> {
    if (!activeConversation.value) return { success: false, error: 'invalid_conversation' }
    const clientId = `dark-pending-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`
    const optimistic: DarkChatMessage = {
      body: outgoing.body ?? '',
      clientId,
      conversationId: activeConversation.value.id,
      createdAt: new Date().toISOString().slice(0, 19).replace('T', ' '),
      deliveryStatus: 'sending',
      direction: 'sent',
      id: clientId,
      mediaDurationMs: outgoing.mediaDurationMs,
      mediaMime: outgoing.mediaMime,
      mediaWaveform: outgoing.mediaWaveform,
      messageType: outgoing.messageType,
      reactions: {},
      replyToId: outgoing.replyToId,
    }
    messages.value.push(optimistic)
    if (outgoing.messageType === 'voice' && outgoing.mediaPayload) {
      mediaSources.value[clientId] = `data:${outgoing.mediaMime};base64,${outgoing.mediaPayload}`
    }
    const response = await nuiCall<DarkChatMessage>('darkchat:send', {
      ...outgoing,
      conversationId: activeConversation.value.id,
    })
    const index = messages.value.findIndex((message) => message.clientId === clientId)
    if (!response.success || !response.data) {
      if (index >= 0) messages.value[index].deliveryStatus = 'failed'
      return response
    }
    const source = mediaSources.value[clientId]
    delete mediaSources.value[clientId]
    if (source) mediaSources.value[response.data.id] = source
    if (index >= 0) {
      messages.value[index] = { ...response.data, clientId, deliveryStatus: 'delivered' }
    }
    await refreshInbox()
    return response
  }

  async function loadMedia(messageId: string): Promise<boolean> {
    if (mediaSources.value[messageId]) return true
    const response = await nuiCall<{ mime: string; payload: string }>('darkchat:media', { messageId })
    if (!response.success || !response.data) return false
    mediaSources.value[messageId] = `data:${response.data.mime};base64,${response.data.payload}`
    return true
  }

  async function mutate(endpoint: string, data: Record<string, unknown>): Promise<boolean> {
    const response = await nuiCall(`darkchat:${endpoint}`, data)
    return response.success
  }

  function closeThread(): void {
    activeConversation.value = null
    messages.value = []
    mediaSources.value = {}
  }

  return {
    activeConversation,
    bootstrap,
    closeThread,
    contacts,
    conversations,
    lastError,
    loadMedia,
    loading,
    mediaSources,
    messages,
    mutate,
    openThread,
    profile,
    refreshInbox,
    send,
    start,
    unreadCount,
  }
})
