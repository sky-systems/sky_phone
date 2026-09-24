import { describe, expect, it } from 'vitest'
import { createRouter, createMemoryHistory } from 'vue-router'

import type { EasySharePayload } from '@/types/easyshare'
import {
  easyShareCrewLinkInviteCode,
  easyShareDarkChatInviteCode,
  easyShareDestinationAppIds,
  easyShareMusicTarget,
  easyShareRoute,
  openEasySharePayload,
} from '@/utils/easyshare'

function payload(overrides: Partial<EasySharePayload>): EasySharePayload {
  return {
    appId: 'notes',
    copyText: 'Shared content',
    kind: 'note',
    title: 'Shared content',
    ...overrides,
  }
}

describe('EasyShare deep links', () => {
  it.each([
    ['skyphone://media/42', '/apps/photos'],
    ['skyphone://location/current', '/apps/map'],
    ['skyphone://phone/5550142', '/apps/phone'],
    ['skyphone://music/server/night-drive', '/apps/music'],
    ['skyphone://citymarkt/listing/listing-1', '/apps/citymarkt'],
  ])('routes %s into its source app', (link, path) => {
    expect(easyShareRoute(payload({ link })).path).toBe(path)
  })

  it('selects an incoming contact by its canonical phone number', () => {
    expect(
      easyShareRoute(
        payload({
          appId: 'phone',
          kind: 'contact',
          id: 'self',
          meta: { phoneNumber: '144 345 6011' },
        }),
      ).query.sharedContactNumber,
    ).toBe('1443456011')
  })
  it('also supports existing contact history without metadata', () => {
    expect(
      easyShareRoute(
        payload({ appId: 'phone', kind: 'contact', subtitle: '1443456011' }),
      ).query.sharedContactNumber,
    ).toBe('1443456011')
  })
  it('launches the same shared target again even while its app is open', async () => {
    const router = createRouter({
      history: createMemoryHistory(),
      routes: [{ path: '/apps/notes', component: {} }],
    })
    const note = payload({ id: 'received-note' })
    await openEasySharePayload(router, note)
    const first = router.currentRoute.value.query.easyShareLaunch
    await openEasySharePayload(router, note)
    expect(router.currentRoute.value.query.easyShareLaunch).not.toBe(first)
    expect(router.currentRoute.value.query.easyShareId).toBe('received-note')
  })

  it('falls back to the payload app and preserves share context', () => {
    expect(
      easyShareRoute(payload({ appId: 'calendar', id: 'event-1' })),
    ).toEqual({
      path: '/apps/calendar',
      query: {
        easyShareId: 'event-1',
        easyShareKind: 'note',
        easyShareLink: '',
        sharedContent: JSON.stringify({
          title: 'Shared content',
          body: 'Shared content',
          kind: 'note',
          items: [],
        }),
      },
    })
  })

  it('opens CityMarkt links on the referenced listing', () => {
    expect(
      easyShareRoute(
        payload({
          appId: 'citymarkt',
          id: 'listing-1',
          kind: 'link',
          link: 'skyphone://citymarkt/listing/listing-1',
        }),
      ).query.listingId,
    ).toBe('listing-1')
  })

  it.each([
    ['picstagram', 'post', 'pic-post-1', '/apps/picstagram'],
    ['picstagram', 'profile', 'pic-profile-1', '/apps/picstagram'],
    ['feather', 'post', 'feather-post-1', '/apps/feather'],
    ['fliptok', 'post', 'fliptok-1', '/apps/fliptok'],
    ['local-pages', 'post', 'pages-post-1', '/apps/local-pages'],
  ])('preserves the exact %s %s target', (appId, kind, id, path) => {
    expect(
      easyShareRoute(
        payload({
          appId: appId as EasySharePayload['appId'],
          id,
          kind: kind as EasySharePayload['kind'],
          link: `skyphone://${appId}/${kind}/${id}`,
        }),
      ),
    ).toMatchObject({
      path,
      query: { easyShareId: id, easyShareKind: kind },
    })
  })

  it('keeps chat snapshots separate from saved recipient copies', () => {
    const note = payload({ id: 'sender-note', meta: { body: 'Text' } })
    expect(JSON.parse(easyShareRoute(note).query.sharedContent).body).toBe(
      'Shared content',
    )
    const received = payload({
      id: 'recipient-note',
      meta: {
        received: { appId: 'notes', kind: 'note', id: 'recipient-note' },
      },
    })
    expect(easyShareRoute(received).query.sharedContent).toBeUndefined()
  })
  it('preserves canonical location and music snapshots for chat links', () => {
    const location = easyShareRoute(
      payload({ appId: 'map', kind: 'location', meta: { x: 1, y: 2, z: 3 } }),
    )
    expect(JSON.parse(location.query.sharedLocation)).toMatchObject({
      x: 1,
      y: 2,
      z: 3,
    })
    const playlist = easyShareRoute(
      payload({
        appId: 'music',
        kind: 'playlist',
        meta: { songs: [{ source: 'server', song_id: 'song' }] },
      }),
    )
    expect(JSON.parse(playlist.query.sharedMusic).songs).toHaveLength(1)
  })
  it('extracts a CrewLink invitation code from a shared deep link', () => {
    expect(
      easyShareCrewLinkInviteCode(
        'link',
        'skyphone://crewlink/invite/ab12cd34',
        'ignored',
      ),
    ).toBe('AB12CD34')
  })

  it('accepts the canonical payload id as a CrewLink invite fallback', () => {
    expect(easyShareCrewLinkInviteCode('link', '', 'n1ght247')).toBe('N1GHT247')
    expect(easyShareCrewLinkInviteCode('profile', '', 'n1ght247')).toBeNull()
    expect(easyShareCrewLinkInviteCode('link', '', 'invalid-code')).toBeNull()
  })

  it('extracts a private DarkChat invitation from its profile share', () => {
    expect(
      easyShareDarkChatInviteCode(
        'profile',
        'skyphone://darkchat/invite/dc-7x4k-nova',
      ),
    ).toBe('DC-7X4K-NOVA')
    expect(
      easyShareDarkChatInviteCode(
        'link',
        'skyphone://darkchat/invite/DC-7X4K-NOVA',
      ),
    ).toBeNull()
    expect(
      easyShareDarkChatInviteCode('profile', 'skyphone://darkchat/invite/bad'),
    ).toBeNull()
  })

  it.each([
    [
      'track',
      'skyphone://music/server/city-after-dark',
      { id: 'city-after-dark', kind: 'track', source: 'server' },
    ],
    [
      'track',
      'skyphone://music/youtube/music-youtube-1',
      { id: 'music-youtube-1', kind: 'track', source: 'youtube' },
    ],
    [
      'playlist',
      'skyphone://music/playlist/music-playlist-1',
      { id: 'music-playlist-1', kind: 'playlist' },
    ],
  ] as const)(
    'extracts the exact shared music target',
    (kind, link, target) => {
      expect(easyShareMusicTarget(kind, link)).toEqual(target)
    },
  )

  it('rejects mismatched music share kinds', () => {
    expect(
      easyShareMusicTarget(
        'playlist',
        'skyphone://music/server/city-after-dark',
      ),
    ).toBeNull()
  })
})

describe('EasyShare destination suggestions', () => {
  it.each(['document', 'link', 'location', 'note', 'text'] as const)(
    'offers Notes for %s content from another app',
    (kind) => {
      expect(
        easyShareDestinationAppIds(payload({ appId: 'calendar', kind })),
      ).toEqual(['messages', 'darkchat', 'flare', 'notes'])
    },
  )

  it.each([
    'contact',
    'photo',
    'playlist',
    'post',
    'profile',
    'track',
    'video',
  ] as const)(
    'does not suggest lossy Notes conversion for %s content',
    (kind) => {
      expect(easyShareDestinationAppIds(payload({ kind }))).toEqual([
        'messages',
        'darkchat',
        'flare',
      ])
    },
  )

  it('does not suggest saving a Notes item back into Notes', () => {
    expect(easyShareDestinationAppIds(payload({}))).toEqual([
      'messages',
      'darkchat',
      'flare',
    ])
  })
})
