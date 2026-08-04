SkyPhoneNotes = {}

local function text_length(value)
    return type(value) == "string" and utf8.len(value) or nil
end

local function note_owner(account_id, imei)
    if account_id then
        return "`account_id` = ?", { account_id }
    end
    return "`account_id` IS NULL AND `device_imei` = ?", { imei }
end

local function note_dto(row)
    return {
        id = row.id,
        title = row.title,
        body = row.body,
        pinned = tonumber(row.pinned) == 1,
        revision = tonumber(row.revision) or 1,
        createdAt = (tonumber(row.created_at_unix) or 0) * 1000,
        updatedAt = (tonumber(row.updated_at_unix) or 0) * 1000,
    }
end

local function notify_owner(account_id, imei)
    if account_id then
        SkyPhone.RefreshAccount(account_id)
    else
        SkyPhone.RefreshDevice(imei)
    end
end

function SkyPhoneNotes.List(account_id, imei)
    local condition, params = note_owner(account_id, imei)
    local rows = Sky.Query(([[
        SELECT `id`, `title`, `body`, `pinned`, `revision`,
            UNIX_TIMESTAMP(`created_at`) AS `created_at_unix`,
            UNIX_TIMESTAMP(`updated_at`) AS `updated_at_unix`
        FROM `sky_phone_notes`
        WHERE %s
        ORDER BY `pinned` DESC, `updated_at` DESC
    ]]):format(condition), params)
    local notes = {}
    for _, row in ipairs(rows) do
        notes[#notes + 1] = note_dto(row)
    end
    return notes
end

local function session_owner(source)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return nil, nil, error_response
    end
    local account = SkyPhone.RequireAccount(source)
    return account and account.id or nil, session.imei
end

Sky.Cb.Register("sky_phone:notes:list", function(source)
    local account_id, imei, error_response = session_owner(source)
    if not imei then
        return error_response
    end
    return { success = true, data = SkyPhoneNotes.List(account_id, imei) }
end)

Sky.Cb.Register("sky_phone:notes:create", function(source, data)
    if not SkyPhone.AllowOperation(source, "notes_write", 120, 60) then
        return { success = false, error = "rate_limited" }
    end
    local account_id, imei, error_response = session_owner(source)
    if not imei then
        return error_response
    end
    if type(data) ~= "table"
        or type(data.id) ~= "string"
        or #data.id < 8
        or #data.id > 64
        or not data.id:match("^[%w%-]+$")
        or not text_length(data.title)
        or text_length(data.title) > 120
        or not text_length(data.body)
        or text_length(data.body) > 20000
        or type(data.pinned) ~= "boolean"
    then
        return { success = false, error = "invalid_note" }
    end

    local result
    if account_id then
        result = Sky.Query([[
            INSERT IGNORE INTO `sky_phone_notes`
                (`id`, `account_id`, `device_imei`, `title`, `body`, `pinned`)
            VALUES (?, ?, NULL, ?, ?, ?)
        ]], { data.id, account_id, data.title, data.body, data.pinned and 1 or 0 })
    else
        result = Sky.Query([[
            INSERT IGNORE INTO `sky_phone_notes`
                (`id`, `account_id`, `device_imei`, `title`, `body`, `pinned`)
            VALUES (?, NULL, ?, ?, ?, ?)
        ]], { data.id, imei, data.title, data.body, data.pinned and 1 or 0 })
    end
    local affected = type(result) == "number" and result
        or (type(result) == "table" and tonumber(result.affectedRows) or 0)
    if affected <= 0 then
        return { success = false, error = "note_exists" }
    end

    notify_owner(account_id, imei)
    return { success = true, data = SkyPhoneNotes.List(account_id, imei) }
end)

Sky.Cb.Register("sky_phone:notes:update", function(source, data)
    if not SkyPhone.AllowOperation(source, "notes_write", 120, 60) then
        return { success = false, error = "rate_limited" }
    end
    local account_id, imei, error_response = session_owner(source)
    if not imei then
        return error_response
    end
    if type(data) ~= "table"
        or type(data.id) ~= "string"
        or not text_length(data.title)
        or text_length(data.title) > 120
        or not text_length(data.body)
        or text_length(data.body) > 20000
        or type(data.pinned) ~= "boolean"
    then
        return { success = false, error = "invalid_note" }
    end

    local revision = math.max(1, math.floor(tonumber(data.revision) or 0))
    local condition, owner_params = note_owner(account_id, imei)
    local params = { data.title, data.body, data.pinned and 1 or 0, data.id }
    for _, value in ipairs(owner_params) do
        params[#params + 1] = value
    end
    params[#params + 1] = revision
    local result = Sky.Query(([[
        UPDATE `sky_phone_notes`
        SET `title` = ?, `body` = ?, `pinned` = ?, `revision` = `revision` + 1
        WHERE `id` = ? AND %s AND `revision` = ?
    ]]):format(condition), params)
    local affected = type(result) == "number" and result
        or (type(result) == "table" and tonumber(result.affectedRows) or 0)
    if affected ~= 1 then
        return { success = false, error = "conflict", data = SkyPhoneNotes.List(account_id, imei) }
    end

    notify_owner(account_id, imei)
    return { success = true, data = SkyPhoneNotes.List(account_id, imei) }
end)

Sky.Cb.Register("sky_phone:notes:delete", function(source, data)
    if not SkyPhone.AllowOperation(source, "notes_write", 120, 60) then
        return { success = false, error = "rate_limited" }
    end
    local account_id, imei, error_response = session_owner(source)
    if not imei then
        return error_response
    end
    if type(data) ~= "table" or type(data.id) ~= "string" then
        return { success = false, error = "invalid_note" }
    end

    local condition, owner_params = note_owner(account_id, imei)
    local params = { data.id }
    for _, value in ipairs(owner_params) do
        params[#params + 1] = value
    end
    Sky.Query(("DELETE FROM `sky_phone_notes` WHERE `id` = ? AND %s"):format(condition), params)
    notify_owner(account_id, imei)
    return { success = true, data = SkyPhoneNotes.List(account_id, imei) }
end)
