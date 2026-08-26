import { describe, expect, it } from 'vitest'

import type { AdminConfiguratorStructure } from '@/types/admin'
import {
  blankFromConfiguratorStructure,
  createMutableTableEntry,
} from '@/utils/adminConfiguratorDefaults'

describe('admin configurator defaults', () => {
  it('creates a usable company draft from its key and the server defaults', () => {
    const entryDefault = {
      AcceptsRequests: true,
      Category: 'public_services',
      Job: '',
      LogoUrl: 'https://picsum.photos/seed/companies-new-logo/180/180',
      Name: '',
      ServiceLine: {
        Number: '500',
        Routing: 'round_robin',
      },
      Services: [
        {
          Description: '',
          Id: '',
          Price: '',
          RequestsEnabled: true,
          Title: '',
        },
      ],
    }
    const structure: AdminConfiguratorStructure = {
      entryDefault,
      fields: {},
      kind: 'table',
      mutableKeys: true,
      template: {
        fields: {
          Job: { kind: 'value', valueType: 'string' },
          Name: { kind: 'value', valueType: 'string' },
        },
        kind: 'table',
      },
    }

    expect(
      createMutableTableEntry(
        structure,
        'Companies.Definitions',
        'pizza_palace',
      ),
    ).toEqual({
      AcceptsRequests: true,
      Category: 'public_services',
      Job: 'pizza_palace',
      LogoUrl: 'https://picsum.photos/seed/companies-pizza_palace-logo/180/180',
      Name: 'Pizza Palace',
      ServiceLine: {
        Number: '500',
        Routing: 'round_robin',
      },
      Services: [
        {
          Description: '',
          Id: 'pizza_palace',
          Price: '',
          RequestsEnabled: true,
          Title: 'Pizza Palace',
        },
      ],
    })
    expect(entryDefault).toMatchObject({
      Job: '',
      Name: '',
      Services: [{ Id: '', Title: '' }],
    })
  })

  it('allocates distinct service numbers for multiple unsaved companies', () => {
    const structure: AdminConfiguratorStructure = {
      entryDefault: {
        Job: '',
        LogoUrl: '',
        Name: '',
        ServiceLine: { Number: '500' },
      },
      fields: {},
      kind: 'table',
      mutableKeys: true,
    }
    const existing = {
      pizzeria: { ServiceLine: { Number: '500' } },
      restaurant: { ServiceLine: { Number: '501' } },
    }

    expect(
      createMutableTableEntry(
        structure,
        'Companies.Definitions',
        'bakery',
        existing,
      ),
    ).toMatchObject({ ServiceLine: { Number: '502' } })
  })

  it('keeps generic mutable tables on their schema-derived blank value', () => {
    const structure: AdminConfiguratorStructure = {
      fields: {},
      kind: 'table',
      mutableKeys: true,
      template: { kind: 'value', valueType: 'boolean' },
    }

    expect(createMutableTableEntry(structure, 'FeatureFlags', 'example')).toBe(
      false,
    )
  })

  it('preserves required nested list fields in schema-derived rows', () => {
    const structure: AdminConfiguratorStructure = {
      fields: {
        jobs: {
          fields: {
            police: { kind: 'value', valueType: 'boolean' },
          },
          kind: 'table',
          mutableKeys: true,
          template: { kind: 'value', valueType: 'boolean' },
        },
        range: {
          items: [
            { kind: 'value', valueType: 'number' },
            { kind: 'value', valueType: 'number' },
          ],
          kind: 'list',
          template: { kind: 'value', valueType: 'number' },
        },
      },
      kind: 'table',
    }

    expect(blankFromConfiguratorStructure(structure)).toEqual({
      jobs: { police: false },
      range: [0, 0],
    })
  })
})
