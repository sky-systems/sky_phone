local test = {
    now = 0, threads = {}, events = {}, nui = {}, messages = {}, requests = {},
    loaded = {}, entities = {}, focused = false, released = false,
    searches = 0, help = 0, coords = nil, voice = false,
}
local vector_meta = {}
local function vector(x, y, z) return setmetatable({ x = x, y = y, z = z }, vector_meta) end
vector_meta.__sub = function(a, b) return vector(a.x - b.x, a.y - b.y, a.z - b.z) end
vector_meta.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
test.coords = vector(0.0, 0.0, 0.0)

local noop = function() end
local hashes = { booth_a = 1, booth_b = 2, booth_c = 3, booth_d = 4, replacement = 5 }
local env = setmetatable({}, { __index = _G })
env.Config = {
    Bridge = { Locale = "en" }, Sim = { NumberLength = 10 },
    Payphones = {
        Enabled = true, Props = { "booth_a", "booth_b", "booth_c", "booth_d" },
        CustomLocations = {}, CustomProp = "booth_a", ReplacementProp = "replacement",
        ScanIntervalMs = 1000, ScanDistance = 25.0, InteractionDistance = 1.8,
        MaximumCallDistance = 4.0, ModelLoadTimeoutMs = 5000, Currency = "$", PricePerSecond = 1,
        Animation = { Dictionary = "payphone", PedClip = "ped", PropClip = "prop", HangupDurationMs = 250 },
    },
}
env.SkyPhoneLocales = { Resolve = function() return {
    Nui = { Payphone = {} },
    Payphone = { Interact = "Use payphone", RingingHelp = "Calling {number}",
        ConnectedHelp = "{number}: {duration} {currency}{cost}" },
} end }
env.Bridge = {
    Debug = function(_, message) error(message) end,
    Framework = { ShowHelpNotification = function(message, key)
        assert(type(message) == "string" and key == "E")
        test.help = test.help + 1
    end },
    Calls = { Join = function() test.voice = true; return true end, Leave = function() test.voice = false end },
    Callbacks = { Trigger = function(name, payload)
        test.requests[#test.requests + 1] = { name = name, payload = payload }
        if name == "sky_phone:payphone:dial" then
            return { success = true, data = { id = "local-call", state = "ringing", otherNumber = payload.phoneNumber } }
        end
        return { success = true }
    end },
}
env.joaat = function(model) return assert(hashes[model], model) end
env.vector3 = vector
env.CreateThread = function(callback)
    test.threads[#test.threads + 1] = { coroutine = coroutine.create(callback), wake = test.now }
end
env.Wait = function(delay) return coroutine.yield(delay) end
env.GetGameTimer = function() return test.now end
env.RegisterNetEvent = function(name, callback) test.events[name] = callback end
env.AddEventHandler = env.RegisterNetEvent
env.RegisterNUICallback = function(name, callback) test.nui[name] = callback end
env.TriggerEvent = function(name, focused)
    if name == "sky_phone:client:setPayphoneFocus" then test.focused = focused end
end
env.SendNUIMessage = function(message) test.messages[#test.messages + 1] = message end
env.GetCurrentResourceName = function() return "sky_phone" end
env.PlayerPedId = function() return 7 end
env.PlayerId = function() return 8 end
env.GetPlayerServerId = function() return 9 end
env.IsNuiFocused = function() return test.focused end
env.HasModelLoaded = function(model) return test.loaded[model] and 1 end
env.DoesEntityExist = function(entity) return (entity == 7 or test.entities[entity]) and 1 end
env.GetEntityCoords = function(entity)
    return entity == 7 and test.coords or assert(test.entities[entity]).coords
end
env.GetClosestObjectOfType = function(x, y, z, radius, model, mission, p6, p7)
    assert(type(x) == "number" and type(y) == "number" and type(z) == "number", "OAL requires scalar coordinates")
    assert(not mission and not p6 and not p7, "world scans must preserve mission-object support")
    test.searches = test.searches + 1
    local nearest, distance = 0, radius
    for entity, data in pairs(test.entities) do
        local candidate_distance = #(data.coords - vector(x, y, z))
        if data.model == model and candidate_distance <= distance then
            nearest, distance = entity, candidate_distance
        end
    end
    return nearest
end
env.IsControlJustReleased = function(group, control)
    assert(group == 0 and control == 38)
    local released = test.released
    test.released = false
    return released
end
env.SetEntityVisible = function(entity, visible) assert(test.entities[entity]).visible = visible end
env.RequestModel = function(model) test.loaded[model] = true end
env.SetModelAsNoLongerNeeded = noop
env.HasAnimDictLoaded = function() return 1 end
env.RemoveAnimDict = noop
env.GetEntityRotation = function() return vector(0.0, 0.0, 0.0) end
env.CreateObjectNoOffset = function(model, x, y, z)
    test.entities[99] = { model = model, coords = vector(x, y, z), visible = true }
    return 99
end
env.DeleteEntity = function(entity) test.entities[entity] = nil end
env.SetEntityAsMissionEntity = noop
env.SetEntityRotation = noop
env.SetEntityHeading = noop
env.FreezeEntityPosition = noop
env.SetEntityCollision = noop
env.NetworkGetNetworkIdFromEntity = function() return 10 end
env.SetNetworkIdCanMigrate = noop
env.NetworkCreateSynchronisedScene = function() return 20 end
env.NetworkGetLocalSceneFromNetworkId = function() return 21 end
env.NetworkAddPedToSynchronisedScene = noop
env.NetworkAddEntityToSynchronisedScene = noop
env.NetworkStartSynchronisedScene = noop
env.NetworkStopSynchronisedScene = noop
env.GetGroundZFor_3dCoord = function() return 1, 0.0 end
env.GetSynchronizedScenePhase = function() return 0.8 end
env.SetSynchronizedSceneRate = noop
env.SetSynchronizedScenePhase = noop
env.StopAnimTask = noop
env.ClearPedTasksImmediately = noop
env.StopEntityAnim = noop

assert(loadfile("sky_phone/source/client/payphones.lua", "t", env))()
local function frame(ms)
    test.now = test.now + (ms or 16)
    for _, thread in ipairs(test.threads) do
        if thread.wake <= test.now and coroutine.status(thread.coroutine) ~= "dead" then
            local ok, delay = coroutine.resume(thread.coroutine)
            assert(ok, delay)
            thread.wake = test.now + math.max(16, delay or 0)
        end
    end
end
local function active_threads()
    local count = 0
    for _, thread in ipairs(test.threads) do
        if coroutine.status(thread.coroutine) ~= "dead" then count = count + 1 end
    end
    return count
end
local function nui(name, data)
    local response
    test.nui[name](data, function(value) response = value end)
    assert(response, "every NUI request must receive a response")
    return response
end
local function configure(enabled)
    env.Config.Payphones.Enabled = enabled
    test.events["sky_phone:configurator:updated"]()
end

frame(0)
for _ = 1, 10 do frame(1000) end
assert(test.searches == 0, "unloaded payphone models must not trigger world-object searches")
assert(active_threads() == 1 and test.help == 0, "idle only needs the configured discovery sampler")
configure(false)
frame(1000)
assert(active_threads() == 0, "disabled payphones must stop every idle worker")
configure(true)
configure(true)
frame(0)
assert(active_threads() == 1, "repeated configuration updates must not duplicate discovery workers")

test.loaded[1], test.loaded[2] = true, true
test.entities[11] = { model = 1, coords = vector(1.5, 0.0, 0.0), visible = true }
test.entities[12] = { model = 2, coords = vector(1.0, 0.0, 0.0), visible = true }
test.focused = true
frame(1000)
assert(test.searches == 0, "focused NUI cannot use a booth and must not perform discovery searches")
test.focused = false
frame(1000)
assert(test.searches == 2 and test.help > 0, "newly streamed models must be found on the next configured scan")
assert(active_threads() == 2, "a nearby booth must have exactly one prompt worker")
test.coords = vector(10.0, 0.0, 0.0)
frame(1000)
assert(active_threads() == 1, "leaving interaction range must terminate the prompt worker")
test.coords = vector(0.0, 0.0, 0.0)
frame(1000)
test.released = true
frame()
assert(test.focused and test.messages[#test.messages].type == "payphone:open", "E must open the nearest booth")
frame()
assert(active_threads() == 1, "opening the dial pad must terminate the prompt worker")
assert(nui("payphone:dial", { phoneNumber = "5551234" }).success)
assert(test.requests[1].payload.model == "booth_b" and test.requests[1].payload.coords.x == 1.0,
    "discovery must preserve nearest-booth selection and the server-authoritative dial request")
frame()
assert(active_threads() == 2 and not test.focused, "a call must start its worker immediately without retaining NUI focus")
assert(not test.entities[12].visible and test.entities[99], "call visuals must still replace the original booth")
test.events["sky_phone:payphone:state"]({ id = "local-call", state = "connected", channel = 123, elapsedSeconds = 5 })
frame()
assert(test.voice and active_threads() == 2, "call state updates must join voice without duplicating the worker")
test.coords = vector(10.0, 0.0, 0.0)
frame()
assert(#test.requests == 2 and test.requests[2].name == "sky_phone:payphone:hangup",
    "leaving the booth must still request a server-authorized hangup")
test.released = true
frame()
assert(#test.requests == 2, "pending hangup must not generate duplicate requests")
test.events["sky_phone:payphone:state"]({ id = "local-call", state = "ended" })
for _ = 1, 20 do frame() end
assert(not test.voice and not test.entities[99] and test.entities[12].visible,
    "hangup must complete its animation, leave voice and restore the original booth")
assert(active_threads() == 1, "ending the call must remove both call and animation workers")

configure(false)
frame(1000)
assert(active_threads() == 0)
test.coords = vector(0.0, 0.0, 0.0)
local remote = { id = "remote-call", callerSource = 10, model = "booth_a", coords = { x = 1.5, y = 0.0, z = 0.0 } }
test.events["sky_phone:payphone:visual:start"](remote)
test.events["sky_phone:payphone:visual:start"](remote)
frame()
assert(active_threads() == 1 and not test.entities[11].visible, "remote visuals must share one worker")
test.events["sky_phone:payphone:visual:stop"]({ id = remote.id })
frame(250)
assert(active_threads() == 0 and test.entities[11].visible, "the last remote stop must restore the booth and stop polling")
test.events["sky_phone:payphone:visual:start"](remote)
frame()
test.events.onResourceStop("sky_phone")
frame(250)
assert(active_threads() == 0 and test.entities[11].visible, "resource cleanup must restore remote visuals")

print("Client payphone discovery, interaction, call and cleanup tests passed")
