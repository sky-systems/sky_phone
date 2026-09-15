import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useEasyShareStore } from '@/stores/easyshare'
import type { EasySharePayload, EasyShareTransfer } from '@/types/easyshare'
import { nuiCall, type NuiResponse } from '@/utils/nui'

vi.mock('@/utils/nui', () => ({ nuiCall: vi.fn() }))

const mockNuiCall = vi.mocked(nuiCall)
const payload: EasySharePayload = {
  appId: 'notes',
  copyText: 'Meet at Mission Row.',
  id: 'note-1',
  kind: 'note',
  title: 'Meeting',
}
const incoming: EasyShareTransfer = {
  createdAt: Date.now(),
  direction: 'incoming',
  id: 'transfer-1',
  otherName: 'Mia Santos',
  payload,
  progress: 0,
  status: 'pending',
}

describe('easyshare store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    mockNuiCall.mockReset()
  })

  it('does not restore waiting status when bootstrap races a completion event', async () => {
    let finish!: (value: NuiResponse) => void
    mockNuiCall.mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          finish = resolve
        }),
    )
    const store = useEasyShareStore()
    store.applyEvent({ transfer: incoming })
    const loading = store.bootstrap()
    store.applyEvent({
      transfer: { ...incoming, status: 'completed', progress: 100 },
    })
    finish({
      success: true,
      data: {
        targets: [],
        history: [incoming],
        pending: [incoming],
        visibility: 'everyone',
      },
    })
    await loading
    expect(store.history[0].status).toBe('completed')
    expect(store.activeTransfer?.status).toBe('completed')
    expect(store.pending).toEqual([])
  })

  it('opens with the selected share payload', () => {
    const easyShare = useEasyShareStore()
    easyShare.open(payload)

    expect(easyShare.opened).toBe(true)
    expect(easyShare.payload).toEqual(payload)
    expect(easyShare.nearbyOpened).toBe(false)
  })

  it('opens the acceptance view for an incoming request', () => {
    const easyShare = useEasyShareStore()
    easyShare.applyEvent({ transfer: incoming })

    expect(easyShare.opened).toBe(true)
    expect(easyShare.nearbyOpened).toBe(true)
    expect(easyShare.incomingTransfer).toEqual(incoming)
  })

  it('keeps progress server-driven and removes terminal transfers from pending', () => {
    const easyShare = useEasyShareStore()
    easyShare.applyEvent({ transfer: incoming })
    easyShare.applyEvent({
      transfer: { ...incoming, progress: 50, status: 'transferring' },
    })
    expect(easyShare.pending[0]?.progress).toBe(50)

    easyShare.applyEvent({
      transfer: { ...incoming, progress: 100, status: 'completed' },
    })
    expect(easyShare.pending).toEqual([])
    expect(easyShare.history[0]?.status).toBe('completed')
  })

  it('sends only the target and current payload when requesting a transfer', async () => {
    mockNuiCall.mockResolvedValueOnce({ data: incoming, success: true })
    const easyShare = useEasyShareStore()
    easyShare.open(payload)

    await easyShare.request(41)

    expect(mockNuiCall).toHaveBeenCalledWith('easyshare:request', {
      payload,
      targetId: 41,
    })
  })

  it('replaces acceptance with progress when the sender reports an accepted transfer', () => {
    const store = useEasyShareStore()
    store.applyEvent({ transfer: incoming })
    store.applyEvent({
      transfer: { ...incoming, status: 'transferring', progress: 10 },
    })
    expect(store.incomingTransfer).toBeNull()
    expect(store.activeTransfer?.progress).toBe(10)
    store.applyEvent({
      transfer: { ...incoming, status: 'completed', progress: 100 },
    })
    expect(store.activeTransfer?.status).toBe('completed')
    expect(store.pending).toEqual([])
  })

  it('prevents repeated acceptance while the server is responding', async () => {
    let resolve!: (value: { success: boolean; data: EasyShareTransfer }) => void
    mockNuiCall.mockReturnValueOnce(
      new Promise((done) => {
        resolve = done
      }),
    )
    const store = useEasyShareStore()
    store.applyEvent({ transfer: incoming })
    const first = store.respond(incoming.id, true)
    expect(store.pendingActionId).toBe(incoming.id)
    expect(await store.respond(incoming.id, true)).toBe(false)
    expect(mockNuiCall).toHaveBeenCalledTimes(1)
    resolve({ success: true, data: { ...incoming, status: 'transferring' } })
    expect(await first).toBe(true)
    expect(store.pendingActionId).toBeNull()
    expect(store.incomingTransfer).toBeNull()
    expect(store.activeTransfer?.status).toBe('transferring')
  })

  it.each(['too_far', 'transfer_not_found', 'rate_limited', 'disabled'])(
    'preserves the actual receiver error %s and clears it for a new share',
    async (error) => {
      mockNuiCall.mockResolvedValueOnce({ success: false, error })
      const store = useEasyShareStore()
      expect(await store.respond(incoming.id, true)).toBe(false)
      expect(store.error).toBe(error)
      expect(store.pendingActionId).toBeNull()
      store.applyEvent({ transfer: incoming })
      expect(store.error).toBe('')
    },
  )

  it('shows expiry as transfer status instead of keeping the acceptance buttons', () => {
    const store = useEasyShareStore()
    store.applyEvent({ transfer: incoming })
    store.applyEvent({ transfer: { ...incoming, status: 'expired' } })
    expect(store.incomingTransfer).toBeNull()
    expect(store.activeTransfer?.status).toBe('expired')
  })

  it('does not resurrect completed transfers when acceptance responds after progress events', async () => {
    let resolve!: (value: { success: boolean; data: EasyShareTransfer }) => void
    mockNuiCall.mockReturnValueOnce(
      new Promise((done) => {
        resolve = done
      }),
    )
    const store = useEasyShareStore()
    store.applyEvent({ transfer: incoming })
    const request = store.respond(incoming.id, true)
    store.applyEvent({
      transfer: { ...incoming, status: 'completed', progress: 100 },
    })
    resolve({
      success: true,
      data: { ...incoming, status: 'transferring', progress: 0 },
    })
    await request
    store.applyEvent({ transfer: incoming })
    expect(store.activeTransfer?.status).toBe('completed')
    expect(store.incomingTransfer).toBeNull()
    expect(store.pending).toEqual([])
  })

  it('preserves discovery errors and clears them after a successful retry', async () => {
    mockNuiCall.mockResolvedValueOnce({ success: false, error: 'disabled' })
    const store = useEasyShareStore()
    expect(await store.bootstrap()).toBe(false)
    expect(store.error).toBe('disabled')
    mockNuiCall.mockResolvedValueOnce({
      success: true,
      data: {
        targets: [],
        pending: [],
        history: [],
        visibility: 'everyone',
      },
    })
    expect(await store.bootstrap()).toBe(true)
    expect(store.error).toBe('')
  })

  it('hands a prepared share message to the selected chat app once', () => {
    const easyShare = useEasyShareStore()
    easyShare.open({ ...payload, link: 'https://notes.sky/note-1' })

    expect(easyShare.prepareChatDraft('messages', '5551234567')).toBe(true)
    expect(easyShare.consumeChatDraft('messages')).toEqual({
      appId: 'messages',
      body: 'Meet at Mission Row.\nhttps://notes.sky/note-1',
      payload: { ...payload, link: 'https://notes.sky/note-1' },
      targetId: '5551234567',
    })
    expect(easyShare.consumeChatDraft('messages')).toBeNull()
  })

  it('keeps a share draft until a conversation is chosen in the destination app', () => {
    const easyShare = useEasyShareStore()
    easyShare.open(payload)

    expect(easyShare.prepareChatDraft('darkchat')).toBe(true)
    expect(easyShare.consumeChatDraft('darkchat')).toEqual({
      appId: 'darkchat',
      body: 'Meet at Mission Row.',
      payload,
      targetId: null,
    })
  })
})
