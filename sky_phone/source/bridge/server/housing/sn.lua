local provider_name = "sn"
local resource_name = "sn_properties"

local function same_identifier(left, right)
    return left ~= nil and right ~= nil and tostring(left) == tostring(right)
end

local function normalized_property_id(value)
    if type(value) == "table" then
        value = value.id or value.propertyId or value.property_id
    end
    local property_id = tonumber(value)
    if not property_id or property_id < 1 or property_id ~= math.floor(property_id) then
        return nil
    end
    return property_id
end

local normalized_coords = Bridge.Normalize.Coordinates

local function get_all_properties()
    local success, properties = pcall(function()
        return exports[resource_name]:getAllProperties()
    end)
    if not success or type(properties) ~= "table" then
        Bridge.Debug("error", "[sky_phone] sn_properties:getAllProperties failed: %s", tostring(properties))
        return nil
    end
    return properties
end

local function collect_owned_property_ids(value, result)
    local direct_id = normalized_property_id(value)
    if direct_id then
        result[direct_id] = true
        return
    end
    if type(value) ~= "table" then
        return
    end

    local array_length = #value
    local is_dense_array = array_length > 0
    if is_dense_array then
        local entries = 0
        for key in pairs(value) do
            entries = entries + 1
            if type(key) ~= "number" or key < 1 or key ~= math.floor(key) or key > array_length then
                is_dense_array = false
            end
        end
        is_dense_array = is_dense_array and entries == array_length
    end

    for key, entry in pairs(value) do
        local entry_id = normalized_property_id(entry)
        if entry_id then
            result[entry_id] = true
        else
            local key_id = normalized_property_id(key)
            local keyed_property = key_id and entry ~= nil and entry ~= false
                and (entry == true or type(key) == "string" or not is_dense_array)
            if keyed_property then
                result[key_id] = true
            end
        end
    end
end

local function get_owned_property_ids(source)
    local success, properties = pcall(function()
        return exports[resource_name]:getPlayerProperties(source)
    end)
    if not success then
        Bridge.Debug("error", "[sky_phone] sn_properties:getPlayerProperties failed: %s", tostring(properties))
        return nil
    end

    local result = {}
    if properties == nil or properties == false then
        return result
    end
    if type(properties) ~= "table" and type(properties) ~= "number" and type(properties) ~= "string" then
        Bridge.Debug("error", "[sky_phone] sn_properties:getPlayerProperties returned an invalid value")
        return nil
    end
    collect_owned_property_ids(properties, result)
    return result
end

local function player_source(identifier)
    for _, source in ipairs(Bridge.Framework.GetPlayers()) do
        if same_identifier(Bridge.Framework.GetIdentifier(source), identifier) then
            return source
        end
    end
    return nil
end

local function player_name(source, fallback)
    if source then
        local name = Bridge.Framework.GetCharacterName(source) or GetPlayerName(source)
        if type(name) == "string" then
            name = name:match("^%s*(.-)%s*$")
            if name ~= "" then
                return name
            end
        end
    end
    return tostring(fallback)
end

local function property_keys(property)
    return type(property.keys) == "table" and property.keys or {}
end

local function property_access(property, identifier, owned_property_ids)
    local property_id = normalized_property_id(property)
    if property_id and owned_property_ids[property_id] then
        return "owner"
    end
    if property_keys(property)[tostring(identifier)] ~= nil then
        return "keyholder"
    end
    return nil
end

local function normalized_keys(property, actor_identifier)
    local keys = {}
    for identifier in pairs(property_keys(property)) do
        if (type(identifier) == "string" or type(identifier) == "number")
            and not same_identifier(identifier, actor_identifier)
        then
            local normalized_identifier = tostring(identifier)
            local source = player_source(normalized_identifier)
            keys[#keys + 1] = {
                identifier = normalized_identifier,
                name = player_name(source, normalized_identifier),
                online = source ~= nil,
                revocable = true,
            }
        end
    end
    table.sort(keys, function(left, right)
        return string.lower(left.name) < string.lower(right.name)
    end)
    return keys
end

local function normalized_property(property, access, actor_identifier)
    local property_id = normalized_property_id(property)
    local entrance = normalized_coords(property.coords)
    if not property_id or property_id < 1 or property_id ~= math.floor(property_id) or not entrance then
        return nil
    end

    local owner = access == "owner"
    return {
        id = ("sn:%s"):format(property_id),
        providerId = tostring(property_id),
        name = tostring(property.label or ("Property %s"):format(property_id)),
        access = access,
        locked = false,
        entrance = entrance,
        capabilities = {
            lock = false,
            keyGrant = false,
            keys = owner,
            waypoint = true,
            cctv = false,
            garageStatus = false,
        },
        cctv = { enabled = false },
        garage = nil,
        keys = owner and normalized_keys(property, actor_identifier) or nil,
    }
end

local function find_property(properties, property_id)
    if normalized_property_id(properties) == property_id then
        return properties
    end
    for _, property in pairs(properties) do
        if type(property) == "table" and tonumber(property.id) == property_id then
            return property
        end
    end
    return nil
end

local function parse_property_id(data)
    if type(data) ~= "table" then
        return nil, "invalid_request"
    end
    local property_id = type(data.propertyId) == "string"
        and tonumber(data.propertyId:match("^sn:(%d+)$")) or nil
    if not property_id then
        property_id = tonumber(data.providerId)
    end
    if not property_id or property_id < 1 or property_id ~= math.floor(property_id) then
        return nil, "invalid_property"
    end
    return property_id
end

local function resolve_property(source, data)
    local property_id, error_code = parse_property_id(data)
    if not property_id then
        return nil, nil, nil, error_code
    end

    local identifier = Bridge.Framework.GetIdentifier(source)
    if not identifier then
        return nil, nil, nil, "housing_unavailable"
    end
    identifier = tostring(identifier)

    local owned_property_ids = get_owned_property_ids(source)
    if not owned_property_ids then
        return nil, nil, nil, "provider_error"
    end

    local properties = get_all_properties()
    if not properties then
        return nil, nil, nil, "provider_error"
    end
    local property = find_property(properties, property_id)
    if not property or not normalized_coords(property.coords) then
        return nil, nil, nil, "property_not_found"
    end

    local access = property_access(property, identifier, owned_property_ids)
    if not access then
        return nil, nil, nil, "property_access_denied"
    end
    return property, property_id, access, nil, identifier, owned_property_ids
end

local function execute_action(source, action, data)
    if not SkyPhone.AllowOperation(source, "housing_sn_action", Config.Housing.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end

    if action == "grant_key" then
        return { success = false, error = "capability_unavailable" }
    end
    if action ~= "revoke_key" then
        return { success = false, error = "invalid_action" }
    end

    local property, property_id, access, error_code, actor_identifier, owned_property_ids = resolve_property(source, data)
    if not property then
        return { success = false, error = error_code }
    end
    if access ~= "owner" or not owned_property_ids[property_id] then
        return { success = false, error = "owner_required" }
    end

    local identifier = data.identifier
    if type(identifier) ~= "string" or identifier == "" or same_identifier(identifier, actor_identifier) then
        return { success = false, error = "invalid_target" }
    end
    if property_keys(property)[identifier] == nil then
        return { success = false, error = "key_not_found" }
    end

    local current_owned_property_ids = get_owned_property_ids(source)
    if not current_owned_property_ids then
        return { success = false, error = "provider_error" }
    end
    if not current_owned_property_ids[property_id] then
        return { success = false, error = "owner_required" }
    end

    local success, result = pcall(function()
        return exports[resource_name]:removeKeyholder(identifier, property_id)
    end)
    if not success then
        Bridge.Debug("error", "[sky_phone] sn_properties:removeKeyholder failed: %s", tostring(result))
        return { success = false, error = "provider_error" }
    end

    local updated_properties = get_all_properties()
    if not updated_properties then
        return { success = false, error = "provider_error" }
    end
    local updated_property = find_property(updated_properties, property_id)
    if not updated_property then
        return { success = false, error = "property_not_found" }
    end
    if property_keys(updated_property)[identifier] ~= nil then
        return { success = false, error = result == false and "provider_rejected" or "action_failed" }
    end
    return { success = true }
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
        identifier = tostring(identifier)

        local owned_property_ids = get_owned_property_ids(source)
        if not owned_property_ids then
            return nil, "provider_error"
        end

        local properties = get_all_properties()
        if not properties then
            return nil, "provider_error"
        end

        local result = {}
        for _, property in pairs(properties) do
            if type(property) == "table" then
                local access = property_access(property, identifier, owned_property_ids)
                local normalized = access and normalized_property(property, access, identifier) or nil
                if normalized then
                    result[#result + 1] = normalized
                    if #result >= Config.Housing.MaximumProperties then
                        break
                    end
                end
            end
        end
        table.sort(result, function(left, right)
            if left.access ~= right.access then
                return left.access == "owner"
            end
            return string.lower(left.name) < string.lower(right.name)
        end)
        return result
    end,
    prepare = function(source, action, data)
        local property, property_id, access, error_code, actor_identifier = resolve_property(source, data)
        if not property then
            return nil, error_code
        end

        if action == "set_waypoint" then
            return { coords = normalized_coords(property.coords) }
        end
        if action == "open_cctv" then
            return nil, "cctv_unavailable"
        end
        if action == "toggle_lock" then
            return nil, "capability_unavailable"
        end
        if action == "key_candidates" then
            if access ~= "owner" then
                return nil, "owner_required"
            end
            return { candidates = {} }
        end
        if action == "grant_key" then
            if access ~= "owner" then
                return nil, "owner_required"
            end
            return nil, "capability_unavailable"
        end
        if action == "revoke_key" then
            if access ~= "owner" then
                return nil, "owner_required"
            end
            local identifier = data.identifier
            if type(identifier) ~= "string" or identifier == "" or same_identifier(identifier, actor_identifier) then
                return nil, "invalid_target"
            end
            if property_keys(property)[identifier] == nil then
                return nil, "key_not_found"
            end
            return { providerId = tostring(property_id), identifier = identifier }
        end
        return nil, "invalid_action"
    end,
})

Bridge.Callbacks.Register("sky_phone:housing:sn:execute", function(source, data)
    if type(data) ~= "table" or type(data.action) ~= "string" then
        return { success = false, error = "invalid_request" }
    end
    return execute_action(source, data.action, data)
end)
