local provider_name = "nolag"
local resource_name = "nolag_properties"

local function same_identifier(left, right)
    return left ~= nil and right ~= nil and tostring(left) == tostring(right)
end

local normalized_coords = Bridge.Normalize.Coordinates

local function player_source(identifier)
    if identifier == nil then
        return nil
    end

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

local function get_properties(identifier)
    local success, properties = pcall(function()
        return exports[resource_name]:GetAllProperties(identifier, "user", true)
    end)
    if not success or type(properties) ~= "table" then
        Bridge.Debug("error", "[sky_phone] nolag_properties:GetAllProperties failed: %s", tostring(properties))
        return nil
    end
    return properties
end

local function get_property_data(property_id)
    local success, property = pcall(function()
        return exports[resource_name]:GetPropertyData(property_id)
    end)
    if not success then
        Bridge.Debug("error", "[sky_phone] nolag_properties:GetPropertyData failed: %s", tostring(property))
        return nil, "provider_error"
    end
    if type(property) ~= "table" then
        return nil, "property_not_found"
    end
    return property
end

local function get_keyholders(property_id)
    local success, keyholders = pcall(function()
        return exports[resource_name]:GetKeyHolders(property_id)
    end)
    if not success or type(keyholders) ~= "table" then
        Bridge.Debug("error", "[sky_phone] nolag_properties:GetKeyHolders failed: %s", tostring(keyholders))
        return nil
    end
    return keyholders
end

local function get_players_in_property(property_id)
    local success, players = pcall(function()
        return exports[resource_name]:GetPlayersInProperty(property_id)
    end)
    if not success or type(players) ~= "table" then
        Bridge.Debug("error", "[sky_phone] nolag_properties:GetPlayersInProperty failed: %s", tostring(players))
        return nil
    end
    return players
end

local function property_access(property, identifier)
    if same_identifier(property.owner, identifier) then
        return "owner"
    end
    if same_identifier(property.renter, identifier) then
        return "keyholder"
    end
    return nil
end

local function keyholder_exists(keyholders, identifier)
    if type(identifier) ~= "string" or identifier == "" then
        return false
    end
    return keyholders[identifier] ~= nil
end

local function normalized_keys(property, keyholders)
    local keys = {}
    for identifier in pairs(keyholders) do
        if (type(identifier) == "string" or type(identifier) == "number")
            and not same_identifier(identifier, property.owner)
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

local function normalized_property(property, details, access, keyholders)
    local property_id = tonumber(property.id)
    local entrance = normalized_coords(property.coords)
    if not property_id or property_id < 1 or property_id ~= math.floor(property_id) or not entrance then
        return nil
    end

    local manages_keys = access == "owner"
    return {
        id = ("nolag:%s"):format(property_id),
        providerId = tostring(property_id),
        name = tostring(property.label or details.label or ("Property %s"):format(property_id)),
        access = access,
        locked = property.doorLocked == true,
        entrance = entrance,
        capabilities = {
            lock = property.hasKey == true,
            keys = manages_keys,
            waypoint = true,
            cctv = false,
            garageStatus = false,
        },
        cctv = { enabled = false },
        garage = nil,
        keys = manages_keys and normalized_keys(details, keyholders) or nil,
    }
end

local function find_property(properties, property_id)
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
        and tonumber(data.propertyId:match("^nolag:(%d+)$")) or nil
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
        return nil, nil, nil, nil, error_code
    end

    local identifier = Bridge.Framework.GetIdentifier(source)
    if not identifier then
        return nil, nil, nil, nil, "housing_unavailable"
    end

    local properties = get_properties(identifier)
    if not properties then
        return nil, nil, nil, nil, "provider_error"
    end
    local property = find_property(properties, property_id)
    if not property or not normalized_coords(property.coords) then
        return nil, nil, nil, nil, "property_access_denied"
    end

    local details, details_error = get_property_data(property_id)
    if not details then
        return nil, nil, nil, nil, details_error
    end
    local access = property_access(details, identifier)
    if not access then
        return nil, nil, nil, nil, "property_access_denied"
    end
    return property, details, property_id, access, nil, tostring(identifier)
end

local function require_current_owner(property_id, identifier)
    local details, details_error = get_property_data(property_id)
    if not details then
        return nil, details_error
    end
    if property_access(details, identifier) ~= "owner" then
        return nil, "owner_required"
    end
    return details
end

local function get_current_access_property(identifier, property_id)
    local properties = get_properties(identifier)
    if not properties then
        return nil, "provider_error"
    end
    local property = find_property(properties, property_id)
    if not property then
        return nil, "property_access_denied"
    end
    return property
end

local function key_candidates(source, property_id, details)
    local players = get_players_in_property(property_id)
    local keyholders = get_keyholders(property_id)
    if not players or not keyholders then
        return nil, "provider_error"
    end

    local candidates = {}
    local seen = {}
    for _, value in pairs(players) do
        local target = tonumber(value)
        local identifier = target and Bridge.Framework.GetIdentifier(target) or nil
        if target and target ~= source and identifier and not seen[target]
            and not same_identifier(identifier, details.owner)
            and not keyholder_exists(keyholders, tostring(identifier))
        then
            seen[target] = true
            candidates[#candidates + 1] = {
                id = target,
                name = player_name(target, identifier),
            }
        end
    end
    table.sort(candidates, function(left, right)
        return string.lower(left.name) < string.lower(right.name)
    end)
    return candidates
end

local function validate_grant_target(source, property_id, details, target)
    target = tonumber(target)
    if not target or target == source then
        return nil, "invalid_target"
    end

    local players = get_players_in_property(property_id)
    local keyholders = get_keyholders(property_id)
    if not players or not keyholders then
        return nil, "provider_error"
    end

    local present = false
    for _, value in pairs(players) do
        if tonumber(value) == target then
            present = true
            break
        end
    end
    if not present then
        return nil, "target_not_in_property"
    end

    local identifier = Bridge.Framework.GetIdentifier(target)
    if not identifier then
        return nil, "invalid_target"
    end
    identifier = tostring(identifier)
    if same_identifier(identifier, details.owner) or keyholder_exists(keyholders, identifier) then
        return nil, "key_already_exists"
    end
    return identifier
end

local function execute_action(source, action, data)
    if not SkyPhone.AllowOperation(source, "housing_nolag_action", Config.Housing.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end
    if action ~= "grant_key" and action ~= "revoke_key" and action ~= "toggle_lock" then
        return { success = false, error = "invalid_action" }
    end

    local property, details, property_id, access, error_code, actor_identifier = resolve_property(source, data)
    if not property then
        return { success = false, error = error_code }
    end
    if (action == "grant_key" or action == "revoke_key") and access ~= "owner" then
        return { success = false, error = "owner_required" }
    end
    if action == "toggle_lock" and property.hasKey ~= true then
        return { success = false, error = "capability_unavailable" }
    end

    if action == "grant_key" then
        local target_identifier, target_error = validate_grant_target(source, property_id, details, data.target)
        if not target_identifier then
            return { success = false, error = target_error }
        end

        local current_details, current_error = require_current_owner(property_id, actor_identifier)
        if not current_details then
            return { success = false, error = current_error }
        end
        local success, result, provider_error = pcall(function()
            return exports[resource_name]:AddKey(source, property_id, target_identifier)
        end)
        if not success then
            Bridge.Debug("error", "[sky_phone] nolag_properties:AddKey failed: %s", tostring(result))
            return { success = false, error = "provider_error" }
        end

        local keyholders_after = get_keyholders(property_id)
        if not keyholders_after then
            return { success = false, error = "provider_error" }
        end
        if result ~= true then
            return { success = false, error = provider_error or "provider_rejected" }
        end
        return keyholder_exists(keyholders_after, target_identifier)
            and { success = true }
            or { success = false, error = "action_failed" }
    end

    if action == "revoke_key" then
        local identifier = data.identifier
        if type(identifier) ~= "string" or identifier == "" or same_identifier(identifier, actor_identifier) then
            return { success = false, error = "invalid_target" }
        end
        local keyholders = get_keyholders(property_id)
        if not keyholders then
            return { success = false, error = "provider_error" }
        end
        if not keyholder_exists(keyholders, identifier) then
            return { success = false, error = "key_not_found" }
        end

        local current_details, current_error = require_current_owner(property_id, actor_identifier)
        if not current_details then
            return { success = false, error = current_error }
        end
        local success, result, provider_error = pcall(function()
            return exports[resource_name]:RemoveKey(source, property_id, identifier)
        end)
        if not success then
            Bridge.Debug("error", "[sky_phone] nolag_properties:RemoveKey failed: %s", tostring(result))
            return { success = false, error = "provider_error" }
        end

        local keyholders_after = get_keyholders(property_id)
        if not keyholders_after then
            return { success = false, error = "provider_error" }
        end
        if result ~= true then
            return { success = false, error = provider_error or "provider_rejected" }
        end
        return not keyholder_exists(keyholders_after, identifier)
            and { success = true }
            or { success = false, error = "action_failed" }
    end

    local current_property, current_error = get_current_access_property(actor_identifier, property_id)
    if not current_property then
        return { success = false, error = current_error }
    end
    if current_property.hasKey ~= true then
        return { success = false, error = "capability_unavailable" }
    end

    local desired_state = current_property.doorLocked ~= true
    local success, result, provider_error = pcall(function()
        return exports[resource_name]:ToggleDoorlock(source, property_id, desired_state)
    end)
    if not success then
        Bridge.Debug("error", "[sky_phone] nolag_properties:ToggleDoorlock failed: %s", tostring(result))
        return { success = false, error = "provider_error" }
    end

    local details_after, details_error = get_property_data(property_id)
    if not details_after then
        return { success = false, error = details_error }
    end
    if result ~= true then
        return { success = false, error = provider_error or "provider_rejected" }
    end
    return type(details_after.doorLocked) == "boolean" and details_after.doorLocked == desired_state
        and { success = true }
        or { success = false, error = "action_failed" }
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

        local properties = get_properties(identifier)
        if not properties then
            return nil, "provider_error"
        end

        local result = {}
        for _, property in pairs(properties) do
            local property_id = type(property) == "table" and tonumber(property.id) or nil
            if property_id then
                local details = get_property_data(property_id)
                local access = details and property_access(details, identifier) or nil
                local keyholders = access == "owner" and get_keyholders(property_id) or {}
                local normalized = access and keyholders
                    and normalized_property(property, details, access, keyholders) or nil
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
        local property, details, property_id, access, error_code = resolve_property(source, data)
        if not property then
            return nil, error_code
        end

        if action == "set_waypoint" then
            return { coords = normalized_coords(property.coords) }
        end
        if action == "open_cctv" then
            return nil, "cctv_unavailable"
        end
        if action == "key_candidates" then
            if access ~= "owner" then
                return nil, "owner_required"
            end
            local candidates, candidates_error = key_candidates(source, property_id, details)
            return candidates and { candidates = candidates } or nil, candidates_error
        end
        if action == "grant_key" then
            if access ~= "owner" then
                return nil, "owner_required"
            end
            local target_identifier, target_error = validate_grant_target(source, property_id, details, data.target)
            if not target_identifier then
                return nil, target_error
            end
            return { providerId = tostring(property_id), target = tonumber(data.target) }
        end
        if action == "revoke_key" then
            if access ~= "owner" then
                return nil, "owner_required"
            end
            local identifier = data.identifier
            local keyholders = get_keyholders(property_id)
            if not keyholders then
                return nil, "provider_error"
            end
            if type(identifier) ~= "string" or not keyholder_exists(keyholders, identifier) then
                return nil, "key_not_found"
            end
            return { providerId = tostring(property_id), identifier = identifier }
        end
        if action == "toggle_lock" then
            if property.hasKey ~= true then
                return nil, "capability_unavailable"
            end
            return { providerId = tostring(property_id) }
        end
        return nil, "invalid_action"
    end,
})

Bridge.Callbacks.Register("sky_phone:housing:nolag:execute", function(source, data)
    if type(data) ~= "table" or type(data.action) ~= "string" then
        return { success = false, error = "invalid_request" }
    end
    return execute_action(source, data.action, data)
end)
