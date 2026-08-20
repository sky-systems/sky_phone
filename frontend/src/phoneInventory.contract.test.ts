import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const readResourceFile = (path: string) =>
  readFileSync(new URL(`../../sky_phone/${path}`, import.meta.url), 'utf8')
const readFrontendFile = (path: string) =>
  readFileSync(new URL(path, import.meta.url), 'utf8')

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
    const phoneBridge = readResourceFile('source/bridge/phones/client/lb.lua')

    expect(phoneBridge).toContain(
      'SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "IsOpen"',
    )
    expect(phoneClient).toContain('open = is_open')
    expect(phoneBridge).toContain('return get_phone_state_value("open")')
  })

  it('provides the LB equipped phone number exports from authoritative device state', () => {
    const phoneClient = readResourceFile('source/client/main.lua')
    const phoneServer = readResourceFile('source/server/phone.lua')
    const clientBridge = readResourceFile('source/bridge/phones/client/lb.lua')
    const serverBridge = readResourceFile('source/bridge/phones/server/lb.lua')
    const serverLifecycle = readResourceFile(
      'source/bridge/phones/server/lifecycle.lua',
    )

    expect(clientBridge).toMatch(
      /"GetEquippedPhoneNumber",\s+phone\.GetEquippedPhoneNumber/,
    )
    expect(phoneClient).toContain('return device_payload.device.sim.number')
    expect(phoneClient).toContain(
      'Bridge.Callbacks.Trigger("sky_phone:device:equipped-number", {})',
    )
    expect(phoneServer).toContain(
      'Bridge.Callbacks.Register("sky_phone:device:equipped-number", function(source)',
    )
    expect(phoneServer).toContain(
      'function SkyPhone.GetEquippedPhoneNumber(player)',
    )
    expect(phoneServer).toContain(
      'cache_equipped_phone_number(source, identifier, device.phone_number)',
    )
    expect(phoneServer).toContain(
      'equipped_phone_sources[phone_number] = source',
    )
    const equippedNumberExport = phoneServer.match(
      /function SkyPhone\.GetEquippedPhoneNumber\(player\)([\s\S]*?)\nfunction SkyPhone\.GetSourceFromNumber/,
    )?.[1]
    const equippedNumberResolver = phoneServer.match(
      /local function resolve_equipped_phone_number\(source\)([\s\S]*?)\nfunction SkyPhone\.GetEquippedPhoneNumber/,
    )?.[1]
    expect(equippedNumberExport).toBeDefined()
    expect(equippedNumberResolver).toBeDefined()
    expect(equippedNumberExport).toContain('type(player) == "number"')
    expect(equippedNumberExport).toContain('online_source_for_identifier(player)')
    expect(phoneServer).toContain('Bridge.Inventory.GetSlotsWithItem(source, Config.Phone.Item)')
    expect(phoneServer).toContain('return resolve_equipped_phone_number(player)')
    expect(equippedNumberExport).not.toContain('tonumber(player)')
    expect(equippedNumberExport).not.toContain('equipped_phone_numbers[player]')
    expect(equippedNumberResolver).not.toContain('return cached_number')
    expect(phoneServer).toContain(
      'player_source and resolve_equipped_phone_number(player_source) == normalized',
    )
    expect(serverBridge).toMatch(
      /"GetEquippedPhoneNumber",\s+phone\.GetEquippedPhoneNumber/,
    )
    expect(serverBridge).toMatch(
      /"GetSourceFromNumber",\s+phone\.GetSourceFromNumber/,
    )
    expect(phoneServer).toContain(
      'TriggerEvent("sky_phone:server:phoneNumberChanged", source, phone_number)',
    )
    expect(serverLifecycle).toContain(
      'SkyPhoneCompatibility.EmitServerProviderStop(LB_PROVIDER_NAME)',
    )
    expect(serverLifecycle).toContain(
      'SkyPhoneCompatibility.EmitServerProviderStart(LB_PROVIDER_NAME)',
    )
  })

  it('maps LB client lifecycle and state contracts', () => {
    const phoneClient = readResourceFile('source/client/main.lua')
    const phoneBridge = readResourceFile('source/bridge/phones/client/lb.lua')

    expect(phoneBridge).toContain(
      'SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "ToggleOpen"',
    )
    expect(phoneClient).toContain(
      'local result = Bridge.Callbacks.Trigger("sky_phone:device:open-request", {})',
    )
    expect(phoneClient).toMatch(
      /result\.success ~= true[\s\S]*open_without_focus = false[\s\S]*return false/,
    )
    expect(phoneBridge).toContain(
      'SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "IsPhoneOnScreen"',
    )
    expect(phoneBridge).toContain(
      'SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "IsInCall"',
    )
    expect(phoneBridge).toContain(
      'SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "FormatNumber", client_bridge.FormatNumber)',
    )
    expect(phoneClient).toContain(
      'TriggerEvent("sky_phone:client:phoneNumberChanged", next_number)',
    )
    expect(phoneClient).toContain(
      'TriggerEvent("sky_phone:client:phoneToggled", true)',
    )
    expect(phoneClient).toContain(
      'TriggerEvent("sky_phone:client:phoneToggled", false)',
    )
    expect(phoneBridge).toContain('TriggerEvent("lb-phone:numberChanged", phone_number)')
    expect(phoneBridge).toContain('TriggerEvent("lb-phone:phoneToggled", open)')
  })

  it('keeps vendor contracts outside the phone business core', () => {
    const corePaths = [
      'source/client/main.lua',
      'source/client/camera.lua',
      'source/client/custom_apps.lua',
      'source/server/phone.lua',
      'source/server/sim.lua',
      'source/server/media.lua',
    ]

    for (const path of corePaths) {
      expect(readResourceFile(path)).not.toMatch(
        /lb-phone|17mov|high-phone|qs-smartphone|yseries|SkyPhoneCompatibility/,
      )
    }
  })

  it('maps the LB custom-app delete lifecycle from the App Store to Lua', () => {
    const appStore = readFrontendFile('stores/app-store.ts')
    const customApps = readResourceFile('source/client/custom_apps.lua')
    const compatibility = readResourceFile('source/bridge/phones/shared/lb.lua')

    expect(appStore).toContain("event: 'delete'")
    expect(customApps).toContain('and lifecycle_event ~= "delete"')
    expect(customApps).toContain(
      'invoke_or_defer_hook(app, "onDelete", lifecycle_payload, deferred_hooks)',
    )
    expect(compatibility).toContain('onDelete = app_data.onDelete')
  })

  it('emits exact LB observer events after authoritative state changes', () => {
    const phonePersistence = readResourceFile(
      'source/server/phone_persistence.lua',
    )
    const simServer = readResourceFile('source/server/sim.lua')
    const mediaServer = readResourceFile('source/server/media.lua')
    const phoneBridge = readResourceFile(
      'source/bridge/phones/server/lifecycle.lua',
    )

    expect(simServer).toContain(
      'TriggerEvent("sky_phone:server:phoneNumberGenerated", source, sim.phone_number)',
    )
    expect(phonePersistence).toContain(
      'TriggerEvent("sky_phone:server:factoryReset", source, phone_number)',
    )
    expect(mediaServer).toContain(
      'TriggerEvent("sky_phone:server:galleryMediaDeleted", src, phone_number, deleted_link)',
    )
    expect(phoneBridge).toContain('TriggerEvent("lb-phone:phoneNumberGenerated"')
    expect(phoneBridge).toContain('TriggerEvent("lb-phone:factoryReset"')
    expect(phoneBridge).toContain('TriggerEvent("lb-phone:deletedFromGallery"')
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
})
