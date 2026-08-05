local registered_callbacks = {}

function Bridge.Callbacks.Register(name, callback)
    assert(type(name) == "string", "Callback name must be a string")
    assert(type(callback) == "function", "Callback handler must be a function")
    assert(not registered_callbacks[name], ("Callback '%s' is already registered"):format(name))
    registered_callbacks[name] = callback
end

RegisterNetEvent("sky_phone:bridge:callback:request", function(name, request_id, data)
    local player_source = source
    if type(name) ~= "string" or type(request_id) ~= "number" or type(data) ~= "table" then
        Bridge.Debug("warn", "[sky_phone] Rejected malformed callback request from source %s.", tostring(player_source))
        return
    end

    local callback = registered_callbacks[name]
    if not callback then
        Bridge.Debug("error", "[sky_phone] Server callback '%s' is not registered.", name)
        TriggerClientEvent("sky_phone:bridge:callback:response", player_source, request_id, nil)
        return
    end

    local success, result = pcall(callback, player_source, data)
    if not success then
        Bridge.Debug("error", "[sky_phone] Server callback '%s' failed: %s", name, tostring(result))
        TriggerClientEvent("sky_phone:bridge:callback:response", player_source, request_id, nil)
        return
    end

    TriggerClientEvent("sky_phone:bridge:callback:response", player_source, request_id, result)
end)
