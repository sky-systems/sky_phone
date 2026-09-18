local cases = {
    { "qb", "qb-vehiclekeys", "server", "GiveKeys", { 7, "KEY123" } },
    { "qbox", "qbx_vehiclekeys", "server", "GiveKeys", { 7, 101, true } },
    { "kiminaze", "VehicleKeyChain", "server", "AddTempKey", { 7, "KEY123" } },
    { "vehicles_keys", "vehicles_keys", "server", "giveVehicleKeysToPlayerId", { 7, "KEY123", "temporary" } },
    { "ak47", "ak47_vehiclekeys", "client", "GiveKey", { "KEY123", false } },
    { "ak47", "ak47_qb_vehiclekeys", "client", "GiveKey", { "KEY123", false } },
    { "brutal", "brutal_keys", "client", "addVehicleKey", { "KEY123", "KEY123" } },
    { "ic3d", "ic3d_vehiclekeys", "client", "ClientInventoryKeys", { "add", "KEY123" } },
    { "jc", "jc_vehiclekeys", "client", "GiveKeys", { "KEY123" } },
    { "jota", "jc_vehiclekeys", "client", "GiveKeys", { "KEY123" } },
    { "mk", "mk_vehiclekeys", "client", "AddKey", { 202 } },
    { "mrnewb", "MrNewbVehicleKeys", "client", "GiveKeys", { 202 } },
    { "msk", "msk_vehiclekeys", "client", "AddKey", { 202, "temporary" } },
    { "quasar", "qs-vehiclekeys", "client", "GiveKeys", { "KEY123", "SULTAN", true } },
    { "wasabi", "wasabi_carlock", "client", "GiveKey", { "KEY123" } },
    { "zyke_garages", "zyke_garages", "client", "GiveKey", { 202 } },
}

local function environment(side, resources, exports)
    local env = setmetatable({
        Bridge = { Debug = function() end },
        Config = { Garage = { VehicleKeySystem = "auto" } },
        GetResourceState = function(name) return resources[name] or "missing" end,
        DoesEntityExist = function(entity) return entity == 202 and 1 or nil end,
        GetEntityModel = function(entity) assert(entity == 202) return 970598228 end,
        GetDisplayNameFromVehicleModel = function(model) assert(model == 970598228) return "SULTAN" end,
        exports = exports or {},
    }, { __index = _G })
    assert(loadfile("sky_phone/source/bridge/" .. side .. "/vehiclekeys.lua", "t", env))()
    return env
end

for _, case in ipairs(cases) do
    local name, resource, side, export_name, arguments = table.unpack(case)
    local calls = 0
    local resources = { [resource] = "started" }
    local api = { [resource] = { [export_name] = function(_, ...)
        local actual = table.pack(...)
        assert(actual.n == #arguments, name .. ": argument count")
        for index, expected in ipairs(arguments) do
            assert(actual[index] == expected, name .. ": argument " .. index)
        end
        calls = calls + 1
        -- Nil is a valid return contract for several providers.
    end } }
    local server = environment("server", resources, side == "server" and api or {})
    server.Config.Garage.VehicleKeySystem = name
    assert(server.Bridge.VehicleKeys.IsSupported(name))
    local provider = assert(server.Bridge.VehicleKeys.ResolveProvider())
    assert(provider.side == side and provider.resource == resource)
    local success, grant = server.Bridge.VehicleKeys.GiveKeys(7, 101, "KEY123", provider)
    assert(success)
    if side == "client" then
        assert(calls == 0 and grant.plate == "KEY123")
        local client = environment("client", resources, api)
        assert(client.Bridge.VehicleKeys.GiveKeys(202, grant))
        assert(not client.Bridge.VehicleKeys.GiveKeys(0, grant))
    else
        assert(grant == nil)
    end
    assert(calls == 1, name .. ": one export call on the correct side")
    server.Config.Garage.VehicleKeySystem = "auto"
    assert(server.Bridge.VehicleKeys.ResolveProvider().resource == resource)
    resources[resource] = "stopped"
    assert(not server.Bridge.VehicleKeys.GiveKeys(7, 101, "KEY123", provider))
    assert(server.Bridge.VehicleKeys.ResolveProvider().name == "none")
    resources[resource] = "started"
    assert(server.Bridge.VehicleKeys.ResolveProvider().resource == resource)
end

local resources = { ["qb-vehiclekeys"] = "started", qbx_vehiclekeys = "started", msk_vehiclekeys = "started" }
local server = environment("server", resources)
assert(server.Bridge.VehicleKeys.ResolveProvider().name == "qbox")
server.Config.Garage.VehicleKeySystem = "msk"
assert(server.Bridge.VehicleKeys.ResolveProvider().name == "msk", "explicit provider wins")
server.Config.Garage.VehicleKeySystem = "none"
assert(server.Bridge.VehicleKeys.GiveKeys(7, 101, "KEY123", server.Bridge.VehicleKeys.ResolveProvider()))
server.Config.Garage.VehicleKeySystem = "unknown"
assert(not server.Bridge.VehicleKeys.ResolveProvider())
assert(not server.Bridge.VehicleKeys.IsSupported("unknown"))
server.Config.Garage.VehicleKeySystem = "custom_server"
assert(not server.Bridge.VehicleKeys.GiveKeys(7, 101, "KEY123", server.Bridge.VehicleKeys.ResolveProvider()))

local client = environment("client", resources)
assert(client.Bridge.VehicleKeys.GiveKeys(202, nil), "none must be a no-op")
assert(not client.Bridge.VehicleKeys.GiveKeys(202, { name = "qb", resource = "qb-vehiclekeys", plate = "KEY123" }))
assert(not client.Bridge.VehicleKeys.GiveKeys(202, { name = "msk", resource = "other_resource", plate = "KEY123" }))

print("Vehicle keys bridge tests passed (16 export contracts, detection, restarts and failure paths)")
