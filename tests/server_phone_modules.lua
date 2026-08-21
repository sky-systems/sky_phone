local registered_callbacks = {}
local migration_callbacks = {}
local event_handlers = {}

Bridge = {
    Callbacks = {
        Register = function(name, callback)
            assert(type(name) == "string" and type(callback) == "function")
            assert(registered_callbacks[name] == nil, "duplicate callback: " .. name)
            registered_callbacks[name] = callback
        end,
    },
    Database = {
        AfterMigration = function(name, callback)
            assert(name == "sky_phone")
            migration_callbacks[#migration_callbacks + 1] = callback
        end,
        Query = function()
            return {}
        end,
        Transaction = function()
            return true
        end,
    },
    Debug = function()
    end,
    Framework = {},
    Inventory = {
        GetResourceName = function()
            return "test_inventory"
        end,
        RegisterUsableItem = function(_, callback)
            assert(type(callback) == "function")
            return true
        end,
    },
}

Config = {
    Phone = {
        DevelopmentCommand = false,
        DeviceName = "Test Phone",
        Item = "phone",
        Unique = true,
    },
    Sim = {
        Enabled = true,
        NumberGroups = { 3, 4 },
        NumberLength = 7,
        NumberPrefix = "",
    },
    Server = {
        PasscodePepper = "test-pepper",
    },
    Security = {
        AttemptsPerMinute = 5,
        LockSeconds = 60,
        MaximumAttempts = 5,
    },
    Mail = {
        AuthAttemptsPerMinute = 5,
        Domain = "test.local",
        LocalPartMinLength = 3,
        LocalPartMaxLength = 32,
        PasswordMinLength = 8,
        PasswordMaxLength = 72,
    },
}

json = {
    encode = function()
        return "{}"
    end,
    decode = function()
        return {}
    end,
}

function AddEventHandler(name, callback)
    assert(type(callback) == "function")
    event_handlers[name] = event_handlers[name] or {}
    event_handlers[name][#event_handlers[name] + 1] = callback
end

function TriggerClientEvent()
end

function TriggerEvent()
end

function GetCurrentResourceName()
    return "sky_phone"
end

function GetGameTimer()
    return 1
end

function GetPlayers()
    return {}
end

SkyPhoneImei = {}
SkyPhoneSimNumber = {}

local module_paths = {
    "sky_phone/source/server/phone_security.lua",
    "sky_phone/source/server/phone_accounts.lua",
    "sky_phone/source/server/phone_persistence.lua",
    "sky_phone/source/server/phone.lua",
}

for _, path in ipairs(module_paths) do
    assert(loadfile(path))()
end

for _, callback in ipairs(migration_callbacks) do
    callback()
end

assert(type(SkyPhoneSecurity) == "table")
assert(type(SkyPhoneSecurity.Load) == "function")
assert(type(SkyPhoneSecurity.Status) == "function")
assert(type(SkyPhoneAccounts) == "table")
assert(type(SkyPhoneAccounts.List) == "function")

for _, method in ipairs({
    "EnsureDevice",
    "FindDeviceSlots",
    "LoadDevice",
    "RefreshSource",
    "GetEquippedPhoneNumber",
    "GetSourceFromNumber",
    "FormatNumber",
    "RequireDeviceSession",
    "RequireSession",
    "AllowOperation",
    "RequireAccount",
    "NotifyAccount",
    "NotifyAccountDevices",
    "RefreshAccount",
    "RefreshDevice",
    "OpenDeviceForCall",
}) do
    assert(type(SkyPhone[method]) == "function", "missing SkyPhone API: " .. method)
end

for _, callback_name in ipairs({
    "sky_phone:security:unlock",
    "sky_phone:security:set-passcode",
    "sky_phone:security:change-passcode",
    "sky_phone:security:disable-passcode",
    "sky_phone:device:save",
    "sky_phone:notifications:save",
    "sky_phone:device:factory-reset",
    "sky_phone:account:login",
    "sky_phone:mail:login",
    "sky_phone:account:register",
    "sky_phone:mail:register",
    "sky_phone:account:logout",
    "sky_phone:mail:logout",
    "sky_phone:account:devices",
    "sky_phone:account:remove-device",
    "sky_phone:device:open-request",
    "sky_phone:device:development-open",
    "sky_phone:device:close",
    "sky_phone:device:equipped-number",
    "sky_phone:device:notification-open",
}) do
    assert(type(registered_callbacks[callback_name]) == "function", "missing callback: " .. callback_name)
end

for _, callback_name in ipairs({
    "sky_phone:security:unlock",
    "sky_phone:device:save",
    "sky_phone:device:factory-reset",
    "sky_phone:account:devices",
}) do
    local response = registered_callbacks[callback_name](1, {})
    assert(response.success == false and response.error == "device_not_open", "callback not bound to core: " .. callback_name)
end

local phone_item = {
    name = "phone",
    slot = 4,
    amount = 1,
    metadata = { imei = "123456789012345" },
}
local opened_event
local device_error
local hide_phone_during_prepare = false

Bridge.Framework.GetIdentifier = function(source)
    assert(source == 1)
    return "license:test-player"
end
Bridge.Framework.GetFirstname = function()
    return "Test"
end
Bridge.Framework.GetLastname = function()
    return "Player"
end
Bridge.Inventory.GetSlot = function(source, slot)
    assert(source == 1 and slot == phone_item.slot)
    return phone_item
end
Bridge.Inventory.GetSlotsWithItem = function(source, item_name)
    assert(source == 1 and item_name == Config.Phone.Item)
    if hide_phone_during_prepare == true then
        return {}
    end
    return { phone_item }
end
Bridge.Inventory.SetSlotMetadata = function()
    error("existing phone metadata must not be rewritten")
end
Bridge.Database.Query = function(query)
    if query:find("FROM `sky_phone_devices` d", 1, true) then
        return {
            {
                imei = phone_item.metadata.imei,
                device_name = Config.Phone.DeviceName,
                account_id = nil,
                sim_id = nil,
            },
        }
    end
    return {}
end
SkyPhoneImei.IsValid = function(imei)
    return imei == phone_item.metadata.imei
end
SkyPhoneSim = {
    PrepareDevice = function(source, slot, imei)
        assert(source == 1 and slot == phone_item and imei == phone_item.metadata.imei)
        if hide_phone_during_prepare == "next" then
            hide_phone_during_prepare = true
        end
        return true
    end,
}
SkyPhoneNotes = {
    List = function()
        return {}
    end,
}
SkyPhoneMemos = {
    List = function()
        return {}
    end,
}
SkyPhoneCompanies = {
    ClearCallAvailability = function()
    end,
}
TriggerClientEvent = function(event_name, source, payload)
    if event_name == "sky_phone:device:open" then
        opened_event = { source = source, payload = payload }
    elseif event_name == "sky_phone:device:error" then
        device_error = { source = source, error = payload }
    end
end

for _, callback in ipairs(event_handlers.onServerResourceStart or {}) do
    callback("sky_phone")
end

local no_sim_open = registered_callbacks["sky_phone:device:open-request"](1, {})
assert(no_sim_open.success == true, "a phone item without a SIM must still open")
assert(opened_event and opened_event.source == 1, "no-SIM open must reach the client")
assert(opened_event.payload.device.imei == phone_item.metadata.imei)
assert(opened_event.payload.device.sim == nil, "no-SIM bootstrap must keep device.sim nullable")

opened_event = nil
device_error = nil
hide_phone_during_prepare = "next"
local lost_phone_open = registered_callbacks["sky_phone:device:open-request"](1, {})
assert(lost_phone_open.success == false, "bootstrap ownership loss must fail the open request")
assert(lost_phone_open.error == "device_not_owned", "bootstrap ownership loss must return its error code")
assert(opened_event == nil, "bootstrap ownership loss must not open the NUI")
assert(device_error and device_error.error == "device_not_owned", "bootstrap ownership loss must notify the client")

local manifest_file = assert(io.open("sky_phone/fxmanifest.lua", "rb"))
local manifest = manifest_file:read("*a")
manifest_file:close()

local security_position = assert(manifest:find("source/server/phone_security.lua", 1, true))
local accounts_position = assert(manifest:find("source/server/phone_accounts.lua", 1, true))
local persistence_position = assert(manifest:find("source/server/phone_persistence.lua", 1, true))
local phone_position = assert(manifest:find("source/server/phone.lua", 1, true))
local migration_position = assert(manifest:find("source/server/db_migrate.lua", 1, true))

assert(security_position < phone_position)
assert(accounts_position < phone_position)
assert(persistence_position < phone_position)
assert(phone_position < migration_position)

print("server phone modules: ok")
