import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { LiveMedia } from './media'
import { nuiCall } from '@/utils/nui'
import { createGameView } from '@/utils/gameView'
import type { RealtimeConfig } from './types'

vi.mock('@/utils/nui', () => ({ nuiCall: vi.fn() }))
vi.mock('@/utils/gameView', () => ({ createGameView: vi.fn() }))

const video = { kind: 'video', stop: vi.fn() }
class Stream {
  constructor(private tracks: (typeof video)[] = []) {}
  addTrack(track: typeof video) {
    this.tracks.push(track)
  }
  getTracks() {
    return this.tracks
  }
  getVideoTracks() {
    return this.tracks
  }
}
const config = { edge: 720, fps: 24 } as RealtimeConfig

describe('realtime camera startup', () => {
  beforeEach(() => {
    vi.stubGlobal('MediaStream', Stream)
    vi.stubGlobal('document', {
      createElement: () => ({ captureStream: () => new Stream([video]) }),
    })
    vi.stubGlobal('window', { innerWidth: 1920, innerHeight: 1080 })
    vi.stubGlobal(
      'requestAnimationFrame',
      vi.fn(() => 1),
    )
    vi.stubGlobal('cancelAnimationFrame', vi.fn())
    vi.mocked(nuiCall).mockResolvedValue({ success: true })
    vi.mocked(createGameView).mockReturnValue({
      resize: vi.fn(),
      render: vi.fn(),
      dispose: vi.fn(),
    } as unknown as ReturnType<typeof createGameView>)
  })
  afterEach(() => {
    vi.clearAllMocks()
    vi.unstubAllGlobals()
  })
  it('starts FaceTime directly in selfie mode without a rear-camera frame', async () => {
    const media = new LiveMedia()
    await media.start('call', config)
    expect(nuiCall).toHaveBeenCalledExactlyOnceWith('camera:setActive', {
      active: true,
      front: true,
    })
    expect(media.stream.getVideoTracks()).toEqual([video])
    media.dispose()
    expect(video.stop).toHaveBeenCalledOnce()
    expect(nuiCall).toHaveBeenLastCalledWith('camera:setActive', {
      active: false,
    })
  })
  it('does not capture or change facing after hangup during camera activation', async () => {
    let complete!: (value: { success: boolean }) => void
    vi.mocked(nuiCall).mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          complete = resolve
        }),
    )
    const media = new LiveMedia()
    const start = media.start('call', config)
    media.dispose()
    complete({ success: true })
    await start
    expect(createGameView).not.toHaveBeenCalled()
    expect(media.stream.getTracks()).toEqual([])
    expect(nuiCall).toHaveBeenLastCalledWith('camera:setActive', {
      active: false,
    })
  })
})
