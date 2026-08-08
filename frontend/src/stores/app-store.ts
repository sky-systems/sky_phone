import { defineStore } from 'pinia'

import {
  isPhoneAppId,
  NON_REMOVABLE_PHONE_APP_IDS,
  PHONE_APPS,
} from '@/config/apps'
import { usePhoneStore } from '@/stores/phone'
import type { LaunchablePhoneAppId } from '@/types/apps'
import {
  addHomePage,
  createDefaultHomeLayout,
  deleteHomePage,
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
    addHomePage(): boolean {
      const next = addHomePage(this.homeLayout)
      if (next === this.homeLayout) return false
      this.homeLayout = next
      this.persist()
      return true
    },
    deleteHomePage(page: number): boolean {
      const next = deleteHomePage(this.homeLayout, page)
      if (next === this.homeLayout) return false
      this.homeLayout = next
      this.persist()
      return true
    },
    claimApp(id: LaunchablePhoneAppId): void {
      if (!this.claimedApps.includes(id)) {
        this.claimedApps.push(id)
        this.homeLayout = restoreHomeApp(this.homeLayout, id)
        this.persist()
      }
    },
    installApp(id: LaunchablePhoneAppId): void {
      const installed =
        CORE_APP_IDS.includes(id) || this.claimedApps.includes(id)
      if (
        this.installingApps[id] ||
        (installed && !this.homeLayout.hidden.includes(id))
      ) {
        return
      }

      this.installingApps[id] = true
      globalThis.setTimeout(() => {
        if (CORE_APP_IDS.includes(id) || this.claimedApps.includes(id)) {
          this.restoreHomeApp(id)
        } else {
          this.claimApp(id)
        }
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
      const protectedHiddenAppIds = this.homeLayout.hidden.filter((id) =>
        NON_REMOVABLE_PHONE_APP_IDS.has(id),
      )
      for (const appId of protectedHiddenAppIds) {
        this.homeLayout = restoreHomeApp(this.homeLayout, appId)
      }
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
      if (protectedHiddenAppIds.length) this.persist()
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
      if (NON_REMOVABLE_PHONE_APP_IDS.has(appId)) return

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
