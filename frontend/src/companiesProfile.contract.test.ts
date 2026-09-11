import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'

import { describe, expect, it } from 'vitest'

import { configuratorDescriptionKey } from './utils/adminConfiguratorDescription'

const source = (path: string) =>
  readFileSync(new URL(path, import.meta.url), 'utf8').replace(/\r\n/g, '\n')
const server = source('../../sky_phone/source/server/companies.lua')
const configurator = source(
  '../../sky_phone/source/server/phone_configurator.lua',
)
const app = source('./views/apps/CompaniesApp.vue')
const require = createRequire(import.meta.url)
const {
  loadConfiguratorSections,
} = require('../testserver/configurator-fixture.cjs')

describe('Companies profile configuration', () => {
  it('publishes admin images for company profiles, requests and shared cards', () => {
    const sections = loadConfiguratorSections()
    const definitions = sections
      .flatMap((section: { fields: Array<{ path: string }> }) => section.fields)
      .find((field: { path: string }) => field.path === 'Companies.Definitions')
    expect(definitions.structure.entryDefault.CoverUrl).toBe('')
    expect(definitions.structure.entryDefault.LogoUrl).toBeTypeOf('string')
    for (const definition of Object.values(definitions.value) as Array<{
      CoverUrl: string
    }>) {
      expect(definition.CoverUrl).toBe('')
    }
    expect(configurator).toContain('definition.CoverUrl == nil')
    expect(configurator).toContain('definition.CoverUrl = ""')
    expect(server).toContain(
      'coverUrl = definition.CoverUrl ~= "" and definition.CoverUrl or nil',
    )
    expect(server).not.toContain('coverUrl = row.cover_url')
    expect(app).not.toContain('coverMediaId')
    expect(app).not.toContain('chooseCover')
    expect(app).not.toContain('chooseLogo')
    expect(app).not.toContain('logoMediaId')
    expect(server).toContain('logoUrl = definition.LogoUrl')
    expect(server).toContain(
      'companyLogoUrl = definition and definition.LogoUrl or nil',
    )
    expect(server).not.toContain('logo_media_id')
    const easyshare = source('../../sky_phone/source/server/easyshare.lua')
    expect(easyshare).toContain('imageUrl = definition.LogoUrl')
    expect(easyshare).not.toContain('logo_media_id')
  })

  it('keeps admin field guidance specific and localized', () => {
    expect(
      configuratorDescriptionKey('Companies.Definitions.police.Name', ''),
    ).toBe('companyName')
    expect(
      configuratorDescriptionKey('Companies.Definitions.police.CoverUrl', ''),
    ).toBe('companyCover')
    expect(
      configuratorDescriptionKey('Companies.Definitions.police.LogoUrl', ''),
    ).toBe('companyLogo')
    for (const locale of ['en', 'de', 'es']) {
      const text = source(`../../sky_phone/config/locales/${locale}.lua`)
      expect(text).toContain('companyName =')
      expect(text).toContain('companyCover =')
      expect(text).toContain('companyLogo =')
    }
    expect(server).toContain('valid_text(definition.Name, 32, false)')
  })

  it('uses locale-independent opening hour inputs and wraps Discover names', () => {
    const hours = app.slice(
      app.indexOf('class="manager-hours-card"'),
      app.indexOf('@click="saveHours"'),
    )
    expect(hours).not.toContain('type="time"')
    expect(hours.match(/placeholder="HH:MM"/g)).toHaveLength(2)
    expect(
      hours.match(/pattern="\(\[01\]\[0-9\]\|2\[0-3\]\):\[0-5\]\[0-9\]"/g),
    ).toHaveLength(2)
    expect(app).toContain(
      'white-space: normal;\n  overflow-wrap: anywhere;\n  text-overflow: clip;',
    )
  })

  it('enables stock SMS lines once while preserving subsequent admin choices', () => {
    const migration = configurator.slice(
      configurator.indexOf(
        'local function migrate_company_service_line_messaging()',
      ),
      configurator.indexOf('\n\ndefault_config = {}'),
    )
    expect(migration).toContain('service-line-messaging:v3')
    expect(migration).toContain('if completed[1] then\n        return')
    expect(migration).toContain('{ "ambulance", "fire", "mechanic", "taxi" }')
    expect(migration).toContain('line.CanMessage = true')
    expect(migration).toContain('Bridge.Database.Transaction(statements)')
    expect(migration).toContain('apply_stored_row(read_stored_row())')
    expect(configurator).toContain(
      'Bridge.Database.AfterMigration("sky_phone", migrate_company_service_line_messaging)',
    )
  })
})
