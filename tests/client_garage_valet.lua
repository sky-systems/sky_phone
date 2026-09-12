local function new_client(options)
    options = options or {}
    local test = {
        now = 0, threads = {}, events = {}, callbacks = {}, entities = {},
        completions = 0, leave_count = 0, deleted = {},
    }
    local env = setmetatable({}, { __index = _G })
    local vector_mt = {}
    local function vector(x, y, z)
        return setmetatable({ x = x, y = y, z = z }, vector_mt)
    end
    vector_mt.__sub = function(a, b) return vector(a.x - b.x, a.y - b.y, a.z - b.z) end
    vector_mt.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end

    env.Config = {
        Bridge = { Locale = "en" },
        Garage = { Valet = {
            SpawnDistance = 110.0, ArrivalDistance = 14.0, DriveSpeed = 20.0,
            DrivingStyle = 786603, TimeoutSeconds = 180,
        } },
    }
    env.SkyPhoneLocales = { Resolve = function()
        return { Nui = { Apps = { garage = { errors = {} } } } }
    end }
    env.GetGameTimer = function() return test.now end
    env.GetCurrentResourceName = function() return "sky_phone" end
    env.RegisterNetEvent = function(name, callback) test.events[name] = callback end
    env.AddEventHandler = env.RegisterNetEvent
    env.RegisterNUICallback = function(name, callback) test.callbacks[name] = callback end
    env.SendNUIMessage = function(message) test.state = message.data end
    env.CreateThread = function(callback)
        test.threads[#test.threads + 1] = { co = coroutine.create(callback), wake = test.now }
    end
    env.Wait = function(ms) return coroutine.yield(ms) end
    env.SetTimeout = function(ms, callback)
        test.threads[#test.threads + 1] = { co = coroutine.create(callback), wake = test.now + ms }
    end
    env.Bridge = {
        Framework = { Notify = function() end },
        Callbacks = { Trigger = function(name)
            if name == "sky_phone:garage:valet-request" then
                return { success = true, data = {
                    orderId = "test-order", cost = 750, driverModel = "valet",
                    vehicle = { model = 1, plate = "VALET", properties = {} },
                } }
            end
            if name == "sky_phone:garage:valet-complete" then
                test.completions = test.completions + 1
                if options.completion_delay then env.Wait(options.completion_delay) end
                return { success = not options.completion_failure }
            end
            assert(name == "sky_phone:garage:valet-cancel", name)
            return { success = true }
        end },
    }
    env.joaat = function(value) return value end
    env.PlayerPedId = function() return 1 end
    env.IsModelInCdimage = function() return 1 end
    env.IsModelAVehicle = function() return 1 end
    env.HasModelLoaded = function() return 1 end
    env.GetGamePool = function() return {} end
    env.GetDisplayNameFromVehicleModel = function() return "TEST" end
    env.GetLabelText = function() return "Test vehicle" end
    env.GetEntityCoords = function() return vector(0.0, 0.0, 0.0) end
    env.GetOffsetFromEntityInWorldCoords = function(_, x, y, z) return vector(x, y, z) end
    env.GetClosestVehicleNodeWithHeading = function() return 1, vector(0.0, 0.0, 0.0), 0.0 end
    env.GetEntityHeading = function() return 0.0 end
    env.CreateVehicle = function()
        test.entities[2] = { kind = "vehicle" }
        return 2
    end
    env.CreatePedInsideVehicle = function()
        test.entities[3] = { kind = "driver", in_vehicle = true }
        return 3
    end
    env.DoesEntityExist = function(entity) return test.entities[entity] and 1 or nil end
    env.IsEntityDead = function() return nil end
    env.IsVehicleDriveable = function() return 1 end
    env.NetworkGetNetworkIdFromEntity = function(entity) return entity end
    env.AddBlipForEntity = function() return 4 end
    env.DoesBlipExist = function() return 1 end
    env.SetEntityAsMissionEntity = function(entity) test.entities[entity].owned = true end
    env.SetEntityAsNoLongerNeeded = function(entity) test.entities[entity].owned = false end
    env.DeleteEntity = function(entity)
        assert(test.entities[entity], "must not delete a missing entity")
        test.entities[entity] = nil
        test.deleted[entity] = (test.deleted[entity] or 0) + 1
    end
    env.TaskVehicleDriveToCoordLongrange = function(driver)
        test.entities[driver].driving = true
    end
    env.ClearPedTasks = function(driver)
        test.entities[driver].driving = false
    end
    env.TaskLeaveVehicle = function(driver)
        test.leave_count = test.leave_count + 1
        test.leave_started = test.now
        test.entities[driver].exit_at = options.blocked_exit and math.huge or test.now + 1000
    end
    env.IsPedInVehicle = function(driver)
        local ped = test.entities[driver]
        -- Seat occupancy can end before the exit/door animation has completed.
        if ped.exit_at and test.now >= ped.exit_at then ped.in_vehicle = false end
        return ped.in_vehicle and 1 or nil
    end
    env.GetScriptTaskStatus = function()
        return test.now < test.leave_started + 1500 and 1 or 7
    end
    local function walk(driver, x, y, z, speed)
        assert(math.type(x) == "float" and math.type(y) == "float" and math.type(z) == "float",
            "OAL coordinates must be separate floats")
        assert(speed == 1.0, "the driver must walk away")
        test.walk_started = test.now
        test.entities[driver].walking = true
    end
    env.TaskGoStraightToCoord = walk
    env.TaskFollowNavMeshToCoord = walk
    for _, name in ipairs({
        "RequestModel", "SetModelAsNoLongerNeeded", "SetVehicleOnGroundProperly", "SetVehicleModKit",
        "ToggleVehicleMod", "SetVehicleNumberPlateText", "SetVehicleHasBeenOwnedByPlayer",
        "SetVehicleDoorsLocked", "SetVehicleEngineOn", "SetNetworkIdCanMigrate",
        "SetBlockingOfNonTemporaryEvents", "SetPedKeepTask", "SetDriverAbility",
        "SetDriverAggressiveness", "SetBlipSprite", "SetBlipColour", "SetBlipRoute",
        "RemoveBlip", "TaskVehicleTempAction",
    }) do
        env[name] = function() end
    end

    function test.advance(ms)
        local target = test.now + ms
        while true do
            local next_thread
            for _, thread in ipairs(test.threads) do
                if coroutine.status(thread.co) ~= "dead" and thread.wake <= target
                    and (not next_thread or thread.wake < next_thread.wake)
                then
                    next_thread = thread
                end
            end
            if not next_thread then break end
            test.now = next_thread.wake
            local success, delay = coroutine.resume(next_thread.co)
            assert(success, delay)
            next_thread.wake = test.now + (delay or 0)
        end
        test.now = target
    end
    function test.stop() test.events.onResourceStop("sky_phone") end
    function test.abort() test.events["sky_phone:garage:valet-aborted"]("valet_timeout") end
    assert(loadfile("sky_phone/source/client/garage.lua", "t", env))()
    test.callbacks["garage:valet-request"]({ plate = "VALET" }, function(result)
        assert(result.success, "request must be accepted")
    end)
    return test
end

local delivered = new_client()
delivered.advance(3400)
assert(delivered.state.status == "delivered" and delivered.completions == 1)
assert(delivered.leave_count == 1, "the driver must only exit once")
assert(delivered.walk_started >= delivered.leave_started + 1500,
    "walking must wait until the normal exit animation is finished")
assert(delivered.entities[3].walking and not delivered.entities[3].driving,
    "the walking driver must have no driving task left to resume")
assert(delivered.entities[3].owned, "the driver must stay under script control until despawn")
delivered.advance(5000)
assert(delivered.entities[3] and not delivered.entities[3].in_vehicle,
    "the driver must remain outside while walking away")
delivered.advance(5000)
assert(not delivered.entities[3] and delivered.deleted[3] == 1, "the driver must despawn after walking")
assert(delivered.entities[2], "despawning the valet must preserve the delivered vehicle")
delivered.advance(12000)
assert(delivered.state == nil, "the completed order must still clear normally")

local blocked = new_client({ blocked_exit = true })
blocked.advance(7000)
assert(blocked.state.status == "delivered" and blocked.completions == 1)
assert(not blocked.entities[3] and blocked.entities[2], "a blocked door must not leave the driver in the car")
assert(not blocked.walk_started, "a seated driver must not be given an on-foot task")

local failed = new_client({ completion_failure = true })
failed.advance(3400)
assert(failed.state.status == "failed" and not failed.entities[2] and not failed.entities[3],
    "failed completion must clean up both valet entities")
failed.entities[3] = { kind = "unrelated" }
failed.advance(12000)
assert(failed.entities[3], "a pending despawn must not delete a reused entity handle after failure")

local stopped = new_client()
stopped.advance(3400)
stopped.stop()
assert(stopped.entities[2] and not stopped.entities[3], "resource stop must clean up the departing driver only")
stopped.entities[3] = { kind = "unrelated" }
stopped.advance(12000)
assert(stopped.entities[3], "a pending despawn must not delete a reused entity handle after resource stop")

for _, abort_time in ipairs({ 1000, 2300 }) do
    local aborted = new_client()
    aborted.advance(abort_time)
    aborted.abort()
    aborted.advance(12000)
    assert(aborted.completions == 0 and not aborted.walk_started,
        "an aborted arrival must not continue with exit, walking, or completion")
    assert(not aborted.entities[2] and not aborted.entities[3])
end

local interrupted = new_client({ completion_delay = 1000 })
interrupted.advance(3400)
interrupted.abort()
interrupted.advance(12000)
assert(interrupted.state == nil and not interrupted.entities[2] and not interrupted.entities[3],
    "a late completion response must not resurrect an aborted order")

local delayed = new_client({ completion_delay = 15000 })
delayed.advance(14000)
assert(delayed.entities[2] and not delayed.entities[3],
    "driver cleanup must not be delayed by a pending server response")
delayed.advance(5000)
assert(delayed.state.status == "delivered" and delayed.entities[2],
    "delivery must still complete if the driver has already despawned")

print("Client garage valet tests passed (8 scenarios)")
