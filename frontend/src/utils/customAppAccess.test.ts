import { describe, expect, it } from 'vitest'
import { normalizeExternalPhoneApp } from '@/stores/app-catalog'
import {
  getCustomAppAccessRequest,
  isCustomAppJobAllowed,
} from './customAppAccess'

function app(store: unknown = {}) {
  return normalizeExternalPhoneApp({
    id: 'dispatch',
    name: 'Dispatch',
    ownerResource: 'dispatch',
    ui: 'https://cfx-nui-dispatch/ui/index.html',
    icon: 'https://cfx-nui-dispatch/ui/icon.png',
    store,
  })!
}
describe('custom app access', () => {
  it('requires a server policy for costs and job restrictions', () => {
    expect(
      getCustomAppAccessRequest(app({ price: 500 }), '111', 'token'),
    ).toMatchObject({ requirePolicy: true, imei: '111', sessionToken: 'token' })
    expect(
      getCustomAppAccessRequest(
        app({ allowedJobs: { police: 0 } }),
        '111',
        'token',
      ).requirePolicy,
    ).toBe(true)
    expect(getCustomAppAccessRequest(app(), '111', 'token').requirePolicy).toBe(
      false,
    )
  })
  it('uses minimum grades and gives the deny list precedence', () => {
    const restricted = app({
      allowedJobs: { police: 2 },
      disabledJobs: { ambulance: 0 },
    })
    expect(
      isCustomAppJobAllowed(restricted, { name: 'police', grade: 2 }),
    ).toBe(true)
    expect(
      isCustomAppJobAllowed(restricted, { name: 'police', grade: 1 }),
    ).toBe(false)
    expect(isCustomAppJobAllowed(restricted, undefined)).toBe(false)
    expect(
      isCustomAppJobAllowed(app({ disabledJobs: { police: 0 } }), {
        name: 'police',
        grade: 99,
      }),
    ).toBe(false)
  })
  it('preserves vendor metadata and safe gradients but rejects unsafe URLs', () => {
    const registered = normalizeExternalPhoneApp({
      ...app(),
      icon: app().iconImage,
      iconBackground: 'linear-gradient(45deg,#ff0000,#0000ff)',
      store: {
        price: 500,
        size: 1024,
        rating: 4.5,
        screenshots: [
          'https://apps.example.com/one.png',
          'javascript:alert(1)',
        ],
        banner: { imageUrl: 'https://apps.example.com/banner.png' },
      },
    })!
    expect(registered.iconBackground).toBe(
      'linear-gradient(45deg,#ff0000,#0000ff)',
    )
    expect(registered.store).toMatchObject({
      price: 500,
      rating: 4.5,
      size: 1024,
      screenshots: ['https://apps.example.com/one.png'],
    })
  })
  it('accepts function-only catalog entries without an iframe URL', () => {
    const registered = normalizeExternalPhoneApp({
      ...app(),
      icon: app().iconImage,
      launchMode: 'action',
      ui: '',
    })
    expect(registered?.launchMode).toBe('action')
    expect(registered?.ui).toBe('')
  })
})
