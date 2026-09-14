import { createPinia, setActivePinia } from 'pinia'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { usePhoneStore } from '@/stores/phone'
import { nuiCall } from '@/utils/nui'
import { faceIdErrorKey } from '@/utils/face-id'

vi.mock('@/utils/nui', () => ({
  nuiCall: vi.fn(),
}))

const mockNuiCall = vi.mocked(nuiCall)

describe('phone passcode store', () => {
  it.each(['unlock', 'enroll'] as const)(
    'shows a useful mask error for Face ID %s without changing security',
    async (action) => {
      const phone = usePhoneStore()
      phone.security = {
        enabled: true,
        length: 4,
        lockedUntil: 0,
        faceIdEnabled: action === 'unlock',
      }
      const before = { ...phone.security }
      mockNuiCall.mockResolvedValueOnce({
        success: false,
        error: 'face_id_masked',
      })
      const response =
        action === 'unlock'
          ? await phone.unlockWithFaceId()
          : await phone.setFaceId(true, '1234')
      expect(response.success).toBe(false)
      expect(phone.security).toEqual(before)
      expect(phone.t(faceIdErrorKey(response.error))).toBe(
        'Remove your mask to use Face ID, or enter your passcode.',
      )
    },
  )
  it('enrolls Face ID using the PIN and accepts only the returned server state', async () => {
    const phone = usePhoneStore()
    phone.security = { enabled: true, length: 4, lockedUntil: 0 }
    mockNuiCall.mockResolvedValueOnce({
      success: false,
      error: 'invalid_passcode',
    })
    await phone.setFaceId(true, '0000')
    expect(phone.security.faceIdEnabled).toBeUndefined()
    const security = { ...phone.security, faceIdEnabled: true }
    mockNuiCall.mockResolvedValueOnce({ success: true, data: { security } })
    await phone.setFaceId(true, '1234')
    expect(phone.security.faceIdEnabled).toBe(true)
    expect(mockNuiCall).toHaveBeenLastCalledWith('security:set-face-id', {
      enabled: true,
      passcode: '1234',
    })
  })

  it('asks the server to recognize the player without sending an owner identifier', async () => {
    mockNuiCall.mockResolvedValueOnce({
      success: false,
      error: 'face_id_not_recognized',
    })
    const response = await usePhoneStore().unlockWithFaceId()
    expect(mockNuiCall).toHaveBeenCalledWith('security:face-id-unlock')
    expect(response.success).toBe(false)
  })

  it.each(['unlock', 'enroll'] as const)(
    'discards a late Face ID %s result from a closed device session',
    async (action) => {
      const phone = usePhoneStore()
      phone.deviceSessionToken = 'old-session'
      let resolve!: (result: Awaited<ReturnType<typeof nuiCall>>) => void
      mockNuiCall.mockReturnValueOnce(
        new Promise((done) => {
          resolve = done
        }),
      )
      const pending =
        action === 'unlock'
          ? phone.unlockWithFaceId()
          : phone.setFaceId(true, '1234')
      phone.deviceSessionToken = 'new-session'
      resolve({
        success: true,
        data: {
          security: {
            enabled: true,
            length: 4,
            lockedUntil: 0,
            faceIdEnabled: true,
          },
        },
      })
      expect((await pending).success).toBe(false)
      expect(phone.security.faceIdEnabled).toBeFalsy()
    },
  )

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
