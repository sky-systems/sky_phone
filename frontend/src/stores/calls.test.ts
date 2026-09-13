import { createPinia, disposePinia, setActivePinia } from 'pinia'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { useCallsStore } from '@/stores/calls'
import { usePhoneStore } from '@/stores/phone'
import type { PhoneCall } from '@/types/phone'
import { nuiCall } from '@/utils/nui'
import {
  playPhoneMediaTone,
  playPhoneTone,
  playPhoneVibration,
} from '@/utils/tones'

vi.mock('@/utils/nui', () => ({
  nuiCall: vi.fn(async () => ({ success: true, data: [] })),
}))
vi.mock('@/utils/tones', () => ({
  playPhoneMediaTone: vi.fn(() => vi.fn()),
  playPhoneTone: vi.fn(() => vi.fn()),
  playPhoneVibration: vi.fn(() => vi.fn()),
}))

describe('calls store', () => {
  let pinia: ReturnType<typeof createPinia>
  beforeEach(() => {
    vi.useFakeTimers()
    vi.stubGlobal('window', {
      matchMedia: vi.fn(() => ({ matches: false })),
      setTimeout,
    })
    pinia = createPinia()
    setActivePinia(pinia)
  })

  afterEach(() => {
    disposePinia(pinia)
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
    expect(playPhoneMediaTone).not.toHaveBeenCalled()

    calls.applyCallState({
      direction: 'incoming',
      id: 'call-1',
      otherNumber: '1234567890',
      startedAt: 1,
      state: 'connected',
    })
    expect(stop).toHaveBeenCalledOnce()
  })

  it('loops the vibration alert for incoming calls while globally muted', () => {
    const phone = usePhoneStore()
    phone.preferences.settings.notificationVolume = 0
    phone.preferences.settings.ringtoneVolume = 0
    const calls = useCallsStore()

    calls.applyCallState({
      direction: 'incoming',
      id: 'call-muted',
      otherNumber: '1234567890',
      startedAt: 1,
      state: 'ringing',
    })

    expect(playPhoneVibration).toHaveBeenCalledWith('call', true)
    expect(playPhoneMediaTone).not.toHaveBeenCalled()
  })

  const outgoingCall: PhoneCall = {
    direction: 'outgoing',
    id: 'outgoing-call',
    otherNumber: '5551110025',
    startedAt: 1,
    state: 'ringing',
  }

  it('loops the supplied calling sound once across duplicate outgoing states', () => {
    const stop = vi.fn()
    vi.mocked(playPhoneMediaTone).mockReturnValueOnce(stop)
    const calls = useCallsStore()
    calls.applyCallState(outgoingCall)
    calls.applyCallState({ ...outgoingCall, otherNumber: '5552220035' })

    expect(playPhoneMediaTone).toHaveBeenCalledExactlyOnceWith(
      expect.stringContaining('sounds/calling.mp3'),
      100,
      true,
    )
    expect(stop).not.toHaveBeenCalled()
    expect(playPhoneTone).not.toHaveBeenCalled()
    expect(playPhoneVibration).not.toHaveBeenCalled()
  })

  it.each([
    'connected',
    'completed',
    'missed',
    'declined',
    'busy',
    'unavailable',
    'no_answer',
    'cancelled',
    'disconnected',
    'sim_removed',
  ] as const)('stops the outgoing sound immediately on %s', (state) => {
    const stop = vi.fn()
    vi.mocked(playPhoneMediaTone).mockReturnValueOnce(stop)
    const calls = useCallsStore()
    calls.applyCallState(outgoingCall)
    calls.applyCallState({ ...outgoingCall, state })
    expect(stop).toHaveBeenCalledOnce()
    if (state === 'connected') {
      expect(playPhoneMediaTone).toHaveBeenCalledOnce()
    } else {
      expect(playPhoneMediaTone).toHaveBeenLastCalledWith(
        expect.stringContaining('sounds/endcall.mp3'),
        100,
        false,
      )
      expect(stop.mock.invocationCallOrder[0]).toBeLessThan(
        vi.mocked(playPhoneMediaTone).mock.invocationCallOrder[1]!,
      )
    }
  })

  it('starts the sound after a successful dial and stops on local hangup', async () => {
    const stop = vi.fn()
    vi.mocked(playPhoneMediaTone).mockReturnValueOnce(stop)
    vi.mocked(nuiCall).mockResolvedValueOnce({
      success: true,
      data: outgoingCall,
    })
    const calls = useCallsStore()
    await calls.dial(outgoingCall.otherNumber)
    expect(playPhoneMediaTone).toHaveBeenCalledOnce()
    expect(await calls.hangup()).toBe(true)
    expect(stop).toHaveBeenCalledOnce()
    expect(calls.activeCall).toBeNull()
  })

  it('does not play a calling sound when dialing fails', async () => {
    vi.mocked(nuiCall).mockResolvedValueOnce({
      success: false,
      error: 'unavailable',
    })
    await useCallsStore().dial(outgoingCall.otherNumber)
    expect(playPhoneMediaTone).not.toHaveBeenCalled()
  })

  it('releases the outgoing sound when the active call is cleared or the store is disposed', () => {
    const stopFirst = vi.fn()
    const stopEnd = vi.fn()
    const stopSecond = vi.fn()
    vi.mocked(playPhoneMediaTone)
      .mockReturnValueOnce(stopFirst)
      .mockReturnValueOnce(stopEnd)
      .mockReturnValueOnce(stopSecond)
    const calls = useCallsStore()
    calls.applyCallState(outgoingCall)
    calls.activeCall = null
    expect(stopFirst).toHaveBeenCalledOnce()
    calls.applyCallState({ ...outgoingCall, id: 'next-call' })
    expect(stopEnd).toHaveBeenCalledOnce()
    calls.$dispose()
    expect(stopSecond).toHaveBeenCalledOnce()
  })

  it('replaces the outgoing sound with the ringtone when switching to an incoming call', () => {
    const stop = vi.fn()
    vi.mocked(playPhoneMediaTone).mockReturnValueOnce(stop)
    const calls = useCallsStore()
    calls.applyCallState(outgoingCall)
    calls.applyCallState({
      ...outgoingCall,
      id: 'incoming-call',
      direction: 'incoming',
    })
    expect(stop).toHaveBeenCalledOnce()
    expect(playPhoneTone).toHaveBeenCalledWith('apex', 80, true)
  })

  it.each(['incoming', 'outgoing'] as const)(
    'plays the end tone once for a completed %s call despite repeated terminal events',
    async (direction) => {
      const stopEnd = vi.fn()
      vi.mocked(playPhoneMediaTone).mockReturnValueOnce(stopEnd)
      const calls = useCallsStore()
      calls.applyCallState({ ...outgoingCall, direction, state: 'connected' })
      calls.applyCallState({ ...outgoingCall, direction, state: 'completed' })
      calls.applyCallState({ ...outgoingCall, direction, state: 'completed' })
      calls.applyCallState({
        ...outgoingCall,
        direction,
        state: 'disconnected',
      })
      await vi.advanceTimersByTimeAsync(1600)

      expect(playPhoneMediaTone).toHaveBeenCalledExactlyOnceWith(
        expect.stringContaining('sounds/endcall.mp3'),
        100,
        false,
      )
      expect(stopEnd).not.toHaveBeenCalled()
      expect(calls.activeCall).toBeNull()
      calls.$dispose()
      expect(stopEnd).toHaveBeenCalledOnce()
    },
  )

  it('does not duplicate or cut off the end tone when hangup acknowledgement clears a terminal state', async () => {
    const stopEnd = vi.fn()
    vi.mocked(playPhoneMediaTone).mockReturnValueOnce(stopEnd)
    const calls = useCallsStore()
    calls.applyCallState({ ...outgoingCall, state: 'connected' })
    const pendingHangup = calls.hangup()
    calls.applyCallState({ ...outgoingCall, state: 'completed' })
    await pendingHangup
    calls.applyCallState({ ...outgoingCall, state: 'completed' })
    expect(playPhoneMediaTone).toHaveBeenCalledOnce()
    expect(stopEnd).not.toHaveBeenCalled()
  })

  it('stops the end tone when a new call begins', () => {
    const stopEnd = vi.fn()
    vi.mocked(playPhoneMediaTone).mockReturnValueOnce(stopEnd)
    const calls = useCallsStore()
    calls.applyCallState({ ...outgoingCall, state: 'completed' })
    calls.applyCallState({ ...outgoingCall, id: 'next-call' })
    expect(stopEnd).toHaveBeenCalledOnce()
    expect(playPhoneMediaTone).toHaveBeenLastCalledWith(
      expect.stringContaining('sounds/calling.mp3'),
      100,
      true,
    )
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

  it('blocks the active caller and closes the call screen', async () => {
    const calls = useCallsStore()
    calls.applyCallState({
      direction: 'incoming',
      id: 'call-3',
      otherNumber: '5551110025',
      startedAt: 1,
      state: 'ringing',
    })

    const response = await calls.blockNumber('5551110025')

    expect(response.success).toBe(true)
    expect(nuiCall).toHaveBeenCalledWith('calls:block', {
      phoneNumber: '5551110025',
    })
    expect(calls.activeCall).toBeNull()
    expect(nuiCall).toHaveBeenCalledWith('calls:recents')
  })

  it('applies the provider-authoritative speaker state for a connected call', async () => {
    vi.mocked(nuiCall).mockResolvedValueOnce({
      success: true,
      data: { speakerEnabled: true },
    })
    const calls = useCallsStore()
    calls.applyCallState({
      direction: 'outgoing',
      id: 'call-speaker',
      otherNumber: '5551110025',
      speakerEnabled: false,
      speakerSupported: true,
      startedAt: 1,
      state: 'connected',
    })

    const response = await calls.setSpeaker(true)

    expect(response.success).toBe(true)
    expect(nuiCall).toHaveBeenCalledWith('calls:set-speaker', {
      enabled: true,
      id: 'call-speaker',
    })
    expect(calls.activeCall?.speakerEnabled).toBe(true)
  })

  it('does not simulate speaker state for unsupported voice providers', async () => {
    const calls = useCallsStore()
    calls.applyCallState({
      direction: 'outgoing',
      id: 'call-pma',
      otherNumber: '5551110025',
      speakerEnabled: false,
      speakerSupported: false,
      startedAt: 1,
      state: 'connected',
    })

    const response = await calls.setSpeaker(true)

    expect(response).toEqual({
      error: 'speaker_unavailable',
      success: false,
    })
    expect(nuiCall).not.toHaveBeenCalled()
    expect(calls.activeCall?.speakerEnabled).toBe(false)
  })

  it('applies the provider-authoritative mute state for a Yaca call', async () => {
    vi.mocked(nuiCall).mockResolvedValueOnce({
      success: true,
      data: { muted: true },
    })
    const calls = useCallsStore()
    calls.applyCallState({
      direction: 'outgoing',
      id: 'call-yaca-mute',
      muted: false,
      muteSupported: true,
      otherNumber: '5551110025',
      startedAt: 1,
      state: 'connected',
    })

    const response = await calls.setMuted(true)

    expect(response.success).toBe(true)
    expect(nuiCall).toHaveBeenCalledWith('calls:set-muted', {
      enabled: true,
      id: 'call-yaca-mute',
    })
    expect(calls.activeCall?.muted).toBe(true)
  })

  it('does not simulate mute state for unsupported voice providers', async () => {
    const calls = useCallsStore()
    calls.applyCallState({
      direction: 'outgoing',
      id: 'call-pma-mute',
      muted: false,
      muteSupported: false,
      otherNumber: '5551110025',
      startedAt: 1,
      state: 'connected',
    })

    const response = await calls.setMuted(true)

    expect(response).toEqual({
      error: 'mute_unavailable',
      success: false,
    })
    expect(nuiCall).not.toHaveBeenCalled()
    expect(calls.activeCall?.muted).toBe(false)
  })

  it('updates a contact favorite and refreshes the contact list', async () => {
    vi.mocked(nuiCall)
      .mockResolvedValueOnce({
        success: true,
        data: { favorite: true, id: 'contact-alex' },
      })
      .mockResolvedValueOnce({
        success: true,
        data: [
          {
            favorite: true,
            id: 'contact-alex',
            name: 'Alex Rivera',
            phone_number: '5551110001',
          },
        ],
      })
    const calls = useCallsStore()

    const response = await calls.setContactFavorite('contact-alex', true)

    expect(response.success).toBe(true)
    expect(nuiCall).toHaveBeenNthCalledWith(1, 'contacts:favorite', {
      favorite: true,
      id: 'contact-alex',
    })
    expect(nuiCall).toHaveBeenNthCalledWith(2, 'contacts:list')
    expect(calls.contacts[0]?.favorite).toBe(true)
  })

  it('sends a contact email and refreshes the contact list after saving', async () => {
    const savedContact = {
      email: 'alex.rivera@ifruit.com',
      id: 'contact-alex',
      name: 'Alex Rivera',
      organization: 'Maze Bank',
      phone_number: '5551110001',
    }
    vi.mocked(nuiCall)
      .mockResolvedValueOnce({ success: true, data: savedContact })
      .mockResolvedValueOnce({ success: true, data: [savedContact] })
    const calls = useCallsStore()

    const response = await calls.saveContact({
      email: 'alex.rivera@ifruit.com',
      id: 'contact-alex',
      name: 'Alex Rivera',
      organization: 'Maze Bank',
      phoneNumber: '5551110001',
    })

    expect(response).toEqual({ success: true, data: savedContact })
    expect(nuiCall).toHaveBeenNthCalledWith(1, 'contacts:save', {
      email: 'alex.rivera@ifruit.com',
      id: 'contact-alex',
      name: 'Alex Rivera',
      organization: 'Maze Bank',
      phoneNumber: '5551110001',
    })
    expect(nuiCall).toHaveBeenNthCalledWith(2, 'contacts:list')
    expect(calls.contacts[0]?.email).toBe('alex.rivera@ifruit.com')
  })

  it('keeps configured company branding on system contacts', async () => {
    vi.mocked(nuiCall).mockResolvedValueOnce({
      success: true,
      data: [
        {
          avatar_url:
            'https://picsum.photos/seed/companies-police-logo/180/180',
          companyId: 'police',
          id: 'company:police',
          name: 'Los Santos Police Department',
          organization: 'Los Santos Police Department',
          phone_number: '911',
          readonly: true,
          source: 'company',
        },
      ],
    })
    const calls = useCallsStore()

    await calls.loadContacts()

    expect(calls.contacts[0]).toMatchObject({
      avatar_url: 'https://picsum.photos/seed/companies-police-logo/180/180',
      organization: 'Los Santos Police Department',
      source: 'company',
    })
  })
})
