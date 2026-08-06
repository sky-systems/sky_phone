import { describe, expect, it } from 'vitest'

import {
  filterMedia,
  formatRecordingDuration,
  mediaErrorKey,
  mergeMedia,
} from './media'

const media = [
  { createdAt: 10, id: 1, mediaType: 'photo' as const, url: 'photo' },
  { createdAt: 20, id: 2, mediaType: 'video' as const, url: 'video' },
]

describe('media utilities', () => {
  it('filters gallery media by explicit type', () => {
    expect(filterMedia(media, 'all')).toHaveLength(2)
    expect(filterMedia(media, 'photo').map((entry) => entry.id)).toEqual([1])
    expect(filterMedia(media, 'video').map((entry) => entry.id)).toEqual([2])
  })

  it('merges pages without duplicates and keeps newest first', () => {
    expect(
      mergeMedia(media, [
        { createdAt: 30, id: 1, mediaType: 'photo', url: 'updated' },
        { createdAt: 25, id: 3, mediaType: 'photo', url: 'new' },
      ]).map((entry) => [entry.id, entry.url]),
    ).toEqual([
      [1, 'updated'],
      [3, 'new'],
      [2, 'video'],
    ])
  })

  it('formats unlimited recording durations', () => {
    expect(formatRecordingDuration(0)).toBe('00:00')
    expect(formatRecordingDuration(3_725_000)).toBe('62:05')
  })

  it('maps unknown server failures to the localized default', () => {
    expect(mediaErrorKey('upload_timeout')).toBe('upload_timeout')
    expect(mediaErrorKey('private_provider_error')).toBe('request_failed')
  })
})
