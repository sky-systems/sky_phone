import { defineStore } from 'pinia'

import { isPhoneAppId } from '@/config/apps'
import { usePhoneStore } from '@/stores/phone'
import type { LaunchablePhoneAppId } from '@/types/apps'

const INSTALL_DURATION_MS = 3000

export const useAppStoreStore = defineStore('app-store', {
  state: () => ({
    claimedApps: [] as LaunchablePhoneAppId[],
    installingApps: {} as Partial<Record<LaunchablePhoneAppId, boolean>>,
    launchCounts: {} as Partial<Record<LaunchablePhoneAppId, number>>,
  }),
  actions: {
    claimApp(id: LaunchablePhoneAppId): void {
      if (!this.claimedApps.includes(id)) {
        this.claimedApps.push(id)
        this.persist()
      }
    },
    installApp(id: LaunchablePhoneAppId): void {
      if (this.claimedApps.includes(id) || this.installingApps[id]) return

      this.installingApps[id] = true
      globalThis.setTimeout(() => {
        this.claimApp(id)
        delete this.installingApps[id]
      }, INSTALL_DURATION_MS)
    },
    hydrate(payload: unknown): void {
      const data = payload as {
        claimedApps?: unknown
        launchCounts?: unknown
      } | null
      this.claimedApps = Array.isArray(data?.claimedApps)
        ? data.claimedApps.filter(
            (id): id is LaunchablePhoneAppId =>
              typeof id === 'string' && isPhoneAppId(id),
          )
        : []
      this.installingApps = {}
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
