import { createPinia, setActivePinia } from 'pinia'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { usePhoneStore } from '@/stores/phone'
import { nuiCall } from '@/utils/nui'

vi.mock('@/utils/nui', () => ({
  nuiCall: vi.fn(),
}))

const mockNuiCall = vi.mocked(nuiCall)

describe('phone passcode store', () => {
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

  it('stores the server security state after setting a six digit passcode', async () => {
    mockNuiCall.mockResolvedValueOnce({
      data: {
        security: { enabled: true, length: 6, lockedUntil: 0 },
      },
      success: true,
    })

    const phone = usePhoneStore()
    const response = await phone.setPasscode('123456')

    expect(response.success).toBe(true)
    expect(phone.security).toEqual({
      enabled: true,
      length: 6,
      lockedUntil: 0,
    })
    expect(mockNuiCall).toHaveBeenCalledWith('security:set-passcode', {
      passcode: '123456',
    })
  })

  it('keeps the configured state after a rejected unlock attempt', async () => {
    mockNuiCall.mockResolvedValueOnce({
      error: 'invalid_passcode',
      success: false,
    })

    const phone = usePhoneStore()
    phone.security = { enabled: true, length: 4, lockedUntil: 0 }
    await phone.unlockWithPasscode('9999')

    expect(phone.security).toEqual({
      enabled: true,
      length: 4,
      lockedUntil: 0,
    })
  })

  it('clears the security state after disabling the passcode', async () => {
    mockNuiCall.mockResolvedValueOnce({
      data: {
        security: { enabled: false, length: null, lockedUntil: 0 },
      },
      success: true,
    })

    const phone = usePhoneStore()
    phone.security = { enabled: true, length: 4, lockedUntil: 0 }
    await phone.disablePasscode('1234')

    expect(phone.security.enabled).toBe(false)
    expect(phone.security.length).toBeNull()
  })
})
