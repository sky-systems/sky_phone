Bridge.Database.AfterMigration("sky_phone", function()
local marker_colors = {
    blue = true,
    green = true,
    orange = true,
    purple = true,
    red = true,
}

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end

    return type(result) == "table" and tonumber(result.affectedRows) or 0
end

local function text_length(value)
    return type(value) == "string" and utf8.len(value) or nil
end

local function marker_dto(row)
    return {
        id = row.id,
        label = row.label,
        color = row.color,
        coords = {
            x = tonumber(row.position_x) or 0.0,
            y = tonumber(row.position_y) or 0.0,
            z = tonumber(row.position_z) or 0.0,
        },
    }
end

local function validate_marker(data)
    if type(data) ~= "table" or type(data.coords) ~= "table" then
        return nil
    end

    local label = type(data.label) == "string" and data.label:match("^%s*(.-)%s*$") or nil
    local label_length = text_length(label)
    local color = data.color
    local x = tonumber(data.coords.x)
    local y = tonumber(data.coords.y)
    local z = tonumber(data.coords.z)
    if not label_length
        or label_length < 1
        or label_length > Config.MapMarkers.LabelMaxLength
        or not marker_colors[color]
        or not x
        or not y
        or (data.coords.z ~= nil and not z)
        or x ~= x
        or y ~= y
        or (z and z ~= z)
        or math.abs(x) > 10000.0
        or math.abs(y) > 10000.0
        or (z and z < -1000.0)
        or (z and z > 3000.0)
    then
        return nil
    end

    return {
        label = label,
        color = color,
        x = x,
        y = y,
        z = z or 0.0,
    }
end

Bridge.Callbacks.Register("sky_phone:map:markers", function(source)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end

    local rows = Bridge.Database.Query([[
        SELECT `id`, `label`, `color`, `position_x`, `position_y`, `position_z`
        FROM `sky_phone_map_markers`
        WHERE `device_imei` = ?
        ORDER BY `created_at`, `id`
        LIMIT ?
    ]], { session.imei, Config.MapMarkers.MaximumMarkers })
    local markers = {}
    for index = 1, #rows do
        markers[index] = marker_dto(rows[index])
    end
    return { success = true, data = markers }
end)

Bridge.Callbacks.Register("sky_phone:map:create-marker", function(source, data)
    if not SkyPhone.AllowOperation(source, "map_marker_write", Config.MapMarkers.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end

    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end

    local marker = validate_marker(data)
    if not marker then
        return { success = false, error = "invalid_marker" }
    end

    local count_rows = Bridge.Database.Query([[
        SELECT COUNT(*) AS `count`
        FROM `sky_phone_map_markers`
        WHERE `device_imei` = ?
    ]], { session.imei })
    if (tonumber(count_rows[1] and count_rows[1].count) or 0) >= Config.MapMarkers.MaximumMarkers then
        return { success = false, error = "marker_limit" }
    end

    local ids = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    local id = ids[1] and ids[1].id
    if type(id) ~= "string" then
        error("[sky_phone] Database did not generate a map marker id.")
    end

    Bridge.Database.Query([[
        INSERT INTO `sky_phone_map_markers`
            (`id`, `device_imei`, `label`, `color`, `position_x`, `position_y`, `position_z`)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { id, session.imei, marker.label, marker.color, marker.x, marker.y, marker.z })
    return {
        success = true,
        data = {
            id = id,
            label = marker.label,
            color = marker.color,
            coords = { x = marker.x, y = marker.y, z = marker.z },
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:map:delete-marker", function(source, data)
    if not SkyPhone.AllowOperation(source, "map_marker_write", Config.MapMarkers.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end

    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end
    if type(data) ~= "table" or type(data.id) ~= "string" or #data.id ~= 36 then
        return { success = false, error = "invalid_marker" }
    end

    local result = Bridge.Database.Query(
        "DELETE FROM `sky_phone_map_markers` WHERE `id` = ? AND `device_imei` = ?",
        { data.id, session.imei }
    )
    if affected_rows(result) ~= 1 then
        return { success = false, error = "marker_not_found" }
    end
    return { success = true }
end)
end)
