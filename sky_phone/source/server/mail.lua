if not Sky.DB.AwaitMigrations("sky_phone") then
    error("[sky_phone] Mail database migrations did not complete.")
end

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

    Sky.Debug(
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

local function validate_text(value, maximum)
    local length = text_length(value)
    return length and length <= maximum
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

local function require_session(source)
    return SkyPhone.RequireAccount(source)
end

local function new_database_id()
    local rows = Sky.Query("SELECT UUID() AS id", {})
    if not rows[1] or type(rows[1].id) ~= "string" then
        error("[sky_phone] Database did not generate a mail id.")
    end

    return rows[1].id
end

local function notify_account(account_id, event_name, data)
    SkyPhone.NotifyAccount(account_id, event_name, data)
end

local function get_counts(account_id)
    local rows = Sky.Query([[
        SELECT
            SUM(CASE WHEN `folder` = 'inbox' AND `trashed_at` IS NULL AND `read_at` IS NULL THEN 1 ELSE 0 END) AS unread,
            SUM(CASE WHEN `folder` = 'inbox' AND `trashed_at` IS NULL THEN 1 ELSE 0 END) AS inbox,
            SUM(CASE WHEN `folder` = 'sent' AND `trashed_at` IS NULL THEN 1 ELSE 0 END) AS sent,
            SUM(CASE WHEN `trashed_at` IS NOT NULL THEN 1 ELSE 0 END) AS trash
        FROM `sky_phone_mail_entries`
        WHERE `account_id` = ?
    ]], { account_id })
    local drafts = Sky.Query(
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

local function broadcast_mailbox_changed(account_id, counts)
    notify_account(account_id, "sky_phone:mail:changed", {
        counts = counts or get_counts(account_id),
    })
end

Sky.Cb.Register("sky_phone:mail:counts", function(source)
    local session, error_response = require_session(source)
    if not session then
        return error_response
    end

    return { success = true, data = get_counts(session.id) }
end)

Sky.Cb.Register("sky_phone:mail:list", function(source, data)
    local session, error_response = require_session(source)
    if not session then
        return error_response
    end

    data = validate_payload(source, "list", data)
    if not data then
        return { success = false, error = "invalid_request" }
    end

    local folder = data.folder
    if folder ~= "inbox" and folder ~= "sent" and folder ~= "drafts" and folder ~= "trash" then
        return { success = false, error = "invalid_folder" }
    end

    local search = trim(data.search) or ""
    if not validate_text(search, 120) then
        return { success = false, error = "invalid_search" }
    end
    local offset = math.max(0, math.min(100000, math.floor(tonumber(data.offset) or 0)))
    local limit = Config.Mail.PageSize + 1
    local rows

    if folder == "drafts" then
        local pattern = "%" .. search .. "%"
        rows = Sky.Query([[
            SELECT `id`, `recipients`, `subject`, LEFT(`body`, 180) AS `preview`, `updated_at` AS `created_at`
            FROM `sky_phone_mail_drafts`
            WHERE `account_id` = ? AND (? = '' OR `subject` LIKE ? OR `body` LIKE ? OR `recipients` LIKE ?)
            ORDER BY `updated_at` DESC
            LIMIT ? OFFSET ?
        ]], { session.id, search, pattern, pattern, pattern, limit, offset })
    else
        local conditions
        local values = { session.id }
        if folder == "trash" then
            conditions = "e.`trashed_at` IS NOT NULL"
        else
            conditions = "e.`folder` = ? AND e.`trashed_at` IS NULL"
            values[#values + 1] = folder
        end

        local pattern = "%" .. search .. "%"
        values[#values + 1] = search
        values[#values + 1] = pattern
        values[#values + 1] = pattern
        values[#values + 1] = pattern
        values[#values + 1] = pattern
        values[#values + 1] = limit
        values[#values + 1] = offset

        rows = Sky.Query(([[
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

Sky.Cb.Register("sky_phone:mail:get", function(source, data)
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

    local rows = Sky.Query([[
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
        Sky.Query(
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

Sky.Cb.Register("sky_phone:mail:get-draft", function(source, data)
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

    local rows = Sky.Query([[
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

Sky.Cb.Register("sky_phone:mail:save-draft", function(source, data)
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
        local result = Sky.Query([[
            UPDATE `sky_phone_mail_drafts`
            SET `recipients` = ?, `subject` = ?, `body` = ?, `updated_at` = CURRENT_TIMESTAMP
            WHERE `id` = ? AND `account_id` = ?
        ]], { json.encode(recipients), subject, body, id, session.id })
        if not result or result == 0 or (type(result) == "table" and result.affectedRows == 0) then
            return { success = false, error = "draft_not_found" }
        end
    else
        id = new_database_id()
        Sky.Query([[
            INSERT INTO `sky_phone_mail_drafts` (`id`, `account_id`, `recipients`, `subject`, `body`)
            VALUES (?, ?, ?, ?, ?)
        ]], { id, session.id, json.encode(recipients), subject, body })
    end

    broadcast_mailbox_changed(session.id)
    return { success = true, data = { id = id } }
end)

Sky.Cb.Register("sky_phone:mail:delete-draft", function(source, data)
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

    Sky.Query(
        "DELETE FROM `sky_phone_mail_drafts` WHERE `id` = ? AND `account_id` = ?",
        { id, session.id }
    )
    broadcast_mailbox_changed(session.id)
    return { success = true }
end)

Sky.Cb.Register("sky_phone:mail:send", function(source, data)
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
    local recipient_accounts = Sky.Query(
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

    if not Sky.DB.Transaction(statements) then
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

Sky.Cb.Register("sky_phone:mail:set-read", function(source, data)
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

    Sky.Query(
        ("UPDATE `sky_phone_mail_entries` SET `read_at` = %s WHERE `id` = ? AND `account_id` = ?")
            :format(data.read and "CURRENT_TIMESTAMP" or "NULL"),
        { id, session.id }
    )
    broadcast_mailbox_changed(session.id)
    return { success = true }
end)

Sky.Cb.Register("sky_phone:mail:trash", function(source, data)
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

    Sky.Query([[
        UPDATE `sky_phone_mail_entries` SET `trashed_at` = CURRENT_TIMESTAMP
        WHERE `id` = ? AND `account_id` = ? AND `trashed_at` IS NULL
    ]], { id, session.id })
    broadcast_mailbox_changed(session.id)
    return { success = true }
end)

Sky.Cb.Register("sky_phone:mail:restore", function(source, data)
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

    Sky.Query([[
        UPDATE `sky_phone_mail_entries` SET `trashed_at` = NULL
        WHERE `id` = ? AND `account_id` = ? AND `trashed_at` IS NOT NULL
    ]], { id, session.id })
    broadcast_mailbox_changed(session.id)
    return { success = true }
end)

Sky.Cb.Register("sky_phone:mail:delete-forever", function(source, data)
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

    Sky.Query([[
        DELETE FROM `sky_phone_mail_entries`
        WHERE `id` = ? AND `account_id` = ? AND `trashed_at` IS NOT NULL
    ]], { id, session.id })
    Sky.Query([[
        DELETE m FROM `sky_phone_mail_messages` m
        LEFT JOIN `sky_phone_mail_entries` e ON e.`message_id` = m.`id`
        WHERE e.`id` IS NULL
    ]], {})
    broadcast_mailbox_changed(session.id)
    return { success = true }
end)

Sky.Cb.Register("sky_phone:mail:empty-trash", function(source)
    local session, error_response = require_session(source)
    if not session then
        return error_response
    end

    Sky.Query(
        "DELETE FROM `sky_phone_mail_entries` WHERE `account_id` = ? AND `trashed_at` IS NOT NULL",
        { session.id }
    )
    Sky.Query([[
        DELETE m FROM `sky_phone_mail_messages` m
        LEFT JOIN `sky_phone_mail_entries` e ON e.`message_id` = m.`id`
        WHERE e.`id` IS NULL
    ]], {})
    broadcast_mailbox_changed(session.id)
    return { success = true }
end)
