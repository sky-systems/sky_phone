import { describe, expect, it } from 'vitest'

import {
  bottomRightGridPosition,
  filterMedia,
  formatMediaSize,
  formatRecordingDuration,
  hasNextMediaPage,
  mediaErrorKey,
  mergeMedia,
  orderMedia,
  orderMediaOldestFirst,
} from './media'

const media = [
  {
    createdAt: 10,
    favorite: false,
    id: 1,
    mediaType: 'photo' as const,
    url: 'photo',
  },
  {
    createdAt: 20,
    favorite: false,
    id: 2,
    mediaType: 'video' as const,
    url: 'video',
  },
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
        {
          createdAt: 30,
          favorite: true,
          id: 1,
          mediaType: 'photo',
          url: 'updated',
        },
        {
          createdAt: 25,
          favorite: false,
          id: 3,
          mediaType: 'photo',
          url: 'new',
        },
      ]).map((entry) => [entry.id, entry.url]),
    ).toEqual([
      [1, 'updated'],
      [3, 'new'],
      [2, 'video'],
    ])
  })

  it('orders the photo grid from oldest to newest', () => {
    expect(orderMediaOldestFirst(media).map((entry) => entry.id)).toEqual([
      1, 2,
    ])
  })

  it('orders the photo grid in the selected direction', () => {
    expect(orderMedia(media, 'oldest').map((entry) => entry.id)).toEqual([1, 2])
    expect(orderMedia(media, 'newest').map((entry) => entry.id)).toEqual([2, 1])
  })

  it('fills the gallery from bottom-right to top-left', () => {
    expect(bottomRightGridPosition(0, 1)).toEqual({ column: 3, row: 1 })
    expect(bottomRightGridPosition(0, 3)).toEqual({ column: 3, row: 1 })
    expect(bottomRightGridPosition(1, 3)).toEqual({ column: 2, row: 1 })
    expect(bottomRightGridPosition(2, 3)).toEqual({ column: 1, row: 1 })
    expect(bottomRightGridPosition(0, 4)).toEqual({ column: 3, row: 2 })
    expect(bottomRightGridPosition(3, 4)).toEqual({ column: 3, row: 1 })
    expect(bottomRightGridPosition(4, 5)).toEqual({ column: 2, row: 1 })
    expect(bottomRightGridPosition(10, 11)).toEqual({ column: 2, row: 1 })
  })

  it('places newest-first media from the bottom-right toward older rows', () => {
    const newestFirst = orderMedia(
      [
        {
          createdAt: 10,
          favorite: false,
          id: 1,
          mediaType: 'photo',
          url: 'oldest',
        },
        {
          createdAt: 20,
          favorite: false,
          id: 2,
          mediaType: 'photo',
          url: 'middle',
        },
        {
          createdAt: 30,
          favorite: false,
          id: 3,
          mediaType: 'photo',
          url: 'newest',
        },
        {
          createdAt: 5,
          favorite: false,
          id: 4,
          mediaType: 'photo',
          url: 'older-row',
        },
      ],
      'newest',
    )

    expect(
      newestFirst.map((entry, index) => ({
        id: entry.id,
        ...bottomRightGridPosition(index, newestFirst.length),
      })),
    ).toEqual([
      { column: 3, id: 3, row: 2 },
      { column: 2, id: 2, row: 2 },
      { column: 1, id: 1, row: 2 },
      { column: 3, id: 4, row: 1 },
    ])
  })

  it('loads another gallery page only after a full 30-item batch', () => {
    expect(hasNextMediaPage(30)).toBe(true)
    expect(hasNextMediaPage(29)).toBe(false)
    expect(hasNextMediaPage(0)).toBe(false)
  })

  it('formats unlimited recording durations', () => {
    expect(formatRecordingDuration(0)).toBe('00:00')
    expect(formatRecordingDuration(3_725_000)).toBe('62:05')
  })

  it('formats imported media sizes with the active locale', () => {
    expect(formatMediaSize(512, 'en')).toBe('512 B')
    expect(formatMediaSize(1_572_864, 'en')).toBe('1.5 MB')
  })

  it('maps unknown server failures to the localized default', () => {
    expect(mediaErrorKey('upload_timeout')).toBe('upload_timeout')
    expect(mediaErrorKey('import_media_too_large')).toBe(
      'import_media_too_large',
    )
    expect(mediaErrorKey('import_url_not_allowed')).toBe(
      'import_url_not_allowed',
    )
    expect(mediaErrorKey('profile_photo_required')).toBe(
      'profile_photo_required',
    )
    expect(mediaErrorKey('media_provider_failed')).toBe('media_provider_failed')
    expect(mediaErrorKey('media_provider_rate_limited')).toBe(
      'media_provider_rate_limited',
    )
    expect(mediaErrorKey('media_provider_unauthorized')).toBe(
      'media_provider_unauthorized',
    )
    expect(mediaErrorKey('private_provider_error')).toBe('request_failed')
  })
})
