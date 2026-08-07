import { createPinia, setActivePinia } from 'pinia'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { useAppStoreStore } from '@/stores/app-store'

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
    apps.removeHomeApp('mail')
    apps.removeHomeApp('memory')
    mocks.saveDeviceNamespace.mockClear()

    apps.installApp('mail')
    apps.installApp('memory')

    expect(apps.installingApps).toEqual({ mail: true, memory: true })
    expect(apps.homeLayout.hidden).toEqual(['mail', 'memory'])

    vi.advanceTimersByTime(3000)

    expect(apps.installingApps).toEqual({})
    expect(apps.homeLayout.hidden).toEqual([])
    expect(apps.homeLayout.grid).toContain('mail')
    expect(apps.homeLayout.grid).toContain('memory')
    expect(apps.claimedApps).toEqual(['memory'])
    expect(mocks.saveDeviceNamespace).toHaveBeenCalledTimes(2)
  })

  it('persists home reordering and removal independently from installation', () => {
    const apps = useAppStoreStore()
    apps.hydrate(null)

    const mailIndex = apps.homeLayout.grid.indexOf('mail')
    apps.moveHomeApp('grid', mailIndex, 'grid', 0)
    expect(apps.homeLayout.grid[0]).toBe('mail')

    apps.removeHomeApp('mail')
    expect(apps.homeLayout.grid).not.toContain('mail')
    expect(apps.homeLayout.hidden).toContain('mail')
    expect(mocks.saveDeviceNamespace).toHaveBeenLastCalledWith('apps', {
      claimedApps: [],
      homeLayout: apps.homeLayout,
      launchCounts: {},
    })
  })
})
