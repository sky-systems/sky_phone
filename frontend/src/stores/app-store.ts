import { defineStore } from 'pinia'

import { isPhoneAppId } from '@/config/apps'
import { usePhoneStore } from '@/stores/phone'
import type { LaunchablePhoneAppId } from '@/types/apps'

export const useAppStoreStore = defineStore('app-store', {
  state: () => ({
    claimedApps: [] as string[],
    launchCounts: {} as Partial<Record<LaunchablePhoneAppId, number>>,
  }),
  actions: {
    claimApp(id: string): void {
      if (!this.claimedApps.includes(id)) {
        this.claimedApps.push(id)
        this.persist()
      }
    },
    hydrate(payload: unknown): void {
      const data = payload as {
        claimedApps?: unknown
        launchCounts?: unknown
      } | null
      this.claimedApps = Array.isArray(data?.claimedApps)
        ? data.claimedApps.filter((id): id is string => typeof id === 'string')
        : []
      this.launchCounts = {}
      if (data?.launchCounts && typeof data.launchCounts === 'object') {
        for (const [appId, count] of Object.entries(data.launchCounts)) {
          if (
            isPhoneAppId(appId) &&
            typeof count === 'number' &&
            Number.isFinite(count) &&
            count > 0
          ) {
            this.launchCounts[appId] = Math.floor(count)
          }
        }
      }
    },
    recordLaunch(appId: LaunchablePhoneAppId): void {
      this.launchCounts[appId] = (this.launchCounts[appId] ?? 0) + 1
      this.persist()
    },
    persist(): void {
      usePhoneStore().saveDeviceNamespace('apps', {
        claimedApps: this.claimedApps,
        launchCounts: this.launchCounts,
      })
    },
  },
})
