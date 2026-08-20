local provider_name = "rx"
local resource_name = "RxHousing"

local function positive_integer(value)
    local number = Bridge.Normalize.FiniteNumber(value)
    if not number or number < 1 or number ~= math.floor(number) then
        return nil
    end
    return number
end

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

local function non_empty_string(value)
    if type(value) ~= "string" and type(value) ~= "number" then
        return nil
    end
    local text = tostring(value):match("^%s*(.-)%s*$")
    return text ~= "" and text or nil
end

local function normalized_coords(value)
    value = decode_object(value)
    return value and Bridge.Normalize.Coordinates(value) or nil
end

local function entrance_for(property)
    if not table_like(property) then
        return nil
    end
    for _, key in ipairs({ "entrance", "Entrance", "entry", "Entry" }) do
        local coords = normalized_coords(field(property, key))
        if coords then
            return coords
        end
    end

    for _, key in ipairs({ "coords", "coordinates", "location", "position" }) do
        local container = decode_object(field(property, key))
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
    return nil
end

local function owner_identifier(property)
    local owner = field(property, "owner")
    local direct = non_empty_string(owner)
    if direct then
        return direct
    end
    if not table_like(owner) then
        return nil
    end
    for _, key in ipairs({ "identifier", "citizenid", "citizenId", "id" }) do
        local value = non_empty_string(field(owner, key))
        if value then
            return value
        end
    end
    return nil
end

local function same_identifier(left, right)
    return left ~= nil and right ~= nil and tostring(left) == tostring(right)
end

local function property_name(property, property_id)
    for _, key in ipairs({ "label", "name", "address", "adress" }) do
        local value = non_empty_string(field(property, key))
        if value then
            return value
        end
    end
    return ("Property %s"):format(property_id)
end

local function call_export(name, callback)
    local success, result = pcall(callback)
    if not success then
        Bridge.Debug("error", "[sky_phone] RxHousing:%s failed: %s", name, tostring(result))
        return nil, false
    end
    return result, true
end

local function get_all_properties()
    local properties, success = call_export("GetAllProperties", function()
        return exports[resource_name]:GetAllProperties()
    end)
    if not success or type(properties) ~= "table" then
        if success then
            Bridge.Debug("error", "[sky_phone] RxHousing:GetAllProperties returned invalid data.")
        end
        return nil, "provider_error"
    end
    return properties
end

local function property_id_for(key, property)
    if table_like(property) then
        for _, name in ipairs({ "id", "propertyId", "property_id" }) do
            local property_id = positive_integer(field(property, name))
            if property_id then
                return property_id
            end
        end
    end
    return positive_integer(key)
end

local function property_entries(properties)
    local result = {}
    local seen = {}
    for key, value in pairs(properties) do
        local property = decode_object(value)
        local property_id = property and property_id_for(key, property) or nil
        if property_id and not seen[property_id] then
            seen[property_id] = true
            result[#result + 1] = { id = property_id, data = property }
        end
    end
    table.sort(result, function(left, right)
        return left.id < right.id
    end)
    return result
end

local function get_owned_property_ids(identifier)
    local properties, success = call_export("GetOwnedProperties", function()
        return exports[resource_name]:GetOwnedProperties(identifier)
    end)
    if not success or type(properties) ~= "table" then
        if success then
            Bridge.Debug("error", "[sky_phone] RxHousing:GetOwnedProperties returned invalid data.")
        end
        return nil, "provider_error"
    end

    local result = {}
    local is_array = #properties > 0
    local direct_id = property_id_for(nil, properties)
    if direct_id then
        result[direct_id] = true
        return result
    end

    for key, value in pairs(properties) do
        local property = decode_object(value)
        local property_id = property and property_id_for(key, property)
            or positive_integer(value)
        if not property_id and (value == true or value == 1) then
            property_id = positive_integer(key)
        end
        if not property_id and not is_array then
            property_id = positive_integer(key)
        end
        if property_id then
            result[property_id] = true
        end
    end
    return result
end

local function get_property(property_id)
    local property, success = call_export("GetProperty", function()
        return exports[resource_name]:GetProperty(property_id)
    end)
    if not success then
        return nil, "provider_error"
    end
    property = decode_object(property)
    if not property then
        return nil, "property_not_found"
    end
    return property
end

local function boolean_result(value)
    return value == true or value == 1 or value == "true"
end

local function has_key(property_id, identifier)
    local result, success = call_export("HasKey", function()
        return exports[resource_name]:HasKey(property_id, identifier)
    end)
    if not success then
        return nil, "provider_error"
    end
    return boolean_result(result)
end

local function online_source(identifier)
    for _, player_source in ipairs(Bridge.Framework.GetPlayers() or {}) do
        if same_identifier(Bridge.Framework.GetIdentifier(player_source), identifier) then
            return player_source
        end
    end
    return nil
end

local function player_name(player_source)
    local first_name = Bridge.Framework.GetFirstname(player_source)
    local last_name = Bridge.Framework.GetLastname(player_source)
    local name = table.concat({ tostring(first_name or ""), tostring(last_name or "") }, " ")
        :match("^%s*(.-)%s*$")
    if name ~= "" then
        return name
    end
    return GetPlayerName(player_source) or tostring(player_source)
end

local function keyholder_identifier(key, value)
    if type(value) == "string" then
        return non_empty_string(value)
    end
    if table_like(value) then
        for _, name in ipairs({ "identifier", "citizenid", "citizenId", "playerIdentifier", "player_identifier" }) do
            local identifier = non_empty_string(field(value, name))
            if identifier then
                return identifier
            end
        end
    end
    if type(key) == "string" and not tonumber(key) and (value == true or table_like(value)) then
        return non_empty_string(key)
    end
    return nil
end

local function supplied_keyholder_name(value)
    if not table_like(value) then
        return nil
    end
    local direct = non_empty_string(field(value, "name") or field(value, "label"))
    if direct then
        return direct
    end
    local first_name = non_empty_string(field(value, "firstname") or field(value, "firstName")) or ""
    local last_name = non_empty_string(field(value, "lastname") or field(value, "lastName")) or ""
    local name = (first_name .. " " .. last_name):match("^%s*(.-)%s*$")
    return name ~= "" and name or nil
end

local function get_keyholder_values(property_id)
    local values, success = call_export("GetPropertyKeyholders", function()
        return exports[resource_name]:GetPropertyKeyholders(property_id)
    end)
    if not success or type(values) ~= "table" then
        if success then
            Bridge.Debug("error", "[sky_phone] RxHousing:GetPropertyKeyholders returned invalid data.")
        end
        return nil, "provider_error"
    end
    return values
end

local function normalized_keyholders(property_id, excluded_identifier)
    local values, error_code = get_keyholder_values(property_id)
    if not values then
        return nil, error_code
    end

    local result = {}
    local seen = {}
    for key, value in pairs(values) do
        local identifier = keyholder_identifier(key, value)
        if identifier and not same_identifier(identifier, excluded_identifier) and not seen[identifier] then
            seen[identifier] = true
            local player_source = online_source(identifier)
            result[#result + 1] = {
                identifier = identifier,
                name = player_source and player_name(player_source)
                    or supplied_keyholder_name(value)
                    or identifier,
                online = player_source ~= nil,
                revocable = true,
            }
        end
    end
    table.sort(result, function(left, right)
        return string.lower(left.name) < string.lower(right.name)
    end)
    return result
end

local function access_for(property_id, identifier, owned_properties)
    if owned_properties[property_id] then
        return "owner"
    end
    local allowed, error_code = has_key(property_id, identifier)
    if allowed == nil then
        return nil, error_code
    end
    return allowed and "keyholder" or nil
end

local function normalized_property(property_id, property, access, actor_identifier)
    local entrance = entrance_for(property)
    if not entrance then
        return nil
    end

    local keys = nil
    if access == "owner" then
        local error_code
        keys, error_code = normalized_keyholders(property_id, actor_identifier)
        if not keys then
            return nil, error_code
        end
    end

    return {
        id = ("rx:%s"):format(property_id),
        providerId = tostring(property_id),
        name = property_name(property, property_id),
        access = access,
        locked = false,
        entrance = entrance,
        capabilities = {
            lock = false,
            keys = access == "owner",
            waypoint = true,
            cctv = false,
            garageStatus = false,
        },
        cctv = { enabled = false },
        garage = nil,
        keys = keys,
    }
end

local function get_overview(source)
    local identifier = Bridge.Framework.GetIdentifier(source)
    if not identifier then
        return nil, "housing_unavailable"
    end
    local owned_properties, owned_error = get_owned_property_ids(identifier)
    if not owned_properties then
        return nil, owned_error
    end
    local properties, error_code = get_all_properties()
    if not properties then
        return nil, error_code
    end

    local result = {}
    for _, entry in ipairs(property_entries(properties)) do
        local access, access_error = access_for(entry.id, identifier, owned_properties)
        if access_error then
            return nil, access_error
        end
        if access then
            local property, normalize_error = normalized_property(entry.id, entry.data, access, identifier)
            if normalize_error then
                return nil, normalize_error
            end
            if property then
                result[#result + 1] = property
            end
        end
    end

    table.sort(result, function(left, right)
        if left.access ~= right.access then
            return left.access == "owner"
        end
        return string.lower(left.name) < string.lower(right.name)
    end)
    local maximum = math.max(0, math.floor(tonumber(Config.Housing.MaximumProperties) or 0))
    while #result > maximum do
        result[#result] = nil
    end
    return result
end

local function parse_property_id(value)
    if type(value) ~= "string" then
        return nil
    end
    return positive_integer(value:match("^rx:(%d+)$"))
end

local function resolve_property(source, data)
    local property_id = parse_property_id(data and data.propertyId)
    if not property_id then
        return nil, nil, nil, "invalid_property"
    end
    local property, error_code = get_property(property_id)
    if not property then
        return nil, nil, nil, error_code
    end
    local identifier = Bridge.Framework.GetIdentifier(source)
    if not identifier then
        return nil, nil, nil, "housing_unavailable"
    end
    local owned_properties, owned_error = get_owned_property_ids(identifier)
    if not owned_properties then
        return nil, nil, nil, owned_error
    end
    local access, access_error = access_for(property_id, identifier, owned_properties)
    if access_error then
        return nil, nil, nil, access_error
    end
    if not access then
        return nil, nil, nil, "property_access_denied"
    end
    if not entrance_for(property) then
        return nil, nil, nil, "invalid_coordinates"
    end
    return property, property_id, access
end

local function player_source_for(key, value)
    local direct = positive_integer(value)
    if direct then
        return direct
    end
    if table_like(value) then
        for _, name in ipairs({ "source", "playerId", "player_id", "serverId", "server_id", "id" }) do
            local player_source = positive_integer(field(value, name))
            if player_source then
                return player_source
            end
        end
    end
    if value == true or table_like(value) then
        return positive_integer(key)
    end
    return nil
end

local function players_in_property(property_id)
    local values, success = call_export("GetPlayersInProperty", function()
        return exports[resource_name]:GetPlayersInProperty(property_id)
    end)
    if not success or type(values) ~= "table" then
        if success then
            Bridge.Debug("error", "[sky_phone] RxHousing:GetPlayersInProperty returned invalid data.")
        end
        return nil, "provider_error"
    end

    local result = {}
    local seen = {}
    for key, value in pairs(values) do
        local player_source = player_source_for(key, value)
        if player_source and not seen[player_source] and GetPlayerName(player_source) then
            seen[player_source] = true
            result[#result + 1] = player_source
        end
    end
    return result
end

local function key_candidates(source, property, property_id)
    local players, error_code = players_in_property(property_id)
    if not players then
        return nil, error_code
    end
    local owner = Bridge.Framework.GetIdentifier(source) or owner_identifier(property)
    local result = {}
    for _, target in ipairs(players) do
        local identifier = Bridge.Framework.GetIdentifier(target)
        if target ~= source and identifier and not same_identifier(identifier, owner) then
            local allowed, access_error = has_key(property_id, identifier)
            if allowed == nil then
                return nil, access_error
            end
            if not allowed then
                result[#result + 1] = {
                    id = target,
                    name = player_name(target),
                }
            end
        end
    end
    table.sort(result, function(left, right)
        return string.lower(left.name) < string.lower(right.name)
    end)
    return result
end

local function has_keyholder(property_id, identifier)
    local keyholders, error_code = normalized_keyholders(property_id)
    if not keyholders then
        return nil, error_code
    end
    for _, keyholder in ipairs(keyholders) do
        if same_identifier(keyholder.identifier, identifier) then
            return true
        end
    end
    return false
end

local function execute_key_action(source, data)
    if not SkyPhone.AllowOperation(source, "housing_rx_action", Config.Housing.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end
    if GetResourceState(resource_name) ~= "started" then
        return { success = false, error = "provider_unavailable" }
    end
    if type(data) ~= "table" or (data.action ~= "grant_key" and data.action ~= "revoke_key") then
        return { success = false, error = "invalid_action" }
    end

    local property_id = positive_integer(data.providerId)
    if not property_id then
        return { success = false, error = "invalid_property" }
    end
    local property, error_code = get_property(property_id)
    if not property then
        return { success = false, error = error_code }
    end
    if not entrance_for(property) then
        return { success = false, error = "invalid_coordinates" }
    end
    local identifier = Bridge.Framework.GetIdentifier(source)
    if not identifier then
        return { success = false, error = "owner_required" }
    end
    local owned_properties, owned_error = get_owned_property_ids(identifier)
    if not owned_properties then
        return { success = false, error = owned_error }
    end
    if not owned_properties[property_id] then
        return { success = false, error = "owner_required" }
    end

    if data.action == "grant_key" then
        local target = positive_integer(data.target)
        local target_identifier = target and Bridge.Framework.GetIdentifier(target) or nil
        if not target or target == source or not target_identifier or not GetPlayerName(target) then
            return { success = false, error = "invalid_target" }
        end
        if same_identifier(target_identifier, identifier) then
            return { success = false, error = "invalid_target" }
        end

        local players, players_error = players_in_property(property_id)
        if not players then
            return { success = false, error = players_error }
        end
        local inside = false
        for _, player_source in ipairs(players) do
            if player_source == target then
                inside = true
                break
            end
        end
        if not inside then
            return { success = false, error = "target_not_in_property" }
        end

        local allowed, access_error = has_key(property_id, target_identifier)
        if allowed == nil then
            return { success = false, error = access_error }
        end
        if allowed then
            return { success = false, error = "key_already_exists" }
        end

        local current_owned, current_error = get_owned_property_ids(identifier)
        if not current_owned then
            return { success = false, error = current_error }
        end
        if not current_owned[property_id] then
            return { success = false, error = "owner_required" }
        end

        local _, success = call_export("AddKeyholder", function()
            return exports[resource_name]:AddKeyholder(property_id, target_identifier)
        end)
        if not success then
            return { success = false, error = "provider_error" }
        end

        local allowed_after, verify_error = has_key(property_id, target_identifier)
        if allowed_after == nil then
            return { success = false, error = verify_error }
        end
        return allowed_after
            and { success = true }
            or { success = false, error = "action_failed" }
    end

    local target_identifier = non_empty_string(data.identifier)
    if not target_identifier or same_identifier(target_identifier, identifier) then
        return { success = false, error = "invalid_target" }
    end
    local exists, key_error = has_keyholder(property_id, target_identifier)
    if exists == nil then
        return { success = false, error = key_error }
    end
    if not exists then
        return { success = false, error = "key_not_found" }
    end

    local current_owned, current_error = get_owned_property_ids(identifier)
    if not current_owned then
        return { success = false, error = current_error }
    end
    if not current_owned[property_id] then
        return { success = false, error = "owner_required" }
    end

    local _, success = call_export("RemoveKeyholder", function()
        return exports[resource_name]:RemoveKeyholder(property_id, target_identifier)
    end)
    if not success then
        return { success = false, error = "provider_error" }
    end

    local exists_after, verify_error = has_keyholder(property_id, target_identifier)
    if exists_after == nil then
        return { success = false, error = verify_error }
    end
    return not exists_after
        and { success = true }
        or { success = false, error = "action_failed" }
end

Bridge.Housing.RegisterProvider(provider_name, {
    resource_name = resource_name,
    is_available = function()
        return GetResourceState(resource_name) == "started"
    end,
    get_overview = get_overview,
    prepare = function(source, action, data)
        if action == "toggle_lock" then
            return nil, "capability_unavailable"
        end
        if action == "open_cctv" then
            return nil, "cctv_unavailable"
        end

        local property, property_id, access, error_code = resolve_property(source, data)
        if not property then
            return nil, error_code
        end
        if action == "set_waypoint" then
            return { coords = entrance_for(property) }
        end
        if access ~= "owner" then
            return nil, "owner_required"
        end
        if action == "key_candidates" then
            local candidates, candidates_error = key_candidates(source, property, property_id)
            if not candidates then
                return nil, candidates_error
            end
            return { candidates = candidates }
        end
        if action == "grant_key" then
            local target = positive_integer(data and data.target)
            if not target then
                return nil, "invalid_target"
            end
            local candidates, candidates_error = key_candidates(source, property, property_id)
            if not candidates then
                return nil, candidates_error
            end
            for _, candidate in ipairs(candidates) do
                if candidate.id == target then
                    return { providerId = tostring(property_id), target = target }
                end
            end
            return nil, "target_not_in_property"
        end
        if action == "revoke_key" then
            local target_identifier = non_empty_string(data and data.identifier)
            local actor_identifier = Bridge.Framework.GetIdentifier(source)
            if not target_identifier or same_identifier(target_identifier, actor_identifier) then
                return nil, "invalid_target"
            end
            local exists, key_error = has_keyholder(property_id, target_identifier)
            if exists == nil then
                return nil, key_error
            end
            if not exists then
                return nil, "key_not_found"
            end
            return { providerId = tostring(property_id), identifier = target_identifier }
        end
        return nil, "invalid_action"
    end,
})

Bridge.Callbacks.Register("sky_phone:housing:rx:execute", function(source, data)
    return execute_key_action(source, data)
end)
