import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { captureDisplay } from './captureDisplay'
import { nuiCall } from './nui'
import { installWorldDisplayCapture } from './worldDisplay'

vi.mock('./captureDisplay', () => ({ captureDisplay: vi.fn() }))
vi.mock('./nui', () => ({ nuiCall: vi.fn() }))

const jpeg =
  'data:image/jpeg;base64,' +
  Buffer.from([
    255,
    216,
    255,
    192,
    0,
    11,
    8,
    3,
    12,
    1,
    104,
    1,
    1,
    17,
    0,
    ...Array(90).fill(0),
  ]).toString('base64')
const canvas = { toDataURL: vi.fn(() => jpeg) } as unknown as HTMLCanvasElement

describe('world display capture lifetime and idle work', () => {
  let root: EventTarget
  let screen: HTMLElement
  let mutations: MutationCallback
  let disconnect: ReturnType<typeof vi.fn>
  let dispose: () => void

  beforeEach(() => {
    vi.useFakeTimers()
    vi.mocked(captureDisplay).mockReset().mockResolvedValue(canvas)
    vi.mocked(nuiCall).mockReset().mockResolvedValue({ success: true })
    root = new EventTarget()
    screen = Object.assign(new EventTarget(), {
      clientWidth: 360,
      querySelector: vi.fn(() => null),
      querySelectorAll: vi.fn(() => []),
      getAnimations: vi.fn(() => []),
    }) as unknown as HTMLElement
    disconnect = vi.fn()
    vi.stubGlobal(
      'MutationObserver',
      class {
        constructor(callback: MutationCallback) {
          mutations = callback
        }
        observe = vi.fn()
        disconnect = disconnect
      },
    )
    vi.stubGlobal('window', Object.assign(root, { setInterval, clearInterval }))
    vi.stubGlobal('document', {
      fonts: new EventTarget(),
      querySelector: vi.fn(() => screen),
    })
    dispose = installWorldDisplayCapture()
  })

  afterEach(() => {
    dispose()
    vi.unstubAllGlobals()
    vi.useRealTimers()
  })

  function permit(token: number | false = 1) {
    root.dispatchEvent(
      Object.assign(new Event('message'), {
        data: { type: 'phone:world-display', token },
      }),
    )
  }

  function mutate(attributeName: string | null = null) {
    mutations([{ attributeName } as MutationRecord], {} as MutationObserver)
  }

  it('does no DOM capture without permission and reuses still pixels for the lease', async () => {
    await vi.advanceTimersByTimeAsync(2000)
    expect(captureDisplay).not.toHaveBeenCalled()
    permit()
    await vi.advanceTimersByTimeAsync(500)
    expect(captureDisplay).toHaveBeenCalledTimes(1)
    await vi.advanceTimersByTimeAsync(2000)
    expect(captureDisplay).toHaveBeenCalledTimes(1)
    expect(nuiCall).toHaveBeenCalledTimes(5)
    expect(nuiCall).toHaveBeenLastCalledWith('worldDisplay:frame', {
      jpeg,
      sequence: 5,
      token: 1,
    })
  })

  it('captures changed text and scroll/input/load/seek events on the next tick', async () => {
    permit()
    await vi.advanceTimersByTimeAsync(500)
    mutate()
    await vi.advanceTimersByTimeAsync(500)
    for (const name of ['scroll', 'input', 'change', 'load', 'seeked']) {
      screen.dispatchEvent(new Event(name))
      await vi.advanceTimersByTimeAsync(500)
    }
    expect(captureDisplay).toHaveBeenCalledTimes(7)
  })

  it('ignores capture-owned temporary attributes and repeated permission signals', async () => {
    permit()
    await vi.advanceTimersByTimeAsync(500)
    mutate('data-sky-display-scroll')
    mutate('data-sky-display-videos')
    permit()
    await vi.advanceTimersByTimeAsync(500)
    expect(captureDisplay).toHaveBeenCalledTimes(1)
    mutate('class')
    await vi.advanceTimersByTimeAsync(500)
    expect(captureDisplay).toHaveBeenCalledTimes(2)
  })

  it('refreshes CSS interaction, font and viewport changes without DOM mutations', async () => {
    permit()
    await vi.advanceTimersByTimeAsync(500)
    for (const name of [
      'focusin',
      'focusout',
      'pointerover',
      'pointerout',
      'pointerdown',
      'pointerup',
      'keydown',
      'keyup',
    ]) {
      screen.dispatchEvent(new Event(name))
      await vi.advanceTimersByTimeAsync(500)
    }
    document.fonts.dispatchEvent(new Event('loadingdone'))
    await vi.advanceTimersByTimeAsync(500)
    root.dispatchEvent(new Event('resize'))
    await vi.advanceTimersByTimeAsync(500)
    expect(captureDisplay).toHaveBeenCalledTimes(11)
  })

  it('preserves changes received while the previous capture is pending', async () => {
    let finish!: (canvas: HTMLCanvasElement) => void
    vi.mocked(captureDisplay).mockImplementationOnce(
      () => new Promise((resolve) => (finish = resolve)),
    )
    permit()
    await vi.advanceTimersByTimeAsync(500)
    mutate()
    await vi.advanceTimersByTimeAsync(1000)
    expect(captureDisplay).toHaveBeenCalledTimes(1)
    finish(canvas)
    await vi.advanceTimersByTimeAsync(500)
    expect(captureDisplay).toHaveBeenCalledTimes(2)
  })

  it('captures live canvas/video and the final CSS animation frame', async () => {
    permit()
    vi.mocked(screen.querySelector).mockReturnValue({} as Element)
    await vi.advanceTimersByTimeAsync(1000)
    expect(captureDisplay).toHaveBeenCalledTimes(2)
    vi.mocked(screen.querySelector).mockReturnValue(null)
    vi.mocked(screen.querySelectorAll).mockReturnValue([
      { paused: false, ended: false },
    ] as unknown as NodeListOf<HTMLVideoElement>)
    await vi.advanceTimersByTimeAsync(500)
    expect(captureDisplay).toHaveBeenCalledTimes(3)
    vi.mocked(screen.querySelectorAll).mockReturnValue(
      [] as unknown as NodeListOf<HTMLVideoElement>,
    )
    vi.mocked(screen.getAnimations).mockReturnValue([
      { playState: 'running' } as Animation,
    ])
    await vi.advanceTimersByTimeAsync(500)
    vi.mocked(screen.getAnimations).mockReturnValue([])
    await vi.advanceTimersByTimeAsync(1000)
    expect(captureDisplay).toHaveBeenCalledTimes(5)
  })

  it('never publishes a late capture into a revoked or newer session', async () => {
    let finish!: (canvas: HTMLCanvasElement) => void
    vi.mocked(captureDisplay).mockImplementationOnce(
      () => new Promise((resolve) => (finish = resolve)),
    )
    permit(1)
    await vi.advanceTimersByTimeAsync(500)
    permit(false)
    permit(2)
    finish(canvas)
    await vi.advanceTimersByTimeAsync(500)
    expect(nuiCall).toHaveBeenCalledTimes(1)
    expect(nuiCall).toHaveBeenCalledWith('worldDisplay:frame', {
      jpeg,
      sequence: 1,
      token: 2,
    })
  })

  it('disconnects observers and cancels owned work on disposal', async () => {
    permit()
    await vi.advanceTimersByTimeAsync(500)
    dispose()
    permit(2)
    screen.dispatchEvent(new Event('scroll'))
    await vi.advanceTimersByTimeAsync(2500)
    expect(disconnect).toHaveBeenCalled()
    expect(vi.getTimerCount()).toBe(0)
    expect(captureDisplay).toHaveBeenCalledTimes(1)
    expect(nuiCall).toHaveBeenCalledTimes(1)
  })
})
