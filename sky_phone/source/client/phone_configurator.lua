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

local function apply_runtime_config(payload)
    if type(payload) ~= "table" or payload.enabled ~= true then
        return
    end
    if type(payload.config) ~= "table" then
        error("[sky_phone] Phone configurator received an invalid client configuration payload.")
    end

    local runtime_config = deserialize_value(payload.config)
    for key, value in pairs(runtime_config) do
        if type(Config[key]) == "table" and type(value) == "table" then
            apply_runtime_table(Config[key], value)
        else
            Config[key] = value
        end
    end
    TriggerEvent("sky_phone:configurator:updated", tonumber(payload.revision) or 0)
end

RegisterNetEvent("sky_phone:configurator:sync", function(payload)
    apply_runtime_config(payload)
end)

local response = Bridge.Callbacks.Trigger("sky_phone:configurator:runtime", {})
if not response or not response.success or type(response.data) ~= "table" then
    if Config.PhoneConfigurator.Enabled then
        error("[sky_phone] Phone configurator failed to load the client runtime configuration.")
    end
    return
end
apply_runtime_config(response.data)
