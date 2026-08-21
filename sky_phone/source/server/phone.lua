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

    local success, error_code = phone_open_handler(source, nil)
    return { success = success, error = error_code }
end)

Bridge.Callbacks.Register("sky_phone:device:development-open", function(source)
    if not Config.Phone.DevelopmentCommand then
        return { success = false, error = "disabled" }
    end
    if not server_started or not phone_open_handler then
        pending_phone_opens[source] = true
        return { success = true, data = { queued = true } }
    end

    local success, error_code = phone_open_handler(source, nil)
    return { success = success, error = error_code }
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
local equipped_phone_numbers = {}
local equipped_phone_identifiers = {}
local equipped_phone_sources = {}
local operation_attempts = {}
local character_device_cache = {}

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

local function discard_equipped_phone_number(source)
    local phone_number = equipped_phone_numbers[source]
    local identifier = equipped_phone_identifiers[source]
    equipped_phone_numbers[source] = nil
    equipped_phone_identifiers[source] = nil
    if identifier then
        equipped_phone_numbers[identifier] = nil
    end
    if phone_number and equipped_phone_sources[phone_number] == source then
        equipped_phone_sources[phone_number] = nil
    end
    return phone_number
end

local function cache_equipped_phone_number(source, identifier, phone_number)
    local previous_number = discard_equipped_phone_number(source)
    equipped_phone_identifiers[source] = identifier
    equipped_phone_numbers[source] = phone_number
    if identifier then
        equipped_phone_numbers[identifier] = phone_number
    end
    if phone_number then
        equipped_phone_sources[phone_number] = source
    end
    if previous_number ~= phone_number then
        TriggerEvent("sky_phone:server:phoneNumberChanged", source, phone_number)
    end
end

local function remove_equipped_phone_number(source)
    local previous_number = discard_equipped_phone_number(source)
    if previous_number then
        TriggerEvent("sky_phone:server:phoneNumberChanged", source, nil)
    end
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
        WHERE mapping.`owner_identifier` = ?
        ORDER BY mapping.`created_at` DESC
        LIMIT 1
    ]], { identifier })
    local imei = rows[1] and rows[1].device_imei or nil
    if imei and not SkyPhoneImei.IsValid(imei) then
        Bridge.Debug(
            "error",
            "[sky_phone] Phone migration mapping contains invalid IMEI '%s' for '%s'.",
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
        "[sky_phone] Inventory '%s' returned no '%s' phone item for source %s. This is an item/configuration problem, not a missing SIM card.",
        tostring(Bridge.Inventory.GetResourceName()),
        tostring(Config.Phone.Item),
        tostring(source)
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

    local identifier = character_identifier(source)
    cache_equipped_phone_number(source, identifier, device.phone_number)

    return {
        token = session.token,
        security = SkyPhoneSecurity.Status(device.imei, security, security_loaded),
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
            devices = SkyPhoneAccounts.List(device.account_id, device.imei),
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

local function online_source_for_identifier(identifier)
    for _, player in ipairs(GetPlayers()) do
        local player_source = tonumber(player)
        if player_source and character_identifier(player_source) == identifier then
            return player_source
        end
    end
    return nil
end

local function resolve_equipped_phone_number(source)
    local identifier = character_identifier(source)
    if not identifier then
        return nil
    end

    local slots = Bridge.Inventory.GetSlotsWithItem(source, Config.Phone.Item)
    if not slots[1] then
        remove_equipped_phone_number(source)
        return nil
    end

    local imei
    if unique_phones then
        table.sort(slots, function(left, right)
            local left_slot = tonumber(left.slot)
            local right_slot = tonumber(right.slot)
            if left_slot and right_slot and left_slot ~= right_slot then
                return left_slot < right_slot
            end
            return tostring(left.slot) < tostring(right.slot)
        end)

        local preferred_imei = preferred_device_imeis[source]
        for _, slot in ipairs(slots) do
            local amount = tonumber(slot.amount or slot.count) or 0
            local slot_imei = slot.metadata and slot.metadata.imei or nil
            if amount == 1 and SkyPhoneImei.IsValid(slot_imei) then
                if slot_imei == preferred_imei then
                    imei = slot_imei
                    break
                end
                imei = imei or slot_imei
            end
        end
    else
        imei = load_character_device(source, identifier)
    end

    if not imei then
        remove_equipped_phone_number(source)
        return nil
    end

    local device = load_device(imei)
    local phone_number = device and device.phone_number or nil
    cache_equipped_phone_number(source, identifier, phone_number)
    return phone_number
end

function SkyPhone.GetEquippedPhoneNumber(player)
    if type(player) == "number" then
        if player <= 0 or player ~= math.floor(player) then
            return nil
        end
        return resolve_equipped_phone_number(player)
    end
    if type(player) ~= "string" or player == "" then
        return nil
    end

    local player_source = online_source_for_identifier(player)
    return player_source and resolve_equipped_phone_number(player_source) or nil
end

function SkyPhone.GetSourceFromNumber(phone_number)
    local normalized = SkyPhoneSimNumber.Normalize(
        phone_number,
        Config.Sim.NumberLength,
        Config.Sim.NumberPrefix
    )
    if not normalized then
        return nil
    end

    local player_source = equipped_phone_sources[normalized]
    if player_source and resolve_equipped_phone_number(player_source) == normalized then
        return player_source
    end
    for _, player in ipairs(GetPlayers()) do
        player_source = tonumber(player)
        if player_source and resolve_equipped_phone_number(player_source) == normalized then
            return player_source
        end
    end
    return nil
end

function SkyPhone.FormatNumber(phone_number)
    return SkyPhoneSimNumber.Format(
        phone_number,
        Config.Sim.NumberGroups,
        Config.Sim.NumberLength,
        Config.Sim.NumberPrefix
    )
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
        remove_equipped_phone_number(source)
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

function SkyPhone.NotifyAccountDevices(account_id, event_name, data)
    local rows = Bridge.Database.Query([[
        SELECT d.`imei`, d.`device_name`, settings.`payload` AS `settings`
        FROM `sky_phone_devices` d
        LEFT JOIN `sky_phone_device_data` settings
            ON settings.`device_imei` = d.`imei` AND settings.`namespace` = 'settings'
        WHERE d.`account_id` = ?
    ]], { account_id })
    local devices = {}
    for _, row in ipairs(rows) do
        devices[row.imei] = row
    end

    local function notify_device(source, device)
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
        return false, slot_error
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
        return false, error_code
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
        local error_code = prepare_error or "request_failed"
        TriggerClientEvent("sky_phone:device:error", source, error_code)
        return false, error_code
    end

    local security = SkyPhoneSecurity.Load(imei)
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
    local payload, bootstrap_error = bootstrap(source, security, true)
    if not payload then
        local error_code = type(bootstrap_error) == "table" and bootstrap_error.error or "request_failed"
        Bridge.Debug(
            "error",
            "[sky_phone] Phone bootstrap failed for source %s slot %s IMEI %s: %s.",
            tostring(source),
            tostring(slot.slot),
            imei,
            tostring(error_code)
        )
        TriggerClientEvent("sky_phone:device:error", source, error_code)
        return false, error_code
    end
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
    local security = SkyPhoneSecurity.Load(imei)
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
    local payload, bootstrap_error = bootstrap(source)
    if not payload then
        Bridge.Debug(
            "error",
            "[sky_phone] Call notification bootstrap failed for source %s IMEI %s: %s.",
            tostring(source),
            tostring(imei),
            tostring(type(bootstrap_error) == "table" and bootstrap_error.error or "request_failed")
        )
        return false
    end
    TriggerClientEvent("sky_phone:device:open", source, payload)
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
    sessions[source] = nil
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:device:equipped-number", function(source)
    return {
        success = true,
        data = { phoneNumber = SkyPhone.GetEquippedPhoneNumber(source) },
    }
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

AddEventHandler("playerDropped", function()
    SkyPhoneCompanies.ClearCallAvailability(source)
    sessions[source] = nil
    discard_equipped_phone_number(source)
    operation_attempts[source] = nil
    character_device_cache[source] = nil
    preferred_device_imeis[source] = nil
end)

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name == GetCurrentResourceName() then
        sessions = {}
        operation_attempts = {}
        character_device_cache = {}
        preferred_device_imeis = {}
        equipped_phone_numbers = {}
        equipped_phone_identifiers = {}
        equipped_phone_sources = {}
    end
end)
end)
