import { registerPhoneMediaElement } from '@/utils/phoneAudio'

import fallUrl from '@/assets/audio/tower-stack/fall.wav?url'
import hitUrl from '@/assets/audio/tower-stack/hit.wav?url'
import perfectUrl from '@/assets/audio/tower-stack/perfect.wav?url'
import startUrl from '@/assets/audio/tower-stack/start.wav?url'

export type TowerStackSound = 'fall' | 'hit' | 'perfect' | 'start'

const soundUrls: Record<TowerStackSound, string> = {
  fall: fallUrl,
  hit: hitUrl,
  perfect: perfectUrl,
  start: startUrl,
}
const playerPools = new Map<TowerStackSound, HTMLAudioElement[]>()

function getPlayers(sound: TowerStackSound): HTMLAudioElement[] {
  const existing = playerPools.get(sound)
  if (existing) return existing

  const players = Array.from({ length: 3 }, () => {
    const player = registerPhoneMediaElement(new Audio(soundUrls[sound]))
    player.preload = 'auto'
    player.volume = 0.84
    return player
  })
  playerPools.set(sound, players)
  return players
}

export function playTowerStackSound(
  sound: TowerStackSound,
  enabled: boolean,
): void {
  if (!enabled) return

  const players = getPlayers(sound)
  const player = players.find((candidate) => candidate.paused) ?? players[0]
  player.currentTime = 0
  void player.play().catch((error: unknown) => {
    console.error(`[Tower Stack audio] Failed to play ${sound}`, error)
  })
}
