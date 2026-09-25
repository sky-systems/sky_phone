local registered_callbacks = {}
local deferred_callbacks = {}

-- Public background reads can arrive while database-dependent modules are loading.
function Bridge.Callbacks.RegisterDeferred(name)
    assert(type(name) == "string", "Callback name must be a string")
    assert(not registered_callbacks[name] and not deferred_callbacks[name],
        ("Callback '%s' is already registered"):format(name))
    deferred_callbacks[name] = true
    SetTimeout(30000, function()
        if deferred_callbacks[name] then
            Bridge.Debug("warn", "[sky_phone] Server callback '%s' is still waiting for database/module initialization after 30 seconds.", name)
        end
    end)
end

function Bridge.Callbacks.Register(name, callback)
    assert(type(name) == "string", "Callback name must be a string")
    assert(type(callback) == "function", "Callback handler must be a function")
    assert(not registered_callbacks[name], ("Callback '%s' is already registered"):format(name))
    local handler = SkyPhoneLog and SkyPhoneLog.WrapCallback(name, callback) or callback
    registered_callbacks[name] = function(player_source, data)
        if SkyPhoneCellular.RequiresSignal(name, data) and not SkyPhoneCellular.HasSignal(player_source) then
            return { success = false, error = "no_signal" }
        end
        return handler(player_source, data)
    end
    deferred_callbacks[name] = nil
end

RegisterNetEvent("sky_phone:bridge:callback:request", function(name, request_id, data)
    local player_source = source
    if type(name) ~= "string" or type(request_id) ~= "number" or type(data) ~= "table" then
        Bridge.Debug("warn", "[sky_phone] Rejected malformed callback request from source %s.", tostring(player_source))
        return
    end

    local callback = registered_callbacks[name]
    if not callback then
        if deferred_callbacks[name] then
            Bridge.Network.SendClient("sky_phone:bridge:callback:response", player_source, request_id,
                { success = false, error = "server_initializing" })
            return
        end
        Bridge.Debug("error", "[sky_phone] Server callback '%s' is not registered.", name)
        Bridge.Network.SendClient("sky_phone:bridge:callback:response", player_source, request_id, nil)
        return
    end

    local success, result = pcall(callback, player_source, data)
    if not success then
        Bridge.Debug("error", "[sky_phone] Server callback '%s' failed: %s", name, tostring(result))
        Bridge.Network.SendClient("sky_phone:bridge:callback:response", player_source, request_id, nil)
        return
    end

    if not Bridge.Network.SendClient("sky_phone:bridge:callback:response", player_source, request_id, result) then
        Bridge.Debug("error", "[sky_phone] Could not return server callback '%s'.", name)
        Bridge.Network.SendClient("sky_phone:bridge:callback:response", player_source, request_id,
            { success = false, error = "request_failed" })
    end
end)
