local registered_callbacks = {}
local migration_callbacks = {}

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
    Framework = {
        HasAdminGroup = function()
            return true
        end,
    },
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
    AdminPanel = {
        AdminGroups = { "admin" },
        Command = "phoneadmin",
        Enabled = true,
    },
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

function AddEventHandler(_, callback)
    assert(type(callback) == "function")
end

function RegisterCommand(name, callback, restricted)
    assert(name == "phoneadmin")
    assert(type(callback) == "function")
    assert(restricted == false)
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
