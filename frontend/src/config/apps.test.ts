import { describe, expect, it } from 'vitest'
import { Newspaper, Siren } from 'lucide-vue-next'

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
    expect(
      PHONE_APPS.every(
        (app) => typeof app.iconImage === 'string' && app.iconImage.length > 0,
      ),
    ).toBe(true)
    expect(PHONE_APPS.find((app) => app.id === 'phone')).toMatchObject({
      dockOrder: 0,
      labelKey: 'Apps.phone.name',
      route: '/apps/phone',
    })
    expect(PHONE_APPS.find((app) => app.id === 'mail')).toMatchObject({
      gridOrder: 6,
      labelKey: 'Apps.mail.name',
      route: '/apps/mail',
    })
    expect(PHONE_APPS.find((app) => app.id === 'weather')).toMatchObject({
      gridOrder: 5,
      labelKey: 'Apps.weather.name',
      route: '/apps/weather',
    })
    expect(PHONE_APPS.find((app) => app.id === 'health')).toMatchObject({
      category: 'utilities',
      gridOrder: 11,
      labelKey: 'Apps.health.name',
      route: '/apps/health',
    })
    expect(isPhoneAppId('health')).toBe(true)
    expect(PHONE_APPS.find((app) => app.id === 'crypto')).toMatchObject({
      category: 'utilities',
      gridOrder: 7,
      labelKey: 'Apps.crypto.name',
      route: '/apps/crypto',
    })
    expect(isPhoneAppId('crypto')).toBe(true)
    expect(PHONE_APPS.find((app) => app.id === 'banking')).toMatchObject({
      gridOrder: 5,
      labelKey: 'Apps.banking.name',
      route: '/apps/banking',
    })
    expect(PHONE_APPS.find((app) => app.id === 'garage')).toMatchObject({
      category: 'utilities',
      gridOrder: 23,
      labelKey: 'Apps.garage.name',
      route: '/apps/garage',
    })
    expect(PHONE_APPS.find((app) => app.id === 'skyride')).toMatchObject({
      category: 'utilities',
      gridOrder: 25,
      labelKey: 'Apps.skyride.name',
      route: '/apps/skyride',
    })
    expect(PHONE_APPS.find((app) => app.id === 'house')).toMatchObject({
      category: 'utilities',
      labelKey: 'Apps.house.name',
      route: '/apps/house',
    })
    expect(PHONE_APPS.find((app) => app.id === 'companies')).toMatchObject({
      category: 'utilities',
      gridOrder: 28,
      labelKey: 'Apps.companies.name',
      route: '/apps/companies',
    })
    expect(PHONE_APPS.find((app) => app.id === 'weazel-news')).toMatchObject({
      category: 'social',
      dockOrder: null,
      gridOrder: 29,
      labelKey: 'Apps.weazelNews.name',
      route: '/apps/weazel-news',
    })
    expect(PHONE_APPS.find((app) => app.id === 'weazel-news')?.icon).toBe(
      Newspaper,
    )
    expect(PHONE_APPS.find((app) => app.id === 'citywarn')).toMatchObject({
      category: 'utilities',
      gridOrder: 30,
      labelKey: 'Apps.citywarn.name',
      route: '/apps/citywarn',
    })
    expect(PHONE_APPS.find((app) => app.id === 'citywarn')?.icon).toBe(Siren)
    expect(isPhoneAppId('citywarn')).toBe(true)
    expect(PHONE_APPS.find((app) => app.id === 'music')).toMatchObject({
      category: 'utilities',
      gridOrder: 26,
      labelKey: 'Apps.music.name',
      route: '/apps/music',
    })
    expect(PHONE_APPS.find((app) => app.id === 'calendar')).toMatchObject({
      gridOrder: 21,
      labelKey: 'Apps.calendar.name',
      route: '/apps/calendar',
    })
    expect(PHONE_APPS.find((app) => app.id === 'radio')).toMatchObject({
      dockOrder: null,
      gridOrder: 21,
      labelKey: 'Apps.radio.name',
      route: '/apps/radio',
    })
    expect(PHONE_APPS.find((app) => app.id === 'snake')).toMatchObject({
      dockOrder: null,
      gridOrder: 12,
      labelKey: 'Apps.snake.name',
      route: '/apps/snake',
    })
    expect(PHONE_APPS.find((app) => app.id === 'memory')).toMatchObject({
      dockOrder: null,
      gridOrder: 13,
      labelKey: 'Apps.memory.name',
      route: '/apps/memory',
    })
    expect(PHONE_APPS.find((app) => app.id === 'number-merge')).toMatchObject({
      dockOrder: null,
      gridOrder: 14,
      labelKey: 'Apps.numberMerge.name',
      route: '/apps/number-merge',
    })
    expect(PHONE_APPS.find((app) => app.id === 'minesweeper')).toMatchObject({
      dockOrder: null,
      gridOrder: 15,
      labelKey: 'Apps.minesweeper.name',
      route: '/apps/minesweeper',
    })
    expect(PHONE_APPS.find((app) => app.id === 'tower-stack')).toMatchObject({
      dockOrder: null,
      gridOrder: 16,
      labelKey: 'Apps.towerStack.name',
      route: '/apps/tower-stack',
    })
    expect(PHONE_APPS.find((app) => app.id === 'sky-flappy')).toMatchObject({
      dockOrder: null,
      gridOrder: 17,
      labelKey: 'Apps.skyFlappy.name',
      route: '/apps/sky-flappy',
    })
    expect(PHONE_APPS.find((app) => app.id === 'neon-drop')).toMatchObject({
      dockOrder: null,
      gridOrder: 18,
      labelKey: 'Apps.neonDrop.name',
      route: '/apps/neon-drop',
    })
    expect(PHONE_APPS.find((app) => app.id === 'citymarkt')).toMatchObject({
      dockOrder: null,
      gridOrder: 19,
      labelKey: 'Apps.citymarkt.name',
      route: '/apps/citymarkt',
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
    expect(isPhoneAppId('skyride')).toBe(true)
    expect(isPhoneAppId('music')).toBe(true)
    expect(isPhoneAppId('companies')).toBe(true)
    expect(isPhoneAppId('weazel-news')).toBe(true)
    expect(PHONE_APPS.find((app) => app.id === 'skypic')).toMatchObject({
      category: 'social',
      dockOrder: null,
      gridOrder: 31,
      labelKey: 'Apps.skypic.name',
      route: '/apps/skypic',
    })
    expect(isPhoneAppId('skypic')).toBe(true)
    expect(
      PHONE_APPS.filter((app) => app.category === 'games').map((app) => app.id),
    ).toEqual([
      'snake',
      'memory',
      'number-merge',
      'minesweeper',
      'tower-stack',
      'sky-flappy',
      'neon-drop',
    ])
    expect(
      PHONE_APPS.filter((app) => app.category === 'social').map(
        (app) => app.id,
      ),
    ).toEqual([
      'weazel-news',
      'picstagram',
      'skypic',
      'feather',
      'fliptok',
      'flare',
      'radio',
      'local-pages',
      'crewlink',
      'phone',
      'darkchat',
      'banking',
      'mail',
    ])
    expect(
      PHONE_APPS.filter((app) => app.dockOrder !== null)
        .sort((a, b) => (a.dockOrder ?? 0) - (b.dockOrder ?? 0))
        .map((app) => app.id),
    ).toEqual(['phone', 'messages', 'camera', 'clock'])
  })
})
