import { defineStore } from 'pinia'

import { usePhoneStore } from '@/stores/phone'
import { cloneJsonData } from '@/utils/clone'

export const useGamesStore = defineStore('games', {
  state: () => ({
    games: {} as Record<string, unknown>,
  }),
  actions: {
    hydrate(payload: unknown): void {
      this.games =
        payload && typeof payload === 'object'
          ? cloneJsonData(payload as Record<string, unknown>)
          : {}
    },
    readGame<T>(gameId: string): T | undefined {
      return this.games[gameId] as T | undefined
    },
    saveGame(gameId: string, payload: unknown): void {
      this.games[gameId] = cloneJsonData(payload)
      usePhoneStore().saveDeviceNamespace('games', this.games)
    },
  },
})
