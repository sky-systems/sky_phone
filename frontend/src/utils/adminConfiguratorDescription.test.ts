import { describe, expect, it } from 'vitest'

import type { AdminConfiguratorStructure } from '@/types/admin'

import {
  configuratorDescriptionKey,
  configuratorPathName,
  describeConfiguratorValue,
} from './adminConfiguratorDescription'

describe('admin configurator descriptions', () => {
  it('selects specific descriptions before generic value descriptions', () => {
    expect(configuratorDescriptionKey('Bridge.CallbackTimeout', 15000)).toBe(
      'milliseconds',
    )
    expect(configuratorDescriptionKey('Media.RequestTimeoutMs', 10000)).toBe(
      'milliseconds',
    )
    expect(configuratorDescriptionKey('Radio.AllowedJobs', [])).toBe('access')
    expect(configuratorDescriptionKey('FiveManage.ApiKey', '')).toBe(
      'credential',
    )
  })

  it('describes structured values from their schema', () => {
    const vector: AdminConfiguratorStructure = {
      kind: 'vector',
      vectorType: 'vector3',
    }
    const table: AdminConfiguratorStructure = {
      fields: {},
      kind: 'table',
    }
    expect(configuratorDescriptionKey('Location', {}, vector)).toBe(
      'coordinates',
    )
    expect(configuratorDescriptionKey('Settings', {}, table)).toBe('table')
  })

  it('passes a readable field name to the localized template', () => {
    const translate = (key: string, params?: Record<string, string>) =>
      `${key}:${params?.name}`
    expect(
      describeConfiguratorValue(
        translate,
        'CustomApps.MaximumStorageBytesPerApp',
        262144,
      ),
    ).toBe('configurator.descriptions.byteLimit:Maximum Storage Bytes Per App')
    expect(
      describeConfiguratorValue(translate, 'Radio.AllowedJobs[2]', 'police'),
    ).toBe('configurator.descriptions.access:Allowed Jobs #2')
  })

  it('humanizes subtab keys', () => {
    expect(configuratorPathName('ExternalPingResources')).toBe(
      'External Ping Resources',
    )
  })
})
