import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const saveDeviceNamespace = vi.fn()

vi.mock('@/stores/phone', () => ({
  usePhoneStore: () => ({ saveDeviceNamespace }),
}))

import { useAppAuthStore } from '@/stores/app-auth'

describe('app auth store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    saveDeviceNamespace.mockReset()
  })

  it('keeps each app session independent', () => {
    const auth = useAppAuthStore()
    auth.hydrate(
      {
        accountEmail: 'demo@ifruit.com',
        signedIn: ['citymarkt', 'feather'],
        version: 1,
      },
      'demo@ifruit.com',
    )

    auth.signOut('citymarkt')

    expect(auth.isSignedIn('citymarkt')).toBe(false)
    expect(auth.isSignedIn('feather')).toBe(true)
    expect(saveDeviceNamespace).toHaveBeenLastCalledWith('appAuth', {
      accountEmail: 'demo@ifruit.com',
      signedIn: ['feather'],
      version: 1,
    })
  })

  it('persists the SkyPic session independently', () => {
    const auth = useAppAuthStore()
    auth.hydrate(null, 'demo@ifruit.com')

    auth.signIn('skypic', 'demo@ifruit.com')

    expect(auth.isSignedIn('skypic')).toBe(true)
    expect(auth.isSignedIn('feather')).toBe(false)
    expect(saveDeviceNamespace).toHaveBeenLastCalledWith('appAuth', {
      accountEmail: 'demo@ifruit.com',
      signedIn: ['skypic'],
      version: 1,
    })

    auth.signOut('skypic')
    expect(auth.isSignedIn('skypic')).toBe(false)
  })

  it('does not restore sessions belonging to another iFruit account', () => {
    const auth = useAppAuthStore()
    auth.hydrate(
      {
        accountEmail: 'old@ifruit.com',
        signedIn: ['citymarkt'],
        version: 1,
      },
      'new@ifruit.com',
    )

    expect(auth.isSignedIn('citymarkt')).toBe(false)
  })
})
