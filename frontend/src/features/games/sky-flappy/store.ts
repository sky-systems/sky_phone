import { defineStore } from 'pinia'

import { useGamesStore } from '@/features/games/store'

import {
  createSkyFlappyGame,
  flapSkyGlider,
  pauseSkyFlappy,
  resumeSkyFlappy,
  stepSkyFlappy,
} from './engine'
import type { SkyFlappyDesign, SkyFlappyGameState } from './types'

type SkyFlappySave = {
  design: SkyFlappyDesign
  highScore: number
  soundEnabled: boolean
}

function isDesign(value: unknown): value is SkyFlappyDesign {
  return value === 'dawn' || value === 'neon' || value === 'storm'
}

export const useSkyFlappyStore = defineStore('sky-flappy', {
  state: () => ({
    design: 'dawn' as SkyFlappyDesign,
    game: null as SkyFlappyGameState | null,
    highScore: 0,
    hydrated: false,
    menuOpen: true,
    soundEnabled: true,
  }),
  actions: {
    hydrate(): void {
      if (this.hydrated) return
      const saved = useGamesStore().readGame<Partial<SkyFlappySave>>('sky-flappy')
      this.highScore = typeof saved?.highScore === 'number' && saved.highScore >= 0 ? Math.floor(saved.highScore) : 0
      this.design = isDesign(saved?.design) ? saved.design : 'dawn'
      if (typeof saved?.soundEnabled === 'boolean') this.soundEnabled = saved.soundEnabled
      this.hydrated = true
    },
    persist(): void {
      useGamesStore().saveGame('sky-flappy', {
        design: this.design,
        highScore: this.highScore,
        soundEnabled: this.soundEnabled,
      } satisfies SkyFlappySave)
    },
    start(): void {
      this.game = createSkyFlappyGame()
      this.menuOpen = false
    },
    flap(): void {
      if (this.game) this.game = flapSkyGlider(this.game)
    },
    tick(elapsedSeconds: number): void {
      if (!this.game) return
      this.game = stepSkyFlappy(this.game, elapsedSeconds)
      if (this.game.status === 'over' && this.game.score > this.highScore) {
        this.highScore = this.game.score
        this.persist()
      }
    },
    pause(): void {
      if (this.game) this.game = pauseSkyFlappy(this.game)
    },
    resume(): void {
      if (this.game) {
        this.game = resumeSkyFlappy(this.game)
        this.menuOpen = false
      }
    },
    showMenu(): void {
      this.pause()
      this.menuOpen = true
    },
    setDesign(design: SkyFlappyDesign): void {
      this.design = design
      this.persist()
    },
    setSoundEnabled(enabled: boolean): void {
      this.soundEnabled = enabled
      this.persist()
    },
  },
})
