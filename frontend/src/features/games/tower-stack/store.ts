import { defineStore } from 'pinia'

import { useGamesStore } from '@/features/games/store'

import {
  advanceTowerBlock,
  createTowerGame,
  pauseTowerGame,
  placeTowerBlock,
  resumeTowerGame,
} from './engine'
import type { TowerGameState, TowerPlacement } from './types'

type TowerStackSave = {
  highHeight: number
  highScore: number
  soundEnabled: boolean
}

export const useTowerStackStore = defineStore('tower-stack', {
  state: () => ({
    game: null as TowerGameState | null,
    highHeight: 0,
    highScore: 0,
    hydrated: false,
    menuOpen: true,
    soundEnabled: true,
  }),
  actions: {
    hydrate(): void {
      if (this.hydrated) return

      const saved = useGamesStore().readGame<Partial<TowerStackSave>>(
        'tower-stack',
      )
      this.highHeight =
        typeof saved?.highHeight === 'number' && saved.highHeight >= 0
          ? Math.floor(saved.highHeight)
          : 0
      this.highScore =
        typeof saved?.highScore === 'number' && saved.highScore >= 0
          ? Math.floor(saved.highScore)
          : 0
      if (typeof saved?.soundEnabled === 'boolean') {
        this.soundEnabled = saved.soundEnabled
      }
      this.hydrated = true
    },
    persist(): void {
      useGamesStore().saveGame('tower-stack', {
        highHeight: this.highHeight,
        highScore: this.highScore,
        soundEnabled: this.soundEnabled,
      } satisfies TowerStackSave)
    },
    start(): void {
      this.game = createTowerGame()
      this.menuOpen = false
    },
    tick(elapsedSeconds: number): void {
      if (this.game) {
        this.game = advanceTowerBlock(this.game, elapsedSeconds)
      }
    },
    place(): TowerPlacement | null {
      if (!this.game) return null

      const result = placeTowerBlock(this.game)
      this.game = result.state
      if (result.state.status === 'over') {
        const height = result.state.blocks.length - 1
        this.highHeight = Math.max(this.highHeight, height)
        this.highScore = Math.max(this.highScore, result.state.score)
        this.persist()
      }
      return result
    },
    pause(): void {
      if (this.game) this.game = pauseTowerGame(this.game)
    },
    resume(): void {
      if (this.game) {
        this.game = resumeTowerGame(this.game)
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
