Bridge.Database.AfterMigration("sky_phone", function()
SkyPhoneAccounts = {}

local auth_attempts = {}

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end

    return type(result) == "table" and tonumber(result.affectedRows) or 0
end

local function trim(value)
    if type(value) ~= "string" then
        return nil
    end

    return value:match("^%s*(.-)%s*$")
end

local function allow_auth_attempt(source)
    local now = os.time()
    local attempts = auth_attempts[source]
    if not attempts or now - attempts.started_at >= 60 then
        auth_attempts[source] = { count = 1, started_at = now }
        return true
    end
    if attempts.count >= Config.Mail.AuthAttemptsPerMinute then
        return false
    end
    attempts.count = attempts.count + 1
    return true
end

local function normalize_email(value)
    local email = trim(value)
    if not email then
        return nil
    end

    email = email:lower()
    local local_part = email
    if email:find("@", 1, true) then
        local_part = email:match("^([^@]+)@" .. Config.Mail.Domain:gsub("%.", "%%.") .. "$")
    end
    if not local_part
        or #local_part < Config.Mail.LocalPartMinLength
        or #local_part > Config.Mail.LocalPartMaxLength
        or not local_part:match("^[a-z0-9][a-z0-9._-]*[a-z0-9]$")
        or local_part:find("..", 1, true)
    then
        return nil
    end
    return local_part .. "@" .. Config.Mail.Domain
end

local function valid_password(value)
    if type(value) ~= "string" then
        return false
    end
    local length = utf8.len(value)
    return length and length >= Config.Mail.PasswordMinLength and length <= Config.Mail.PasswordMaxLength
end

function SkyPhoneAccounts.List(account_id, current_imei)
    local rows = Bridge.Database.Query([[
        SELECT `imei`, `device_name`, `created_at`, `updated_at`
        FROM `sky_phone_devices`
        WHERE `account_id` = ?
        ORDER BY `updated_at` DESC
    ]], { account_id })
    for _, row in ipairs(rows) do
        row.current = row.imei == current_imei
    end
    return rows
end

local function link_account(source, account)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end

    if not SkyPhoneCalls.LinkAccountData(account.id, session.imei) then
        return { success = false, error = "request_failed" }
    end
    if not Bridge.Database.Transaction({
        {
            query = "UPDATE `sky_phone_devices` SET `account_id` = ? WHERE `imei` = ?",
            params = { account.id, session.imei },
        },
        {
            query = [[
                UPDATE `sky_phone_notes`
                SET `account_id` = ?, `device_imei` = NULL, `revision` = `revision` + 1
                WHERE `device_imei` = ? AND `account_id` IS NULL
            ]],
            params = { account.id, session.imei },
        },
        {
            query = [[
                UPDATE `sky_phone_media`
                SET `account_id` = ?, `device_imei` = NULL
                WHERE `device_imei` = ? AND `account_id` IS NULL
            ]],
            params = { account.id, session.imei },
        },
        {
            query = [[
                UPDATE `sky_phone_music_playlist_items` AS `item`
                INNER JOIN `sky_phone_music_playlists` AS `playlist`
                    ON `playlist`.`id` = `item`.`playlist_id`
                INNER JOIN `sky_phone_music_youtube_songs` AS `local_song`
                    ON `item`.`source` = 'youtube' AND `local_song`.`id` = `item`.`song_id`
                INNER JOIN `sky_phone_music_youtube_songs` AS `cloud_song`
                    ON `cloud_song`.`account_id` = ? AND `cloud_song`.`video_id` = `local_song`.`video_id`
                SET `item`.`song_id` = `cloud_song`.`id`
                WHERE `playlist`.`device_imei` = ? AND `playlist`.`account_id` IS NULL
                    AND `local_song`.`device_imei` = ? AND `local_song`.`account_id` IS NULL
            ]],
            params = { account.id, session.imei, session.imei },
        },
        {
            query = [[
                DELETE `local_song` FROM `sky_phone_music_youtube_songs` AS `local_song`
                INNER JOIN `sky_phone_music_youtube_songs` AS `cloud_song`
                    ON `cloud_song`.`account_id` = ? AND `cloud_song`.`video_id` = `local_song`.`video_id`
                WHERE `local_song`.`device_imei` = ? AND `local_song`.`account_id` IS NULL
            ]],
            params = { account.id, session.imei },
        },
        {
            query = [[
                UPDATE `sky_phone_music_youtube_songs`
                SET `account_id` = ?, `device_imei` = NULL
                WHERE `device_imei` = ? AND `account_id` IS NULL
            ]],
            params = { account.id, session.imei },
        },
        {
            query = [[
                UPDATE `sky_phone_music_playlists`
                SET `account_id` = ?, `device_imei` = NULL
                WHERE `device_imei` = ? AND `account_id` IS NULL
            ]],
            params = { account.id, session.imei },
        },
    }) then
        return { success = false, error = "request_failed" }
    end

    SkyPhone.RefreshSource(source)
    return {
        success = true,
        data = {
            email = account.email,
            devices = SkyPhoneAccounts.List(account.id, session.imei),
        },
    }
end

local function authenticate(source, data, registering)
    if not allow_auth_attempt(source) then
        return { success = false, error = "rate_limited" }
    end
    if type(data) ~= "table" then
        return { success = false, error = "invalid_request" }
    end

    local email = normalize_email(data.email)
    local password = data.password
    if not email then
        return { success = false, error = registering and "invalid_email" or "invalid_credentials" }
    end
    if not valid_password(password) then
        return { success = false, error = registering and "invalid_password" or "invalid_credentials" }
    end

    if registering then
        local result = Bridge.Database.Query(
            "INSERT IGNORE INTO `sky_phone_accounts` (`email`, `password`) VALUES (?, ?)",
            { email, password }
        )
        if affected_rows(result) == 0 then
            return { success = false, error = "email_taken" }
        end
    end

    local accounts = Bridge.Database.Query(
        "SELECT `id`, `email` FROM `sky_phone_accounts` WHERE `email` = ? AND `password` = ? LIMIT 1",
        { email, password }
    )
    if not accounts[1] then
        return { success = false, error = "invalid_credentials" }
    end
    return link_account(source, accounts[1])
end

for _, endpoint in ipairs({ "account:login", "mail:login" }) do
    Bridge.Callbacks.Register("sky_phone:" .. endpoint, function(source, data)
        return authenticate(source, data, false)
    end)
end

for _, endpoint in ipairs({ "account:register", "mail:register" }) do
    Bridge.Callbacks.Register("sky_phone:" .. endpoint, function(source, data)
        return authenticate(source, data, true)
    end)
end

for _, endpoint in ipairs({ "account:logout", "mail:logout" }) do
    Bridge.Callbacks.Register("sky_phone:" .. endpoint, function(source)
        local account, error_response = SkyPhone.RequireAccount(source)
        if not account then
            return error_response
        end
        if not SkyPhoneCalls.CopyCloudToDevice(account.id, account.imei) then
            return { success = false, error = "request_failed" }
        end
        Bridge.Database.Query("UPDATE `sky_phone_devices` SET `account_id` = NULL WHERE `imei` = ?", { account.imei })
        SkyPhone.RefreshSource(source)
        return { success = true }
    end)
end

Bridge.Callbacks.Register("sky_phone:account:devices", function(source)
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then
        return error_response
    end
    return { success = true, data = SkyPhoneAccounts.List(account.id, account.imei) }
end)

Bridge.Callbacks.Register("sky_phone:account:remove-device", function(source, data)
    if not SkyPhone.AllowOperation(source, "remove_device", 10, 60) then
        return { success = false, error = "rate_limited" }
    end
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then
        return error_response
    end
    if type(data) ~= "table" or not SkyPhoneImei.IsValid(data.imei) or not valid_password(data.password) then
        return { success = false, error = "invalid_request" }
    end
    if data.imei == account.imei then
        return { success = false, error = "current_device" }
    end
    local passwords = Bridge.Database.Query("SELECT `id` FROM `sky_phone_accounts` WHERE `id` = ? AND `password` = ? LIMIT 1", {
        account.id,
        data.password,
    })
    if not passwords[1] then
        return { success = false, error = "invalid_credentials" }
    end
    local result = Bridge.Database.Query(
        "UPDATE `sky_phone_devices` SET `account_id` = NULL WHERE `imei` = ? AND `account_id` = ?",
        { data.imei, account.id }
    )
    if affected_rows(result) ~= 1 then
        return { success = false, error = "device_not_found" }
    end
    SkyPhone.RefreshDevice(data.imei)
    SkyPhone.RefreshAccount(account.id)
    return { success = true, data = SkyPhoneAccounts.List(account.id, account.imei) }
end)

AddEventHandler("playerDropped", function()
    auth_attempts[source] = nil
end)

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name == GetCurrentResourceName() then
        auth_attempts = {}
    end
end)
end)
