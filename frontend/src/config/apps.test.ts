import { describe, expect, it } from 'vitest'
import { isPhoneAppId, PHONE_APPS } from './apps'
describe('app registry', () => {
  it('has unique ids and routes with the reference dock order', () => {
    expect(new Set(PHONE_APPS.map((app) => app.id)).size).toBe(
      PHONE_APPS.length,
    )
    expect(
      PHONE_APPS.every(
        (app) => app.route === null || app.route === `/apps/${app.id}`,
      ),
    ).toBe(true)
    expect(PHONE_APPS.every((app) => app.iconImage.endsWith('.webp'))).toBe(
      true,
    )
    expect(PHONE_APPS.find((app) => app.id === 'phone')).toMatchObject({
      dockOrder: 0,
      labelKey: 'Apps.phone.name',
      route: '/apps/phone',
    })
    expect(PHONE_APPS.find((app) => app.id === 'mail')).toMatchObject({
      gridOrder: 5,
      labelKey: 'Apps.mail.name',
      route: '/apps/mail',
    })
    expect(PHONE_APPS.find((app) => app.id === 'weather')).toMatchObject({
      gridOrder: 4,
      labelKey: 'Apps.weather.name',
      route: '/apps/weather',
    })
    expect(PHONE_APPS.find((app) => app.id === 'camera')).toMatchObject({
      route: '/apps/camera',
    })
    expect(PHONE_APPS.find((app) => app.id === 'photos')).toMatchObject({
      route: '/apps/photos',
    })
    expect(isPhoneAppId('camera')).toBe(true)
    expect(isPhoneAppId('photos')).toBe(true)
    expect(isPhoneAppId('clock')).toBe(true)
    expect(
      PHONE_APPS.filter((app) => app.dockOrder !== null)
        .sort((a, b) => (a.dockOrder ?? 0) - (b.dockOrder ?? 0))
        .map((app) => app.id),
    ).toEqual(['phone', 'calculator', 'camera', 'clock'])
  })
})
