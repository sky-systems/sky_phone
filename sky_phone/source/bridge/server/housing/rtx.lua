local provider_name = "rtx"
local resource_name = "rtx_housing"

local function provider_call(export_name, callback)
    local success, result = pcall(callback)
    if not success then
        Bridge.Debug(
            "error",
            "[sky_phone] %s:%s failed: %s",
            resource_name,
            export_name,
            tostring(result)
        )
        return false, nil
    end
    return true, result
end

local function normalize_property_id(value)
    local number = Bridge.Normalize.FiniteNumber(value)
    if not number or number < 1 or number ~= math.floor(number) then
        return nil, nil
    end
    local integer = math.tointeger(number)
    if not integer then
        return nil, nil
    end
    return integer, tostring(integer)
end

local function decode_table(value)
    local value_type = type(value)
    if value_type == "table" or value_type == "vector3" or value_type == "vector4" then
        return value
    end
    if value_type ~= "string" or value == "" then
        return nil
    end
    local success, decoded = pcall(json.decode, value)
    return success and type(decoded) == "table" and decoded or nil
end

local function normalized_coords(value)
    local coords = Bridge.Normalize.Coordinates(value)
    if not coords then
        return nil
    end
    if math.abs(coords.x) < 0.001 and math.abs(coords.y) < 0.001 and math.abs(coords.z) < 0.001 then
        return nil
    end
    return coords
end

local function nested_coords(value)
    local data = decode_table(value)
    if not data then
        return nil
    end
    return normalized_coords(data.coords) or normalized_coords(data)
end

local function property_zone_coords(property)
    local zone = decode_table(property.propertyzone)
    local points = zone and decode_table(zone.polyzonedata) or nil
    if not points then
        return nil
    end

    local count = 0
    local x_total = 0.0
    local y_total = 0.0
    local z_total = 0.0
    local z_count = 0
    for _, point in pairs(points) do
        local point_type = type(point)
        if point_type == "table" or point_type == "vector3" or point_type == "vector4" then
            local x = Bridge.Normalize.FiniteNumber(point.x)
            local y = Bridge.Normalize.FiniteNumber(point.y)
            local z = Bridge.Normalize.FiniteNumber(point.z)
            if x and y then
                count = count + 1
                x_total = x_total + x
                y_total = y_total + y
                if z then
                    z_count = z_count + 1
                    z_total = z_total + z
                end
            end
        end
    end
    if count == 0 then
        return nil
    end

    local z = z_count > 0 and z_total / z_count or nil
    if not z then
        local minimum_z = Bridge.Normalize.FiniteNumber(zone.minz)
        local maximum_z = Bridge.Normalize.FiniteNumber(zone.maxz)
        if minimum_z and maximum_z then
            z = (minimum_z + maximum_z) / 2.0
        end
    end
    return normalized_coords({
        x = x_total / count,
        y = y_total / count,
        z = z,
    })
end

local function property_entrance(property)
    local coords = nested_coords(property.enter)
        or nested_coords(property.sellsign)
    if coords then
        return coords
    end

    local doors = decode_table(property.doors)
    if doors then
        for _, door in pairs(doors) do
            local door_data = decode_table(door)
            coords = door_data and nested_coords(door_data.door1) or nil
            if coords then
                return coords
            end
        end
    end

    coords = nested_coords(property.garage)
    return coords or property_zone_coords(property)
end

local function property_identifier(property, fallback)
    local value = type(property) == "table"
        and (property.houseid or property.id or property.propertyid)
        or nil
    return normalize_property_id(value or fallback)
end

local function get_all_properties()
    local success, properties = provider_call("GetAllProperties", function()
        return exports[resource_name]:GetAllProperties()
    end)
    if not success then
        return nil, "provider_error"
    end
    if type(properties) ~= "table" then
        Bridge.Debug("error", "[sky_phone] %s:GetAllProperties returned invalid data.", resource_name)
        return nil, "provider_error"
    end
    return properties
end

local function get_owned_properties(source)
    local success, properties = provider_call("GetPlayerOwnedProperties", function()
        return exports[resource_name]:GetPlayerOwnedProperties(source)
    end)
    if not success then
        return nil, "provider_error"
    end
    if type(properties) ~= "table" then
        Bridge.Debug("error", "[sky_phone] %s:GetPlayerOwnedProperties returned invalid data.", resource_name)
        return nil, "provider_error"
    end
    return properties
end

local function get_property(property_id)
    local success, property = provider_call("GetPropertyData", function()
        return exports[resource_name]:GetPropertyData(property_id)
    end)
    if not success then
        return nil, "provider_error"
    end
    if property == nil then
        return nil, "property_not_found"
    end
    if type(property) ~= "table" then
        Bridge.Debug("error", "[sky_phone] %s:GetPropertyData returned invalid data.", resource_name)
        return nil, "provider_error"
    end
    return property
end

local function boolean_export(export_name, callback)
    local success, value = provider_call(export_name, callback)
    if not success then
        return nil, "provider_error"
    end
    if type(value) ~= "boolean" then
        Bridge.Debug("error", "[sky_phone] %s:%s returned a non-boolean value.", resource_name, export_name)
        return nil, "provider_error"
    end
    return value
end

local function lock_status(property_id)
    return boolean_export("GetPropertyLockStatus", function()
        return exports[resource_name]:GetPropertyLockStatus(property_id)
    end)
end

local function collect_catalog(catalog, properties)
    local is_array = #properties > 0
    for key, property in pairs(properties) do
        if type(property) == "table" then
            local property_id, id_key = property_identifier(property, is_array and nil or key)
            if property_id then
                catalog[id_key] = {
                    id = property_id,
                    property = property,
                }
            end
        end
    end
end

local function collect_owned(properties, catalog)
    local owned = {}
    local is_array = #properties > 0
    for key, value in pairs(properties) do
        local property = type(value) == "table" and value or nil
        local fallback = property and (is_array and nil or key)
            or (is_array and value or key)
        local property_id, id_key = property_identifier(property, fallback)
        if property_id then
            owned[id_key] = property_id
            if catalog and property then
                catalog[id_key] = {
                    id = property_id,
                    property = property,
                }
            end
        end
    end
    return owned
end

local function property_access(source, property, property_id, id_key, owned, identifier)
    if owned[id_key] then
        return "owner"
    end
    local owner = property.owner or property.Owner
    if identifier and owner ~= nil and tostring(owner) == tostring(identifier) then
        return "owner"
    end

    local has_keys, error_code = boolean_export("CheckPropertyKeys", function()
        return exports[resource_name]:CheckPropertyKeys(source, property_id)
    end)
    if has_keys == nil then
        return nil, error_code
    end
    if has_keys then
        return "keyholder"
    end

    local has_permissions
    has_permissions, error_code = boolean_export("HasPlayerAnyPropertyPermissions", function()
        return exports[resource_name]:HasPlayerAnyPropertyPermissions(source, property_id)
    end)
    if has_permissions == nil then
        return nil, error_code
    end
    return has_permissions and "keyholder" or nil
end

local function can_control_lock(source, property_id, access)
    if access == "owner" then
        return true
    end
    return boolean_export("GetPropertyPermission", function()
        return exports[resource_name]:GetPropertyPermission(source, property_id, "unlocking")
    end)
end

local function property_name(property, id_key)
    local name = property.propertyname or property.name
    if type(name) == "string" and name ~= "" then
        return name
    end
    local address = property.adress or property.address
    if type(address) == "string" and address ~= "" then
        return address
    end
    return ("Property %s"):format(id_key)
end

local function normalized_property(property, property_id, id_key, access, coords, locked, can_lock)
    return {
        id = ("%s:%s"):format(provider_name, id_key),
        providerId = id_key,
        name = property_name(property, id_key),
        access = access,
        locked = locked,
        entrance = coords,
        capabilities = {
            lock = can_lock == true,
            keys = false,
            waypoint = true,
            cctv = false,
            garageStatus = false,
        },
        cctv = { enabled = false },
        garage = nil,
        keys = nil,
    }
end

local function actor_access(source, property, property_id, id_key)
    local owned_properties, error_code = get_owned_properties(source)
    if not owned_properties then
        return nil, nil, error_code
    end
    local owned = collect_owned(owned_properties)
    local identifier = Bridge.Framework.GetIdentifier(source)
    local access
    access, error_code = property_access(
        source,
        property,
        property_id,
        id_key,
        owned,
        identifier
    )
    if error_code then
        return nil, nil, error_code
    end
    if not access then
        return nil, nil, "property_access_denied"
    end
    local can_lock
    can_lock, error_code = can_control_lock(source, property_id, access)
    if can_lock == nil then
        return nil, nil, error_code
    end
    return access, can_lock
end

local function resolve_property(source, data)
    if type(data) ~= "table" or type(data.propertyId) ~= "string" then
        return nil, nil, nil, nil, nil, "invalid_request"
    end
    local raw_id = data.propertyId:match("^rtx:(%d+)$")
    local property_id, id_key = normalize_property_id(raw_id)
    if not property_id then
        return nil, nil, nil, nil, nil, "invalid_property"
    end

    local property, error_code = get_property(property_id)
    if not property then
        return nil, nil, nil, nil, nil, error_code
    end
    local access, can_lock
    access, can_lock, error_code = actor_access(source, property, property_id, id_key)
    if not access then
        return nil, nil, nil, nil, nil, error_code
    end
    local coords = property_entrance(property)
    if not coords then
        return nil, nil, nil, nil, nil, "invalid_coordinates"
    end
    return property, property_id, id_key, access, can_lock, nil, coords
end

Bridge.Housing.RegisterProvider(provider_name, {
    resource_name = resource_name,
    is_available = function()
        return GetResourceState(resource_name) == "started"
    end,
    get_overview = function(source)
        local properties, error_code = get_all_properties()
        if not properties then
            return nil, error_code
        end
        local owned_properties
        owned_properties, error_code = get_owned_properties(source)
        if not owned_properties then
            return nil, error_code
        end

        local catalog = {}
        collect_catalog(catalog, properties)
        local owned = collect_owned(owned_properties, catalog)
        for id_key, property_id in pairs(owned) do
            if not catalog[id_key] then
                local property
                property, error_code = get_property(property_id)
                if not property then
                    return nil, error_code
                end
                catalog[id_key] = { id = property_id, property = property }
            end
        end

        local identifier = Bridge.Framework.GetIdentifier(source)
        local result = {}
        for id_key, entry in pairs(catalog) do
            local access
            access, error_code = property_access(
                source,
                entry.property,
                entry.id,
                id_key,
                owned,
                identifier
            )
            if error_code then
                return nil, error_code
            end
            if access then
                local coords = property_entrance(entry.property)
                if coords then
                    local locked
                    locked, error_code = lock_status(entry.id)
                    if locked == nil then
                        return nil, error_code
                    end
                    local can_lock
                    can_lock, error_code = can_control_lock(source, entry.id, access)
                    if can_lock == nil then
                        return nil, error_code
                    end
                    result[#result + 1] = normalized_property(
                        entry.property,
                        entry.id,
                        id_key,
                        access,
                        coords,
                        locked,
                        can_lock
                    )
                else
                    Bridge.Debug(
                        "debug",
                        "[sky_phone] Ignored RTX property '%s' because no valid entrance was found.",
                        id_key
                    )
                end
            end
        end

        table.sort(result, function(left, right)
            if left.access ~= right.access then
                return left.access == "owner"
            end
            return string.lower(left.name) < string.lower(right.name)
        end)

        local maximum = math.max(0, math.floor(tonumber(Config.Housing.MaximumProperties) or 50))
        local limited = {}
        for index = 1, math.min(#result, maximum) do
            limited[index] = result[index]
        end
        return limited
    end,
    prepare = function(source, action, data)
        local property, property_id, id_key, access, can_lock, error_code, coords =
            resolve_property(source, data)
        if not property then
            return nil, error_code
        end

        if action == "set_waypoint" then
            return { coords = coords }
        end
        if action == "toggle_lock" then
            if not can_lock then
                return nil, "property_access_denied"
            end
            return { providerId = id_key }
        end
        if action == "key_candidates" or action == "grant_key" or action == "revoke_key" then
            return nil, "capability_unavailable"
        end
        if action == "open_cctv" then
            return nil, "cctv_unavailable"
        end
        return nil, "invalid_action"
    end,
})

local function execute_lock_action(source, data)
    if not SkyPhone.AllowOperation(source, "housing_rtx_action", Config.Housing.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end
    if type(data) ~= "table" or data.action ~= "toggle_lock" then
        return { success = false, error = "invalid_action" }
    end
    if GetResourceState(resource_name) ~= "started" then
        return { success = false, error = "provider_unavailable" }
    end

    local property_id, id_key = normalize_property_id(data.providerId)
    if not property_id then
        return { success = false, error = "invalid_property" }
    end
    local property, error_code = get_property(property_id)
    if not property then
        return { success = false, error = error_code }
    end

    local access, can_lock
    access, can_lock, error_code = actor_access(source, property, property_id, id_key)
    if not access then
        return { success = false, error = error_code }
    end
    if not can_lock then
        return { success = false, error = "property_access_denied" }
    end

    local current
    current, error_code = lock_status(property_id)
    if current == nil then
        return { success = false, error = error_code }
    end
    local requested = not current
    local setter_success = provider_call("SetPropertyLockStatus", function()
        return exports[resource_name]:SetPropertyLockStatus(property_id, requested)
    end)
    if not setter_success then
        return { success = false, error = "provider_error" }
    end

    local verified
    verified, error_code = lock_status(property_id)
    if verified == nil then
        return { success = false, error = error_code }
    end
    if verified ~= requested then
        Bridge.Debug(
            "error",
            "[sky_phone] %s lock update verification failed for property %s.",
            resource_name,
            id_key
        )
        return { success = false, error = "action_failed" }
    end
    return { success = true }
end

Bridge.Callbacks.Register("sky_phone:housing:rtx:execute", function(source, data)
    return execute_lock_action(source, data)
end)
