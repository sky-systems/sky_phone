Bridge.Database.AfterMigration("sky_phone", function()

local MAX_SAFE_INTEGER = 9007199254740991
local DELETE_FOLDERS = {
    drafts = true,
    inbox = true,
    sent = true,
    trash = true,
}

local function trim(value)
    if type(value) ~= "string" then
        return nil
    end

    return value:match("^%s*(.-)%s*$")
end

local function validate_payload(source, operation, value)
    if type(value) == "table" then
        return value
    end

    Bridge.Debug(
        "warn",
        "[sky_phone] Invalid mail payload for %s from source %s.",
        operation,
        tostring(source)
    )
    return nil
end

local function text_length(value)
    if type(value) ~= "string" then
        return nil
    end

    return utf8.len(value)
end

local function normalize_email(value)
    local email = trim(value)
    if not email then
        return nil
    end

    email = email:lower()
    local local_part = email
    if email:find("@", 1, true) then
        local_part = email:match("^([^@]+)@" .. Config.Mail.Domain:lower():gsub("(%W)", "%%%1") .. "$")
    end

    if not local_part
        or #local_part < Config.Mail.LocalPartMinLength
        or #local_part > Config.Mail.LocalPartMaxLength
        or not local_part:match("^[a-z0-9][a-z0-9._-]*[a-z0-9]$")
        or local_part:find("..", 1, true)
    then
        return nil
    end

    return local_part .. "@" .. Config.Mail.Domain:lower()
end

local function validate_text(value, maximum)
    local length = text_length(value)
    return length and length <= maximum
end

local function normalize_mailbox_name(value)
    local name = trim(value)
    local length = text_length(name)
    if not length or length < 1 or length > Config.Mail.MailboxNameMaxLength or name:find("%c") then
        return nil
    end

    return name
end

local function normalize_numeric_id(value)
    local id = tonumber(value)
    if not id or id ~= id or id < 1 or id > MAX_SAFE_INTEGER or id ~= math.floor(id) then
        return nil
    end

    return id
end

local function mailbox_id_from_folder(folder)
    if type(folder) ~= "string" then
        return nil
    end

    local value = folder:match("^mailbox:(%d+)$")
    return value and normalize_numeric_id(value) or nil
end

local function normalize_list_filters(value)
    if value == nil then
        return {
            address = "all",
            direction = "all",
            read = "all",
            today = false,
        }
    end
    if type(value) ~= "table"
        or (value.address ~= "all" and value.address ~= "from-me" and value.address ~= "to-me")
        or (value.direction ~= "all" and value.direction ~= "inbox" and value.direction ~= "sent")
        or (value.read ~= "all" and value.read ~= "read" and value.read ~= "unread")
        or type(value.today) ~= "boolean"
    then
        return nil
    end

    return {
        address = value.address,
        direction = value.direction,
        read = value.read,
        today = value.today,
    }
end

local function normalize_recipients(values, strict)
    if type(values) ~= "table" or #values > Config.Mail.MaxRecipients then
        return nil
    end

    local recipients = {}
    local seen = {}
    for _, value in ipairs(values) do
        local recipient
        if strict then
            recipient = normalize_email(value)
        else
            recipient = trim(value)
            if recipient and #recipient > 64 then
                recipient = nil
            end
        end

        if not recipient then
            return nil
        end

        local key = recipient:lower()
        if key ~= "" and not seen[key] then
            seen[key] = true
            recipients[#recipients + 1] = recipient
        end
    end

    return recipients
end

local function normalize_delete_ids(folder, values)
    if type(values) ~= "table" then
        return nil
    end

    local input_count = 0
    for key in pairs(values) do
        if type(key) ~= "number"
            or key < 1
            or key > Config.Mail.DeleteBatchSize
            or key ~= math.floor(key)
        then
            return nil
        end
        input_count = input_count + 1
    end
    if input_count == 0 or input_count > Config.Mail.DeleteBatchSize then
        return nil
    end

    local ids = {}
    local seen = {}
    for index = 1, input_count do
        local value = values[index]
        if value == nil then
            return nil
        end

        local id
        if folder == "drafts" then
            if type(value) ~= "string"
                or not value:match(
                    "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
                )
            then
                return nil
            end
            id = value:lower()
        else
            if type(value) ~= "number"
                or value ~= value
                or value < 1
                or value > MAX_SAFE_INTEGER
                or value ~= math.floor(value)
            then
                return nil
            end
            id = value
        end

        if not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end

    return ids
end

local function make_placeholders(count)
    local placeholders = {}
    for index = 1, count do
        placeholders[index] = "?"
    end
    return table.concat(placeholders, ", ")
end

local function append_values(target, values)
    for index = 1, #values do
        target[#target + 1] = values[index]
    end
end

local function require_session(source)
    return SkyPhone.RequireAccount(source)
end

local function new_database_id()
    local rows = Bridge.Database.Query("SELECT UUID() AS id", {})
    if not rows[1] or type(rows[1].id) ~= "string" then
        error("[sky_phone] Database did not generate a mail id.")
    end

    return rows[1].id
end

local function notify_account(account_id, event_name, data)
    SkyPhone.NotifyAccount(account_id, event_name, data)
end

local function get_counts(account_id)
    local rows = Bridge.Database.Query([[
        SELECT
            SUM(CASE WHEN `folder` = 'inbox' AND `mailbox_id` IS NULL AND `trashed_at` IS NULL AND `read_at` IS NULL THEN 1 ELSE 0 END) AS unread,
            SUM(CASE WHEN `folder` = 'inbox' AND `mailbox_id` IS NULL AND `trashed_at` IS NULL THEN 1 ELSE 0 END) AS inbox,
            SUM(CASE WHEN `folder` = 'sent' AND `mailbox_id` IS NULL AND `trashed_at` IS NULL THEN 1 ELSE 0 END) AS sent,
            SUM(CASE WHEN `trashed_at` IS NOT NULL THEN 1 ELSE 0 END) AS trash
        FROM `sky_phone_mail_entries`
        WHERE `account_id` = ?
    ]], { account_id })
    local drafts = Bridge.Database.Query(
        "SELECT COUNT(*) AS count FROM `sky_phone_mail_drafts` WHERE `account_id` = ?",
        { account_id }
    )
    local counts = rows[1] or {}

    return {
        unread = tonumber(counts.unread) or 0,
        inbox = tonumber(counts.inbox) or 0,
        sent = tonumber(counts.sent) or 0,
        trash = tonumber(counts.trash) or 0,
        drafts = tonumber(drafts[1] and drafts[1].count) or 0,
    }
end

local function get_mailboxes(account_id)
    local rows = Bridge.Database.Query([[
        SELECT mailbox.`id`, mailbox.`name`, mailbox.`sort_order`, COUNT(entry.`id`) AS `count`
        FROM `sky_phone_mailboxes` mailbox
        LEFT JOIN `sky_phone_mail_entries` entry
            ON entry.`mailbox_id` = mailbox.`id`
            AND entry.`account_id` = mailbox.`account_id`
            AND entry.`trashed_at` IS NULL
        WHERE mailbox.`account_id` = ?
        GROUP BY mailbox.`id`, mailbox.`name`, mailbox.`sort_order`
        ORDER BY mailbox.`sort_order` ASC, mailbox.`id` ASC
    ]], { account_id })

    for index = 1, #rows do
        rows[index].id = tonumber(rows[index].id)
        rows[index].sort_order = tonumber(rows[index].sort_order) or 0
        rows[index].count = tonumber(rows[index].count) or 0
    end

    return rows
end

local function find_owned_mailbox(account_id, mailbox_id)
    local rows = Bridge.Database.Query([[
        SELECT `id`, `name`, `sort_order`
        FROM `sky_phone_mailboxes`
        WHERE `id` = ? AND `account_id` = ?
        LIMIT 1
    ]], { mailbox_id, account_id })
    return rows[1]
end

local function broadcast_mailbox_changed(account_id, counts)
    notify_account(account_id, "sky_phone:mail:changed", {
        counts = counts or get_counts(account_id),
    })
end

Bridge.Callbacks.Register("sky_phone:mail:counts", function(source)
    local session, error_response = require_session(source)
    if not session then
        return error_response
    end

    return { success = true, data = get_counts(session.id) }
end)

Bridge.Callbacks.Register("sky_phone:mail:mailboxes", function(source)
    local session, error_response = require_session(source)
    if not session then
        return error_response
    end

    return { success = true, data = { mailboxes = get_mailboxes(session.id) } }
end)

Bridge.Callbacks.Register("sky_phone:mail:create-mailbox", function(source, data)
    local session, error_response = require_session(source)
    if not session then
        return error_response
    end
    if not SkyPhone.AllowOperation(source, "mail_manage_mailboxes", Config.Mail.MailboxRequestsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end

    data = validate_payload(source, "create-mailbox", data)
    if not data then
        return { success = false, error = "invalid_request" }
    end

    local name = normalize_mailbox_name(data.name)
    if not name then
        return { success = false, error = "invalid_mailbox" }
    end

    local rows = Bridge.Database.Query([[
        SELECT COUNT(*) AS `count`,
            SUM(CASE WHEN LOWER(`name`) = LOWER(?) THEN 1 ELSE 0 END) AS `duplicate_count`,
            COALESCE(MAX(`sort_order`), -1) AS `maximum_sort_order`
        FROM `sky_phone_mailboxes`
        WHERE `account_id` = ?
    ]], { name, session.id })
    local summary = rows[1] or {}
    if (tonumber(summary.duplicate_count) or 0) > 0 then
        return { success = false, error = "mailbox_exists" }
    end
    if (tonumber(summary.count) or 0) >= Config.Mail.MaxMailboxes then
        return { success = false, error = "mailbox_limit" }
    end

    local sort_order = math.min(65535, (tonumber(summary.maximum_sort_order) or -1) + 1)
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_mailboxes` (`account_id`, `name`, `sort_order`)
        VALUES (?, ?, ?)
    ]], { session.id, name, sort_order })

    local created = Bridge.Database.Query([[
        SELECT `id`, `name`, `sort_order`, 0 AS `count`
        FROM `sky_phone_mailboxes`
        WHERE `account_id` = ? AND LOWER(`name`) = LOWER(?)
        LIMIT 1
    ]], { session.id, name })
    if not created[1] then
        error("[sky_phone] Created mail mailbox could not be loaded.")
    end

    created[1].id = tonumber(created[1].id)
    created[1].sort_order = tonumber(created[1].sort_order) or 0
    created[1].count = 0
    broadcast_mailbox_changed(session.id)
    return { success = true, data = created[1] }
end)

Bridge.Callbacks.Register("sky_phone:mail:delete-mailbox", function(source, data)
    local session, error_response = require_session(source)
    if not session then
        return error_response
    end
    if not SkyPhone.AllowOperation(source, "mail_manage_mailboxes", Config.Mail.MailboxRequestsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end

    data = validate_payload(source, "delete-mailbox", data)
    if not data then
        return { success = false, error = "invalid_request" }
    end

    local mailbox_id = normalize_numeric_id(data.id)
    if not mailbox_id or not find_owned_mailbox(session.id, mailbox_id) then
        return { success = false, error = "mailbox_not_found" }
    end

    if not Bridge.Database.Transaction({
        {
            query = [[
                UPDATE `sky_phone_mail_entries` SET `mailbox_id` = NULL
                WHERE `account_id` = ? AND `mailbox_id` = ?
            ]],
            params = { session.id, mailbox_id },
        },
        {
            query = "DELETE FROM `sky_phone_mailboxes` WHERE `id` = ? AND `account_id` = ?",
            params = { mailbox_id, session.id },
        },
    }) then
        return { success = false, error = "request_failed" }
    end

    broadcast_mailbox_changed(session.id)
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:mail:list", function(source, data)
    local session, error_response = require_session(source)
    if not session then
        return error_response
    end

    data = validate_payload(source, "list", data)
    if not data then
        return { success = false, error = "invalid_request" }
    end

    local folder = data.folder
    local custom_mailbox_id = mailbox_id_from_folder(folder)
    if folder ~= "inbox" and folder ~= "sent" and folder ~= "drafts" and folder ~= "trash"
        and not custom_mailbox_id
    then
        return { success = false, error = "invalid_folder" }
    end
    if custom_mailbox_id and not find_owned_mailbox(session.id, custom_mailbox_id) then
        return { success = false, error = "mailbox_not_found" }
    end

    local search = trim(data.search) or ""
    if not validate_text(search, 120) then
        return { success = false, error = "invalid_search" }
    end
    local offset = math.max(0, math.min(100000, math.floor(tonumber(data.offset) or 0)))
    local limit = Config.Mail.PageSize + 1
    local filters = normalize_list_filters(data.filters)
    if not filters then
        return { success = false, error = "invalid_filter" }
    end
    local rows

    if folder == "drafts" then
        if filters.address ~= "all" or filters.direction ~= "all" or filters.read ~= "all" or filters.today then
            return { success = false, error = "invalid_filter" }
        end
        local pattern = "%" .. search .. "%"
        rows = Bridge.Database.Query([[
            SELECT `id`, `recipients`, `subject`, LEFT(`body`, 180) AS `preview`, `updated_at` AS `created_at`
            FROM `sky_phone_mail_drafts`
            WHERE `account_id` = ? AND (? = '' OR `subject` LIKE ? OR `body` LIKE ? OR `recipients` LIKE ?)
            ORDER BY `updated_at` DESC
            LIMIT ? OFFSET ?
        ]], { session.id, search, pattern, pattern, pattern, limit, offset })
    else
        local conditions
        local values = { session.id }
        if custom_mailbox_id then
            conditions = "e.`mailbox_id` = ? AND e.`trashed_at` IS NULL"
            values[#values + 1] = custom_mailbox_id
        elseif folder == "trash" then
            conditions = "e.`trashed_at` IS NOT NULL"
        else
            conditions = "e.`folder` = ? AND e.`mailbox_id` IS NULL AND e.`trashed_at` IS NULL"
            values[#values + 1] = folder
        end

        if filters.read == "unread" then
            conditions = conditions .. " AND e.`folder` = 'inbox' AND e.`read_at` IS NULL"
        elseif filters.read == "read" then
            conditions = conditions .. " AND (e.`folder` = 'sent' OR e.`read_at` IS NOT NULL)"
        end
        if filters.direction ~= "all" then
            conditions = conditions .. " AND e.`folder` = ?"
            values[#values + 1] = filters.direction
        end
        if filters.address == "to-me" then
            conditions = conditions .. " AND m.`recipients` LIKE ?"
            values[#values + 1] = "%\"" .. session.email .. "\"%"
        elseif filters.address == "from-me" then
            conditions = conditions .. " AND m.`sender_account_id` = e.`account_id`"
        end
        if filters.today then
            conditions = conditions .. " AND m.`created_at` >= CURRENT_DATE() AND m.`created_at` < CURRENT_DATE() + INTERVAL 1 DAY"
        end

        local pattern = "%" .. search .. "%"
        values[#values + 1] = search
        values[#values + 1] = pattern
        values[#values + 1] = pattern
        values[#values + 1] = pattern
        values[#values + 1] = pattern
        values[#values + 1] = limit
        values[#values + 1] = offset

        rows = Bridge.Database.Query(([[
            SELECT e.`id`, e.`folder`, e.`read_at`, e.`trashed_at`, m.`id` AS `message_id`,
                sender.`email` AS `sender`, m.`recipients`, m.`subject`, LEFT(m.`body`, 180) AS `preview`,
                m.`created_at`
            FROM `sky_phone_mail_entries` e
            JOIN `sky_phone_mail_messages` m ON m.`id` = e.`message_id`
            JOIN `sky_phone_accounts` sender ON sender.`id` = m.`sender_account_id`
            WHERE e.`account_id` = ? AND %s
                AND (? = '' OR m.`subject` LIKE ? OR m.`body` LIKE ? OR sender.`email` LIKE ? OR m.`recipients` LIKE ?)
            ORDER BY m.`created_at` DESC, e.`id` DESC
            LIMIT ? OFFSET ?
        ]]):format(conditions), values)
    end

    local has_more = #rows > Config.Mail.PageSize
    if has_more then
        rows[#rows] = nil
    end
    for _, row in ipairs(rows) do
        row.recipients = json.decode(row.recipients) or {}
        row.is_read = row.read_at ~= nil
        row.read_at = nil
    end

    return {
        success = true,
        data = { items = rows, hasMore = has_more, offset = offset },
    }
end)

Bridge.Callbacks.Register("sky_phone:mail:get", function(source, data)
    local session, error_response = require_session(source)
    if not session then
        return error_response
    end

    data = validate_payload(source, "get", data)
    if not data then
        return { success = false, error = "invalid_request" }
    end

    local entry_id = tonumber(data.id)
    if not entry_id then
        return { success = false, error = "invalid_message" }
    end

    local rows = Bridge.Database.Query([[
        SELECT e.`id`, e.`folder`, e.`read_at`, e.`trashed_at`, m.`id` AS `message_id`,
            sender.`email` AS `sender`, m.`recipients`, m.`subject`, m.`body`, m.`created_at`
        FROM `sky_phone_mail_entries` e
        JOIN `sky_phone_mail_messages` m ON m.`id` = e.`message_id`
        JOIN `sky_phone_accounts` sender ON sender.`id` = m.`sender_account_id`
        WHERE e.`id` = ? AND e.`account_id` = ?
        LIMIT 1
    ]], { entry_id, session.id })
    if not rows[1] then
        return { success = false, error = "message_not_found" }
    end

    if not rows[1].read_at then
        Bridge.Database.Query(
            "UPDATE `sky_phone_mail_entries` SET `read_at` = CURRENT_TIMESTAMP WHERE `id` = ? AND `account_id` = ?",
            { entry_id, session.id }
        )
        rows[1].read_at = os.date("%Y-%m-%d %H:%M:%S")
        broadcast_mailbox_changed(session.id)
    end

    rows[1].recipients = json.decode(rows[1].recipients) or {}
    rows[1].is_read = true
    rows[1].read_at = nil
    return { success = true, data = rows[1] }
end)

Bridge.Callbacks.Register("sky_phone:mail:get-draft", function(source, data)
    local session, error_response = require_session(source)
    if not session then
        return error_response
    end

    data = validate_payload(source, "get-draft", data)
    if not data then
        return { success = false, error = "invalid_request" }
    end

    local id = data.id
    if type(id) ~= "string" or #id ~= 36 then
        return { success = false, error = "invalid_draft" }
    end

    local rows = Bridge.Database.Query([[
        SELECT `id`, `recipients`, `subject`, `body`, `created_at`, `updated_at`
        FROM `sky_phone_mail_drafts`
        WHERE `id` = ? AND `account_id` = ?
        LIMIT 1
    ]], { id, session.id })
    if not rows[1] then
        return { success = false, error = "draft_not_found" }
    end

    rows[1].recipients = json.decode(rows[1].recipients) or {}
    return { success = true, data = rows[1] }
end)

Bridge.Callbacks.Register("sky_phone:mail:save-draft", function(source, data)
    local session, error_response = require_session(source)
    if not session then
        return error_response
    end

    data = validate_payload(source, "save-draft", data)
    if not data then
        return { success = false, error = "invalid_request" }
    end

    local recipients = normalize_recipients(data.recipients, false)
    local subject = data.subject
    local body = data.body
    if not recipients or not validate_text(subject, Config.Mail.SubjectMaxLength)
        or not validate_text(body, Config.Mail.BodyMaxLength)
    then
        return { success = false, error = "invalid_draft" }
    end

    local id = data.id
    if id ~= nil and (type(id) ~= "string" or #id ~= 36) then
        return { success = false, error = "invalid_draft" }
    end

    if id then
        local result = Bridge.Database.Query([[
            UPDATE `sky_phone_mail_drafts`
            SET `recipients` = ?, `subject` = ?, `body` = ?, `updated_at` = CURRENT_TIMESTAMP
            WHERE `id` = ? AND `account_id` = ?
        ]], { json.encode(recipients), subject, body, id, session.id })
        if not result or result == 0 or (type(result) == "table" and result.affectedRows == 0) then
            return { success = false, error = "draft_not_found" }
        end
    else
        id = new_database_id()
        Bridge.Database.Query([[
            INSERT INTO `sky_phone_mail_drafts` (`id`, `account_id`, `recipients`, `subject`, `body`)
            VALUES (?, ?, ?, ?, ?)
        ]], { id, session.id, json.encode(recipients), subject, body })
    end

    broadcast_mailbox_changed(session.id)
    return { success = true, data = { id = id } }
end)

Bridge.Callbacks.Register("sky_phone:mail:delete-draft", function(source, data)
    local session, error_response = require_session(source)
    if not session then
        return error_response
    end

    data = validate_payload(source, "delete-draft", data)
    if not data then
        return { success = false, error = "invalid_request" }
    end

    local id = data.id
    if type(id) ~= "string" or #id ~= 36 then
        return { success = false, error = "invalid_draft" }
    end

    Bridge.Database.Query(
        "DELETE FROM `sky_phone_mail_drafts` WHERE `id` = ? AND `account_id` = ?",
        { id, session.id }
    )
    broadcast_mailbox_changed(session.id)
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:mail:send", function(source, data)
    local session, error_response = require_session(source)
    if not session then
        return error_response
    end

    data = validate_payload(source, "send", data)
    if not data then
        return { success = false, error = "invalid_request" }
    end

    local recipients = normalize_recipients(data.recipients, true)
    local subject = trim(data.subject)
    local body = data.body
    if not recipients or #recipients == 0
        or not validate_text(subject, Config.Mail.SubjectMaxLength)
        or not validate_text(body, Config.Mail.BodyMaxLength)
        or (subject == "" and trim(body) == "")
    then
        return { success = false, error = "invalid_message" }
    end

    local placeholders = {}
    for index = 1, #recipients do
        placeholders[index] = "?"
    end
    local recipient_accounts = Bridge.Database.Query(
        ("SELECT `id`, `email` FROM `sky_phone_accounts` WHERE `email` IN (%s)"):format(table.concat(placeholders, ", ")),
        recipients
    )
    if #recipient_accounts ~= #recipients then
        return { success = false, error = "recipient_not_found" }
    end

    local message_id = new_database_id()
    local statements = {
        {
            query = [[
                INSERT INTO `sky_phone_mail_messages`
                    (`id`, `sender_account_id`, `recipients`, `subject`, `body`)
                VALUES (?, ?, ?, ?, ?)
            ]],
            params = { message_id, session.id, json.encode(recipients), subject, body },
        },
        {
            query = [[
                INSERT INTO `sky_phone_mail_entries` (`message_id`, `account_id`, `folder`, `read_at`)
                VALUES (?, ?, 'sent', CURRENT_TIMESTAMP)
            ]],
            params = { message_id, session.id },
        },
    }
    for _, account in ipairs(recipient_accounts) do
        statements[#statements + 1] = {
            query = [[
                INSERT INTO `sky_phone_mail_entries` (`message_id`, `account_id`, `folder`)
                VALUES (?, ?, 'inbox')
            ]],
            params = { message_id, account.id },
        }
    end
    if type(data.draftId) == "string" and #data.draftId == 36 then
        statements[#statements + 1] = {
            query = "DELETE FROM `sky_phone_mail_drafts` WHERE `id` = ? AND `account_id` = ?",
            params = { data.draftId, session.id },
        }
    end

    if not Bridge.Database.Transaction(statements) then
        return { success = false, error = "request_failed" }
    end

    broadcast_mailbox_changed(session.id)
    for _, account in ipairs(recipient_accounts) do
        local counts = get_counts(account.id)
        SkyPhone.NotifyAccountDevices(account.id, "sky_phone:mail:new", {
            counts = counts,
            sender = session.email,
            subject = subject,
        })
        broadcast_mailbox_changed(account.id, counts)
    end

    return { success = true, data = { id = message_id } }
end)

Bridge.Callbacks.Register("sky_phone:mail:set-read", function(source, data)
    local session, error_response = require_session(source)
    if not session then
        return error_response
    end

    data = validate_payload(source, "set-read", data)
    if not data then
        return { success = false, error = "invalid_request" }
    end

    local id = tonumber(data.id)
    if not id or type(data.read) ~= "boolean" then
        return { success = false, error = "invalid_message" }
    end

    Bridge.Database.Query(
        ("UPDATE `sky_phone_mail_entries` SET `read_at` = %s WHERE `id` = ? AND `account_id` = ?")
            :format(data.read and "CURRENT_TIMESTAMP" or "NULL"),
        { id, session.id }
    )
    broadcast_mailbox_changed(session.id)
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:mail:move", function(source, data)
    local session, error_response = require_session(source)
    if not session then
        return error_response
    end
    if not SkyPhone.AllowOperation(source, "mail_move", Config.Mail.MailboxRequestsPerMinute * 3, 60) then
        return { success = false, error = "rate_limited" }
    end

    data = validate_payload(source, "move", data)
    if not data then
        return { success = false, error = "invalid_request" }
    end

    local entry_id = normalize_numeric_id(data.id)
    local mailbox_id
    if data.mailboxId ~= 0 then
        mailbox_id = normalize_numeric_id(data.mailboxId)
    end
    if not entry_id then
        return { success = false, error = "message_not_found" }
    end
    if data.mailboxId ~= 0 and (not mailbox_id or not find_owned_mailbox(session.id, mailbox_id)) then
        return { success = false, error = "mailbox_not_found" }
    end

    local entries = Bridge.Database.Query([[
        SELECT `id`
        FROM `sky_phone_mail_entries`
        WHERE `id` = ? AND `account_id` = ? AND `trashed_at` IS NULL
        LIMIT 1
    ]], { entry_id, session.id })
    if not entries[1] then
        return { success = false, error = "message_not_found" }
    end

    if mailbox_id then
        Bridge.Database.Query([[
            UPDATE `sky_phone_mail_entries` SET `mailbox_id` = ?
            WHERE `id` = ? AND `account_id` = ? AND `trashed_at` IS NULL
        ]], { mailbox_id, entry_id, session.id })
    else
        Bridge.Database.Query([[
            UPDATE `sky_phone_mail_entries` SET `mailbox_id` = NULL
            WHERE `id` = ? AND `account_id` = ? AND `trashed_at` IS NULL
        ]], { entry_id, session.id })
    end
    broadcast_mailbox_changed(session.id)
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:mail:trash", function(source, data)
    local session, error_response = require_session(source)
    if not session then
        return error_response
    end

    data = validate_payload(source, "trash", data)
    if not data then
        return { success = false, error = "invalid_request" }
    end

    local id = tonumber(data.id)
    if not id then
        return { success = false, error = "invalid_message" }
    end

    Bridge.Database.Query([[
        UPDATE `sky_phone_mail_entries` SET `trashed_at` = CURRENT_TIMESTAMP
        WHERE `id` = ? AND `account_id` = ? AND `trashed_at` IS NULL
    ]], { id, session.id })
    broadcast_mailbox_changed(session.id)
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:mail:restore", function(source, data)
    local session, error_response = require_session(source)
    if not session then
        return error_response
    end

    data = validate_payload(source, "restore", data)
    if not data then
        return { success = false, error = "invalid_request" }
    end

    local id = tonumber(data.id)
    if not id then
        return { success = false, error = "invalid_message" }
    end

    Bridge.Database.Query([[
        UPDATE `sky_phone_mail_entries` SET `trashed_at` = NULL
        WHERE `id` = ? AND `account_id` = ? AND `trashed_at` IS NOT NULL
    ]], { id, session.id })
    broadcast_mailbox_changed(session.id)
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:mail:delete-forever", function(source, data)
    local session, error_response = require_session(source)
    if not session then
        return error_response
    end

    data = validate_payload(source, "delete-forever", data)
    if not data then
        return { success = false, error = "invalid_request" }
    end

    local id = tonumber(data.id)
    if not id then
        return { success = false, error = "invalid_message" }
    end

    Bridge.Database.Query([[
        DELETE FROM `sky_phone_mail_entries`
        WHERE `id` = ? AND `account_id` = ? AND `trashed_at` IS NOT NULL
    ]], { id, session.id })
    Bridge.Database.Query([[
        DELETE m FROM `sky_phone_mail_messages` m
        LEFT JOIN `sky_phone_mail_entries` e ON e.`message_id` = m.`id`
        WHERE e.`id` IS NULL
    ]], {})
    broadcast_mailbox_changed(session.id)
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:mail:delete-many", function(source, data)
    local session, error_response = require_session(source)
    if not session then
        return error_response
    end
    if not SkyPhone.AllowOperation(source, "mail_delete_many", Config.Mail.DeleteRequestsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end

    data = validate_payload(source, "delete-many", data)
    if not data then
        return { success = false, error = "invalid_request" }
    end

    local folder = data.folder
    local custom_mailbox_id = mailbox_id_from_folder(folder)
    if type(folder) ~= "string" or (not DELETE_FOLDERS[folder] and not custom_mailbox_id) then
        return { success = false, error = "invalid_folder" }
    end
    if custom_mailbox_id and not find_owned_mailbox(session.id, custom_mailbox_id) then
        return { success = false, error = "mailbox_not_found" }
    end

    local ids = normalize_delete_ids(folder, data.ids)
    if not ids then
        return { success = false, error = "invalid_request" }
    end

    local placeholders = make_placeholders(#ids)
    if folder == "drafts" then
        local parameters = { session.id }
        append_values(parameters, ids)
        Bridge.Database.Query(([[
            DELETE FROM `sky_phone_mail_drafts`
            WHERE `account_id` = ? AND `id` IN (%s)
        ]]):format(placeholders), parameters)
    elseif folder == "inbox" or folder == "sent" then
        local parameters = { session.id, folder }
        append_values(parameters, ids)
        Bridge.Database.Query(([[
            UPDATE `sky_phone_mail_entries` SET `trashed_at` = CURRENT_TIMESTAMP
            WHERE `account_id` = ? AND `folder` = ? AND `mailbox_id` IS NULL
                AND `trashed_at` IS NULL
                AND `id` IN (%s)
        ]]):format(placeholders), parameters)
    elseif custom_mailbox_id then
        local parameters = { session.id, custom_mailbox_id }
        append_values(parameters, ids)
        Bridge.Database.Query(([[
            UPDATE `sky_phone_mail_entries` SET `trashed_at` = CURRENT_TIMESTAMP
            WHERE `account_id` = ? AND `mailbox_id` = ? AND `trashed_at` IS NULL
                AND `id` IN (%s)
        ]]):format(placeholders), parameters)
    else
        local orphan_parameters = { session.id }
        append_values(orphan_parameters, ids)
        orphan_parameters[#orphan_parameters + 1] = session.id
        append_values(orphan_parameters, ids)

        local delete_parameters = { session.id }
        append_values(delete_parameters, ids)

        local statements = {
            {
                query = ([[
                    DELETE m
                    FROM `sky_phone_mail_messages` m
                    JOIN `sky_phone_mail_entries` target ON target.`message_id` = m.`id`
                    WHERE target.`account_id` = ? AND target.`trashed_at` IS NOT NULL
                        AND target.`id` IN (%s)
                        AND NOT EXISTS (
                            SELECT 1
                            FROM `sky_phone_mail_entries` remaining
                            WHERE remaining.`message_id` = m.`id`
                                AND NOT (
                                    remaining.`account_id` = ?
                                    AND remaining.`trashed_at` IS NOT NULL
                                    AND remaining.`id` IN (%s)
                                )
                        )
                ]]):format(placeholders, placeholders),
                params = orphan_parameters,
            },
            {
                query = ([[
                    DELETE FROM `sky_phone_mail_entries`
                    WHERE `account_id` = ? AND `trashed_at` IS NOT NULL
                        AND `id` IN (%s)
                ]]):format(placeholders),
                params = delete_parameters,
            },
        }
        if not Bridge.Database.Transaction(statements) then
            return { success = false, error = "request_failed" }
        end
    end

    broadcast_mailbox_changed(session.id)
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:mail:empty-trash", function(source)
    local session, error_response = require_session(source)
    if not session then
        return error_response
    end

    Bridge.Database.Query(
        "DELETE FROM `sky_phone_mail_entries` WHERE `account_id` = ? AND `trashed_at` IS NOT NULL",
        { session.id }
    )
    Bridge.Database.Query([[
        DELETE m FROM `sky_phone_mail_messages` m
        LEFT JOIN `sky_phone_mail_entries` e ON e.`message_id` = m.`id`
        WHERE e.`id` IS NULL
    ]], {})
    broadcast_mailbox_changed(session.id)
    return { success = true }
end)
end)
