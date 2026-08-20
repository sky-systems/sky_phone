local provider_name = "quasar"
local resource_name = "qs-housing"

local function table_like(value)
    local value_type = type(value)
    return value_type == "table" or value_type == "vector3" or value_type == "vector4"
end

local function field(value, key)
    if not table_like(value) then
        return nil
    end
    local success, result = pcall(function()
        return value[key]
    end)
    return success and result or nil
end

local function decode_object(value)
    if table_like(value) then
        return value
    end
    if type(value) ~= "string" or value == "" then
        return nil
    end
    local success, decoded = pcall(json.decode, value)
    return success and table_like(decoded) and decoded or nil
end

local function normalized_coords(value)
    value = decode_object(value)
    return value and Bridge.Normalize.Coordinates(value) or nil
end

local function property_tables(property)
    if not table_like(property) then
        return {}
    end
    local result = { property }
    for _, key in ipairs({ "data", "houseData", "house_data", "propertyData", "property_data" }) do
        local nested = decode_object(field(property, key))
        if nested and nested ~= property then
            result[#result + 1] = nested
        end
    end
    return result
end

local function entrance_for(property)
    for _, candidate in ipairs(property_tables(property)) do
        for _, key in ipairs({ "entrance", "Entrance", "entry", "Entry" }) do
            local coords = normalized_coords(field(candidate, key))
            if coords then
                return coords
            end
        end

        for _, key in ipairs({ "coords", "coordinates", "location", "position" }) do
            local container = decode_object(field(candidate, key))
            if container then
                for _, nested_key in ipairs({ "entrance", "Entrance", "entry", "Entry", "enter", "door" }) do
                    local coords = normalized_coords(field(container, nested_key))
                    if coords then
                        return coords
                    end
                end
                local coords = normalized_coords(container)
                if coords then
                    return coords
                end
            end
        end
    end
    return nil
end

local function non_empty_string(value)
    if type(value) ~= "string" and type(value) ~= "number" then
        return nil
    end
    local text = tostring(value):match("^%s*(.-)%s*$")
    return text ~= "" and text or nil
end

local function house_reference(key, property)
    local direct = non_empty_string(property)
    if direct then
        return direct
    end
    if table_like(property) then
        for _, name in ipairs({
            "house", "houseName", "house_name", "name", "identifier",
        }) do
            local value = non_empty_string(field(property, name))
            if value then
                return value
            end
        end
    end
    if type(key) == "string" and not tonumber(key) then
        return non_empty_string(key)
    end
    if table_like(property) then
        for _, name in ipairs({ "propertyId", "property_id", "id" }) do
            local value = non_empty_string(field(property, name))
            if value then
                return value
            end
        end
    end
    return nil
end

local function property_name(property, house)
    for _, candidate in ipairs(property_tables(property)) do
        for _, key in ipairs({ "label", "address", "adress", "displayName", "display_name", "name" }) do
            local value = non_empty_string(field(candidate, key))
            if value then
                return value
            end
        end
    end
    return house
end

local function get_player_properties(source)
    local success, properties = pcall(function()
        return exports[resource_name]:GetPlayerHouses(source)
    end)
    if success and type(properties) == "table" then
        return properties
    end

    Bridge.Debug(
        "error",
        "[sky_phone] qs-housing:GetPlayerHouses failed for source %s: %s",
        tostring(source),
        tostring(properties)
    )
    return nil, "provider_error"
end

local function normalized_properties(source)
    local properties, error_code = get_player_properties(source)
    if not properties then
        return nil, error_code
    end

    local result = {}
    local seen = {}
    for key, property in pairs(properties) do
        local house = house_reference(key, property)
        if house and not seen[house] then
            local entrance = entrance_for(property)
            seen[house] = true
            result[#result + 1] = {
                id = provider_name .. ":" .. house,
                providerId = house,
                name = property_name(property, house),
                access = "owner",
                locked = false,
                entrance = entrance,
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
    end

    table.sort(result, function(left, right)
        return string.lower(left.name) < string.lower(right.name)
    end)

    local maximum = math.max(0, math.floor(tonumber(Config.Housing.MaximumProperties) or 0))
    while #result > maximum do
        result[#result] = nil
    end
    return result
end

local function find_property(source, property_id)
    if type(property_id) ~= "string" then
        return nil, "invalid_property"
    end
    local house = property_id:match("^quasar:(.+)$")
    if not house or house == "" then
        return nil, "invalid_property"
    end

    local properties, error_code = normalized_properties(source)
    if not properties then
        return nil, error_code
    end
    for _, property in ipairs(properties) do
        if property.providerId == house then
            return property
        end
    end
    return nil, "property_access_denied"
end

Bridge.Housing.RegisterProvider(provider_name, {
    resource_name = resource_name,
    is_available = function()
        return GetResourceState(resource_name) == "started"
    end,
    get_overview = normalized_properties,
    prepare = function(source, action, data)
        if action == "toggle_lock" or action == "grant_key" or action == "revoke_key"
            or action == "key_candidates"
        then
            return nil, "capability_unavailable"
        end
        if action == "open_cctv" then
            return nil, "cctv_unavailable"
        end
        if action ~= "set_waypoint" then
            return nil, "invalid_action"
        end

        local property, error_code = find_property(source, data and data.propertyId)
        if not property then
            return nil, error_code
        end
        return {
            providerId = property.providerId,
            coords = property.entrance,
        }
    end,
})
