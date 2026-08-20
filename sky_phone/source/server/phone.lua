local phone_open_handler
local pending_phone_opens = {}
local server_started = false

local function flush_pending_phone_opens()
    if not server_started or not phone_open_handler then
        return
    end

    for player_source in pairs(pending_phone_opens) do
        pending_phone_opens[player_source] = nil
        phone_open_handler(player_source, nil)
    end
end

Bridge.Callbacks.Register("sky_phone:device:open-request", function(source)
    if not server_started or not phone_open_handler then
        pending_phone_opens[source] = true
        return { success = true, data = { queued = true } }
    end

    return { success = phone_open_handler(source, nil) }
end)

Bridge.Callbacks.Register("sky_phone:device:development-open", function(source)
    if not Config.Phone.DevelopmentCommand then
        return { success = false, error = "disabled" }
    end
    if not server_started or not phone_open_handler then
        pending_phone_opens[source] = true
        return { success = true, data = { queued = true } }
    end

    return { success = phone_open_handler(source, nil) }
end)

AddEventHandler("playerDropped", function()
    pending_phone_opens[source] = nil
end)

AddEventHandler("onServerResourceStart", function(resource_name)
    if resource_name ~= GetCurrentResourceName() then
        return
    end

    server_started = true
    flush_pending_phone_opens()
end)

Bridge.Database.AfterMigration("sky_phone", function()
Bridge.Debug("debug", "[sky_phone] Server initialization started after database migration.", { always = true })

SkyPhone = {}

local unique_phones = Config.Phone.Unique ~= false
local sim_cards_enabled = Config.Sim.Enabled ~= false
local sessions = {}
local preferred_device_imeis = {}
local auth_attempts = {}
local operation_attempts = {}
local character_device_cache = {}
local max_device_data_bytes = 100000
local passcode_pepper = tostring(Config.Server.PasscodePepper or "")
if passcode_pepper == "" then
    Bridge.Debug(
        "warn",
        "[sky_phone] Config.Server.PasscodePepper is empty. Device passcodes still work, but their hashes lack the required server-side secret. Set a stable random value in config/config.lua before production; changing it later invalidates existing device passcodes.",
        { always = true }
    )
end
local allowed_device_namespaces = {
    settings = true,
    notifications = true,
    wallpaper = true,
    alarms = true,
    appAuth = true,
    apps = true,
    games = true,
    widgets = true,
    citywarn = true,
}

local function trim(value)
    if type(value) ~= "string" then
        return nil
    end

    return value:match("^%s*(.-)%s*$")
end

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end

    return type(result) == "table" and tonumber(result.affectedRows) or 0
end

local function reserve_imei()
    local imei = SkyPhoneImei.Reserve(function()
        local rows = Bridge.Database.Query("SELECT UUID() AS `id`", {})
        local uuid = rows[1] and rows[1].id
        if type(uuid) ~= "string" then
            error("[sky_phone] Database did not generate entropy for an IMEI.")
        end
        return uuid
    end, function(candidate)
        local result = Bridge.Database.Query([[
            INSERT IGNORE INTO `sky_phone_devices` (`imei`, `device_name`)
            VALUES (?, ?)
        ]], { candidate, Config.Phone.DeviceName })
        return affected_rows(result) > 0
    end)

    if not imei then
        error("[sky_phone] Could not generate a unique IMEI after 20 attempts.")
    end
    return imei
end

local function character_identifier(source)
    local identifier = Bridge.Framework.GetIdentifier(source)
    if identifier == nil then
        return nil
    end

    identifier = tostring(identifier)
    if identifier == "" or #identifier > 80 then
        Bridge.Debug(
            "warn",
            "[sky_phone] Could not resolve a valid character identifier for source %s.",
            tostring(source)
        )
        return nil
    end
    return identifier
end

local function migrated_device_for_character(source)
    local identifier = character_identifier(source)
    if not identifier then
        return nil
    end

    local rows = Bridge.Database.Query([[
        SELECT mapping.`device_imei`
        FROM `sky_phone_migration_owners` mapping
        JOIN `sky_phone_character_devices` character_device
            ON character_device.`owner_identifier` = mapping.`owner_identifier`
            AND character_device.`device_imei` = mapping.`device_imei`
        JOIN `sky_phone_devices` device ON device.`imei` = mapping.`device_imei`
        WHERE mapping.`source` = 'lb-phone' AND mapping.`owner_identifier` = ?
        ORDER BY mapping.`created_at` DESC
        LIMIT 1
    ]], { identifier })
    local imei = rows[1] and rows[1].device_imei or nil
    if imei and not SkyPhoneImei.IsValid(imei) then
        Bridge.Debug(
            "error",
            "[sky_phone] LB Phone migration mapping contains invalid IMEI '%s' for '%s'.",
            tostring(imei),
            identifier
        )
        return nil
    end
    return imei
end

local function load_character_device(source, identifier)
    identifier = identifier or character_identifier(source)
    if not identifier then
        return nil, "player_unavailable"
    end

    local cached = character_device_cache[source]
    if cached and cached.identifier == identifier then
        return cached.imei, nil, identifier
    end

    local rows = Bridge.Database.Query([[
        SELECT `device_imei`
        FROM `sky_phone_character_devices`
        WHERE `owner_identifier` = ?
        LIMIT 1
    ]], { identifier })
    local imei = rows[1] and rows[1].device_imei or nil
    if imei then
        character_device_cache[source] = { identifier = identifier, imei = imei }
    else
        character_device_cache[source] = nil
    end
    return imei, nil, identifier
end

local function cache_character_device(source, identifier, imei)
    character_device_cache[source] = { identifier = identifier, imei = imei }
    return imei
end

local function map_character_device(source, slot)
    local mapped_imei, error_code, identifier = load_character_device(source)
    if error_code or mapped_imei then
        return mapped_imei, error_code
    end

    -- On the first switch from unique to shared phones, adopt the currently used
    -- legacy device when it has not already been claimed by another character.
    local legacy_imei = slot.metadata and slot.metadata.imei or nil
    if SkyPhoneImei.IsValid(legacy_imei) then
        Bridge.Database.Query([[
            INSERT IGNORE INTO `sky_phone_devices` (`imei`, `device_name`)
            VALUES (?, ?)
        ]], { legacy_imei, Config.Phone.DeviceName })
        local result = Bridge.Database.Query([[
            INSERT IGNORE INTO `sky_phone_character_devices` (`owner_identifier`, `device_imei`)
            VALUES (?, ?)
        ]], { identifier, legacy_imei })
        if affected_rows(result) == 1 then
            return cache_character_device(source, identifier, legacy_imei)
        end

        mapped_imei = load_character_device(source, identifier)
        if mapped_imei then
            return mapped_imei
        end
    end

    local imei = reserve_imei()
    local result = Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_character_devices` (`owner_identifier`, `device_imei`)
        VALUES (?, ?)
    ]], { identifier, imei })
    if affected_rows(result) == 1 then
        return cache_character_device(source, identifier, imei)
    end

    -- Another simultaneous open may have created the mapping first. Keep its
    -- winner and remove only the fresh, unmapped device reserved by this call.
    mapped_imei = load_character_device(source, identifier)
    Bridge.Database.Query([[
        DELETE d FROM `sky_phone_devices` d
        LEFT JOIN `sky_phone_character_devices` c ON c.`device_imei` = d.`imei`
        WHERE d.`imei` = ? AND c.`device_imei` IS NULL
    ]], { imei })
    if mapped_imei then
        return mapped_imei
    end

    Bridge.Debug(
        "error",
        "[sky_phone] Could not create a shared device mapping for source %s.",
        tostring(source)
    )
    return nil, "request_failed"
end

local function find_device_slots(source, imei)
    local matches = {}
    local slots = Bridge.Inventory.GetSlotsWithItem(source, Config.Phone.Item)
    if not unique_phones then
        if not slots[1] then
            return matches
        end
        local mapped_imei = load_character_device(source)
        if mapped_imei ~= imei then
            return matches
        end
        for _, item in ipairs(slots) do
            matches[#matches + 1] = item
        end
        return matches
    end

    for _, item in ipairs(slots) do
        if item.metadata and item.metadata.imei == imei then
            matches[#matches + 1] = item
        end
    end

    if #matches > 1 then
        Bridge.Debug(
            "warn",
            "[sky_phone] Source %s has %s items with duplicated IMEI %s.",
            tostring(source),
            tostring(#matches),
            imei
        )
    end

    return matches
end

local function resolve_used_slot(source, used_item)
    Bridge.Debug(
        "debug",
        "[sky_phone] Resolving used item for source %s: type=%s slot=%s id=%s name=%s.",
        tostring(source),
        type(used_item),
        tostring(used_item and used_item.slot),
        tostring(used_item and used_item.id),
        tostring(used_item and used_item.name),
        { always = true }
    )

    local slot_id = used_item and (used_item.slot or used_item.id)
    if slot_id then
        local slot = Bridge.Inventory.GetSlot(source, slot_id)
        Bridge.Debug(
            "debug",
            "[sky_phone] Inventory slot lookup for source %s slot %s returned name=%s amount=%s metadata_imei=%s.",
            tostring(source),
            tostring(slot_id),
            tostring(slot and slot.name),
            tostring(slot and (slot.amount or slot.count)),
            tostring(slot and slot.metadata and slot.metadata.imei),
            { always = true }
        )
        if slot and slot.name == Config.Phone.Item then
            return slot
        end

        Bridge.Debug(
            "warn",
            "[sky_phone] Usable item callback reported invalid phone slot %s for source %s.",
            tostring(slot_id),
            tostring(source)
        )
        return nil, "phone_slot_missing"
    end

    local slots = Bridge.Inventory.GetSlotsWithItem(source, Config.Phone.Item)
    Bridge.Debug(
        "debug",
        "[sky_phone] Inventory fallback found %s phone slot candidates for source %s.",
        tostring(#slots),
        tostring(source),
        { always = true }
    )
    for _, candidate in ipairs(slots) do
        Bridge.Debug(
            "debug",
            "[sky_phone] Candidate slot=%s name=%s amount=%s metadata_imei=%s.",
            tostring(candidate.slot),
            tostring(candidate.name),
            tostring(candidate.amount or candidate.count),
            tostring(candidate.metadata and candidate.metadata.imei),
            { always = true }
        )
    end

    if not unique_phones and #slots > 0 then
        return slots[1]
    end

    local preferred_imei = preferred_device_imeis[source]
    if preferred_imei then
        for _, candidate in ipairs(slots) do
            if candidate.metadata and candidate.metadata.imei == preferred_imei then
                return candidate
            end
        end
    end

    table.sort(slots, function(left, right)
        local left_slot = tonumber(left.slot)
        local right_slot = tonumber(right.slot)
        if left_slot and right_slot and left_slot ~= right_slot then
            return left_slot < right_slot
        end
        return tostring(left.slot) < tostring(right.slot)
    end)

    if slots[1] then
        return slots[1]
    end

    Bridge.Debug(
        "warn",
        "[sky_phone] No phone item slot was available for source %s (%s candidates).",
        tostring(source),
        tostring(#slots)
    )
    return nil, "phone_required"
end

local function ensure_device(source, slot)
    local amount = tonumber(slot.amount or slot.count) or 0
    Bridge.Debug(
        "debug",
        "[sky_phone] Ensuring device for source %s slot=%s amount=%s existing_imei=%s inventory=%s.",
        tostring(source),
        tostring(slot.slot),
        tostring(amount),
        tostring(slot.metadata and slot.metadata.imei),
        tostring(Bridge.Inventory.GetResourceName()),
        { always = true }
    )
    if not unique_phones then
        if amount < 1 then
            return nil, "phone_slot_missing"
        end
        return map_character_device(source, slot)
    end

    if amount ~= 1 then
        Bridge.Debug("warn", "[sky_phone] Phone item in slot %s is stacked for source %s.", tostring(slot.slot), tostring(source))
        return nil, "phone_stacked"
    end

    local metadata = slot.metadata or {}
    local imei = metadata.imei
    if imei and not SkyPhoneImei.IsValid(imei) then
        Bridge.Debug("warn", "[sky_phone] Phone item in slot %s has invalid IMEI metadata.", tostring(slot.slot))
        return nil, "invalid_imei"
    end

    if not imei then
        imei = migrated_device_for_character(source)
        if imei then
            metadata.imei = imei
            local metadata_written = Bridge.Inventory.SetSlotMetadata(source, slot.slot, metadata)
            if not metadata_written then
                Bridge.Debug(
                    "error",
                    "[sky_phone] Inventory '%s' could not adopt migrated phone metadata for source %s slot %s.",
                    Bridge.Inventory.GetResourceName(),
                    tostring(source),
                    tostring(slot.slot)
                )
                return nil, "metadata_unsupported"
            end
            Bridge.Debug(
                "info",
                "[sky_phone] Adopted LB Phone migrated device %s for source %s.",
                imei,
                tostring(source),
                { always = true }
            )
            return imei
        end

        imei = reserve_imei()
        metadata.imei = imei
        Bridge.Debug(
            "debug",
            "[sky_phone] Reserved IMEI %s; writing metadata to source %s slot %s.",
            imei,
            tostring(source),
            tostring(slot.slot),
            { always = true }
        )
        local metadata_written = Bridge.Inventory.SetSlotMetadata(source, slot.slot, metadata)
        Bridge.Debug(
            "debug",
            "[sky_phone] Metadata write result for source %s slot %s IMEI %s: %s.",
            tostring(source),
            tostring(slot.slot),
            imei,
            tostring(metadata_written),
            { always = true }
        )
        if not metadata_written then
            Bridge.Database.Query("DELETE FROM `sky_phone_devices` WHERE `imei` = ?", { imei })
            Bridge.Debug(
                "error",
                "[sky_phone] Inventory '%s' could not write phone metadata for source %s slot %s.",
                Bridge.Inventory.GetResourceName(),
                tostring(source),
                tostring(slot.slot)
            )
            return nil, "metadata_unsupported"
        end
        return imei
    end

    Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_devices` (`imei`, `device_name`)
        VALUES (?, ?)
    ]], { imei, Config.Phone.DeviceName })

    return imei
end

local function load_device(imei)
    local rows = Bridge.Database.Query([[
        SELECT d.`imei`, d.`device_name`, d.`account_id`, d.`sim_id`, d.`created_at`, d.`updated_at`,
            a.`email`, s.`phone_number`, s.`sim_type`, s.`registered_at`, s.`is_virtual` AS `sim_is_virtual`
        FROM `sky_phone_devices` d
        LEFT JOIN `sky_phone_accounts` a ON a.`id` = d.`account_id`
        LEFT JOIN `sky_phone_sims` s ON s.`id` = d.`sim_id`
        WHERE d.`imei` = ?
        LIMIT 1
    ]], { imei })
    return rows[1]
end

local function load_device_data(imei)
    local rows = Bridge.Database.Query([[
        SELECT `namespace`, `payload`, `revision`
        FROM `sky_phone_device_data`
        WHERE `device_imei` = ?
    ]], { imei })
    local data = {}
    for _, row in ipairs(rows) do
        data[row.namespace] = {
            payload = json.decode(row.payload),
            revision = tonumber(row.revision) or 0,
        }
    end
    return data
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

local function security_status(imei, security, security_loaded)
    if not security_loaded then
        security = load_device_security(imei)
    end
    return {
        enabled = security ~= nil,
        length = security and tonumber(security.passcode_length) or nil,
        lockedUntil = security and tonumber(security.locked_until) or 0,
    }
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

local function account_devices(account_id, current_imei)
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

local function bootstrap(source, security, security_loaded)
    local session, error_response = SkyPhone.RequireDeviceSession(source)
    if not session then
        return nil, error_response
    end

    local device = load_device(session.imei)
    if not device then
        error(("[sky_phone] Active IMEI %s has no device row."):format(session.imei))
    end

    session.account_id = device.account_id and tonumber(device.account_id) or nil
    session.account_email = session.account_id and device.email or nil

    return {
        token = session.token,
        security = security_status(device.imei, security, security_loaded),
        device = {
            imei = device.imei,
            name = device.device_name,
            sim = device.sim_id and {
                id = device.sim_id,
                number = device.phone_number,
                removable = sim_cards_enabled and tonumber(device.sim_is_virtual) ~= 1,
                type = device.sim_type,
                registered = device.registered_at ~= nil,
            } or nil,
            data = load_device_data(device.imei),
        },
        account = device.account_id and {
            id = tonumber(device.account_id),
            email = device.email,
            devices = account_devices(device.account_id, device.imei),
        } or nil,
        notes = SkyPhoneNotes.List(device.account_id, device.imei),
        memos = SkyPhoneMemos.List(device.account_id, device.imei),
        player = {
            firstName = trim(Bridge.Framework.GetFirstname(source)) or "",
            lastName = trim(Bridge.Framework.GetLastname(source)) or "",
        },
    }
end

local function refresh_source(source)
    local payload = bootstrap(source)
    if payload then
        TriggerClientEvent("sky_phone:device:updated", source, payload)
    end
end

SkyPhone.EnsureDevice = ensure_device
SkyPhone.FindDeviceSlots = find_device_slots
SkyPhone.LoadDevice = load_device
SkyPhone.RefreshSource = refresh_source

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

    refresh_source(source)
    return {
        success = true,
        data = {
            email = account.email,
            devices = account_devices(account.id, session.imei),
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

function SkyPhone.RequireDeviceSession(source)
    local session = sessions[source]
    if not session then
        return nil, { success = false, error = "device_not_open" }
    end

    local matches = find_device_slots(source, session.imei)
    if not matches[1] then
        SkyPhoneCompanies.ClearCallAvailability(source)
        sessions[source] = nil
        TriggerClientEvent("sky_phone:device:invalidated", source)
        return nil, { success = false, error = "device_not_owned" }
    end
    session.slot = matches[1].slot
    return session
end

function SkyPhone.RequireSession(source)
    local session, error_response = SkyPhone.RequireDeviceSession(source)
    if not session then
        return nil, error_response
    end
    if not session.unlocked then
        return nil, { success = false, error = "device_locked" }
    end
    return session
end

function SkyPhone.AllowOperation(source, operation, maximum, window_seconds)
    local now = os.time()
    operation_attempts[source] = operation_attempts[source] or {}
    local attempts = operation_attempts[source][operation]
    if not attempts or now - attempts.started_at >= window_seconds then
        operation_attempts[source][operation] = { count = 1, started_at = now }
        return true
    end
    if attempts.count >= maximum then
        Bridge.Debug(
            "warn",
            "[sky_phone] Rate limit '%s' exceeded by source %s.",
            operation,
            tostring(source)
        )
        return false
    end
    attempts.count = attempts.count + 1
    return true
end

function SkyPhone.RequireAccount(source)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return nil, error_response
    end
    if not session.account_id then
        return nil, { success = false, error = "not_authenticated" }
    end
    return {
        id = session.account_id,
        email = session.account_email,
        imei = session.imei,
    }
end

function SkyPhone.NotifyAccount(account_id, event_name, data)
    for source in pairs(sessions) do
        local account = SkyPhone.RequireAccount(source)
        if account and account.id == tonumber(account_id) then
            TriggerClientEvent(event_name, source, data)
        end
    end
end

function SkyPhone.NotifyAccountDevices(account_id, event_name, data, required_app_auth)
    local rows = Bridge.Database.Query([[
        SELECT d.`imei`, d.`device_name`, account.`email` AS `account_email`,
            settings.`payload` AS `settings`, app_auth.`payload` AS `app_auth`
        FROM `sky_phone_devices` d
        JOIN `sky_phone_accounts` account ON account.`id` = d.`account_id`
        LEFT JOIN `sky_phone_device_data` settings
            ON settings.`device_imei` = d.`imei` AND settings.`namespace` = 'settings'
        LEFT JOIN `sky_phone_device_data` app_auth
            ON app_auth.`device_imei` = d.`imei` AND app_auth.`namespace` = 'appAuth'
        WHERE d.`account_id` = ?
    ]], { account_id })
    local devices = {}
    for _, row in ipairs(rows) do
        devices[row.imei] = row
    end

    local function has_required_app_session(device)
        if required_app_auth == nil then
            return true
        end
        if type(required_app_auth) ~= 'string' or type(device.app_auth) ~= 'string' then
            return false
        end
        local decoded, app_auth = pcall(json.decode, device.app_auth)
        if not decoded or type(app_auth) ~= 'table' or app_auth.version ~= 1
            or app_auth.accountEmail ~= device.account_email or type(app_auth.signedIn) ~= 'table'
        then
            return false
        end
        for _, app_id in ipairs(app_auth.signedIn) do
            if app_id == required_app_auth then
                return true
            end
        end
        return false
    end

    local function notify_device(source, device)
        if not has_required_app_session(device) then
            return
        end
        local payload = {}
        for key, value in pairs(data) do
            payload[key] = value
        end
        payload.device = {
            imei = device.imei,
            name = device.device_name,
            settings = device.settings,
        }
        TriggerClientEvent(event_name, source, payload)
    end

    for _, player_source in ipairs(Bridge.Framework.GetPlayers()) do
        local source = tonumber(player_source) or player_source
        if not unique_phones then
            if Bridge.Inventory.GetSlotsWithItem(source, Config.Phone.Item)[1] then
                local imei = load_character_device(source)
                local device = imei and devices[imei] or nil
                if device then
                    notify_device(source, device)
                end
            end
        else
            local notified_devices = {}
            for _, item in ipairs(Bridge.Inventory.GetSlotsWithItem(source, Config.Phone.Item)) do
                local imei = item.metadata and item.metadata.imei
                local device = imei and devices[imei]
                if device and not notified_devices[imei] then
                    notified_devices[imei] = true
                    notify_device(source, device)
                end
            end
        end
    end
end

function SkyPhone.RefreshAccount(account_id)
    for source in pairs(sessions) do
        local account = SkyPhone.RequireAccount(source)
        if account and account.id == tonumber(account_id) then
            refresh_source(source)
        end
    end
end

function SkyPhone.RefreshDevice(imei)
    for source, session in pairs(sessions) do
        if session.imei == imei then
            refresh_source(source)
        end
    end
end

local function open_phone(source, used_item)
    local opened_at = GetGameTimer()
    Bridge.Debug(
        "debug",
        "[sky_phone] Usable phone callback invoked for source %s.",
        tostring(source),
        { always = true }
    )
    local slot, slot_error = resolve_used_slot(source, used_item)
    if not slot then
        Bridge.Debug(
            "debug",
            "[sky_phone] Phone open rejected for source %s: %s.",
            tostring(source),
            tostring(slot_error),
            { always = true }
        )
        TriggerClientEvent("sky_phone:device:error", source, slot_error)
        return false
    end

    local imei, error_code = ensure_device(source, slot)
    if not imei then
        Bridge.Debug(
            "debug",
            "[sky_phone] Phone open rejected for source %s slot %s: %s.",
            tostring(source),
            tostring(slot.slot),
            tostring(error_code),
            { always = true }
        )
        TriggerClientEvent("sky_phone:device:error", source, error_code)
        return false
    end
    local prepared, prepare_error = SkyPhoneSim.PrepareDevice(source, slot, imei)
    if not prepared then
        Bridge.Debug(
            "error",
            "[sky_phone] Phone preparation failed for source %s IMEI %s: %s.",
            tostring(source),
            imei,
            tostring(prepare_error)
        )
        TriggerClientEvent("sky_phone:device:error", source, prepare_error or "request_failed")
        return false
    end

    local security = load_device_security(imei)
    if sessions[source] and sessions[source].imei ~= imei then
        SkyPhoneCompanies.ClearCallAvailability(source)
    end
    sessions[source] = {
        imei = imei,
        slot = slot.slot,
        token = ("%s:%s:%s"):format(imei, tostring(source), tostring(GetGameTimer())),
        unlocked = security == nil,
    }
    preferred_device_imeis[source] = imei
    local payload = bootstrap(source, security, true)
    Bridge.Debug(
        "debug",
        "[sky_phone] Triggering client open for source %s slot %s IMEI %s account_linked=%s after %sms.",
        tostring(source),
        tostring(slot.slot),
        imei,
        tostring(payload.account ~= nil),
        tostring(GetGameTimer() - opened_at),
        { always = true }
    )
    TriggerClientEvent("sky_phone:device:open", source, payload)
    return true
end

phone_open_handler = open_phone
flush_pending_phone_opens()

function SkyPhone.OpenDeviceForCall(source, imei)
    local matches = find_device_slots(source, imei)
    if not matches[1] then
        Bridge.Debug("warn", "[sky_phone] Could not open ringing device %s for source %s.", tostring(imei), tostring(source))
        return false
    end
    local security = load_device_security(imei)
    local existing_session = sessions[source]
    if existing_session and existing_session.imei ~= imei then
        SkyPhoneCompanies.ClearCallAvailability(source)
    end
    if existing_session and existing_session.imei == imei then
        existing_session.slot = matches[1].slot
    else
        sessions[source] = {
            imei = imei,
            slot = matches[1].slot,
            token = ("%s:%s:%s"):format(imei, tostring(source), tostring(GetGameTimer())),
            unlocked = security == nil,
        }
    end
    preferred_device_imeis[source] = imei
    TriggerClientEvent("sky_phone:device:open", source, bootstrap(source))
    return true
end

Bridge.Debug(
    "debug",
    "[sky_phone] Registering usable item '%s' through inventory '%s'.",
    Config.Phone.Item,
    tostring(Bridge.Inventory.GetResourceName()),
    { always = true }
)
local usable_registered = Bridge.Inventory.RegisterUsableItem(Config.Phone.Item, open_phone)
if not usable_registered then
    error(("[sky_phone] Inventory '%s' did not register phone item '%s' as usable."):format(
        tostring(Bridge.Inventory.GetResourceName()),
        tostring(Config.Phone.Item)
    ))
end
Bridge.Debug(
    "debug",
    "[sky_phone] Usable item registration returned: %s.",
    tostring(usable_registered),
    { always = true }
)

Bridge.Callbacks.Register("sky_phone:device:close", function(source)
    SkyPhoneCompanies.ClearCallAvailability(source)
    sessions[source] = nil
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:device:notification-open", function(source, data)
    if not SkyPhone.AllowOperation(source, "notification_open", 10, 60)
        or type(data) ~= "table" or type(data.imei) ~= "string"
    then
        return { success = false, error = "invalid_request" }
    end
    if not SkyPhone.OpenDeviceForCall(source, data.imei) then
        return { success = false, error = "device_not_owned" }
    end
    return { success = true }
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
        return { success = true, data = { security = security_status(session.imei) } }
    end

    local verified, verification_error = verify_passcode(session, data and data.passcode)
    if not verified then
        return verification_error
    end
    session.unlocked = true
    return { success = true, data = { security = security_status(session.imei) } }
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
    return { success = true, data = { security = security_status(session.imei) } }
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
    return { success = true, data = { security = security_status(session.imei) } }
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
    return { success = true, data = { security = security_status(session.imei) } }
end)

Bridge.Callbacks.Register("sky_phone:device:save", function(source, data)
    if not SkyPhone.AllowOperation(source, "device_save", 120, 60) then
        return { success = false, error = "rate_limited" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end
    if type(data) ~= "table" then
        return { success = false, error = "invalid_request" }
    end
    if data.imei ~= session.imei or data.sessionToken ~= session.token then
        return { success = false, error = "stale_session" }
    end
    if not allowed_device_namespaces[data.namespace] then
        return { success = false, error = "invalid_namespace" }
    end

    local encoded = json.encode(data.payload)
    if #encoded > max_device_data_bytes then
        return { success = false, error = "payload_too_large" }
    end
    local revision = math.max(0, math.floor(tonumber(data.revision) or 0))
    local rows = Bridge.Database.Query([[
        SELECT `payload`, `revision`
        FROM `sky_phone_device_data`
        WHERE `device_imei` = ? AND `namespace` = ?
        LIMIT 1
    ]], { session.imei, data.namespace })

    if rows[1] then
        local current_revision = tonumber(rows[1].revision) or 0
        if revision ~= current_revision then
            refresh_source(source)
            return {
                success = false,
                error = "conflict",
                data = { payload = json.decode(rows[1].payload), revision = current_revision },
            }
        end
        local result = Bridge.Database.Query([[
            UPDATE `sky_phone_device_data`
            SET `payload` = ?, `revision` = `revision` + 1
            WHERE `device_imei` = ? AND `namespace` = ? AND `revision` = ?
        ]], { encoded, session.imei, data.namespace, revision })
        if affected_rows(result) ~= 1 then
            refresh_source(source)
            return { success = false, error = "conflict" }
        end
        return { success = true, data = { revision = revision + 1 } }
    end

    if revision ~= 0 then
        return { success = false, error = "conflict" }
    end
    local result = Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_device_data` (`device_imei`, `namespace`, `payload`)
        VALUES (?, ?, ?)
    ]], { session.imei, data.namespace, encoded })
    if affected_rows(result) <= 0 then
        refresh_source(source)
        return { success = false, error = "conflict" }
    end
    return { success = true, data = { revision = 1 } }
end)

Bridge.Callbacks.Register("sky_phone:notifications:save", function(source, data)
    if not SkyPhone.AllowOperation(source, "notifications_save", 240, 60) then
        return { success = false, error = "rate_limited" }
    end
    if type(data) ~= "table" or not SkyPhoneImei.IsValid(data.imei) or type(data.payload) ~= "table" then
        return { success = false, error = "invalid_request" }
    end
    if #SkyPhone.FindDeviceSlots(source, data.imei) == 0 then
        Bridge.Debug(
            "warn",
            "[sky_phone] Source %s attempted to save notifications for unowned device %s.",
            tostring(source),
            tostring(data.imei)
        )
        return { success = false, error = "device_not_owned" }
    end
    if data.payload.version ~= 1 or type(data.payload.items) ~= "table" then
        return { success = false, error = "invalid_request" }
    end
    local item_count = #data.payload.items
    local key_count = 0
    for key in pairs(data.payload.items) do
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > item_count then
            return { success = false, error = "invalid_request" }
        end
        key_count = key_count + 1
    end
    if key_count ~= item_count then
        return { success = false, error = "invalid_request" }
    end
    for _, item in ipairs(data.payload.items) do
        if type(item) ~= "table"
            or type(item.appId) ~= "string" or #item.appId > 64
            or type(item.id) ~= "string" or #item.id > 100
            or type(item.title) ~= "string" or #item.title > 200
            or type(item.text) ~= "string" or #item.text > 2000
            or (item.subtitle ~= nil and (type(item.subtitle) ~= "string" or #item.subtitle > 200))
        then
            return { success = false, error = "invalid_request" }
        end
    end

    local encoded = json.encode(data.payload)
    if #encoded > max_device_data_bytes then
        return { success = false, error = "payload_too_large" }
    end
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_device_data` (`device_imei`, `namespace`, `payload`)
        VALUES (?, 'notifications', ?)
        ON DUPLICATE KEY UPDATE `payload` = VALUES(`payload`), `revision` = `revision` + 1
    ]], { data.imei, encoded })
    return { success = true }
end)

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
        refresh_source(source)
        return { success = true }
    end)
end

Bridge.Callbacks.Register("sky_phone:account:devices", function(source)
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then
        return error_response
    end
    return { success = true, data = account_devices(account.id, account.imei) }
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
    return { success = true, data = account_devices(account.id, account.imei) }
end)

Bridge.Callbacks.Register("sky_phone:device:factory-reset", function(source)
    if not SkyPhone.AllowOperation(source, "factory_reset", 3, 60) then
        return { success = false, error = "rate_limited" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end
    local media_remote_ids = SkyPhoneMedia.GetDeviceRemoteIds(session.imei)
    if not Bridge.Database.Transaction({
        {
            query = "DELETE FROM `sky_phone_device_security` WHERE `device_imei` = ?",
            params = { session.imei },
        },
        {
            query = "DELETE FROM `sky_phone_device_data` WHERE `device_imei` = ?",
            params = { session.imei },
        },
        {
            query = "DELETE FROM `sky_phone_custom_app_data` WHERE `device_imei` = ?",
            params = { session.imei },
        },
        {
            query = "DELETE FROM `sky_phone_notes` WHERE `device_imei` = ? AND `account_id` IS NULL",
            params = { session.imei },
        },
        {
            query = "DELETE FROM `sky_phone_media` WHERE `device_imei` = ? AND `account_id` IS NULL",
            params = { session.imei },
        },
        {
            query = "DELETE FROM `sky_phone_music_playlists` WHERE `device_imei` = ? AND `account_id` IS NULL",
            params = { session.imei },
        },
        {
            query = "DELETE FROM `sky_phone_music_youtube_songs` WHERE `device_imei` = ? AND `account_id` IS NULL",
            params = { session.imei },
        },
        {
            query = "DELETE FROM `sky_phone_contacts` WHERE `device_imei` = ? AND `account_id` IS NULL",
            params = { session.imei },
        },
        {
            query = "DELETE FROM `sky_phone_call_entries` WHERE `device_imei` = ? AND `account_id` IS NULL",
            params = { session.imei },
        },
        {
            query = "DELETE FROM `sky_phone_fliptok_sessions` WHERE `device_imei` = ?",
            params = { session.imei },
        },
        {
            query = "UPDATE `sky_phone_devices` SET `account_id` = NULL, `device_name` = ? WHERE `imei` = ?",
            params = { Config.Phone.DeviceName, session.imei },
        },
    }) then
        return { success = false, error = "request_failed" }
    end
    SkyPhoneMedia.CleanupRemoteFiles(media_remote_ids)
    session.unlocked = true
    refresh_source(source)
    return { success = true }
end)

AddEventHandler("playerDropped", function()
    SkyPhoneCompanies.ClearCallAvailability(source)
    sessions[source] = nil
    auth_attempts[source] = nil
    operation_attempts[source] = nil
    character_device_cache[source] = nil
    preferred_device_imeis[source] = nil
end)

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name == GetCurrentResourceName() then
        sessions = {}
        auth_attempts = {}
        operation_attempts = {}
        character_device_cache = {}
        preferred_device_imeis = {}
    end
end)
end)
