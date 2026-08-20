import { createPinia, setActivePinia } from 'pinia'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { DEFAULT_INSTALLED_PHONE_APP_IDS } from '@/config/apps'
import { useAppStoreStore } from '@/stores/app-store'
import {
  getHomeFolder,
  HOME_GRID_PAGE_SIZE,
  HOME_LAYOUT_VERSION,
  removeHomeApp,
} from '@/utils/homeLayout'

const mocks = vi.hoisted(() => ({
  phone: {
    device: { imei: 'phone-a' },
    isOpen: true,
    permissions: { adminPanel: false },
    saveDeviceNamespace: vi.fn(),
  },
}))
vi.mock('@/stores/phone', () => ({
  usePhoneStore: () => mocks.phone,
}))

describe('app store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    mocks.phone.device.imei = 'phone-a'
    mocks.phone.isOpen = true
    mocks.phone.permissions.adminPanel = false
    mocks.phone.saveDeviceNamespace.mockReset()
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it('installs the sixteen system apps by default', () => {
    const apps = useAppStoreStore()

    apps.hydrate(null)

    expect([...DEFAULT_INSTALLED_PHONE_APP_IDS]).toEqual([
      'phone',
      'messages',
      'calculator',
      'camera',
      'clock',
      'weather',
      'mail',
      'notes',
      'memos',
      'photos',
      'app-store',
      'settings',
      'map',
      'calendar',
      'health',
      'citywarn',
    ])
    for (const appId of DEFAULT_INSTALLED_PHONE_APP_IDS) {
      expect(apps.isInstalled(appId)).toBe(true)
    }
    expect(apps.isInstalled('banking')).toBe(false)
    expect(apps.isInstalled('feather')).toBe(false)
    expect(apps.isInstalled('snake')).toBe(false)
    expect(apps.isInstalled('health')).toBe(true)
    expect(apps.isInstalled('citywarn')).toBe(true)
    expect(apps.homeLayout.dock).toEqual([
      'phone',
      'messages',
      'camera',
      'clock',
    ])
    for (const dockAppId of ['phone', 'messages', 'camera', 'clock']) {
      expect(apps.homeLayout.grid).not.toContain(dockAppId)
    }
  })

  it('exposes the protected admin app only with server-granted access', () => {
    const apps = useAppStoreStore()

    apps.hydrate({ claimedApps: ['admin'] })
    expect(apps.isInstalled('admin')).toBe(false)
    expect(apps.homeLayout.grid).not.toContain('admin')

    mocks.phone.permissions.adminPanel = true
    apps.hydrate(null, true)
    expect(apps.isInstalled('admin')).toBe(true)
    expect(apps.homeLayout.grid).toContain('admin')
  })

  it('migrates current layouts so dock apps are not repeated in the grid', () => {
    const apps = useAppStoreStore()

    apps.hydrate({
      homeLayout: {
        dock: ['phone', 'messages', 'camera', 'clock'],
        grid: ['phone', 'messages', 'calculator', 'camera', 'clock'],
        hidden: [],
        pageCount: 1,
        version: HOME_LAYOUT_VERSION,
      },
    })

    expect(apps.homeLayout.dock).toEqual([
      'phone',
      'messages',
      'camera',
      'clock',
    ])
    for (const dockAppId of ['phone', 'messages', 'camera', 'clock']) {
      expect(apps.homeLayout.grid).not.toContain(dockAppId)
    }
    expect(apps.homeLayout.grid).toContain('calculator')
    expect(mocks.phone.saveDeviceNamespace).toHaveBeenCalledTimes(1)
  })

  it('removes old automatic apps unless the player installed them', () => {
    const apps = useAppStoreStore()

    apps.hydrate({
      claimedApps: ['feather'],
      homeLayout: {
        dock: [],
        grid: ['banking', 'feather', 'phone'],
        hidden: [],
        version: 5,
      },
    })

    expect(apps.homeLayout.grid).not.toContain('banking')
    expect(apps.homeLayout.grid).toContain('feather')
    expect(mocks.phone.saveDeviceNamespace).toHaveBeenCalledTimes(1)
  })

  it('hydrates valid launch counts and persists launches with claimed apps', () => {
    const apps = useAppStoreStore()

    apps.hydrate({
      claimedApps: ['snake'],
      launchCounts: { mail: 3, invalid: 20, phone: -1 },
    })
    apps.recordLaunch('mail')

    expect(apps.launchCounts).toEqual({ mail: 4 })
    expect(mocks.phone.saveDeviceNamespace).toHaveBeenCalledWith('apps', {
      claimedApps: ['snake'],
      homeLayout: apps.homeLayout,
      launchCounts: { mail: 4 },
    })
  })

  it('keeps external app state while migrating version 4 layouts', () => {
    const apps = useAppStoreStore()
    const grid = Array.from({ length: 24 }, () => null as string | null)
    grid[20] = 'external-radio'

    apps.hydrate({
      claimedApps: ['external-radio'],
      homeLayout: { dock: [], grid, hidden: [], version: 4 },
      launchCounts: { 'external-radio': 3 },
    })

    expect(apps.claimedApps).toEqual(['external-radio'])
    expect(apps.homeLayout.version).toBe(HOME_LAYOUT_VERSION)
    expect(apps.homeLayout.grid).toContain('external-radio')
    const pageAppCount = apps.homeLayout.grid
      .slice(0, HOME_GRID_PAGE_SIZE)
      .filter((appId) => appId !== null).length
    expect(apps.homeLayout.grid.slice(0, pageAppCount)).not.toContain(null)
    expect(apps.launchCounts).toEqual({ 'external-radio': 3 })
    expect(mocks.phone.saveDeviceNamespace).toHaveBeenCalledTimes(1)
  })

  it('keeps external app state from current layouts', () => {
    const apps = useAppStoreStore()

    apps.hydrate({
      claimedApps: ['external-radio'],
      homeLayout: {
        dock: [],
        grid: ['external-radio'],
        hidden: [],
        pageCount: 1,
        version: HOME_LAYOUT_VERSION,
      },
      launchCounts: { 'external-radio': 3 },
    })

    expect(apps.claimedApps).toEqual(['external-radio'])
    expect(apps.homeLayout.grid).toContain('external-radio')
    expect(apps.launchCounts).toEqual({ 'external-radio': 3 })
    expect(mocks.phone.saveDeviceNamespace).not.toHaveBeenCalled()
  })

  it('persists a page-aware version 3 migration once', () => {
    const apps = useAppStoreStore()
    const grid = Array.from({ length: 40 }, () => null as string | null)
    grid[20] = 'external-page-two'

    apps.hydrate({
      claimedApps: ['external-page-two'],
      homeLayout: { dock: [], grid, hidden: [], version: 3 },
    })

    expect(apps.homeLayout.version).toBe(HOME_LAYOUT_VERSION)
    expect(apps.homeLayout.grid[20]).not.toBe('external-page-two')
    expect(apps.homeLayout.grid[24]).toBe('external-page-two')
    expect(mocks.phone.saveDeviceNamespace).toHaveBeenCalledTimes(1)
  })

  it('installs a downloadable app after a three second loading state', () => {
    vi.useFakeTimers()
    const apps = useAppStoreStore()

    apps.installApp('snake')

    expect(apps.installingApps.snake).toBe(true)
    expect(apps.claimedApps).toEqual([])

    vi.advanceTimersByTime(2999)
    expect(apps.claimedApps).toEqual([])

    vi.advanceTimersByTime(1)
    expect(apps.installingApps.snake).toBeUndefined()
    expect(apps.claimedApps).toEqual(['snake'])
    expect(mocks.phone.saveDeviceNamespace).toHaveBeenCalledWith('apps', {
      claimedApps: ['snake'],
      homeLayout: apps.homeLayout,
      launchCounts: {},
    })
  })

  it('fully uninstalls removable apps and allows downloading them again', () => {
    vi.useFakeTimers()
    const apps = useAppStoreStore()
    apps.hydrate({ claimedApps: ['snake'] })
    mocks.phone.saveDeviceNamespace.mockClear()

    expect(apps.uninstallApp('snake')).toBe(true)
    expect(apps.isInstalled('snake')).toBe(false)
    expect(apps.uninstalledApps).toEqual(['snake'])
    expect(apps.homeLayout.hidden).toContain('snake')
    expect(mocks.phone.saveDeviceNamespace).toHaveBeenLastCalledWith('apps', {
      claimedApps: [],
      homeLayout: apps.homeLayout,
      launchCounts: {},
      uninstalledApps: ['snake'],
    })

    apps.installApp('snake')
    vi.advanceTimersByTime(3000)

    expect(apps.isInstalled('snake')).toBe(true)
    expect(apps.uninstalledApps).toEqual([])
    expect(apps.homeLayout.hidden).not.toContain('snake')
  })

  it('hydrates persisted removals while rejecting protected and invalid ids', () => {
    const apps = useAppStoreStore()

    apps.hydrate({
      uninstalledApps: ['calculator', 'phone', 'not-an-app'],
    })

    expect(apps.uninstalledApps).toEqual([])
    expect(apps.isInstalled('calculator')).toBe(true)
    expect(apps.isInstalled('phone')).toBe(true)
  })

  it('protects every default app from full uninstallation', () => {
    const apps = useAppStoreStore()
    apps.hydrate(null)
    mocks.phone.saveDeviceNamespace.mockClear()

    for (const appId of DEFAULT_INSTALLED_PHONE_APP_IDS) {
      expect(apps.uninstallApp(appId)).toBe(false)
      expect(apps.isInstalled(appId)).toBe(true)
    }
    expect(mocks.phone.saveDeviceNamespace).not.toHaveBeenCalled()
  })

  it('ignores duplicate installation requests and invalid persisted ids', () => {
    vi.useFakeTimers()
    const apps = useAppStoreStore()

    apps.hydrate({ claimedApps: ['memory', 'not-an-app'] })
    apps.installApp('snake')
    apps.installApp('snake')
    vi.advanceTimersByTime(3000)

    expect(apps.claimedApps).toEqual(['memory', 'snake'])
    expect(mocks.phone.saveDeviceNamespace).toHaveBeenCalledTimes(1)
  })

  it('reinstalls claimed apps removed from the Home Screen', () => {
    vi.useFakeTimers()
    const apps = useAppStoreStore()

    apps.hydrate({ claimedApps: ['memory'] })
    apps.removeHomeApp('notes')
    apps.removeHomeApp('memory')
    mocks.phone.saveDeviceNamespace.mockClear()

    apps.installApp('notes')
    apps.installApp('memory')

    expect(apps.installingApps).toEqual({ memory: true })
    expect(apps.homeLayout.hidden).toEqual(['memory'])

    vi.advanceTimersByTime(3000)

    expect(apps.installingApps).toEqual({})
    expect(apps.homeLayout.hidden).toEqual([])
    expect(apps.homeLayout.grid).toContain('notes')
    expect(apps.homeLayout.grid).toContain('memory')
    expect(apps.claimedApps).toEqual(['memory'])
    expect(mocks.phone.saveDeviceNamespace).toHaveBeenCalledTimes(1)
  })

  it('prevents every default app from being removed from the Home Screen', () => {
    const apps = useAppStoreStore()
    apps.hydrate(null)
    mocks.phone.saveDeviceNamespace.mockClear()

    for (const appId of DEFAULT_INSTALLED_PHONE_APP_IDS) {
      apps.removeHomeApp(appId)
      expect(apps.homeLayout.hidden).not.toContain(appId)
    }

    expect(mocks.phone.saveDeviceNamespace).not.toHaveBeenCalled()
  })

  it('restores protected apps hidden by older persisted layouts', () => {
    const apps = useAppStoreStore()
    const legacyLayout = removeHomeApp(apps.homeLayout, 'mail')

    apps.hydrate({ homeLayout: legacyLayout })

    expect(apps.homeLayout.hidden).not.toContain('mail')
    expect(apps.homeLayout.grid).toContain('mail')
    expect(mocks.phone.saveDeviceNamespace).toHaveBeenCalledWith('apps', {
      claimedApps: [],
      homeLayout: apps.homeLayout,
      launchCounts: {},
    })
  })

  it('persists home reordering and removal independently from installation', () => {
    const apps = useAppStoreStore()
    apps.hydrate({ claimedApps: ['memory'] })
    mocks.phone.saveDeviceNamespace.mockClear()

    const memoryIndex = apps.homeLayout.grid.indexOf('memory')
    apps.moveHomeApp('grid', memoryIndex, 'grid', 0)
    expect(apps.homeLayout.grid[0]).toBe('memory')

    apps.removeHomeApp('memory')
    expect(apps.homeLayout.grid).not.toContain('memory')
    expect(apps.homeLayout.hidden).toContain('memory')
    expect(mocks.phone.saveDeviceNamespace).toHaveBeenLastCalledWith('apps', {
      claimedApps: ['memory'],
      homeLayout: apps.homeLayout,
      launchCounts: {},
    })
  })

  it('persists a cross-page drop exactly once', () => {
    const apps = useAppStoreStore()
    apps.hydrate(null)
    mocks.phone.saveDeviceNamespace.mockClear()
    const sourceIndex = apps.homeLayout.grid.indexOf('calculator')
    expect(sourceIndex).toBeGreaterThanOrEqual(0)

    expect(
      apps.moveHomeAppToGridPage('grid', sourceIndex, 2, 0, [
        HOME_GRID_PAGE_SIZE,
        HOME_GRID_PAGE_SIZE,
      ]),
    ).toBe(true)
    expect(apps.homeLayout.grid[HOME_GRID_PAGE_SIZE]).toBe('calculator')
    expect(mocks.phone.saveDeviceNamespace).toHaveBeenCalledTimes(1)
  })

  it('persists widget reflow without pulling apps back a page', () => {
    const apps = useAppStoreStore()
    apps.hydrate(null)
    mocks.phone.saveDeviceNamespace.mockClear()
    const originalApps = apps.homeLayout.grid.filter(Boolean)

    expect(
      apps.applyWidgetGridCapacities(
        [10, HOME_GRID_PAGE_SIZE],
        [HOME_GRID_PAGE_SIZE, 10],
      ),
    ).toBe(true)
    expect(
      apps.homeLayout.grid.slice(0, HOME_GRID_PAGE_SIZE).filter(Boolean),
    ).toEqual(originalApps.slice(0, 10))
    expect(
      apps.homeLayout.grid
        .slice(HOME_GRID_PAGE_SIZE, HOME_GRID_PAGE_SIZE * 2)
        .filter(Boolean),
    ).toEqual(originalApps.slice(10))
    expect(mocks.phone.saveDeviceNamespace).toHaveBeenCalledTimes(1)
  })

  it('persists and restores an otherwise empty extra page', () => {
    const apps = useAppStoreStore()
    apps.hydrate(null)
    mocks.phone.saveDeviceNamespace.mockClear()

    expect(apps.addHomePage()).toBe(true)
    expect(apps.homeLayout.pageCount).toBe(2)
    expect(mocks.phone.saveDeviceNamespace).toHaveBeenCalledTimes(1)

    const persisted = mocks.phone.saveDeviceNamespace.mock.calls[0]?.[1] as {
      homeLayout: typeof apps.homeLayout
    }
    apps.hydrate({
      ...persisted,
      homeLayout: {
        ...persisted.homeLayout,
        grid: persisted.homeLayout.grid.slice(0, HOME_GRID_PAGE_SIZE),
      },
    })

    expect(apps.homeLayout.pageCount).toBe(2)
    expect(apps.homeLayout.grid).toHaveLength(HOME_GRID_PAGE_SIZE * 2)
  })

  it('persists the complete folder lifecycle through store actions', () => {
    const apps = useAppStoreStore()
    apps.hydrate(null)
    mocks.phone.saveDeviceNamespace.mockClear()

    const notesIndex = apps.homeLayout.grid.indexOf('notes')
    const settingsIndex = apps.homeLayout.grid.indexOf('settings')
    const folderId = apps.createHomeFolder(
      'grid',
      notesIndex,
      'grid',
      settingsIndex,
      'Utilities',
    )

    expect(folderId).toBeTruthy()
    expect(getHomeFolder(apps.homeLayout, folderId!)?.apps).toEqual([
      'settings',
      'notes',
    ])
    const mailIndex = apps.homeLayout.grid.indexOf('mail')
    expect(apps.addHomeAppToFolder('grid', mailIndex, folderId!)).toBe(true)
    apps.moveHomeFolderApp(folderId!, 2, 0)
    apps.renameHomeFolder(folderId!, 'Work')
    expect(getHomeFolder(apps.homeLayout, folderId!)).toMatchObject({
      apps: ['mail', 'notes', 'settings'],
      name: 'Work',
    })

    const emptyIndex = apps.homeLayout.grid.indexOf(null)
    expect(apps.extractHomeFolderApp(folderId!, 0, 'grid', emptyIndex)).toBe(
      true,
    )
    expect(apps.homeLayout.grid).toContain('mail')
    expect(mocks.phone.saveDeviceNamespace).toHaveBeenCalledTimes(5)
  })

  it('does not commit an installation to a different phone', () => {
    vi.useFakeTimers()
    const apps = useAppStoreStore()

    apps.installApp('snake')
    mocks.phone.device.imei = 'phone-b'
    vi.advanceTimersByTime(3000)

    expect(apps.installingApps).toEqual({})
    expect(apps.claimedApps).toEqual([])
    expect(mocks.phone.saveDeviceNamespace).not.toHaveBeenCalled()
  })

  it('cancels installation timers when hydration changes device scope', () => {
    vi.useFakeTimers()
    const apps = useAppStoreStore()

    apps.installApp('snake')
    expect(vi.getTimerCount()).toBe(1)

    mocks.phone.device.imei = 'phone-b'
    apps.hydrate(null)
    expect(vi.getTimerCount()).toBe(0)

    vi.advanceTimersByTime(3000)
    expect(apps.claimedApps).toEqual([])
    expect(mocks.phone.saveDeviceNamespace).not.toHaveBeenCalled()
  })

  it('cancels installation timers when the phone closes', () => {
    vi.useFakeTimers()
    const apps = useAppStoreStore()

    apps.installApp('snake')
    mocks.phone.isOpen = false
    apps.cancelPendingInstalls()

    expect(vi.getTimerCount()).toBe(0)
    expect(apps.installingApps).toEqual({})
    vi.advanceTimersByTime(3000)
    expect(apps.claimedApps).toEqual([])
    expect(mocks.phone.saveDeviceNamespace).not.toHaveBeenCalled()
  })
})
