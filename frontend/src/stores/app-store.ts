import { defineStore } from 'pinia'

import { isPhoneAppId, PHONE_APPS } from '@/config/apps'
import { usePhoneStore } from '@/stores/phone'
import type { LaunchablePhoneAppId } from '@/types/apps'
import {
  createDefaultHomeLayout,
  moveHomeApp,
  parseHomeLayout,
  removeHomeApp,
  restoreHomeApp,
  type HomeArea,
} from '@/utils/homeLayout'

const INSTALL_DURATION_MS = 3000
const DEFAULT_GRID_IDS = [...PHONE_APPS]
  .sort((a, b) => a.gridOrder - b.gridOrder)
  .map((app) => app.id)
const DEFAULT_DOCK_IDS = PHONE_APPS.filter((app) => app.dockOrder !== null)
  .sort((a, b) => (a.dockOrder ?? 0) - (b.dockOrder ?? 0))
  .map((app) => app.id)
const CORE_APP_IDS = PHONE_APPS.filter((app) => app.category !== 'games').map(
  (app) => app.id,
)

export const useAppStoreStore = defineStore('app-store', {
  state: () => ({
    claimedApps: [] as LaunchablePhoneAppId[],
    homeLayout: createDefaultHomeLayout(
      CORE_APP_IDS,
      DEFAULT_GRID_IDS,
      DEFAULT_DOCK_IDS,
    ),
    installingApps: {} as Partial<Record<LaunchablePhoneAppId, boolean>>,
    launchCounts: {} as Partial<Record<LaunchablePhoneAppId, number>>,
  }),
  actions: {
    claimApp(id: LaunchablePhoneAppId): void {
      if (!this.claimedApps.includes(id)) {
        this.claimedApps.push(id)
        this.homeLayout = restoreHomeApp(this.homeLayout, id)
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
        homeLayout?: unknown
        launchCounts?: unknown
      } | null
      this.claimedApps = Array.isArray(data?.claimedApps)
        ? data.claimedApps.filter(
            (id): id is LaunchablePhoneAppId =>
              typeof id === 'string' && isPhoneAppId(id),
          )
        : []
      const installedIds = [...CORE_APP_IDS, ...this.claimedApps]
      const defaults = createDefaultHomeLayout(
        installedIds,
        DEFAULT_GRID_IDS,
        DEFAULT_DOCK_IDS,
      )
      this.homeLayout = parseHomeLayout(
        data?.homeLayout,
        defaults,
        installedIds,
      )
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
    moveHomeApp(
      from: HomeArea,
      sourceIndex: number,
      to: HomeArea,
      targetIndex: number,
    ): void {
      this.homeLayout = moveHomeApp(
        this.homeLayout,
        from,
        sourceIndex,
        to,
        targetIndex,
      )
      this.persist()
    },
    removeHomeApp(appId: LaunchablePhoneAppId): void {
      this.homeLayout = removeHomeApp(this.homeLayout, appId)
      this.persist()
    },
    restoreHomeApp(appId: LaunchablePhoneAppId): void {
      this.homeLayout = restoreHomeApp(this.homeLayout, appId)
      this.persist()
    },
    persist(): void {
      usePhoneStore().saveDeviceNamespace('apps', {
        claimedApps: this.claimedApps,
        homeLayout: this.homeLayout,
        launchCounts: this.launchCounts,
      })
    },
  },
})
