import gameOverUrl from '@/assets/audio/number-merge/game-over.wav?url'
import mergeUrl from '@/assets/audio/number-merge/merge.wav?url'
import moveUrl from '@/assets/audio/number-merge/move.wav?url'
import winUrl from '@/assets/audio/number-merge/win.wav?url'

export type NumberMergeSound = 'game-over' | 'merge' | 'move' | 'win'

const soundUrls: Record<NumberMergeSound, string> = {
  'game-over': gameOverUrl,
  merge: mergeUrl,
  move: moveUrl,
  win: winUrl,
}
const playerPools = new Map<NumberMergeSound, HTMLAudioElement[]>()

function getPlayers(sound: NumberMergeSound): HTMLAudioElement[] {
  const existing = playerPools.get(sound)
  if (existing) return existing

  const players = Array.from({ length: 3 }, () => {
    const player = new Audio(soundUrls[sound])
    player.preload = 'auto'
    player.volume = 0.82
    return player
  })
  playerPools.set(sound, players)
  return players
}

export function playNumberMergeSound(
  sound: NumberMergeSound,
  enabled: boolean,
): void {
  if (!enabled) return

  const players = getPlayers(sound)
  const player = players.find((candidate) => candidate.paused) ?? players[0]
  player.currentTime = 0
  void player.play().catch((error: unknown) => {
    console.error(`[2048 audio] Failed to play ${sound}`, error)
  })
}
