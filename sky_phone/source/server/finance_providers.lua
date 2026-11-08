-- Providers keep their own ledger and authorization. Phone owns the device session.
Bridge.Finance = {}
local providers = { billing = {}, banking = {} }
local actions = {
    billing = { overview = true, list = true, detail = true, markRead = true, pay = true, dispute = true },
    banking = { overview = true, prepareTransfer = true, recordTransfer = true, recordPayment = true },
}

exports("RegisterFinanceProvider", function(kind, endpoint)
    local owner = GetInvokingResource()
    if not providers[kind] or not owner or type(endpoint) ~= "string"
        or #endpoint > 64 or not endpoint:match("^[%w_]+$") then
        return false, "invalid_provider"
    end
    providers[kind][owner] = endpoint
    return true
end)

exports("NotifyFinanceChanged", function(kind, player)
    local owner = GetInvokingResource()
    local config = kind == "billing" and Config.Billing or Config.Banking
    if not providers[kind] or not providers[kind][owner] or config.Provider ~= owner
        or type(player) ~= "number" or player % 1 ~= 0 or (player <= 0 and player ~= -1) then return false end
    TriggerClientEvent("sky_phone:" .. kind .. ":changed", player)
    return true
end)

function Bridge.Finance.Call(kind, action, source, data)
    local config = kind == "billing" and Config.Billing or Config.Banking
    local provider = config.Provider
    if not actions[kind] or not actions[kind][action] then
        return { success = false, error = "invalid_request" }
    end
    data = type(data) == "table" and data or {}
    if kind == "billing" and action ~= "overview" and action ~= "list" then
        local prefix = provider .. ":"
        if type(data.id) ~= "string" or data.id:sub(1, #prefix) ~= prefix then
            return { success = false, error = "invoice_not_found" }
        end
        local request = {}
        for key, value in pairs(data) do request[key] = value end
        request.id = data.id:sub(#prefix + 1)
        data = request
    end
    local quasar = kind == "banking" and provider == "qs"
    local endpoint = providers[kind][provider]
    if not quasar and (not endpoint or GetResourceState(provider) ~= "started") then
        Bridge.Debug("warn", "[sky_phone] Finance provider %s (%s) is unavailable.", tostring(provider), kind)
        return { success = false, error = kind .. "_unavailable" }
    end
    local identifier = Bridge.Framework.GetIdentifier(source)
    if not identifier then return { success = false, error = "not_authorized" } end
    local ok, result = pcall(function()
        if quasar then return Bridge.Finance.Quasar(source, action, data or {}) end
        local resource_exports = exports[provider]
        return resource_exports[endpoint](resource_exports, source, action, data or {})
    end)
    if not ok or type(result) ~= "table" or type(result.success) ~= "boolean" then
        -- A failed reply may follow a committed payment. Never retry or switch ledgers.
        Bridge.Debug("error", "[sky_phone] Finance provider %s failed during %s; outcome may be unknown.", provider, action)
        return { success = false, error = action == "pay" and "payment_unknown" or "request_failed" }
    end
    if Bridge.Framework.GetIdentifier(source) ~= identifier then
        return { success = false, error = "not_authorized" }
    end
    if (kind == "billing" and Config.Billing or Config.Banking).Provider ~= provider then
        return { success = false, error = action == "pay" and "payment_unknown" or "request_failed" }
    end
    if result.success and kind == "billing" then
        local body = result.data
        if type(body) ~= "table" or (action == "detail" or action == "pay") and not body.id then
            return { success = false, error = action == "pay" and "payment_unknown" or "request_failed" }
        end
        if body.id then body.id = provider .. ":" .. tostring(body.id) end
        for _, collection in ipairs({ body.invoices or {}, body.urgentInvoices or {} }) do
            for _, invoice in ipairs(collection) do invoice.id = provider .. ":" .. tostring(invoice.id) end
        end
    end
    return result
end

function Bridge.Finance.RecordInvoicePayment(source, amount, label, reference, record_phone)
    local identifier = Bridge.Framework.GetIdentifier(source)
    if not identifier or type(amount) ~= "number" or not (amount > 0 and amount < math.huge) then return false end
    local saved = true
    if record_phone then
        saved = pcall(Bridge.Database.Query, [[
            INSERT INTO sky_phone_bank_transactions (owner_identifier, kind, amount, label, reference)
            VALUES (?, 'withdrawal', ?, ?, ?)
        ]], { identifier, amount, label or "", reference })
    end
    if Bridge.Framework.GetIdentifier(source) ~= identifier then return false end
    if (Config.Banking.Provider or "framework") ~= "framework" then
        local result = Bridge.Finance.Call("banking", "recordPayment", source,
            { senderIdentifier = identifier, amount = amount, label = label or "", reference = reference })
        saved = result.success and saved
    end
    if not saved then Bridge.Debug("error", "[sky_phone] Invoice paid, but its bank statement update failed.") end
    return saved
end

local selected = { billing = Config.Billing.Provider, banking = Config.Banking.Provider }
AddEventHandler("sky_phone:configurator:serverUpdated", function()
    for kind, previous in pairs(selected) do
        local current = (kind == "billing" and Config.Billing or Config.Banking).Provider
        if current ~= previous then
            selected[kind] = current
            TriggerClientEvent("sky_phone:" .. kind .. ":changed", -1)
        end
    end
end)

AddEventHandler("onResourceStop", function(resource)
    for _, entries in pairs(providers) do entries[resource] = nil end
end)

-- Registration uses fresh export names, never retained cross-resource function references.
AddEventHandler("onResourceStart", function(resource)
    if resource == GetCurrentResourceName() then TriggerEvent("sky_phone:server:financeReady") end
end)
