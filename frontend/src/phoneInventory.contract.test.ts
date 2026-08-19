import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const readResourceFile = (path: string) =>
  readFileSync(new URL(`../../sky_phone/${path}`, import.meta.url), 'utf8')

const inventoryAdapters = [
  ['ox', 'source/bridge/server/inventory/ox.lua'],
  ['qb', 'source/bridge/server/inventory/qb.lua'],
  ['lj', 'source/bridge/server/inventory/qb.lua'],
  ['qs', 'source/bridge/server/inventory/qs.lua'],
  ['codem', 'source/bridge/server/inventory/codem.lua'],
  ['core', 'source/bridge/server/inventory/core.lua'],
  ['mf', 'source/bridge/server/inventory/mf.lua'],
  ['smx', 'source/bridge/server/inventory/smx.lua'],
  ['hex', 'source/bridge/server/inventory/esx.lua'],
  ['esx', 'source/bridge/server/inventory/esx.lua'],
] as const

describe('phone inventory contracts', () => {
  it.each(inventoryAdapters)(
    'registers the phone as a usable item through the %s adapter',
    (_inventory, path) => {
      expect(readResourceFile(path)).toContain(
        'function Bridge.Inventory.RegisterUsableItem',
      )
    },
  )

  it('fails startup when the selected inventory cannot register the phone item', () => {
    const phoneServer = readResourceFile('source/server/phone.lua')

    expect(phoneServer).toContain(
      'Bridge.Inventory.RegisterUsableItem(Config.Phone.Item, open_phone)',
    )
    expect(phoneServer).toContain('if not usable_registered then')
  })

  it('auto-detects HEX and limits count-based ESX inventories to metadata-free modes', () => {
    const inventoryBridge = readResourceFile(
      'source/bridge/server/inventory.lua',
    )

    expect(inventoryBridge).toContain(
      'GetResourceState("hex_4_inventory") == "started"',
    )
    expect(inventoryBridge).toContain('configured_inventory = "hex"')
    expect(inventoryBridge).toContain('Config.Phone.Unique ~= false')
    expect(inventoryBridge).toContain('Config.Sim.Enabled ~= false')
  })

  it('provides the LB IsOpen export alias from the authoritative client state', () => {
    const phoneClient = readResourceFile('source/client/main.lua')

    expect(phoneClient).toContain(
      'SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "IsOpen"',
    )
    expect(phoneClient).toContain('return is_open')
  })

  it('opens from a configurable F1 mapping without client-provided device identity', () => {
    const config = readResourceFile('config/config.lua')
    const phoneClient = readResourceFile('source/client/main.lua')
    const phoneServer = readResourceFile('source/server/phone.lua')

    expect(config).toContain('Keybind = "F1"')
    expect(phoneClient).toContain(
      'RegisterKeyMapping("sky_phone_toggle", locale.Controls.OpenPhone, "keyboard", Config.Phone.Keybind)',
    )
    expect(phoneClient).toContain(
      'Bridge.Callbacks.Trigger("sky_phone:device:open-request", {})',
    )
    expect(phoneServer).toContain(
      'Bridge.Callbacks.Register("sky_phone:device:open-request", function(source)',
    )
  })

  it('keeps a server-selected unique handset as the preferred hotkey device', () => {
    const phoneServer = readResourceFile('source/server/phone.lua')

    expect(phoneServer).toContain('local preferred_device_imeis = {}')
    expect(phoneServer).toContain(
      'local preferred_imei = preferred_device_imeis[source]',
    )
    expect(phoneServer).toContain('preferred_device_imeis[source] = imei')
  })

  it('keeps non-unique phones bound to one persistent device per character', () => {
    const phoneServer = readResourceFile('source/server/phone.lua')
    const migration = readResourceFile('source/server/db_migrate.lua')

    expect(phoneServer).toContain('if not unique_phones then')
    expect(phoneServer).toContain('return map_character_device(source, slot)')
    expect(phoneServer).toContain('FROM `sky_phone_character_devices`')
    expect(phoneServer).toContain('WHERE `owner_identifier` = ?')
    expect(migration).toContain('name = "sky_phone_character_devices"')
    expect(migration).toContain('primaryKey = "owner_identifier"')
  })
})
