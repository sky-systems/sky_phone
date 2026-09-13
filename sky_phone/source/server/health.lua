Bridge.Database.AfterMigration("sky_phone", function()

local activity_reports = {}
local allowed_blood_types = {
    [""] = true,
    ["A+"] = true,
    ["A-"] = true,
    ["B+"] = true,
    ["B-"] = true,
    ["AB+"] = true,
    ["AB-"] = true,
    ["O+"] = true,
    ["O-"] = true,
}

local function character_identifier(source, require_session)
    if require_session then
        local session, error_response = SkyPhone.RequireSession(source)
        if not session then
            return nil, error_response
        end
    end

    local identifier = Bridge.Framework.GetIdentifier(source)
    if type(identifier) ~= "string" or identifier == "" then
        return nil, { success = false, error = "health_unavailable" }
    end
    return identifier
end

local function player_name(source)
    local firstname = Bridge.Framework.GetFirstname(source)
    local lastname = Bridge.Framework.GetLastname(source)
    local name = ((firstname or "") .. " " .. (lastname or "")):match("^%s*(.-)%s*$")
    if name == "" then
        return GetPlayerName(source) or ("Player %s"):format(source)
    end
    return name
end

local function clean_text(value, maximum_length)
    if type(value) ~= "string" or value:find("[%z\1-\31]") then
        return nil
    end
    local cleaned = value:match("^%s*(.-)%s*$")
    if #cleaned > maximum_length then
        return nil
    end
    return cleaned
end

local function empty_profile(source)
    return {
        playerName = player_name(source),
        bloodType = "",
        allergies = "",
        conditions = "",
        medication = "",
        emergencyName = "",
        emergencyRelation = "",
        emergencyPhone = "",
    }
end

local function profile_for(source, identifier)
    local rows = Bridge.Database.Query([[
        SELECT `blood_type`, `allergies`, `conditions`, `medication`,
            `emergency_name`, `emergency_relation`, `emergency_phone`
        FROM `sky_phone_health_profiles`
        WHERE `owner_identifier` = ?
        LIMIT 1
    ]], { identifier })
    local row = rows[1]
    if not row then
        return empty_profile(source)
    end
    return {
        playerName = player_name(source),
        bloodType = row.blood_type or "",
        allergies = row.allergies or "",
        conditions = row.conditions or "",
        medication = row.medication or "",
        emergencyName = row.emergency_name or "",
        emergencyRelation = row.emergency_relation or "",
        emergencyPhone = row.emergency_phone or "",
    }
end

local function day_key(timestamp)
    return os.date("%Y-%m-%d", timestamp)
end

local function activity_history(identifier)
    local rows = Bridge.Database.Query([[
        SELECT DATE_FORMAT(`activity_date`, '%Y-%m-%d') AS `activity_date`,
            `steps`, `distance_meters`, `active_seconds`, `energy_kcal`
        FROM `sky_phone_health_daily`
        WHERE `owner_identifier` = ?
            AND `activity_date` >= DATE_SUB(CURDATE(), INTERVAL 13 DAY)
        ORDER BY `activity_date` ASC
    ]], { identifier })
    local by_date = {}
    for _, row in ipairs(rows) do
        by_date[row.activity_date] = row
    end

    local now = os.time()
    local days = {}
    local previous_week_steps = 0
    for days_ago = 13, 0, -1 do
        local date = day_key(now - days_ago * 86400)
        local row = by_date[date]
        local item = {
            date = date,
            steps = math.max(0, tonumber(row and row.steps) or 0),
            distanceMeters = math.max(0, tonumber(row and row.distance_meters) or 0),
            activeSeconds = math.max(0, tonumber(row and row.active_seconds) or 0),
            energyKcal = math.max(0, tonumber(row and row.energy_kcal) or 0),
        }
        if days_ago >= 7 then
            previous_week_steps = previous_week_steps + item.steps
        else
            days[#days + 1] = item
        end
    end
    return days, previous_week_steps
end

local function overview(source, identifier)
    local days, previous_week_steps = activity_history(identifier)
    return {
        dailyStepGoal = Config.Health.DailyStepGoal,
        days = days,
        previousWeekSteps = previous_week_steps,
        medicalId = profile_for(source, identifier),
        emergencyNumber = Config.Health.EmergencyNumber,
    }
end

Bridge.Callbacks.Register("sky_phone:health:overview", function(source)
    if not SkyPhone.AllowOperation(source, "health_overview", 60, 60) then
        return { success = false, error = "rate_limited" }
    end
    local identifier, error_response = character_identifier(source, true)
    if not identifier then
        return error_response
    end
    return { success = true, data = overview(source, identifier) }
end)

Bridge.Callbacks.Register("sky_phone:health:save-profile", function(source, data)
    if not SkyPhone.AllowOperation(source, "health_profile_save", 12, 60) then
        return { success = false, error = "rate_limited" }
    end
    local identifier, error_response = character_identifier(source, true)
    if not identifier then
        return error_response
    end
    if type(data) ~= "table" then
        return { success = false, error = "invalid_request" }
    end

    local blood_type = clean_text(data.bloodType, 3)
    local allergies = clean_text(data.allergies, Config.Health.ProfileTextMaxLength)
    local conditions = clean_text(data.conditions, Config.Health.ProfileTextMaxLength)
    local medication = clean_text(data.medication, Config.Health.ProfileTextMaxLength)
    local emergency_name = clean_text(data.emergencyName, 80)
    local emergency_relation = clean_text(data.emergencyRelation, 40)
    local emergency_phone = clean_text(data.emergencyPhone, 24)
    if not blood_type or not allowed_blood_types[blood_type]
        or not allergies or not conditions or not medication
        or not emergency_name or not emergency_relation or not emergency_phone
    then
        return { success = false, error = "invalid_request" }
    end
    if emergency_phone ~= "" then
        emergency_phone = SkyPhoneSimNumber.Normalize(
            emergency_phone,
            Config.Sim.NumberLength,
            Config.Sim.NumberPrefix
        )
        if not emergency_phone then
            return { success = false, error = "invalid_phone_number" }
        end
    end

    Bridge.Database.Query([[
        INSERT INTO `sky_phone_health_profiles`
            (`owner_identifier`, `blood_type`, `allergies`, `conditions`, `medication`,
                `emergency_name`, `emergency_relation`, `emergency_phone`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            `blood_type` = VALUES(`blood_type`),
            `allergies` = VALUES(`allergies`),
            `conditions` = VALUES(`conditions`),
            `medication` = VALUES(`medication`),
            `emergency_name` = VALUES(`emergency_name`),
            `emergency_relation` = VALUES(`emergency_relation`),
            `emergency_phone` = VALUES(`emergency_phone`)
    ]], {
        identifier,
        blood_type,
        allergies,
        conditions,
        medication,
        emergency_name,
        emergency_relation,
        emergency_phone,
    })
    return { success = true, data = profile_for(source, identifier) }
end)

RegisterNetEvent("sky_phone:health:record-activity", function(data)
    local player_source = source
    if type(data) ~= "table"
        or type(data.steps) ~= "number" or data.steps ~= math.floor(data.steps)
        or type(data.distanceMeters) ~= "number" or data.distanceMeters ~= math.floor(data.distanceMeters)
        or type(data.activeSeconds) ~= "number" or data.activeSeconds ~= math.floor(data.activeSeconds)
        or data.steps < 0 or data.distanceMeters < 0 or data.activeSeconds < 0
    then
        Bridge.Debug("warn", "[sky_phone] Rejected malformed health activity from source %s.", tostring(player_source))
        return
    end
    if not SkyPhone.AllowOperation(player_source, "health_activity", Config.Health.ReportsPerMinute, 60) then
        return
    end

    local identifier = character_identifier(player_source, false)
    if not identifier then
        return
    end
    local now = os.time()
    local previous = activity_reports[player_source]
    local elapsed = previous and math.max(1, now - previous) or Config.Health.ReportIntervalSeconds + 5
    activity_reports[player_source] = now
    local maximum_distance = math.ceil(elapsed * Config.Health.MaximumSpeedMetersPerSecond)
    local maximum_steps = math.ceil(data.distanceMeters / 0.35) + 4
    if data.distanceMeters > maximum_distance
        or data.activeSeconds > elapsed + 5
        or data.distanceMeters > data.activeSeconds * Config.Health.MaximumSpeedMetersPerSecond + 5
        or data.steps > maximum_steps
    then
        Bridge.Debug("warn", "[sky_phone] Rejected implausible health activity from source %s.", tostring(player_source))
        return
    end
    if data.steps == 0 and data.distanceMeters == 0 and data.activeSeconds == 0 then
        return
    end

    local energy_kcal = math.floor(data.distanceMeters * 0.06 + 0.5)
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_health_daily`
            (`owner_identifier`, `activity_date`, `steps`, `distance_meters`, `active_seconds`, `energy_kcal`)
        VALUES (?, CURDATE(), ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            `steps` = `steps` + VALUES(`steps`),
            `distance_meters` = `distance_meters` + VALUES(`distance_meters`),
            `active_seconds` = `active_seconds` + VALUES(`active_seconds`),
            `energy_kcal` = `energy_kcal` + VALUES(`energy_kcal`)
    ]], { identifier, data.steps, data.distanceMeters, data.activeSeconds, energy_kcal })
    if SkyPhoneLog then
        SkyPhoneLog.Record("Health", "health:activity", "recorded", player_source, {
            steps = data.steps, distanceMeters = data.distanceMeters,
            activeSeconds = data.activeSeconds, energyKcal = energy_kcal,
        })
    end
    TriggerClientEvent("sky_phone:health:changed", player_source)
end)

AddEventHandler("playerDropped", function()
    activity_reports[source] = nil
end)

end)
