import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

function source(path: string): string {
  return readFileSync(new URL(path, import.meta.url), 'utf8')
}

const config = source('../../sky_phone/config/config.lua')
const configDefault = source('../../sky_phone/source/shared/config_default.lua')
const framework = source('../../sky_phone/source/bridge/server/framework.lua')
const qbox = source('../../sky_phone/source/bridge/server/frameworks/qbox.lua')
const configurator = source(
  '../../sky_phone/source/server/phone_configurator.lua',
)
const configuratorFixture = source('../testserver/configurator-fixture.cjs')

describe('fixed server permissions', () => {
  it('defines every protected phone capability only in config.lua', () => {
    expect(config).toContain('Config.CommandPermissions = {')
    for (const permission of [
      'phonepanel',
      'phonetestdata',
      'fliptokverify',
      'picstagramverify',
      'picstagramadmin',
    ]) {
      expect(config).toMatch(new RegExp(`\\s${permission} = \\{`))
    }
    expect(config).not.toContain('AdminGroups =')
    expect(configDefault).not.toContain('Config.PhoneConfigurator')
    expect(configDefault).not.toContain('Config.CommandPermissions')
    expect(configDefault).not.toContain('Config.CustomTones')
    expect(configDefault).not.toContain('AdminGroups =')
  })

  it('keeps fixed permissions outside SQL and removes legacy group fields', () => {
    expect(configurator).toContain('key ~= "CommandPermissions"')
    expect(configurator).toContain(
      'if key ~= "CommandPermissions" and key ~= "CustomTones" then',
    )
    expect(configuratorFixture).toContain('delete config.CommandPermissions')
    expect(configuratorFixture).toContain('delete config.CustomTones')
    for (const path of [
      'AdminPanel.AdminGroups',
      'TestData.AdminGroups',
      'FlipTok.AdminGroups',
      'Picstagram.AdminGroups',
    ]) {
      expect(configurator).toContain(`["${path}"] = true`)
    }
    expect(configurator).toContain(
      'SKY PHONE: IN-GAME CONFIGURATOR ENABLED',
    )
    expect(configurator).toContain(
      '^1 Changes to config.lua and media.lua are ignored in this mode,^0',
    )
    expect(configurator).toContain(
      '^1 Edit them in /phonepanel > Phone Configurator and save your changes.^0',
    )
    expect(configurator).toContain(
      '^1 Config.PhoneConfigurator, Config.CommandPermissions, Config.CustomTones.^0',
    )
  })

  it('authorizes Qbox through ACE before retaining framework group support', () => {
    expect(framework).toContain(
      'local groups = Config.CommandPermissions[permission]',
    )
    expect(qbox).toContain(
      'if IsPlayerAceAllowed(tostring(source), group) then',
    )
    expect(qbox.indexOf('IsPlayerAceAllowed')).toBeLessThan(
      qbox.indexOf('exports.qbx_core:HasGroup'),
    )
  })

  it('uses stable permission identifiers for every protected operation', () => {
    const expectations = [
      ['../../sky_phone/source/server/admin.lua', 'phonepanel'],
      ['../../sky_phone/source/server/testdata.lua', 'phonetestdata'],
      ['../../sky_phone/source/server/fliptok.lua', 'fliptokverify'],
      ['../../sky_phone/source/server/picstagram.lua', 'picstagramverify'],
      ['../../sky_phone/source/server/picstagram.lua', 'picstagramadmin'],
    ] as const

    for (const [path, permission] of expectations) {
      expect(source(path)).toContain(
        `Bridge.Framework.HasPermission(source, "${permission}")`,
      )
    }
  })
})
