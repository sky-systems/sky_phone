local provider_name = "vms"
local resource_name = "vms_housing"

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
    if type(value) == "number" then
        local number = Bridge.Normalize.FiniteNumber(value)
        if not number or number < 1 or number ~= math.floor(number) then
            return nil, nil
        end
        local integer = math.tointeger(number)
        return integer, integer and tostring(integer) or nil
    end
    if type(value) ~= "string" then
        return nil, nil
    end
    local normalized = value:match("^%s*(.-)%s*$")
    if normalized == "" or #normalized > 128 or normalized:find("%c") then
        return nil, nil
    end
    return normalized, normalized
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

local function property_identifier(property, fallback)
    local value = type(property) == "table"
        and (property.id or property.propertyId or property.property_id)
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

local function get_player_properties(source)
    local success, properties = provider_call("GetPlayerProperties", function()
        return exports[resource_name]:GetPlayerProperties(source)
    end)
    if not success then
        return nil, "provider_error"
    end
    if type(properties) ~= "table" then
        Bridge.Debug("error", "[sky_phone] %s:GetPlayerProperties returned invalid data.", resource_name)
        return nil, "provider_error"
    end
    return properties
end

local function get_property(property_id)
    local success, property = provider_call("GetProperty", function()
        return exports[resource_name]:GetProperty(property_id)
    end)
    if not success then
        return nil, "provider_error"
    end
    if property == nil then
        return nil, "property_not_found"
    end
    if type(property) ~= "table" then
        Bridge.Debug("error", "[sky_phone] %s:GetProperty returned invalid data.", resource_name)
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

local function collect_catalog(catalog, properties)
    local direct_id, direct_key = property_identifier(properties)
    if direct_id then
        catalog[direct_key] = { id = direct_id, property = properties }
        return
    end

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

local function collect_player_properties(properties, catalog)
    local direct = {}
    local direct_id, direct_key = property_identifier(properties)
    if direct_id then
        direct[direct_key] = direct_id
        if catalog then
            catalog[direct_key] = { id = direct_id, property = properties }
        end
        return direct
    end

    local is_array = #properties > 0
    for key, value in pairs(properties) do
        local property = type(value) == "table" and value or nil
        local fallback = property and (is_array and nil or key)
            or (is_array and value or key)
        local property_id, id_key = property_identifier(property, fallback)
        if property_id then
            direct[id_key] = property_id
            if catalog and property then
                catalog[id_key] = {
                    id = property_id,
                    property = property,
                }
            end
        end
    end
    return direct
end

local function identifiers_match(value, identifier)
    return identifier ~= nil
        and value ~= nil
        and tostring(value) ~= ""
        and tostring(value) == tostring(identifier)
end

local function property_access(source, property, property_id, id_key, direct, identifier)
    if identifiers_match(property.owner, identifier) then
        return "owner"
    end
    if identifiers_match(property.renter, identifier) or direct[id_key] then
        return "keyholder"
    end
    if not identifier then
        return nil
    end

    local has_keys, error_code = boolean_export("HasKeys", function()
        return exports[resource_name]:HasKeys(source, identifier, property_id)
    end)
    if has_keys == nil then
        return nil, error_code
    end
    if has_keys then
        return "keyholder"
    end

    local has_permissions
    has_permissions, error_code = boolean_export("HasAnyPermission", function()
        return exports[resource_name]:HasAnyPermission(property_id, identifier)
    end)
    if has_permissions == nil then
        return nil, error_code
    end
    return has_permissions and "keyholder" or nil
end

local function property_metadata(property)
    return decode_table(property.metadata) or {}
end

local function property_entrance(property, building_cache)
    local object_id = property.object_id
    if object_id ~= nil and tostring(object_id) ~= "" then
        local normalized_object_id, object_key = normalize_property_id(object_id)
        if normalized_object_id then
            local building = nil
            local cache_hit = building_cache and building_cache[object_key] ~= nil
            if cache_hit then
                building = building_cache[object_key]
            else
                local object, error_code = get_property(normalized_object_id)
                if not object and error_code ~= "property_not_found" then
                    return nil, error_code
                end
                building = object or false
                if building_cache then
                    building_cache[object_key] = building
                end
            end
            if type(building) == "table" and building.type == "building" then
                local coords = normalized_coords(property_metadata(building).enter)
                if coords then
                    return coords
                end
            end
        end
    end

    local metadata = property_metadata(property)
    return normalized_coords(metadata.enter) or normalized_coords(metadata.menu)
end

local function property_name(property, id_key)
    if type(property.name) == "string" and property.name ~= "" then
        return property.name
    end
    if type(property.address) == "string" and property.address ~= "" then
        return property.address
    end
    return ("Property %s"):format(id_key)
end

local function normalized_property(property, id_key, access, coords)
    local metadata = property_metadata(property)
    return {
        id = ("%s:%s"):format(provider_name, id_key),
        providerId = id_key,
        name = property_name(property, id_key),
        access = access,
        locked = metadata.locked == true,
        entrance = coords,
        capabilities = {
            lock = false,
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

local function resolve_property(source, data)
    if type(data) ~= "table" or type(data.propertyId) ~= "string" then
        return nil, nil, nil, nil, "invalid_request"
    end
    local raw_id = data.propertyId:match("^vms:(.+)$")
    local property_id, id_key = normalize_property_id(raw_id)
    if not property_id then
        return nil, nil, nil, nil, "invalid_property"
    end

    local property, error_code = get_property(property_id)
    if not property then
        return nil, nil, nil, nil, error_code
    end
    local player_properties
    player_properties, error_code = get_player_properties(source)
    if not player_properties then
        return nil, nil, nil, nil, error_code
    end
    local direct = collect_player_properties(player_properties)
    local identifier = Bridge.Framework.GetIdentifier(source)
    local access
    access, error_code = property_access(
        source,
        property,
        property_id,
        id_key,
        direct,
        identifier
    )
    if error_code then
        return nil, nil, nil, nil, error_code
    end
    if not access then
        return nil, nil, nil, nil, "property_access_denied"
    end
    local coords
    coords, error_code = property_entrance(property)
    if not coords then
        return nil, nil, nil, nil, error_code or "invalid_coordinates"
    end
    return property, property_id, id_key, coords
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
        local player_properties
        player_properties, error_code = get_player_properties(source)
        if not player_properties then
            return nil, error_code
        end

        local catalog = {}
        collect_catalog(catalog, properties)
        local direct = collect_player_properties(player_properties, catalog)
        for id_key, property_id in pairs(direct) do
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
        local building_cache = {}
        local result = {}
        for id_key, entry in pairs(catalog) do
            local access
            access, error_code = property_access(
                source,
                entry.property,
                entry.id,
                id_key,
                direct,
                identifier
            )
            if error_code then
                return nil, error_code
            end
            if access then
                local coords
                coords, error_code = property_entrance(entry.property, building_cache)
                if error_code then
                    return nil, error_code
                end
                if coords then
                    result[#result + 1] = normalized_property(
                        entry.property,
                        id_key,
                        access,
                        coords
                    )
                else
                    Bridge.Debug(
                        "debug",
                        "[sky_phone] Ignored VMS property '%s' because no valid entrance was found.",
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
        local property, property_id, id_key, coords, error_code =
            resolve_property(source, data)
        if not property then
            return nil, error_code
        end
        if action == "set_waypoint" then
            return { coords = coords }
        end
        if action == "key_candidates" or action == "grant_key" or action == "revoke_key"
            or action == "toggle_lock"
        then
            return nil, "capability_unavailable"
        end
        if action == "open_cctv" then
            return nil, "cctv_unavailable"
        end
        return nil, "invalid_action"
    end,
})
