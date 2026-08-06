Bridge.Database.AfterMigration("sky_phone", function()
local reminder_minutes = {
    [0] = true,
    [10] = true,
    [30] = true,
    [60] = true,
    [1440] = true,
}

local function text_length(value)
    return type(value) == "string" and utf8.len(value) or nil
end

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end
    return type(result) == "table" and tonumber(result.affectedRows) or 0
end

local function event_dto(row)
    return {
        id = row.id,
        title = row.title,
        note = row.note,
        startsAt = (tonumber(row.starts_at_unix) or 0) * 1000,
        endsAt = (tonumber(row.ends_at_unix) or 0) * 1000,
        reminderMinutes = row.reminder_minutes and tonumber(row.reminder_minutes) or nil,
        remindedAt = row.reminded_at_unix and tonumber(row.reminded_at_unix) * 1000 or nil,
        revision = tonumber(row.revision) or 1,
    }
end

local function list_events(account_id, starts_at, ends_at)
    local rows = Bridge.Database.Query([[
        SELECT `id`, `title`, `note`, `reminder_minutes`, `revision`,
            UNIX_TIMESTAMP(`starts_at`) AS `starts_at_unix`,
            UNIX_TIMESTAMP(`ends_at`) AS `ends_at_unix`,
            UNIX_TIMESTAMP(`reminded_at`) AS `reminded_at_unix`
        FROM `sky_phone_calendar_events`
        WHERE `account_id` = ?
            AND `ends_at` >= FROM_UNIXTIME(?)
            AND `starts_at` < FROM_UNIXTIME(?)
        ORDER BY `starts_at`, `ends_at`, `id`
        LIMIT 500
    ]], { account_id, starts_at, ends_at })
    local events = {}
    for _, row in ipairs(rows) do
        events[#events + 1] = event_dto(row)
    end
    return events
end

local function valid_range(starts_at, ends_at)
    local now = os.time()
    return starts_at >= now - Config.Calendar.PastEditSeconds
        and starts_at <= now + Config.Calendar.FutureSeconds
        and ends_at > starts_at
        and ends_at - starts_at <= Config.Calendar.MaximumDurationSeconds
end

local function validate_event(data)
    if type(data) ~= "table" then
        return nil
    end
    local title_length = text_length(data.title)
    local note_length = text_length(data.note)
    local starts_at = math.floor(tonumber(data.startsAt) or 0)
    local ends_at = math.floor(tonumber(data.endsAt) or 0)
    local reminder = data.reminderMinutes
    if not title_length
        or title_length < 1
        or title_length > Config.Calendar.TitleMaxLength
        or not note_length
        or note_length > Config.Calendar.NoteMaxLength
        or not valid_range(starts_at, ends_at)
        or (reminder ~= nil and not reminder_minutes[tonumber(reminder)])
    then
        return nil
    end
    return {
        title = data.title,
        note = data.note,
        starts_at = starts_at,
        ends_at = ends_at,
        reminder_minutes = reminder == nil and nil or tonumber(reminder),
    }
end

Bridge.Callbacks.Register("sky_phone:calendar:list", function(source, data)
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then
        return error_response
    end
    local starts_at = math.floor(tonumber(data and data.startsAt) or 0)
    local ends_at = math.floor(tonumber(data and data.endsAt) or 0)
    if starts_at <= 0 or ends_at <= starts_at or ends_at - starts_at > Config.Calendar.MaximumQuerySeconds then
        return { success = false, error = "invalid_range" }
    end
    return { success = true, data = list_events(account.id, starts_at, ends_at) }
end)

Bridge.Callbacks.Register("sky_phone:calendar:create", function(source, data)
    if not SkyPhone.AllowOperation(source, "calendar_write", 60, 60) then
        return { success = false, error = "rate_limited" }
    end
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then
        return error_response
    end
    local event = validate_event(data)
    if not event then
        return { success = false, error = "invalid_event" }
    end
    local ids = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    local id = ids[1] and ids[1].id
    if type(id) ~= "string" then
        error("[sky_phone] Database did not generate a calendar event id.")
    end
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_calendar_events`
            (`id`, `account_id`, `title`, `note`, `starts_at`, `ends_at`, `reminder_minutes`)
        VALUES (?, ?, ?, ?, FROM_UNIXTIME(?), FROM_UNIXTIME(?), ?)
    ]], {
        id,
        account.id,
        event.title,
        event.note,
        event.starts_at,
        event.ends_at,
        event.reminder_minutes,
    })
    return { success = true, data = { id = id } }
end)

Bridge.Callbacks.Register("sky_phone:calendar:update", function(source, data)
    if not SkyPhone.AllowOperation(source, "calendar_write", 60, 60) then
        return { success = false, error = "rate_limited" }
    end
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then
        return error_response
    end
    local event = validate_event(data)
    if not event or type(data.id) ~= "string" then
        return { success = false, error = "invalid_event" }
    end
    local revision = math.max(1, math.floor(tonumber(data.revision) or 0))
    local result = Bridge.Database.Query([[
        UPDATE `sky_phone_calendar_events`
        SET `title` = ?, `note` = ?, `starts_at` = FROM_UNIXTIME(?),
            `ends_at` = FROM_UNIXTIME(?), `reminder_minutes` = ?,
            `reminded_at` = NULL, `revision` = `revision` + 1
        WHERE `id` = ? AND `account_id` = ? AND `revision` = ?
    ]], {
        event.title,
        event.note,
        event.starts_at,
        event.ends_at,
        event.reminder_minutes,
        data.id,
        account.id,
        revision,
    })
    if affected_rows(result) ~= 1 then
        return { success = false, error = "conflict" }
    end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:calendar:delete", function(source, data)
    if not SkyPhone.AllowOperation(source, "calendar_write", 60, 60) then
        return { success = false, error = "rate_limited" }
    end
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then
        return error_response
    end
    if type(data) ~= "table" or type(data.id) ~= "string" then
        return { success = false, error = "invalid_event" }
    end
    Bridge.Database.Query(
        "DELETE FROM `sky_phone_calendar_events` WHERE `id` = ? AND `account_id` = ?",
        { data.id, account.id }
    )
    return { success = true }
end)

CreateThread(function()
    while true do
        Wait(Config.Calendar.ReminderPollSeconds * 1000)
        local due_events = Bridge.Database.Query([[
            SELECT `id`, `account_id`, `title`, UNIX_TIMESTAMP(`starts_at`) AS `starts_at_unix`
            FROM `sky_phone_calendar_events`
            WHERE `reminder_minutes` IS NOT NULL
                AND `reminded_at` IS NULL
                AND DATE_SUB(`starts_at`, INTERVAL `reminder_minutes` MINUTE) <= CURRENT_TIMESTAMP
                AND `starts_at` >= DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 DAY)
            ORDER BY `starts_at`
            LIMIT 100
        ]], {})
        for _, event in ipairs(due_events) do
            local result = Bridge.Database.Query([[
                UPDATE `sky_phone_calendar_events`
                SET `reminded_at` = CURRENT_TIMESTAMP
                WHERE `id` = ? AND `reminded_at` IS NULL
            ]], { event.id })
            if affected_rows(result) == 1 then
                SkyPhone.NotifyAccountDevices(event.account_id, "sky_phone:calendar:reminder", {
                    eventId = event.id,
                    eventTitle = event.title,
                    startsAt = (tonumber(event.starts_at_unix) or 0) * 1000,
                })
            end
        end
    end
end)
end)
