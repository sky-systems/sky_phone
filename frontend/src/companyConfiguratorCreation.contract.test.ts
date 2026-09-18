import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

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
const englishLocale = readFileSync(
  new URL('../../sky_phone/config/locales/en.lua', import.meta.url),
  'utf8',
)
const germanLocale = readFileSync(
  new URL('../../sky_phone/config/locales/de.lua', import.meta.url),
  'utf8',
)
const spanishLocale = readFileSync(
  new URL('../../sky_phone/config/locales/es.lua', import.meta.url),
  'utf8',
)

describe('company configurator creation contract', () => {
  it('publishes complete defaults for newly added company definitions', () => {
    expect(configuratorServer).toContain(
      'local function company_definition_entry_default(company_id, configuration)',
    )
    expect(configuratorServer).toContain(
      'local function next_available_company_service_number(configuration)',
    )
    expect(configuratorServer).toContain(
      'entryDefault = company_definition_entry_default()',
    )
    expect(configuratorServer).toContain('Routing = "round_robin"')
    expect(configuratorServer).toContain('RequestsEnabled = true')
  })

  it('validates the candidate runtime config before encoding or writing SQL', () => {
    const save = configuratorServer.slice(
      configuratorServer.indexOf('function SkyPhoneConfigurator.Save('),
    )
    const validation = save.indexOf(
      'SkyPhoneCompanies.ValidateConfiguration(candidate_config)',
    )
    const encoding = save.indexOf(
      'local config_encoded = encode_payload(next_config, "config")',
    )
    const update = save.indexOf('UPDATE `%s`')

    expect(validation).toBeGreaterThanOrEqual(0)
    expect(validation).toBeLessThan(encoding)
    expect(validation).toBeLessThan(update)
    expect(save).toContain(
      'return { success = false, error = "invalid_company_configuration" }',
    )
  })

  it('validates into isolated registries before replacing the live company state', () => {
    expect(companiesServer).toContain(
      'function SkyPhoneCompanies.ValidateConfiguration(configuration)',
    )
    expect(companiesServer).toContain(
      'local validated, validation_error = validate_configuration(configuration)',
    )
    expect(companiesServer).toContain('definitions = validated.definitions')
    expect(companiesServer).toContain(
      'definition_ids = validated.definition_ids',
    )
  })

  it('localizes rejected company configurations in every shipped locale', () => {
    for (const locale of [englishLocale, germanLocale, spanishLocale]) {
      expect(locale).toContain('invalid_company_configuration =')
    }
  })

  it('repairs company rows created by the legacy blank schema before Companies starts', () => {
    const migration = configuratorServer.slice(
      configuratorServer.indexOf(
        'local function migrate_blank_company_definitions()',
      ),
      configuratorServer.indexOf(
        'local function migrate_police_request_defaults()',
      ),
    )
    const blankRegistration = configuratorServer.indexOf(
      'Bridge.Database.AfterMigration("sky_phone", migrate_blank_company_definitions)',
    )
    const policeRegistration = configuratorServer.indexOf(
      'Bridge.Database.AfterMigration("sky_phone", migrate_police_request_defaults)',
    )

    expect(migration).toContain(
      'sky-phone:configurator:company-definition-defaults:v1',
    )
    expect(migration).toContain('company_definition_entry_default(')
    expect(migration).toContain('Bridge.Database.Transaction(statements)')
    expect(migration).toContain('SET `config_payload` = ?')
    expect(migration).toContain('`revision` = `revision` + 1')
    expect(blankRegistration).toBeGreaterThanOrEqual(0)
    expect(blankRegistration).toBeLessThan(policeRegistration)
  })

  it('enables persisted police service-line messaging before Companies starts', () => {
    const migration = configuratorServer.slice(
      configuratorServer.indexOf(
        'local function migrate_police_service_line_messaging()',
      ),
      configuratorServer.indexOf('\n\ndefault_config = {}'),
    )
    const policeRegistration = configuratorServer.indexOf(
      'Bridge.Database.AfterMigration("sky_phone", migrate_police_request_defaults)',
    )
    const messageRegistration = configuratorServer.indexOf(
      'Bridge.Database.AfterMigration("sky_phone", migrate_police_service_line_messaging)',
    )

    expect(migration).toContain(
      'sky-phone:configurator:service-line-messaging:v2',
    )
    expect(migration).toContain('line.CanMessage ~= true')
    expect(migration).toContain('line.CanMessage = true')
    expect(migration).toContain('Bridge.Database.Transaction(statements)')
    expect(migration).toContain('SET `config_payload` = ?')
    expect(migration).toContain('`revision` = `revision` + 1')
    expect(migration).toContain('apply_stored_row(read_stored_row())')
    expect(migration).toContain('apply_runtime_configuration()')
    expect(messageRegistration).toBeGreaterThan(policeRegistration)
    expect(companiesServer).not.toContain(
      'enables messaging without a virtual service-line message router',
    )
  })
})
