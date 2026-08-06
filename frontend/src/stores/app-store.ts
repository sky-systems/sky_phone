import { defineStore } from 'pinia'

import { usePhoneStore } from '@/stores/phone'

export const useAppStoreStore = defineStore('app-store', {
  state: () => ({
    claimedApps: [] as string[],
  }),
  actions: {
    claimApp(id: string): void {
      if (!this.claimedApps.includes(id)) {
        this.claimedApps.push(id)
        this.persist()
      }
    },
    hydrate(payload: unknown): void {
      const data = payload as { claimedApps?: unknown } | null
      this.claimedApps = Array.isArray(data?.claimedApps)
        ? data.claimedApps.filter((id): id is string => typeof id === 'string')
        : []
    },
    persist(): void {
      usePhoneStore().saveDeviceNamespace('apps', {
        claimedApps: this.claimedApps,
      })
    },
  },
})
