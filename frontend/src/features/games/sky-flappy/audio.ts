import { registerPhoneMediaElement } from '@/utils/phoneAudio'

import crashUrl from '@/assets/audio/sky-flappy/crash.wav?url'
import flapUrl from '@/assets/audio/sky-flappy/flap.wav?url'
import pointUrl from '@/assets/audio/sky-flappy/point.wav?url'

export type SkyFlappySound = 'crash' | 'flap' | 'point'
const urls: Record<SkyFlappySound, string> = { crash: crashUrl, flap: flapUrl, point: pointUrl }
const pools = new Map<SkyFlappySound, HTMLAudioElement[]>()

export function playSkyFlappySound(sound: SkyFlappySound, enabled: boolean): void {
  if (!enabled) return
  let players = pools.get(sound)
  if (!players) {
    players = Array.from({ length: 3 }, () => {
      const player = registerPhoneMediaElement(new Audio(urls[sound]))
      player.preload = 'auto'
      player.volume = 0.84
      return player
    })
    pools.set(sound, players)
  }
  const player = players.find((candidate) => candidate.paused) ?? players[0]
  player.currentTime = 0
  void player.play().catch((error: unknown) => console.error(`[Sky Flappy audio] Failed to play ${sound}`, error))
}
