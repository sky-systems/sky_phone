local camera_state = nil

local function server_prepare(action, data)
    local request = {
        action = action,
        propertyId = data and data.propertyId,
        target = data and data.target,
        identifier = data and data.identifier,
    }
    return Bridge.Callbacks.Trigger("sky_phone:housing:prepare", request)
end

local function suspend_phone()
    TriggerEvent("sky_phone:client:setSuspended", true)
    TriggerEvent("sky_phone:animation:phone", false)
    SendNUIMessage({ type = "app:suspend" })
end

local function resume_phone()
    SendNUIMessage({ type = "app:resume" })
    TriggerEvent("sky_phone:client:setSuspended", false)
    TriggerEvent("sky_phone:animation:phone", true)
end

local function stop_camera(resume)
    local state = camera_state
    if not state then
        return
    end
    camera_state = nil
    RenderScriptCams(false, true, 350, true, true)
    if state.camera and DoesCamExist(state.camera) then
        DestroyCam(state.camera, false)
    end
    ClearFocus()
    SetNightvision(state.night_vision)
    if DoesEntityExist(state.ped) then
        FreezeEntityPosition(state.ped, state.frozen)
    end
    if resume ~= false then
        resume_phone()
    end
end

local function camera_number(value, fallback)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge or number == -math.huge then
        return fallback
    end
    return number
end

local function run_camera(provider_name, camera_data)
    if camera_state or type(camera_data) ~= "table"
        or type(camera_data.coords) ~= "table"
        or type(camera_data.rotation) ~= "table"
    then
        return
    end
    local coords = {
        x = camera_number(camera_data.coords.x),
        y = camera_number(camera_data.coords.y),
        z = camera_number(camera_data.coords.z),
    }
    local rotation = {
        x = camera_number(camera_data.rotation.x),
        y = camera_number(camera_data.rotation.y, 0.0),
        z = camera_number(camera_data.rotation.z),
    }
    if not coords.x or not coords.y or not coords.z or not rotation.x or not rotation.z then
        Bridge.Debug("error", "[sky_phone] Rejected invalid housing camera data.")
        return
    end

    local config = Config.Housing.Camera
    local ped = PlayerPedId()
    local camera = CreateCamWithParams(
        "DEFAULT_SCRIPTED_CAMERA",
        coords.x,
        coords.y,
        coords.z,
        rotation.x,
        rotation.y,
        rotation.z,
        config.FieldOfView,
        true,
        2
    )
    if not camera or camera == 0 then
        Bridge.Debug("error", "[sky_phone] Failed to create housing camera.")
        return
    end

    camera_state = {
        camera = camera,
        frozen = IsEntityPositionFrozen(ped),
        night_vision = GetUsingnightvision(),
        ped = ped,
        provider = provider_name,
    }
    suspend_phone()
    FreezeEntityPosition(ped, true)
    SetFocusArea(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0)
    SetCamActive(camera, true)
    RenderScriptCams(true, true, 350, true, true)

    local maximum_left = camera_number(camera_data.maximumLeft)
    local maximum_right = camera_number(camera_data.maximumRight)
    local night_vision = camera_state.night_vision
    local resume_after_camera = false
    local close_phone_after_camera = false
    while camera_state and camera_state.camera == camera do
        Wait(0)
        DisableAllControlActions(0)
        if IsDisabledControlJustPressed(0, config.ExitControl) then
            resume_after_camera = true
            break
        end
        if IsPedDeadOrDying(ped, true) or GetResourceState(provider_name) ~= "started" then
            close_phone_after_camera = true
            break
        end

        local camera_rotation = GetCamRot(camera, 2)
        local next_x = camera_rotation.x
        local next_z = camera_rotation.z
        if IsDisabledControlPressed(0, config.LeftControl)
            and (not maximum_left or next_z < maximum_left)
        then
            next_z = next_z + config.RotateSpeed
        elseif IsDisabledControlPressed(0, config.RightControl)
            and (not maximum_right or next_z > maximum_right)
        then
            next_z = next_z - config.RotateSpeed
        end
        if IsDisabledControlPressed(0, config.UpControl) then
            next_x = math.min(85.0, next_x + config.RotateSpeed)
        elseif IsDisabledControlPressed(0, config.DownControl) then
            next_x = math.max(-85.0, next_x - config.RotateSpeed)
        end
        if next_x ~= camera_rotation.x or next_z ~= camera_rotation.z then
            SetCamRot(camera, next_x, camera_rotation.y, next_z, 2)
        end

        local field_of_view = GetCamFov(camera)
        if IsDisabledControlJustPressed(0, config.ZoomInControl) then
            SetCamFov(camera, math.max(config.MinimumFieldOfView, field_of_view - 3.0))
        elseif IsDisabledControlJustPressed(0, config.ZoomOutControl) then
            SetCamFov(camera, math.min(config.MaximumFieldOfView, field_of_view + 3.0))
        end
        if IsDisabledControlJustPressed(0, config.NightVisionControl) then
            night_vision = not night_vision
            SetNightvision(night_vision)
        end
    end
    stop_camera(resume_after_camera)
    if close_phone_after_camera then
        TriggerEvent("sky_phone:client:forceClose")
    end
end

RegisterNetEvent("sky_phone:device:invalidated", function()
    stop_camera(false)
end)

RegisterNUICallback("housing:overview", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    local result = Bridge.Callbacks.Trigger("sky_phone:housing:overview", {})
    if type(result) == "table" and result.success and type(result.data) == "table" then
        local properties, error_code = Bridge.Housing.EnrichOverview(
            result.data.provider,
            result.data.properties
        )
        if not properties then
            cb({ success = false, error = error_code or "provider_error" })
            return
        end
        result.data.properties = properties
    end
    cb(type(result) == "table" and result or { success = false, error = "request_failed" })
end)

AddEventHandler("sky_phone:client:nuiReady", function()
    if camera_state then
        suspend_phone()
    end
end)

RegisterNUICallback("housing:key-candidates", function(data, cb)
    if type(data) ~= "table" or type(data.propertyId) ~= "string" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    local result = server_prepare("key_candidates", data)
    cb(type(result) == "table" and result or { success = false, error = "request_failed" })
end)

RegisterNUICallback("housing:command", function(data, cb)
    if type(data) ~= "table" or type(data.action) ~= "string" or type(data.propertyId) ~= "string" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    local actions = {
        grant_key = true,
        open_cctv = true,
        revoke_key = true,
        set_waypoint = true,
        toggle_lock = true,
    }
    if not actions[data.action] then
        cb({ success = false, error = "invalid_action" })
        return
    end

    local prepared = server_prepare(data.action, data)
    if type(prepared) ~= "table" or not prepared.success or type(prepared.data) ~= "table" then
        cb(type(prepared) == "table" and prepared or { success = false, error = "request_failed" })
        return
    end
    if data.action == "set_waypoint" then
        local coords = prepared.data.coords
        if coords == nil then
            local success, error_code = Bridge.Housing.Execute(
                prepared.data.provider,
                data.action,
                prepared.data
            )
            cb(success and { success = true }
                or { success = false, error = error_code or "invalid_coordinates" })
            return
        end

        local x = type(coords) == "table" and camera_number(coords.x) or nil
        local y = type(coords) == "table" and camera_number(coords.y) or nil
        if not x or not y then
            cb({ success = false, error = "invalid_coordinates" })
            return
        end
        SetNewWaypoint(x + 0.0, y + 0.0)
        cb({ success = true })
        return
    end
    if data.action == "open_cctv" then
        if type(prepared.data.camera) ~= "table" or type(prepared.data.provider) ~= "string" then
            cb({ success = false, error = "cctv_unavailable" })
            return
        end
        cb({ success = true })
        CreateThread(function()
            run_camera(prepared.data.provider, prepared.data.camera)
        end)
        return
    end

    local success, error_code = Bridge.Housing.Execute(prepared.data.provider, data.action, prepared.data)
    cb(success and { success = true } or { success = false, error = error_code or "provider_rejected" })
end)

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name == GetCurrentResourceName() and camera_state then
        stop_camera(false)
    end
end)
