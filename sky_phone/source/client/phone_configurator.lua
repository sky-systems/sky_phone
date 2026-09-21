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
    if value.__skyType == "map" then
        local decoded = {}
        for _, entry in ipairs(value.entries or {}) do
            local key = entry.keyType == "number" and tonumber(entry.key) or entry.key
            decoded[key] = deserialize_value(entry.value)
        end
        return decoded
    end

    local decoded = {}
    for key, child in pairs(value) do
        decoded[key] = deserialize_value(child)
    end
    return decoded
end

local function apply_runtime_table(current, replacement)
    for key in pairs(current) do
        if replacement[key] == nil then
            current[key] = nil
        end
    end

    for key, value in pairs(replacement) do
        local current_value = current[key]
        if type(current_value) == "table" and type(value) == "table" then
            apply_runtime_table(current_value, value)
        else
            current[key] = value
        end
    end
end

local current_revision = -1
local requested_revision = -1
local resync_running = false
local request_runtime

local function apply_runtime_config(payload)
    if type(payload) ~= "table" or payload.enabled ~= true then
        return
    end
    if type(payload.config) ~= "table" then
        error("[sky_phone] Phone configurator received an invalid client configuration payload.")
    end
    local next_revision = tonumber(payload.revision)
    if not next_revision or next_revision <= current_revision then return end
    if payload.baseRevision ~= nil and payload.baseRevision ~= current_revision then
        requested_revision = math.max(requested_revision, next_revision)
        request_runtime()
        return
    end

    local runtime_config = deserialize_value(payload.config)
    for _, key in ipairs(payload.removed or {}) do Config[key] = nil end
    for key, value in pairs(runtime_config) do
        if type(Config[key]) == "table" and type(value) == "table" then
            apply_runtime_table(Config[key], value)
        else
            Config[key] = value
        end
    end
    current_revision = next_revision
    TriggerEvent("sky_phone:configurator:updated", current_revision)
end

request_runtime = function()
    if resync_running then return end
    resync_running = true
    repeat
        local before = current_revision
        local response = Bridge.Callbacks.Trigger("sky_phone:configurator:runtime", {})
        if not response or not response.success or type(response.data) ~= "table" then
            resync_running = false
            error("[sky_phone] Phone configurator failed to load the client runtime configuration.")
        end
        apply_runtime_config(response.data)
        if current_revision == before and current_revision < requested_revision then
            resync_running = false
            error("[sky_phone] Phone configurator received a stale recovery snapshot.")
        end
    until current_revision >= requested_revision
    resync_running = false
end

RegisterNetEvent("sky_phone:configurator:sync", function(payload)
    apply_runtime_config(payload)
end)

request_runtime()
