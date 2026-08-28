local AUDIO_TRANSFER_TIMEOUT_MS = math.max(15000, tonumber(Config.Bridge.CallbackTimeout) or 0)
local MAX_AUDIO_REQUEST_ID = 2147483646
local MAX_PENDING_AUDIO_REQUESTS = 2
local next_audio_request_id = 0
local pending_audio_requests = {}
local pending_audio_request_count = 0

RegisterNetEvent("sky_phone:tones:audio-response", function(request_id, result)
    local request = pending_audio_requests[request_id]
    if not request then
        return
    end

    pending_audio_requests[request_id] = nil
    pending_audio_request_count = pending_audio_request_count - 1
    if type(result) == "table" then
        request:resolve(result)
        return
    end

    request:resolve({ success = false, error = "request_failed" })
end)

RegisterNUICallback("tones:audio", function(data, cb)
    local tone_id = type(data) == "table" and data.id or nil
    if type(tone_id) ~= "string" or tone_id == "" or #tone_id > 128 then
        cb({ success = false, error = "invalid_request" })
        return
    end
    if pending_audio_request_count >= MAX_PENDING_AUDIO_REQUESTS then
        cb({ success = false, error = "request_in_progress" })
        return
    end

    next_audio_request_id = next_audio_request_id % MAX_AUDIO_REQUEST_ID + 1
    local request_id = next_audio_request_id
    local request = promise.new()
    pending_audio_requests[request_id] = request
    pending_audio_request_count = pending_audio_request_count + 1

    TriggerServerEvent("sky_phone:tones:audio-request", request_id, tone_id)
    SetTimeout(AUDIO_TRANSFER_TIMEOUT_MS, function()
        if pending_audio_requests[request_id] ~= request then
            return
        end

        pending_audio_requests[request_id] = nil
        pending_audio_request_count = pending_audio_request_count - 1
        Bridge.Debug(
            "error",
            "[sky_phone] Custom tone audio request '%s' timed out.",
            tostring(tone_id)
        )
        request:resolve({ success = false, error = "request_timeout" })
    end)

    local result = Citizen.Await(request)
    if type(result) == "table" then
        cb(result)
        return
    end

    cb({ success = false, error = "request_failed" })
end)

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name ~= GetCurrentResourceName() then
        return
    end

    for request_id, request in pairs(pending_audio_requests) do
        pending_audio_requests[request_id] = nil
        request:resolve({ success = false, error = "resource_stopped" })
    end
    pending_audio_request_count = 0
end)
