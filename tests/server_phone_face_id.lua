-- Run from the repository root with Lua 5.4.
local callbacks, security, session, identifier, pin, query_hook
local allow_operation, carried, now = true, true, 100
local ped, model, appearance
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v) end
    return result
end
local env = setmetatable({
    Config = { Server = { PasscodePepper = "test-secret" }, Security = {
        AttemptsPerMinute = 10, MaximumAttempts = 3, LockSeconds = 30,
    } },
    AddEventHandler = function() end,
    GetPlayerPed = function(source) assert(source == "1"); return ped end,
    GetEntityModel = function(entity) assert(entity == ped); return model end,
    GetHashKey = function(name)
        return name == "mp_m_freemode_01" and 1885233650 or 2627665880
    end,
    os = { time = function() return now end },
}, { __index = _G })
callbacks = {}
env.Bridge = {
    Framework = { GetIdentifier = function() return identifier end },
    Debug = function() end,
    Callbacks = { Register = function(name, fn) callbacks[name] = fn end },
    Database = {
        AfterMigration = function(_, fn) fn() end,
        Query = function(sql, params)
            assert(type(params) == "table")
            if query_hook then local fn = query_hook; query_hook = nil; fn() end
            if sql:find("SELECT `passcode_length`", 1, true) then
                return security and { copy(security) } or {}
            elseif sql:find("SELECT 1 AS `matches`", 1, true) then
                return security and params[3] == pin and { { matches = 1 } } or {}
            elseif sql:find("SET `face_id_identifier` = ?", 1, true) then
                if security then security.face_id_identifier = params[1] end
                return security and 1 or 0
            elseif sql:find("SET `face_id_identifier` = NULL", 1, true) then
                if security then security.face_id_identifier = nil end
                return security and 1 or 0
            elseif sql:find("SET `failed_attempts` = 0, `locked_until` = ?", 1, true) then
                security.failed_attempts, security.locked_until = 0, params[1]
                return 1
            elseif sql:find("SET `failed_attempts` = 0, `locked_until` = 0", 1, true) then
                security.failed_attempts, security.locked_until = 0, 0
                return 1
            elseif sql:find("SET `failed_attempts` = ?", 1, true) then
                security.failed_attempts = params[1]
                return 1
            elseif sql:find("DELETE FROM `sky_phone_device_security`", 1, true) then
                security = nil
                return 1
            end
            error("Unhandled security query: " .. sql)
        end,
    },
}
env.SkyPhone = {
    AllowOperation = function() return allow_operation end,
    RequireDeviceSession = function()
        if session and carried then return session end
        return nil, { success = false, error = "device_not_open" }
    end,
    RequireSession = function()
        if not session or not carried then return nil, { success = false, error = "device_not_open" } end
        if not session.unlocked then return nil, { success = false, error = "device_locked" } end
        return session
    end,
}
assert(loadfile("sky_phone/source/server/phone_security.lua", "t", env))()
local function reset()
    security = { passcode_length = 4, failed_attempts = 0, locked_until = 0 }
    session = { imei = "123456789012345", unlocked = true }
    identifier, pin, carried, allow_operation, query_hook = "character:owner", "1234", true, true, nil
    ped, model = 9, 1885233650
    appearance = { model = model, drawable = 0, texture = 0 }
    env.Config.Security.FaceIdMaskWhitelist = {}
end
local function call(action, data)
    data = copy(data or {})
    data.faceIdAppearance = data.faceIdAppearance or copy(appearance)
    return callbacks["sky_phone:security:" .. action](1, data)
end
local function rejected(action, data, expected)
    local result = call(action, data)
    assert(result.success == false and result.error == expected, action .. ": expected " .. expected)
end

reset()
assert(env.SkyPhoneSecurity.Status(session.imei).faceIdEnabled == false)
rejected("face-id-unlock", {}, "face_id_not_enabled")
rejected("set-face-id", { enabled = "true", passcode = pin }, "invalid_request")
rejected("set-face-id", { enabled = true, passcode = "0000" }, "invalid_passcode")
assert(security.face_id_identifier == nil)
local result = call("set-face-id", { enabled = true, passcode = pin, ownerIdentifier = "spoofed" })
assert(result.success and result.data.security.faceIdEnabled)
assert(security.face_id_identifier == "character:owner", "Never enroll a client-provided identity")
assert(result.data.security.face_id_identifier == nil, "Do not disclose the enrolled character")
session.unlocked = false
identifier = "character:other"
rejected("face-id-unlock", { ownerIdentifier = "character:owner" }, "face_id_not_recognized")
assert(session.unlocked == false)
identifier = nil
rejected("face-id-unlock", {}, "face_id_not_recognized")
identifier = "character:owner"
assert(call("face-id-unlock").success and session.unlocked)
session.unlocked = false
carried = false
rejected("face-id-unlock", {}, "device_not_open")
carried = true
allow_operation = false
rejected("face-id-unlock", {}, "rate_limited")
rejected("set-face-id", { enabled = true, passcode = pin }, "rate_limited")
allow_operation = true
rejected("set-face-id", { enabled = true, passcode = pin }, "device_locked")
assert(call("unlock", { passcode = pin }).success, "PIN fallback remains available")
rejected("set-face-id", { enabled = false, passcode = "0000" }, "invalid_passcode")
assert(security.face_id_identifier == identifier)
assert(call("set-face-id", { enabled = false, passcode = pin }).success)
assert(not env.SkyPhoneSecurity.Status(session.imei).faceIdEnabled)
assert(call("set-face-id", { enabled = true, passcode = pin }).success)
assert(call("disable-passcode", { passcode = pin }).success)
assert(security == nil and not env.SkyPhoneSecurity.Status(session.imei).faceIdEnabled)
rejected("face-id-unlock", {}, "face_id_not_enabled")
rejected("set-face-id", { enabled = true, passcode = pin }, "passcode_not_set")

reset()
for _ = 1, 2 do rejected("set-face-id", { enabled = true, passcode = "0000" }, "invalid_passcode") end
rejected("set-face-id", { enabled = true, passcode = "0000" }, "passcode_locked")
rejected("set-face-id", { enabled = true, passcode = pin }, "passcode_locked")
assert(security.face_id_identifier == nil)

reset()
identifier = string.rep("a", 81)
rejected("set-face-id", { enabled = true, passcode = pin }, "face_id_unavailable")
reset()
query_hook = function() session = { imei = "different", unlocked = true } end
rejected("set-face-id", { enabled = true, passcode = pin }, "device_not_open")
assert(security.face_id_identifier == nil)
reset()
security.face_id_identifier = identifier
session.unlocked = false
query_hook = function() identifier = "character:changed" end
rejected("face-id-unlock", {}, "device_not_open")
assert(session.unlocked == false)
reset()
security.face_id_identifier = identifier
session.unlocked = false
local old_session = session
query_hook = function() session = { imei = "different", unlocked = false } end
rejected("face-id-unlock", {}, "device_not_open")
assert(not old_session.unlocked and not session.unlocked)

reset()
appearance.drawable = 12
rejected("set-face-id", { enabled = true, passcode = pin }, "face_id_masked")
assert(security.face_id_identifier == nil, "A masked character cannot enroll")
appearance.drawable = 0
assert(call("set-face-id", { enabled = true, passcode = pin }).success)
session.unlocked, appearance.drawable = false, 12
rejected("face-id-unlock", { isMasked = false }, "face_id_masked")
assert(not session.unlocked)
assert(call("unlock", { passcode = pin }).success, "PIN fallback works while wearing a mask")
assert(call("set-face-id", { enabled = false, passcode = pin }).success, "Masked owners can disable Face ID with their PIN")
env.Config.Security.FaceIdMaskWhitelist = { { Model = "mp_m_freemode_01", Drawable = 12, Texture = 3 } }
rejected("set-face-id", { enabled = true, passcode = pin }, "face_id_masked")
appearance.texture = 3
assert(call("set-face-id", { enabled = true, passcode = pin }).success)
session.unlocked = false
assert(call("face-id-unlock").success, "Exact mask and texture are allowed")
appearance.texture = 4
rejected("face-id-unlock", {}, "face_id_masked")
env.Config.Security.FaceIdMaskWhitelist[1].Texture = -1
assert(call("face-id-unlock").success, "Wildcard permits every texture")
model, appearance.model = 2627665880, 2627665880
rejected("face-id-unlock", {}, "face_id_masked")
env.Config.Security.FaceIdMaskWhitelist[1].Model = "mp_f_freemode_01"
appearance.model = model - 4294967296
assert(call("face-id-unlock").success, "Signed and unsigned ped hashes match")
identifier = "character:other"
rejected("face-id-unlock", {}, "face_id_not_recognized")
identifier = "character:owner"
env.Config.Security.FaceIdMaskWhitelist = {}
session.unlocked = false
rejected("face-id-unlock", {}, "face_id_masked")
appearance.drawable = 0
assert(call("face-id-unlock").success, "Removing the mask permits retry without reopening the phone")
session.unlocked = false
for _, invalid in ipairs({ {}, { model = model, drawable = -1, texture = 0 },
    { model = model, drawable = "0", texture = 0 }, { model = model, drawable = 0.5, texture = 0 },
    { model = model, drawable = 0, texture = -1 }, { model = 1, drawable = 0, texture = 0 } }) do
    rejected("face-id-unlock", { faceIdAppearance = invalid }, "face_id_unavailable")
    assert(not session.unlocked)
end
assert(callbacks["sky_phone:security:face-id-unlock"](1, {}).error == "face_id_unavailable")
ped = 0
rejected("face-id-unlock", {}, "face_id_unavailable")
print("Phone Face ID ownership, masks, whitelist, PIN fallback, rate limits and session races passed")
