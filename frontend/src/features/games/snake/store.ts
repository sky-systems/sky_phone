import { defineStore } from 'pinia'

import { useGamesStore } from '@/features/games/store'

import { createSnakeGame, stepSnake, turnSnake } from './engine'
import type { SnakeDirection, SnakeGameState, SnakeSpeed } from './types'

type SnakeSave = {
  highScore: number
  speed: SnakeSpeed
}

const SPEED_TICK_MS: Record<SnakeSpeed, number> = {
  relaxed: 210,
  normal: 155,
  fast: 110,
}

function isSnakeSpeed(value: unknown): value is SnakeSpeed {
  return value === 'relaxed' || value === 'normal' || value === 'fast'
}

export const useSnakeStore = defineStore('snake', {
  state: () => ({
    game: null as SnakeGameState | null,
    highScore: 0,
    hydrated: false,
    speed: 'normal' as SnakeSpeed,
  }),
  getters: {
    tickMilliseconds: (state) => SPEED_TICK_MS[state.speed],
  },
  actions: {
    hydrate(): void {
      if (this.hydrated) return

      const saved = useGamesStore().readGame<Partial<SnakeSave>>('snake')
      this.highScore =
        typeof saved?.highScore === 'number' && saved.highScore >= 0
          ? Math.floor(saved.highScore)
          : 0
      this.speed = isSnakeSpeed(saved?.speed) ? saved.speed : 'normal'
      this.hydrated = true
    },
    persist(): void {
      useGamesStore().saveGame('snake', {
        highScore: this.highScore,
        speed: this.speed,
      } satisfies SnakeSave)
    },
    setSpeed(speed: SnakeSpeed): void {
      this.speed = speed
      this.persist()
    },
    start(): void {
      this.game = createSnakeGame()
    },
    pause(): void {
      if (this.game?.status === 'playing') {
        this.game = { ...this.game, status: 'paused' }
      }
    },
    resume(): void {
      if (this.game?.status === 'paused') {
        this.game = { ...this.game, status: 'playing' }
      }
    },
    turn(direction: SnakeDirection): void {
      if (this.game) this.game = turnSnake(this.game, direction)
    },
    tick(): void {
      if (!this.game) return

      this.game = stepSnake(this.game)
      if (this.game.status === 'game-over' && this.game.score > this.highScore) {
        this.highScore = this.game.score
        this.persist()
      }
    },
    showMenu(): void {
      this.game = null
    },
  },
})
