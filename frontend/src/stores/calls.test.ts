import { createPinia, setActivePinia } from 'pinia'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { useCallsStore } from '@/stores/calls'
import { nuiCall } from '@/utils/nui'
import { playPhoneTone } from '@/utils/tones'

vi.mock('@/utils/nui', () => ({
  nuiCall: vi.fn(async () => ({ success: true, data: [] })),
}))
vi.mock('@/utils/tones', () => ({
  playPhoneTone: vi.fn(() => vi.fn()),
}))

describe('calls store', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    vi.stubGlobal('window', {
      matchMedia: vi.fn(() => ({ matches: false })),
      setTimeout,
    })
    setActivePinia(createPinia())
  })

  afterEach(() => {
    vi.clearAllMocks()
    vi.clearAllTimers()
    vi.useRealTimers()
    vi.unstubAllGlobals()
  })

  it('rings for incoming calls and stops when connected', () => {
    const stop = vi.fn()
    vi.mocked(playPhoneTone).mockReturnValueOnce(stop)
    const calls = useCallsStore()

    calls.applyCallState({
      direction: 'incoming',
      id: 'call-1',
      otherNumber: '1234567890',
      startedAt: 1,
      state: 'ringing',
    })
    expect(playPhoneTone).toHaveBeenCalledWith('apex', 80, true)

    calls.applyCallState({
      direction: 'incoming',
      id: 'call-1',
      otherNumber: '1234567890',
      startedAt: 1,
      state: 'connected',
    })
    expect(stop).toHaveBeenCalledOnce()
  })

  it('clears terminal states and refreshes recents', async () => {
    const calls = useCallsStore()
    calls.applyCallState({
      direction: 'outgoing',
      id: 'call-2',
      otherNumber: '1234567890',
      startedAt: 1,
      state: 'busy',
    })

    await vi.advanceTimersByTimeAsync(1600)

    expect(calls.activeCall).toBeNull()
    expect(nuiCall).toHaveBeenCalledWith('calls:recents')
  })
})
