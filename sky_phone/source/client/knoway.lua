-- The phone is only a view of the ride. Networked vehicle tasks outlive its UI.
local vehicles = {}
local pending_bags = {}
local worker_running = false
local stopped = false
local active_ride
local ride_blip
local shuffle_ped
local previous_shuffle_flag

local function coordinates(value)
    if type(value) ~= "table" then return nil end
    local x, y, z = tonumber(value.x), tonumber(value.y), tonumber(value.z)
    if not x or not y or not z or x ~= x or y ~= y or z ~= z
        or math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 5000 then
        return nil
    end
    return { x = x, y = y, z = z }
end

local function horizontal_distance(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function road_node(point)
    local found, position, heading = GetClosestVehicleNodeWithHeading(point.x, point.y, point.z, 1, 3.0, 0)
    if not found or horizontal_distance(position, point) > Config.Knoway.RoadSnapDistance then return nil end
    return { x = position.x, y = position.y, z = position.z, heading = heading }
end

local function street_label(point)
    local street = GetStreetNameAtCoord(point.x, point.y, point.z)
    if street == 0 then return "" end
    return GetStreetNameFromHashKey(street)
end

local function spawn_node(origin)
    local minimum, maximum = Config.Knoway.SpawnMinimumDistance, Config.Knoway.SpawnMaximumDistance
    local heading = GetEntityHeading(PlayerPedId()) + 180.0
    for step = 0, 11 do
        local angle = math.rad(heading + step * 30.0)
        for _, radius in ipairs({ (minimum + maximum) / 2, minimum, maximum }) do
            local node = road_node({
                x = origin.x + math.sin(angle) * radius,
                y = origin.y + math.cos(angle) * radius,
                z = origin.z,
            })
            if node then
                local distance = horizontal_distance(node, origin)
                if distance >= minimum and distance <= maximum
                    and not IsAnyVehicleNearPoint(node.x, node.y, node.z, 5.0) then
                    return node
                end
            end
        end
    end
    return nil
end

local function request_model(model)
    RequestModel(model)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(50) end
    local loaded = HasModelLoaded(model)
    SetModelAsNoLongerNeeded(model)
    return loaded
end

local function remove_blip()
    if ride_blip and DoesBlipExist(ride_blip) then RemoveBlip(ride_blip) end
    ride_blip = nil
end

local function apply_state(data)
    if type(data) ~= "table" then return end
    local ride = type(data.activeRide) == "table" and data.activeRide.id and data.activeRide or nil
    if not active_ride or not ride or active_ride.id ~= ride.id or active_ride.status ~= ride.status then remove_blip() end
    active_ride = ride
    if data.activeRide == false then data.activeRide = json.null end
end

local function relay(name, data, cb)
    local result = Bridge.Callbacks.Trigger("sky_phone:" .. name, data)
    if type(result) ~= "table" then result = { success = false, error = "request_failed" } end
    if result.success then apply_state(result.data) end
    cb(result)
end

for _, name in ipairs({ "knoway:bootstrap", "knoway:request", "knoway:start", "knoway:cancel" }) do
    RegisterNUICallback(name, function(data, cb)
        if type(data) ~= "table" then cb({ success = false, error = "invalid_request" }); return end
        relay(name, data, cb)
    end)
end

RegisterNUICallback("knoway:quote", function(data, cb)
    local destination = type(data) == "table" and data.destination
    local target = type(destination) == "table" and coordinates(destination.coords)
    if not target then cb({ success = false, error = "invalid_destination" }); return end
    local vehicle_model = Config.Knoway.VehicleModel
    if vehicle_model == "" or not IsModelInCdimage(joaat(vehicle_model)) or not IsModelAVehicle(joaat(vehicle_model)) then
        cb({ success = false, error = "invalid_vehicle_model" }); return
    end
    local driver_model = joaat(Config.Knoway.DriverModel)
    if not IsModelInCdimage(driver_model) or not IsModelAPed(driver_model) then
        cb({ success = false, error = "invalid_driver_model" }); return
    end
    if not request_model(joaat(vehicle_model)) or not request_model(driver_model) then
        cb({ success = false, error = "model_unavailable" }); return
    end
    local origin = GetEntityCoords(PlayerPedId())
    local pickup, arrival = road_node(origin), road_node(target)
    if not pickup or not arrival then cb({ success = false, error = "no_road" }); return end
    pickup.label = street_label(pickup)
    local arrival_label = street_label(arrival)
    local spawn = spawn_node(origin)
    if not spawn then cb({ success = false, error = "no_spawn_point" }); return end
    relay("knoway:quote", {
        destination = { coords = target, label = arrival_label ~= "" and arrival_label or destination.label },
        pickupNode = pickup, destinationNode = arrival, spawnNode = spawn,
    }, cb)
end)

RegisterNUICallback("knoway:get-player-coords", function(_, cb)
    local position = GetEntityCoords(PlayerPedId())
    cb({ success = true, data = { coords = { x = position.x, y = position.y, z = position.z } } })
end)

RegisterNUICallback("knoway:get-waypoint", function(_, cb)
    local waypoint = GetFirstBlipInfoId(8)
    if not DoesBlipExist(waypoint) then cb({ success = false, error = "no_waypoint" }); return end
    local position = GetBlipInfoIdCoord(waypoint)
    cb({ success = true, data = { coords = { x = position.x, y = position.y, z = position.z } } })
end)

RegisterNetEvent("sky_phone:knoway:changed", function(data)
    apply_state(data)
    SendNUIMessage({ type = "knoway:changed", data = data })
end)

local function hide_driver(driver)
    SetEntityVisible(driver, false, false)
    SetEntityAlpha(driver, 0, false)
    SetPedCanBeDraggedOut(driver, false)
    SetPedStayInVehicleWhenJacked(driver, true)
    SetBlockingOfNonTemporaryEvents(driver, true)
    SetPedConfigFlag(driver, 251, true) -- AI can drive with rear-seat passengers.
    SetPedConfigFlag(driver, 255, true) -- Permit passenger entry around the AI task.
end

local function registered_driver(driver)
    for _, record in pairs(GlobalState.skyPhoneKnowayEntities or {}) do
        if record.driver == NetworkGetNetworkIdFromEntity(driver)
            and GetEntityModel(driver) % 4294967296 == record.driverModel % 4294967296 then return true end
    end
    return false
end

local function restore_shuffle()
    if shuffle_ped and DoesEntityExist(shuffle_ped) then
        SetPedConfigFlag(shuffle_ped, 184, previous_shuffle_flag)
    end
    shuffle_ped, previous_shuffle_flag = nil, nil
end

local function manage_passenger()
    local player = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(player, false)
    if vehicles[vehicle] and vehicles[vehicle].authorized then
        if shuffle_ped ~= player then
            restore_shuffle()
            shuffle_ped = player
            previous_shuffle_flag = GetPedConfigFlag(player, 184, false)
            SetPedConfigFlag(player, 184, true)
        end
        -- The invisible driver and locked driver door reserve seat -1. Do not
        -- disable exit controls: every passenger must remain free to leave.
    else
        restore_shuffle()
    end
end

local function update_vehicle(vehicle, entry)
    entry.authorized = false
    local state = entry.state
    local record = (GlobalState.skyPhoneKnowayEntities or {})[state.rideId]
    -- Entity bags can be written by their network owner. Only the server's
    -- registry authorizes manipulating a vehicle or hiding its assigned driver.
    if not record or record.vehicle ~= NetworkGetNetworkIdFromEntity(vehicle)
        or record.driver ~= state.driverNetId or GetEntityModel(vehicle) % 4294967296 ~= record.model % 4294967296
        or type(state.speedKmh) ~= "number" or state.speedKmh ~= state.speedKmh or state.speedKmh <= 0 or state.speedKmh > 200
        or type(state.drivingStyle) ~= "number" or state.drivingStyle ~= math.floor(state.drivingStyle)
        or math.abs(state.drivingStyle) > 2147483647
        or type(state.arrivalRadius) ~= "number" or state.arrivalRadius ~= state.arrivalRadius or state.arrivalRadius < 1
        or state.arrivalRadius > 100 then entry.controlled = false; return end
    local driver_id = tonumber(state.driverNetId)
    if not driver_id or not NetworkDoesEntityExistWithNetworkId(driver_id) then
        entry.controlled = false
        return
    end
    local driver = NetToPed(driver_id)
    if driver == 0 or not DoesEntityExist(driver) or not registered_driver(driver) then entry.controlled = false; return end
    entry.authorized = true
    if entry.driver ~= driver then hide_driver(driver); entry.driver = driver; entry.controlled = false end
    local vehicle_controlled = NetworkHasControlOfEntity(vehicle)
    if vehicle_controlled and not NetworkHasControlOfEntity(driver) then NetworkRequestControlOfEntity(driver) end
    local controlled = vehicle_controlled and NetworkHasControlOfEntity(driver)
    if not controlled then entry.controlled = false; return end
    local target = type(state.target) == "table" and coordinates(state.target)
    local signature = table.concat({ tostring(state.rideId), tostring(state.status), tostring(state.replan),
        target and tostring(target.x) or "", target and tostring(target.y) or "", target and tostring(target.z) or "",
        tostring(state.speedKmh), tostring(state.drivingStyle), tostring(state.arrivalRadius) }, ":")
    if entry.controlled and entry.signature == signature then return end
    entry.controlled, entry.signature = true, signature
    hide_driver(driver)
    SetPedKeepTask(driver, true)
    SetDriverAbility(driver, 1.0)
    SetDriverAggressiveness(driver, 0.0)
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleIndividualDoorsLocked(vehicle, 0, 2)
    if GetPedInVehicleSeat(vehicle, -1) == 0 then SetPedIntoVehicle(driver, vehicle, -1) end
    if GetPedInVehicleSeat(vehicle, -1) ~= driver then
        entry.controlled = false
        return
    end
    if (state.status == "approaching" or state.status == "driving") and target then
        ClearPedTasks(driver)
        SetVehicleHandbrake(vehicle, false)
        SetVehicleEngineOn(vehicle, true, true, false)
        TaskVehicleDriveToCoordLongrange(driver, vehicle, target.x, target.y, target.z,
            state.speedKmh / 3.6, state.drivingStyle, state.arrivalRadius)
        SetDriveTaskCruiseSpeed(driver, state.speedKmh / 3.6)
    else
        SetDriveTaskCruiseSpeed(driver, 0.0)
        TaskVehicleTempAction(driver, vehicle, 27, -1)
    end
end

local function start_worker()
    if worker_running or stopped then return end
    worker_running = true
    CreateThread(function()
        while not stopped and next(vehicles) do
            if ride_blip and not DoesBlipExist(ride_blip) then ride_blip = nil end
            for vehicle, entry in pairs(vehicles) do
                if not DoesEntityExist(vehicle) then
                    vehicles[vehicle] = nil
                else
                    update_vehicle(vehicle, entry)
                    if not ride_blip and active_ride and active_ride.vehicle
                        and active_ride.vehicle.netId == NetworkGetNetworkIdFromEntity(vehicle)
                        and (active_ride.status == "approaching" or active_ride.status == "waiting" or active_ride.status == "driving") then
                        ride_blip = AddBlipForEntity(vehicle)
                        SetBlipSprite(ride_blip, 225)
                        SetBlipColour(ride_blip, 3)
                    end
                end
            end
            manage_passenger()
            Wait(500)
        end
        restore_shuffle()
        worker_running = false
    end)
end

local function track_bag(bag_name, value, is_driver)
    if stopped then return end
    if not value then
        local entity = GetEntityFromStateBagName(bag_name)
        vehicles[entity] = nil
        pending_bags[bag_name] = nil
        return
    end
    if not is_driver and (type(value) ~= "table" or type(value.rideId) ~= "string") then return end
    local token = {}
    pending_bags[bag_name] = token
    CreateThread(function()
        local deadline = GetGameTimer() + 10000
        while not stopped and pending_bags[bag_name] == token and GetGameTimer() < deadline do
            local entity = GetEntityFromStateBagName(bag_name)
            if entity ~= 0 and DoesEntityExist(entity) then
                pending_bags[bag_name] = nil
                if is_driver then
                    if registered_driver(entity) then hide_driver(entity) end
                else
                    local entry = vehicles[entity] or {}
                    entry.state = value
                    vehicles[entity] = entry
                    start_worker()
                end
                return
            end
            Wait(100)
        end
        if pending_bags[bag_name] == token then pending_bags[bag_name] = nil end
    end)
end

local vehicle_cookie = AddStateBagChangeHandler("skyPhoneKnoway", nil, function(bag_name, _, value)
    track_bag(bag_name, value, false)
end)
local driver_cookie = AddStateBagChangeHandler("skyPhoneKnowayDriver", nil, function(bag_name, _, value)
    track_bag(bag_name, value, true)
end)

-- A resource restart can attach to already streamed entities without a fresh
-- state-change event. Subsequent streaming is covered by the state handlers.
CreateThread(function()
    for _, vehicle in ipairs(GetGamePool("CVehicle")) do
        local value = Entity(vehicle).state.skyPhoneKnoway
        if type(value) == "table" and type(value.rideId) == "string" then
            vehicles[vehicle] = { state = value }
        end
    end
    start_worker()
end)

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name ~= GetCurrentResourceName() then return end
    stopped = true
    RemoveStateBagChangeHandler(vehicle_cookie)
    RemoveStateBagChangeHandler(driver_cookie)
    restore_shuffle()
    remove_blip()
    for vehicle, entry in pairs(vehicles) do
        if entry.authorized and DoesEntityExist(vehicle) and NetworkHasControlOfEntity(vehicle) then
            SetVehicleDoorsLocked(vehicle, 1)
            SetVehicleIndividualDoorsLocked(vehicle, 0, 1)
            if entry.driver and DoesEntityExist(entry.driver) and NetworkHasControlOfEntity(entry.driver) then
                SetDriveTaskCruiseSpeed(entry.driver, 0.0)
                TaskVehicleTempAction(entry.driver, vehicle, 27, 5000)
            end
        end
    end
    vehicles, pending_bags = {}, {}
end)
