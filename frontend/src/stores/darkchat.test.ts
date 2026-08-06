import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useDarkChatStore } from '@/stores/darkchat'
import type { DarkChatMessage, DarkChatThread } from '@/types/darkchat'
import { nuiCall } from '@/utils/nui'

vi.mock('@/utils/nui', () => ({ nuiCall: vi.fn() }))
const mockNuiCall = vi.mocked(nuiCall)

const conversation: DarkChatThread['conversation'] = {
  blockedByPeer: false,
  createdAt: '2026-08-06 20:00:00',
  disappearingSeconds: 3600,
  id: 'conversation-id',
  notificationsEnabled: true,
  peer: { alias: 'Nova', avatarSeed: 42, darkId: 'dark:N0VA-41KQ', id: 2 },
  readReceipts: true,
}

function message(id: string): DarkChatMessage {
  return {
    body: 'Quiet channel',
    conversationId: conversation.id,
    createdAt: '2026-08-06 20:01:00',
    direction: 'sent',
    id,
    messageType: 'text',
    reactions: {},
  }
}

describe('darkchat store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    mockNuiCall.mockReset()
  })

  it('optimistically sends and confirms a private message', async () => {
    let resolveSend: ((value: { data: DarkChatMessage; success: true }) => void) | undefined
    const pending = new Promise<{ data: DarkChatMessage; success: true }>((resolve) => (resolveSend = resolve))
    mockNuiCall
      .mockResolvedValueOnce({ data: { conversation, messages: [] }, success: true })
      .mockResolvedValueOnce({ data: { contacts: [], conversations: [], profile: null }, success: true })
      .mockImplementationOnce(() => pending)
      .mockResolvedValueOnce({ data: { contacts: [], conversations: [], profile: null }, success: true })

    const store = useDarkChatStore()
    await store.openThread(conversation.id)
    const sending = store.send({ body: 'Quiet channel', messageType: 'text' })
    expect(store.messages[0]).toMatchObject({ deliveryStatus: 'sending', body: 'Quiet channel' })

    resolveSend?.({ data: message('server-message'), success: true })
    await sending
    expect(store.messages[0]).toMatchObject({ deliveryStatus: 'delivered', id: 'server-message' })
  })

  it('keeps failed messages visible for delivery feedback', async () => {
    mockNuiCall
      .mockResolvedValueOnce({ data: { conversation, messages: [] }, success: true })
      .mockResolvedValueOnce({ data: { contacts: [], conversations: [], profile: null }, success: true })
      .mockResolvedValueOnce({ error: 'blocked', success: false })

    const store = useDarkChatStore()
    await store.openThread(conversation.id)
    await store.send({ body: 'Quiet channel', messageType: 'text' })
    expect(store.messages[0].deliveryStatus).toBe('failed')
  })

  it('loads protected voice data once', async () => {
    mockNuiCall.mockResolvedValueOnce({
      data: { mime: 'audio/webm;codecs=opus', payload: 'ZmFrZQ==' },
      success: true,
    })
    const store = useDarkChatStore()
    expect(await store.loadMedia('voice-id')).toBe(true)
    expect(await store.loadMedia('voice-id')).toBe(true)
    expect(store.mediaSources['voice-id']).toBe('data:audio/webm;codecs=opus;base64,ZmFrZQ==')
    expect(mockNuiCall).toHaveBeenCalledTimes(1)
  })
})
