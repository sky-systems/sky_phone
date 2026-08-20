Bridge.Database.AfterMigration("sky_phone", function()
SkyPhoneSecurity = {}

local passcode_pepper = tostring(Config.Server.PasscodePepper or "")
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
        SELECT `passcode_length`, `failed_attempts`, `locked_until`
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
        length = security and tonumber(security.passcode_length) or nil,
        lockedUntil = security and tonumber(security.locked_until) or 0,
    }
end

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
