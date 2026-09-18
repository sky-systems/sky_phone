import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const readResourceFile = (path: string) =>
  readFileSync(new URL(`../../sky_phone/${path}`, import.meta.url), 'utf8')

describe('LB runtime compatibility contracts', () => {
  it('routes legacy call and SMS actions through Sky Phone', () => {
    const callsClient = readResourceFile('source/client/calls.lua')
    const phoneBridge = readResourceFile('source/bridge/phones/client/lb.lua')
    const callsServer = readResourceFile('source/server/calls.lua')
    const phoneUi = readFileSync(new URL('./App.vue', import.meta.url), 'utf8')
    const customAppFrame = readFileSync(
      new URL('./components/CustomAppFrame.vue', import.meta.url),
      'utf8',
    )

    expect(phoneBridge).toContain(
      'SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "CreateCall", create_call)',
    )
    expect(callsClient).toContain(
      'Bridge.Callbacks.Trigger("sky_phone:calls:dial"',
    )
    expect(callsServer).toContain(
      'SkyPhoneCompanies.GetServiceLineForCompany(data.company)',
    )
    expect(phoneBridge).toContain(
      'SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "CreateSMS", create_sms)',
    )
    expect(phoneBridge).toContain('type = "compat:open-messages"')
    expect(phoneUi).toContain("event.data?.type === 'compat:open-messages'")
    expect(phoneUi).toContain('messages.openThread(data.phoneNumber)')
    expect(customAppFrame).toContain("message.action === 'createCall'")
    expect(customAppFrame).toContain("message.action === 'createSMS'")
  })

  it('redirects PicChat phone identity to the Sky SIM table without deleting orphaned data', () => {
    const manifest = readResourceFile('fxmanifest.lua')
    const migration = readResourceFile(
      'source/server/lb_app_compat_migration.lua',
    )

    expect(manifest).toContain("'source/server/lb_app_compat_migration.lua'")
    expect(
      manifest.indexOf("'source/server/lb_app_compat_migration.lua'"),
    ).toBeGreaterThan(manifest.indexOf("'source/server/testdata.lua'"))
    expect(migration).toContain('"lbpicchat_logged_in"')
    expect(migration).toContain('"phone_phones"')
    expect(migration).toContain('"sky_phone_sims"')
    expect(migration).toContain('DROP FOREIGN KEY')
    expect(migration).toContain('ON DELETE CASCADE ON UPDATE CASCADE')
    expect(migration).toContain('Legacy data was preserved')
    expect(migration).toContain('FROM `INFORMATION_SCHEMA`.`KEY_COLUMN_USAGE`')
    expect(migration).not.toMatch(/KEY_COLUMN_USAGE`\s+keys/i)
    expect(migration).toContain(
      'xpcall(migrate_picchat_phone_reference, debug.traceback)',
    )
    expect(migration).toContain('Sky Phone startup will continue')
    expect(migration).not.toMatch(/DELETE\s+FROM\s+/i)
  })
})
