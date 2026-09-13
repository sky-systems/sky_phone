-- Run from the repository root with Lua 5.4.
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local callbacks = {}
local now, bucket, player_ped = 100, 0, 2
local carried, logged_in, phone_open, app_enabled = true, true, true, true
local inserted_ping
local ping_count, account_offset = 0, 0
local allow_operation = true
local ping_timer = 0
local pause_ping_query, fail_ping_query = false, false
local profile = { id = "profile-1", account_id = 1, username = "Skyline" }
local group = {
    id = "group-1", group_id = "group-1", name = "Road Crew", colour = "blue",
    role = "member", owner_profile_id = "profile-2", member_count = 2,
}
local peer = { id = "profile-2", account_id = 2, username = "Nova", role = "owner", active_group_id = "group-1" }
local env = setmetatable({
    IsDuplicityVersion = function() return true end,
    vector3 = function(x, y, z) return { x = x, y = y, z = z } end,
    vector4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end,
    AddEventHandler = function() end,
    TriggerEvent = function() end,
    exports = function() end,
    os = { time = function() return now end },
    GetGameTimer = function() return ping_timer end,
    GetPlayerRoutingBucket = function(source) return source == 2 and bucket or 0 end,
    GetPlayerPed = function() return player_ped end,
    GetEntityCoords = function() return { x = 10, y = 20, z = 30 } end,
}, { __index = _G })
assert(loadfile("sky_phone/source/shared/config_default.lua", "t", env))()
env.Config = env.ConfigDefaults
env.SkyPhone = {
    AllowOperation = function() return allow_operation end,
    RequireSession = function()
        if phone_open then return { imei = "device-1" } end
        return nil, { success = false, error = "device_not_open" }
    end,
    IsAppEnabled = function() return app_enabled end,
    RequireAccount = function(source) return { id = source } end,
    NotifyAccount = function() end,
}
env.SkyPhoneDeviceDirectory = { GetOnlineBySource = function(source)
    if carried then return { imei = "device-" .. source, accountId = source + account_offset } end
end }
env.SkyPhoneLocales = { Resolve = function()
    return { Nui = { Apps = { crewlink = { quickPingLabel = "Meet here" } } } }
end }
env.Bridge = {
    Debug = function() end,
    Callbacks = {
        RegisterDeferred = function() end,
        Register = function(name, callback) callbacks[name] = callback end,
    },
    Framework = { GetPlayers = function() return { 1, 2 } end },
    Database = {
        AfterMigration = function(_, callback) callback() end,
        Query = function(query, params)
            if query:find("SELECT UUID()", 1, true) then return {{ id = "ping-1" }} end
            if query:find("SELECT COUNT(*) AS `count` FROM `sky_phone_crewlink_pings`", 1, true) then
                if pause_ping_query then coroutine.yield("ping_query") end
                if fail_ping_query then
                    fail_ping_query = false
                    error("Test database failure")
                end
                return {{ count = ping_count }}
            end
            if query:find("INSERT INTO `sky_phone_crewlink_pings`", 1, true) then
                inserted_ping = copy(params)
                return { affectedRows = 1 }
            end
            if query:find("UPDATE IGNORE `sky_phone_crewlink_profiles`", 1, true) then
                assert(params[5] == profile.id, "profile updates must target the signed-in profile")
                profile.username = params[1]
                -- oxmysql casts TINYINT(1) query results to Lua booleans.
                profile.map_visible = params[2] == 1
                profile.overhead_visible = params[3] == 1
                return { affectedRows = 1 }
            end
            if query:find("FROM `sky_phone_crewlink_sessions`", 1, true) then
                return logged_in and { copy(params[1] == "device-2" and peer or profile) } or {}
            end
            if query:find("FROM `sky_phone_crewlink_invitations`", 1, true)
                or query:find("FROM `sky_phone_crewlink_pings`", 1, true) then return {} end
            if query:find("SELECT p.`account_id`", 1, true) then return {} end
            if query:find("UNIX_TIMESTAMP(m.`joined_at`)", 1, true) then return { copy(peer) } end
            if query:find("FROM `sky_phone_crewlink_memberships`", 1, true) then
                return profile.active_group_id and { copy(group) } or {}
            end
            error("Unexpected query: " .. query)
        end,
    },
}
assert(loadfile("sky_phone/source/server/crewlink.lua", "t", env))()

local function call(action, data)
    return assert(callbacks["sky_phone:crewlink:" .. action])(1, data or {})
end

for _, enabled in ipairs({ true, false }) do
    local result = call("update-profile", { username = "Skyline", mapVisible = enabled, overheadVisible = enabled })
    assert(result.success)
    assert(result.data.profile.mapVisible == enabled, "map visibility must survive the save response")
    assert(result.data.profile.overheadVisible == enabled, "overhead visibility must survive the save response")
    local reloaded = call("bootstrap").data.profile
    assert(reloaded.mapVisible == enabled and reloaded.overheadVisible == enabled,
        "visibility must survive reopening CrewLink")
end

profile.active_group_id = group.id
for _, value in ipairs({ true, 1, "1", false, 0, "0" }) do
    local enabled = value == true or tonumber(value) == 1
    profile.map_visible, profile.overhead_visible = value, value
    peer.map_visible, peer.overhead_visible = value, value
    group.allow_member_pings, group.overhead_allowed = value, value
    local data = call("bootstrap").data
    assert(data.profile.mapVisible == enabled and data.profile.overheadVisible == enabled)
    assert(data.activeGroup.allowMemberPings == enabled and data.activeGroup.overheadAllowed == enabled)
    assert(data.activeGroup.members[1].mapVisible == enabled)
    assert(data.activeGroup.members[1].overheadVisible == enabled)
    local live = call("live").data
    assert((live.members[1].coords ~= nil) == enabled, "locations must respect the saved opt-in")
    assert((#live.overheadMembers == 1) == enabled, "overhead labels must respect all database flag formats")
end

profile.overhead_visible, peer.overhead_visible, group.overhead_allowed = true, true, false
assert(#call("live").data.overheadMembers == 0, "the crew can disable overhead labels")
group.overhead_allowed, peer.overhead_visible = true, false
assert(#call("live").data.overheadMembers == 0, "members must opt in to overhead labels")
peer.overhead_visible, profile.overhead_visible = true, false
assert(#call("live").data.overheadMembers == 0, "the viewer must opt in to overhead labels")
phone_open = false
profile.map_visible, peer.map_visible = true, true
now = now + 2
assert(call("world").data.members[1].coords, "world locations must work while both phones are closed")
bucket, now = 1, now + 2
assert(not call("world").data.members[1].coords, "different routing buckets must not share locations")
bucket, peer.active_group_id, now = 0, "other-group", now + 2
assert(not call("world").data.members[1].coords, "members of another active crew must not share locations")
peer.active_group_id, player_ped, now = "group-1", 0, now + 2
assert(not call("world").data.members[1].coords, "missing peds must not expose origin coordinates")
player_ped = 2

group.allow_member_pings = true
local ping = call("quick-ping", { groupId = "forged", coords = { x = 999, y = 999, z = 999 } })
assert(ping.success and ping.data.coords.x == 10, "quick pings must use server coordinates with the phone closed")
assert(inserted_ping[2] == profile.active_group_id and inserted_ping[3] == profile.id,
    "quick pings must target the authenticated active crew and creator")
assert(call("quick-ping").error == "ping_cooldown", "the keybind must not send another ping immediately")
env.Config.CrewLink.PingCooldownSeconds = nil
assert(call("quick-ping").error == "ping_cooldown", "existing config files must use the shipped default")
env.Config.CrewLink.PingCooldownSeconds = 5
profile.id = "another-profile"
assert(call("quick-ping").success, "another crew member must have an independent cooldown")
profile.id = "profile-1"
phone_open = true
assert(call("create-ping", { type = "meeting", label = "Test", useCurrent = true }).error == "ping_cooldown",
    "app and keybind pings must share a cooldown")
profile.active_group_id = "other-group"
assert(call("quick-ping").error == "ping_cooldown", "switching crews must not bypass the profile cooldown")
profile.active_group_id = group.id
ping_timer = 4999
assert(call("quick-ping").error == "ping_cooldown", "the full configured interval must elapse")
ping_timer = 5000
assert(call("create-ping", { type = "meeting", label = "Test", useCurrent = true }).success)
assert(call("quick-ping").error == "ping_cooldown", "an app ping must also delay the keybind")
phone_open = false
env.Config.CrewLink.PingCooldownSeconds = 10
ping_timer = 10000
assert(call("quick-ping").error == "ping_cooldown", "longer runtime cooldowns must apply immediately")
env.Config.CrewLink.PingCooldownSeconds = 2
assert(call("quick-ping").success, "shorter runtime cooldowns must apply immediately")
env.Config.CrewLink.PingCooldownSeconds = 0
assert(call("quick-ping").success and call("quick-ping").success, "zero must disable the timed cooldown")
env.Config.CrewLink.PingCooldownSeconds = 5
ping_timer = 15000
pause_ping_query = true
local concurrent_result
local request = coroutine.create(function() concurrent_result = call("quick-ping") end)
local ok, marker = coroutine.resume(request)
assert(ok and marker == "ping_query")
assert(call("quick-ping").error == "ping_cooldown", "a database yield must not allow concurrent pings")
pause_ping_query = false
assert(coroutine.resume(request))
assert(concurrent_result.success)
ping_timer = 20000
fail_ping_query = true
local succeeded, failure = pcall(call, "quick-ping")
assert(not succeeded and tostring(failure):find("Test database failure", 1, true))
assert(call("quick-ping").success, "database failures must release the in-flight reservation")
ping_timer = 25000
ping_count = env.Config.CrewLink.MaximumActivePings
assert(call("quick-ping").error == "ping_limit", "quick pings must respect the shared active-ping limit")
ping_count = 0
assert(call("quick-ping").success, "rejected pings must not start the cooldown")
ping_count, allow_operation = 0, false
assert(call("quick-ping").error == "rate_limited", "quick pings must respect the shared rate limit")
allow_operation = true
group.allow_member_pings = false
assert(call("quick-ping").error == "forbidden", "quick pings must enforce crew role permissions")
env.Config.CrewLink.QuickPing.Enabled = false
assert(call("quick-ping").error == "quick_ping_disabled")
env.Config.CrewLink.QuickPing.Enabled = true
carried = false
assert(not call("world").success and not call("quick-ping").success, "a dropped phone must revoke background access")
carried, logged_in = true, false
assert(not call("world").success and not call("quick-ping").success, "logging out must revoke background access")
logged_in, app_enabled = true, false
assert(call("world").error == "disabled")
app_enabled, account_offset = true, 1
assert(not call("world").success and not call("quick-ping").success,
    "a phone signed into another cloud account must not retain the previous CrewLink session")
print("CrewLink persistence and visibility tests passed")
