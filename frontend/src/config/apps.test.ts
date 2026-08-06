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
    expect(PHONE_APPS.find((app) => app.id === 'snake')).toMatchObject({
      dockOrder: null,
      gridOrder: 11,
      labelKey: 'Apps.snake.name',
      route: '/apps/snake',
    })
    expect(PHONE_APPS.find((app) => app.id === 'memory')).toMatchObject({
      dockOrder: null,
      gridOrder: 12,
      labelKey: 'Apps.memory.name',
      route: '/apps/memory',
    })
    expect(PHONE_APPS.find((app) => app.id === 'number-merge')).toMatchObject({
      dockOrder: null,
      gridOrder: 13,
      labelKey: 'Apps.numberMerge.name',
      route: '/apps/number-merge',
    })
    expect(
      PHONE_APPS.filter((app) => app.dockOrder !== null)
        .sort((a, b) => (a.dockOrder ?? 0) - (b.dockOrder ?? 0))
        .map((app) => app.id),
    ).toEqual(['phone', 'calculator', 'camera', 'clock'])
  })
})
