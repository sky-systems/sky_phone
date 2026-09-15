import { describe, expect, it } from 'vitest'

import type { AdminConfiguratorStructure } from '@/types/admin'

import {
  configuratorDescriptionKey,
  configuratorPathName,
  describeConfiguratorValue,
} from './adminConfiguratorDescription'

describe('admin configurator descriptions', () => {
  it('explains model-specific Face ID masks and texture wildcards', () => {
    expect(configuratorDescriptionKey('Security.FaceIdMaskWhitelist', [])).toBe(
      'faceIdMaskWhitelist',
    )
    for (const key of ['Model', 'Drawable', 'Texture']) {
      for (const entry of ['[1]', '.1']) {
        expect(
          configuratorDescriptionKey(
            `Security.FaceIdMaskWhitelist${entry}.${key}`,
            1,
          ),
        ).toBe(`faceIdMask${key}`)
      }
    }
  })
  it('explains both service-line routing modes and their timing controls', () => {
    expect(
      configuratorDescriptionKey(
        'Companies.Definitions.police.ServiceLine.Routing',
        'ring_all',
      ),
    ).toBe('companyCallRouting')
    expect(
      configuratorDescriptionKey('Companies.CallRouting.MaxAttempts', 3),
    ).toBe('companyCallAttempts')
    expect(
      configuratorDescriptionKey('Companies.CallRouting.RingSeconds', 10),
    ).toBe('companyCallRingSeconds')
  })
  it('explains the shared category colors for both maps and the app', () => {
    expect(configuratorDescriptionKey('CityWarn.CategoryColors', {})).toBe(
      'citywarnCategoryColor',
    )
    expect(
      configuratorDescriptionKey('CityWarn.CategoryColors.medical', '#059669'),
    ).toBe('citywarnCategoryColor')
  })
  it('explains the CityWarn native settings and fixed radius separately', () => {
    for (const key of [
      'Sprite',
      'Display',
      'ShortRange',
      'CategoryId',
      'CategoryName',
      'GroupByCategory',
      'RadiusEnabled',
      'Radius',
    ]) {
      expect(configuratorDescriptionKey(`CityWarn.Blip.${key}`, 10)).toBe(
        `citywarnBlip${key}`,
      )
    }
  })
  it('selects specific descriptions before generic value descriptions', () => {
    expect(configuratorDescriptionKey('CrewLink.PingCooldownSeconds', 5)).toBe(
      'crewlinkPingCooldown',
    )
    for (const key of [
      'Enabled',
      'Sprite',
      'PingSprite',
      'CategoryId',
      'CategoryName',
      'Scale',
    ]) {
      expect(configuratorDescriptionKey(`CrewLink.Blip.${key}`, 1)).toBe(
        `crewlinkBlip${key}`,
      )
    }
    for (const key of ['Enabled', 'DefaultKey']) {
      expect(
        configuratorDescriptionKey(`CrewLink.QuickPing.${key}`, 'NUMPAD5'),
      ).toBe(`crewlinkQuickPing${key}`)
    }
    expect(configuratorDescriptionKey('Garage.System', 'msk')).toBe(
      'garageSystem',
    )
    expect(configuratorDescriptionKey('Bridge.CallbackTimeout', 15000)).toBe(
      'milliseconds',
    )
    expect(configuratorDescriptionKey('Media.RequestTimeoutMs', 10000)).toBe(
      'milliseconds',
    )
    expect(configuratorDescriptionKey('Radio.AllowedJobs', [])).toBe('access')
    expect(configuratorDescriptionKey('FiveManage.ApiKey', '')).toBe(
      'fiveManageApiKey',
    )
  })

  it.each([
    ['Import.Enabled', 'importEnabled'],
    ['Import.Websites', 'importWebsites'],
    ['Import.Websites[1]', 'importSource'],
    ['Import.Websites[2].Adapter', 'importAdapter'],
    ['Import.Websites[2].ApiKey', 'importApiKey'],
    ['Import.Websites[1].Path', 'importPath'],
    ['Import.Websites[1].AllowedMediaHosts', 'importHosts'],
    ['Import.Websites[1].AllowedMediaHosts[2]', 'importHosts'],
    ['Media.Import.Websites[1].MediaTypes[1]', 'importMediaTypes'],
    ['Import.Websites.2.ManifestUrl', 'importManifestUrl'],
    ['Import.Websites[2].Auth.TokenConvar', 'importAuthConvar'],
    ['Import.Websites[2].RequiredAce', 'importRequiredAce'],
    ['Wallpaper.CustomUploadEnabled', 'wallpaperImport'],
    ['Photo.Quality', 'photoQuality'],
    ['Video.BitrateKbps', 'videoBitrate'],
  ])('explains media setup for %s', (path, key) => {
    expect(configuratorDescriptionKey(path, '')).toBe(key)
  })

  it('retains generic help for unrelated fields and import timeouts', () => {
    expect(configuratorDescriptionKey('CustomApp.ApiKey', '')).toBe(
      'credential',
    )
    expect(
      configuratorDescriptionKey('Import.Websites[1].RequestTimeoutMs', 10000),
    ).toBe('milliseconds')
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

it('explains the integrated voice controls alongside the provider and speaker switch', () => {
  expect(configuratorDescriptionKey('Calls.VoiceProvider', 'pma')).toBe(
    'callsVoiceProvider',
  )
  expect(configuratorDescriptionKey('Speaker.Enabled', true)).toBe(
    'phoneSpeaker',
  )
})

it('explains the independent default-on player and radio restrictions', () => {
  expect(configuratorDescriptionKey('Phone.BlockWhenDead', true)).toBe(
    'phoneBlockWhenDead',
  )
  expect(configuratorDescriptionKey('Phone.BlockWhenCuffed', true)).toBe(
    'phoneBlockWhenCuffed',
  )
  expect(configuratorDescriptionKey('Radio.RequirePhoneItem', true)).toBe(
    'radioRequirePhoneItem',
  )
})
