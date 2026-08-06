import { defineStore } from 'pinia'

import { useGamesStore } from '@/features/games/store'

import {
  createNeonDropGame,
  hardDropNeonPiece,
  moveNeonDropPiece,
  pauseNeonDrop,
  resumeNeonDrop,
  rotateNeonDropPiece,
  stepNeonDrop,
} from './engine'
import type { NeonDropEvent, NeonDropGameState } from './types'

type NeonDropSave = {
  bestLines: number
  bestScore: number
  soundEnabled: boolean
}

export const useNeonDropStore = defineStore('neon-drop', {
  state: () => ({
    bestLines: 0,
    bestScore: 0,
    game: null as NeonDropGameState | null,
    hydrated: false,
    menuOpen: true,
    soundEnabled: true,
  }),
  actions: {
    hydrate(): void {
      if (this.hydrated) return
      const saved = useGamesStore().readGame<Partial<NeonDropSave>>('neon-drop')
      this.bestLines =
        typeof saved?.bestLines === 'number' && saved.bestLines >= 0
          ? Math.floor(saved.bestLines)
          : 0
      this.bestScore =
        typeof saved?.bestScore === 'number' && saved.bestScore >= 0
          ? Math.floor(saved.bestScore)
          : 0
      if (typeof saved?.soundEnabled === 'boolean') {
        this.soundEnabled = saved.soundEnabled
      }
      this.hydrated = true
    },
    persist(): void {
      useGamesStore().saveGame('neon-drop', {
        bestLines: this.bestLines,
        bestScore: this.bestScore,
        soundEnabled: this.soundEnabled,
      } satisfies NeonDropSave)
    },
    start(): void {
      this.game = createNeonDropGame()
      this.menuOpen = false
    },
    applyResult(result: {
      event: NeonDropEvent
      state: NeonDropGameState
    }): NeonDropEvent {
      this.game = result.state
      if (result.state.status === 'over') {
        this.bestLines = Math.max(this.bestLines, result.state.lines)
        this.bestScore = Math.max(this.bestScore, result.state.score)
        this.persist()
      }
      return result.event
    },
    move(direction: -1 | 1): NeonDropEvent {
      if (!this.game) return 'none'
      return this.applyResult(moveNeonDropPiece(this.game, direction))
    },
    rotate(): NeonDropEvent {
      if (!this.game) return 'none'
      return this.applyResult(rotateNeonDropPiece(this.game))
    },
    softDrop(): NeonDropEvent {
      if (!this.game) return 'none'
      return this.applyResult(stepNeonDrop(this.game, Math.random, true))
    },
    hardDrop(): NeonDropEvent {
      if (!this.game) return 'none'
      return this.applyResult(hardDropNeonPiece(this.game))
    },
    tick(): NeonDropEvent {
      if (!this.game) return 'none'
      return this.applyResult(stepNeonDrop(this.game))
    },
    pause(): void {
      if (this.game) this.game = pauseNeonDrop(this.game)
    },
    resume(): void {
      if (this.game) {
        this.game = resumeNeonDrop(this.game)
        this.menuOpen = false
      }
    },
    showMenu(): void {
      this.pause()
      this.menuOpen = true
    },
    setSoundEnabled(enabled: boolean): void {
      this.soundEnabled = enabled
      this.persist()
    },
  },
})
