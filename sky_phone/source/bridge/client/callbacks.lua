local pending_requests = {}
local next_request_id = 0

function Bridge.Callbacks.Trigger(name, data)
    next_request_id = next_request_id + 1
    local request_id = next_request_id
    local request = promise.new()
    pending_requests[request_id] = request

    TriggerServerEvent("sky_phone:bridge:callback:request", name, request_id, data)

    SetTimeout(Config.Bridge.CallbackTimeout, function()
        if pending_requests[request_id] ~= request then
            return
        end

        pending_requests[request_id] = nil
        Bridge.Debug("error", "[sky_phone] Server callback '%s' timed out.", tostring(name))
        request:resolve(nil)
    end)

    return Citizen.Await(request)
end

RegisterNetEvent("sky_phone:bridge:callback:response", function(request_id, result)
    local request = pending_requests[request_id]
    if not request then
        return
    end

    pending_requests[request_id] = nil
    request:resolve(result)
end)

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name ~= GetCurrentResourceName() then
        return
    end

    for request_id, request in pairs(pending_requests) do
        pending_requests[request_id] = nil
        request:resolve(nil)
    end
end)
