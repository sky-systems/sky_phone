import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'

import { describe, expect, it } from 'vitest'

type ConfiguratorField = {
  path: string
  structure?: ConfiguratorStructure
  type: string
  value: unknown
}

type ConfiguratorStructure = {
  entries?: Array<{ structure: ConfiguratorStructure }>
  fields?: Record<string, ConfiguratorStructure>
  items?: ConfiguratorStructure[]
  kind: string
}

type ConfiguratorSection = {
  fields: ConfiguratorField[]
  id: string
  scope: 'config' | 'media'
}

const require = createRequire(import.meta.url)
const { loadConfiguratorSections } = require('./configurator-fixture.cjs') as {
  loadConfiguratorSections: () => ConfiguratorSection[]
}

const configSource = readFileSync(
  new URL('../../sky_phone/config/config.lua', import.meta.url),
  'utf8',
)

function countStructure(structure: ConfiguratorStructure | undefined): number {
  if (!structure) return 1
  if (structure.fields) {
    return Object.values(structure.fields).reduce(
      (total, field) => total + countStructure(field),
      0,
    )
  }
  if (structure.items) {
    return structure.items.reduce(
      (total, item) => total + countStructure(item),
      0,
    )
  }
  if (structure.entries) {
    return structure.entries.reduce(
      (total, entry) => total + countStructure(entry.structure),
      0,
    )
  }
  return 1
}

describe('admin configurator fixture', () => {
  it('exposes every config.lua root through the full live preview', () => {
    const sections = loadConfiguratorSections()
    const fields = sections.flatMap((section) => section.fields)
    const roots = [
      ...configSource.matchAll(/^\s{0,4}Config\.([A-Za-z0-9_]+)\s*=/gm),
    ]
      .map((match) => match[1])
      .filter((root) => root !== 'Media' && root !== 'PhoneConfigurator')

    expect(sections).toHaveLength(45)
    expect(
      fields.reduce(
        (total, field) => total + countStructure(field.structure),
        0,
      ),
    ).toBeGreaterThan(700)
    for (const root of new Set(roots)) {
      expect(
        sections.some(
          (section) =>
            section.id === `config:${root}` ||
            section.fields.some(
              (field) =>
                field.path === root || field.path.startsWith(`${root}.`),
            ),
        ),
        `Missing Config.${root}`,
      ).toBe(true)
    }
  })

  it('preserves numeric Lua map keys and the false keybind option', () => {
    const fields = loadConfiguratorSections().flatMap(
      (section) => section.fields,
    )
    const darkChat = fields.find((field) => field.path === 'DarkChat')
    const phone = fields.find((field) => field.path === 'Phone')
    const companies = fields.find((field) => field.path === 'Companies')
    const garage = fields.find((field) => field.path === 'Garage')
    const timers = (darkChat?.value as Record<string, unknown> | undefined)
      ?.AllowedDisappearTimers

    expect(timers).toMatchObject({
      __skyType: 'map',
      entries: expect.arrayContaining([
        { key: -1, keyType: 'number', value: true },
        { key: 0, keyType: 'number', value: true },
        { key: 604800, keyType: 'number', value: true },
      ]),
    })
    expect(darkChat?.structure?.fields?.AllowedDisappearTimers.kind).toBe('map')
    expect(phone?.structure?.fields?.Keybind.kind).toBe('optionalString')
    expect(companies?.structure?.fields?.Definitions.kind).toBe('table')
    expect(
      garage?.structure?.fields?.VehicleImages.fields?.ModelNames.kind,
    ).toBe('map')
  })
})
