if not Sky.DB.AwaitMigrations("sky_phone") then
    error("[sky_phone] Device database migrations did not complete.")
end

SkyPhone = {}

local sessions = {}
local auth_attempts = {}
local operation_attempts = {}

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
    for _ = 1, 20 do
        local uuid_rows = Sky.Query("SELECT UUID() AS `id`", {})
        local uuid = uuid_rows[1] and uuid_rows[1].id
        if type(uuid) ~= "string" then
            error("[sky_phone] Database did not generate entropy for an IMEI.")
        end

        local imei = SkyPhoneImei.FromEntropy(uuid)
        local result = Sky.Query([[
            INSERT IGNORE INTO `sky_phone_devices` (`imei`, `device_name`)
            VALUES (?, ?)
        ]], { imei, Config.Phone.DeviceName })
        if affected_rows(result) > 0 then
            return imei
        end
    end

    error("[sky_phone] Could not generate a unique IMEI after 20 attempts.")
end

local function find_device_slots(source, imei)
    local matches = {}
    for _, item in ipairs(Sky.FW.GetInventorySlotsWithItem(source, Config.Phone.Item)) do
        if item.metadata and item.metadata.imei == imei then
            matches[#matches + 1] = item
        end
    end

    if #matches > 1 then
        Sky.Debug(
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
    local slot_id = tonumber(used_item and (used_item.slot or used_item.id))
    if slot_id then
        local slot = Sky.FW.GetInventorySlot(source, slot_id)
        if slot and slot.name == Config.Phone.Item then
            return slot
        end
    end

    local slots = Sky.FW.GetInventorySlotsWithItem(source, Config.Phone.Item)
    if #slots == 1 then
        return slots[1]
    end

    Sky.Debug(
        "warn",
        "[sky_phone] Usable item callback did not identify an exact phone slot for source %s (%s candidates).",
        tostring(source),
        tostring(#slots)
    )
    return nil
end

local function ensure_device(source, slot)
    if (tonumber(slot.amount or slot.count) or 0) ~= 1 then
        Sky.Debug("warn", "[sky_phone] Phone item in slot %s is stacked for source %s.", tostring(slot.slot), tostring(source))
        return nil, "phone_stacked"
    end

    local metadata = slot.metadata or {}
    local imei = metadata.imei
    if imei and not SkyPhoneImei.IsValid(imei) then
        Sky.Debug("warn", "[sky_phone] Phone item in slot %s has invalid IMEI metadata.", tostring(slot.slot))
        return nil, "invalid_imei"
    end

    if not imei then
        imei = reserve_imei()
        metadata.imei = imei
        if not Sky.FW.SetInventorySlotMetadata(source, slot.slot, metadata) then
            Sky.Query("DELETE FROM `sky_phone_devices` WHERE `imei` = ?", { imei })
            Sky.Debug(
                "error",
                "[sky_phone] Inventory '%s' could not write phone metadata for source %s slot %s.",
                Sky.FW.GetResourceName(),
                tostring(source),
                tostring(slot.slot)
            )
            return nil, "metadata_unsupported"
        end
        return imei
    end

    Sky.Query([[
        INSERT IGNORE INTO `sky_phone_devices` (`imei`, `device_name`)
        VALUES (?, ?)
    ]], { imei, Config.Phone.DeviceName })

    return imei
end

local function load_device(imei)
    local rows = Sky.Query([[
        SELECT d.`imei`, d.`device_name`, d.`account_id`, d.`created_at`, d.`updated_at`, a.`email`
        FROM `sky_phone_devices` d
        LEFT JOIN `sky_phone_accounts` a ON a.`id` = d.`account_id`
        WHERE d.`imei` = ?
        LIMIT 1
    ]], { imei })
    return rows[1]
end

local function load_device_data(imei)
    local rows = Sky.Query([[
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

local function account_devices(account_id, current_imei)
    local rows = Sky.Query([[
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

local function bootstrap(source)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return nil, error_response
    end

    local device = load_device(session.imei)
    if not device then
        error(("[sky_phone] Active IMEI %s has no device row."):format(session.imei))
    end

    return {
        token = session.token,
        device = {
            imei = device.imei,
            name = device.device_name,
            data = load_device_data(device.imei),
        },
        account = device.account_id and {
            id = tonumber(device.account_id),
            email = device.email,
            devices = account_devices(device.account_id, device.imei),
        } or nil,
        notes = SkyPhoneNotes.List(device.account_id, device.imei),
    }
end

local function refresh_source(source)
    local payload = bootstrap(source)
    if payload then
        TriggerClientEvent("sky_phone:device:updated", source, payload)
    end
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

local function link_account(source, account)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end

    if not Sky.DB.Transaction({
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
        local result = Sky.Query(
            "INSERT IGNORE INTO `sky_phone_accounts` (`email`, `password`) VALUES (?, ?)",
            { email, password }
        )
        if affected_rows(result) == 0 then
            return { success = false, error = "email_taken" }
        end
    end

    local accounts = Sky.Query(
        "SELECT `id`, `email` FROM `sky_phone_accounts` WHERE `email` = ? AND `password` = ? LIMIT 1",
        { email, password }
    )
    if not accounts[1] then
        return { success = false, error = "invalid_credentials" }
    end
    return link_account(source, accounts[1])
end

function SkyPhone.RequireSession(source)
    local session = sessions[source]
    if not session then
        return nil, { success = false, error = "device_not_open" }
    end

    local matches = find_device_slots(source, session.imei)
    if not matches[1] then
        sessions[source] = nil
        TriggerClientEvent("sky_phone:device:invalidated", source)
        return nil, { success = false, error = "device_not_owned" }
    end
    session.slot = matches[1].slot
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
        Sky.Debug(
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
    local device = load_device(session.imei)
    if not device or not device.account_id then
        return nil, { success = false, error = "not_authenticated" }
    end
    return {
        id = tonumber(device.account_id),
        email = device.email,
        imei = device.imei,
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
    local slot = resolve_used_slot(source, used_item)
    if not slot then
        TriggerClientEvent("sky_phone:device:error", source, "phone_slot_missing")
        return false
    end

    local imei, error_code = ensure_device(source, slot)
    if not imei then
        TriggerClientEvent("sky_phone:device:error", source, error_code)
        return false
    end

    sessions[source] = {
        imei = imei,
        slot = slot.slot,
        token = ("%s:%s:%s"):format(imei, tostring(source), tostring(GetGameTimer())),
    }
    local payload = bootstrap(source)
    TriggerClientEvent("sky_phone:device:open", source, payload)
    return true
end

Sky.FW.RegisterUsableItem(Config.Phone.Item, open_phone)

Sky.Cb.Register("sky_phone:device:close", function(source)
    sessions[source] = nil
    return { success = true }
end)

Sky.Cb.Register("sky_phone:device:development-open", function(source)
    if not Config.Phone.DevelopmentCommand then
        return { success = false, error = "disabled" }
    end
    return { success = open_phone(source, nil) }
end)

Sky.Cb.Register("sky_phone:device:save", function(source, data)
    if not SkyPhone.AllowOperation(source, "device_save", 120, 60) then
        return { success = false, error = "rate_limited" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end
    if type(data) ~= "table" or not Config.Phone.AllowedDeviceNamespaces[data.namespace] then
        return { success = false, error = "invalid_namespace" }
    end

    local encoded = json.encode(data.payload)
    if #encoded > Config.Phone.MaxDeviceDataBytes then
        return { success = false, error = "payload_too_large" }
    end
    local revision = math.max(0, math.floor(tonumber(data.revision) or 0))
    local rows = Sky.Query([[
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
        local result = Sky.Query([[
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
    local result = Sky.Query([[
        INSERT IGNORE INTO `sky_phone_device_data` (`device_imei`, `namespace`, `payload`)
        VALUES (?, ?, ?)
    ]], { session.imei, data.namespace, encoded })
    if affected_rows(result) <= 0 then
        refresh_source(source)
        return { success = false, error = "conflict" }
    end
    return { success = true, data = { revision = 1 } }
end)

for _, endpoint in ipairs({ "account:login", "mail:login" }) do
    Sky.Cb.Register("sky_phone:" .. endpoint, function(source, data)
        return authenticate(source, data, false)
    end)
end

for _, endpoint in ipairs({ "account:register", "mail:register" }) do
    Sky.Cb.Register("sky_phone:" .. endpoint, function(source, data)
        return authenticate(source, data, true)
    end)
end

for _, endpoint in ipairs({ "account:logout", "mail:logout" }) do
    Sky.Cb.Register("sky_phone:" .. endpoint, function(source)
        local account, error_response = SkyPhone.RequireAccount(source)
        if not account then
            return error_response
        end
        Sky.Query("UPDATE `sky_phone_devices` SET `account_id` = NULL WHERE `imei` = ?", { account.imei })
        refresh_source(source)
        return { success = true }
    end)
end

Sky.Cb.Register("sky_phone:account:devices", function(source)
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then
        return error_response
    end
    return { success = true, data = account_devices(account.id, account.imei) }
end)

Sky.Cb.Register("sky_phone:account:remove-device", function(source, data)
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
    local passwords = Sky.Query("SELECT `id` FROM `sky_phone_accounts` WHERE `id` = ? AND `password` = ? LIMIT 1", {
        account.id,
        data.password,
    })
    if not passwords[1] then
        return { success = false, error = "invalid_credentials" }
    end
    local result = Sky.Query(
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

Sky.Cb.Register("sky_phone:device:factory-reset", function(source)
    if not SkyPhone.AllowOperation(source, "factory_reset", 3, 60) then
        return { success = false, error = "rate_limited" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end
    if not Sky.DB.Transaction({
        {
            query = "DELETE FROM `sky_phone_device_data` WHERE `device_imei` = ?",
            params = { session.imei },
        },
        {
            query = "DELETE FROM `sky_phone_notes` WHERE `device_imei` = ? AND `account_id` IS NULL",
            params = { session.imei },
        },
        {
            query = "UPDATE `sky_phone_devices` SET `account_id` = NULL, `device_name` = ? WHERE `imei` = ?",
            params = { Config.Phone.DeviceName, session.imei },
        },
    }) then
        return { success = false, error = "request_failed" }
    end
    refresh_source(source)
    return { success = true }
end)

AddEventHandler("playerDropped", function()
    sessions[source] = nil
    auth_attempts[source] = nil
    operation_attempts[source] = nil
end)

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name == GetCurrentResourceName() then
        sessions = {}
        auth_attempts = {}
        operation_attempts = {}
    end
end)
