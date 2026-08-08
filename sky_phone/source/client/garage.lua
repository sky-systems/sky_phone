local current_valet = nil

local vehicle_mods = {
    modSpoilers = 0,
    modFrontBumper = 1,
    modRearBumper = 2,
    modSideSkirt = 3,
    modExhaust = 4,
    modFrame = 5,
    modGrille = 6,
    modHood = 7,
    modFender = 8,
    modRightFender = 9,
    modRoof = 10,
    modEngine = 11,
    modBrakes = 12,
    modTransmission = 13,
    modHorns = 14,
    modSuspension = 15,
    modArmor = 16,
    modFrontWheels = 23,
    modBackWheels = 24,
    modPlateHolder = 25,
    modVanityPlate = 26,
    modTrimA = 27,
    modOrnaments = 28,
    modDashboard = 29,
    modDial = 30,
    modDoorSpeaker = 31,
    modSeats = 32,
    modSteeringWheel = 33,
    modShifterLeavers = 34,
    modAPlate = 35,
    modSpeakers = 36,
    modTrunk = 37,
    modHydrolic = 38,
    modEngineBlock = 39,
    modAirFilter = 40,
    modStruts = 41,
    modArchCover = 42,
    modAerials = 43,
    modTrimB = 44,
    modTank = 45,
    modWindows = 46,
    modLivery = 48,
}

local function garage_locale()
    local locale = Locales[Config.Bridge.Locale] or Locales["en"]
    return locale.Nui.Apps.garage
end

local function normalized_plate(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function request_model(model)
    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(50)
    end
    return HasModelLoaded(model)
end

local function set_vehicle_color(vehicle, primary, secondary)
    if type(primary) == "table" then
        SetVehicleCustomPrimaryColour(
            vehicle,
            tonumber(primary[1]) or 0,
            tonumber(primary[2]) or 0,
            tonumber(primary[3]) or 0
        )
    end
    if type(secondary) == "table" then
        SetVehicleCustomSecondaryColour(
            vehicle,
            tonumber(secondary[1]) or 0,
            tonumber(secondary[2]) or 0,
            tonumber(secondary[3]) or 0
        )
    end
    if type(primary) == "number" or type(secondary) == "number" then
        local current_primary, current_secondary = GetVehicleColours(vehicle)
        SetVehicleColours(
            vehicle,
            tonumber(primary) or current_primary,
            tonumber(secondary) or current_secondary
        )
    end
end

local function apply_vehicle_properties(vehicle, properties, fallback)
    properties = type(properties) == "table" and properties or {}
    SetVehicleModKit(vehicle, 0)
    set_vehicle_color(vehicle, properties.color1, properties.color2)
    if properties.pearlescentColor or properties.wheelColor then
        SetVehicleExtraColours(
            vehicle,
            tonumber(properties.pearlescentColor) or 0,
            tonumber(properties.wheelColor) or 0
        )
    end
    if properties.wheels then
        SetVehicleWheelType(vehicle, tonumber(properties.wheels) or 0)
    end
    if properties.windowTint then
        SetVehicleWindowTint(vehicle, tonumber(properties.windowTint) or 0)
    end
    if properties.xenonColor then
        SetVehicleXenonLightsColor(vehicle, tonumber(properties.xenonColor) or -1)
    end
    for property, mod_type in pairs(vehicle_mods) do
        local value = tonumber(properties[property])
        if value then
            SetVehicleMod(vehicle, mod_type, value, false)
        end
    end
    ToggleVehicleMod(vehicle, 18, properties.modTurbo == true)
    ToggleVehicleMod(vehicle, 20, properties.modSmokeEnabled == true)
    ToggleVehicleMod(vehicle, 22, properties.modXenon == true)
    if type(properties.neonEnabled) == "table" then
        for index = 0, 3 do
            SetVehicleNeonLightEnabled(vehicle, index, properties.neonEnabled[index + 1] == true)
        end
    end
    if type(properties.neonColor) == "table" then
        SetVehicleNeonLightsColour(
            vehicle,
            tonumber(properties.neonColor[1]) or 0,
            tonumber(properties.neonColor[2]) or 0,
            tonumber(properties.neonColor[3]) or 0
        )
    end
    if type(properties.tyreSmokeColor) == "table" then
        SetVehicleTyreSmokeColor(
            vehicle,
            tonumber(properties.tyreSmokeColor[1]) or 0,
            tonumber(properties.tyreSmokeColor[2]) or 0,
            tonumber(properties.tyreSmokeColor[3]) or 0
        )
    end
    if type(properties.extras) == "table" then
        for extra_id, enabled in pairs(properties.extras) do
            local numeric_id = tonumber(extra_id)
            if numeric_id and DoesExtraExist(vehicle, numeric_id) then
                SetVehicleExtra(vehicle, numeric_id, not enabled)
            end
        end
    end
    local fuel = tonumber(properties.fuelLevel or properties.fuel or fallback.fuel)
    local engine = tonumber(properties.engineHealth or properties.engine or fallback.engine and fallback.engine * 10)
    local body = tonumber(properties.bodyHealth or properties.body or fallback.body and fallback.body * 10)
    if fuel then
        SetVehicleFuelLevel(vehicle, math.max(0.0, math.min(100.0, fuel)))
    end
    if engine then
        SetVehicleEngineHealth(vehicle, math.max(-4000.0, math.min(1000.0, engine)))
    end
    if body then
        SetVehicleBodyHealth(vehicle, math.max(0.0, math.min(1000.0, body)))
    end
    if properties.dirtLevel then
        SetVehicleDirtLevel(vehicle, math.max(0.0, math.min(15.0, tonumber(properties.dirtLevel) or 0.0)))
    end
    SetVehicleNumberPlateText(vehicle, fallback.plate)
end

local function existing_vehicle(plate)
    local normalized = string.upper(normalized_plate(plate))
    for _, vehicle in ipairs(GetGamePool("CVehicle")) do
        if string.upper(normalized_plate(GetVehicleNumberPlateText(vehicle))) == normalized then
            return vehicle
        end
    end
    return nil
end

local function public_valet_state()
    if not current_valet then
        return nil
    end
    return {
        canCancel = current_valet.can_cancel,
        cost = current_valet.cost,
        distance = current_valet.distance,
        etaSeconds = current_valet.eta_seconds,
        orderId = current_valet.order_id,
        plate = current_valet.plate,
        status = current_valet.status,
        vehicleName = current_valet.vehicle_name,
    }
end

local function send_valet_state()
    SendNUIMessage({
        type = "garage:valet-status",
        data = public_valet_state(),
    })
end

local function remove_valet_blip()
    if current_valet and current_valet.blip and DoesBlipExist(current_valet.blip) then
        RemoveBlip(current_valet.blip)
        current_valet.blip = nil
    end
end

local function delete_valet_entities()
    if not current_valet then
        return
    end
    remove_valet_blip()
    if current_valet.driver and DoesEntityExist(current_valet.driver) then
        DeleteEntity(current_valet.driver)
    end
    if current_valet.vehicle and DoesEntityExist(current_valet.vehicle) then
        DeleteEntity(current_valet.vehicle)
    end
end

local function fail_valet(error_code, server_cancel)
    if not current_valet then
        return
    end
    local order_id = current_valet.order_id
    current_valet.cancelled = true
    delete_valet_entities()
    if server_cancel then
        Bridge.Callbacks.Trigger("sky_phone:garage:valet-cancel", { orderId = order_id })
    end
    current_valet.status = "failed"
    current_valet.can_cancel = false
    current_valet.error = error_code
    send_valet_state()
    local locale = garage_locale()
    Bridge.Framework.Notify(locale.name, locale.errors[error_code] or locale.errors.default, "error", 5000)
    SetTimeout(8000, function()
        if current_valet and current_valet.order_id == order_id then
            current_valet = nil
            send_valet_state()
        end
    end)
end

local function update_drive_target(driver, vehicle)
    local coords = GetEntityCoords(PlayerPedId())
    TaskVehicleDriveToCoordLongrange(
        driver,
        vehicle,
        coords.x,
        coords.y,
        coords.z,
        Config.Garage.Valet.DriveSpeed,
        Config.Garage.Valet.DrivingStyle,
        Config.Garage.Valet.ArrivalDistance
    )
end

local function run_valet_delivery(order)
    local model = tonumber(order.vehicle.model)
    if not model and type(order.vehicle.model) == "string" then
        model = joaat(order.vehicle.model)
    end
    local driver_model = joaat(order.driverModel)
    if not model or not IsModelInCdimage(model) or not IsModelAVehicle(model) then
        fail_valet("invalid_vehicle_model", true)
        return
    end
    if existing_vehicle(order.vehicle.plate) then
        fail_valet("vehicle_already_out", true)
        return
    end
    current_valet.status = "preparing"
    send_valet_state()
    if not request_model(model) or not request_model(driver_model) then
        SetModelAsNoLongerNeeded(model)
        SetModelAsNoLongerNeeded(driver_model)
        fail_valet("valet_spawn_failed", true)
        return
    end

    local player_ped = PlayerPedId()
    local player_coords = GetEntityCoords(player_ped)
    local target = GetOffsetFromEntityInWorldCoords(player_ped, 0.0, -Config.Garage.Valet.SpawnDistance, 0.0)
    local found, spawn_coords, spawn_heading = GetClosestVehicleNodeWithHeading(
        target.x,
        target.y,
        target.z,
        1,
        3.0,
        0
    )
    if not found then
        SetModelAsNoLongerNeeded(model)
        SetModelAsNoLongerNeeded(driver_model)
        fail_valet("valet_no_road", true)
        return
    end

    local vehicle = CreateVehicle(
        model,
        spawn_coords.x,
        spawn_coords.y,
        spawn_coords.z,
        spawn_heading,
        true,
        true
    )
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        SetModelAsNoLongerNeeded(model)
        SetModelAsNoLongerNeeded(driver_model)
        fail_valet("valet_spawn_failed", true)
        return
    end
    current_valet.vehicle = vehicle
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    apply_vehicle_properties(vehicle, order.vehicle.properties, order.vehicle)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleDoorsLocked(vehicle, 2)
    SetVehicleEngineOn(vehicle, true, true, false)
    local network_id = NetworkGetNetworkIdFromEntity(vehicle)
    SetNetworkIdCanMigrate(network_id, true)

    local driver = CreatePedInsideVehicle(vehicle, 26, driver_model, -1, true, true)
    if driver == 0 or not DoesEntityExist(driver) then
        SetModelAsNoLongerNeeded(model)
        SetModelAsNoLongerNeeded(driver_model)
        fail_valet("valet_spawn_failed", true)
        return
    end
    current_valet.driver = driver
    SetEntityAsMissionEntity(driver, true, true)
    SetBlockingOfNonTemporaryEvents(driver, true)
    SetPedKeepTask(driver, true)
    SetDriverAbility(driver, 1.0)
    SetDriverAggressiveness(driver, 0.0)
    SetModelAsNoLongerNeeded(model)
    SetModelAsNoLongerNeeded(driver_model)

    current_valet.blip = AddBlipForEntity(vehicle)
    SetBlipSprite(current_valet.blip, 225)
    SetBlipColour(current_valet.blip, 3)
    SetBlipRoute(current_valet.blip, true)
    current_valet.status = "en_route"
    current_valet.can_cancel = true
    update_drive_target(driver, vehicle)
    send_valet_state()

    local timeout = GetGameTimer() + (Config.Garage.Valet.TimeoutSeconds * 1000)
    local next_retask = GetGameTimer() + 8000
    while current_valet and not current_valet.cancelled and GetGameTimer() < timeout do
        if not DoesEntityExist(vehicle)
            or not DoesEntityExist(driver)
            or IsEntityDead(driver)
            or not IsVehicleDriveable(vehicle, false)
        then
            fail_valet("valet_interrupted", true)
            return
        end
        player_coords = GetEntityCoords(PlayerPedId())
        local vehicle_coords = GetEntityCoords(vehicle)
        local distance = #(vehicle_coords - player_coords)
        current_valet.distance = math.floor(distance + 0.5)
        current_valet.eta_seconds = math.max(1, math.ceil(distance / math.max(1.0, Config.Garage.Valet.DriveSpeed)))
        if distance <= Config.Garage.Valet.ArrivalDistance then
            break
        end
        if GetGameTimer() >= next_retask then
            update_drive_target(driver, vehicle)
            next_retask = GetGameTimer() + 8000
        end
        send_valet_state()
        Wait(750)
    end
    if not current_valet or current_valet.cancelled then
        return
    end
    if GetGameTimer() >= timeout then
        fail_valet("valet_timeout", true)
        return
    end

    current_valet.status = "arriving"
    current_valet.can_cancel = false
    current_valet.distance = 0
    current_valet.eta_seconds = 0
    send_valet_state()
    TaskVehicleTempAction(driver, vehicle, 27, 1800)
    Wait(1800)
    SetVehicleEngineOn(vehicle, false, true, true)
    SetVehicleDoorsLocked(vehicle, 1)
    TaskLeaveVehicle(driver, vehicle, 0)

    local leave_timeout = GetGameTimer() + 5000
    while IsPedInVehicle(driver, vehicle, false) and GetGameTimer() < leave_timeout do
        Wait(100)
    end
    local driver_target = GetOffsetFromEntityInWorldCoords(vehicle, 4.0, 8.0, 0.0)
    TaskGoStraightToCoord(
        driver,
        driver_target.x,
        driver_target.y,
        driver_target.z,
        1.0,
        10000,
        GetEntityHeading(driver),
        0.5
    )
    SetPedKeepTask(driver, true)
    SetEntityAsNoLongerNeeded(driver)
    current_valet.driver = nil

    local completion = Bridge.Callbacks.Trigger(
        "sky_phone:garage:valet-complete",
        {
            orderId = current_valet.order_id,
            networkId = NetworkGetNetworkIdFromEntity(vehicle),
        }
    )
    if not completion or not completion.success then
        fail_valet("valet_completion_failed", false)
        return
    end
    remove_valet_blip()
    SetEntityAsNoLongerNeeded(vehicle)
    current_valet.vehicle = nil
    current_valet.status = "delivered"
    current_valet.can_cancel = false
    send_valet_state()
    local locale = garage_locale()
    Bridge.Framework.Notify(locale.name, locale.valetDelivered, "success", 5000)
    local completed_order_id = current_valet.order_id
    SetTimeout(12000, function()
        if current_valet and current_valet.order_id == completed_order_id then
            current_valet = nil
            send_valet_state()
        end
    end)
end

RegisterNUICallback("garage:valet-request", function(data, cb)
    if current_valet then
        cb({ success = false, error = "valet_active" })
        return
    end
    local result = Bridge.Callbacks.Trigger("sky_phone:garage:valet-request", data)
    if not result or not result.success or type(result.data) ~= "table" then
        cb(result or { success = false, error = "request_failed" })
        return
    end
    local vehicle = result.data.vehicle
    local model_hash = tonumber(vehicle.model)
    if not model_hash and type(vehicle.model) == "string" then
        model_hash = joaat(vehicle.model)
    end
    local display_name = model_hash and GetDisplayNameFromVehicleModel(model_hash) or nil
    local label = display_name and GetLabelText(display_name) or nil
    current_valet = {
        can_cancel = false,
        cancelled = false,
        cost = result.data.cost,
        distance = nil,
        eta_seconds = nil,
        order_id = result.data.orderId,
        plate = vehicle.plate,
        status = "ordering",
        vehicle_name = label and label ~= "NULL" and label ~= "CARNOTFOUND"
            and label
            or tostring(vehicle.model),
    }
    cb({ success = true, data = public_valet_state() })
    send_valet_state()
    CreateThread(function()
        run_valet_delivery(result.data)
    end)
end)

RegisterNUICallback("garage:valet-cancel", function(_, cb)
    if not current_valet or not current_valet.can_cancel then
        cb({ success = false, error = "valet_not_cancellable" })
        return
    end
    local order_id = current_valet.order_id
    local result = Bridge.Callbacks.Trigger("sky_phone:garage:valet-cancel", { orderId = order_id })
    if not result or not result.success then
        cb(result or { success = false, error = "request_failed" })
        return
    end
    current_valet.cancelled = true
    delete_valet_entities()
    current_valet.status = "cancelled"
    current_valet.can_cancel = false
    send_valet_state()
    cb({ success = true, data = public_valet_state() })
    SetTimeout(5000, function()
        if current_valet and current_valet.order_id == order_id then
            current_valet = nil
            send_valet_state()
        end
    end)
end)

RegisterNUICallback("garage:valet-state", function(_, cb)
    cb({ success = true, data = public_valet_state() })
end)

RegisterNetEvent("sky_phone:garage:valet-aborted", function(error_code)
    if current_valet then
        fail_valet(error_code or "valet_timeout", false)
    end
end)

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name ~= GetCurrentResourceName() or not current_valet then
        return
    end
    delete_valet_entities()
end)
