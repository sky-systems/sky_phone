local MODE_HIDDEN = "hidden"
local MODE_PHONE_READ = "phone_read"
local MODE_CALL = "call"
local MODE_CAMERA_REAR = "camera_rear"
local MODE_CAMERA_SELFIE = "camera_selfie"
local LOOPED_UPPER_BODY_FLAGS = 49
local TRANSITION_UPPER_BODY_FLAGS = 48

local animation_state = {
    call_direction = nil,
    call_state = nil,
    camera_active = false,
    camera_front = false,
    camera_landscape = false,
    current_animation = nil,
    current_mode = MODE_HIDDEN,
    ped = nil,
    phone_open = false,
    prop = nil,
    revision = 0,
    watcher_active = false,
}

local reevaluate

local function load_model(model_hash)
    RequestModel(model_hash)
    local deadline = GetGameTimer() + Config.Animations.LoadTimeoutMs
    while not HasModelLoaded(model_hash) do
        if GetGameTimer() >= deadline then
            Bridge.Debug(
                "error",
                "[sky_phone] Timed out loading phone prop model '%s'.",
                Config.Animations.PropModel
            )
            return false
        end
        Wait(0)
    end
    return true
end

local function load_animation_dictionary(dictionary)
    RequestAnimDict(dictionary)
    local deadline = GetGameTimer() + Config.Animations.LoadTimeoutMs
    while not HasAnimDictLoaded(dictionary) do
        if GetGameTimer() >= deadline then
            Bridge.Debug(
                "error",
                "[sky_phone] Timed out loading animation dictionary '%s'.",
                dictionary
            )
            return false
        end
        Wait(0)
    end
    return true
end

local function can_animate(ped)
    if not DoesEntityExist(ped) or IsEntityDead(ped) then
        return false
    end
    if IsPedRagdoll(ped) or IsPedFalling(ped) or IsPedClimbing(ped) then
        return false
    end
    if IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped) or IsPedInParachuteFreeFall(ped) then
        return false
    end
    return true
end

local function get_phone_dictionary(ped)
    if not IsPedInAnyVehicle(ped, false) then
        return Config.Animations.Dictionaries.OnFoot, "on_foot"
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if GetPedInVehicleSeat(vehicle, -1) == ped then
        return Config.Animations.Dictionaries.Driver, "driver:" .. tostring(vehicle)
    end
    return Config.Animations.Dictionaries.Passenger, "passenger:" .. tostring(vehicle)
end

local function derive_mode()
    if not Config.Animations.Enabled then
        return MODE_HIDDEN
    end
    if animation_state.call_state == "connected" then
        return MODE_CALL
    end
    if animation_state.call_state == "ringing" and animation_state.call_direction == "outgoing" then
        return MODE_CALL
    end
    if animation_state.camera_active and animation_state.camera_front then
        return MODE_CAMERA_SELFIE
    end
    if animation_state.camera_active then
        return MODE_CAMERA_REAR
    end
    if animation_state.call_state == "ringing" or animation_state.phone_open then
        return MODE_PHONE_READ
    end
    return MODE_HIDDEN
end

local function stop_current_animation()
    local current = animation_state.current_animation
    if not current then
        return
    end

    local ped = animation_state.ped
    if ped and DoesEntityExist(ped) then
        StopAnimTask(ped, current.dictionary, current.clip, 3.0)
    end
    animation_state.current_animation = nil
end

local function delete_phone_prop()
    local prop = animation_state.prop
    if not prop then
        animation_state.ped = nil
        return true
    end
    if not DoesEntityExist(prop) then
        animation_state.prop = nil
        animation_state.ped = nil
        return true
    end

    DetachEntity(prop, true, true)
    SetEntityAsMissionEntity(prop, true, true)
    DeleteEntity(prop)
    if DoesEntityExist(prop) then
        Bridge.Debug("error", "[sky_phone] Failed to delete the attached phone prop.")
        return false
    end

    animation_state.prop = nil
    animation_state.ped = nil
    return true
end

local function cleanup_phone()
    stop_current_animation()
    delete_phone_prop()
end

local function ensure_phone_prop(ped, revision)
    if animation_state.prop and DoesEntityExist(animation_state.prop) and animation_state.ped == ped then
        return true
    end

    if animation_state.prop then
        delete_phone_prop()
    end

    local model_hash = joaat(Config.Animations.PropModel)
    if not load_model(model_hash) then
        return false
    end
    if animation_state.revision ~= revision then
        SetModelAsNoLongerNeeded(model_hash)
        return false
    end

    local coords = GetEntityCoords(ped)
    local prop = CreateObject(model_hash, coords.x, coords.y, coords.z, true, true, false)
    SetModelAsNoLongerNeeded(model_hash)
    if not prop or prop == 0 or not DoesEntityExist(prop) then
        Bridge.Debug("error", "[sky_phone] Failed to create the phone prop.")
        return false
    end

    SetEntityCollision(prop, false, false)
    animation_state.prop = prop
    animation_state.ped = ped
    return true
end

local function get_transform(mode)
    if (mode == MODE_CAMERA_REAR or mode == MODE_CAMERA_SELFIE) and animation_state.camera_landscape then
        return Config.Animations.Transforms.Landscape
    end
    return Config.Animations.Transforms.Portrait
end

local function attach_phone_prop(ped, mode)
    local transform = get_transform(mode)
    local position = transform.position
    local rotation = transform.rotation
    AttachEntityToEntity(
        animation_state.prop,
        ped,
        GetPedBoneIndex(ped, Config.Animations.PropBone),
        position.x,
        position.y,
        position.z,
        rotation.x,
        rotation.y,
        rotation.z,
        true,
        false,
        false,
        false,
        2,
        true
    )
end

local function play_animation(ped, dictionary, clip, looped, revision)
    if not load_animation_dictionary(dictionary) or animation_state.revision ~= revision then
        return nil
    end

    local duration = -1
    local flags = LOOPED_UPPER_BODY_FLAGS
    if not looped then
        local duration_seconds = GetAnimDuration(dictionary, clip)
        if duration_seconds <= 0.0 then
            Bridge.Debug(
                "error",
                "[sky_phone] Animation '%s' was not found in dictionary '%s'.",
                clip,
                dictionary
            )
            return nil
        end
        duration = math.max(1, math.floor(duration_seconds * 1000.0))
        flags = TRANSITION_UPPER_BODY_FLAGS
    end

    stop_current_animation()
    TaskPlayAnim(ped, dictionary, clip, 4.0, -4.0, duration, flags, 1.0, false, false, false)
    animation_state.current_animation = {
        clip = clip,
        dictionary = dictionary,
    }
    return duration
end

local function get_base_animation(ped, mode)
    local dictionary = get_phone_dictionary(ped)
    if mode == MODE_CALL then
        return dictionary, Config.Animations.Clips.CallListen
    end
    if
        (mode == MODE_CAMERA_REAR or mode == MODE_CAMERA_SELFIE)
        and not IsPedInAnyVehicle(ped, false)
    then
        return Config.Animations.Dictionaries.Camera, Config.Animations.Clips.Camera
    end
    return dictionary, Config.Animations.Clips.TextRead
end

local function get_transition_clip(previous_mode, mode)
    if previous_mode == MODE_HIDDEN then
        return Config.Animations.Clips.TextIn
    end
    if previous_mode == MODE_CALL and mode ~= MODE_CALL then
        return Config.Animations.Clips.CallToText
    end
    if previous_mode ~= MODE_CALL and mode == MODE_CALL then
        return Config.Animations.Clips.TextToCall
    end
    return nil
end

local function apply_visible_mode(previous_mode, mode, revision)
    local ped = PlayerPedId()
    if not can_animate(ped) or not ensure_phone_prop(ped, revision) then
        return
    end

    attach_phone_prop(ped, mode)
    local transition_clip = get_transition_clip(previous_mode, mode)
    if transition_clip then
        local dictionary = get_phone_dictionary(ped)
        local duration = play_animation(ped, dictionary, transition_clip, false, revision)
        if not duration then
            cleanup_phone()
            return
        end
        Wait(duration)
        if animation_state.revision ~= revision or not can_animate(ped) then
            return
        end
        attach_phone_prop(ped, mode)
    end

    local dictionary, clip = get_base_animation(ped, mode)
    if not play_animation(ped, dictionary, clip, true, revision) then
        cleanup_phone()
    end
end

local function apply_hidden_mode(previous_mode, revision)
    local ped = animation_state.ped
    if not ped or not DoesEntityExist(ped) or not animation_state.prop or not DoesEntityExist(animation_state.prop) then
        cleanup_phone()
        return
    end

    local clip = previous_mode == MODE_CALL and Config.Animations.Clips.CallOut or Config.Animations.Clips.TextOut
    local dictionary = get_phone_dictionary(ped)
    local duration = play_animation(ped, dictionary, clip, false, revision)
    if not duration then
        cleanup_phone()
        return
    end
    Wait(duration)
    if animation_state.revision == revision then
        cleanup_phone()
    end
end

local function apply_mode(previous_mode, mode, revision)
    if mode == MODE_HIDDEN then
        apply_hidden_mode(previous_mode, revision)
        return
    end
    apply_visible_mode(previous_mode, mode, revision)
end

local function ensure_context_watcher()
    if animation_state.watcher_active or derive_mode() == MODE_HIDDEN then
        return
    end

    animation_state.watcher_active = true
    CreateThread(function()
        local observed_ped = nil
        local observed_context = nil
        local was_available = false
        while derive_mode() ~= MODE_HIDDEN do
            local ped = PlayerPedId()
            local available = can_animate(ped)
            local context = "unavailable"
            if available then
                local _, current_context = get_phone_dictionary(ped)
                context = current_context
            end

            if not available and (was_available or animation_state.prop) then
                animation_state.revision = animation_state.revision + 1
                animation_state.current_mode = MODE_HIDDEN
                cleanup_phone()
            elseif available and (not was_available or observed_ped ~= ped or observed_context ~= context) then
                reevaluate(true)
            end

            observed_ped = ped
            observed_context = context
            was_available = available
            Wait(Config.Animations.ContextPollMs)
        end
        animation_state.watcher_active = false
    end)
end

reevaluate = function(force)
    local mode = derive_mode()
    local ped = PlayerPedId()
    if mode ~= MODE_HIDDEN and not can_animate(ped) then
        animation_state.revision = animation_state.revision + 1
        animation_state.current_mode = MODE_HIDDEN
        cleanup_phone()
        ensure_context_watcher()
        return
    end
    if mode == animation_state.current_mode and not force then
        ensure_context_watcher()
        return
    end

    local previous_mode = animation_state.current_mode
    animation_state.current_mode = mode
    animation_state.revision = animation_state.revision + 1
    local revision = animation_state.revision
    ensure_context_watcher()
    CreateThread(function()
        apply_mode(previous_mode, mode, revision)
    end)
end

AddEventHandler("sky_phone:configurator:updated", function()
    animation_state.revision = animation_state.revision + 1
    cleanup_phone()
    reevaluate(true)
end)

local function reset_animation_state()
    animation_state.phone_open = false
    animation_state.call_state = nil
    animation_state.call_direction = nil
    animation_state.camera_active = false
    animation_state.camera_front = false
    animation_state.camera_landscape = false
    animation_state.current_mode = MODE_HIDDEN
    animation_state.revision = animation_state.revision + 1
    cleanup_phone()
end

AddEventHandler("sky_phone:animation:phone", function(open)
    if type(open) ~= "boolean" then
        Bridge.Debug("warn", "[sky_phone] Ignored invalid phone animation state.")
        return
    end
    animation_state.phone_open = open

    if not open then
        animation_state.camera_active = false
        animation_state.camera_front = false
        animation_state.camera_landscape = false

        if derive_mode() == MODE_HIDDEN then
            animation_state.current_mode = MODE_HIDDEN
            animation_state.revision = animation_state.revision + 1
            cleanup_phone()
            return
        end
    end

    reevaluate(false)
end)

AddEventHandler("sky_phone:animation:call", function(data)
    if type(data) ~= "table" or type(data.state) ~= "string" or type(data.direction) ~= "string" then
        Bridge.Debug("warn", "[sky_phone] Ignored invalid call animation state.")
        return
    end
    animation_state.call_state = data.state
    animation_state.call_direction = data.direction
    reevaluate(false)
end)

AddEventHandler("sky_phone:animation:camera", function(data)
    if type(data) ~= "table" or type(data.active) ~= "boolean" then
        Bridge.Debug("warn", "[sky_phone] Ignored invalid camera animation state.")
        return
    end
    animation_state.camera_active = data.active and animation_state.phone_open
    animation_state.camera_front = data.front == true
    animation_state.camera_landscape = data.landscape == true
    reevaluate(true)
end)

AddEventHandler("sky_phone:animation:reset", reset_animation_state)

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name == GetCurrentResourceName() then
        reset_animation_state()
    end
end)
