local first_person_view_mode = 4
local third_person_view_mode = 1
local front_camera_view_mode = 0
local front_camera_fov = 25.0
local front_camera_distance = 0.75
local front_camera_height = 0.05
local front_camera_target_height = 0.03
local camera_emote = "malemirrorselfie3"
local camera_emote_texture_variation = 8
local camera_state = {
    active = false,
    enforcing = false,
    flash_enabled = false,
    flash_thread = false,
    focus_watcher = false,
    front_camera = false,
    front_camera_handle = nil,
    nui_focused = true,
    previous_ped_view = nil,
    previous_radar_hidden = nil,
    previous_vehicle_view = nil,
}

local function start_camera_emote()
    exports.rpemotes:EmoteCommandStart(camera_emote, camera_emote_texture_variation)
end

local function stop_camera_emote()
    if LocalPlayer.state.currentEmote == camera_emote then
        exports.rpemotes:EmoteCancel(true)
    end
end

local function rotation_to_direction(rotation)
    local z = math.rad(rotation.z)
    local x = math.rad(rotation.x)
    local horizontal = math.abs(math.cos(x))
    return vector3(-math.sin(z) * horizontal, math.cos(z) * horizontal, math.sin(x))
end

local function draw_flash_light()
    local camera_coords = GetGameplayCamCoord()
    local direction = rotation_to_direction(GetGameplayCamRot(2))
    local light_position = camera_coords + (direction * 0.8)
    DrawLightWithRange(light_position.x, light_position.y, light_position.z, 255, 255, 255, 12.0, 8.0)
end

local function set_flash_enabled(enabled)
    camera_state.flash_enabled = enabled
    if not enabled or not camera_state.active or camera_state.flash_thread then
        return
    end
    camera_state.flash_thread = true
    CreateThread(function()
        while camera_state.active and camera_state.flash_enabled do
            draw_flash_light()
            Wait(0)
        end
        camera_state.flash_thread = false
    end)
end

local function apply_camera_view()
    local ped = PlayerPedId()
    local view_mode = camera_state.front_camera and front_camera_view_mode or first_person_view_mode
    if IsPedInAnyVehicle(ped, false) then
        SetFollowVehicleCamViewMode(view_mode)
        return
    end
    SetFollowPedCamViewMode(view_mode)
end

local function front_camera_position(ped)
    local head = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
    local forward = GetEntityForwardVector(ped)
    local forward_vector = vector3(forward.x, forward.y, forward.z)
    local offset = forward_vector * front_camera_distance
    local camera_position = head + offset + vector3(0.0, 0.0, front_camera_height)
    local to_camera = camera_position - head
    local dot = (to_camera.x * forward_vector.x) + (to_camera.y * forward_vector.y) + (to_camera.z * forward_vector.z)
    if dot < 0.0 then
        camera_position = head - offset + vector3(0.0, 0.0, front_camera_height)
    end
    return camera_position, head + vector3(0.0, 0.0, front_camera_target_height)
end

local function ensure_front_camera(ped)
    if camera_state.front_camera_handle and DoesCamExist(camera_state.front_camera_handle) then
        return
    end
    camera_state.front_camera_handle = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamFov(camera_state.front_camera_handle, front_camera_fov)
    SetCamActive(camera_state.front_camera_handle, true)
    RenderScriptCams(true, false, 0, true, true)
end

local function clear_front_camera()
    if camera_state.front_camera_handle and DoesCamExist(camera_state.front_camera_handle) then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(camera_state.front_camera_handle, false)
    end
    camera_state.front_camera_handle = nil
end

local function restore_camera_view()
    if camera_state.previous_ped_view ~= nil then
        SetFollowPedCamViewMode(camera_state.previous_ped_view)
    end
    if camera_state.previous_vehicle_view ~= nil then
        SetFollowVehicleCamViewMode(camera_state.previous_vehicle_view)
    end
    if camera_state.previous_radar_hidden ~= nil then
        DisplayRadar(not camera_state.previous_radar_hidden)
    end
end

local function set_camera_focus(focused)
    if camera_state.nui_focused == focused then
        return
    end
    camera_state.nui_focused = focused
    if focused then
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ type = "camera:focus", data = { focused = true } })
        return
    end
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(true)
    SendNUIMessage({ type = "camera:focus", data = { focused = false } })
    if camera_state.focus_watcher then
        return
    end
    camera_state.focus_watcher = true
    CreateThread(function()
        while camera_state.active and not camera_state.nui_focused do
            if IsControlJustReleased(0, 22) then
                set_camera_focus(true)
                break
            end
            Wait(0)
        end
        camera_state.focus_watcher = false
    end)
end

local function set_camera_active(active)
    if camera_state.active == active then
        return
    end
    camera_state.active = active
    if active then
        start_camera_emote()
        camera_state.front_camera = false
        clear_front_camera()
        camera_state.previous_ped_view = GetFollowPedCamViewMode()
        camera_state.previous_vehicle_view = GetFollowVehicleCamViewMode()
        camera_state.previous_radar_hidden = IsRadarHidden()
        DisplayRadar(false)
        set_camera_focus(true)
        apply_camera_view()
        if camera_state.enforcing then
            return
        end
        camera_state.enforcing = true
        CreateThread(function()
            local next_apply = 0
            while camera_state.active do
                HideHudAndRadarThisFrame()
                if camera_state.front_camera then
                    local ped = PlayerPedId()
                    ensure_front_camera(ped)
                    local camera_position, target = front_camera_position(ped)
                    SetCamCoord(
                        camera_state.front_camera_handle,
                        camera_position.x,
                        camera_position.y,
                        camera_position.z
                    )
                    PointCamAtCoord(camera_state.front_camera_handle, target.x, target.y, target.z)
                end
                local now = GetGameTimer()
                if now >= next_apply then
                    apply_camera_view()
                    next_apply = now + 250
                end
                Wait(0)
            end
            camera_state.enforcing = false
        end)
        return
    end
    camera_state.flash_enabled = false
    camera_state.front_camera = false
    stop_camera_emote()
    clear_front_camera()
    restore_camera_view()
    if not camera_state.nui_focused then
        camera_state.nui_focused = true
        SetNuiFocusKeepInput(false)
        SetNuiFocus(true, true)
    end
end

local function set_front_camera(active)
    if camera_state.front_camera == active then
        return
    end
    camera_state.front_camera = active
    if not camera_state.active then
        return
    end
    if active then
        ensure_front_camera(PlayerPedId())
    else
        clear_front_camera()
    end
    apply_camera_view()
end

RegisterNUICallback("camera:setActive", function(data, cb)
    set_camera_active(data and data.active == true)
    cb({ success = true })
end)

RegisterNUICallback("camera:setFocus", function(data, cb)
    if camera_state.active then
        set_camera_focus(data and data.focused == true)
    end
    cb({ success = true })
end)

RegisterNUICallback("camera:setFlash", function(data, cb)
    set_flash_enabled(data and data.enabled == true)
    cb({ success = true })
end)

RegisterNUICallback("camera:setFacing", function(data, cb)
    set_front_camera(data and data.front == true)
    cb({ success = true })
end)

RegisterNUICallback("media:requestUpload", function(data, cb)
    TriggerServerEvent("sky_phone:media:request-upload", data or {})
    cb({ success = true })
end)

RegisterNUICallback("media:completeUpload", function(data, cb)
    TriggerServerEvent("sky_phone:media:complete-upload", data or {})
    cb({ success = true })
end)

RegisterNUICallback("media:cancelUpload", function(data, cb)
    TriggerServerEvent("sky_phone:media:cancel-upload", data or {})
    cb({ success = true })
end)

RegisterNUICallback("media:failUpload", function(data, cb)
    TriggerServerEvent("sky_phone:media:fail-upload", data or {})
    cb({ success = true })
end)

RegisterNUICallback("gallery:delete", function(data, cb)
    TriggerServerEvent("sky_phone:media:delete", data or {})
    cb({ success = true })
end)

RegisterNetEvent("sky_phone:media:upload-ready", function(data)
    SendNUIMessage({ type = "media:uploadReady", data = data })
end)

RegisterNetEvent("sky_phone:media:upload-result", function(data)
    SendNUIMessage({ type = "media:uploadResult", data = data })
end)

RegisterNetEvent("sky_phone:media:delete-result", function(data)
    SendNUIMessage({ type = "media:deleteResult", data = data })
end)

AddEventHandler("sky_phone:nuiClosed", function()
    set_camera_active(false)
end)

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name == GetCurrentResourceName() then
        set_camera_active(false)
        SetNuiFocusKeepInput(false)
    end
end)
