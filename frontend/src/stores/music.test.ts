import { createPinia, setActivePinia } from 'pinia'
import {
  afterEach,
  beforeAll,
  beforeEach,
  describe,
  expect,
  it,
  vi,
} from 'vitest'

import type { MusicTrack } from '@/types/music'
import { nuiCall } from '@/utils/nui'
import { cellular } from '@/utils/cellular'

vi.mock('@/utils/nui', () => ({ nuiCall: vi.fn() }))

class FakeAudio extends EventTarget {
  static latest: FakeAudio | null = null

  currentTime = 0
  duration = 0
  paused = true
  preload = ''
  seekable = {
    end: () => 0,
    length: 0,
    start: () => 0,
  } as TimeRanges
  src = ''
  volume = 1

  load = vi.fn()

  constructor() {
    super()
    FakeAudio.latest = this
  }

  pause(): void {
    if (this.paused) return
    this.paused = true
    this.dispatchEvent(new Event('pause'))
  }

  async play(): Promise<void> {
    this.paused = false
    this.dispatchEvent(new Event('play'))
  }

  removeAttribute(name: string): void {
    if (name === 'src') this.src = ''
  }

  reset(): void {
    this.currentTime = 0
    this.duration = 0
    this.paused = true
    this.seekable = {
      end: () => 0,
      length: 0,
      start: () => 0,
    } as TimeRanges
    this.src = ''
    this.volume = 1
    this.load.mockClear()
  }
}

const fetchMock = vi.fn<typeof fetch>()
const createObjectUrlMock = vi.fn<(blob: Blob) => string>()
const revokeObjectUrlMock = vi.fn<(url: string) => void>()
let fakeAudio: FakeAudio
let useMusicStore: (typeof import('@/stores/music'))['useMusicStore']

function track(id: string, extension: 'mp3' | 'ogg' = 'ogg'): MusicTrack {
  return {
    artist: 'Sky Records',
    artwork: null,
    id,
    source: 'server',
    title: id,
    url: `https://cfx-nui-sky_phone/config/music/${id}.${extension}`,
  }
}

function audioResponse(bytes = [1, 2, 3]): Response {
  return {
    arrayBuffer: vi.fn().mockResolvedValue(Uint8Array.from(bytes).buffer),
    ok: true,
    status: 200,
  } as unknown as Response
}

beforeAll(async () => {
  vi.stubGlobal('Audio', FakeAudio)
  vi.stubGlobal('fetch', fetchMock)
  vi.stubGlobal('window', {
    location: {
      href: 'https://cfx-nui-sky_phone/source/html/index.html#/music',
    },
  })
  Object.defineProperty(URL, 'createObjectURL', {
    configurable: true,
    value: createObjectUrlMock,
  })
  Object.defineProperty(URL, 'revokeObjectURL', {
    configurable: true,
    value: revokeObjectUrlMock,
  })
  ;({ useMusicStore } = await import('@/stores/music'))
  if (!FakeAudio.latest)
    throw new Error('Music audio test double was not used.')
  fakeAudio = FakeAudio.latest
})

beforeEach(() => {
  cellular.enabled = false
  cellular.hasSignal = true
  setActivePinia(createPinia())
  fakeAudio.reset()
  fetchMock.mockReset()
  createObjectUrlMock.mockReset()
  createObjectUrlMock.mockReturnValue('blob:sky-music')
  revokeObjectUrlMock.mockReset()
  vi.mocked(nuiCall).mockReset()
})

afterEach(() => {
  useMusicStore().stop()
})

describe('music server playback', () => {
  it('blocks YouTube playback and resume without reception while bundled tracks remain playable', async () => {
    cellular.enabled = true
    cellular.hasSignal = false
    const music = useMusicStore()
    const youtubeTrack: MusicTrack = {
      id: 'remote',
      artist: '',
      title: 'Remote',
      artwork: null,
      source: 'youtube',
      videoId: 'remote',
    }
    await music.play(youtubeTrack)
    expect(music.playbackError).toBe('no_signal')
    expect(music.isPlaying).toBe(false)
    music.currentTrack = youtubeTrack
    await music.toggle()
    expect(music.isPlaying).toBe(false)
    fetchMock.mockResolvedValue(audioResponse())
    await music.play(track('offline'))
    expect(music.isPlaying).toBe(true)
    expect(music.playbackError).toBe('')
  })

  it('loads CFX-NUI audio into a seekable Blob URL', async () => {
    fetchMock.mockResolvedValue(audioResponse())
    const music = useMusicStore()

    await music.play(track('night-drive'), [track('night-drive')])

    expect(fetchMock).toHaveBeenCalledWith(
      'https://cfx-nui-sky_phone/config/music/night-drive.ogg',
      { signal: expect.any(AbortSignal) },
    )
    expect(createObjectUrlMock).toHaveBeenCalledOnce()
    expect(createObjectUrlMock.mock.calls[0]?.[0].type).toBe('audio/ogg')
    expect(fakeAudio.src).toBe('blob:sky-music')
    expect(music.isPlaying).toBe(true)
  })

  it('updates duration and seeks within the track bounds', async () => {
    fetchMock.mockResolvedValue(audioResponse())
    const music = useMusicStore()
    const serverTrack = track('bounded-seek', 'mp3')
    await music.play(serverTrack, [serverTrack])

    fakeAudio.duration = 120
    fakeAudio.dispatchEvent(new Event('loadedmetadata'))
    music.seek(42)

    expect(music.duration).toBe(120)
    expect(fakeAudio.currentTime).toBe(42)
    expect(music.currentTime).toBe(42)

    music.seek(999)
    expect(fakeAudio.currentTime).toBe(120)

    music.seek(-10)
    expect(fakeAudio.currentTime).toBe(0)
  })

  it('revokes the active Blob URL when playback stops', async () => {
    fetchMock.mockResolvedValue(audioResponse())
    const music = useMusicStore()
    const serverTrack = track('cleanup')
    await music.play(serverTrack, [serverTrack])

    music.stop()

    expect(revokeObjectUrlMock).toHaveBeenCalledOnce()
    expect(revokeObjectUrlMock).toHaveBeenCalledWith('blob:sky-music')
    expect(fakeAudio.src).toBe('')
  })

  it('does not let a stale audio request replace a newer track', async () => {
    let resolveFirstRequest: ((response: Response) => void) | undefined
    fetchMock
      .mockImplementationOnce(
        () =>
          new Promise<Response>((resolve) => {
            resolveFirstRequest = resolve
          }),
      )
      .mockResolvedValueOnce(audioResponse([4, 5, 6]))
    const music = useMusicStore()
    const firstTrack = track('first')
    const secondTrack = track('second')

    const firstPlay = music.play(firstTrack, [firstTrack, secondTrack])
    await music.play(secondTrack, [firstTrack, secondTrack])
    resolveFirstRequest?.(audioResponse())
    await firstPlay

    expect(music.currentTrack?.id).toBe('second')
    expect(fakeAudio.src).toBe('blob:sky-music')
    expect(createObjectUrlMock).toHaveBeenCalledOnce()
  })
})

describe('music playlists', () => {
  it('adds a track with the expected payload and applies the refreshed playlist', async () => {
    const serverTrack = track('night-drive')
    vi.mocked(nuiCall).mockResolvedValueOnce({
      data: {
        playlists: [
          {
            createdAt: 1,
            entries: [{ songId: serverTrack.id, source: serverTrack.source }],
            id: 'playlist-1',
            name: 'Night Ride',
          },
        ],
        serverTracks: [serverTrack],
        youtubeTracks: [],
      },
      success: true,
    })
    const music = useMusicStore()

    const success = await music.addToPlaylist('playlist-1', serverTrack)

    expect(success).toBe(true)
    expect(nuiCall).toHaveBeenCalledWith('music:add-to-playlist', {
      playlistId: 'playlist-1',
      songId: 'night-drive',
      source: 'server',
    })
    expect(music.playlists[0]?.entries).toEqual([
      { songId: 'night-drive', source: 'server' },
    ])
  })

  it('surfaces a duplicate-track error and releases the loading state', async () => {
    const serverTrack = track('night-drive')
    vi.mocked(nuiCall).mockResolvedValueOnce({
      error: 'song_already_in_playlist',
      success: false,
    })
    const music = useMusicStore()

    const success = await music.addToPlaylist('playlist-1', serverTrack)

    expect(success).toBe(false)
    expect(music.error).toBe('song_already_in_playlist')
    expect(music.isLoading).toBe(false)
  })
})
