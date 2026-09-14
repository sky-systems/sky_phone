Bridge.Database.AfterMigration("sky_phone", function()
SkyPhoneSecurity = {}

local passcode_pepper = tostring(Config.Server.PasscodePepper or "")
AddEventHandler("sky_phone:configurator:serverUpdated", function()
    passcode_pepper = tostring(Config.Server.PasscodePepper or "")
end)

if passcode_pepper == "" then
    Bridge.Debug(
        "warn",
        "[sky_phone] Config.Server.PasscodePepper is empty. Device passcodes still work, but their hashes lack the required server-side secret. Set a stable random value in config/config.lua before production; changing it later invalidates existing device passcodes.",
        { always = true }
    )
end

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end

    return type(result) == "table" and tonumber(result.affectedRows) or 0
end

local function load_device_security(imei)
    local rows = Bridge.Database.Query([[
        SELECT `passcode_length`, `failed_attempts`, `locked_until`, `face_id_identifier`
        FROM `sky_phone_device_security`
        WHERE `device_imei` = ?
        LIMIT 1
    ]], { imei })
    return rows[1]
end

local function valid_passcode(value)
    return type(value) == "string"
        and (#value == 4 or #value == 6)
        and value:match("^%d+$") ~= nil
end

local function passcode_matches(imei, passcode)
    local rows = Bridge.Database.Query([[
        SELECT 1 AS `matches`
        FROM `sky_phone_device_security`
        WHERE `device_imei` = ?
            AND `passcode_hash` = UNHEX(SHA2(CONCAT(?, `passcode_salt`, ?), 256))
        LIMIT 1
    ]], { imei, passcode_pepper, passcode })
    return rows[1] ~= nil
end

local function verify_passcode(session, passcode)
    if not valid_passcode(passcode) then
        return false, { success = false, error = "invalid_passcode" }
    end

    local security = load_device_security(session.imei)
    if not security then
        return false, { success = false, error = "passcode_not_set" }
    end

    local now = os.time()
    local locked_until = tonumber(security.locked_until) or 0
    if locked_until > now then
        return false, {
            success = false,
            error = "passcode_locked",
            data = { retryAfter = locked_until - now },
        }
    end

    if passcode_matches(session.imei, passcode) then
        Bridge.Database.Query([[
            UPDATE `sky_phone_device_security`
            SET `failed_attempts` = 0, `locked_until` = 0
            WHERE `device_imei` = ?
        ]], { session.imei })
        return true
    end

    local failed_attempts = (tonumber(security.failed_attempts) or 0) + 1
    if failed_attempts >= Config.Security.MaximumAttempts then
        local next_unlock = now + Config.Security.LockSeconds
        Bridge.Database.Query([[
            UPDATE `sky_phone_device_security`
            SET `failed_attempts` = 0, `locked_until` = ?
            WHERE `device_imei` = ?
        ]], { next_unlock, session.imei })
        return false, {
            success = false,
            error = "passcode_locked",
            data = { retryAfter = Config.Security.LockSeconds },
        }
    end

    Bridge.Database.Query([[
        UPDATE `sky_phone_device_security`
        SET `failed_attempts` = ?
        WHERE `device_imei` = ?
    ]], { failed_attempts, session.imei })
    return false, {
        success = false,
        error = "invalid_passcode",
        data = { attemptsRemaining = Config.Security.MaximumAttempts - failed_attempts },
    }
end

function SkyPhoneSecurity.Load(imei)
    return load_device_security(imei)
end

function SkyPhoneSecurity.Status(imei, security, security_loaded)
    if not security_loaded then
        security = load_device_security(imei)
    end
    return {
        enabled = security ~= nil,
        faceIdEnabled = security ~= nil and type(security.face_id_identifier) == "string"
            and security.face_id_identifier ~= "",
        length = security and tonumber(security.passcode_length) or nil,
        lockedUntil = security and tonumber(security.locked_until) or 0,
    }
end

local function character_identifier(source)
    local identifier = Bridge.Framework.GetIdentifier(source)
    if identifier == nil then return nil end
    identifier = tostring(identifier)
    if identifier == "" or #identifier > 80 then return nil end
    return identifier
end

local function same_device_session(source, session, identifier)
    local current = SkyPhone.RequireDeviceSession(source)
    return current == session and character_identifier(source) == identifier
end

local function verify_face_id_mask(source, data)
    -- Clothing getters are client-only natives. Treat the sampled appearance as
    -- untrusted input; the server owns the whitelist, ped model and owner check.
    local appearance = type(data) == "table" and data.faceIdAppearance
    local function integer_between(value, minimum, maximum)
        return type(value) == "number" and value % 1 == 0 and value >= minimum and value <= maximum
    end
    if type(appearance) ~= "table"
        or not integer_between(appearance.model, -2147483648, 4294967295)
        or not integer_between(appearance.drawable, 0, 65535)
        or not integer_between(appearance.texture, 0, 65535) then
        return false, { success = false, error = "face_id_unavailable" }
    end
    local ped = GetPlayerPed(tostring(source))
    local model = ped ~= 0 and GetEntityModel(ped) or 0
    if model == 0 or (model & 0xffffffff) ~= (appearance.model & 0xffffffff) then
        return false, { success = false, error = "face_id_unavailable" }
    end
    if appearance.drawable == 0 then return true end
    for _, mask in ipairs(Config.Security.FaceIdMaskWhitelist or {}) do
        if type(mask) == "table" and type(mask.Model) == "string"
            and (GetHashKey(mask.Model) & 0xffffffff) == (model & 0xffffffff)
            and mask.Drawable == appearance.drawable
            and (mask.Texture == -1 or mask.Texture == appearance.texture) then
            return true
        end
    end
    return false, { success = false, error = "face_id_masked" }
end

Bridge.Callbacks.Register("sky_phone:security:face-id-unlock", function(source, data)
    if not SkyPhone.AllowOperation(source, "security_unlock", Config.Security.AttemptsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local session, error_response = SkyPhone.RequireDeviceSession(source)
    if not session then return error_response end
    local identifier = character_identifier(source)
    local security = load_device_security(session.imei)
    if not security or not security.face_id_identifier then
        return { success = false, error = "face_id_not_enabled" }
    end
    if not identifier or security.face_id_identifier ~= identifier then
        return { success = false, error = "face_id_not_recognized" }
    end
    local visible, visibility_error = verify_face_id_mask(source, data)
    if not visible then return visibility_error end
    if not same_device_session(source, session, identifier) then
        return { success = false, error = "device_not_open" }
    end
    session.unlocked = true
    return { success = true, data = { security = SkyPhoneSecurity.Status(session.imei, security, true) } }
end)

Bridge.Callbacks.Register("sky_phone:security:set-face-id", function(source, data)
    if not SkyPhone.AllowOperation(source, "security_settings", Config.Security.AttemptsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then return error_response end
    if type(data) ~= "table" or type(data.enabled) ~= "boolean" then
        return { success = false, error = "invalid_request" }
    end
    local identifier = character_identifier(source)
    if not identifier then return { success = false, error = "face_id_unavailable" } end
    -- Enrollment always requires the device PIN; possession of an unlocked item is insufficient.
    local verified, verification_error = verify_passcode(session, data.passcode)
    if not verified then return verification_error end
    if data.enabled then
        local visible, visibility_error = verify_face_id_mask(source, data)
        if not visible then return visibility_error end
    end
    if not same_device_session(source, session, identifier) then
        return { success = false, error = "device_not_open" }
    end
    if data.enabled then
        Bridge.Database.Query([[
            UPDATE `sky_phone_device_security` SET `face_id_identifier` = ? WHERE `device_imei` = ?
        ]], { identifier, session.imei })
    else
        Bridge.Database.Query([[
            UPDATE `sky_phone_device_security` SET `face_id_identifier` = NULL WHERE `device_imei` = ?
        ]], { session.imei })
    end
    local security = load_device_security(session.imei)
    if not same_device_session(source, session, identifier) then
        return { success = false, error = "device_not_open" }
    end
    if not security or (data.enabled and security.face_id_identifier ~= identifier)
        or (not data.enabled and security.face_id_identifier ~= nil) then
        return { success = false, error = "request_failed" }
    end
    return { success = true, data = { security = SkyPhoneSecurity.Status(session.imei, security, true) } }
end)

Bridge.Callbacks.Register("sky_phone:security:unlock", function(source, data)
    if not SkyPhone.AllowOperation(source, "security_unlock", Config.Security.AttemptsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local session, error_response = SkyPhone.RequireDeviceSession(source)
    if not session then
        return error_response
    end
    if session.unlocked then
        return { success = true, data = { security = SkyPhoneSecurity.Status(session.imei) } }
    end

    local verified, verification_error = verify_passcode(session, data and data.passcode)
    if not verified then
        return verification_error
    end
    session.unlocked = true
    return { success = true, data = { security = SkyPhoneSecurity.Status(session.imei) } }
end)

Bridge.Callbacks.Register("sky_phone:security:set-passcode", function(source, data)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end
    local passcode = data and data.passcode
    if not valid_passcode(passcode) then
        return { success = false, error = "invalid_passcode" }
    end
    if load_device_security(session.imei) then
        return { success = false, error = "passcode_already_set" }
    end

    local salts = Bridge.Database.Query("SELECT REPLACE(UUID(), '-', '') AS `salt`", {})
    local salt = salts[1] and salts[1].salt
    if type(salt) ~= "string" or #salt ~= 32 then
        error("[sky_phone] Database did not generate a valid passcode salt.")
    end
    local result = Bridge.Database.Query([[
        INSERT INTO `sky_phone_device_security`
            (`device_imei`, `passcode_hash`, `passcode_salt`, `passcode_length`)
        VALUES (?, UNHEX(SHA2(CONCAT(?, ?, ?), 256)), ?, ?)
    ]], { session.imei, passcode_pepper, salt, passcode, salt, #passcode })
    if affected_rows(result) ~= 1 then
        return { success = false, error = "request_failed" }
    end
    return { success = true, data = { security = SkyPhoneSecurity.Status(session.imei) } }
end)

Bridge.Callbacks.Register("sky_phone:security:change-passcode", function(source, data)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end
    local new_passcode = data and data.newPasscode
    if not valid_passcode(new_passcode) then
        return { success = false, error = "invalid_passcode" }
    end
    local verified, verification_error = verify_passcode(session, data and data.currentPasscode)
    if not verified then
        return verification_error
    end

    local salts = Bridge.Database.Query("SELECT REPLACE(UUID(), '-', '') AS `salt`", {})
    local salt = salts[1] and salts[1].salt
    if type(salt) ~= "string" or #salt ~= 32 then
        error("[sky_phone] Database did not generate a valid passcode salt.")
    end
    local result = Bridge.Database.Query([[
        UPDATE `sky_phone_device_security`
        SET `passcode_hash` = UNHEX(SHA2(CONCAT(?, ?, ?), 256)),
            `passcode_salt` = ?, `passcode_length` = ?, `failed_attempts` = 0, `locked_until` = 0
        WHERE `device_imei` = ?
    ]], { passcode_pepper, salt, new_passcode, salt, #new_passcode, session.imei })
    if affected_rows(result) ~= 1 then
        return { success = false, error = "request_failed" }
    end
    return { success = true, data = { security = SkyPhoneSecurity.Status(session.imei) } }
end)

Bridge.Callbacks.Register("sky_phone:security:disable-passcode", function(source, data)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end
    local verified, verification_error = verify_passcode(session, data and data.passcode)
    if not verified then
        return verification_error
    end
    local result = Bridge.Database.Query(
        "DELETE FROM `sky_phone_device_security` WHERE `device_imei` = ?",
        { session.imei }
    )
    if affected_rows(result) ~= 1 then
        return { success = false, error = "request_failed" }
    end
    session.unlocked = true
    return { success = true, data = { security = SkyPhoneSecurity.Status(session.imei) } }
end)
end)
