import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

function source(path: string): string {
  return readFileSync(new URL(path, import.meta.url), 'utf8').replace(
    /\r\n/g,
    '\n',
  )
}

function sourceBlock(
  value: string,
  startMarker: string,
  endMarker: string,
): string {
  const start = value.indexOf(startMarker)
  const end = value.indexOf(endMarker, start)

  expect(start).toBeGreaterThanOrEqual(0)
  expect(end).toBeGreaterThan(start)
  return value.slice(start, end)
}

const companiesServer = source('../../sky_phone/source/server/companies.lua')
const messagesServer = source('../../sky_phone/source/server/messages.lua')
const databaseMigration = source('../../sky_phone/source/server/db_migrate.lua')
const configDefaults = source(
  '../../sky_phone/source/shared/config_default.lua',
)
const messagesApp = source('./views/apps/MessagesApp.vue')
const phoneFallbacks = source('./stores/phone.ts')
const locales = ['en', 'de', 'es'].map((locale) =>
  source(`../../sky_phone/config/locales/${locale}.lua`),
)

describe('Companies service-line message routing contract', () => {
  it('enables the police service line and persists an indexed route channel', () => {
    const police = sourceBlock(
      configDefaults,
      '            police = {',
      '            ambulance = {',
    )
    const schema = sourceBlock(
      databaseMigration,
      '        name = "sky_phone_company_requests",',
      '        name = "sky_phone_company_request_reads",',
    )

    expect(police).toContain('Number = "911"')
    expect(police).toContain('CanMessage = true')
    expect(schema).toContain(
      "name = \"channel\", type = \"ENUM('app','service_line') NOT NULL DEFAULT 'app'\"",
    )
    expect(schema).toContain(
      'name = "idx_sky_phone_company_requests_service_line"',
    )
  })

  it('resolves short service numbers before the normal SIM-number path', () => {
    const resolver = sourceBlock(
      messagesServer,
      'local function resolve_message_recipient(value)',
      '\n\nlocal function shared_contact',
    )
    const send = sourceBlock(
      messagesServer,
      'Bridge.Callbacks.Register("sky_phone:messages:send"',
      '\n\nend)',
    )

    expect(resolver).toContain('SkyPhoneCompanies.GetServiceLine(value)')
    expect(resolver).toContain('return service_line.number, service_line')
    expect(messagesServer.match(/resolve_message_recipient\(/g)?.length).toBe(4)
    expect(send).toContain('service_line_text_only')
    expect(send).toContain('SkyPhoneCompanies.RouteServiceLineMessage')
    expect(send.indexOf('RouteServiceLineMessage')).toBeLessThan(
      send.indexOf('SELECT s.`id`, s.`phone_number`'),
    )
  })

  it('atomically mirrors inbound SMS into one active company request', () => {
    const route = sourceBlock(
      companiesServer,
      'function SkyPhoneCompanies.RouteServiceLineMessage(source, data)',
      'Bridge.Callbacks.Register("sky_phone:companies:create-request"',
    )

    expect(route).toContain('current_device(source, false)')
    expect(route).toContain('service_line.canMessage')
    expect(route).toContain('UPDATE `sky_phone_sims`')
    expect(route).toContain("`channel` = 'service_line'")
    expect(route).toContain('AND NOT EXISTS (')
    expect(route).toContain('INSERT INTO `sky_phone_company_request_messages`')
    expect(route).toContain('INSERT INTO `sky_phone_sms_messages`')
    expect(route).toContain('Bridge.Database.Transaction(statements)')
    expect(route).toContain('emit_request_change(row, true, true, source)')
    expect(route).toContain('"sky_phone:companies:notification"')
  })

  it('mirrors authorized company replies back to the customer SMS thread', () => {
    const sendMessage = sourceBlock(
      companiesServer,
      'Bridge.Callbacks.Register("sky_phone:companies:send-message"',
      'Bridge.Callbacks.Register("sky_phone:companies:claim-request"',
    )

    expect(sendMessage).toContain('access.row.channel == "service_line"')
    expect(
      sendMessage.match(/INSERT INTO `sky_phone_sms_messages`/g)?.length,
    ).toBe(2)
    expect(sendMessage).toContain("message.`sender_type` = 'customer'")
    expect(sendMessage).toContain("message.`sender_type` = 'company'")
    expect(sendMessage).toContain('"sky_phone:messages:changed"')
    expect(sendMessage).toContain('"sky_phone:messages:new"')
  })

  it('keeps service-line composition text-only in every shipped locale', () => {
    expect(messagesApp).toContain(
      "() => activeContact.value?.source === 'company'",
    )
    expect(messagesApp).toContain(
      'activeCanMessage && !activeServiceLine && attachmentMenuOpen',
    )
    expect(messagesApp).toContain('v-if="!activeServiceLine"')
    expect(messagesApp).toContain('v-else-if="!activeServiceLine"')
    expect(messagesApp).toContain("'service_line_text_only'")
    expect(phoneFallbacks).toContain('service_line_text_only:')
    for (const locale of locales) {
      expect(locale).toContain('service_line_text_only =')
    }
  })
})
