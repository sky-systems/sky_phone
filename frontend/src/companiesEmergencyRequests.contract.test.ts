import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const config = readFileSync(
  new URL('../../sky_phone/config/config.lua', import.meta.url),
  'utf8',
).replace(/\r\n/g, '\n')
const companiesServer = readFileSync(
  new URL('../../sky_phone/source/server/companies.lua', import.meta.url),
  'utf8',
).replace(/\r\n/g, '\n')
const configuratorServer = readFileSync(
  new URL(
    '../../sky_phone/source/server/phone_configurator.lua',
    import.meta.url,
  ),
  'utf8',
).replace(/\r\n/g, '\n')
const testServer = readFileSync(
  new URL('../testserver/index.cjs', import.meta.url),
  'utf8',
).replace(/\r\n/g, '\n')

function sourceBlock(source: string, startMarker: string, endMarker: string) {
  const start = source.indexOf(startMarker)
  const end = source.indexOf(endMarker, start)

  expect(start).toBeGreaterThanOrEqual(0)
  expect(end).toBeGreaterThan(start)
  return source.slice(start, end)
}

describe('Companies emergency request contract', () => {
  it('ships non-emergency police assistance as a requestable service', () => {
    const police = sourceBlock(
      config,
      '            police = {',
      '            ambulance = {',
    )
    const mockPolice = sourceBlock(
      testServer,
      'const companyProfiles = [',
      "  {\n    acceptsRequests: false,\n    announcement: null,",
    )

    expect(police).toContain('Emergency = true')
    expect(police).toContain('AcceptsRequests = true')
    expect(police).toContain('Id = "police-assistance"')
    expect(police).toContain('RequestsEnabled = true')
    expect(mockPolice).toContain('acceptsRequests: true')
    expect(mockPolice).toContain("name: 'Los Santos Police Department'")
    expect(mockPolice).toContain("id: 'police-assistance'")
  })

  it('authorizes configured emergency companies through the normal request gates', () => {
    const validation = sourceBlock(
      companiesServer,
      'local function validate_configuration()',
      'local function seed_companies()',
    )
    const payload = sourceBlock(
      companiesServer,
      'local function company_payload(',
      'local function public_company(',
    )
    const createRequest = sourceBlock(
      companiesServer,
      'Bridge.Callbacks.Register("sky_phone:companies:create-request"',
      'Bridge.Callbacks.Register("sky_phone:companies:cancel-request"',
    )
    const updateProfile = sourceBlock(
      companiesServer,
      'Bridge.Callbacks.Register("sky_phone:companies:update-profile"',
      'Bridge.Callbacks.Register("sky_phone:companies:update-hours"',
    )

    expect(validation).not.toContain(
      'definition.Emergency and definition.AcceptsRequests',
    )
    expect(payload).toContain(
      'acceptsRequests = tonumber(row.accepts_requests) == 1,',
    )
    expect(payload).not.toContain('not definition.Emergency')
    expect(createRequest).toContain(
      'if not definition or not definition.Public then',
    )
    expect(createRequest).not.toContain('definition.Emergency')
    expect(createRequest).toContain('SELECT `accepts_requests`')
    expect(createRequest).toContain('AND `requests_enabled` = 1')
    expect(updateProfile).not.toContain('member.definition.Emergency')
  })

  it('migrates existing requestable emergency profiles exactly once', () => {
    const migration = sourceBlock(
      companiesServer,
      'local function migrate_requestable_emergency_companies()',
      'local function tombstone_removed_companies()',
    )
    const refresh = sourceBlock(
      companiesServer,
      'local function refresh_runtime_configuration()',
      '\n\nrefresh_runtime_configuration()',
    )

    expect(migration).toContain(
      'sky-phone:companies:requestable-emergency:v1',
    )
    expect(migration).toContain(
      'if definition.Emergency and definition.AcceptsRequests then',
    )
    expect(migration).toContain('SET `accepts_requests` = 1')
    expect(migration).toContain('INSERT IGNORE INTO `sky_phone_migrations`')
    expect(migration).toContain('Bridge.Database.Transaction(statements)')
    expect(refresh.indexOf('seed_companies()')).toBeLessThan(
      refresh.indexOf('migrate_requestable_emergency_companies()'),
    )
    expect(
      refresh.indexOf('migrate_requestable_emergency_companies()'),
    ).toBeLessThan(refresh.indexOf('tombstone_removed_companies()'))
  })

  it('migrates the existing Phone Configurator police defaults', () => {
    const migration = sourceBlock(
      configuratorServer,
      'local function migrate_police_request_defaults()',
      '\n\ndefault_config = {}',
    )

    expect(migration).toContain('sky-phone:configurator:police-requests:v1')
    expect(migration).toContain('police.AcceptsRequests == false')
    expect(migration).toContain('next(police.Services) == nil')
    expect(migration).toContain(
      'police.AcceptsRequests = defaults.AcceptsRequests',
    )
    expect(migration).toContain('police.Services = copy_value(defaults.Services)')
    expect(migration).toContain('SET `config_payload` = ?')
    expect(migration).toContain('`revision` = `revision` + 1')
    expect(migration).toContain('INSERT IGNORE INTO `sky_phone_migrations`')
    expect(migration).toContain('Bridge.Database.Transaction(statements)')
    expect(migration).toContain('apply_stored_row(read_stored_row())')
    expect(migration).toContain('apply_runtime_configuration()')
    expect(configuratorServer).toContain(
      'Bridge.Database.AfterMigration("sky_phone", migrate_police_request_defaults)',
    )
  })
})
