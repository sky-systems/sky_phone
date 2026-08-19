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

local function property_tables(value, house)
    value = decode_object(value)
    if not value then
        return {}
    end
    local result = { value }
    local named = house and decode_object(field(value, house)) or nil
    if named and named ~= value then
        result[#result + 1] = named
    end
    for _, key in ipairs({ "data", "houseData", "house_data", "propertyData", "property_data" }) do
        local nested = decode_object(field(value, key))
        if nested and nested ~= value and nested ~= named then
            result[#result + 1] = nested
        end
    end
    return result
end

local function entrance_for(value, house)
    for _, candidate in ipairs(property_tables(value, house)) do
        for _, key in ipairs({ "entrance", "Entrance", "entry", "Entry", "enter", "Enter" }) do
            local coords = normalized_coords(field(candidate, key))
            if coords then
                return coords
            end
        end

        for _, key in ipairs({ "coords", "coordinates", "location", "position", "points" }) do
            local container = decode_object(field(candidate, key))
            if container then
                for _, nested_key in ipairs({
                    "entrance", "Entrance", "entry", "Entry", "enter", "Enter", "door", "frontDoor",
                }) do
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

local function house_reference(value)
    if type(value) ~= "string" and type(value) ~= "number" then
        return nil
    end
    local house = tostring(value):match("^%s*(.-)%s*$")
    return house ~= "" and house or nil
end

local function house_entrance(house)
    local success, house_data = pcall(function()
        return exports["qs-housing"]:getHouseData(house)
    end)
    if not success then
        Bridge.Debug(
            "error",
            "[sky_phone] qs-housing:getHouseData failed for '%s': %s",
            house,
            tostring(house_data)
        )
        return nil, "provider_error"
    end
    local entrance = entrance_for(house_data, house)
    if not entrance then
        return nil, "invalid_coordinates"
    end
    return entrance
end

local function enrich_overview(properties)
    local result = {}
    if GetResourceState(resource_name) ~= "started" or type(properties) ~= "table" then
        return result
    end

    for _, property in ipairs(properties) do
        local house = type(property) == "table" and house_reference(property.providerId) or nil
        if house and property.id == provider_name .. ":" .. house then
            local entrance = normalized_coords(property.entrance)
            if not entrance then
                entrance = house_entrance(house)
            end
            if entrance then
                result[#result + 1] = {
                    id = property.id,
                    entrance = entrance,
                }
            end
        end
    end
    return result
end

Bridge.Housing.RegisterClientProvider(provider_name, {
    enrich_overview = enrich_overview,
    execute = function(action, data)
        if GetResourceState(resource_name) ~= "started" then
            return false, "provider_unavailable"
        end
        if action ~= "set_waypoint" then
            return false, "capability_unavailable"
        end
        local house = type(data) == "table" and house_reference(data.providerId) or nil
        if not house then
            return false, "invalid_property"
        end
        local entrance, error_code = house_entrance(house)
        if not entrance then
            return false, error_code
        end
        SetNewWaypoint(entrance.x + 0.0, entrance.y + 0.0)
        return true
    end,
})
