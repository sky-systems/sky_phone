import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const client = readFileSync(
  new URL('../../sky_phone/source/client/nui_server_bridge.lua', import.meta.url),
  'utf8',
).replace(/\r\n/g, '\n')
const companiesServer = readFileSync(
  new URL('../../sky_phone/source/server/companies.lua', import.meta.url),
  'utf8',
).replace(/\r\n/g, '\n')
const callsServer = readFileSync(
  new URL('../../sky_phone/source/server/calls.lua', import.meta.url),
  'utf8',
).replace(/\r\n/g, '\n')
const companiesStore = readFileSync(
  new URL('./stores/companies.ts', import.meta.url),
  'utf8',
).replace(/\r\n/g, '\n')
const apostrophe = String.fromCharCode(39)
const quote = String.fromCharCode(34)

function sourceBlock(source: string, startMarker: string, endMarker: string) {
  const start = source.indexOf(startMarker)
  const end = source.indexOf(endMarker, start)

  expect(start).toBeGreaterThanOrEqual(0)
  expect(end).toBeGreaterThan(start)
  return source.slice(start, end)
}

describe('Companies outbound service-line call contract', () => {
  it('exposes the dedicated callback through the NUI client bridge', () => {
    expect(client).toMatch(/companies\s*=\s*\[\[[^\]]*dial-service-line/)
  })

  it('accepts only a target number and derives the company from the live server member', () => {
    const callback = sourceBlock(
      companiesServer,
      `Bridge.Callbacks.Register(${quote}sky_phone:companies:dial-service-line${quote}`,
      '\n\nlocal function company_mutation_payload',
    )
    const storeAction = sourceBlock(
      companiesStore,
      'async dialServiceLine(',
      '\n    async mutateRequest(',
    )

    expect(callback).toContain(
      `local phone_number = type(data) == ${quote}table${quote} and data.phoneNumber or nil`,
    )
    expect(callback).toContain('local member = call_member(source)')
    expect(callback).toContain(
      'SkyPhoneCalls.StartCompanyCall(source, member.company_id, phone_number)',
    )
    expect(callback).not.toContain('data.companyId')
    expect(callback).not.toContain('data.callerNumber')
    expect(storeAction).toContain(
      `${apostrophe}companies:dial-service-line${apostrophe}`,
    )
    expect(storeAction).toContain('{\n        phoneNumber,\n      }')
    expect(storeAction).not.toContain('companyId')
    expect(storeAction).not.toContain('callerNumber')
  })

  it('revalidates call permission and presents the configured service number as caller ID', () => {
    const startCompanyCall = sourceBlock(
      callsServer,
      'function SkyPhoneCalls.StartCompanyCall(',
      `Bridge.Callbacks.Register(${quote}sky_phone:calls:dial${quote}`,
    )

    expect(startCompanyCall).toContain(
      'SkyPhoneCompanies.CanPlaceCompanyCall(source, company_id)',
    )
    expect(startCompanyCall).toContain(
      'SkyPhoneCompanies.GetServiceLineForCompany(company_id)',
    )
    expect(startCompanyCall).toContain(
      'create_terminal_call(scope, number, target, target_status, service_line.number)',
    )
    expect(startCompanyCall).toContain('caller_number = service_line.number')
    expect(startCompanyCall).not.toContain('data.companyId')
    expect(startCompanyCall).not.toContain('data.callerNumber')
  })
})
