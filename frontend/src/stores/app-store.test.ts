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
})
