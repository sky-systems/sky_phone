import { describe, expect, it } from 'vitest'
import { PHONE_APPS } from './apps'
describe('app registry', () => {
  it('has unique ids and routes with the reference dock order', () => {
    expect(new Set(PHONE_APPS.map((app) => app.id)).size).toBe(
      PHONE_APPS.length,
    )
    expect(PHONE_APPS.every((app) => app.route === `/apps/${app.id}`)).toBe(
      true,
    )
    expect(PHONE_APPS.every((app) => app.iconImage.endsWith('.webp'))).toBe(
      true,
    )
    expect(PHONE_APPS.find((app) => app.id === 'mail')).toMatchObject({
      gridOrder: 3,
      labelKey: 'Apps.mail.name',
      route: '/apps/mail',
    })
    expect(
      PHONE_APPS.filter((app) => app.dockOrder !== null)
        .sort((a, b) => (a.dockOrder ?? 0) - (b.dockOrder ?? 0))
        .map((app) => app.id),
    ).toEqual(['app-store', 'calculator', 'camera', 'clock'])
  })
})
