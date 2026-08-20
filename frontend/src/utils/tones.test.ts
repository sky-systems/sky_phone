import { afterEach, describe, expect, it, vi } from 'vitest'

import { ALARM_SOUND_IDS } from './alarms'
import { phoneToneDuration, playPhoneVibration } from './tones'

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
})
