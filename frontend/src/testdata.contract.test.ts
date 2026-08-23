import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const readResourceFile = (path: string) =>
  readFileSync(new URL(`../../sky_phone/${path}`, import.meta.url), 'utf8')

const config = readResourceFile('config/config.lua')
const testData = readResourceFile('source/server/testdata.lua')

describe('test data seeding contracts', () => {
  it('keeps test data disabled while retaining the development phone command', () => {
    expect(config).toContain('DevelopmentCommand = true')
    expect(config).toContain(
      'Enabled = false, -- development/test servers only',
    )
  })

  it('refreshes the test-data command when its runtime configuration changes', () => {
    expect(testData).toContain('local function refresh_test_data_command()')
    expect(testData).toContain(
      'active_test_data_command = Config.TestData.Enabled and Config.TestData.Command or nil',
    )
    expect(testData).toContain(
      'AddEventHandler("sky_phone:configurator:serverUpdated", refresh_test_data_command)',
    )
    expect(testData).not.toContain('RegisterCommand(Config.TestData.Command')
  })

  it('moves an existing player SIM before attaching it to the selected phone', () => {
    expect(testData).toContain('local function move_sim_to_device')
    expect(testData).toContain(
      'SET `sim_id` = NULL WHERE `sim_id` = ? AND `imei` <> ?',
    )
    expect(testData).toContain(
      'SET `sim_id` = ? WHERE `imei` = ? AND `sim_id` IS NULL',
    )
    expect(testData).toContain(
      'local previous_imei = move_sim_to_device(sim.id, imei)',
    )
    expect(testData).toContain(
      'restore_sim_attachment(sim.id, imei, previous_imei)',
    )
  })

  it('derives distinct DarkChat identifiers from each account', () => {
    expect(testData).toContain(
      'local function darkchat_identifiers(account_id)',
    )
    expect(testData).toContain(
      'local user_dark_id, user_invite_code = darkchat_identifiers(account_id)',
    )
    expect(testData).toContain(
      'local bot_dark_id, bot_invite_code = darkchat_identifiers(bot_id)',
    )
    expect(testData).not.toContain("'DARK0000000001'")
    expect(testData).not.toContain("'INV00000001'")
  })

  it('loads the persisted Flare match before inserting its test message', () => {
    const matchLookup = testData.indexOf(
      'SELECT `id` FROM `sky_phone_flare_matches`',
    )
    const messageInsert = testData.indexOf(
      'INSERT INTO `sky_phone_flare_messages`',
    )

    expect(matchLookup).toBeGreaterThan(-1)
    expect(messageInsert).toBeGreaterThan(matchLookup)
    expect(testData).toContain(
      'stable_uuid("sky_phone:testdata:flare:message:" .. match_id)',
    )
  })
})
