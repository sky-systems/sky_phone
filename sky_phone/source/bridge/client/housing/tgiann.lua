local provider_name = "tgiann"
local resource_name = "tgiann-house"

local function house_reference(value)
    if type(value) ~= "string" then
        return nil
    end
    return value ~= "" and value or nil
end

local function house_entrance(house)
    local success, house_data = pcall(function()
        return exports[resource_name]:getHouseData(house)
    end)
    if not success then
        Bridge.Debug(
            "error",
            "[sky_phone] tgiann-house:getHouseData failed for '%s': %s",
            house,
            tostring(house_data)
        )
        return nil, "provider_error"
    end
    local entrance = type(house_data) == "table"
        and Bridge.Normalize.Coordinates(house_data.doorCoord) or nil
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
            local entrance = house_entrance(house)
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
