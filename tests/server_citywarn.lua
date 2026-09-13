local callbacks, events, rows = {}, {}, {}
local now, uuid_count, snapshot_queries = 0, 0, 0
local allow_operation, allow_session, during_query = true, true, nil
local broadcast

Config = { CityWarn = {
    Enabled = true, RequireDuty = true, PageSize = 1, MaximumActiveAlerts = 20,
    TitleMaxLength = 120, BodyMaxLength = 2000, InstructionsMaxLength = 2000, UpdateMaxLength = 2000,
    AreaLabelMaxLength = 120, MinimumRadius = 100, MaximumRadius = 10000,
    DefaultDurationMinutes = 60, MaximumDurationMinutes = 1440,
    RateLimits = { Read = 180, Write = 20 },
    Publishers = { police = { MinimumGrade = 2, MaximumSeverity = "extreme", CityWide = true,
        Categories = { "public_safety", "police", "fire", "medical", "infrastructure", "evacuation" } } },
} }

local function database(sql, parameters)
    if sql:find("TIMESTAMPDIFF", 1, true) then
        snapshot_queries = snapshot_queries + 1
        assert(not sql:find("LIMIT", 1, true), "blips must not be truncated to the app page size")
        assert(sql:find("`status` = 'active'", 1, true) and sql:find("`expires_at` > NOW()", 1, true))
        assert(not sql:find("`area_type` IN", 1, true), "located city-wide warnings also need blips")
        assert(sql:find("`category`", 1, true), "snapshots must include category colors for all warnings")
        assert(sql:find("`center_x` IS NOT NULL AND `center_y` IS NOT NULL", 1, true))
        local result = {}
        for _, row in pairs(rows) do
            if row.status == "active" and row.expires_at_unix > now / 1000
                and row.center_x and row.center_y
            then
                local copy = {}
                for key, value in pairs(row) do copy[key] = value end
                copy.remaining_seconds = row.expires_at_unix - math.floor(now / 1000)
                result[#result + 1] = copy
            end
        end
        if during_query then
            local action = during_query
            during_query = nil
            action()
        end
        return result
    elseif sql:find("SELECT COUNT(*)", 1, true) then
        return { { count = 0 } }
    elseif sql:find("SELECT UUID()", 1, true) then
        uuid_count = uuid_count + 1
        return { { id = ("00000000-0000-0000-0000-%012d"):format(uuid_count) } }
    elseif sql:find("INSERT INTO `sky_phone_citywarn_alerts`", 1, true) then
        rows[parameters[1]] = {
            id = parameters[1], title = parameters[2], body = parameters[3], instructions = parameters[4],
            category = parameters[5], severity = parameters[6], area_type = parameters[7], area_label = parameters[8],
            center_x = parameters[9], center_y = parameters[10], radius = parameters[11],
            source_label = parameters[13], author_name = parameters[15], status = "active", revision = 1,
            starts_at_unix = 0, expires_at_unix = now / 1000 + parameters[16] * 60,
            created_at_unix = 0, updated_at_unix = 0,
        }
        return 1
    elseif sql:find("INSERT INTO `sky_phone_citywarn_updates`", 1, true) then
        return 1
    elseif sql:find("UPDATE `sky_phone_citywarn_alerts`", 1, true) then
        local row = rows[parameters[1]]
        assert(row and row.revision == parameters[2])
        row.revision = row.revision + 1
        if sql:find("'resolved'", 1, true) then row.status = "resolved" end
        return 1
    elseif sql:find("FROM `sky_phone_citywarn_updates`", 1, true) then
        return {}
    elseif sql:find("WHERE alert.`id` = ?", 1, true) then
        return { rows[parameters[1]] }
    end
    error("Unexpected query: " .. sql)
end

Bridge = {
    Database = { AfterMigration = function(_, callback) callback() end, Query = database },
    Callbacks = {
        RegisterDeferred = function(name) assert(name == "sky_phone:citywarn:blips") end,
        Register = function(name, callback) callbacks[name] = callback end,
    },
    Framework = {
        GetJob = function() return { name = "police", label = "Police", grade = 3, onDuty = true } end,
        GetIdentifier = function() return "test-author" end,
        GetFirstname = function() return "Test" end,
        GetLastname = function() return "Author" end,
        GetPlayers = function() return { 1, 2 } end,
    },
}
SkyPhone = {
    AllowOperation = function(_, operation, maximum, window)
        if operation == "citywarn_blips" then assert(maximum == 60 and window == 60) end
        return allow_operation
    end,
    RequireSession = function()
        if allow_session then return {} end
        return nil, { success = false, error = "device_not_open" }
    end,
}
function GetGameTimer() return now end
function GetPlayerPed() return 42 end
function GetEntityCoords(ped) assert(ped == 42) return { x = 321, y = -456, z = 10 } end
function AddEventHandler(name, callback) events[name] = callback end
function TriggerClientEvent(name, target, data)
    assert(name == "sky_phone:citywarn:changed" and target == -1)
    broadcast = data
end

dofile("sky_phone/source/server/citywarn.lua")
local function snapshot() return callbacks["sky_phone:citywarn:blips"](1) end
local function publish(area, category)
    local result = callbacks["sky_phone:citywarn:publish"](1, {
        title = "Test warning", body = "Avoid the area", instructions = "", durationMinutes = 1,
        category = category or "police", severity = "danger",
        area = area or { type = "radius", label = "Test area", centerX = 100, centerY = 200, radius = 500 },
    })
    assert(result.success)
    return result.data.alert
end

allow_session = false
assert(snapshot().success, "public blips must work without an open phone")
local denied = callbacks["sky_phone:citywarn:publish"](1, {})
assert(not denied.success and denied.error == "device_not_open", "publishing must still require a phone session")
allow_session = true
local first = publish()
assert(broadcast.kind == "published" and broadcast.alertId == first.id)
local state = snapshot().data.alerts
assert(#state == 1 and state[1].radius == 500 and state[1].remainingMs == 60000,
    "publishing must invalidate the previously empty cache")
assert(state[1].body == nil and state[1].author_name == nil and state[1].updates == nil,
    "the public snapshot must only expose fields needed for blips")
local queries = snapshot_queries
now = 2000
state = snapshot().data.alerts
assert(snapshot_queries == queries and state[1].remainingMs == 58000, "cache hits must age expiry without querying again")
state[1].title = "Mutated response"
assert(snapshot().data.alerts[1].title == "Test warning", "responses must not mutate the shared cache")

local updated = callbacks["sky_phone:citywarn:update"](1, { id = first.id, revision = 1, message = "Update" })
assert(updated.success and broadcast.kind == "update")
snapshot()
assert(snapshot_queries == queries + 1, "updates must invalidate the cache")
local resolved = callbacks["sky_phone:citywarn:resolve"](1, { id = first.id, revision = 2, message = "All clear" })
assert(resolved.success and broadcast.kind == "resolved")
assert(#snapshot().data.alerts == 0, "resolved warnings must disappear from authoritative snapshots")

publish()
publish({ type = "district", label = "District", centerX = 0, centerY = 0 })
publish({ type = "district", label = "Unlocated district" })
publish({ type = "city", label = "Whole city" })
state = snapshot().data.alerts
assert(#state == 4, "all located alerts, including zero coordinates, must be returned beyond PageSize")
local points, radii = 0, 0
for _, item in ipairs(state) do
    if item.radius then radii = radii + 1 else points = points + 1 end
end
assert(points == 3 and radii == 1, "districts must not receive a fabricated radius")

allow_operation = false
assert(snapshot().error == "rate_limited")
allow_operation = true
Config.CityWarn.Enabled = false
events["sky_phone:configurator:serverUpdated"]()
assert(#snapshot().data.alerts == 0, "disabling CityWarn must return an empty authoritative snapshot")
Config.CityWarn.Enabled = true
events["sky_phone:configurator:serverUpdated"]()
assert(#snapshot().data.alerts == 4)
now = now + 61000
assert(#snapshot().data.alerts == 0, "expiry must work without opening bootstrap or mutating DB status")

publish()
during_query = function() events["sky_phone:configurator:serverUpdated"]() end
assert(snapshot().error == "revision_conflict", "an invalidated in-flight query must not populate the cache")
assert(#snapshot().data.alerts == 1, "the next snapshot must recover after a racing change")

for _, category in ipairs(Config.CityWarn.Publishers.police.Categories) do
    for _, area_type in ipairs({ "radius", "district", "city" }) do
        local created = publish({ type = area_type, label = category, centerX = 0, centerY = 0, radius = 500 }, category)
        local found
        for _, item in ipairs(snapshot().data.alerts) do
            if item.id == created.id then found = item end
        end
        assert(found and found.category == category and found.x == 0 and found.y == 0,
            "every category and located area type must appear in the snapshot")
    end
end
local anchored = publish({ type = "city", label = "City" }, "evacuation")
assert(anchored.area.centerX == 321 and anchored.area.centerY == -456,
    "old clients must get a server-provided incident location for new city warnings")
print("CityWarn server lifecycle tests passed")
