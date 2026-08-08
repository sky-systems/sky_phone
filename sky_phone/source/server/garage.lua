Bridge.Database.AfterMigration("sky_phone", function()

local supported_systems = {
    auto = true,
    custom = true,
    esx = true,
    qb = true,
    qbox = true,
    ak47 = true,
    bp = true,
    cd = true,
    codem = true,
    ["ds-servercreator"] = true,
    hex = true,
    jg = true,
    my = true,
    okok = true,
    op = true,
    quasar = true,
    rx = true,
    vms = true,
    ws = true,
    zyke_garages = true,
}

local function decode_object(value)
    if type(value) == "table" then
        return value
    end
    if type(value) ~= "string" or value == "" then
        return {}
    end
    local success, decoded = pcall(json.decode, value)
    if not success or type(decoded) ~= "table" then
        return {}
    end
    return decoded
end

local function first_value(...)
    local values = { ... }
    for index = 1, #values do
        local value = values[index]
        if value ~= nil and value ~= "" then
            return value
        end
    end
    return nil
end

local function truthy_database_value(value)
    return value == true or value == 1 or value == "1" or value == "true"
end

local function normalized_health(value, maximum)
    local number = tonumber(value)
    if not number then
        return nil
    end
    if maximum == 1000 then
        number = number / 10
    end
    return math.max(0, math.min(100, math.floor(number + 0.5)))
end

local function vehicle_status(row, location, garage_system)
    local state = tonumber(row.state)
    local location_key = string.lower(tostring(location or ""))
    if truthy_database_value(row.impound)
        or truthy_database_value(row.impounded)
        or truthy_database_value(row.pound)
        or location_key:find("impound", 1, true)
        or location_key:find("pound", 1, true)
    then
        return "impounded"
    end
    if garage_system == "jg" then
        return truthy_database_value(row.in_garage) and "garaged" or "out"
    end
    if state == 2 then
        return "impounded"
    end
    local stored = first_value(row.stored, row.in_garage, row.parked)
    if truthy_database_value(stored) or state == 1 then
        return "garaged"
    end
    return "out"
end

local function vehicle_kind(value)
    local kind = string.lower(tostring(value or ""))
    if kind == "boat" then
        return "boat"
    end
    if kind == "plane" or kind == "air" or kind == "airplane" then
        return "plane"
    end
    if kind == "heli" or kind == "helicopter" then
        return "helicopter"
    end
    if kind == "bike" or kind == "bicycle" or kind == "motorcycle" then
        return "bike"
    end
    return "car"
end

local function vehicle_properties(row)
    local properties = decode_object(first_value(row.mods, row.vehicle_data, row.properties))
    local vehicle_object = decode_object(row.vehicle)
    if next(vehicle_object) ~= nil then
        for key, value in pairs(vehicle_object) do
            if properties[key] == nil then
                properties[key] = value
            end
        end
    end
    return properties
end

local function vehicle_dto(row, garage_system)
    local mods = vehicle_properties(row)
    local vehicle_value = row.vehicle

    local model = first_value(row.model, row.hash, mods.model, mods.hash)
    if type(vehicle_value) == "string" and vehicle_value:sub(1, 1) ~= "{" then
        model = first_value(model, vehicle_value)
    elseif type(vehicle_value) == "number" then
        model = first_value(model, vehicle_value)
    end
    local numeric_model = tonumber(model)
    if numeric_model then
        model = numeric_model
    end

    local location = first_value(row.garage_id, row.parking, row.garage, row.parked_at)
    local plate = tostring(first_value(row.plate, mods.plate) or ""):match("^%s*(.-)%s*$")
    return {
        id = tostring(first_value(row.id, row.vin, plate)),
        plate = plate,
        vin = tostring(row.vin or ""),
        nickname = tostring(row.nickname or ""),
        model = model,
        kind = vehicle_kind(first_value(row.garage_type, row.type, mods.type)),
        status = vehicle_status(row, location, garage_system),
        location = tostring(location or ""),
        fuel = normalized_health(first_value(row.fuel, mods.fuelLevel, mods.fuel), 100),
        engine = normalized_health(first_value(row.engine, mods.engineHealth, mods.engine), 1000),
        body = normalized_health(first_value(row.body, mods.bodyHealth, mods.body), 1000),
    }
end

local function storage_config()
    local system = tostring(Config.Garage.System or "auto")
    if not supported_systems[system] then
        error(("[sky_phone] Unsupported garage system '%s'."):format(system))
    end
    if system == "custom" then
        local table_name = tostring(Config.Garage.Custom.Table or "")
        local owner_column = tostring(Config.Garage.Custom.OwnerColumn or "")
        if not table_name:match("^[%w_]+$") or not owner_column:match("^[%w_]+$") then
            error("[sky_phone] Custom garage table and owner column must be configured with SQL identifiers.")
        end
        return table_name, owner_column, system
    end
    if system == "esx" then
        return "owned_vehicles", "owner", system
    end
    if system == "qb" or system == "qbox" then
        return "player_vehicles", "citizenid", system
    end
    if system == "auto" and GetResourceState("jg-advancedgarages") == "started" then
        system = "jg"
    end
    if Bridge.Framework.GetName() == "esx" then
        return "owned_vehicles", "owner", system == "auto" and "esx" or system
    end
    return "player_vehicles", "citizenid", system == "auto" and Bridge.Framework.GetName() or system
end

local active_valets = {}
local valet_cooldowns = {}

local function normalized_plate(value)
    if type(value) ~= "string" then
        return nil
    end
    local plate = value:match("^%s*(.-)%s*$")
    if plate == "" or #plate > 16 or plate:find("[%c]") then
        return nil
    end
    return plate
end

local function owned_vehicle_row(identifier, plate)
    local table_name, owner_column, garage_system = storage_config()
    local rows = Bridge.Database.Query(
        ("SELECT * FROM %s WHERE %s = ? AND TRIM(plate) = ? LIMIT 1"):format(table_name, owner_column),
        { identifier, plate }
    )
    return rows[1], table_name, owner_column, garage_system
end

local function status_snapshot(row)
    local snapshot = {}
    for _, column in ipairs({ "stored", "state", "in_garage", "parked" }) do
        if row[column] ~= nil then
            snapshot[column] = row[column]
        end
    end
    return snapshot
end

local function write_vehicle_status(order, restore)
    local assignments = {}
    local parameters = {}
    for column, original_value in pairs(order.status) do
        assignments[#assignments + 1] = ("%s = ?"):format(column)
        parameters[#parameters + 1] = restore and original_value or 0
    end
    if #assignments == 0 then
        return false
    end
    parameters[#parameters + 1] = order.identifier
    parameters[#parameters + 1] = order.plate
    Bridge.Database.Query(
        ("UPDATE %s SET %s WHERE %s = ? AND TRIM(plate) = ?")
            :format(order.table_name, table.concat(assignments, ", "), order.owner_column),
        parameters
    )
    return true
end

local function refund_valet(source, order)
    if order.refunded then
        return
    end
    order.refunded = true
    if not Bridge.Framework.AddMoney(source, Config.Garage.Valet.Account, order.cost) then
        Bridge.Debug("error", "[sky_phone] Failed to refund valet order '%s' for player %s.", tostring(order.id), tostring(source))
        return
    end
    TriggerClientEvent("sky_phone:banking:changed", source)
end

local function cancel_valet(source, order)
    write_vehicle_status(order, true)
    refund_valet(source, order)
    active_valets[source] = nil
end

Bridge.Callbacks.Register("sky_phone:garage:valet-request", function(source, data)
    local valet = Config.Garage.Valet
    if not valet.Enabled then
        return { success = false, error = "valet_disabled" }
    end
    if not SkyPhone.AllowOperation(source, "garage_valet", valet.RequestsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end
    if active_valets[source] then
        return { success = false, error = "valet_active" }
    end
    local now = os.time()
    if (valet_cooldowns[source] or 0) > now then
        return {
            success = false,
            error = "valet_cooldown",
            data = { retryAfter = valet_cooldowns[source] - now },
        }
    end
    local plate = normalized_plate(data and data.plate)
    if not plate then
        return { success = false, error = "invalid_vehicle" }
    end
    local identifier = Bridge.Framework.GetIdentifier(source)
    if type(identifier) ~= "string" or identifier == "" then
        return { success = false, error = "garage_unavailable" }
    end
    local row, table_name, owner_column, garage_system = owned_vehicle_row(identifier, plate)
    if not row then
        return { success = false, error = "vehicle_not_owned" }
    end
    local vehicle = vehicle_dto(row, garage_system)
    if vehicle.status ~= "garaged" then
        return { success = false, error = "vehicle_not_garaged" }
    end
    if not valet.VehicleTypes[vehicle.kind] then
        return { success = false, error = "valet_vehicle_type" }
    end
    local price = math.max(0, math.floor(tonumber(valet.Price) or 0))
    local balance = tonumber(Bridge.Framework.GetMoney(source, valet.Account)) or 0
    if balance < price then
        return { success = false, error = "insufficient_funds" }
    end
    local order = {
        cost = price,
        expires_at = now + valet.TimeoutSeconds,
        identifier = identifier,
        id = ("%s:%s:%s"):format(source, now, math.random(100000, 999999)),
        owner_column = owner_column,
        plate = plate,
        status = status_snapshot(row),
        table_name = table_name,
    }
    if not write_vehicle_status(order, false) then
        return { success = false, error = "valet_status_unsupported" }
    end
    if price > 0 and not Bridge.Framework.RemoveMoney(source, valet.Account, price) then
        write_vehicle_status(order, true)
        return { success = false, error = "insufficient_funds" }
    end
    active_valets[source] = order
    TriggerClientEvent("sky_phone:banking:changed", source)
    return {
        success = true,
        data = {
            cost = price,
            driverModel = valet.DriverModel,
            orderId = order.id,
            vehicle = {
                body = vehicle.body,
                engine = vehicle.engine,
                fuel = vehicle.fuel,
                kind = vehicle.kind,
                model = vehicle.model,
                plate = vehicle.plate,
                properties = vehicle_properties(row),
            },
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:garage:valet-cancel", function(source, data)
    local order = active_valets[source]
    if not order or type(data) ~= "table" or data.orderId ~= order.id then
        return { success = false, error = "valet_not_found" }
    end
    cancel_valet(source, order)
    return { success = true, data = { refunded = order.cost } }
end)

Bridge.Callbacks.Register("sky_phone:garage:valet-complete", function(source, data)
    local order = active_valets[source]
    if not order or type(data) ~= "table" or data.orderId ~= order.id then
        return { success = false, error = "valet_not_found" }
    end

    local network_id = tonumber(data.networkId)
    if not network_id or network_id <= 0 or network_id ~= math.floor(network_id) then
        return { success = false, error = "valet_vehicle_unverified" }
    end
    local entity = NetworkGetEntityFromNetworkId(network_id)
    if entity == 0 or not DoesEntityExist(entity) or tonumber(NetworkGetEntityOwner(entity)) ~= source then
        return { success = false, error = "valet_vehicle_unverified" }
    end

    active_valets[source] = nil
    valet_cooldowns[source] = os.time() + Config.Garage.Valet.CooldownSeconds
    return { success = true }
end)

AddEventHandler("playerDropped", function()
    local source = source
    local order = active_valets[source]
    if order then
        cancel_valet(source, order)
    end
    valet_cooldowns[source] = nil
end)

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name ~= GetCurrentResourceName() then
        return
    end
    for source, order in pairs(active_valets) do
        cancel_valet(source, order)
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for source, order in pairs(active_valets) do
            if order.expires_at <= now then
                cancel_valet(source, order)
                TriggerClientEvent("sky_phone:garage:valet-aborted", source, "valet_timeout")
            end
        end
    end
end)

Bridge.Callbacks.Register("sky_phone:garage:vehicles", function(source)
    if not SkyPhone.AllowOperation(source, "garage_vehicles", Config.Garage.RequestsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end
    local identifier = Bridge.Framework.GetIdentifier(source)
    if type(identifier) ~= "string" or identifier == "" then
        return { success = false, error = "garage_unavailable" }
    end
    local table_name, owner_column, garage_system = storage_config()
    local rows = Bridge.Database.Query(
        ("SELECT * FROM `%s` WHERE `%s` = ? LIMIT ?"):format(table_name, owner_column),
        { identifier, Config.Garage.MaximumVehicles }
    )
    local vehicles = {}
    for _, row in ipairs(rows) do
        local vehicle = vehicle_dto(row, garage_system)
        if vehicle.plate ~= "" then
            vehicles[#vehicles + 1] = vehicle
        end
    end
    table.sort(vehicles, function(left, right)
        return left.plate < right.plate
    end)
    return {
        success = true,
        data = {
            system = garage_system,
            valet = {
                account = Config.Garage.Valet.Account,
                enabled = Config.Garage.Valet.Enabled,
                price = math.max(0, math.floor(tonumber(Config.Garage.Valet.Price) or 0)),
                vehicleTypes = Config.Garage.Valet.VehicleTypes,
            },
            vehicles = vehicles,
        },
    }
end)

end)
