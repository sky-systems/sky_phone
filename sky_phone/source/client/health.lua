local pending_steps = 0
local pending_distance = 0.0
local pending_active_seconds = 0.0
local step_progress = 0.0
local last_coords = nil
local last_report_at = GetGameTimer()

local function flush_activity()
    last_report_at = GetGameTimer()
    local distance_meters = math.floor(pending_distance + 0.5)
    local active_seconds = math.floor(pending_active_seconds + 0.5)
    if pending_steps == 0 and distance_meters == 0 and active_seconds == 0 then
        return
    end

    TriggerServerEvent("sky_phone:health:record-activity", {
        steps = pending_steps,
        distanceMeters = distance_meters,
        activeSeconds = active_seconds,
    })
    pending_steps = 0
    pending_distance = 0.0
    pending_active_seconds = 0.0
end

CreateThread(function()
    while true do
        Wait(Config.Health.SampleIntervalMs)

        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            local coords = GetEntityCoords(ped)
            if last_coords then
                local delta_x = coords.x - last_coords.x
                local delta_y = coords.y - last_coords.y
                local distance = math.sqrt(delta_x * delta_x + delta_y * delta_y)
                local maximum_sample_distance = Config.Health.MaximumSpeedMetersPerSecond
                    * Config.Health.SampleIntervalMs / 1000.0
                -- A stationary sample or teleport cannot contribute activity.
                if distance >= 0.04 and distance <= maximum_sample_distance
                    and IsPedOnFoot(ped)
                    and not IsPedDeadOrDying(ped, true)
                    and not IsPedFalling(ped)
                    and not IsPedRagdoll(ped)
                then
                    local sprinting = IsPedSprinting(ped)
                    local running = not sprinting and IsPedRunning(ped)
                    if sprinting or running or IsPedWalking(ped) then
                        local stride_length = sprinting and 1.15 or (running and 1.0 or 0.75)

                        pending_distance = pending_distance + distance
                        pending_active_seconds = pending_active_seconds + Config.Health.SampleIntervalMs / 1000.0
                        step_progress = step_progress + distance
                        while step_progress >= stride_length do
                            step_progress = step_progress - stride_length
                            pending_steps = pending_steps + 1
                        end
                    end
                end
            end
            last_coords = coords
        else
            last_coords = nil
        end

        if GetGameTimer() - last_report_at >= Config.Health.ReportIntervalSeconds * 1000 then
            flush_activity()
        end
    end
end)

AddEventHandler("playerSpawned", function()
    last_coords = nil
end)

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name == GetCurrentResourceName() then
        flush_activity()
    end
end)

RegisterNUICallback("health:overview", function(data, cb)
    local result = Bridge.Callbacks.Trigger("sky_phone:health:overview", data or {})
    cb(result or { success = false, error = "request_failed" })
end)

RegisterNUICallback("health:save-profile", function(data, cb)
    local result = Bridge.Callbacks.Trigger("sky_phone:health:save-profile", data or {})
    cb(result or { success = false, error = "request_failed" })
end)

RegisterNetEvent("sky_phone:health:changed", function()
    SendNUIMessage({ type = "health:changed" })
end)
