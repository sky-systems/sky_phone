local function fixture(options)
    options = options or {}
    local s = {
        now = 0, callbacks = {}, events = {}, state_handlers = {}, threads = {},
        entities = { [1] = true }, bags = {}, states = {}, controlled = {}, calls = {},
        driving = {}, braking = {}, hidden = {}, flags = {}, seats = {}, messages = {},
        locks = {}, blips = {}, removed_handlers = 0, destroyed = 0,
    }
    local e = setmetatable({}, { __index = _G })
    e.Config = { Knoway = {
        VehicleModel = "knoway_car", DriverModel = "driver", RoadSnapDistance = 100,
        SpawnMinimumDistance = 100, SpawnMaximumDistance = 150,
    } }
    e.json = { null = { null = true } }
    e.GlobalState = { skyPhoneKnowayEntities = {} }
    e.GetGameTimer = function() return s.now end
    e.GetCurrentResourceName = function() return "sky_phone" end
    e.PlayerPedId = function() return 1 end
    e.GetEntityCoords = function() return { x = 0, y = 0, z = 1 } end
    e.GetEntityHeading = function() return 0 end
    e.joaat = function(value) return value end
    e.IsModelInCdimage = function() return not options.missing_model end
    e.IsModelAVehicle = function() return not options.invalid_vehicle end
    e.IsModelAPed = function() return not options.invalid_driver end
    e.RequestModel = function() end
    e.HasModelLoaded = function() return not options.unloaded_model end
    e.SetModelAsNoLongerNeeded = function() end
    e.GetClosestVehicleNodeWithHeading = function(x, y, z)
        if options.no_road then return false end
        return true, { x = x + (options.node_offset or 0), y = y, z = z }, 90
    end
    e.IsAnyVehicleNearPoint = function() return options.blocked_spawn end
    e.GetStreetNameAtCoord = function() return 0 end
    e.GetStreetNameFromHashKey = function() return "Street" end
    e.RegisterNUICallback = function(name, fn) s.callbacks[name] = fn end
    e.RegisterNetEvent = function(name, fn) s.events[name] = fn end
    e.AddEventHandler = e.RegisterNetEvent
    e.SendNUIMessage = function(data) s.messages[#s.messages + 1] = data end
    e.GetFirstBlipInfoId = function() return options.waypoint and 8 or 0 end
    e.DoesBlipExist = function(id) return (id == 8 and options.waypoint) or s.blips[id] end
    e.GetBlipInfoIdCoord = function() return { x = 100, y = 200, z = 0 } end
    e.AddBlipForEntity = function(vehicle) s.blips[vehicle + 100] = true; return vehicle + 100 end
    e.SetBlipSprite = function() end
    e.SetBlipColour = function() end
    e.RemoveBlip = function(id) s.blips[id] = nil end
    e.GetEntityFromStateBagName = function(name) return s.bags[name] or 0 end
    e.DoesEntityExist = function(entity) return s.entities[entity] end
    e.NetworkDoesEntityExistWithNetworkId = function(id) return s.entities[id] end
    e.NetToPed = function(id) return id end
    e.NetworkGetNetworkIdFromEntity = function(entity) return entity end
    e.GetEntityModel = function(entity) return entity end
    e.NetworkHasControlOfEntity = function(entity) return s.controlled[entity] end
    e.NetworkRequestControlOfEntity = function(entity)
        assert(entity == 3, "only the assigned driver's ownership may be requested")
        s.control_requests = (s.control_requests or 0) + 1
    end
    e.GetGamePool = function()
        local result = {}
        for entity in pairs(s.states) do result[#result + 1] = entity end
        return result
    end
    e.Entity = function(entity) return { state = { skyPhoneKnoway = s.states[entity] } } end
    e.AddStateBagChangeHandler = function(key, _, fn) s.state_handlers[key] = fn; return key end
    e.RemoveStateBagChangeHandler = function() s.removed_handlers = s.removed_handlers + 1 end
    e.CreateThread = function(fn) s.threads[#s.threads + 1] = { co = coroutine.create(fn), wake = s.now } end
    e.Wait = function(ms)
        assert(ms >= 50, "KnoWay must not run an idle per-frame worker")
        coroutine.yield(ms)
    end
    e.GetVehiclePedIsIn = function() return s.player_vehicle or 0 end
    e.GetPedConfigFlag = function(ped, flag)
        assert(flag == 184)
        return s.flags[ped] and s.flags[ped][flag] or false
    end
    e.SetPedConfigFlag = function(ped, flag, value)
        s.flags[ped] = s.flags[ped] or {}
        s.flags[ped][flag] = value
    end
    e.SetEntityVisible = function(ped, value) s.hidden[ped] = not value end
    e.SetEntityAlpha = function(_, alpha) assert(alpha == 0) end
    e.SetPedCanBeDraggedOut = function(_, value) assert(not value) end
    e.SetPedStayInVehicleWhenJacked = function(_, value) assert(value) end
    e.SetBlockingOfNonTemporaryEvents = function(_, value) assert(value) end
    e.SetPedKeepTask = function(_, value) assert(value) end
    e.SetDriverAbility = function() end
    e.SetDriverAggressiveness = function() end
    e.SetVehicleDoorsLocked = function(_, value) assert(value == 1) end
    e.SetVehicleIndividualDoorsLocked = function(vehicle, door, value)
        assert(door == 0)
        s.locks[vehicle] = value
    end
    e.GetPedInVehicleSeat = function(vehicle, seat)
        assert(seat == -1)
        return s.seats[vehicle] or 0
    end
    e.SetPedIntoVehicle = function(ped, vehicle, seat)
        assert(ped ~= 1 and seat == -1, "never warp a passenger")
        s.seats[vehicle] = ped
    end
    e.SetVehicleHandbrake = function(_, value) assert(not value) end
    e.SetVehicleEngineOn = function() end
    e.ClearPedTasks = function(ped) s.cleared = ped end
    e.TaskVehicleDriveToCoordLongrange = function(driver, vehicle, x, y, z, speed, style, radius)
        assert(type(x) == "number" and type(y) == "number" and type(z) == "number", "OAL needs scalar coordinates")
        s.driving[#s.driving + 1] = { driver = driver, vehicle = vehicle, x = x, speed = speed, style = style, radius = radius }
    end
    e.SetDriveTaskCruiseSpeed = function() end
    e.TaskVehicleTempAction = function(driver, vehicle, action, duration)
        assert(action == 27 and (duration == -1 or duration == 5000))
        s.braking[#s.braking + 1] = { driver, vehicle, duration }
    end
    e.DeleteEntity = function() s.destroyed = s.destroyed + 1 end
    e.Bridge = { Callbacks = { Trigger = function(name, data)
        s.calls[#s.calls + 1] = { name = name, data = data }
        if options.reply then return options.reply(name, data) end
        return { success = true, data = { activeRide = false } }
    end } }
    function s.advance(milliseconds)
        local deadline = s.now + milliseconds
        local iterations = 0
        while true do
            local selected, at
            for index, thread in ipairs(s.threads) do
                if thread.wake <= deadline and (not at or thread.wake < at) then selected, at = index, thread.wake end
            end
            if not selected then break end
            iterations = iterations + 1; assert(iterations < 10000, "worker did not yield")
            s.now = at
            local thread = table.remove(s.threads, selected)
            local ok, delay = coroutine.resume(thread.co)
            assert(ok, delay)
            if coroutine.status(thread.co) ~= "dead" then
                thread.wake = s.now + delay
                s.threads[#s.threads + 1] = thread
            end
        end
        s.now = deadline
    end
    function s.call(name, data)
        local response, count = nil, 0
        e.CreateThread(function()
            s.callbacks[name](data, function(result) count = count + 1; response = result end)
        end)
        s.advance(options.unloaded_model and 5100 or 0)
        assert(count == 1, name .. " must respond exactly once")
        return response
    end
    function s.vehicle(state, controlled)
        s.entities[2], s.entities[3] = true, true
        s.bags["entity:2"], s.bags["entity:3"] = 2, 3
        s.controlled[2], s.controlled[3] = controlled, controlled
        if not options.no_registry then
            e.GlobalState.skyPhoneKnowayEntities[state.rideId] = { vehicle = 2, driver = 3, model = 2, driverModel = 3 }
        end
        s.states[2] = state
        s.state_handlers.skyPhoneKnoway("entity:2", "skyPhoneKnoway", state)
        s.advance(0)
    end
    s.env = e
    assert(loadfile("sky_phone/source/client/knoway.lua", "t", e))()
    s.advance(0)
    return s
end

local target = { destination = { coords = { x = 1000, y = 2000, z = 0 }, label = "Destination" } }
local s = fixture()
assert(#s.threads == 0, "no vehicle should mean no running worker")
for _, action in ipairs({ "bootstrap", "request", "start", "cancel" }) do
    assert(s.call("knoway:" .. action, false).error == "invalid_request")
    assert(s.call("knoway:" .. action, {}).success)
    assert(s.calls[#s.calls].name == "sky_phone:knoway:" .. action)
end
assert(s.call("knoway:get-player-coords", {}).data.coords.z == 1)
assert(s.call("knoway:get-waypoint", {}).error == "no_waypoint")
assert(fixture({ waypoint = true }).call("knoway:get-waypoint", {}).data.coords.y == 200)
assert(s.call("knoway:quote", {}).error == "invalid_destination")
assert(s.call("knoway:quote", { destination = { coords = { x = 0 / 0, y = 1, z = 0 } } }).error == "invalid_destination")
assert(fixture({ missing_model = true }).call("knoway:quote", target).error == "invalid_vehicle_model")
assert(fixture({ invalid_vehicle = true }).call("knoway:quote", target).error == "invalid_vehicle_model")
assert(fixture({ invalid_driver = true }).call("knoway:quote", target).error == "invalid_driver_model")
assert(fixture({ unloaded_model = true }).call("knoway:quote", target).error == "model_unavailable")
assert(fixture({ no_road = true }).call("knoway:quote", target).error == "no_road")
assert(fixture({ node_offset = 150 }).call("knoway:quote", target).error == "no_road")
assert(fixture({ blocked_spawn = true }).call("knoway:quote", target).error == "no_spawn_point")
assert(s.call("knoway:quote", target).success)
local quote = s.calls[#s.calls]
assert(quote.name == "sky_phone:knoway:quote" and quote.data.destination.label == "Destination")
assert(quote.data.pickupNode.x == 0 and quote.data.destinationNode.x == 1000)
local spawn = quote.data.spawnNode
local distance = math.sqrt(spawn.x * spawn.x + spawn.y * spawn.y)
assert(distance >= 100 and distance <= 150 and type(spawn.heading) == "number")
local failed = fixture({ reply = function() return nil end })
assert(failed.call("knoway:request", {}).error == "request_failed")

local state = {
    rideId = "ride-1", driverNetId = 3, status = "approaching", replan = 0,
    target = { x = 50, y = 60, z = 1 }, speedKmh = 80, drivingStyle = 786603, arrivalRadius = 20,
}
s.vehicle(state, false)
assert(s.hidden[3] and #s.driving == 0, "remote clones hide the driver without issuing drive tasks")
s.controlled[2], s.controlled[3] = true, true
s.advance(500)
assert(#s.driving == 1 and s.driving[1].speed == 80 / 3.6 and s.locks[2] == 2)
s.advance(1500)
assert(#s.driving == 1, "a stable owner must not restart the route every tick")
s.controlled[3] = false; s.advance(500)
assert(s.control_requests == 1, "the vehicle owner must bring its assigned driver under the same owner")
s.controlled[3] = true; s.advance(500)
assert(#s.driving == 2, "a new owner resumes the server's current route")
state.replan = 1
s.state_handlers.skyPhoneKnoway("entity:2", "skyPhoneKnoway", state); s.advance(500)
assert(#s.driving == 3, "server replanning must restart the native task")
state.status = "waiting"
s.state_handlers.skyPhoneKnoway("entity:2", "skyPhoneKnoway", state); s.advance(500)
assert(#s.braking == 1 and s.braking[1][3] == -1, "waiting must hold the vehicle")
s.player_vehicle = 2; s.advance(500)
assert(s.flags[1][184], "passengers must not shuffle into the driver seat")
s.player_vehicle = nil; s.advance(500)
assert(not s.flags[1][184], "leaving must restore the player's previous shuffle flag")
s.flags[1][184] = true; s.player_vehicle = 2; s.advance(500)
s.player_vehicle = nil; s.advance(500)
assert(s.flags[1][184], "an existing shuffle restriction belongs to its original owner")

s.events["sky_phone:knoway:changed"]({ activeRide = { id = "ride-1", status = "waiting", vehicle = { netId = 2 } } })
s.advance(500)
assert(s.blips[102] and s.messages[#s.messages].type == "knoway:changed")
s.events["sky_phone:knoway:changed"]({ activeRide = false })
assert(not s.blips[102] and s.messages[#s.messages].data.activeRide == s.env.json.null)
s.events.onResourceStop("unrelated")
assert(s.removed_handlers == 0)
s.events.onResourceStop("sky_phone")
assert(s.removed_handlers == 2 and s.locks[2] == 1 and s.destroyed == 0,
    "shutdown must release doors without deleting an occupied server vehicle")
s.advance(1000)
assert(#s.threads == 0, "shutdown must retire all local workers")

local delayed = fixture()
delayed.env.GlobalState.skyPhoneKnowayEntities[state.rideId] = { vehicle = 2, driver = 3, model = 2, driverModel = 3 }
delayed.state_handlers.skyPhoneKnoway("entity:2", "skyPhoneKnoway", state)
delayed.advance(500)
assert(#delayed.driving == 0)
delayed.entities[2], delayed.entities[3] = true, true
delayed.bags["entity:2"] = 2
delayed.controlled[2], delayed.controlled[3] = true, true
delayed.advance(500)
assert(delayed.hidden[3] and #delayed.braking == 1, "state may arrive before the streamed entity")
delayed.state_handlers.skyPhoneKnoway("entity:2", "skyPhoneKnoway", nil)
delayed.advance(500)
assert(#delayed.threads == 0, "removed/out-of-scope entities must not leave an idle worker")

local unregistered = fixture({ no_registry = true })
unregistered.vehicle(state, true)
assert(not unregistered.hidden[3] and #unregistered.braking == 0 and #unregistered.driving == 0,
    "client-owned vehicle bags alone do not authorize hiding or driving an entity")
unregistered.entities[99], unregistered.bags["entity:99"] = true, 99
unregistered.state_handlers.skyPhoneKnowayDriver("entity:99", "skyPhoneKnowayDriver", true)
unregistered.advance(0)
assert(not unregistered.hidden[99], "a forged driver marker must not hide an unrelated pedestrian")
local spoofed_driver = fixture()
local spoofed_state = {}
for key, value in pairs(state) do spoofed_state[key] = value end
spoofed_state.driverNetId = 99
spoofed_driver.vehicle(spoofed_state, true)
assert(not spoofed_driver.hidden[3] and #spoofed_driver.braking == 0,
    "vehicle state must retain the driver assigned by the server registry")
print("KnoWay client runtime tests passed")
