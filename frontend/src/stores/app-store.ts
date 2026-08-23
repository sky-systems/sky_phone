import { defineStore } from 'pinia'

import {
  DEFAULT_INSTALLED_PHONE_APP_IDS,
  getPhoneApp,
  isExternalPhoneApp,
  isPhoneAppId,
  isPhoneAppRemovable,
  isValidExternalPhoneAppId,
  NON_REMOVABLE_PHONE_APP_IDS,
  PHONE_APPS,
} from '@/config/apps'
import { usePhoneStore } from '@/stores/phone'
import type { LaunchablePhoneAppId } from '@/types/apps'
import {
  addHomeAppToFolder,
  addHomePage,
  createHomeFolder,
  createDefaultHomeLayout,
  deleteHomePage,
  extractHomeFolderApp,
  moveHomeFolderApp,
  moveHomeApp,
  moveHomeAppToGridPage,
  parseHomeLayout,
  reflowHomeGridForWidgetChange,
  renameHomeFolder,
  removeDockGridDuplicates,
  removeHomeApp,
  restoreHomeApp,
  type HomeArea,
} from '@/utils/homeLayout'
import { nuiCall } from '@/utils/nui'

const INSTALL_DURATION_MS = 3000

type PendingInstallation = {
  deviceImei: string
  timer: ReturnType<typeof globalThis.setTimeout>
  token: symbol
}

const pendingInstallations = new WeakMap<
  object,
  Map<LaunchablePhoneAppId, PendingInstallation>
>()

function isAppDisabled(
  appId: LaunchablePhoneAppId,
  disabledApps: readonly LaunchablePhoneAppId[],
): boolean {
  return disabledApps.includes(appId)
}

function getDefaultGridIds(
  disabledApps: readonly LaunchablePhoneAppId[] = [],
): LaunchablePhoneAppId[] {
  return PHONE_APPS.filter(
    (app) => app.dockOrder === null && !isAppDisabled(app.id, disabledApps),
  )
    .sort((a, b) => a.gridOrder - b.gridOrder)
    .map((app) => app.id)
}

function getDefaultDockIds(
  disabledApps: readonly LaunchablePhoneAppId[] = [],
): LaunchablePhoneAppId[] {
  return PHONE_APPS.filter(
    (app) => app.dockOrder !== null && !isAppDisabled(app.id, disabledApps),
  )
    .sort((a, b) => (a.dockOrder ?? 0) - (b.dockOrder ?? 0))
    .map((app) => app.id)
}

function getDefaultInstalledIds(
  disabledApps: readonly LaunchablePhoneAppId[] = [],
): LaunchablePhoneAppId[] {
  return PHONE_APPS.filter((app) => {
    if (app.adminOnly || isAppDisabled(app.id, disabledApps)) return false
    return isExternalPhoneApp(app)
      ? app.defaultInstalled
      : DEFAULT_INSTALLED_PHONE_APP_IDS.has(app.id)
  }).map((app) => app.id)
}

function isProtectedHomeApp(
  appId: LaunchablePhoneAppId,
  disabledApps: readonly LaunchablePhoneAppId[],
): boolean {
  if (isAppDisabled(appId, disabledApps)) return false
  const app = getPhoneApp(appId)
  return app
    ? !isPhoneAppRemovable(app)
    : NON_REMOVABLE_PHONE_APP_IDS.has(appId)
}

function hasUninstalledBuiltinApp(
  layout: unknown,
  installedIds: readonly LaunchablePhoneAppId[],
): boolean {
  if (!layout || typeof layout !== 'object') return false
  const installed = new Set(installedIds)
  const source = layout as {
    dock?: unknown
    grid?: unknown
    hidden?: unknown
  }
  const items = [source.dock, source.grid, source.hidden]
    .filter(Array.isArray)
    .flat(2)

  return items.some((item) => {
    const ids =
      item && typeof item === 'object' && Array.isArray(item.apps)
        ? item.apps
        : [item]
    return ids.some((id: unknown) => {
      if (typeof id !== 'string') return false
      const app = getPhoneApp(id)
      return !!app && !installed.has(app.id) && !isExternalPhoneApp(app)
    })
  })
}

export const useAppStoreStore = defineStore('app-store', {
  state: () => ({
    claimedApps: [] as LaunchablePhoneAppId[],
    disabledApps: [] as LaunchablePhoneAppId[],
    uninstalledApps: [] as LaunchablePhoneAppId[],
    homeLayout: createDefaultHomeLayout(
      getDefaultInstalledIds(),
      getDefaultGridIds(),
      getDefaultDockIds(),
    ),
    hydrated: false,
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
      if (!this.isAvailable(id)) return
      this.uninstalledApps = this.uninstalledApps.filter(
        (appId) => appId !== id,
      )
      if (!this.claimedApps.includes(id)) {
        this.claimedApps.push(id)
        this.homeLayout = restoreHomeApp(this.homeLayout, id)
        this.persist()
      }
    },
    cancelPendingInstalls(): void {
      const installations = pendingInstallations.get(this)
      if (installations) {
        for (const installation of installations.values()) {
          globalThis.clearTimeout(installation.timer)
        }
        pendingInstallations.delete(this)
      }
      this.installingApps = {}
    },
    installApp(id: LaunchablePhoneAppId): void {
      if (!this.isAvailable(id)) return
      const installed = this.isInstalled(id)
      if (
        this.installingApps[id] ||
        (installed && !this.homeLayout.hidden.includes(id))
      ) {
        return
      }

      const phone = usePhoneStore()
      const deviceImei = phone.device?.imei
      if (!phone.isOpen || !deviceImei) {
        console.error(
          `[App store] Installation cancelled because no phone device is open for ${id}.`,
        )
        return
      }

      const app = getPhoneApp(id)
      const reportInstall = !installed && isExternalPhoneApp(app)
      const token = Symbol(id)
      const installations =
        pendingInstallations.get(this) ??
        new Map<LaunchablePhoneAppId, PendingInstallation>()
      this.installingApps[id] = true
      const timer = globalThis.setTimeout(() => {
        const pending = installations.get(id)
        if (!pending || pending.token !== token) return
        installations.delete(id)
        if (!installations.size) pendingInstallations.delete(this)

        const activePhone = usePhoneStore()
        if (
          !activePhone.isOpen ||
          activePhone.device?.imei !== pending.deviceImei
        ) {
          delete this.installingApps[id]
          console.error(
            `[App store] Installation cancelled because the active phone changed for ${id}.`,
          )
          return
        }
        if (!this.isAvailable(id)) {
          delete this.installingApps[id]
          return
        }
        if (reportInstall && !isExternalPhoneApp(getPhoneApp(id))) {
          delete this.installingApps[id]
          console.error(
            `[Custom apps] Installation cancelled because ${id} is no longer registered.`,
          )
          return
        }
        if (this.isInstalled(id)) {
          this.restoreHomeApp(id)
        } else {
          this.claimApp(id)
        }
        delete this.installingApps[id]
        if (reportInstall) {
          void nuiCall('custom-app:lifecycle', {
            appId: id,
            event: 'install',
          }).then((response) => {
            if (!response.success) {
              console.error(
                `[Custom apps] Install lifecycle failed for ${id}: ${response.error ?? 'request_failed'}`,
              )
            }
          })
        }
      }, INSTALL_DURATION_MS)
      installations.set(id, { deviceImei, timer, token })
      pendingInstallations.set(this, installations)
    },
    hydrate(payload: unknown, disabledApps: unknown = []): void {
      this.cancelPendingInstalls()
      this.disabledApps = Array.isArray(disabledApps)
        ? disabledApps.filter(
            (id): id is LaunchablePhoneAppId =>
              typeof id === 'string' && isPhoneAppId(id),
          )
        : []
      const data = payload as {
        claimedApps?: unknown
        homeLayout?: unknown
        launchCounts?: unknown
        uninstalledApps?: unknown
      } | null
      const layoutVersion =
        data?.homeLayout && typeof data.homeLayout === 'object'
          ? (data.homeLayout as { version?: unknown }).version
          : undefined
      const supportsPersistedExternalApps =
        layoutVersion === 3 ||
        layoutVersion === 4 ||
        layoutVersion === 5 ||
        layoutVersion === 6
      this.claimedApps = Array.isArray(data?.claimedApps)
        ? data.claimedApps.filter((id): id is LaunchablePhoneAppId => {
            if (typeof id !== 'string') return false
            const app = getPhoneApp(id)
            if (app?.adminOnly) return false
            return (
              isPhoneAppId(id) ||
              (supportsPersistedExternalApps && isValidExternalPhoneAppId(id))
            )
          })
        : []
      this.uninstalledApps = Array.isArray(data?.uninstalledApps)
        ? data.uninstalledApps.filter((id): id is LaunchablePhoneAppId => {
            if (typeof id !== 'string' || !isPhoneAppId(id)) return false
            const app = getPhoneApp(id)
            return !!app && isPhoneAppRemovable(app)
          })
        : []
      const installedIds = [
        ...new Set([
          ...getDefaultInstalledIds(this.disabledApps),
          ...this.claimedApps,
        ]),
      ].filter(
        (id) =>
          !this.uninstalledApps.includes(id) && this.isAvailable(id),
      )
      const removedLegacyDefaults = hasUninstalledBuiltinApp(
        data?.homeLayout,
        installedIds,
      )
      const defaults = createDefaultHomeLayout(
        installedIds,
        getDefaultGridIds(this.disabledApps),
        getDefaultDockIds(this.disabledApps),
      )
      const parsedHomeLayout = parseHomeLayout(
        data?.homeLayout,
        defaults,
        installedIds,
        false,
      )
      const normalizedHomeLayout = removeDockGridDuplicates(parsedHomeLayout)
      const removedDockGridDuplicates =
        normalizedHomeLayout !== parsedHomeLayout
      this.homeLayout = normalizedHomeLayout
      const protectedHiddenAppIds = this.homeLayout.hidden.filter((appId) =>
        isProtectedHomeApp(appId, this.disabledApps),
      )
      for (const appId of protectedHiddenAppIds) {
        this.homeLayout = restoreHomeApp(this.homeLayout, appId)
      }
      this.launchCounts = {}
      if (data?.launchCounts && typeof data.launchCounts === 'object') {
        for (const [appId, count] of Object.entries(data.launchCounts)) {
          if (
            (isPhoneAppId(appId) ||
              (supportsPersistedExternalApps &&
                isValidExternalPhoneAppId(appId))) &&
            typeof count === 'number' &&
            Number.isFinite(count) &&
            count > 0
          ) {
            this.launchCounts[appId] = Math.floor(count)
          }
        }
      }
      this.hydrated = true
      if (
        protectedHiddenAppIds.length ||
        removedDockGridDuplicates ||
        removedLegacyDefaults ||
        layoutVersion === 2 ||
        layoutVersion === 3 ||
        layoutVersion === 4 ||
        layoutVersion === 5
      ) {
        this.persist()
      }
    },
    isAvailable(appId: LaunchablePhoneAppId): boolean {
      return !isAppDisabled(appId, this.disabledApps)
    },
    isInstalled(appId: LaunchablePhoneAppId): boolean {
      if (!this.isAvailable(appId)) return false
      const app = getPhoneApp(appId)
      if (app?.adminOnly) return false
      if (this.uninstalledApps.includes(appId)) return false
      if (this.claimedApps.includes(appId)) return true
      if (!app) return false
      return isExternalPhoneApp(app)
        ? app.defaultInstalled
        : DEFAULT_INSTALLED_PHONE_APP_IDS.has(app.id)
    },
    reconcileCatalog(): void {
      const installedIds = [
        ...new Set([
          ...getDefaultInstalledIds(this.disabledApps),
          ...this.claimedApps,
        ]),
      ].filter(
        (id) =>
          !this.uninstalledApps.includes(id) && this.isAvailable(id),
      )
      const defaults = createDefaultHomeLayout(
        installedIds,
        getDefaultGridIds(this.disabledApps),
        getDefaultDockIds(this.disabledApps),
      )
      const previous = JSON.stringify(this.homeLayout)
      this.homeLayout = removeDockGridDuplicates(
        parseHomeLayout(this.homeLayout, defaults, installedIds, false),
      )

      for (const appId of [...this.homeLayout.hidden]) {
        if (isProtectedHomeApp(appId, this.disabledApps)) {
          this.homeLayout = restoreHomeApp(this.homeLayout, appId)
        }
      }

      if (this.hydrated && previous !== JSON.stringify(this.homeLayout)) {
        this.persist()
      }
    },
    recordLaunch(appId: LaunchablePhoneAppId): void {
      if (!this.isAvailable(appId)) return
      this.launchCounts[appId] = (this.launchCounts[appId] ?? 0) + 1
      this.persist()
    },
    moveHomeApp(
      from: HomeArea,
      sourceIndex: number,
      to: HomeArea,
      targetIndex: number,
    ): boolean {
      const next = moveHomeApp(
        this.homeLayout,
        from,
        sourceIndex,
        to,
        targetIndex,
      )
      if (next === this.homeLayout) return false
      this.homeLayout = next
      this.persist()
      return true
    },
    moveHomeAppToGridPage(
      from: HomeArea,
      sourceIndex: number,
      targetPage: number,
      targetOffset: number,
      capacities: readonly number[],
    ): boolean {
      const next = moveHomeAppToGridPage(
        this.homeLayout,
        from,
        sourceIndex,
        targetPage,
        targetOffset,
        capacities,
      )
      if (next === this.homeLayout) return false
      this.homeLayout = next
      this.persist()
      return true
    },
    applyWidgetGridCapacities(
      previousCapacities: readonly number[],
      nextCapacities: readonly number[],
    ): boolean {
      const next = reflowHomeGridForWidgetChange(
        this.homeLayout,
        previousCapacities,
        nextCapacities,
      )
      if (!next) return false
      if (next !== this.homeLayout) {
        this.homeLayout = next
        this.persist()
      }
      return true
    },
    createHomeFolder(
      from: HomeArea,
      sourceIndex: number,
      to: HomeArea,
      targetIndex: number,
      name: string,
    ): string | null {
      const folderId = `folder-${globalThis.crypto.randomUUID()}`
      const next = createHomeFolder(
        this.homeLayout,
        from,
        sourceIndex,
        to,
        targetIndex,
        folderId,
        name,
      )
      if (next === this.homeLayout) return null
      this.homeLayout = next
      this.persist()
      return folderId
    },
    addHomeAppToFolder(
      from: HomeArea,
      sourceIndex: number,
      folderId: string,
    ): boolean {
      const next = addHomeAppToFolder(
        this.homeLayout,
        from,
        sourceIndex,
        folderId,
      )
      if (next === this.homeLayout) return false
      this.homeLayout = next
      this.persist()
      return true
    },
    renameHomeFolder(folderId: string, name: string): void {
      const next = renameHomeFolder(this.homeLayout, folderId, name)
      if (next === this.homeLayout) return
      this.homeLayout = next
      this.persist()
    },
    moveHomeFolderApp(
      folderId: string,
      sourceIndex: number,
      targetIndex: number,
    ): void {
      const next = moveHomeFolderApp(
        this.homeLayout,
        folderId,
        sourceIndex,
        targetIndex,
      )
      if (next === this.homeLayout) return
      this.homeLayout = next
      this.persist()
    },
    extractHomeFolderApp(
      folderId: string,
      sourceIndex: number,
      to: HomeArea,
      targetIndex: number,
    ): boolean {
      const next = extractHomeFolderApp(
        this.homeLayout,
        folderId,
        sourceIndex,
        to,
        targetIndex,
      )
      if (next === this.homeLayout) return false
      this.homeLayout = next
      this.persist()
      return true
    },
    removeHomeApp(appId: LaunchablePhoneAppId): void {
      if (isProtectedHomeApp(appId, this.disabledApps)) return

      this.homeLayout = removeHomeApp(this.homeLayout, appId)
      this.persist()
    },
    restoreHomeApp(appId: LaunchablePhoneAppId): void {
      if (!this.isAvailable(appId)) return
      this.homeLayout = restoreHomeApp(this.homeLayout, appId)
      this.persist()
    },
    uninstallApp(appId: LaunchablePhoneAppId): boolean {
      const app = getPhoneApp(appId)
      if (!app || !this.isInstalled(appId) || !isPhoneAppRemovable(app)) {
        return false
      }

      this.claimedApps = this.claimedApps.filter((id) => id !== appId)
      if (!this.uninstalledApps.includes(appId)) {
        this.uninstalledApps.push(appId)
      }
      this.homeLayout = removeHomeApp(this.homeLayout, appId)
      this.persist()
      if (isExternalPhoneApp(app)) {
        void nuiCall('custom-app:lifecycle', {
          appId,
          event: 'delete',
        }).then((response) => {
          if (!response.success) {
            console.error(
              `[Custom apps] Delete lifecycle failed for ${appId}: ${response.error ?? 'request_failed'}`,
            )
          }
        })
      }

      return true
    },
    persist(): void {
      usePhoneStore().saveDeviceNamespace('apps', {
        claimedApps: this.claimedApps,
        homeLayout: this.homeLayout,
        launchCounts: this.launchCounts,
        ...(this.uninstalledApps.length
          ? { uninstalledApps: this.uninstalledApps }
          : {}),
      })
    },
  },
})
