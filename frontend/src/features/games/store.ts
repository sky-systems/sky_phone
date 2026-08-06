import { defineStore } from 'pinia'

import { usePhoneStore } from '@/stores/phone'

export const useGamesStore = defineStore('games', {
  state: () => ({
    games: {} as Record<string, unknown>,
  }),
  actions: {
    hydrate(payload: unknown): void {
      this.games =
        payload && typeof payload === 'object'
          ? structuredClone(payload as Record<string, unknown>)
          : {}
    },
    readGame<T>(gameId: string): T | undefined {
      return this.games[gameId] as T | undefined
    },
    saveGame(gameId: string, payload: unknown): void {
      this.games[gameId] = structuredClone(payload)
      usePhoneStore().saveDeviceNamespace('games', this.games)
    },
  },
})
