import { defineStore } from 'pinia'

import { useGamesStore } from '@/features/games/store'

import {
  continueNumberMerge,
  createNumberMergeGame,
  isNumberMergeGameState,
  moveNumberMerge,
} from './engine'
import type {
  NumberMergeDirection,
  NumberMergeGameState,
  NumberMergeMoveResult,
} from './types'

type NumberMergeSave = {
  bestScore: number
  game: NumberMergeGameState | null
  highestTile: number
  soundEnabled: boolean
}

function savedNumber(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0
    ? Math.floor(value)
    : 0
}

export const useNumberMergeStore = defineStore('number-merge', {
  state: () => ({
    bestScore: 0,
    game: null as NumberMergeGameState | null,
    highestTile: 0,
    hydrated: false,
    menuOpen: true,
    soundEnabled: true,
  }),
  actions: {
    hydrate(): void {
      if (this.hydrated) return

      const saved = useGamesStore().readGame<Partial<NumberMergeSave>>(
        'number-merge',
      )
      this.game = isNumberMergeGameState(saved?.game)
        ? {
            ...structuredClone(saved.game),
            tiles: saved.game.tiles.map((tile) => ({
              ...tile,
              isNew: false,
              merged: false,
            })),
          }
        : null
      this.bestScore = Math.max(
        savedNumber(saved?.bestScore),
        this.game?.score ?? 0,
      )
      this.highestTile = Math.max(
        savedNumber(saved?.highestTile),
        ...(this.game?.tiles.map((tile) => tile.value) ?? [0]),
      )
      if (typeof saved?.soundEnabled === 'boolean') {
        this.soundEnabled = saved.soundEnabled
      }
      this.hydrated = true
    },
    persist(): void {
      useGamesStore().saveGame('number-merge', {
        bestScore: this.bestScore,
        game: this.game,
        highestTile: this.highestTile,
        soundEnabled: this.soundEnabled,
      } satisfies NumberMergeSave)
    },
    start(): void {
      this.game = createNumberMergeGame()
      this.highestTile = Math.max(
        this.highestTile,
        ...this.game.tiles.map((tile) => tile.value),
      )
      this.menuOpen = false
      this.persist()
    },
    resume(): void {
      if (this.game) this.menuOpen = false
    },
    showMenu(): void {
      this.menuOpen = true
    },
    move(direction: NumberMergeDirection): NumberMergeMoveResult | null {
      if (!this.game) return null

      const result = moveNumberMerge(this.game, direction)
      if (!result.changed) return result

      this.game = result.state
      this.bestScore = Math.max(this.bestScore, result.state.score)
      this.highestTile = Math.max(
        this.highestTile,
        ...result.state.tiles.map((tile) => tile.value),
      )
      this.persist()
      return result
    },
    continueAfterWin(): void {
      if (!this.game) return
      this.game = continueNumberMerge(this.game)
      this.persist()
    },
    setSoundEnabled(enabled: boolean): void {
      this.soundEnabled = enabled
      this.persist()
    },
  },
})
