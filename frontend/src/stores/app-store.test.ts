import { createPinia, setActivePinia } from 'pinia'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { NON_REMOVABLE_PHONE_APP_IDS } from '@/config/apps'
import { useAppStoreStore } from '@/stores/app-store'
import { removeHomeApp } from '@/utils/homeLayout'

const mocks = vi.hoisted(() => ({ saveDeviceNamespace: vi.fn() }))
vi.mock('@/stores/phone', () => ({
  usePhoneStore: () => ({
    saveDeviceNamespace: mocks.saveDeviceNamespace,
  }),
}))

describe('app store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    mocks.saveDeviceNamespace.mockReset()
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it('hydrates valid launch counts and persists launches with claimed apps', () => {
    const apps = useAppStoreStore()

    apps.hydrate({
      claimedApps: ['snake'],
      launchCounts: { mail: 3, invalid: 20, phone: -1 },
    })
    apps.recordLaunch('mail')

    expect(apps.launchCounts).toEqual({ mail: 4 })
    expect(mocks.saveDeviceNamespace).toHaveBeenCalledWith('apps', {
      claimedApps: ['snake'],
      homeLayout: apps.homeLayout,
      launchCounts: { mail: 4 },
    })
  })

  it('installs an app after showing a three second loading state', () => {
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
    expect(mocks.saveDeviceNamespace).toHaveBeenCalledWith('apps', {
      claimedApps: ['snake'],
      homeLayout: apps.homeLayout,
      launchCounts: {},
    })
  })

  it('ignores duplicate installation requests and invalid persisted ids', () => {
    vi.useFakeTimers()
    const apps = useAppStoreStore()

    apps.hydrate({ claimedApps: ['memory', 'not-an-app'] })
    apps.installApp('snake')
    apps.installApp('snake')
    vi.advanceTimersByTime(3000)

    expect(apps.claimedApps).toEqual(['memory', 'snake'])
    expect(mocks.saveDeviceNamespace).toHaveBeenCalledTimes(1)
  })

  it('reinstalls core and claimed apps removed from the Home Screen', () => {
    vi.useFakeTimers()
    const apps = useAppStoreStore()

    apps.hydrate({ claimedApps: ['memory'] })
    apps.removeHomeApp('notes')
    apps.removeHomeApp('memory')
    mocks.saveDeviceNamespace.mockClear()

    apps.installApp('notes')
    apps.installApp('memory')

    expect(apps.installingApps).toEqual({ notes: true, memory: true })
    expect(apps.homeLayout.hidden).toEqual(['notes', 'memory'])

    vi.advanceTimersByTime(3000)

    expect(apps.installingApps).toEqual({})
    expect(apps.homeLayout.hidden).toEqual([])
    expect(apps.homeLayout.grid).toContain('notes')
    expect(apps.homeLayout.grid).toContain('memory')
    expect(apps.claimedApps).toEqual(['memory'])
    expect(mocks.saveDeviceNamespace).toHaveBeenCalledTimes(2)
  })

  it('prevents protected apps from being removed from the Home Screen', () => {
    const apps = useAppStoreStore()
    apps.hydrate(null)
    mocks.saveDeviceNamespace.mockClear()

    expect([...NON_REMOVABLE_PHONE_APP_IDS]).toEqual([
      'app-store',
      'settings',
      'camera',
      'photos',
      'phone',
      'messages',
      'mail',
    ])
    for (const appId of NON_REMOVABLE_PHONE_APP_IDS) {
      apps.removeHomeApp(appId)
      expect(apps.homeLayout.hidden).not.toContain(appId)
    }

    expect(mocks.saveDeviceNamespace).not.toHaveBeenCalled()
  })

  it('restores protected apps hidden by older persisted layouts', () => {
    const apps = useAppStoreStore()
    const legacyLayout = removeHomeApp(apps.homeLayout, 'mail')

    apps.hydrate({ homeLayout: legacyLayout })

    expect(apps.homeLayout.hidden).not.toContain('mail')
    expect(apps.homeLayout.grid).toContain('mail')
    expect(mocks.saveDeviceNamespace).toHaveBeenCalledWith('apps', {
      claimedApps: [],
      homeLayout: apps.homeLayout,
      launchCounts: {},
    })
  })

  it('persists home reordering and removal independently from installation', () => {
    const apps = useAppStoreStore()
    apps.hydrate(null)

    const notesIndex = apps.homeLayout.grid.indexOf('notes')
    apps.moveHomeApp('grid', notesIndex, 'grid', 0)
    expect(apps.homeLayout.grid[0]).toBe('notes')

    apps.removeHomeApp('notes')
    expect(apps.homeLayout.grid).not.toContain('notes')
    expect(apps.homeLayout.hidden).toContain('notes')
    expect(mocks.saveDeviceNamespace).toHaveBeenLastCalledWith('apps', {
      claimedApps: [],
      homeLayout: apps.homeLayout,
      launchCounts: {},
    })
  })
})
