import { registerPhoneMediaElement } from '@/utils/phoneAudio'

import flagUrl from '@/assets/audio/minesweeper/flag.wav?url'
import clearUrl from '@/assets/audio/minesweeper/clear.wav?url'
import mineUrl from '@/assets/audio/minesweeper/mine.wav?url'
import placeUrl from '@/assets/audio/minesweeper/place.wav?url'
import revealUrl from '@/assets/audio/minesweeper/reveal.wav?url'
import winUrl from '@/assets/audio/minesweeper/win.wav?url'

export type MinesweeperSound =
  | 'clear'
  | 'flag'
  | 'mine'
  | 'place'
  | 'reveal'
  | 'win'

const soundUrls: Record<MinesweeperSound, string> = {
  clear: clearUrl,
  flag: flagUrl,
  mine: mineUrl,
  place: placeUrl,
  reveal: revealUrl,
  win: winUrl,
}
const playerPools = new Map<MinesweeperSound, HTMLAudioElement[]>()

function getPlayers(sound: MinesweeperSound): HTMLAudioElement[] {
  const existing = playerPools.get(sound)
  if (existing) return existing

  const players = Array.from({ length: 3 }, () => {
    const player = registerPhoneMediaElement(new Audio(soundUrls[sound]))
    player.preload = 'auto'
    player.volume = 0.82
    return player
  })
  playerPools.set(sound, players)
  return players
}

export function playMinesweeperSound(
  sound: MinesweeperSound,
  enabled: boolean,
): void {
  if (!enabled) return

  const players = getPlayers(sound)
  const player = players.find((candidate) => candidate.paused) ?? players[0]
  player.currentTime = 0
  void player.play().catch((error: unknown) => {
    console.error(`[Minesweeper audio] Failed to play ${sound}`, error)
  })
}
