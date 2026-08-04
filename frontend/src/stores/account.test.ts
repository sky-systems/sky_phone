import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useAccountStore } from '@/stores/account'
import type { AccountDevice } from '@/types/device'
import { nuiCall } from '@/utils/nui'

vi.mock('@/utils/nui', () => ({
  nuiCall: vi.fn(),
}))

const mockNuiCall = vi.mocked(nuiCall)
const devices: AccountDevice[] = [
  {
    created_at: '2026-08-04 10:00:00',
    current: true,
    device_name: 'iFruit Phone',
    imei: '356938035643809',
    updated_at: '2026-08-04 10:00:00',
  },
]

describe('account store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    mockNuiCall.mockReset()
  })

  it('links the whole device after account login', async () => {
    mockNuiCall.mockResolvedValueOnce({
      data: { devices, email: 'alex@ifruit.com' },
      success: true,
    })

    const account = useAccountStore()
    const response = await account.login('alex', 'roleplay')

    expect(response.success).toBe(true)
    expect(account.email).toBe('alex@ifruit.com')
    expect(account.devices).toEqual(devices)
    expect(mockNuiCall).toHaveBeenCalledWith('account:login', {
      email: 'alex',
      password: 'roleplay',
    })
  })

  it('keeps the existing account state when credentials fail', async () => {
    mockNuiCall.mockResolvedValueOnce({
      error: 'invalid_credentials',
      success: false,
    })

    const account = useAccountStore()
    account.hydrate({ devices, email: 'alex@ifruit.com' })
    await account.login('alex', 'wrong-password')

    expect(account.email).toBe('alex@ifruit.com')
    expect(account.devices).toEqual(devices)
  })

  it('clears account state after a factory reset', async () => {
    mockNuiCall.mockResolvedValueOnce({ success: true })

    const account = useAccountStore()
    account.hydrate({ devices, email: 'alex@ifruit.com' })
    const success = await account.factoryReset()

    expect(success).toBe(true)
    expect(account.email).toBe('')
    expect(account.devices).toEqual([])
    expect(mockNuiCall).toHaveBeenCalledWith('device:factory-reset')
  })
})
