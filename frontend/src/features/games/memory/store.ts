import { defineStore } from 'pinia'

import { useGamesStore } from '@/features/games/store'

import {
  createMemoryGame,
  flipMemoryCard,
  resolveMemoryMismatch,
} from './engine'
import type {
  MemoryBest,
  MemoryDifficulty,
  MemoryGameState,
} from './types'

type MemorySave = {
  best: Partial<Record<MemoryDifficulty, MemoryBest>>
  soundEnabled: boolean
}

function isMemoryBest(value: unknown): value is MemoryBest {
  if (!value || typeof value !== 'object') return false
  const best = value as Partial<MemoryBest>
  return (
    typeof best.moves === 'number' &&
    best.moves > 0 &&
    typeof best.timeMs === 'number' &&
    best.timeMs >= 0
  )
}

export const useMemoryStore = defineStore('memory', {
  state: () => ({
    best: {} as Partial<Record<MemoryDifficulty, MemoryBest>>,
    elapsedMs: 0,
    game: null as MemoryGameState | null,
    hydrated: false,
    soundEnabled: true,
    startedAt: null as number | null,
  }),
  actions: {
    hydrate(): void {
      if (this.hydrated) return

      const saved = useGamesStore().readGame<Partial<MemorySave>>('memory')
      for (const difficulty of ['small', 'medium', 'large'] as const) {
        const candidate = saved?.best?.[difficulty]
        if (isMemoryBest(candidate)) this.best[difficulty] = candidate
      }
      if (typeof saved?.soundEnabled === 'boolean') {
        this.soundEnabled = saved.soundEnabled
      }
      this.hydrated = true
    },
    persist(): void {
      useGamesStore().saveGame('memory', {
        best: this.best,
        soundEnabled: this.soundEnabled,
      } satisfies MemorySave)
    },
    setSoundEnabled(enabled: boolean): void {
      this.soundEnabled = enabled
      this.persist()
    },
    start(difficulty: MemoryDifficulty): void {
      this.game = createMemoryGame(difficulty)
      this.elapsedMs = 0
      this.startedAt = Date.now()
    },
    updateElapsed(now = Date.now()): void {
      if (this.startedAt === null) return
      this.elapsedMs += now - this.startedAt
      this.startedAt = now
    },
    pause(): void {
      this.updateElapsed()
      this.startedAt = null
    },
    resume(): void {
      if (this.game?.status === 'playing' && this.startedAt === null) {
        this.startedAt = Date.now()
      }
    },
    flip(cardId: string): void {
      if (!this.game) return

      const previousStatus = this.game.status
      this.game = flipMemoryCard(this.game, cardId)
      if (previousStatus !== 'won' && this.game.status === 'won') {
        this.updateElapsed()
        this.startedAt = null
        const result = { moves: this.game.moves, timeMs: this.elapsedMs }
        const current = this.best[this.game.difficulty]
        if (
          !current ||
          result.moves < current.moves ||
          (result.moves === current.moves && result.timeMs < current.timeMs)
        ) {
          this.best[this.game.difficulty] = result
          this.persist()
        }
      }
    },
    resolveMismatch(): void {
      if (this.game) this.game = resolveMemoryMismatch(this.game)
    },
    showMenu(): void {
      this.pause()
      this.game = null
      this.elapsedMs = 0
    },
  },
})
