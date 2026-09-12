import { afterEach, describe, expect, it, vi } from 'vitest'

import { ALARM_SOUND_IDS } from './alarms'
import {
  phoneToneDuration,
  playPhoneMediaTone,
  playPhoneVibration,
} from './tones'

describe('phone tones', () => {
  afterEach(() => vi.unstubAllGlobals())

  it('defines a playable duration for every alarm sound', () => {
    for (const sound of ALARM_SOUND_IDS) {
      expect(phoneToneDuration(sound)).toBeGreaterThan(0)
      expect(phoneToneDuration(sound)).toBeLessThanOrEqual(1500)
    }
  })

  it.each([
    ['notification', 'sounds/vibration-notification.mp3', false],
    ['call', 'sounds/vibration-call.mp3', true],
  ] as const)(
    'plays the %s vibration asset with the requested loop behavior',
    (kind, path, loop) => {
      const pause = vi.fn()
      const play = vi.fn(async () => undefined)
      const players: Array<{
        currentTime: number
        loop: boolean
        pause: () => void
        play: () => Promise<void>
        preload: string
        load: () => void
        removeAttribute: (name: string) => void
        src: string
        volume: number
      }> = []
      vi.stubGlobal(
        'Audio',
        class extends EventTarget {
          currentTime = 7
          loop = false
          pause = pause
          play = play
          preload = ''
          src: string
          volume = 0

          load(): void {}

          removeAttribute(name: string): void {
            if (name === 'src') this.src = ''
          }

          constructor(src: string) {
            super()
            this.src = src
            players.push(this)
          }
        },
      )

      const stop = playPhoneVibration(kind, loop)

      expect(players[0]).toMatchObject({
        loop,
        preload: 'auto',
        src: expect.stringContaining(path),
        volume: 1,
      })
      expect(play).toHaveBeenCalledOnce()
      stop()
      expect(pause).toHaveBeenCalledOnce()
      expect(players[0].currentTime).toBe(0)
    },
  )

  it('reports media playback only after play has actually started', async () => {
    let resolvePlay: (() => void) | undefined
    const onError = vi.fn()
    const onStarted = vi.fn()
    vi.stubGlobal(
      'Audio',
      class extends EventTarget {
        loop = false
        preload = ''
        volume = 0

        load(): void {}

        pause(): void {}

        play(): Promise<void> {
          return new Promise((resolve) => {
            resolvePlay = resolve
          })
        }

        removeAttribute(): void {}
      },
    )

    const stop = playPhoneMediaTone(
      'data:audio/ogg;base64,T2dnUw==',
      75,
      false,
      {
        onError,
        onStarted,
      },
    )

    expect(onStarted).not.toHaveBeenCalled()
    resolvePlay?.()
    await vi.waitFor(() => expect(onStarted).toHaveBeenCalledOnce())
    expect(onError).not.toHaveBeenCalled()
    stop()
  })

  it.each([false, true])(
    'releases completed one-shot media while preserving looping playback (loop=%s)',
    (loop) => {
      const pause = vi.fn()
      const load = vi.fn()
      const removeAttribute = vi.fn()
      const players: EventTarget[] = []
      vi.stubGlobal(
        'Audio',
        class extends EventTarget {
          loop = false
          preload = ''
          volume = 1
          pause = pause
          load = load
          removeAttribute = removeAttribute

          constructor() {
            super()
            players.push(this)
          }

          async play(): Promise<void> {}
        },
      )

      const stop = playPhoneMediaTone('sounds/endcall.mp3', 100, loop)
      players[0]?.dispatchEvent(new Event('ended'))
      expect(pause).toHaveBeenCalledTimes(loop ? 0 : 1)
      stop()
      stop()
      expect(pause).toHaveBeenCalledOnce()
      expect(load).toHaveBeenCalledOnce()
      expect(removeAttribute).toHaveBeenCalledWith('src')
    },
  )
})
