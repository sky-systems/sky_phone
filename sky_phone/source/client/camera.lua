SkyPhoneCamera = {}

local minimum_zoom = 0.5
local maximum_zoom = 3.0
local mouse_wheel_zoom_step = 0.08
local first_person_view_mode = 4
local front_camera_view_mode = 0
local front_camera_fov = 32.0
local front_camera_distance = 1.05
local front_camera_height = 0.05
local front_camera_target_height = 0.03
local blocked_camera_controls = {
    0, -- INPUT_NEXT_CAMERA
    22, -- INPUT_JUMP
    24, -- INPUT_ATTACK
    25, -- INPUT_AIM
    37, -- INPUT_SELECT_WEAPON
    44, -- INPUT_COVER
    45, -- INPUT_RELOAD
    68, -- INPUT_VEH_AIM
    69, -- INPUT_VEH_ATTACK
    70, -- INPUT_VEH_ATTACK2
    91, -- INPUT_VEH_PASSENGER_AIM
    92, -- INPUT_VEH_PASSENGER_ATTACK
    140, -- INPUT_MELEE_ATTACK_LIGHT
    141, -- INPUT_MELEE_ATTACK_HEAVY
    142, -- INPUT_MELEE_ATTACK_ALTERNATE
    241, -- INPUT_CURSOR_SCROLL_UP
    242, -- INPUT_CURSOR_SCROLL_DOWN
    257, -- INPUT_ATTACK2
    261, -- INPUT_PREV_WEAPON
    262, -- INPUT_NEXT_WEAPON
    263, -- INPUT_MELEE_ATTACK1
    264, -- INPUT_MELEE_ATTACK2
}
local camera_look_controls = {
    1, -- INPUT_LOOK_LR
    2, -- INPUT_LOOK_UD
}
local camera_state = {
    active = false,
    enforcing = false,
    flash_enabled = false,
    flash_thread = false,
    focus_watcher = false,
    front_camera = false,
    front_camera_handle = nil,
    game_input = false,
    landscape = false,
    locked = false,
    applied_nui_focus = true,
    nui_focused = true,
    previous_ped_view = nil,
    previous_radar_hidden = nil,
    previous_vehicle_view = nil,
    walkable = false,
    zoom = 1.0,
}

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
    if not enabled or camera_state.flash_thread then
        return
    end
    camera_state.flash_thread = true
    CreateThread(function()
        while camera_state.flash_enabled do
            draw_flash_light()
            Wait(0)
        end
        camera_state.flash_thread = false
    end)
end

local function get_front_camera_transform(ped)
    local head_position = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
    local forward = GetEntityForwardVector(ped)
    local forward_vector = vector3(forward.x, forward.y, forward.z)
    local camera_offset = forward_vector * front_camera_distance
    local camera_position = head_position + camera_offset + vector3(0.0, 0.0, front_camera_height)
    local to_camera = camera_position - head_position
    local dot = (to_camera.x * forward_vector.x)
        + (to_camera.y * forward_vector.y)
        + (to_camera.z * forward_vector.z)
    if dot < 0.0 then
        camera_position = head_position - camera_offset + vector3(0.0, 0.0, front_camera_height)
    end
    local target_position = head_position + vector3(0.0, 0.0, front_camera_target_height)
    return camera_position, target_position
end

local function apply_front_camera(ped)
    if not camera_state.front_camera_handle or not DoesCamExist(camera_state.front_camera_handle) then
        camera_state.front_camera_handle = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        SetCamFov(camera_state.front_camera_handle, front_camera_fov)
        SetCamActive(camera_state.front_camera_handle, true)
        RenderScriptCams(true, false, 0, true, true)
    end

    local camera_position, target_position = get_front_camera_transform(ped)
    SetCamCoord(
        camera_state.front_camera_handle,
        camera_position.x,
        camera_position.y,
        camera_position.z
    )
    PointCamAtCoord(
        camera_state.front_camera_handle,
        target_position.x,
        target_position.y,
        target_position.z
    )
end

local function clear_front_camera()
    if camera_state.front_camera_handle and DoesCamExist(camera_state.front_camera_handle) then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(camera_state.front_camera_handle, false)
    end
    camera_state.front_camera_handle = nil
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

local function apply_camera_controls()
    for _, control in ipairs(blocked_camera_controls) do
        DisableControlAction(0, control, true)
    end
    if camera_state.locked or camera_state.front_camera then
        for _, control in ipairs(camera_look_controls) do
            DisableControlAction(0, control, true)
        end
    end
    DisablePlayerFiring(PlayerId(), true)
end

local function update_camera_focus_claim()
    TriggerEvent("sky_phone:client:setCameraFocus", {
        active = camera_state.active,
        nuiFocused = camera_state.nui_focused,
    })
end

local set_camera_focus

local function set_camera_zoom(zoom)
    if not zoom or zoom < minimum_zoom or zoom > maximum_zoom then
        return false
    end
    zoom = math.floor((zoom * 100.0) + 0.5) / 100.0
    if camera_state.zoom == zoom then
        return true
    end
    camera_state.zoom = zoom
    SendNUIMessage({ type = "camera:zoom", data = { zoom = zoom } })
    return true
end

local function watch_camera_controls()
    if camera_state.focus_watcher then
        return
    end
    camera_state.focus_watcher = true
    CreateThread(function()
        while camera_state.active do
            apply_camera_controls()
            if camera_state.game_input then
                if
                    IsDisabledControlJustPressed(0, 241)
                    or IsDisabledControlJustPressed(0, 261)
                then
                    set_camera_zoom(
                        math.min(maximum_zoom, camera_state.zoom + mouse_wheel_zoom_step)
                    )
                elseif
                    IsDisabledControlJustPressed(0, 242)
                    or IsDisabledControlJustPressed(0, 262)
                then
                    set_camera_zoom(
                        math.max(minimum_zoom, camera_state.zoom - mouse_wheel_zoom_step)
                    )
                end
                if IsDisabledControlJustReleased(0, 22) then
                    set_camera_focus(true)
                end
            end
            Wait(0)
        end
        camera_state.focus_watcher = false
    end)
end

set_camera_focus = function(focused)
    camera_state.nui_focused = focused
    update_camera_focus_claim()
end

AddEventHandler("sky_phone:client:cameraFocusApplied", function(data)
    if type(data) ~= "table"
        or type(data.active) ~= "boolean"
        or type(data.cursor) ~= "boolean"
        or type(data.focused) ~= "boolean"
        or type(data.gameInput) ~= "boolean"
    then
        return
    end
    camera_state.game_input = data.gameInput
    if camera_state.applied_nui_focus ~= data.focused then
        camera_state.applied_nui_focus = data.focused
        SendNUIMessage({ type = "camera:focus", data = { focused = data.focused } })
    end
    if data.active and data.gameInput then
        watch_camera_controls()
    end
end)

local function set_camera_active(active)
    if camera_state.active == active then
        return
    end
    camera_state.active = active
    TriggerEvent("sky_phone:client:cameraActiveChanged", active)
    if active then
        camera_state.front_camera = false
        camera_state.landscape = false
        camera_state.locked = false
        camera_state.zoom = 1.0
        clear_front_camera()
        camera_state.previous_ped_view = GetFollowPedCamViewMode()
        camera_state.previous_radar_hidden = IsRadarHidden()
        camera_state.previous_vehicle_view = GetFollowVehicleCamViewMode()
        DisplayRadar(false)
        set_camera_focus(true)
        apply_camera_view()
        TriggerEvent("sky_phone:animation:camera", {
            active = true,
            front = camera_state.front_camera,
            landscape = camera_state.landscape,
        })
        if camera_state.enforcing then
            return
        end
        camera_state.enforcing = true
        CreateThread(function()
            while camera_state.active do
                HideHudAndRadarThisFrame()
                if camera_state.front_camera then
                    apply_front_camera(PlayerPedId())
                end
                apply_camera_view()
                Wait(0)
            end
            camera_state.enforcing = false
        end)
        return
    end
    set_flash_enabled(false)
    camera_state.front_camera = false
    camera_state.game_input = false
    camera_state.landscape = false
    camera_state.locked = false
    camera_state.walkable = false
    clear_front_camera()
    restore_camera_view()
    camera_state.nui_focused = true
    update_camera_focus_claim()
    TriggerEvent("sky_phone:animation:camera", {
        active = false,
        front = false,
        landscape = false,
    })
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
        apply_front_camera(PlayerPedId())
    else
        clear_front_camera()
    end
    apply_camera_view()
    TriggerEvent("sky_phone:animation:camera", {
        active = true,
        front = camera_state.front_camera,
        landscape = camera_state.landscape,
    })
end

local function set_camera_landscape(active)
    if camera_state.landscape == active then
        return
    end
    camera_state.landscape = active
    if camera_state.active then
        TriggerEvent("sky_phone:animation:camera", {
            active = true,
            front = camera_state.front_camera,
            landscape = camera_state.landscape,
        })
    end
end

local function enable_walkable_camera(selfie_mode)
    set_camera_active(true)
    camera_state.walkable = true
    set_front_camera(selfie_mode == true)
    set_camera_focus(false)
end

local function disable_walkable_camera()
    if not camera_state.walkable then
        return
    end

    set_camera_active(false)
end

local function toggle_camera_frozen()
    camera_state.locked = not camera_state.locked
end

local function get_camera_state()
    return {
        active = camera_state.active,
        flashEnabled = camera_state.flash_enabled,
        frozen = camera_state.locked,
        selfie = camera_state.front_camera,
        walkable = camera_state.walkable and camera_state.active,
    }
end

SkyPhoneCamera.DisableWalkable = disable_walkable_camera
SkyPhoneCamera.EnableWalkable = enable_walkable_camera
SkyPhoneCamera.GetState = get_camera_state
SkyPhoneCamera.SetFlashlight = set_flash_enabled
SkyPhoneCamera.SetSelfie = set_front_camera
SkyPhoneCamera.ToggleFrozen = toggle_camera_frozen

RegisterNUICallback("camera:setActive", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    if data.active == true then
        camera_state.walkable = false
    end
    set_camera_active(data.active == true)
    cb({ success = true })
end)

RegisterNUICallback("camera:setFocus", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    if camera_state.active then
        set_camera_focus(data.focused == true)
    end
    cb({ success = true })
end)

RegisterNUICallback("camera:setLocked", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    camera_state.locked = data.locked == true
    cb({ success = true })
end)

RegisterNUICallback("camera:setFlash", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    set_flash_enabled(data.enabled == true)
    cb({ success = true })
end)

RegisterNUICallback("camera:setFacing", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    set_front_camera(data.front == true)
    cb({ success = true })
end)

RegisterNUICallback("camera:setOrientation", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    set_camera_landscape(data.landscape == true)
    cb({ success = true })
end)

RegisterNUICallback("camera:setZoom", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    cb({ success = set_camera_zoom(tonumber(data.zoom)) })
end)

RegisterNUICallback("media:requestUpload", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    TriggerServerEvent("sky_phone:media:request-upload", data)
    cb({ success = true })
end)

RegisterNUICallback("media:completeUpload", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    TriggerServerEvent("sky_phone:media:complete-upload", data)
    cb({ success = true })
end)

RegisterNUICallback("media:cancelUpload", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    TriggerServerEvent("sky_phone:media:cancel-upload", data)
    cb({ success = true })
end)

RegisterNUICallback("media:failUpload", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    TriggerServerEvent("sky_phone:media:fail-upload", data)
    cb({ success = true })
end)

RegisterNUICallback("gallery:delete", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    TriggerServerEvent("sky_phone:media:delete", data)
    cb({ success = true })
end)

RegisterNUICallback("gallery:delete-many", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    TriggerServerEvent("sky_phone:media:delete-many", data)
    cb({ success = true })
end)

RegisterNUICallback("memos:requestUpload", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    TriggerServerEvent("sky_phone:memos:request-upload", data)
    cb({ success = true })
end)

RegisterNUICallback("memos:completeUpload", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    TriggerServerEvent("sky_phone:memos:complete-upload", data)
    cb({ success = true })
end)

RegisterNUICallback("memos:cancelUpload", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    TriggerServerEvent("sky_phone:memos:cancel-upload", data)
    cb({ success = true })
end)

RegisterNUICallback("memos:failUpload", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    TriggerServerEvent("sky_phone:memos:fail-upload", data)
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

RegisterNetEvent("sky_phone:media:delete-many-result", function(data)
    SendNUIMessage({ type = "media:deleteManyResult", data = data })
end)

RegisterNetEvent("sky_phone:memos:upload-ready", function(data)
    SendNUIMessage({ type = "memos:uploadReady", data = data })
end)

RegisterNetEvent("sky_phone:memos:upload-result", function(data)
    SendNUIMessage({ type = "memos:uploadResult", data = data })
end)

AddEventHandler("sky_phone:nuiClosed", function()
    set_flash_enabled(false)
    set_camera_active(false)
end)

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name == GetCurrentResourceName() then
        set_flash_enabled(false)
        set_camera_active(false)
    end
end)
