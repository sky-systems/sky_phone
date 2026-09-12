Bridge.Callbacks.RegisterDeferred("sky_phone:citywarn:blips")

Bridge.Database.AfterMigration("sky_phone", function()
local config = Config.CityWarn

if type(config) ~= "table" then
    error("[sky_phone] Config.CityWarn must be configured.")
end

local categories = {
    public_safety = true,
    police = true,
    fire = true,
    medical = true,
    infrastructure = true,
    evacuation = true,
}
local severity_rank = {
    information = 1,
    warning = 2,
    danger = 3,
    extreme = 4,
}

local function require_integer_config(name, minimum, maximum)
    local value = config[name]
    if type(value) ~= "number" or value ~= math.floor(value) or value < minimum or value > maximum then
        error(("[sky_phone] Config.CityWarn.%s must be an integer between %d and %d."):format(name, minimum, maximum))
    end
end

if type(config.Enabled) ~= "boolean" or type(config.RequireDuty) ~= "boolean" then
    error("[sky_phone] CityWarn Enabled and RequireDuty must be booleans.")
end
require_integer_config("PageSize", 1, 100)
require_integer_config("MaximumActiveAlerts", 1, 1000)
require_integer_config("TitleMaxLength", 1, 120)
require_integer_config("BodyMaxLength", 1, 2000)
require_integer_config("InstructionsMaxLength", 1, 2000)
require_integer_config("UpdateMaxLength", 1, 2000)
require_integer_config("AreaLabelMaxLength", 1, 120)
require_integer_config("MinimumRadius", 1, 10000)
require_integer_config("MaximumRadius", config.MinimumRadius, 50000)
require_integer_config("DefaultDurationMinutes", 1, 1440)
require_integer_config("MaximumDurationMinutes", config.DefaultDurationMinutes, 10080)

if type(config.RateLimits) ~= "table" or type(config.Publishers) ~= "table" then
    error("[sky_phone] CityWarn RateLimits and Publishers must be tables.")
end
for _, name in ipairs({ "Read", "Write" }) do
    local value = config.RateLimits[name]
    if type(value) ~= "number" or value ~= math.floor(value) or value < 1 or value > 10000 then
        error(("[sky_phone] Invalid CityWarn rate limit '%s'."):format(name))
    end
end
for job_name, publisher in pairs(config.Publishers) do
    if type(job_name) ~= "string" or not job_name:match("^[%w_-]+$") or type(publisher) ~= "table"
        or type(publisher.MinimumGrade) ~= "number" or publisher.MinimumGrade < 0
        or publisher.MinimumGrade ~= math.floor(publisher.MinimumGrade)
        or not severity_rank[publisher.MaximumSeverity] or type(publisher.CityWide) ~= "boolean"
        or type(publisher.Categories) ~= "table"
    then
        error(("[sky_phone] Invalid CityWarn publisher '%s'."):format(tostring(job_name)))
    end
    local seen = {}
    for _, category in ipairs(publisher.Categories) do
        if not categories[category] or seen[category] then
            error(("[sky_phone] Invalid CityWarn category '%s' for publisher '%s'."):format(tostring(category), job_name))
        end
        seen[category] = true
    end
end

local alert_columns = [[
    alert.`id`, alert.`title`, alert.`body`, alert.`instructions`, alert.`category`,
    alert.`severity`, alert.`status`, alert.`area_type`, alert.`area_label`,
    alert.`center_x`, alert.`center_y`, alert.`radius`, alert.`source_label`,
    alert.`author_name`, alert.`revision`,
    UNIX_TIMESTAMP(alert.`starts_at`) AS `starts_at_unix`,
    UNIX_TIMESTAMP(alert.`expires_at`) AS `expires_at_unix`,
    UNIX_TIMESTAMP(alert.`created_at`) AS `created_at_unix`,
    UNIX_TIMESTAMP(alert.`updated_at`) AS `updated_at_unix`
]]

local function trim(value)
    if type(value) ~= "string" then
        return nil
    end
    return value:match("^%s*(.-)%s*$")
end

local function text_length(value)
    if type(value) ~= "string" then
        return nil
    end
    local success, length = pcall(utf8.len, value)
    return success and length or nil
end

local function valid_text(value, maximum, allow_empty)
    local normalized = trim(value)
    local length = text_length(normalized)
    if not length or normalized:find("%z") or length > maximum or (not allow_empty and length < 1) then
        return nil
    end
    return normalized
end

local function valid_number(value, minimum, maximum)
    local number = tonumber(value)
    if not number or number ~= number or number < minimum or number > maximum then
        return nil
    end
    return number
end

local function valid_integer(value, minimum, maximum)
    local number = valid_number(value, minimum, maximum)
    return number and number == math.floor(number) and number or nil
end

local function valid_uuid(value)
    return type(value) == "string"
        and value:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end
    return type(result) == "table" and tonumber(result.affectedRows) or 0
end

local function new_uuid()
    local rows = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    local id = rows[1] and rows[1].id
    if not valid_uuid(id) then
        error("[sky_phone] Database did not generate a valid CityWarn UUID.")
    end
    return id
end

local function require_phone(source, operation, maximum)
    if not config.Enabled then
        return nil, { success = false, error = "feature_disabled" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return nil, error_response
    end
    if not SkyPhone.AllowOperation(source, "citywarn_" .. operation, maximum, 60) then
        return nil, { success = false, error = "rate_limited" }
    end
    return session
end

local function publisher_access(source)
    local job = Bridge.Framework.GetJob(source)
    local publisher = config.Publishers[job.name]
    local grade = tonumber(job.grade) or 0
    local on_duty = job.onDuty == true
    if not publisher or grade < publisher.MinimumGrade or (config.RequireDuty and not on_duty) then
        return nil, job, publisher
    end
    local allowed_categories = {}
    local allowed_lookup = {}
    for _, category in ipairs(publisher.Categories) do
        allowed_categories[#allowed_categories + 1] = category
        allowed_lookup[category] = true
    end
    return {
        allowed_categories = allowed_categories,
        allowed_lookup = allowed_lookup,
        can_city_wide = publisher.CityWide,
        job_name = job.name,
        job_label = type(job.label) == "string" and job.label or job.name,
        grade_label = type(job.gradeLabel) == "string" and job.gradeLabel or "",
        maximum_severity = publisher.MaximumSeverity,
        on_duty = on_duty,
    }, job, publisher
end

local function context_dto(source)
    local access, job, publisher = publisher_access(source)
    local allowed_categories = {}
    if publisher and type(publisher.Categories) == "table" then
        for _, category in ipairs(publisher.Categories) do
            allowed_categories[#allowed_categories + 1] = category
        end
    end
    return {
        canPublish = access ~= nil,
        jobLabel = publisher and (job.label or job.name) or nil,
        gradeLabel = publisher and (job.gradeLabel or "") or nil,
        onDuty = job.onDuty == true,
        requiresDuty = config.RequireDuty,
        allowedCategories = allowed_categories,
        maximumSeverity = publisher and publisher.MaximumSeverity or nil,
        canCityWide = publisher and publisher.CityWide == true or false,
    }
end

local function require_publisher(source)
    local access = publisher_access(source)
    if not access then
        return nil, { success = false, error = "not_authorized" }
    end
    return access
end

local function actor_identity(source)
    local identifier = Bridge.Framework.GetIdentifier(source)
    if type(identifier) ~= "string" or #identifier < 1 or #identifier > 80 then
        return nil
    end
    local first_name = trim(Bridge.Framework.GetFirstname(source)) or ""
    local last_name = trim(Bridge.Framework.GetLastname(source)) or ""
    local name = trim(first_name .. " " .. last_name)
    if not name or name == "" then
        name = trim(GetPlayerName(source)) or "CityWarn"
    end
    if #name > 120 then
        name = name:sub(1, 120)
    end
    return { identifier = identifier, name = name }
end

local function alert_dto(row)
    return {
        id = row.id,
        title = row.title,
        body = row.body,
        instructions = row.instructions,
        category = row.category,
        severity = row.severity,
        status = row.status,
        area = {
            type = row.area_type,
            label = row.area_label,
            centerX = row.center_x and tonumber(row.center_x) or nil,
            centerY = row.center_y and tonumber(row.center_y) or nil,
            radius = row.radius and tonumber(row.radius) or nil,
        },
        sourceLabel = row.source_label,
        authorName = row.author_name,
        revision = tonumber(row.revision) or 1,
        startsAt = tonumber(row.starts_at_unix) * 1000,
        expiresAt = tonumber(row.expires_at_unix) * 1000,
        createdAt = tonumber(row.created_at_unix) * 1000,
        updatedAt = tonumber(row.updated_at_unix) * 1000,
        updates = {},
    }
end

local function attach_updates(alerts)
    if #alerts < 1 then
        return alerts
    end
    local ids, placeholders, by_id = {}, {}, {}
    for index, alert in ipairs(alerts) do
        ids[index] = alert.id
        placeholders[index] = "?"
        by_id[alert.id] = alert
    end
    local rows = Bridge.Database.Query(([[
        SELECT `id`, `alert_id`, `kind`, `message`, `actor_name`,
            UNIX_TIMESTAMP(`created_at`) AS `created_at_unix`
        FROM `sky_phone_citywarn_updates`
        WHERE `alert_id` IN (%s)
        ORDER BY `created_at` DESC, `id` DESC
    ]]):format(table.concat(placeholders, ",")), ids)
    for _, row in ipairs(rows) do
        local alert = by_id[row.alert_id]
        if alert then
            alert.updates[#alert.updates + 1] = {
                id = row.id,
                kind = row.kind,
                message = row.message,
                actorName = row.actor_name,
                createdAt = tonumber(row.created_at_unix) * 1000,
            }
        end
    end
    return alerts
end

local function expire_alerts()
    Bridge.Database.Query([[
        UPDATE `sky_phone_citywarn_alerts`
        SET `status` = 'expired', `revision` = `revision` + 1
        WHERE `status` = 'active' AND `expires_at` <= NOW()
    ]], {})
end

local function query_alerts(status)
    local where = status == "active"
        and "alert.`status` = 'active' AND alert.`expires_at` > NOW()"
        or "(alert.`status` <> 'active' OR alert.`expires_at` <= NOW())"
    local rows = Bridge.Database.Query(([[
        SELECT %s
        FROM `sky_phone_citywarn_alerts` alert
        WHERE %s
        ORDER BY alert.`created_at` DESC, alert.`id` DESC
        LIMIT ?
    ]]):format(alert_columns, where), { config.PageSize })
    local alerts = {}
    for _, row in ipairs(rows) do
        alerts[#alerts + 1] = alert_dto(row)
    end
    return attach_updates(alerts)
end

local function load_alert(id)
    local rows = Bridge.Database.Query(([[
        SELECT %s FROM `sky_phone_citywarn_alerts` alert WHERE alert.`id` = ? LIMIT 1
    ]]):format(alert_columns), { id })
    local alert = rows[1] and alert_dto(rows[1]) or nil
    return alert and attach_updates({ alert })[1] or nil
end

local function validate_area(data, access)
    if type(data) ~= "table" or (data.type ~= "radius" and data.type ~= "district" and data.type ~= "city") then
        return nil
    end
    local label = valid_text(data.label, config.AreaLabelMaxLength, false)
    if not label or (data.type == "city" and not access.can_city_wide) then
        return nil
    end
    local center_x, center_y, radius
    if data.type == "radius" then
        center_x = valid_number(data.centerX, -10000, 10000)
        center_y = valid_number(data.centerY, -10000, 10000)
        radius = valid_integer(data.radius, config.MinimumRadius, config.MaximumRadius)
        if not center_x or not center_y or not radius then
            return nil
        end
    elseif data.centerX ~= nil or data.centerY ~= nil then
        center_x = valid_number(data.centerX, -10000, 10000)
        center_y = valid_number(data.centerY, -10000, 10000)
        if not center_x or not center_y then
            return nil
        end
    end
    return {
        type = data.type,
        label = label,
        center_x = center_x,
        center_y = center_y,
        radius = radius,
    }
end

local blip_cache
local blip_version = 0

local function invalidate_blips()
    blip_cache = nil
    blip_version = blip_version + 1
end

AddEventHandler("sky_phone:configurator:serverUpdated", function()
    config = Config.CityWarn
    invalidate_blips()
end)

-- Population warnings are public, including while a phone is closed. This
-- read-only endpoint deliberately does not require an open device session.
Bridge.Callbacks.Register("sky_phone:citywarn:blips", function(source)
    if not SkyPhone.AllowOperation(source, "citywarn_blips", 60, 60) then
        return { success = false, error = "rate_limited" }
    end
    if not config.Enabled then
        return { success = true, data = { alerts = {} } }
    end

    if not blip_cache or ((GetGameTimer() - blip_cache.created_at) & 0xffffffff) >= 5000 then
        local version = blip_version
        local started_at = GetGameTimer()
        local rows = Bridge.Database.Query([[
            SELECT `id`, `title`, `severity`, `area_type`, `center_x`, `center_y`, `radius`,
                TIMESTAMPDIFF(SECOND, NOW(), `expires_at`) AS `remaining_seconds`
            FROM `sky_phone_citywarn_alerts`
            WHERE `status` = 'active' AND `expires_at` > NOW()
                AND `area_type` IN ('radius', 'district')
                AND `center_x` IS NOT NULL AND `center_y` IS NOT NULL
        ]], {})
        -- A publication/resolution can complete while the database query yields.
        if version ~= blip_version then
            return { success = false, error = "revision_conflict" }
        end
        blip_cache = { created_at = started_at, rows = rows }
    end

    local age = (GetGameTimer() - blip_cache.created_at) & 0xffffffff
    local alerts = {}
    for _, row in ipairs(blip_cache.rows) do
        local remaining_ms = (tonumber(row.remaining_seconds) or 0) * 1000 - age
        if remaining_ms > 0 then
            alerts[#alerts + 1] = {
                id = row.id,
                title = row.title,
                severity = row.severity,
                x = tonumber(row.center_x),
                y = tonumber(row.center_y),
                radius = row.area_type == "radius" and tonumber(row.radius) or nil,
                remainingMs = remaining_ms,
            }
        end
    end
    return { success = true, data = { alerts = alerts } }
end)

local function broadcast(kind, alert)
    invalidate_blips()
    TriggerClientEvent("sky_phone:citywarn:changed", -1, {
        alert = alert,
        alertId = alert.id,
        kind = kind,
        severity = alert.severity,
        sourceLabel = alert.sourceLabel,
    })
end

Bridge.Callbacks.Register("sky_phone:citywarn:bootstrap", function(source)
    local _, error_response = require_phone(source, "read", config.RateLimits.Read)
    if error_response then
        return error_response
    end
    expire_alerts()
    return {
        success = true,
        data = {
            active = query_alerts("active"),
            archive = query_alerts("archive"),
            context = context_dto(source),
            onlinePlayers = #Bridge.Framework.GetPlayers(),
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:citywarn:publish", function(source, data)
    local _, error_response = require_phone(source, "write", config.RateLimits.Write)
    if error_response then
        return error_response
    end
    local access, access_error = require_publisher(source)
    if access_error then
        return access_error
    end
    local actor = actor_identity(source)
    local title = type(data) == "table" and valid_text(data.title, config.TitleMaxLength, false) or nil
    local body = type(data) == "table" and valid_text(data.body, config.BodyMaxLength, false) or nil
    local instructions = type(data) == "table" and valid_text(data.instructions, config.InstructionsMaxLength, true) or nil
    local duration = type(data) == "table" and valid_integer(data.durationMinutes, 1, config.MaximumDurationMinutes) or nil
    local area = type(data) == "table" and validate_area(data.area, access) or nil
    if not actor or not title or not body or instructions == nil or not duration or not area
        or not access.allowed_lookup[data.category]
        or not severity_rank[data.severity]
        or severity_rank[data.severity] > severity_rank[access.maximum_severity]
    then
        return { success = false, error = "invalid_warning" }
    end
    local counts = Bridge.Database.Query([[
        SELECT COUNT(*) AS `count` FROM `sky_phone_citywarn_alerts`
        WHERE `status` = 'active' AND `expires_at` > NOW()
    ]], {})
    if tonumber(counts[1] and counts[1].count) >= config.MaximumActiveAlerts then
        return { success = false, error = "active_limit" }
    end

    local id = new_uuid()
    local result = Bridge.Database.Query([[
        INSERT INTO `sky_phone_citywarn_alerts`
            (`id`, `title`, `body`, `instructions`, `category`, `severity`, `area_type`, `area_label`,
             `center_x`, `center_y`, `radius`, `source_job`, `source_label`, `author_identifier`,
             `author_name`, `expires_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
    ]], {
        id, title, body, instructions, data.category, data.severity, area.type, area.label,
        area.center_x, area.center_y, area.radius, access.job_name, access.job_label,
        actor.identifier, actor.name, duration,
    })
    if affected_rows(result) ~= 1 then
        return { success = false, error = "request_failed" }
    end
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_citywarn_updates`
            (`id`, `alert_id`, `kind`, `message`, `actor_identifier`, `actor_name`)
        VALUES (?, ?, 'published', ?, ?, ?)
    ]], { new_uuid(), id, title, actor.identifier, actor.name })
    local alert = load_alert(id)
    broadcast("published", alert)
    return {
        success = true,
        data = { alert = alert, recipients = #Bridge.Framework.GetPlayers() },
    }
end)

Bridge.Callbacks.Register("sky_phone:citywarn:update", function(source, data)
    local _, error_response = require_phone(source, "write", config.RateLimits.Write)
    if error_response then
        return error_response
    end
    local _, access_error = require_publisher(source)
    if access_error then
        return access_error
    end
    local actor = actor_identity(source)
    local message = type(data) == "table" and valid_text(data.message, config.UpdateMaxLength, false) or nil
    local revision = type(data) == "table" and valid_integer(data.revision, 1, 4294967295) or nil
    if not actor or not message or not revision or not valid_uuid(data.id) then
        return { success = false, error = "invalid_update" }
    end
    local result = Bridge.Database.Query([[
        UPDATE `sky_phone_citywarn_alerts`
        SET `revision` = `revision` + 1
        WHERE `id` = ? AND `status` = 'active' AND `expires_at` > NOW() AND `revision` = ?
    ]], { data.id, revision })
    if affected_rows(result) ~= 1 then
        return { success = false, error = "revision_conflict" }
    end
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_citywarn_updates`
            (`id`, `alert_id`, `kind`, `message`, `actor_identifier`, `actor_name`)
        VALUES (?, ?, 'update', ?, ?, ?)
    ]], { new_uuid(), data.id, message, actor.identifier, actor.name })
    local alert = load_alert(data.id)
    broadcast("update", alert)
    return { success = true, data = { alert = alert } }
end)

Bridge.Callbacks.Register("sky_phone:citywarn:resolve", function(source, data)
    local _, error_response = require_phone(source, "write", config.RateLimits.Write)
    if error_response then
        return error_response
    end
    local _, access_error = require_publisher(source)
    if access_error then
        return access_error
    end
    local actor = actor_identity(source)
    local message = type(data) == "table" and valid_text(data.message, config.UpdateMaxLength, false) or nil
    local revision = type(data) == "table" and valid_integer(data.revision, 1, 4294967295) or nil
    if not actor or not message or not revision or not valid_uuid(data.id) then
        return { success = false, error = "invalid_update" }
    end
    local result = Bridge.Database.Query([[
        UPDATE `sky_phone_citywarn_alerts`
        SET `status` = 'resolved', `resolved_at` = NOW(), `revision` = `revision` + 1
        WHERE `id` = ? AND `status` = 'active' AND `revision` = ?
    ]], { data.id, revision })
    if affected_rows(result) ~= 1 then
        return { success = false, error = "revision_conflict" }
    end
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_citywarn_updates`
            (`id`, `alert_id`, `kind`, `message`, `actor_identifier`, `actor_name`)
        VALUES (?, ?, 'resolved', ?, ?, ?)
    ]], { new_uuid(), data.id, message, actor.identifier, actor.name })
    local alert = load_alert(data.id)
    broadcast("resolved", alert)
    return { success = true, data = { alert = alert } }
end)
end)
