local test = { now = 0, threads = {}, events = {}, handles = {}, commands = {}, mappings = {}, texts = {} }
local env = setmetatable({ Config = {} }, { __index = _G })
env.IsDuplicityVersion = function() return false end
env.vector3 = function(x, y, z) return { x = x, y = y, z = z } end
assert(loadfile("sky_phone/config/config.lua", "t", env))()
env.GetGameTimer = function() return test.now end
env.GetCurrentResourceName = function() return "sky_phone" end
env.RegisterNetEvent = function(name, fn) test.events[name] = fn end
env.AddEventHandler = env.RegisterNetEvent
env.RegisterNUICallback = env.RegisterNetEvent
env.RegisterCommand = function(name, fn) test.commands[name] = fn end
env.RegisterKeyMapping = function(command, label, mapper, key)
    test.mappings[#test.mappings + 1] = { command = command, label = label, mapper = mapper, key = key }
end
env.IsNuiFocused = function() return test.focused end
env.IsPauseMenuActive = function() return false end
env.PlayerId = function() return 0 end
env.GetPlayerServerId = function() return 1 end
env.SkyPhoneLocales = { Resolve = function() return { Nui = { Apps = { crewlink = {
    name = "CrewLink", quickPingKeybind = "CrewLink: Ping active crew", pingCreated = "Ping shared",
    errors = { request_failed = "Request failed", forbidden = "Forbidden" },
} } } } end }
env.CreateThread = function(fn)
    test.threads[#test.threads + 1] = { coroutine = coroutine.create(fn), wake = 0 }
end
env.Wait = function(ms) return coroutine.yield(ms) end
env.Bridge = {
    Debug = function() end,
    Framework = { Notify = function(_, message) test.notification = message end },
    Callbacks = { Trigger = function(name, data)
        assert(type(data) == "table")
        if name == "sky_phone:crewlink:quick-ping" then
            test.quick_requests = (test.quick_requests or 0) + 1
            assert(next(data) == nil, "the keybind must not supply a group or coordinates")
            return { success = true }
        end
        assert(name == "sky_phone:crewlink:world" or name == "sky_phone:crewlink:live")
        if test.block then return coroutine.yield("request") end
        if test.result and test.result.data then test.result.data.serverTime = 100000 + test.now end
        return test.result
    end },
}
local function coordinates(x, y, z)
    assert(math.type(x) == "float" and math.type(y) == "float" and math.type(z) == "float",
        "OAL coordinates must be individual floats")
    return { x = x, y = y, z = z }
end
env.AddBlipForCoord = function(x, y, z)
    local id = #test.handles + 1
    test.handles[id] = { exists = true, coords = coordinates(x, y, z) }
    return id
end
env.DoesBlipExist = function(handle) return test.handles[handle] and test.handles[handle].exists and 1 end
env.RemoveBlip = function(handle) test.handles[handle].exists = false end
env.SetBlipCoords = function(handle, x, y, z) test.handles[handle].coords = coordinates(x, y, z) end
env.AddTextEntry = function(key, value) test.texts[key] = value end
for _, field in ipairs({ "Sprite", "Category", "Display", "AsShortRange", "Scale", "Colour" }) do
    env["SetBlip" .. field] = function(handle, value) test.handles[handle][field] = value end
end
env.BeginTextCommandSetBlipName = function() test.name = "" end
env.AddTextComponentSubstringPlayerName = function(name, ...)
    assert(select("#", ...) == 0 and #name <= 99 and utf8.len(name), "native text arguments must be bounded, intact UTF-8")
    test.name = test.name .. name
end
env.EndTextCommandSetBlipName = function(handle) test.handles[handle].name = test.name end
assert(loadfile("sky_phone/source/client/crewlink.lua", "t", env))()

local function resume(thread, ...)
    local ok, delay = coroutine.resume(thread.coroutine, ...)
    assert(ok, delay)
    thread.wake = type(delay) == "number" and test.now + delay or math.huge
    if delay == "request" then test.pending = thread end
end
local function run()
    for _, thread in ipairs(test.threads) do
        if thread.wake <= test.now and coroutine.status(thread.coroutine) ~= "dead" then resume(thread) end
    end
end
local function advance(ms)
    for _ = 1, ms / 500 do test.now = test.now + 500; run() end
end
local function count()
    local n = 0
    for _, handle in ipairs(test.handles) do if handle.exists then n = n + 1 end end
    return n
end
local function snapshot()
    test.result = { success = true, data = {
        groupId = "crew-1", colour = "blue", overheadMembers = {},
        members = {
            { id = "self", username = "Self", source = 1, online = true, mapVisible = true, coords = { x = 0, y = 0, z = 0 } },
            { id = "peer", username = "Nova", source = 2, online = true, mapVisible = true, coords = { x = 10, y = 20, z = 30 } },
            { id = "hidden", username = "Hidden", source = 3, online = true, mapVisible = false, coords = { x = 10, y = 20, z = 30 } },
        },
        pings = {{ id = "ping-1", label = string.rep(utf8.char(0x1F680), 48), coords = { x = 40, y = 50, z = 60 }, expiresAt = 105000 }},
    } }
end

snapshot()
run()
assert(count() == 2, "only a visible peer and an active ping should have blips")
assert(test.handles[1].Sprite == 126 and test.handles[2].Sprite == 280)
assert(test.handles[2].name == test.result.data.pings[1].label)
assert(test.handles[1].Category == 13 and test.texts.BLIP_CAT_13 == "CrewLink")
assert(test.handles[1].Display == 2 and not test.handles[1].AsShortRange)
assert(test.mappings[1].key == "NUMPAD5" and test.mappings[1].mapper == "keyboard")
assert(not test.events["sky_phone:nuiClosed"], "closing the phone must not clear world state")
test.commands.sky_phone_crewlink_ping()
assert(test.quick_requests == 1 and test.notification == "Ping shared")
test.focused = true
test.commands.sky_phone_crewlink_ping()
assert(test.quick_requests == 1, "typing in the phone must not send pings")
test.focused = false
env.Config.CrewLink.QuickPing.Enabled = false
test.commands.sky_phone_crewlink_ping()
assert(test.quick_requests == 1)
env.Config.CrewLink.QuickPing.Enabled = true
env.Config.CrewLink.Blip.Sprite, env.Config.CrewLink.Blip.PingSprite = 7, 8
env.Config.CrewLink.Blip.CategoryId, env.Config.CrewLink.Blip.CategoryName = 21, "Road crew"
test.events["sky_phone:configurator:updated"]()
advance(500)
assert(count() == 2 and test.texts.BLIP_CAT_21 == "Road crew")
assert(test.handles[#test.handles - 1].Sprite == 7 and test.handles[#test.handles].Sprite == 8)
assert(#test.mappings == 1, "config changes must preserve player key bindings")
advance(4500)
assert(count() == 1, "expired pings must disappear without waiting for server refresh")
test.result.data.members[2].mapVisible = false
advance(3000)
assert(count() == 0, "revoking location sharing must remove the blip")
snapshot()
test.result.data.pings = {}
advance(3000)
assert(count() == 1)
test.block = true
advance(6500)
assert(test.pending and count() == 0, "stale locations must expire while a callback is blocked")
test.events["sky_phone:device:invalidated"]()
resume(test.pending, test.result)
assert(count() == 0, "a late snapshot must not restore invalidated locations")
test.block = false
advance(500)
assert(count() == 1)
test.result = { success = false, error = "not_authenticated" }
advance(3000)
assert(count() == 0, "loss of phone ownership or login must clear all blips")
snapshot()
env.source = 65535
test.events["sky_phone:crewlink:changed"]()
advance(500)
assert(count() == 1)
test.events.onResourceStop("sky_phone")
assert(count() == 0, "resource stop must remove owned blips")
print("CrewLink map, ping, key binding and cleanup tests passed")
