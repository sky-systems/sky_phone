import { createPinia, setActivePinia } from 'pinia'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { usePhoneStore } from '@/stores/phone'
import { nuiCall, type NuiResponse } from '@/utils/nui'

vi.mock('@/utils/nui', () => ({
  nuiCall: vi.fn(),
}))

const mockNuiCall = vi.mocked(nuiCall)

function deferredResponse<T>(): {
  promise: Promise<NuiResponse<T>>
  resolve: (response: NuiResponse<T>) => void
} {
  let resolve!: (response: NuiResponse<T>) => void
  const promise = new Promise<NuiResponse<T>>((next) => {
    resolve = next
  })
  return { promise, resolve }
}

function openPhone(imei: string, token: string, revision: number): void {
  usePhoneStore().open({
    device: {
      data: { settings: { payload: {}, revision } },
      imei,
      name: `Phone ${imei}`,
      sim: null,
    },
    token,
  })
}

describe('phone device persistence scope', () => {
  beforeEach(() => {
    vi.stubGlobal('window', {
      matchMedia: vi.fn(() => ({ matches: false })),
    })
    setActivePinia(createPinia())
    mockNuiCall.mockReset()
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('does not apply a late save response to a newer device session', async () => {
    const stale = deferredResponse<{ revision: number }>()
    mockNuiCall.mockReturnValueOnce(stale.promise)
    const phone = usePhoneStore()
    openPhone('111', 'session-a', 2)

    phone.saveDeviceNamespace('settings', { value: 'old' })
    await Promise.resolve()
    expect(mockNuiCall).toHaveBeenCalledWith('device:save', {
      imei: '111',
      namespace: 'settings',
      payload: { value: 'old' },
      revision: 2,
      sessionToken: 'session-a',
    })

    openPhone('222', 'session-b', 7)
    stale.resolve({ data: { revision: 3 }, success: true })
    await stale.promise
    await Promise.resolve()

    expect(phone.device?.imei).toBe('222')
    expect(phone.deviceRevisions.settings).toBe(7)
  })

  it('drops queued writes from an obsolete device generation', async () => {
    const first = deferredResponse<{ revision: number }>()
    mockNuiCall.mockReturnValueOnce(first.promise)
    const phone = usePhoneStore()
    openPhone('111', 'session-a', 0)

    phone.saveDeviceNamespace('settings', { order: 1 })
    phone.saveDeviceNamespace('settings', { order: 2 })
    await Promise.resolve()
    openPhone('222', 'session-b', 0)
    first.resolve({ data: { revision: 1 }, success: true })
    await first.promise
    await Promise.resolve()
    await Promise.resolve()

    expect(mockNuiCall).toHaveBeenCalledTimes(1)
  })

  it('flushes every queued write after a normal visibility close', async () => {
    const first = deferredResponse<{ revision: number }>()
    mockNuiCall
      .mockReturnValueOnce(first.promise)
      .mockResolvedValueOnce({ data: { revision: 2 }, success: true })
    const phone = usePhoneStore()
    openPhone('111', 'session-a', 0)

    phone.saveDeviceNamespace('settings', { order: 1 })
    phone.saveDeviceNamespace('settings', { order: 2 })
    await Promise.resolve()
    phone.close()
    const flushed = phone.flushDevicePersistence()

    first.resolve({ data: { revision: 1 }, success: true })
    await flushed

    expect(mockNuiCall).toHaveBeenCalledTimes(2)
    expect(mockNuiCall).toHaveBeenLastCalledWith('device:save', {
      imei: '111',
      namespace: 'settings',
      payload: { order: 2 },
      revision: 1,
      sessionToken: 'session-a',
    })
    expect(phone.deviceRevisions.settings).toBe(2)
  })

  it('keeps queued writes scoped across a same-session bootstrap update', async () => {
    const first = deferredResponse<{ revision: number }>()
    mockNuiCall
      .mockReturnValueOnce(first.promise)
      .mockResolvedValueOnce({ data: { revision: 2 }, success: true })
    const phone = usePhoneStore()
    openPhone('111', 'session-a', 0)

    phone.saveDeviceNamespace('settings', { order: 1 })
    phone.saveDeviceNamespace('settings', { order: 2 })
    await Promise.resolve()
    first.resolve({ data: { revision: 1 }, success: true })
    await first.promise
    await Promise.resolve()
    openPhone('111', 'session-a', 1)
    await phone.flushDevicePersistence()

    expect(mockNuiCall).toHaveBeenCalledTimes(2)
    expect(phone.deviceRevisions.settings).toBe(2)
  })

  it('waits for writes queued while a persistence flush is in progress', async () => {
    const first = deferredResponse<{ revision: number }>()
    const queuedDuringFlush = deferredResponse<{ revision: number }>()
    mockNuiCall
      .mockReturnValueOnce(first.promise)
      .mockReturnValueOnce(queuedDuringFlush.promise)
    const phone = usePhoneStore()
    openPhone('111', 'session-a', 0)

    phone.saveDeviceNamespace('settings', { order: 1 })
    await Promise.resolve()
    let flushCompleted = false
    const flushed = phone.flushDevicePersistence().then(() => {
      flushCompleted = true
    })
    phone.saveDeviceNamespace('widgets', { order: 2 })
    await Promise.resolve()

    first.resolve({ data: { revision: 1 }, success: true })
    await first.promise
    await Promise.resolve()
    expect(flushCompleted).toBe(false)

    queuedDuringFlush.resolve({ data: { revision: 1 }, success: true })
    await flushed

    expect(mockNuiCall).toHaveBeenCalledTimes(2)
    expect(phone.deviceRevisions.widgets).toBe(1)
  })

  it('marks setup complete only after the settings save is acknowledged', async () => {
    const completion = deferredResponse<{ revision: number }>()
    mockNuiCall.mockReturnValueOnce(completion.promise)
    const phone = usePhoneStore()
    phone.open({
      device: {
        data: {
          settings: {
            payload: {
              settings: { setupCompleted: false, setupStep: 9 },
              version: 1,
            },
            revision: 3,
          },
        },
        imei: '111',
        name: 'Phone 111',
        sim: null,
      },
      token: 'session-a',
    })

    const completed = phone.completeSetup()
    await Promise.resolve()

    expect(phone.preferences.settings.setupCompleted).toBe(false)
    completion.resolve({ data: { revision: 4 }, success: true })

    await expect(completed).resolves.toBe(true)
    expect(phone.preferences.settings.setupCompleted).toBe(true)
    expect(phone.deviceRevisions.settings).toBe(4)
  })

  it('keeps setup open when the completion save is rejected', async () => {
    mockNuiCall.mockResolvedValueOnce({
      error: 'request_failed',
      success: false,
    })
    const phone = usePhoneStore()
    phone.open({
      device: {
        data: {
          settings: {
            payload: {
              settings: { setupCompleted: false, setupStep: 9 },
              version: 1,
            },
            revision: 3,
          },
        },
        imei: '111',
        name: 'Phone 111',
        sim: null,
      },
      token: 'session-a',
    })

    await expect(phone.completeSetup()).resolves.toBe(false)
    expect(phone.preferences.settings.setupCompleted).toBe(false)
    expect(phone.deviceRevisions.settings).toBe(3)
  })
})
