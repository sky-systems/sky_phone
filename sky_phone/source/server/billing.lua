Bridge.Database.AfterMigration("sky_phone", function()

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end
    return type(result) == "table" and tonumber(result.affectedRows) or 0
end

local function uuid()
    local rows = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    if not rows[1] or type(rows[1].id) ~= "string" then
        error("[sky_phone] Database did not generate a Billing UUID.")
    end
    return rows[1].id
end

local function trimmed(value, maximum_length)
    if type(value) ~= "string" then
        return nil
    end
    local result = value:match("^%s*(.-)%s*$")
    if result == "" or #result > maximum_length then
        return nil
    end
    return result
end

local function valid_amount(value)
    local amount = tonumber(value)
    if not amount or amount ~= math.floor(amount) then
        return nil
    end
    if amount < Config.Billing.MinimumAmount or amount > Config.Billing.MaximumAmount then
        return nil
    end
    return amount
end

local function valid_invoice_id(value)
    return type(value) == "string" and #value == 36 and value:match("^[0-9a-fA-F%-]+$") ~= nil
end

local function require_billing_session(source)
    if not Config.Billing.Enabled then
        return nil, { success = false, error = "billing_unavailable" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return nil, error_response
    end
    local identifier = Bridge.Framework.GetIdentifier(source)
    if type(identifier) ~= "string" or identifier == "" then
        return nil, { success = false, error = "billing_unavailable" }
    end
    return identifier
end

local function invoice_dto(row, identifier)
    local due_at = tonumber(row.due_at_unix)
    local paid_at = tonumber(row.paid_at_unix)
    local issued_at = tonumber(row.issued_at_unix) or 0
    local direction = row.recipient_identifier == identifier and "inbox" or "sent"
    local status = row.status or "open"
    return {
        id = row.id,
        amount = tonumber(row.amount) or 0,
        currency = row.currency or Config.Billing.Currency,
        description = row.description or "",
        direction = direction,
        dueAt = due_at and due_at * 1000 or nil,
        issuedAt = issued_at * 1000,
        issuerAccount = row.issuer_account or "",
        issuerLabel = row.issuer_label or "",
        isOverdue = status == "open" and due_at ~= nil and due_at < os.time(),
        isUnread = direction == "inbox" and row.read_at == nil,
        paidAt = paid_at and paid_at * 1000 or nil,
        paymentReference = row.payment_reference or "",
        status = status,
        title = row.title or "",
        canPay = direction == "inbox" and status == "open",
        canDispute = direction == "inbox" and status == "open" and Config.Billing.AllowDisputes,
    }
end

local function invoice_select(where_sql, parameters)
    local rows = Bridge.Database.Query(([=[
        SELECT `id`, `recipient_identifier`, `issuer_identifier`, `issuer_account`, `issuer_label`,
            `title`, `description`, `amount`, `currency`, `status`, `read_at`, `payment_reference`,
            UNIX_TIMESTAMP(`issued_at`) AS `issued_at_unix`,
            UNIX_TIMESTAMP(`due_at`) AS `due_at_unix`,
            UNIX_TIMESTAMP(`paid_at`) AS `paid_at_unix`
        FROM `sky_phone_billing_invoices`
        WHERE %s
    ]=]):format(where_sql), parameters)
    return rows
end

local function find_owned_invoice(id, identifier)
    if not valid_invoice_id(id) then
        return nil
    end
    return invoice_select("`id` = ? AND (`recipient_identifier` = ? OR `issuer_identifier` = ?) LIMIT 1", {
        id, identifier, identifier,
    })[1]
end

local function unread_count(identifier)
    local rows = Bridge.Database.Query([[
        SELECT COUNT(*) AS `count`
        FROM `sky_phone_billing_invoices`
        WHERE `recipient_identifier` = ? AND `read_at` IS NULL
    ]], { identifier })
    return tonumber(rows[1] and rows[1].count) or 0
end

local function notify_identifier(identifier, event_name, data)
    for _, player_source in ipairs(Bridge.Framework.GetPlayers()) do
        local target = tonumber(player_source) or player_source
        if Bridge.Framework.GetIdentifier(target) == identifier then
            TriggerClientEvent(event_name, target, data or {})
        end
    end
end

local function create_invoice(data)
    if not Config.Billing.Enabled or type(data) ~= "table" then
        return nil, "billing_unavailable"
    end
    local recipient_identifier = trimmed(data.recipientIdentifier, 80)
    if not recipient_identifier and tonumber(data.recipientSource) then
        recipient_identifier = Bridge.Framework.GetIdentifier(tonumber(data.recipientSource))
    end
    local issuer_identifier = trimmed(data.issuerIdentifier, 80) or ""
    if issuer_identifier == "" and tonumber(data.issuerSource) then
        issuer_identifier = Bridge.Framework.GetIdentifier(tonumber(data.issuerSource)) or ""
    end
    local issuer_account = trimmed(data.issuerAccount, 80)
    local issuer_label = trimmed(data.issuerLabel, 80)
    local title = trimmed(data.title, Config.Billing.MaximumTitleLength)
    local description = type(data.description) == "string" and data.description:match("^%s*(.-)%s*$") or ""
    local amount = valid_amount(data.amount)
    if not recipient_identifier or not issuer_account or not issuer_label or not title or not amount
        or #description > Config.Billing.MaximumDescriptionLength then
        return nil, "invalid_request"
    end
    local due_days = math.max(0, math.min(365, math.floor(tonumber(data.dueDays) or Config.Billing.DefaultDueDays)))
    local id = uuid()
    local result = Bridge.Database.Query([[
        INSERT INTO `sky_phone_billing_invoices`
            (`id`, `recipient_identifier`, `issuer_identifier`, `issuer_account`, `issuer_label`,
             `title`, `description`, `amount`, `currency`, `due_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? DAY))
    ]], {
        id, recipient_identifier, issuer_identifier, issuer_account, issuer_label,
        title, description, amount, Config.Billing.Currency, due_days,
    })
    if affected_rows(result) ~= 1 then
        return nil, "request_failed"
    end
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_billing_events` (`invoice_id`, `event`, `actor_identifier`)
        VALUES (?, 'created', ?)
    ]], { id, issuer_identifier })
    notify_identifier(recipient_identifier, "sky_phone:billing:new", {
        amount = amount,
        issuer = issuer_label,
    })
    if SkyPhoneLog then
        SkyPhoneLog.Record("Billing", "billing:created", "created", tonumber(data.issuerSource), {
            id = id, title = title, description = description, amount = amount,
            currency = Config.Billing.Currency, issuer = issuer_label, issuerAccount = issuer_account,
            recipientSource = tonumber(data.recipientSource), dueDays = due_days,
            resource = GetInvokingResource(),
        })
    end
    return id
end

Bridge.Callbacks.Register("sky_phone:billing:overview", function(source, data)
    local identifier, error_response = require_billing_session(source)
    if not identifier then
        return error_response
    end
    local direction = data and data.direction == "sent" and "sent" or "inbox"
    local owner_column = direction == "sent" and "issuer_identifier" or "recipient_identifier"
    local rows = Bridge.Database.Query(([=[
        SELECT COUNT(CASE WHEN `status` = 'open' THEN 1 END) AS `open_count`,
            COALESCE(SUM(CASE WHEN `status` = 'open' THEN `amount` ELSE 0 END), 0) AS `open_total`,
            COUNT(CASE WHEN `status` = 'open' AND `due_at` < NOW() THEN 1 END) AS `overdue_count`
        FROM `sky_phone_billing_invoices`
        WHERE `%s` = ?
    ]=]):format(owner_column), { identifier })
    local summary = rows[1] or {}
    local urgent_rows = invoice_select(("`%s` = ? AND `status` = 'open' ORDER BY (`due_at` IS NULL), `due_at`, `id` DESC LIMIT ?"):format(owner_column), {
        identifier, Config.Billing.UrgentLimit,
    })
    local urgent = {}
    for _, row in ipairs(urgent_rows) do
        urgent[#urgent + 1] = invoice_dto(row, identifier)
    end
    return {
        success = true,
        data = {
            currency = Config.Billing.Currency,
            openCount = tonumber(summary.open_count) or 0,
            openTotal = tonumber(summary.open_total) or 0,
            overdueCount = tonumber(summary.overdue_count) or 0,
            supportsDisputes = Config.Billing.AllowDisputes,
            supportsSent = true,
            unreadCount = unread_count(identifier),
            urgentInvoices = urgent,
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:billing:list", function(source, data)
    local identifier, error_response = require_billing_session(source)
    if not identifier then
        return error_response
    end
    local direction = data and data.direction == "sent" and "sent" or "inbox"
    local filter = type(data and data.filter) == "string" and data.filter or "all"
    if filter ~= "all" and filter ~= "open" and filter ~= "overdue" and filter ~= "paid" then
        return { success = false, error = "invalid_request" }
    end
    local offset = math.max(0, math.floor(tonumber(data and data.offset) or 0))
    local search = type(data and data.search) == "string" and data.search:sub(1, 80) or ""
    local owner_column = direction == "sent" and "issuer_identifier" or "recipient_identifier"
    local where = { ("`%s` = ?"):format(owner_column) }
    local parameters = { identifier }
    if filter == "open" then
        where[#where + 1] = "`status` = 'open'"
    elseif filter == "overdue" then
        where[#where + 1] = "`status` = 'open' AND `due_at` < NOW()"
    elseif filter == "paid" then
        where[#where + 1] = "`status` IN ('paid', 'disputed', 'cancelled', 'refunded')"
    end
    if search ~= "" then
        where[#where + 1] = "(`title` LIKE ? OR `issuer_label` LIKE ? OR `description` LIKE ?)"
        local pattern = "%" .. search .. "%"
        parameters[#parameters + 1] = pattern
        parameters[#parameters + 1] = pattern
        parameters[#parameters + 1] = pattern
    end
    parameters[#parameters + 1] = Config.Billing.PageSize + 1
    parameters[#parameters + 1] = offset
    local rows = invoice_select(table.concat(where, " AND ") .. " ORDER BY `issued_at` DESC, `id` DESC LIMIT ? OFFSET ?", parameters)
    local has_more = #rows > Config.Billing.PageSize
    if has_more then
        rows[#rows] = nil
    end
    local invoices = {}
    for _, row in ipairs(rows) do
        invoices[#invoices + 1] = invoice_dto(row, identifier)
    end
    return {
        success = true,
        data = { invoices = invoices, hasMore = has_more, nextOffset = offset + #invoices },
    }
end)

Bridge.Callbacks.Register("sky_phone:billing:detail", function(source, data)
    local identifier, error_response = require_billing_session(source)
    if not identifier then
        return error_response
    end
    local row = find_owned_invoice(data and data.id, identifier)
    if not row then
        return { success = false, error = "invoice_not_found" }
    end
    return { success = true, data = invoice_dto(row, identifier) }
end)

Bridge.Callbacks.Register("sky_phone:billing:markRead", function(source, data)
    local identifier, error_response = require_billing_session(source)
    if not identifier then
        return error_response
    end
    if not valid_invoice_id(data and data.id) then
        return { success = false, error = "invoice_not_found" }
    end
    Bridge.Database.Query([[
        UPDATE `sky_phone_billing_invoices` SET `read_at` = COALESCE(`read_at`, NOW())
        WHERE `id` = ? AND `recipient_identifier` = ?
    ]], { data and data.id, identifier })
    return { success = true, data = { unreadCount = unread_count(identifier) } }
end)

Bridge.Callbacks.Register("sky_phone:billing:dispute", function(source, data)
    if not Config.Billing.AllowDisputes then
        return { success = false, error = "dispute_unavailable" }
    end
    local identifier, error_response = require_billing_session(source)
    if not identifier then
        return error_response
    end
    if not valid_invoice_id(data and data.id) then
        return { success = false, error = "invoice_not_found" }
    end
    local result = Bridge.Database.Query([[
        UPDATE `sky_phone_billing_invoices` SET `status` = 'disputed', `read_at` = COALESCE(`read_at`, NOW())
        WHERE `id` = ? AND `recipient_identifier` = ? AND `status` = 'open'
    ]], { data and data.id, identifier })
    if affected_rows(result) ~= 1 then
        return { success = false, error = "dispute_unavailable" }
    end
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_billing_events` (`invoice_id`, `event`, `actor_identifier`)
        VALUES (?, 'disputed', ?)
    ]], { data.id, identifier })
    notify_identifier(identifier, "sky_phone:billing:changed")
    local row = find_owned_invoice(data.id, identifier)
    return { success = true, data = invoice_dto(row, identifier) }
end)

Bridge.Callbacks.Register("sky_phone:billing:pay", function(source, data)
    if not SkyPhone.AllowOperation(source, "billing_payment", Config.Billing.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local identifier, error_response = require_billing_session(source)
    if not identifier then
        return error_response
    end
    local invoice_id = data and data.id
    if not valid_invoice_id(invoice_id) then
        return { success = false, error = "invoice_not_found" }
    end
    local rows = invoice_select("`id` = ? AND `recipient_identifier` = ? LIMIT 1", { invoice_id, identifier })
    local row = rows[1]
    if not row then
        return { success = false, error = "invoice_not_found" }
    end
    if row.status == "paid" then
        return { success = false, error = "invoice_already_paid" }
    end
    if row.status == "processing" then
        return { success = false, error = "payment_in_progress" }
    end
    if row.status ~= "open" then
        return { success = false, error = "invoice_not_payable" }
    end
    local claim = Bridge.Database.Query([[
        UPDATE `sky_phone_billing_invoices` SET `status` = 'processing'
        WHERE `id` = ? AND `recipient_identifier` = ? AND `status` = 'open'
    ]], { invoice_id, identifier })
    if affected_rows(claim) ~= 1 then
        return { success = false, error = "payment_in_progress" }
    end
    local payment_id = uuid()
    local amount = tonumber(row.amount) or 0
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_billing_payments` (`id`, `invoice_id`, `recipient_identifier`, `amount`)
        VALUES (?, ?, ?, ?)
    ]], { payment_id, invoice_id, identifier, amount })
    if not Bridge.Framework.RemoveMoney(source, Config.Billing.PaymentAccount, amount) then
        Bridge.Database.Transaction({
            { query = "UPDATE `sky_phone_billing_invoices` SET `status` = 'open' WHERE `id` = ? AND `status` = 'processing'", params = { invoice_id } },
            { query = "UPDATE `sky_phone_billing_payments` SET `status` = 'failed', `error_code` = 'insufficient_funds' WHERE `id` = ?", params = { payment_id } },
        })
        return { success = false, error = "insufficient_funds" }
    end
    local completed = Bridge.Database.Transaction({
        { query = "UPDATE `sky_phone_billing_invoices` SET `status` = 'paid', `paid_at` = NOW(), `read_at` = COALESCE(`read_at`, NOW()), `payment_reference` = ? WHERE `id` = ? AND `status` = 'processing'", params = { payment_id, invoice_id } },
        { query = "UPDATE `sky_phone_billing_payments` SET `status` = 'paid' WHERE `id` = ?", params = { payment_id } },
        { query = "INSERT INTO `sky_phone_billing_events` (`invoice_id`, `event`, `actor_identifier`) VALUES (?, 'paid', ?)", params = { invoice_id, identifier } },
        { query = "INSERT INTO `sky_phone_billing_accounts` (`account_key`, `balance`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `balance` = `balance` + VALUES(`balance`)", params = { row.issuer_account, amount } },
        { query = "INSERT INTO `sky_phone_bank_transactions` (`owner_identifier`, `kind`, `amount`, `label`, `reference`) VALUES (?, 'withdrawal', ?, ?, ?)", params = { identifier, amount, row.issuer_label, payment_id } },
    })
    if not completed then
        Bridge.Framework.AddMoney(source, Config.Billing.PaymentAccount, amount)
        Bridge.Database.Transaction({
            { query = "UPDATE `sky_phone_billing_invoices` SET `status` = 'open' WHERE `id` = ? AND `status` = 'processing'", params = { invoice_id } },
            { query = "UPDATE `sky_phone_billing_payments` SET `status` = 'failed', `error_code` = 'payment_failed' WHERE `id` = ?", params = { payment_id } },
        })
        Bridge.Debug("error", "[sky_phone] Billing payment transaction failed for invoice %s; payer was refunded.", tostring(invoice_id))
        return { success = false, error = "payment_failed" }
    end
    TriggerClientEvent("sky_phone:banking:changed", source)
    notify_identifier(identifier, "sky_phone:billing:changed")
    if row.issuer_identifier ~= "" then
        notify_identifier(row.issuer_identifier, "sky_phone:billing:changed")
    end
    local paid_row = find_owned_invoice(invoice_id, identifier)
    return { success = true, data = invoice_dto(paid_row, identifier) }
end)

exports("CreateInvoice", function(data)
    return create_invoice(data)
end)

exports("CancelInvoice", function(invoice_id, actor_identifier)
    if not valid_invoice_id(invoice_id) then
        return false
    end
    local result = Bridge.Database.Query([[
        UPDATE `sky_phone_billing_invoices` SET `status` = 'cancelled'
        WHERE `id` = ? AND `status` = 'open'
    ]], { invoice_id })
    if affected_rows(result) ~= 1 then
        return false
    end
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_billing_events` (`invoice_id`, `event`, `actor_identifier`)
        VALUES (?, 'cancelled', ?)
    ]], { invoice_id, type(actor_identifier) == "string" and actor_identifier or "" })
    local rows = Bridge.Database.Query("SELECT `recipient_identifier`, `issuer_identifier` FROM `sky_phone_billing_invoices` WHERE `id` = ? LIMIT 1", { invoice_id })
    if rows[1] then
        notify_identifier(rows[1].recipient_identifier, "sky_phone:billing:changed")
        if rows[1].issuer_identifier ~= "" then
            notify_identifier(rows[1].issuer_identifier, "sky_phone:billing:changed")
        end
    end
    if SkyPhoneLog then
        SkyPhoneLog.Record("Billing", "billing:cancelled", "cancelled", nil,
            { id = invoice_id, resource = GetInvokingResource() })
    end
    return true
end)

exports("GetBillingAccountBalance", function(account_key)
    local key = trimmed(account_key, 80)
    if not key then
        return nil
    end
    local rows = Bridge.Database.Query("SELECT `balance` FROM `sky_phone_billing_accounts` WHERE `account_key` = ? LIMIT 1", { key })
    return tonumber(rows[1] and rows[1].balance) or 0
end)

exports("RemoveBillingAccountBalance", function(account_key, value)
    local key = trimmed(account_key, 80)
    local amount = valid_amount(value)
    if not key or not amount then
        return false
    end
    local result = Bridge.Database.Query([[
        UPDATE `sky_phone_billing_accounts` SET `balance` = `balance` - ?
        WHERE `account_key` = ? AND `balance` >= ?
    ]], { amount, key, amount })
    local removed = affected_rows(result) == 1
    if removed and SkyPhoneLog then
        SkyPhoneLog.Record("Billing", "billing:balance-withdrawn", "withdrawn", nil,
            { account = key, amount = amount, resource = GetInvokingResource() })
    end
    return removed
end)

end)
