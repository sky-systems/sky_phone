Bridge.VehicleKeys = {}

-- Order decides automatic detection. Only one provider handles each delivery.
local providers = {
    { name = "qbox", side = "server", resources = { "qbx_vehiclekeys" } },
    { name = "qb", side = "server", resources = { "qb-vehiclekeys" } },
    { name = "quasar", side = "client", resources = { "qs-vehiclekeys" } },
    { name = "mrnewb", side = "client", resources = { "MrNewbVehicleKeys" } },
    { name = "mk", side = "client", resources = { "mk_vehiclekeys" } },
    { name = "wasabi", side = "client", resources = { "wasabi_carlock" } },
    { name = "msk", side = "client", resources = { "msk_vehiclekeys" } },
    { name = "brutal", side = "client", resources = { "brutal_keys" } },
    { name = "vehicles_keys", side = "server", resources = { "vehicles_keys" } },
    { name = "ak47", side = "client", resources = { "ak47_qb_vehiclekeys", "ak47_vehiclekeys" } },
    { name = "jc", side = "client", resources = { "jc_vehiclekeys" } },
    { name = "kiminaze", side = "server", resources = { "VehicleKeyChain" } },
    { name = "ic3d", side = "client", resources = { "ic3d_vehiclekeys" } },
    { name = "zyke_garages", side = "client", resources = { "zyke_garages" } },
}

local handlers = {
    qb = function(source, vehicle, plate)
        return exports["qb-vehiclekeys"]:GiveKeys(source, plate)
    end,
    qbox = function(source, vehicle)
        return exports["qbx_vehiclekeys"]:GiveKeys(source, vehicle, true)
    end,
    kiminaze = function(source, vehicle, plate)
        return exports["VehicleKeyChain"]:AddTempKey(source, plate)
    end,
    vehicles_keys = function(source, vehicle, plate)
        return exports["vehicles_keys"]:giveVehicleKeysToPlayerId(source, plate, "temporary")
    end,
    custom_server = function(source, vehicle, plate)
        error("Custom vehicle keys integration: implement the server export in bridge/server/vehiclekeys.lua")
    end,
}

function Bridge.VehicleKeys.IsSupported(name)
    if name == "auto" or name == "none" or name == "jota"
        or name == "custom_client" or name == "custom_server" then
        return true
    end
    for _, provider in ipairs(providers) do
        if provider.name == name then return true end
    end
    return false
end

function Bridge.VehicleKeys.ResolveProvider()
    local configured = Config.Garage.VehicleKeySystem or "auto"
    if configured == "none" then return { name = "none" } end
    if configured == "custom_client" or configured == "custom_server" then
        return { name = configured, side = configured == "custom_client" and "client" or "server" }
    end
    if configured == "jota" then configured = "jc" end
    for _, provider in ipairs(providers) do
        if configured == "auto" or configured == provider.name then
            for _, resource in ipairs(provider.resources) do
                if GetResourceState(resource) == "started" then
                    return { name = provider.name, side = provider.side, resource = resource }
                end
            end
        end
    end
    if configured == "auto" then return { name = "none" } end
    Bridge.Debug("error", "[sky_phone] Vehicle keys provider '%s' is unsupported or unavailable.", tostring(configured))
    return nil
end

-- Called only after the garage has verified the order and delivered vehicle.
-- Client providers are returned to that player's existing completion callback.
function Bridge.VehicleKeys.GiveKeys(source, vehicle, plate, provider)
    if provider.name == "none" then return true end
    if provider.resource and GetResourceState(provider.resource) ~= "started" then
        Bridge.Debug("error", "[sky_phone] Vehicle keys resource '%s' stopped before delivery.", provider.resource)
        return false
    end
    if provider.side == "client" then
        return true, { name = provider.name, resource = provider.resource, plate = plate }
    end
    local handler = handlers[provider.name]
    if not handler then return false end
    local success, result = pcall(handler, source, vehicle, plate)
    if not success or result == false then
        Bridge.Debug("error", "[sky_phone] Vehicle keys provider '%s' failed to give keys: %s",
            provider.name, tostring(result))
        return false
    end
    return true
end
