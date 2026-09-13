import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { defaultMapPercentToWorld } from '@/features/map/defaultMapGeometry'
import type { CityWarnArea, CityWarnAreaType } from '@/types/citywarn'
import {
  cityWarnColorStyle,
  cityWarnMapArea,
  cityWarnMapPosition,
  DEFAULT_CITYWARN_COLORS,
  parseCityWarnColors,
  parseCityWarnMapBlip,
} from './citywarnPresentation'

const area: CityWarnArea = {
  type: 'radius',
  centerX: 100,
  centerY: 200,
  radius: 800,
  label: 'Test area',
}

describe('CityWarn map presentation', () => {
  it('uses distinct category colors matching the shipped Lua defaults', () => {
    const config = readFileSync(
      new URL('../../../sky_phone/config/config.lua', import.meta.url),
      'utf8',
    )
    expect(new Set(Object.values(DEFAULT_CITYWARN_COLORS)).size).toBe(6)
    for (const [category, color] of Object.entries(DEFAULT_CITYWARN_COLORS))
      expect(config).toContain(`${category} = "${color}"`)
  })

  it('accepts configured hex colors and falls back per category for invalid input', () => {
    expect(
      parseCityWarnColors({
        police: '#AABBCC',
        fire: 'transparent',
        medical: null,
      }),
    ).toEqual({ ...DEFAULT_CITYWARN_COLORS, police: '#AABBCC' })
  })

  it.each([
    ...Object.values(DEFAULT_CITYWARN_COLORS),
    '#ffffff',
    '#000000',
    '#ffff00',
    '#777777',
  ])('keeps text readable on %s without color-mix', (color) => {
    const style = cityWarnColorStyle(color)
    const rgb = [1, 3, 5]
      .map((i) => parseInt(color.slice(i, i + 2), 16) / 255)
      .map((c) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4))
    const luminance = rgb[0]! * 0.2126 + rgb[1]! * 0.7152 + rgb[2]! * 0.0722
    const contrast =
      style['--category-foreground'] === '#ffffff'
        ? 1.05 / (luminance + 0.05)
        : (luminance + 0.05) / 0.05
    expect(contrast).toBeGreaterThanOrEqual(4.5)
    expect(Object.values(style).join(' ')).not.toContain('color-mix')
  })

  it.each([
    { x: 0, y: 0 },
    { x: 100, y: 200 },
    { x: 4704.5, y: -5139.09 },
  ])(
    'places mainland and island markers in the same coordinate system as the images: %o',
    (point) => {
      const style = cityWarnMapPosition({
        ...area,
        centerX: point.x,
        centerY: point.y,
      })!
      const world = defaultMapPercentToWorld({
        x: parseFloat(style.left!) / 100,
        y: parseFloat(style.top!) / 100,
      })
      expect(world.x).toBeCloseTo(point.x)
      expect(world.y).toBeCloseTo(point.y)
    },
  )

  it.each<CityWarnAreaType>(['radius', 'district', 'city'])(
    'uses the configured GTA radius for %s warnings instead of their notification area',
    (type) => {
      for (const configuredRadius of [1, 100, 250.5, 50000]) {
        const warningArea = { ...area, type }
        const style = cityWarnMapArea(warningArea, {
          radiusEnabled: true,
          radius: configuredRadius,
        })!
        const left = parseFloat(style.left!) / 100
        const top = parseFloat(style.top!) / 100
        const width = parseFloat(style.width!) / 100
        const height = parseFloat(style.height!) / 100
        const east = defaultMapPercentToWorld({ x: left + width / 2, y: top })
        const north = defaultMapPercentToWorld({ x: left, y: top - height / 2 })
        expect(east.x - warningArea.centerX!).toBeCloseTo(configuredRadius)
        expect(north.y - warningArea.centerY!).toBeCloseTo(configuredRadius)
        expect(style).not.toHaveProperty('inset')
      }
    },
  )

  it.each([
    undefined,
    null,
    {},
    { radius: 0 },
    { radius: 50001 },
    { radius: NaN },
    { radius: Infinity },
    { radius: '250' },
  ])('matches native defaults for missing or invalid config: %o', (value) => {
    expect(parseCityWarnMapBlip(value)).toEqual({
      radiusEnabled: true,
      radius: 100,
    })
  })

  it('accepts fractional radii and preserves an explicitly disabled radius', () => {
    const settings = parseCityWarnMapBlip({
      radiusEnabled: false,
      radius: 250.5,
    })
    expect(settings).toEqual({ radiusEnabled: false, radius: 250.5 })
    for (const type of ['radius', 'district', 'city'] as const) {
      expect(cityWarnMapArea({ ...area, type }, settings)).toBeNull()
      expect(cityWarnMapPosition({ ...area, type })).not.toBeNull()
    }
  })

  it('does not invent coverage for legacy unlocated warnings', () => {
    expect(cityWarnMapPosition({ ...area, centerX: null })).toBeNull()
    for (const type of ['radius', 'district', 'city'] as const) {
      expect(
        cityWarnMapArea(
          { ...area, type, centerX: null },
          parseCityWarnMapBlip(null),
        ),
      ).toBeNull()
    }
  })
})
