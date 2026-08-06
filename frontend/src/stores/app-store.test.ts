import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

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
})
