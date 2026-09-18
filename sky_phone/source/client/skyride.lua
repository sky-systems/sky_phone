local server_callbacks = {
    "skyride:bootstrap",
    "skyride:update-profile",
    "skyride:quote",
    "skyride:request",
    "skyride:set-driver-status",
    "skyride:accept",
    "skyride:arrive",
    "skyride:start",
    "skyride:complete",
    "skyride:cancel",
    "skyride:rate",
    "skyride:history",
}

local function normalize_person(person)
    if type(person) ~= "table" then
        return
    end
    if person.avatarUrl == false then
        person.avatarUrl = json.null
    end
end

local function normalize_ride(ride)
    if type(ride) ~= "table" then
        return
    end
    normalize_person(ride.passenger)
    if ride.driver == false then
        ride.driver = json.null
        return
    end
    if type(ride.driver) ~= "table" then
        return
    end
    normalize_person(ride.driver)
    local vehicle = ride.driver.vehicle
    local model_hash = type(vehicle) == "table" and tonumber(vehicle.model) or nil
    if not model_hash then
        return
    end
    local display_name = GetDisplayNameFromVehicleModel(model_hash)
    local label = display_name and GetLabelText(display_name) or nil
    if label and label ~= "NULL" and label ~= "CARNOTFOUND" then
        vehicle.model = label
    end
end

local function normalize_rides(rides)
    if type(rides) ~= "table" then
        return
    end
    for index = 1, #rides do
        normalize_ride(rides[index])
    end
end

local function normalize_state(data)
    if type(data) ~= "table" then
        return
    end
    if data.activeRide == false then
        data.activeRide = json.null
    else
        normalize_ride(data.activeRide)
    end
    if data.pendingRating == false then
        data.pendingRating = json.null
    else
        normalize_ride(data.pendingRating)
    end
    normalize_rides(data.availableRequests)
    normalize_rides(data.history)
    normalize_rides(data.items)
    if type(data.profile) == "table" then
        if data.profile.acceptanceRate == false then
            data.profile.acceptanceRate = json.null
        end
        if data.profile.avatarUrl == false then
            data.profile.avatarUrl = json.null
        end
        if data.profile.avatarMediaId == false then
            data.profile.avatarMediaId = json.null
        end
        if data.profile.earningsToday == false then
            data.profile.earningsToday = json.null
        end
    end
end

for index = 1, #server_callbacks do
    local callback_name = server_callbacks[index]
    RegisterNUICallback(callback_name, function(data, cb)
        if type(data) ~= "table" then
            cb({ success = false, error = "invalid_request" })
            return
        end
        local result = Bridge.Callbacks.Trigger("sky_phone:" .. callback_name, data)
        if not result then
            cb({ success = false, error = "request_failed" })
            return
        end
        if result.success and type(result.data) == "table" then
            normalize_state(result.data)
        end
        cb(result)
    end)
end

RegisterNetEvent("sky_phone:skyride:changed", function(data)
    normalize_state(data)
    SendNUIMessage({ type = "skyride:changed", data = data })
end)
