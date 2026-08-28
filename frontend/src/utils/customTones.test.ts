import { beforeEach, describe, expect, it, vi } from 'vitest'

import { nuiCall } from '@/utils/nui'
import { playPhoneMediaTone } from '@/utils/tones'

import {
  CUSTOM_TONE_CHUNK_CHARS,
  MAX_CUSTOM_TONE_PAYLOAD_CHARS,
  findCustomPhoneTone,
  isCustomTonePreferenceId,
  parseCustomPhoneToneCatalog,
  playCustomPhoneTone,
} from './customTones'

vi.mock('@/utils/nui', () => ({ nuiCall: vi.fn() }))
vi.mock('@/utils/tones', () => ({ playPhoneMediaTone: vi.fn() }))

const DISPATCH_ID = '1fbd07b4-d231-4a76-b661-c9e5d0ab19a8'
const RETRO_ID = 'a1e8db72-bc56-41c8-84e2-521180e14db1'

function tone(
  id: string,
  label: string,
  toneType: 'notification' | 'ringtone',
  byteSize = 120_000,
) {
  return {
    byteSize,
    createdAt: '2026-08-27 12:00:00',
    durationMs: 8_500,
    id,
    label,
    mimeType: 'audio/mpeg',
    toneType,
  }
}

describe('custom phone tones', () => {
  beforeEach(() => vi.clearAllMocks())

  it('keeps transfer chunks below the reliable event ceiling and Base64-aligned', () => {
    expect(CUSTOM_TONE_CHUNK_CHARS).toBe(8_000)
    expect(CUSTOM_TONE_CHUNK_CHARS % 4).toBe(0)
    expect(
      Math.ceil(MAX_CUSTOM_TONE_PAYLOAD_CHARS / CUSTOM_TONE_CHUNK_CHARS),
    ).toBe(334)
  })

  it('accepts valid stored-audio catalog entries and creates namespaced preference ids', () => {
    const catalog = parseCustomPhoneToneCatalog({
      notificationSounds: [tone(DISPATCH_ID, 'Dispatch Alert', 'notification')],
      ringtones: [tone(RETRO_ID, 'Retro Ring', 'ringtone')],
    })

    expect(catalog.ringtones[0]).toMatchObject({
      id: `custom:${RETRO_ID}`,
      label: 'Retro Ring',
      mimeType: 'audio/mpeg',
    })
    expect(
      findCustomPhoneTone(catalog.notificationSounds, `custom:${DISPATCH_ID}`)
        ?.label,
    ).toBe('Dispatch Alert')
  })

  it('rejects malformed ids, mismatched categories, duplicates and blank labels', () => {
    const catalog = parseCustomPhoneToneCatalog({
      notificationSounds: [],
      ringtones: [
        tone('../escape', 'Escape', 'ringtone'),
        tone(DISPATCH_ID, 'Wrong category', 'notification'),
        tone(RETRO_ID, '   ', 'ringtone'),
        tone(DISPATCH_ID, 'Safe', 'ringtone'),
        tone(DISPATCH_ID, 'Duplicate', 'ringtone'),
      ],
    })

    expect(catalog.ringtones).toHaveLength(1)
    expect(catalog.ringtones[0]).toMatchObject({
      id: `custom:${DISPATCH_ID}`,
      label: 'Safe',
    })
    expect(isCustomTonePreferenceId(`custom:${DISPATCH_ID}`)).toBe(true)
    expect(isCustomTonePreferenceId('custom:../escape')).toBe(false)
  })

  it('accepts safe config-file tone ids in their matching category', () => {
    const catalog = parseCustomPhoneToneCatalog({
      notificationSounds: [],
      ringtones: [
        {
          ...tone('config:ringtone:dispatch_call', 'Dispatch Call', 'ringtone'),
          source: 'config',
        },
      ],
    })

    expect(catalog.ringtones[0]).toMatchObject({
      id: 'custom:config:ringtone:dispatch_call',
      source: 'config',
    })
    expect(
      isCustomTonePreferenceId('custom:config:ringtone:dispatch_call'),
    ).toBe(true)
  })

  it('accepts tones above the old 270 KB limit up to 2 MB', () => {
    const catalog = parseCustomPhoneToneCatalog({
      notificationSounds: [],
      ringtones: [
        tone(DISPATCH_ID, 'Large valid tone', 'ringtone', 1_500_000),
        tone(RETRO_ID, 'Too large', 'ringtone', 2_000_001),
      ],
    })

    expect(catalog.ringtones).toHaveLength(1)
    expect(catalog.ringtones[0]?.byteSize).toBe(1_500_000)
  })

  it('loads preview audio in one NUI request before starting playback', async () => {
    const customTone = parseCustomPhoneToneCatalog({
      notificationSounds: [],
      ringtones: [tone(DISPATCH_ID, 'Fast preview', 'ringtone')],
    }).ringtones[0]!
    const onStarted = vi.fn()
    const stopPlayback = vi.fn()
    vi.mocked(nuiCall).mockResolvedValue({
      data: {
        id: DISPATCH_ID,
        mimeType: 'audio/ogg',
        payload: 'T2dnUw==',
      },
      success: true,
    })
    vi.mocked(playPhoneMediaTone).mockImplementation(
      (_url, _volume, _loop, callbacks) => {
        callbacks?.onStarted?.()
        return stopPlayback
      },
    )

    const stop = playCustomPhoneTone(customTone, 70, false, { onStarted })

    await vi.waitFor(() => expect(onStarted).toHaveBeenCalledOnce())
    expect(nuiCall).toHaveBeenCalledOnce()
    expect(nuiCall).toHaveBeenCalledWith('tones:audio', { id: DISPATCH_ID })
    expect(playPhoneMediaTone).toHaveBeenCalledWith(
      'data:audio/ogg;base64,T2dnUw==',
      70,
      false,
      { onStarted },
    )
    stop()
    expect(stopPlayback).toHaveBeenCalledOnce()
  })
})
