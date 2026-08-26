import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'

import { describe, expect, it } from 'vitest'

type ConfiguratorField = {
  label: string
  path: string
  structure?: ConfiguratorStructure
  type: string
  value: unknown
}

type ConfiguratorStructure = {
  entryDefault?: unknown
  entries?: Array<{ structure: ConfiguratorStructure }>
  fields?: Record<string, ConfiguratorStructure>
  items?: ConfiguratorStructure[]
  keyType?: 'number' | 'string'
  kind: string
  mutableKeys?: boolean
  template?: ConfiguratorStructure
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
  it('exposes every SQL-managed config.lua root through the full live preview', () => {
    const sections = loadConfiguratorSections()
    const fields = sections.flatMap((section) => section.fields)
    const roots = [
      ...configSource.matchAll(/^\s{0,4}Config\.([A-Za-z0-9_]+)\s*=/gm),
    ]
      .map((match) => match[1])
      .filter(
        (root) =>
          root !== 'Media' &&
          root !== 'PhoneConfigurator' &&
          root !== 'CommandPermissions',
      )

    expect(sections).toHaveLength(46)
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
    const companyJobs = fields.find(
      (field) => field.path === 'Companies.Definitions',
    )
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
    expect(companyJobs?.label).toBe('Jobs')
    expect(companyJobs?.structure).toMatchObject({
      entryDefault: {
        AcceptsRequests: true,
        Category: 'public_services',
        Job: '',
        ServiceLine: {
          Number: '500',
          Routing: 'round_robin',
        },
        Services: [
          {
            Id: '',
            RequestsEnabled: true,
            Title: '',
          },
        ],
      },
      fields: {
        ambulance: { kind: 'table' },
        police: { kind: 'table' },
      },
      kind: 'table',
      mutableKeys: true,
      template: { kind: 'table' },
    })
    expect(
      garage?.structure?.fields?.VehicleImages.fields?.ModelNames.kind,
    ).toBe('map')
  })

  it('exposes the requestable police assistance defaults', () => {
    const companyJobs = loadConfiguratorSections()
      .flatMap((section) => section.fields)
      .find((field) => field.path === 'Companies.Definitions')
    const police = (
      companyJobs?.value as Record<string, Record<string, unknown>> | undefined
    )?.police

    expect(police).toMatchObject({
      AcceptsRequests: true,
      Emergency: true,
      Services: [
        {
          Id: 'police-assistance',
          RequestsEnabled: true,
        },
      ],
    })
    expect(
      companyJobs?.structure?.fields?.police.fields?.Services,
    ).toMatchObject({
      items: [
        {
          fields: {
            Id: { kind: 'value', valueType: 'string' },
            RequestsEnabled: { kind: 'value', valueType: 'boolean' },
          },
          kind: 'table',
        },
      ],
      kind: 'list',
      template: {
        fields: {
          Id: { kind: 'value', valueType: 'string' },
          RequestsEnabled: { kind: 'value', valueType: 'boolean' },
        },
        kind: 'table',
      },
    })
  })

  it('allows custom jobs in locked radio channel entries', () => {
    const radio = loadConfiguratorSections()
      .flatMap((section) => section.fields)
      .find((field) => field.path === 'Radio')
    const lockedChannels = radio?.structure?.fields?.LockedChannels
    const jobs = lockedChannels?.items?.[0]?.fields?.jobs

    expect(jobs).toMatchObject({
      fields: {
        ambulance: { kind: 'value', valueType: 'boolean' },
        police: { kind: 'value', valueType: 'boolean' },
      },
      kind: 'table',
      mutableKeys: true,
      template: { kind: 'value', valueType: 'boolean' },
    })
    expect(lockedChannels?.template?.fields?.jobs).toMatchObject({
      kind: 'table',
      mutableKeys: true,
      template: { kind: 'value', valueType: 'boolean' },
    })
  })

  it('publishes fixed schemas for every empty configurable collection', () => {
    const fields = loadConfiguratorSections().flatMap(
      (section) => section.fields,
    )
    const root = (path: string) =>
      fields.find((field) => field.path === path)?.structure

    expect(root('Music')?.fields?.Tracks).toMatchObject({
      items: [],
      kind: 'list',
      template: {
        fields: {
          Artist: { kind: 'value', valueType: 'string' },
          Id: { kind: 'value', valueType: 'string' },
          Title: { kind: 'value', valueType: 'string' },
        },
        kind: 'table',
      },
    })
    expect(root('FlipTok')?.fields?.MusicTracks.template).toMatchObject({
      fields: { Url: { kind: 'value', valueType: 'string' } },
      kind: 'table',
    })
    expect(root('Payphones')?.fields?.CustomLocations.template).toEqual({
      kind: 'vector',
      vectorType: 'vector4',
    })
    expect(root('CrewLink')?.fields?.ExternalPingResources).toMatchObject({
      fields: {},
      kind: 'table',
      mutableKeys: true,
      template: { kind: 'value', valueType: 'boolean' },
    })
    expect(root('CustomApps')?.fields?.TrustedAdapters).toMatchObject({
      fields: {},
      kind: 'table',
      mutableKeys: true,
      template: { kind: 'value', valueType: 'boolean' },
    })
    expect(
      root('Garage')?.fields?.VehicleImages.fields?.ModelNames,
    ).toMatchObject({
      entries: [],
      keyType: 'number',
      kind: 'map',
      template: { kind: 'value', valueType: 'string' },
    })
    expect(
      root('Companies.Definitions')?.fields?.ambulance.fields?.Services,
    ).toMatchObject({
      items: [],
      kind: 'list',
      template: {
        fields: {
          Id: { kind: 'value', valueType: 'string' },
          RequestsEnabled: { kind: 'value', valueType: 'boolean' },
        },
        kind: 'table',
      },
    })
  })
})
