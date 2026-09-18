Bridge.VehicleKeys = {}

local providers = {
    ak47 = {
        resources = { ak47_vehiclekeys = true, ak47_qb_vehiclekeys = true },
        give = function(resource, vehicle, plate) return exports[resource]:GiveKey(plate, false) end,
    },
    brutal = {
        resources = { brutal_keys = true },
        give = function(resource, vehicle, plate) return exports[resource]:addVehicleKey(plate, plate) end,
    },
    ic3d = {
        resources = { ic3d_vehiclekeys = true },
        give = function(resource, vehicle, plate) return exports[resource]:ClientInventoryKeys("add", plate) end,
    },
    jc = {
        resources = { jc_vehiclekeys = true },
        give = function(resource, vehicle, plate) return exports[resource]:GiveKeys(plate) end,
    },
    mk = {
        resources = { mk_vehiclekeys = true },
        give = function(resource, vehicle) return exports[resource]:AddKey(vehicle) end,
    },
    mrnewb = {
        resources = { MrNewbVehicleKeys = true },
        give = function(resource, vehicle) return exports[resource]:GiveKeys(vehicle) end,
    },
    msk = {
        resources = { msk_vehiclekeys = true },
        give = function(resource, vehicle) return exports[resource]:AddKey(vehicle, "temporary") end,
    },
    quasar = {
        resources = { ["qs-vehiclekeys"] = true },
        give = function(resource, vehicle, plate)
            local model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
            return exports[resource]:GiveKeys(plate, model, true)
        end,
    },
    wasabi = {
        resources = { wasabi_carlock = true },
        give = function(resource, vehicle, plate) return exports[resource]:GiveKey(plate) end,
    },
    zyke_garages = {
        resources = { zyke_garages = true },
        give = function(resource, vehicle) return exports[resource]:GiveKey(vehicle) end,
    },
    custom_client = {
        give = function(resource, vehicle, plate)
            error("Custom vehicle keys integration: implement the client export in bridge/client/vehiclekeys.lua")
        end,
    },
}

-- No public grant event: only the accepted garage completion calls this function.
function Bridge.VehicleKeys.GiveKeys(vehicle, grant)
    if not grant then return true end
    local provider = providers[grant.name]
    if not provider or not DoesEntityExist(vehicle) then return false end
    if provider.resources and (not provider.resources[grant.resource]
        or GetResourceState(grant.resource) ~= "started") then
        Bridge.Debug("error", "[sky_phone] Vehicle keys provider '%s' is unavailable.", grant.name)
        return false
    end
    local success, result = pcall(provider.give, grant.resource, vehicle, grant.plate)
    if not success or result == false then
        Bridge.Debug("error", "[sky_phone] Vehicle keys provider '%s' failed to give keys: %s",
            grant.name, tostring(result))
        return false
    end
    -- Existing key providers may complete without returning a value.
    return true
end
