local blips = {}
local sync_requested = true
local change_version = 0
local stopped = false
local severity_colours = { information = 3, warning = 5, danger = 1, extreme = 27 }

local function elapsed(since)
    return (GetGameTimer() - since) & 0xffffffff
end

local function enabled()
    return Config.CityWarn and Config.CityWarn.Enabled
end

local function remove_handle(handle)
    if handle and DoesBlipExist(handle) then
        RemoveBlip(handle)
    end
end

local function remove_alert(id)
    local entry = blips[id]
    if entry then
        remove_handle(entry.point)
        remove_handle(entry.radius)
        blips[id] = nil
    end
end

local function clear_blips()
    for id in pairs(blips) do
        remove_alert(id)
    end
end

local function finite_number(value, minimum, maximum)
    return type(value) == "number" and value == value and value >= minimum and value <= maximum
end

local function valid_alert(alert)
    return type(alert) == "table" and type(alert.id) == "string" and #alert.id > 0 and #alert.id <= 64
        and type(alert.title) == "string" and severity_colours[alert.severity] ~= nil
        and finite_number(alert.x, -10000, 10000) and finite_number(alert.y, -10000, 10000)
        and finite_number(alert.remainingMs, 0, 604800000)
        and (alert.radius == nil or finite_number(alert.radius, 1, 50000))
end

local function set_name(handle, title)
    -- GTA interprets tildes as formatting. Keep each text component within 99 bytes,
    -- without cutting a UTF-8 character or losing long, localized warning titles.
    local label = title:gsub("~", "")
    BeginTextCommandSetBlipName("STRING")
    local first = 1
    while first <= #label do
        local last = math.min(first + 98, #label)
        while last < #label and label:byte(last + 1) >= 128 and label:byte(last + 1) < 192 do
            last = last - 1
        end
        AddTextComponentSubstringPlayerName(label:sub(first, last))
        first = last + 1
    end
    EndTextCommandSetBlipName(handle)
end

local function blip_settings()
    local settings = Config.CityWarn.Blip or {}
    local function integer(value, minimum, maximum, fallback)
        local number = math.tointeger(value)
        return number and number >= minimum and number <= maximum and number or fallback
    end
    local name = type(settings.CategoryName) == "string" and settings.CategoryName or "CityWarn"
    if #name > 99 or not name:find("%S") or name:find("[%c~]") then
        name = "CityWarn"
    end
    return {
        Sprite = integer(settings.Sprite, 0, 65535, 161),
        Display = integer(settings.Display, 0, 10, 2),
        ShortRange = settings.ShortRange ~= false,
        CategoryId = integer(settings.CategoryId, 12, 133, 12),
        CategoryName = name,
        GroupByCategory = settings.GroupByCategory == true,
        RadiusEnabled = settings.RadiusEnabled ~= false,
        Radius = finite_number(settings.Radius, 1, 50000) and settings.Radius or 100.0,
    }
end

local function apply_blip_settings(entry, settings)
    if settings.GroupByCategory then
        AddTextEntry("BLIP_CAT_" .. settings.CategoryId, settings.CategoryName)
    end
    if entry.point and DoesBlipExist(entry.point) then
        SetBlipSprite(entry.point, settings.Sprite)
        -- Custom categories replace individual names in the map legend.
        SetBlipCategory(entry.point, settings.GroupByCategory and settings.CategoryId or 2)
        SetBlipDisplay(entry.point, settings.Display)
        SetBlipAsShortRange(entry.point, settings.ShortRange)
    end
    if entry.radius and DoesBlipExist(entry.radius) then
        SetBlipDisplay(entry.radius, settings.Display)
        SetBlipAsShortRange(entry.radius, settings.ShortRange)
        SetBlipHiddenOnLegend(entry.radius, true)
    end
end

local function update_alert(alert, started_at)
    local entry = blips[alert.id] or {}
    blips[alert.id] = entry
    local settings = blip_settings()
    local radius = settings.RadiusEnabled and settings.Radius or nil

    if not entry.point or not DoesBlipExist(entry.point) then
        entry.point = AddBlipForCoord(alert.x + 0.0, alert.y + 0.0, 0.0)
        if not entry.point or not DoesBlipExist(entry.point) then
            remove_alert(alert.id)
            return false
        end
    end
    SetBlipCoords(entry.point, alert.x + 0.0, alert.y + 0.0, 0.0)

    if entry.radius_size ~= radius then
        remove_handle(entry.radius)
        entry.radius = nil
    end
    if radius then
        if not entry.radius or not DoesBlipExist(entry.radius) then
            entry.radius = AddBlipForRadius(alert.x + 0.0, alert.y + 0.0, 0.0, radius + 0.0)
            if not entry.radius or not DoesBlipExist(entry.radius) then
                remove_alert(alert.id)
                return false
            end
            SetBlipAlpha(entry.radius, 80)
        end
        SetBlipCoords(entry.radius, alert.x + 0.0, alert.y + 0.0, 0.0)
        SetBlipColour(entry.radius, severity_colours[alert.severity])
    end
    apply_blip_settings(entry, settings)
    SetBlipScale(entry.point, 0.9)
    SetBlipColour(entry.point, severity_colours[alert.severity])
    set_name(entry.point, alert.title)
    entry.alert = alert
    entry.radius_size = radius
    entry.started_at = started_at
    entry.remaining_ms = alert.remainingMs
    return true
end

local function apply_snapshot(alerts, started_at)
    local seen = {}
    local error_code
    for _, alert in ipairs(alerts) do
        if not valid_alert(alert) then
            error_code = "invalid_snapshot"
        elseif elapsed(started_at) < alert.remainingMs then
            seen[alert.id] = true
            if not update_alert(alert, started_at) then
                error_code = "blip_creation_failed"
            end
        end
    end
    for id in pairs(blips) do
        if not seen[id] then
            remove_alert(id)
        end
    end
    return error_code
end

local function request_sync()
    change_version = change_version + 1
    sync_requested = true
end

RegisterNetEvent("sky_phone:citywarn:changed", function(data)
    if source ~= 65535 or type(data) ~= "table" then
        return
    end
    -- Fetch authoritative state instead of allowing an older event to recreate
    -- a resolved alert. Existing NUI notifications keep their own event handler.
    request_sync()
    if data.kind == "resolved" and type(data.alertId) == "string" then
        remove_alert(data.alertId)
    end
end)

AddEventHandler("sky_phone:configurator:updated", function()
    request_sync()
    if not enabled() then
        clear_blips()
    else
        for _, entry in pairs(blips) do
            update_alert(entry.alert, entry.started_at)
        end
    end
end)

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name == GetCurrentResourceName() then
        stopped = true
        clear_blips()
    end
end)

CreateThread(function()
    local last_attempt = GetGameTimer()
    local retry_after = 0
    local last_error
    while not stopped do
        if enabled() and (sync_requested or elapsed(last_attempt) >= retry_after) then
            sync_requested = false
            local version = change_version
            local started_at = GetGameTimer()
            local response = Bridge.Callbacks.Trigger("sky_phone:citywarn:blips", {})
            last_attempt = GetGameTimer()
            retry_after = 5000
            if not stopped and enabled() and version == change_version then
                local error_code
                if response and response.success and type(response.data) == "table"
                    and type(response.data.alerts) == "table"
                then
                    error_code = apply_snapshot(response.data.alerts, started_at)
                    if not error_code then
                        retry_after = 30000
                    end
                else
                    error_code = response and response.error or "request_failed"
                end
                if error_code and error_code ~= last_error then
                    Bridge.Debug("warn", "[sky_phone] CityWarn blip sync failed: %s.", tostring(error_code))
                end
                last_error = error_code
            end
        end
        Wait(1000)
    end
end)

-- Expiry must continue even while a server callback is waiting or timing out.
CreateThread(function()
    while not stopped do
        for id, entry in pairs(blips) do
            if not enabled() or elapsed(entry.started_at) >= entry.remaining_ms then
                remove_alert(id)
            end
        end
        Wait(1000)
    end
end)
