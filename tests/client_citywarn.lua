local function new_client()
    local test = { now = 0, threads = {}, events = {}, handles = {}, requests = 0, logs = {}, text_entries = {} }
    local env = setmetatable({}, { __index = _G })
    env.Config = {}
    env.IsDuplicityVersion = function() return false end
    env.vector3 = function(x, y, z) return { x = x, y = y, z = z } end
    assert(loadfile("sky_phone/config/config.lua", "t", env))()
    test.config = env.Config
    env.SkyPhoneLocales = { Resolve = function()
        return { Nui = { Apps = { citywarn = { name = "CityWarn" } } } }
    end }
    env.GetGameTimer = function() return test.now end
    env.GetCurrentResourceName = function() return "sky_phone" end
    env.RegisterNetEvent = function(name, callback) test.events[name] = callback end
    env.AddEventHandler = env.RegisterNetEvent
    env.CreateThread = function(callback)
        test.threads[#test.threads + 1] = { coroutine = coroutine.create(callback), wake = test.now }
    end
    env.Wait = function(ms) return coroutine.yield(ms) end
    env.Bridge = {
        Debug = function(_, _, error_code) test.logs[#test.logs + 1] = error_code end,
        Callbacks = { Trigger = function(name, data)
            assert(name == "sky_phone:citywarn:blips" and type(data) == "table")
            test.requests = test.requests + 1
            if test.block then return coroutine.yield("request") end
            return test.response
        end },
    }
    local function coordinates(x, y, z)
        assert(math.type(x) == "float" and math.type(y) == "float" and math.type(z) == "float",
            "OAL coordinates must be separate floats")
        return { x = x, y = y, z = z }
    end
    local function create(kind, x, y, z, radius)
        if test.fail == kind then return 0 end
        local handle = #test.handles + 1
        test.handles[handle] = { kind = kind, coords = coordinates(x, y, z), size = radius, exists = true }
        return handle
    end
    env.AddBlipForCoord = function(x, y, z) return create("point", x, y, z) end
    env.AddBlipForRadius = function(x, y, z, radius)
        assert(math.type(radius) == "float", "OAL radius must be a float")
        return create("radius", x, y, z, radius)
    end
    env.DoesBlipExist = function(handle)
        return test.handles[handle] and test.handles[handle].exists and 1 or nil
    end
    env.RemoveBlip = function(handle)
        assert(env.DoesBlipExist(handle), "only live, owned handles may be removed")
        test.handles[handle].exists = false
    end
    env.SetBlipCoords = function(handle, x, y, z) test.handles[handle].coords = coordinates(x, y, z) end
    env.AddTextEntry = function(key, value) test.text_entries[key] = value end
    for _, property in ipairs({ "Sprite", "Scale", "Display", "AsShortRange", "Alpha", "Colour", "Category", "HiddenOnLegend" }) do
        env["SetBlip" .. property] = function(handle, value)
            assert(env.DoesBlipExist(handle))
            test.handles[handle][property] = value
        end
    end
    local components
    env.BeginTextCommandSetBlipName = function(label)
        assert(label == "STRING")
        components = {}
    end
    env.AddTextComponentSubstringPlayerName = function(value)
        assert(#value <= 99 and utf8.len(value), "text components must contain bounded, intact UTF-8")
        components[#components + 1] = value
    end
    env.EndTextCommandSetBlipName = function(handle) test.handles[handle].name = table.concat(components) end

    function test.resume(thread, ...)
        local success, delay = coroutine.resume(thread.coroutine, ...)
        assert(success, delay)
        thread.wake = type(delay) == "number" and test.now + delay or math.huge
        if delay == "request" then test.pending = thread end
    end
    function test.run()
        for _, thread in ipairs(test.threads) do
            if thread.wake <= test.now and coroutine.status(thread.coroutine) ~= "dead" then
                test.resume(thread)
            end
        end
    end
    function test.advance(ms)
        local target = test.now + ms
        while test.now < target do
            test.now = math.min(target, test.now + 1000)
            test.run()
        end
    end
    function test.snapshot(alerts) test.response = { success = true, data = { alerts = alerts } } end
    function test.send(kind, id, origin)
        env.source = origin or 65535
        test.events["sky_phone:citywarn:changed"]({ kind = kind, alertId = id })
    end
    function test.count()
        local count = 0
        for _, handle in ipairs(test.handles) do if handle.exists then count = count + 1 end end
        return count
    end
    function test.configure(enabled, settings)
        env.Config.CityWarn.Enabled = enabled
        for key, value in pairs(settings or {}) do env.Config.CityWarn.Blip[key] = value end
        test.events["sky_phone:configurator:updated"]()
    end
    assert(loadfile("sky_phone/source/client/citywarn.lua", "t", env))()
    return test
end

local function alert(overrides)
    local value = { id = "alert-1", title = "Police operation", severity = "danger", x = 100, y = 200,
        radius = 500, remainingMs = 60000 }
    for key, item in pairs(overrides or {}) do value[key] = item end
    return value
end

local client = new_client()
client.snapshot({ alert() })
client.run()
assert(client.count() == 2 and client.requests == 1, "join/restart must restore blips without opening NUI")
assert(client.handles[1].Display == 2 and client.handles[1].AsShortRange == false)
assert(client.handles[1].Sprite == 10 and client.handles[1].Category == 12)
assert(client.text_entries.BLIP_CAT_12 == "CityWarn")
assert(client.handles[2].size == 100 and client.handles[2].HiddenOnLegend == true,
    "the fixed area must be sized in world metres and hidden from the legend")
assert(client.handles[1].Colour == 1 and client.handles[2].Alpha == 80)
assert(client.handles[1].name == "CityWarn: Police operation")
client.send("published", "alert-1")
client.send("published", "alert-1")
client.advance(1000)
assert(client.count() == 2 and #client.handles == 2, "duplicate events must not duplicate blips")

local long_title = string.rep("Ä", 120)
client.snapshot({ alert({ x = -50, y = 0, radius = 800, severity = "extreme", title = "~r~" .. long_title }) })
client.send("update", "alert-1")
client.advance(1000)
assert(client.count() == 2 and #client.handles == 2,
    "changing a warning's notification radius must preserve the configured map radius")
assert(client.handles[1].coords.x == -50 and client.handles[1].Colour == 27)
assert(client.handles[2].size == 100 and client.handles[2].Colour == 27)
assert(client.handles[1].name == "CityWarn: r" .. long_title, "names must strip GTA directives and preserve UTF-8")

local district = alert()
district.radius = nil
client.snapshot({ district })
client.send("update", "alert-1")
client.advance(1000)
assert(client.count() == 2 and client.handles[1].exists, "located districts must retain the configured radius")

client.configure(true, { Sprite = 375, Display = 3, ShortRange = true, CategoryId = 13,
    CategoryName = "Public warnings", Radius = 250 })
assert(client.handles[1].Sprite == 375 and client.handles[1].Display == 3
    and client.handles[1].AsShortRange == true and client.handles[1].Category == 13)
assert(client.text_entries.BLIP_CAT_13 == "Public warnings")
assert(not client.handles[2].exists and client.handles[3].size == 250
    and client.handles[3].Display == 3 and client.handles[3].AsShortRange == true
    and client.handles[3].HiddenOnLegend == true,
    "panel changes must immediately update existing markers and recreate resized areas")
client.configure(true, { RadiusEnabled = false, Display = 0, ShortRange = false })
assert(client.count() == 1 and client.handles[1].Display == 0 and client.handles[1].AsShortRange == false,
    "disabling the radius must preserve the point, including false and zero settings")
client.advance(1000)
assert(client.count() == 1, "snapshots must respect disabled radius settings")
client.send("resolved", "alert-1", 12)
assert(client.count() == 1, "local events must not control public blips")
client.snapshot({})
client.send("resolved", "alert-1")
assert(client.count() == 0, "resolution must remove handles immediately")
client.send("published", "alert-1")
client.advance(1000)
assert(client.count() == 0, "delayed publication must not resurrect a resolved alert")

client.snapshot({ alert() })
client.configure(true, { RadiusEnabled = true, Display = 2 })
client.advance(30000)
assert(client.count() == 2, "periodic snapshots must recover missed publications")
client.snapshot({})
client.advance(30000)
assert(client.count() == 0, "periodic snapshots must recover missed removals")

client = new_client()
client.snapshot({ alert({ remainingMs = 3000 }) })
client.run()
client.block = true
client.send("update", "alert-1")
client.advance(1000)
assert(client.pending)
client.advance(2000)
assert(client.count() == 0, "expiry must run while callbacks are blocked")
client.resume(client.pending, { success = true, data = { alerts = { alert({ remainingMs = 1000 }) } } })
assert(client.count() == 0, "network time must not extend expired warnings")

client = new_client()
client.block = true
client.run()
client.send("resolved", "alert-1")
client.resume(client.pending, { success = true, data = { alerts = { alert() } } })
assert(client.count() == 0, "a resolution during a request must invalidate its snapshot")
client.block = false
client.snapshot({})
client.advance(1000)
assert(client.requests == 2 and client.count() == 0)
client.response = nil
client.send("published", "alert-1")
client.advance(1000)
assert(client.logs[#client.logs] == "request_failed")
client.snapshot({ alert() })
client.advance(5000)
assert(client.count() == 2, "failed bootstrap/callbacks must retry")

client.configure(false)
assert(client.count() == 0, "disabling CityWarn must immediately remove its blips")
local requests = client.requests
client.advance(30000)
assert(client.requests == requests, "disabled CityWarn must not poll")
client.configure(true)
client.advance(1000)
assert(client.count() == 2, "re-enabling CityWarn must restore active warnings")
client.block = true
client.send("update", "alert-1")
client.advance(1000)
client.configure(false)
client.resume(client.pending, { success = true, data = { alerts = { alert() } } })
assert(client.count() == 0, "in-flight responses must not revive disabled blips")

client = new_client()
client.fail = "radius"
client.snapshot({ alert() })
client.run()
assert(client.count() == 0 and client.logs[1] == "blip_creation_failed", "partial creation must clean up and report failure")
client.fail = nil
client.advance(5000)
assert(client.count() == 2, "failed natives must be retried")
client.handles[#client.handles].exists = false
client.advance(30000)
assert(client.count() == 2, "missing native handles must be repaired")
client.events.onResourceStop("another_resource")
assert(client.count() == 2)
client.block = true
client.send("update", "alert-1")
client.advance(1000)
client.events.onResourceStop("sky_phone")
client.resume(client.pending, { success = true, data = { alerts = { alert() } } })
assert(client.count() == 0, "resource stop must remove owned blips and reject pending results")

client = new_client()
client.snapshot({ alert({ x = 0 / 0 }), alert({ x = math.huge }), alert({ y = 10001 }),
    alert({ radius = -1 }), alert({ severity = "invalid" }), alert({ remainingMs = 0 }) })
client.run()
assert(client.count() == 0, "invalid coordinates, radii and expirations must never reach natives")
assert(client.logs[1] == "invalid_snapshot", "invalid snapshots must remain visible in diagnostics")
client.now = 0x7fffffff - 1000
client.snapshot({ alert({ remainingMs = 3000 }) })
client.send("published", "alert-1")
client.run()
assert(client.count() == 2)
client.now = client.now - 0x100000000 + 3000
for _, thread in ipairs(client.threads) do thread.wake = client.now end
client.block = true
client.run()
assert(client.count() == 0, "expiry must survive signed GetGameTimer wraparound")

print("CityWarn client lifecycle tests passed")
