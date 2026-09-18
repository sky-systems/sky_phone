local provider_name = "tgiann"
local resource_name = "tgiann-house"

local function query_owned_houses(identifier)
    local success, properties = pcall(function()
        return MySQL.query.await([[
            SELECT `name`
            FROM `tgiann_house`
            WHERE `owner` = ?
            ORDER BY `name` ASC
        ]], { identifier })
    end)
    if not success or type(properties) ~= "table" then
        Bridge.Debug("error", "[sky_phone] tgiann-house overview query failed: %s", tostring(properties))
        return nil
    end
    return properties
end

local function owns_house(identifier, house)
    local success, property = pcall(function()
        return MySQL.single.await([[
            SELECT `name`
            FROM `tgiann_house`
            WHERE `name` = ? AND `owner` = ?
            LIMIT 1
        ]], { house, identifier })
    end)
    if not success then
        Bridge.Debug("error", "[sky_phone] tgiann-house ownership query failed: %s", tostring(property))
        return nil, "provider_error"
    end
    return type(property) == "table"
end

local function house_from_property_id(value)
    if type(value) ~= "string" then
        return nil
    end
    local house = value:match("^tgiann:(.+)$")
    return house and house ~= "" and house or nil
end

local function normalized_property(house)
    return {
        id = provider_name .. ":" .. house,
        providerId = house,
        name = house,
        access = "owner",
        locked = false,
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

Bridge.Housing.RegisterProvider(provider_name, {
    resource_name = resource_name,
    is_available = function()
        return GetResourceState(resource_name) == "started"
    end,
    get_overview = function(source)
        local identifier = Bridge.Framework.GetIdentifier(source)
        if not identifier then
            return nil, "housing_unavailable"
        end
        local properties = query_owned_houses(identifier)
        if not properties then
            return nil, "provider_error"
        end

        local result = {}
        local seen = {}
        local maximum = math.max(0, math.floor(tonumber(Config.Housing.MaximumProperties) or 0))
        for _, property in ipairs(properties) do
            if #result >= maximum then
                break
            end
            local house = type(property.name) == "string" and property.name or nil
            if house and house ~= "" and not seen[house] then
                seen[house] = true
                result[#result + 1] = normalized_property(house)
            end
        end
        return result
    end,
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

        local house = house_from_property_id(data and data.propertyId)
        if not house then
            return nil, "invalid_property"
        end
        local identifier = Bridge.Framework.GetIdentifier(source)
        if not identifier then
            return nil, "housing_unavailable"
        end
        local owned, error_code = owns_house(identifier, house)
        if owned == nil then
            return nil, error_code
        end
        if not owned then
            return nil, "property_access_denied"
        end
        return { providerId = house }
    end,
})
