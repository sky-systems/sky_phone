import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const readResourceFile = (path: string) =>
  readFileSync(
    new URL(`../../sky_phone/${path}`, import.meta.url),
    'utf8',
  ).replace(/\r\n/g, '\n')
const readFrontendFile = (path: string) =>
  readFileSync(new URL(path, import.meta.url), 'utf8')

const inventoryAdapters = [
  ['jaksam', 'source/bridge/server/inventory/jaksam.lua'],
  ['ox', 'source/bridge/server/inventory/ox.lua'],
  ['qb', 'source/bridge/server/inventory/qb.lua'],
  ['lj', 'source/bridge/server/inventory/qb.lua'],
  ['qs', 'source/bridge/server/inventory/qs.lua'],
  ['ps', 'source/bridge/server/inventory/ps.lua'],
  ['codem', 'source/bridge/server/inventory/codem.lua'],
  ['tgiann', 'source/bridge/server/inventory/tgiann.lua'],
  ['core', 'source/bridge/server/inventory/core.lua'],
  ['jpr', 'source/bridge/server/inventory/jpr.lua'],
  ['origen', 'source/bridge/server/inventory/origen.lua'],
  ['ak47', 'source/bridge/server/inventory/ak47.lua'],
  ['one', 'source/bridge/server/inventory/one.lua'],
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
      'Bridge.Inventory.RegisterUsableItem(item_name, function(...)',
    )
    expect(phoneServer).toContain('if Config.Phone.Item == item_name then')
    expect(phoneServer).toContain(
      'if not Bridge.Inventory.RegisterUsableItem(item_name, function(...)',
    )
  })

  it('uses One Inventory slot ids and authoritative slot reads', () => {
    const adapter = readResourceFile(
      'source/bridge/server/inventory/one.lua',
    )

    expect(adapter).toContain('inventory:GetSlotIdsWithItem(')
    expect(adapter).toContain(
      'local normalized = Bridge.Inventory.GetSlot(source, slot_id)',
    )
    expect(adapter).not.toContain('inventory:SearchInventory(')
    expect(adapter).toContain(
      'inventory:SetItemMetadata(source, slot.slot, requested_metadata) == false',
    )
  })

  it('serializes and rate-limits phone bootstrap requests on both sides', () => {
    const phoneClient = readResourceFile('source/client/main.lua')
    const phoneServer = readResourceFile('source/server/phone.lua')

    expect(phoneClient).toContain('local function request_phone_open(')
    expect(phoneClient).toMatch(
      /request_phone_open\(callback_name\)[\s\S]*?open_requested = true[\s\S]*?Bridge\.Callbacks\.Trigger\(callback_name, \{\}\)/,
    )
    expect(phoneClient).toMatch(
      /RegisterNetEvent\("sky_phone:device:error"[\s\S]*?if not is_open then[\s\S]*?open_requested = false/,
    )
    expect(phoneServer).toContain('local phone_open_in_progress = {}')
    expect(phoneServer).toContain(
      'SkyPhone.AllowOperation(source, "phone_open", request_limit, 60)',
    )
    expect(phoneServer).toContain(
      'pcall(perform_phone_open, source, used_item)',
    )
  })

  it('auto-detects registered inventories and forces metadata-free adapters into compatible modes', () => {
    const inventoryBridge = readResourceFile(
      'source/bridge/server/inventory.lua',
    )

    expect(inventoryBridge).toContain(
      '{ name = "hex", resource = "hex_4_inventory", framework = "esx", metadata = false },',
    )
    expect(inventoryBridge).toContain(
      'GetResourceState(adapter.resource) == "started"',
    )
    expect(inventoryBridge).toContain('configured_inventory = adapter.name')
    expect(inventoryBridge).toContain('selected_adapter.metadata == false')
    expect(inventoryBridge).toContain('Config.Phone.Unique = false')
    expect(inventoryBridge).toContain('Config.Sim.Enabled = false')
    expect(inventoryBridge).toContain(
      'does not support item metadata; unique phones and physical SIM cards were disabled automatically',
    )
    expect(inventoryBridge).toContain(
      'AddEventHandler("sky_phone:configurator:serverUpdated"',
    )
    expect(inventoryBridge).not.toContain(
      'cannot store unique phone or physical SIM metadata',
    )
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
    expect(equippedNumberExport).toContain(
      'online_source_for_identifier(player)',
    )
    expect(phoneServer).toContain(
      'Bridge.Inventory.GetSlotsWithItem(source, Config.Phone.Item)',
    )
    expect(phoneServer).toContain(
      'return resolve_equipped_phone_number(player)',
    )
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
      'local result = Bridge.Callbacks.Trigger(callback_name, {})',
    )
    expect(phoneClient).toMatch(
      /result\.success == true[\s\S]*open_requested = false[\s\S]*open_without_focus = false[\s\S]*return false/,
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
    expect(phoneBridge).toContain(
      'TriggerEvent("lb-phone:numberChanged", phone_number)',
    )
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
    expect(phoneBridge).toContain(
      'TriggerEvent("lb-phone:phoneNumberGenerated"',
    )
    expect(phoneBridge).toContain('TriggerEvent("lb-phone:factoryReset"')
    expect(phoneBridge).toContain('TriggerEvent("lb-phone:deletedFromGallery"')
  })

  it('opens from a configurable F1 mapping without client-provided device identity', () => {
    const config = readResourceFile('config/config.lua')
    const phoneClient = readResourceFile('source/client/main.lua')
    const phoneServer = readResourceFile('source/server/phone.lua')

    expect(config).toContain('Keybind = "F1"')
    expect(phoneClient).toContain('refresh_phone_key_mapping = function()')
    expect(phoneClient).toContain(
      'RegisterKeyMapping(command_name, locale.Controls.OpenPhone, "keyboard", key_name)',
    )
    expect(phoneClient).toContain(
      'if active_key_mapping_command == command_name then',
    )
    expect(phoneClient).toContain(
      'request_phone_open("sky_phone:device:open-request")',
    )
    expect(phoneServer).toContain(
      'Bridge.Callbacks.Register("sky_phone:device:open-request", function(source)',
    )
  })

  it('applies development command changes immediately without a resource restart', () => {
    const phoneClient = readResourceFile('source/client/main.lua')

    expect(phoneClient).toContain('local active_development_command = nil')
    expect(phoneClient).toContain('refresh_development_command = function()')
    expect(phoneClient).toContain(
      'local command_name = Config.Phone.DevelopmentCommand and Config.Command or nil',
    )
    expect(phoneClient).toContain('RegisterCommand(command_name, function()')
    expect(phoneClient).toContain(
      'if active_development_command == command_name and Config.Phone.DevelopmentCommand then',
    )
    expect(phoneClient).toContain(
      'TriggerEvent("chat:removeSuggestion", "/" .. active_development_command)',
    )
    expect(phoneClient).toMatch(
      /AddEventHandler\("sky_phone:configurator:updated", function\(\)[\s\S]*?refresh_development_command\(\)/,
    )
  })

  it('opens a running live activity with Space without affecting normal gameplay', () => {
    const phoneClient = readResourceFile('source/client/main.lua')

    expect(phoneClient).toContain(
      'RegisterCommand("sky_phone_live_activity_open"',
    )
    expect(phoneClient).toContain(
      'if not live_activity_active or is_open or open_requested then',
    )
    expect(phoneClient).toContain(
      'RegisterKeyMapping(\n    "sky_phone_live_activity_open"',
    )
    expect(phoneClient).toContain('"SPACE"')
    expect(phoneClient).toContain('RegisterNUICallback("ui:live-activity"')
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

    expect(phoneServer).toContain('if Config.Phone.Unique == false then')
    expect(phoneServer).toContain('return map_character_device(source, slot)')
    expect(phoneServer).toContain('FROM `sky_phone_character_devices`')
    expect(phoneServer).toContain('WHERE `owner_identifier` = ?')
    expect(migration).toContain('name = "sky_phone_character_devices"')
    expect(migration).toContain('primaryKey = "owner_identifier"')
  })
})
