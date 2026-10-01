import { createPinia, setActivePinia } from 'pinia'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { getPhoneApp, replaceExternalPhoneApps } from '@/config/apps'
import { useAppCatalogStore } from '@/stores/app-catalog'
import { useAppStoreStore } from '@/stores/app-store'
import { usePhoneStore } from '@/stores/phone'
import { nuiCall } from '@/utils/nui'

vi.mock('@/utils/nui', () => ({ nuiCall: vi.fn() }))

const mockNuiCall = vi.mocked(nuiCall)

function registerApps(ids: string[]): void {
  useAppCatalogStore().replaceCatalog({
    apps: ids.map((id) => ({
      defaultInstalled: true,
      icon: 'https://cfx-nui-example/ui/icon.png',
      id,
      name: id,
      ownerResource: 'example',
      ui: 'https://cfx-nui-example/ui/index.html',
    })),
  })
}

function openPhone(imei: string, payload: unknown = null): void {
  usePhoneStore().open({
    device: {
      data: { apps: { payload, revision: 0 } },
      imei,
      name: 'Phone',
      sim: null,
    },
    token: `session-${imei}`,
  })
  useAppStoreStore().hydrate(payload)
}

describe('custom app catalog device persistence', () => {
  beforeEach(() => {
    vi.stubGlobal('window', { matchMedia: () => ({ matches: false }) })
    setActivePinia(createPinia())
    replaceExternalPhoneApps([])
    mockNuiCall.mockReset()
    mockNuiCall.mockResolvedValue({ success: true, data: { revision: 1 } })
    vi.spyOn(console, 'error').mockImplementation(() => {})
  })

  afterEach(async () => {
    vi.useRealTimers()
    await usePhoneStore().flushDevicePersistence()
    replaceExternalPhoneApps([])
    vi.restoreAllMocks()
    vi.unstubAllGlobals()
  })

  it('accepts startup registrations and adds them when a device first opens', () => {
    registerApps(['external-radio'])
    registerApps(['external-radio', 'external-chat'])

    expect(useAppCatalogStore().externalApps).toHaveLength(2)
    expect(mockNuiCall).not.toHaveBeenCalled()
    expect(console.error).not.toHaveBeenCalled()

    openPhone('111')
    expect(useAppStoreStore().homeLayout.grid).toEqual(
      expect.arrayContaining(['external-radio', 'external-chat']),
    )
  })

  it('does not mutate or save the previous device during closed registrations', async () => {
    openPhone('111')
    const phone = usePhoneStore()
    const apps = useAppStoreStore()
    const previousLayout = JSON.stringify(apps.homeLayout)
    phone.endDeviceSession()

    registerApps(['external-radio'])
    registerApps(['external-radio', 'external-chat'])
    await phone.flushDevicePersistence()

    expect(phone.device?.imei).toBe('111')
    expect(phone.deviceSessionToken).toBeNull()
    expect(JSON.stringify(apps.homeLayout)).toBe(previousLayout)
    expect(mockNuiCall).not.toHaveBeenCalled()
    expect(console.error).not.toHaveBeenCalled()

    openPhone('111')
    expect(apps.homeLayout.grid).toEqual(
      expect.arrayContaining(['external-radio', 'external-chat']),
    )
  })

  it('uses the newly opened device layout after registrations while closed', async () => {
    openPhone('111')
    const phone = usePhoneStore()
    const apps = useAppStoreStore()
    const savedLayout = JSON.parse(JSON.stringify(apps.homeLayout))
    savedLayout.grid[0] = 'snake'
    phone.endDeviceSession()
    registerApps(['external-radio'])

    openPhone('222', {
      claimedApps: ['snake'],
      homeLayout: savedLayout,
      launchCounts: { snake: 7 },
    })

    expect(apps.homeLayout.grid[0]).toBe('snake')
    expect(apps.homeLayout.grid).toContain('external-radio')
    expect(apps.claimedApps).toEqual(['snake'])
    expect(apps.launchCounts).toEqual({ snake: 7 })
    apps.recordLaunch('snake')
    await phone.flushDevicePersistence()

    expect(mockNuiCall).toHaveBeenCalledOnce()
    expect(mockNuiCall).toHaveBeenCalledWith(
      'device:save',
      expect.objectContaining({
        imei: '222',
        namespace: 'apps',
        sessionToken: 'session-222',
        payload: expect.objectContaining({ launchCounts: { snake: 8 } }),
      }),
    )
  })

  it('persists changed catalogs while open and ignores identical updates', async () => {
    openPhone('111')
    const phone = usePhoneStore()
    registerApps(['external-radio'])
    await phone.flushDevicePersistence()

    expect(mockNuiCall).toHaveBeenCalledOnce()
    expect(mockNuiCall).toHaveBeenCalledWith(
      'device:save',
      expect.objectContaining({
        imei: '111',
        namespace: 'apps',
        sessionToken: 'session-111',
      }),
    )
    registerApps(['external-radio'])
    await phone.flushDevicePersistence()
    expect(mockNuiCall).toHaveBeenCalledOnce()
  })

  it('still reports actual save failures during an open session', async () => {
    openPhone('111')
    mockNuiCall.mockResolvedValueOnce({ success: false, error: 'conflict' })
    registerApps(['external-radio'])
    await usePhoneStore().flushDevicePersistence()

    expect(console.error).toHaveBeenCalledWith(
      '[Phone persistence] Could not save apps: conflict',
    )
  })

  function registerPaidApp() {
    useAppCatalogStore().replaceCatalog({
      apps: [
        {
          id: 'external-paid',
          name: 'Paid app',
          ownerResource: 'example',
          icon: 'https://cfx-nui-example/ui/icon.png',
          ui: 'https://cfx-nui-example/ui/index.html',
          store: { price: 500 },
          removable: true,
        },
      ],
    })
    return getPhoneApp('external-paid')!.id
  }

  it('awaits payment and the device save before reporting installation', async () => {
    vi.useFakeTimers()
    openPhone('111')
    const id = registerPaidApp()
    const apps = useAppStoreStore()
    apps.installApp(id)
    expect(apps.isInstalled(id)).toBe(false)
    await vi.advanceTimersByTimeAsync(3000)
    expect(mockNuiCall.mock.calls.map(([endpoint]) => endpoint)).toEqual([
      'custom-app:install',
      'device:save',
      'custom-app:lifecycle',
    ])
    expect(mockNuiCall).toHaveBeenCalledWith(
      'custom-app:install',
      expect.objectContaining({
        expectedPrice: 500,
        requirePolicy: true,
        ownerResource: 'example',
        imei: '111',
        sessionToken: 'session-111',
      }),
    )
    expect(apps.isInstalled(id)).toBe(true)
  })

  it('keeps rejected purchases uninstalled and exposes the error', async () => {
    vi.useFakeTimers()
    openPhone('111')
    const id = registerPaidApp()
    mockNuiCall.mockResolvedValueOnce({
      success: false,
      error: 'insufficient_funds',
    })
    const apps = useAppStoreStore()
    apps.installApp(id)
    await vi.advanceTimersByTimeAsync(3000)
    expect(apps.isInstalled(id)).toBe(false)
    expect(apps.installErrors[id]).toBe('insufficient_funds')
    expect(mockNuiCall).toHaveBeenCalledOnce()
  })

  it('does not claim a purchase response in another device session', async () => {
    vi.useFakeTimers()
    openPhone('111')
    const id = registerPaidApp()
    let resolvePayment!: (value: { success: boolean }) => void
    mockNuiCall.mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          resolvePayment = resolve
        }),
    )
    const apps = useAppStoreStore()
    apps.installApp(id)
    await vi.advanceTimersByTimeAsync(3000)
    usePhoneStore().endDeviceSession()
    openPhone('222')
    resolvePayment({ success: true })
    await vi.advanceTimersByTimeAsync(0)
    expect(apps.isInstalled(id)).toBe(false)
    expect(mockNuiCall).toHaveBeenCalledOnce()
  })

  it('retains permanent external removals while an owner is stopped', () => {
    openPhone('111', {
      homeLayout: { version: 6 },
      uninstalledApps: ['external-radio'],
    })
    registerApps(['external-radio'])
    expect(
      useAppStoreStore().isInstalled(getPhoneApp('external-radio')!.id),
    ).toBe(false)
  })
})
