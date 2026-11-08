(SkyPhoneAppDatabase and SkyPhoneAppDatabase.Bind("banking") or function(start)
    Bridge.Database.AfterMigration("sky_phone", start)
end)(function()

local function valid_amount(value)
    local amount = tonumber(value)
    if not amount or amount ~= math.floor(amount) then
        return nil
    end
    if amount < Config.Banking.MinimumAmount or amount > Config.Banking.MaximumAmount then
        return nil
    end
    return amount
end

local function player_name(source)
    local firstname = Bridge.Framework.GetFirstname(source)
    local lastname = Bridge.Framework.GetLastname(source)
    local name = ((firstname or "") .. " " .. (lastname or "")):match("^%s*(.-)%s*$")
    if name == "" then
        name = GetPlayerName(source) or ("Player %s"):format(source)
    end
    return name
end

local function require_banking_session(source)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return nil, error_response
    end
    local identifier = Bridge.Framework.GetIdentifier(source)
    if type(identifier) ~= "string" or identifier == "" then
        return nil, { success = false, error = "banking_unavailable" }
    end
    return identifier
end

local function transaction_dto(row)
    return {
        id = tonumber(row.id),
        kind = row.kind,
        amount = tonumber(row.amount) or 0,
        label = row.label or "",
        reference = row.reference or "",
        createdAt = (tonumber(row.created_at_unix) or 0) * 1000,
    }
end

local function transactions(identifier)
    local rows = Bridge.Database.Query([[
        SELECT `id`, `kind`, `amount`, `label`, `reference`,
            UNIX_TIMESTAMP(`created_at`) AS `created_at_unix`
        FROM `sky_phone_bank_transactions`
        WHERE `owner_identifier` = ?
        ORDER BY `id` DESC
        LIMIT ?
    ]], { identifier, Config.Banking.HistoryLimit })
    local result = {}
    for _, row in ipairs(rows) do
        result[#result + 1] = transaction_dto(row)
    end
    return result
end

local function overview(source, identifier, transfer_completed)
    local provider = Config.Banking.Provider or "framework"
    local provider_failed = false
    if provider ~= "framework" and provider ~= "qs" then
        local result = Bridge.Finance.Call("banking", "overview", source)
        if Bridge.Framework.GetIdentifier(source) ~= identifier then
            return { success = false, error = "not_authorized" }
        end
        if result.success or not transfer_completed then return result end
        provider_failed = true
    end
    local data = {
        bank = math.max(0, tonumber(Bridge.Framework.GetMoney(source, "bank")) or 0),
        cash = math.max(0, tonumber(Bridge.Framework.GetMoney(source, "cash")) or 0),
        currency = Config.Banking.Currency,
        playerId = source,
        playerName = player_name(source),
        transactions = not provider_failed and transactions(identifier) or {},
        historyWarning = provider_failed or nil,
    }
    if Bridge.Framework.GetIdentifier(source) ~= identifier then
        return { success = false, error = "not_authorized" }
    end
    if provider == "qs" then
        local result = Bridge.Finance.Call("banking", "overview", source, { overview = data })
        if Bridge.Framework.GetIdentifier(source) ~= identifier then
            return { success = false, error = "not_authorized" }
        end
        if result.success or not transfer_completed then return result end
        -- The transfer is already committed. A failed statement read must not invite another payment.
        data.historyWarning = true
    end
    return { success = true, data = data }
end

local function record_transaction(identifier, kind, amount, label, reference)
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_bank_transactions`
            (`owner_identifier`, `kind`, `amount`, `label`, `reference`)
        VALUES (?, ?, ?, ?, ?)
    ]], { identifier, kind, amount, label or "", reference or "" })
end

local function notify_changed(source, data)
    TriggerClientEvent("sky_phone:banking:changed", source, data)
end

local function online_source_for_phone(number)
    local rows = Bridge.Database.Query([[
        SELECT d.`imei`
        FROM `sky_phone_sims` s
        INNER JOIN `sky_phone_devices` d ON d.`sim_id` = s.`id`
        WHERE s.`phone_number` = ?
        LIMIT 1
    ]], { number })
    local device = rows[1]
    if not device or type(device.imei) ~= "string" then
        return nil
    end
    for _, player_source in ipairs(Bridge.Framework.GetPlayers()) do
        local target = tonumber(player_source) or player_source
        if SkyPhone.FindDeviceSlots(target, device.imei)[1] then
            return target
        end
    end
    return nil
end

Bridge.Callbacks.Register("sky_phone:banking:overview", function(source)
    local identifier, error_response = require_banking_session(source)
    if not identifier then
        return error_response
    end
    return overview(source, identifier)
end)

Bridge.Callbacks.Register("sky_phone:banking:transfer", function(source, data)
    if not SkyPhone.AllowOperation(source, "banking_transaction", Config.Banking.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local identifier, error_response = require_banking_session(source)
    if not identifier then
        return error_response
    end
    local amount = valid_amount(data and data.amount)
    local number = SkyPhoneSimNumber.Normalize(data and data.phoneNumber)
    if not amount or not number then
        return { success = false, error = "invalid_request" }
    end
    local target = online_source_for_phone(number)
    if not target then
        return { success = false, error = "target_not_found" }
    end
    if target == source then
        return { success = false, error = "self_transfer" }
    end
    local target_identifier = Bridge.Framework.GetIdentifier(target)
    if type(target_identifier) ~= "string" or target_identifier == "" then
        return { success = false, error = "target_not_found" }
    end
    local provider = Config.Banking.Provider or "framework"
    local transfer = { amount = amount, target = target, senderIdentifier = identifier,
        targetIdentifier = target_identifier, senderName = player_name(source), targetName = player_name(target) }
    if (Config.Banking.Provider or "framework") ~= "framework" then
        local prepared = Bridge.Finance.Call("banking", "prepareTransfer", source, transfer)
        if not prepared.success then return prepared end
    end
    if (Config.Banking.Provider or "framework") ~= provider or Bridge.Framework.GetIdentifier(source) ~= identifier
        or Bridge.Framework.GetIdentifier(target) ~= target_identifier then
        return { success = false, error = "target_not_found" }
    end
    if not Bridge.Framework.RemoveMoney(source, "bank", amount) then
        return { success = false, error = "insufficient_funds" }
    end
    if not Bridge.Framework.AddMoney(target, "bank", amount) then
        Bridge.Framework.AddMoney(source, "bank", amount)
        return { success = false, error = "transfer_failed" }
    end

    local reference = ("phone-transfer-%s-%s"):format(os.time(), source)
    local sender_name = transfer.senderName
    local history_synced = pcall(function()
        record_transaction(identifier, "transfer_out", amount, transfer.targetName, reference)
        record_transaction(target_identifier, "transfer_in", amount, sender_name, reference)
    end)
    if not history_synced then
        Bridge.Debug("error", "[sky_phone] Transfer completed, but the Phone statement could not be updated.")
    end
    if provider ~= "framework" then
        if (Config.Banking.Provider or "framework") == provider then
            local recorded = Bridge.Finance.Call("banking", "recordTransfer", source, transfer)
            history_synced = recorded.success and history_synced
        else history_synced = false end
    end
    if Bridge.Framework.GetIdentifier(target) == target_identifier then
        notify_changed(target, {
            kind = "transfer_in", amount = amount, currency = Config.Banking.Currency, sender = sender_name,
        })
    end
    local refreshed, result = pcall(overview, source, identifier, true)
    if not refreshed or not result.success then
        Bridge.Debug("error", "[sky_phone] Transfer completed, but its statement reload failed.")
        if Bridge.Framework.GetIdentifier(source) ~= identifier then return { success = true } end
        return { success = true, data = {
            bank = Bridge.Framework.GetMoney(source, "bank"), cash = Bridge.Framework.GetMoney(source, "cash"),
            currency = Config.Banking.Currency, playerId = source, playerName = transfer.senderName,
            transactions = {}, historyWarning = true,
        } }
    end
    if result.data and not history_synced then result.data.historyWarning = true end
    return result
end)

end)
