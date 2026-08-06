import { defineStore } from 'pinia'

import { useGamesStore } from '@/features/games/store'
import { cloneJsonData } from '@/utils/clone'

import {
  createMinesweeperGame,
  isMinesweeperGameState,
  revealMinesweeperCell,
  toggleMinesweeperFlag,
} from './engine'
import type {
  MinesweeperActionResult,
  MinesweeperBest,
  MinesweeperDifficulty,
  MinesweeperGameState,
} from './types'

type MinesweeperSave = {
  best: Partial<Record<MinesweeperDifficulty, MinesweeperBest>>
  elapsedMs: number
  game: MinesweeperGameState | null
  soundEnabled: boolean
}

function isBest(value: unknown): value is MinesweeperBest {
  return (
    !!value &&
    typeof value === 'object' &&
    typeof (value as Partial<MinesweeperBest>).timeMs === 'number' &&
    ((value as Partial<MinesweeperBest>).timeMs ?? -1) >= 0
  )
}

export const useMinesweeperStore = defineStore('minesweeper', {
  state: () => ({
    best: {} as Partial<Record<MinesweeperDifficulty, MinesweeperBest>>,
    elapsedMs: 0,
    game: null as MinesweeperGameState | null,
    hydrated: false,
    menuOpen: true,
    soundEnabled: true,
    startedAt: null as number | null,
  }),
  actions: {
    hydrate(): void {
      if (this.hydrated) return

      const saved = useGamesStore().readGame<Partial<MinesweeperSave>>(
        'minesweeper',
      )
      for (const difficulty of ['quick', 'classic', 'expert'] as const) {
        if (isBest(saved?.best?.[difficulty])) {
          this.best[difficulty] = saved.best[difficulty]
        }
      }
      this.elapsedMs =
        typeof saved?.elapsedMs === 'number' && saved.elapsedMs >= 0
          ? saved.elapsedMs
          : 0
      this.game = isMinesweeperGameState(saved?.game)
        ? cloneJsonData(saved.game)
        : null
      if (typeof saved?.soundEnabled === 'boolean') {
        this.soundEnabled = saved.soundEnabled
      }
      this.hydrated = true
    },
    persist(): void {
      useGamesStore().saveGame('minesweeper', {
        best: this.best,
        elapsedMs: this.elapsedMs,
        game: this.game,
        soundEnabled: this.soundEnabled,
      } satisfies MinesweeperSave)
    },
    start(difficulty: MinesweeperDifficulty): void {
      this.game = createMinesweeperGame(difficulty)
      this.elapsedMs = 0
      this.menuOpen = false
      this.startedAt = null
      this.persist()
    },
    resumeGame(): void {
      if (!this.game) return
      this.menuOpen = false
      if (this.game.status === 'playing') this.startedAt = Date.now()
    },
    showMenu(): void {
      this.pause()
      this.menuOpen = true
      this.persist()
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
    reveal(cellId: number): MinesweeperActionResult | null {
      if (!this.game) return null

      const previousStatus = this.game.status
      const actionStartedAt = Date.now()
      const result = revealMinesweeperCell(this.game, cellId)
      if (!result.changed) return result

      this.game = result.state
      if (previousStatus === 'ready') {
        this.startedAt = actionStartedAt
      }
      if (result.state.status === 'won' || result.state.status === 'lost') {
        this.pause()
        if (result.state.status === 'won') {
          const current = this.best[result.state.difficulty]
          if (!current || this.elapsedMs < current.timeMs) {
            this.best[result.state.difficulty] = { timeMs: this.elapsedMs }
          }
        }
      }
      this.persist()
      return result
    },
    toggleFlag(cellId: number): MinesweeperActionResult | null {
      if (!this.game) return null
      const result = toggleMinesweeperFlag(this.game, cellId)
      if (result.changed) {
        this.game = result.state
        this.persist()
      }
      return result
    },
    setSoundEnabled(enabled: boolean): void {
      this.soundEnabled = enabled
      this.persist()
    },
  },
})
