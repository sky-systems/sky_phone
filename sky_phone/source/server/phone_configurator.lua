SkyPhoneConfigurator = SkyPhoneConfigurator or {}

local TABLE_NAME = "sky_phone_configurator"
local CONFIG_ROW_ID = 1
local MAX_CHANGES = 1000
local MAX_PAYLOAD_BYTES = 8 * 1024 * 1024
local REDACTED_VALUE = "***REDACTED***"
local configurator_enabled = Config.PhoneConfigurator.Enabled == true
local default_config
local default_media
local stored_config
local stored_media
local revision = 1
local updated_at
local updated_by_name

local CLIENT_CONFIG_KEYS = {
    AdminPanel = true,
    Animations = true,
    Banking = true,
    Billing = true,
    Bridge = true,
    Calendar = true,
    Calls = true,
    Command = true,
    CrewLink = true,
    Crypto = true,
    CustomApps = true,
    DarkChat = true,
    EasyShare = true,
    Feather = true,
    FlipTok = true,
    Garage = true,
    Health = true,
    Housing = true,
    LocalPages = true,
    Mail = true,
    MapMarkers = true,
    Marketplace = true,
    Memos = true,
    Messages = true,
    Payphones = true,
    Phone = true,
    Picstagram = true,
    Radio = true,
    Security = true,
    Sim = true,
    SkyRide = true,
    Speaker = true,
    TestData = true,
}

local function copy_value(value, active)
    local value_type = type(value)
    if value_type ~= "table" then
        return value
    end

    active = active or {}
    if active[value] then
        error("[sky_phone] Phone configurator cannot copy a cyclic table.")
    end
    active[value] = true

    local copy = {}
    for key, child in pairs(value) do
        copy[key] = copy_value(child, active)
    end
    active[value] = nil
    return copy
end

local function serialize_value(value, active)
    local value_type = type(value)
    if value_type == "nil" or value_type == "boolean" or value_type == "string" then
        return value
    end
    if value_type == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            error("[sky_phone] Phone configurator cannot serialize a non-finite number.")
        end
        return value
    end
    if value_type == "vector2" then
        return { __skyType = "vector2", x = value.x, y = value.y }
    end
    if value_type == "vector3" then
        return { __skyType = "vector3", x = value.x, y = value.y, z = value.z }
    end
    if value_type == "vector4" then
        return { __skyType = "vector4", x = value.x, y = value.y, z = value.z, w = value.w }
    end
    if value_type ~= "table" then
        error(("[sky_phone] Phone configurator cannot serialize value type '%s'."):format(value_type))
    end

    active = active or {}
    if active[value] then
        error("[sky_phone] Phone configurator cannot serialize a cyclic table.")
    end
    active[value] = true

    local serialized = {}
    for key, child in pairs(value) do
        if type(key) ~= "string" and type(key) ~= "number" then
            error("[sky_phone] Phone configurator only supports string and numeric table keys.")
        end
        serialized[key] = serialize_value(child, active)
    end
    active[value] = nil
    return serialized
end

local function deserialize_value(value)
    if type(value) ~= "table" then
        return value
    end

    if value.__skyType == "vector2" then
        return vector2(tonumber(value.x) or 0.0, tonumber(value.y) or 0.0)
    end
    if value.__skyType == "vector3" then
        return vector3(tonumber(value.x) or 0.0, tonumber(value.y) or 0.0, tonumber(value.z) or 0.0)
    end
    if value.__skyType == "vector4" then
        return vector4(
            tonumber(value.x) or 0.0,
            tonumber(value.y) or 0.0,
            tonumber(value.z) or 0.0,
            tonumber(value.w) or 0.0
        )
    end

    local decoded = {}
    for key, child in pairs(value) do
        decoded[key] = deserialize_value(child)
    end
    return decoded
end

local function is_sequence(value)
    if type(value) ~= "table" then
        return false
    end

    local count = 0
    local maximum = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false
        end
        count = count + 1
        maximum = math.max(maximum, key)
    end
    return count > 0 and count == maximum
end

local function merge_values(defaults, saved)
    if type(defaults) ~= "table" or type(saved) ~= "table" then
        return copy_value(saved)
    end
    if defaults.__skyType or saved.__skyType or is_sequence(defaults) or is_sequence(saved) then
        return copy_value(saved)
    end

    local merged = copy_value(defaults)
    for key, child in pairs(saved) do
        if merged[key] ~= nil then
            merged[key] = merge_values(merged[key], child)
        else
            merged[key] = copy_value(child)
        end
    end
    return merged
end

local function decode_payload(encoded, scope)
    if type(encoded) ~= "string" or encoded == "" then
        error(("[sky_phone] Phone configurator has an empty %s SQL payload."):format(scope))
    end

    local success, decoded = pcall(json.decode, encoded)
    if not success or type(decoded) ~= "table" then
        error(("[sky_phone] Phone configurator failed to decode the %s SQL payload."):format(scope))
    end
    return decoded
end

local function encode_payload(payload, scope)
    local success, encoded = pcall(json.encode, payload)
    if not success or type(encoded) ~= "string" then
        error(("[sky_phone] Phone configurator failed to encode the %s SQL payload."):format(scope))
    end
    if #encoded > MAX_PAYLOAD_BYTES then
        error(("[sky_phone] Phone configurator %s payload exceeds %s bytes."):format(scope, MAX_PAYLOAD_BYTES))
    end
    return encoded
end

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end
    return type(result) == "table" and tonumber(result.affectedRows) or 0
end

local function apply_runtime_configuration()
    if not configurator_enabled then
        return
    end

    local runtime_config = deserialize_value(stored_config)
    for key, value in pairs(runtime_config) do
        Config[key] = value
    end
    Config.Media = deserialize_value(stored_media)
end

local function humanize(value)
    local text = tostring(value or "")
        :gsub("[_%-]+", " ")
        :gsub("(%l)(%u)", "%1 %2")
        :gsub("(%a)(%d)", "%1 %2")
    return text:gsub("^%l", string.upper)
end

local function sensitive_path(path)
    local leaf = tostring(path):match("([^.]+)$") or path
    local normalized = leaf:lower():gsub("[^%w]", "")
    if normalized:find("apikey", 1, true)
        or normalized:find("secret", 1, true)
        or normalized:find("pepper", 1, true)
        or normalized == "password"
        or normalized == "token"
        or normalized == "authorization"
        or normalized == "credential"
        or normalized == "connectionstring"
    then
        return true
    end
    return false
end

local function mask_admin_value(value, path)
    if type(value) ~= "table" then
        return type(value) == "string" and sensitive_path(path) and REDACTED_VALUE or value
    end

    local masked = {}
    for key, child in pairs(value) do
        masked[key] = mask_admin_value(child, path .. "." .. tostring(key))
    end
    return masked
end

local function restore_redacted_values(value, current, path)
    if type(value) ~= "table" then
        if value == REDACTED_VALUE and sensitive_path(path) then
            return current
        end
        return value
    end

    local restored = {}
    for key, child in pairs(value) do
        local current_child = type(current) == "table" and current[key] or nil
        restored[key] = restore_redacted_values(child, current_child, path .. "." .. tostring(key))
    end
    return restored
end

local function add_field(fields, field_index, scope, path, value)
    local value_type = type(value)
    local field_type = value_type
    if value_type == "table" then
        field_type = "json"
    elseif value_type ~= "boolean" and value_type ~= "number" and value_type ~= "string" then
        return
    end

    local sensitive = type(value) == "string" and sensitive_path(path)
    local field = {
        configured = sensitive and value ~= "" or nil,
        label = humanize(path:match("([^.]+)$") or path),
        path = path,
        scope = scope,
        sensitive = sensitive,
        type = field_type,
        value = sensitive and "" or mask_admin_value(value, path),
    }
    fields[#fields + 1] = field
    field_index[scope .. ":" .. path] = field
end

local function flatten_fields(fields, field_index, scope, path, value)
    if type(value) ~= "table" or value.__skyType or is_sequence(value) or next(value) == nil then
        add_field(fields, field_index, scope, path, value)
        return
    end

    local keys = {}
    for key in pairs(value) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(left, right)
        return tostring(left) < tostring(right)
    end)
    for _, key in ipairs(keys) do
        local child_path = path == "" and tostring(key) or (path .. "." .. tostring(key))
        flatten_fields(fields, field_index, scope, child_path, value[key])
    end
end

local function build_sections(scope, payload, sections, field_index)
    local general_fields = {}
    local keys = {}
    for key in pairs(payload) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(left, right)
        return tostring(left) < tostring(right)
    end)

    for _, key in ipairs(keys) do
        local value = payload[key]
        if type(value) == "table" and not value.__skyType and not is_sequence(value) and next(value) ~= nil then
            local fields = {}
            flatten_fields(fields, field_index, scope, tostring(key), value)
            table.sort(fields, function(left, right)
                return left.path < right.path
            end)
            sections[#sections + 1] = {
                fields = fields,
                id = scope .. ":" .. tostring(key),
                label = humanize(key),
                scope = scope,
            }
        else
            add_field(general_fields, field_index, scope, tostring(key), value)
        end
    end

    if #general_fields > 0 then
        table.insert(sections, scope == "config" and 1 or (#sections + 1), {
            fields = general_fields,
            id = scope .. ":general",
            label = "General",
            scope = scope,
        })
    end
end

local function build_admin_data()
    local sections = {}
    local field_index = {}
    build_sections("config", stored_config, sections, field_index)
    build_sections("media", stored_media, sections, field_index)
    return {
        enabled = configurator_enabled,
        revision = revision,
        sections = sections,
        updatedAt = updated_at,
        updatedBy = updated_by_name,
    }, field_index
end

local function split_path(path)
    local parts = {}
    for part in path:gmatch("[^.]+") do
        parts[#parts + 1] = part
    end
    return parts
end

local function set_path(root, path, value)
    local parts = split_path(path)
    if #parts == 0 then
        return false
    end

    local parent = root
    for index = 1, #parts - 1 do
        parent = parent[parts[index]]
        if type(parent) ~= "table" then
            return false
        end
    end
    parent[parts[#parts]] = value
    return true
end

local function get_path(root, path)
    local value = root
    for _, part in ipairs(split_path(path)) do
        if type(value) ~= "table" then
            return nil
        end
        value = value[part]
    end
    return value
end

local function normalize_change_value(field, value)
    if field.type == "boolean" then
        return type(value) == "boolean" and value or nil
    end
    if field.type == "number" then
        if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
            return nil
        end
        return value
    end
    if field.type == "string" then
        if type(value) ~= "string" or #value > 65535 or value == REDACTED_VALUE then
            return nil
        end
        return value
    end
    if field.type == "json" and type(value) == "table" then
        return serialize_value(value)
    end
    return nil
end

local function client_payload()
    local payload = {}
    for key in pairs(CLIENT_CONFIG_KEYS) do
        if stored_config[key] ~= nil then
            payload[key] = copy_value(stored_config[key])
        end
    end
    return payload
end

default_config = {}
for key, value in pairs(Config) do
    if key ~= "Media" and key ~= "PhoneConfigurator" then
        default_config[key] = serialize_value(value)
    end
end
default_media = serialize_value(Config.Media)

Bridge.Database.Migrate("sky_phone_configurator", { SkyPhoneConfiguratorSchema })
Bridge.Database.Query(([[
    INSERT IGNORE INTO `%s` (`id`, `config_payload`, `media_payload`, `revision`)
    VALUES (?, ?, ?, 1)
]]):format(TABLE_NAME), {
    CONFIG_ROW_ID,
    encode_payload(default_config, "config"),
    encode_payload(default_media, "media"),
})

local rows = Bridge.Database.Query(([[
    SELECT `config_payload`, `media_payload`, `revision`, `updated_at`, `updated_by_name`
    FROM `%s`
    WHERE `id` = ?
    LIMIT 1
]]):format(TABLE_NAME), { CONFIG_ROW_ID })
local row = rows[1]
if not row then
    error("[sky_phone] Phone configurator could not load its SQL row after initialization.")
end

stored_config = merge_values(default_config, decode_payload(row.config_payload, "config"))
stored_media = merge_values(default_media, decode_payload(row.media_payload, "media"))
revision = tonumber(row.revision) or 1
updated_at = row.updated_at
updated_by_name = row.updated_by_name
apply_runtime_configuration()

function SkyPhoneConfigurator.GetAdminData()
    local data = build_admin_data()
    return data
end

function SkyPhoneConfigurator.Save(expected_revision, changes, actor_identifier, actor_name)
    if not configurator_enabled then
        return { success = false, error = "configurator_disabled" }
    end
    if tonumber(expected_revision) ~= revision then
        return { success = false, error = "revision_conflict", data = SkyPhoneConfigurator.GetAdminData() }
    end
    if type(changes) ~= "table" or #changes < 1 or #changes > MAX_CHANGES then
        return { success = false, error = "invalid_request" }
    end

    local _, field_index = build_admin_data()
    local next_config = copy_value(stored_config)
    local next_media = copy_value(stored_media)
    local seen = {}
    for _, change in ipairs(changes) do
        if type(change) ~= "table" or type(change.scope) ~= "string" or type(change.path) ~= "string" then
            return { success = false, error = "invalid_request" }
        end

        local field_key = change.scope .. ":" .. change.path
        local field = field_index[field_key]
        if not field or seen[field_key] then
            return { success = false, error = "invalid_field" }
        end
        seen[field_key] = true

        local normalized = normalize_change_value(field, change.value)
        if normalized == nil then
            return { success = false, error = "invalid_value" }
        end
        local target = change.scope == "config" and next_config or next_media
        if change.scope ~= "config" and change.scope ~= "media" then
            return { success = false, error = "invalid_field" }
        end
        if field.type == "json" then
            normalized = restore_redacted_values(normalized, get_path(target, change.path), change.path)
        end
        if not set_path(target, change.path, normalized) then
            return { success = false, error = "invalid_field" }
        end
    end

    local config_encoded = encode_payload(next_config, "config")
    local media_encoded = encode_payload(next_media, "media")
    local result = Bridge.Database.Query(([[
        UPDATE `%s`
        SET `config_payload` = ?, `media_payload` = ?, `revision` = `revision` + 1,
            `updated_by_identifier` = ?, `updated_by_name` = ?
        WHERE `id` = ? AND `revision` = ?
    ]]):format(TABLE_NAME), {
        config_encoded,
        media_encoded,
        tostring(actor_identifier or ""):sub(1, 80),
        tostring(actor_name or ""):sub(1, 120),
        CONFIG_ROW_ID,
        revision,
    })
    if affected_rows(result) ~= 1 then
        local latest = Bridge.Database.Query(("SELECT `revision` FROM `%s` WHERE `id` = ? LIMIT 1"):format(TABLE_NAME), {
            CONFIG_ROW_ID,
        })
        revision = latest[1] and tonumber(latest[1].revision) or revision
        return { success = false, error = "revision_conflict", data = SkyPhoneConfigurator.GetAdminData() }
    end

    stored_config = next_config
    stored_media = next_media
    revision = revision + 1
    updated_at = os.date("!%Y-%m-%d %H:%M:%S")
    updated_by_name = tostring(actor_name or ""):sub(1, 120)
    apply_runtime_configuration()
    TriggerClientEvent("sky_phone:configurator:sync", -1, {
        config = client_payload(),
        enabled = true,
        revision = revision,
    })

    return { success = true, data = SkyPhoneConfigurator.GetAdminData() }
end

Bridge.Callbacks.Register("sky_phone:configurator:runtime", function()
    return {
        success = true,
        data = {
            config = configurator_enabled and client_payload() or {},
            enabled = configurator_enabled,
            revision = revision,
        },
    }
end)

Bridge.Debug(
    "info",
    "[sky_phone] Phone configurator initialized enabled=%s revision=%s.",
    tostring(configurator_enabled),
    tostring(revision)
)
