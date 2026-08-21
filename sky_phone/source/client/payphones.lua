local payphone_open = false
local nearest_payphone = nil
local active_booth = nil
local active_call_id = nil
local active_call_state = nil
local active_call_number = nil
local active_call_elapsed_seconds = 0
local active_call_elapsed_updated_at = 0
local active_call_payload = nil
local call_channel = 0
local replacement_prop = nil
local hidden_prop = nil
local animation_scene = nil
local network_animation_scene = nil
local animation_ped = nil
local animation_floor_z = nil
local visuals_starting = false
local visuals_ending = false
local hangup_requested = false
local remote_visuals = {}
local custom_payphone_props = {}

local configured_models = {}
for _, model_name in ipairs(Config.Payphones.Props or {}) do
    configured_models[joaat(model_name)] = model_name
end

local function valid_visual_number(value, maximum)
    local number = tonumber(value)
    if not number or number ~= number or math.abs(number) > maximum then
        return nil
    end
    return number
end

local function restore_remote_visual(id)
    local visual = remote_visuals[id]
    if not visual then
        return
    end
    remote_visuals[id] = nil
    if not visual.hidden_entity or not DoesEntityExist(visual.hidden_entity) then
        return
    end

    for _, other in pairs(remote_visuals) do
        if other.model_hash == visual.model_hash and #(other.coords - visual.coords) < 0.5 then
            other.hidden_entity = other.hidden_entity or visual.hidden_entity
            return
        end
    end
    SetEntityVisible(visual.hidden_entity, true, false)
end

RegisterNetEvent("sky_phone:payphone:visual:start", function(data)
    if type(data) ~= "table" or type(data.id) ~= "string" or type(data.model) ~= "string"
        or tonumber(data.callerSource) == GetPlayerServerId(PlayerId())
    then
        return
    end
    local model_hash = joaat(data.model)
    if not configured_models[model_hash] or type(data.coords) ~= "table" then
        return
    end
    local x = valid_visual_number(data.coords.x, 10000.0)
    local y = valid_visual_number(data.coords.y, 10000.0)
    local z = valid_visual_number(data.coords.z, 2000.0)
    if not x or not y or not z then
        return
    end

    restore_remote_visual(data.id)
    remote_visuals[data.id] = {
        coords = vector3(x, y, z),
        model_hash = model_hash,
        hidden_entity = nil,
    }
end)

RegisterNetEvent("sky_phone:payphone:visual:stop", function(data)
    if type(data) ~= "table" or type(data.id) ~= "string" then
        return
    end
    restore_remote_visual(data.id)
end)

local locale = SkyPhoneLocales.Resolve(Config.Bridge.Locale)

local function load_model(model_hash)
    if HasModelLoaded(model_hash) then
        return true
    end
    RequestModel(model_hash)
    local deadline = GetGameTimer() + Config.Payphones.ModelLoadTimeoutMs
    while not HasModelLoaded(model_hash) and GetGameTimer() < deadline do
        Wait(0)
    end
    return HasModelLoaded(model_hash)
end

local function spawn_custom_payphones()
    local locations = Config.Payphones.CustomLocations or {}
    if not Config.Payphones.Enabled or #locations == 0 then
        return
    end

    local model_name = Config.Payphones.CustomProp
    local model_hash = type(model_name) == "string" and joaat(model_name) or 0
    if not configured_models[model_hash] then
        Bridge.Debug(
            "error",
            "[sky_phone] Config.Payphones.CustomProp must also be listed in Config.Payphones.Props.",
            { always = true }
        )
        return
    end
    if not load_model(model_hash) then
        Bridge.Debug("error", "[sky_phone] The configured custom payphone prop could not be loaded.", {
            always = true,
        })
        return
    end

    for index, coords in ipairs(locations) do
        local coords_type = type(coords)
        local x = (coords_type == "vector4" or coords_type == "table")
            and valid_visual_number(coords.x, 10000.0) or nil
        local y = x and valid_visual_number(coords.y, 10000.0) or nil
        local z = y and valid_visual_number(coords.z, 2000.0) or nil
        local heading = z and valid_visual_number(coords.w, 360000.0) or nil
        if not heading then
            Bridge.Debug(
                "error",
                "[sky_phone] Ignored invalid Config.Payphones.CustomLocations entry %s; use vector4(x, y, z, heading).",
                index,
                { always = true }
            )
        else
            local entity = CreateObjectNoOffset(model_hash, x, y, z, false, true, false)
            if entity == 0 or not DoesEntityExist(entity) then
                Bridge.Debug(
                    "error",
                    "[sky_phone] Failed to spawn custom payphone %s.",
                    index,
                    { always = true }
                )
            else
                SetEntityHeading(entity, heading % 360.0)
                FreezeEntityPosition(entity, true)
                custom_payphone_props[#custom_payphone_props + 1] = entity
            end
        end
    end
    SetModelAsNoLongerNeeded(model_hash)
end

CreateThread(spawn_custom_payphones)

local function load_animation(dictionary)
    if HasAnimDictLoaded(dictionary) then
        return true
    end
    RequestAnimDict(dictionary)
    local deadline = GetGameTimer() + Config.Payphones.ModelLoadTimeoutMs
    while not HasAnimDictLoaded(dictionary) and GetGameTimer() < deadline do
        Wait(0)
    end
    return HasAnimDictLoaded(dictionary)
end

local function leave_call_voice()
    if call_channel == 0 then
        return
    end
    Bridge.Calls.Leave()
    call_channel = 0
end

local function join_call_voice(channel)
    local next_channel = tonumber(channel) or 0
    if not Bridge.Calls.Join(next_channel) then
        Bridge.Debug("error", "[sky_phone] The payphone call could not join the configured voice provider.", {
            always = true,
        })
        return false
    end
    call_channel = next_channel
    return call_channel > 0
end

local function stop_call_visuals()
    local animation = Config.Payphones.Animation
    local ped = animation_ped or PlayerPedId()
    local visuals_active = animation_scene ~= nil or replacement_prop ~= nil
    visuals_starting = false
    visuals_ending = false

    if visuals_active and DoesEntityExist(ped) then
        StopAnimTask(ped, animation.Dictionary, animation.PedClip, 0.0)
        ClearPedTasksImmediately(ped)
    end

    if network_animation_scene then
        NetworkStopSynchronisedScene(network_animation_scene)
        network_animation_scene = nil
        animation_scene = nil
    elseif animation_scene then
        SetSynchronizedSceneHoldLastFrame(animation_scene, false)
        DisposeSynchronizedScene(animation_scene)
        animation_scene = nil
    end

    animation_ped = nil
    animation_floor_z = nil

    if replacement_prop and DoesEntityExist(replacement_prop) then
        StopEntityAnim(replacement_prop, animation.PropClip, animation.Dictionary, 0.0)
        SetEntityVisible(replacement_prop, false, false)
        SetEntityAsMissionEntity(replacement_prop, true, true)
        DeleteEntity(replacement_prop)
    end
    replacement_prop = nil

    if hidden_prop and DoesEntityExist(hidden_prop) then
        SetEntityVisible(hidden_prop, true, false)
    end
    hidden_prop = nil
    RemoveAnimDict(animation.Dictionary)
end

local function keep_animation_ped_grounded()
    if not animation_ped or not animation_floor_z or not DoesEntityExist(animation_ped) then
        return
    end
    local coords = GetEntityCoords(animation_ped)
    if coords.z >= animation_floor_z - 0.15 then
        return
    end
    SetEntityCoordsNoOffset(animation_ped, coords.x, coords.y, animation_floor_z, false, false, false)
    SetEntityVelocity(animation_ped, 0.0, 0.0, 0.0)
end

local function play_hangup_visuals()
    if visuals_ending then
        return
    end
    if not animation_scene or not animation_ped or not DoesEntityExist(animation_ped) then
        stop_call_visuals()
        active_booth = nil
        return
    end

    visuals_ending = true
    local scene = animation_scene
    local starting_phase = math.max(0.0, math.min(1.0, GetSynchronizedScenePhase(scene)))
    local duration_ms = math.max(250, math.floor(tonumber(Config.Payphones.Animation.HangupDurationMs) or 2000))
    local started_at = GetGameTimer()
    SetSynchronizedSceneRate(scene, 0.0)

    CreateThread(function()
        while animation_scene == scene do
            local progress = math.min(1.0, (GetGameTimer() - started_at) / duration_ms)
            local phase = starting_phase * (1.0 - progress)
            SetSynchronizedScenePhase(scene, phase)
            keep_animation_ped_grounded()
            if progress >= 1.0 then
                break
            end
            Wait(0)
        end
        if animation_scene == scene then
            stop_call_visuals()
            active_booth = nil
        end
    end)
end

local function start_call_visuals()
    if visuals_starting or replacement_prop or not active_call_id
        or not active_booth or not DoesEntityExist(active_booth.entity)
    then
        return
    end

    visuals_starting = true
    local expected_call_id = active_call_id
    local booth = active_booth
    local replacement_hash = joaat(Config.Payphones.ReplacementProp)
    local animation = Config.Payphones.Animation
    if not load_model(replacement_hash) or not load_animation(animation.Dictionary) then
        Bridge.Debug("error", "[sky_phone] The payphone animation assets could not be loaded.")
        visuals_starting = false
        SetModelAsNoLongerNeeded(replacement_hash)
        RemoveAnimDict(animation.Dictionary)
        return
    end
    if active_call_id ~= expected_call_id or active_booth ~= booth or not DoesEntityExist(booth.entity) then
        visuals_starting = false
        SetModelAsNoLongerNeeded(replacement_hash)
        RemoveAnimDict(animation.Dictionary)
        return
    end

    local original = booth.entity
    local coords = GetEntityCoords(original)
    local rotation = GetEntityRotation(original, 2)
    local replacement = CreateObjectNoOffset(
        replacement_hash,
        coords.x,
        coords.y,
        coords.z,
        true,
        true,
        false
    )
    if replacement == 0 or not DoesEntityExist(replacement) then
        Bridge.Debug("error", "[sky_phone] The animated payphone replacement prop could not be created.")
        visuals_starting = false
        SetModelAsNoLongerNeeded(replacement_hash)
        RemoveAnimDict(animation.Dictionary)
        return
    end

    SetEntityRotation(replacement, rotation.x, rotation.y, rotation.z, 2, false)
    FreezeEntityPosition(replacement, true)
    SetEntityCollision(replacement, false, false)
    local replacement_network_id = NetworkGetNetworkIdFromEntity(replacement)
    if replacement_network_id == 0 then
        Bridge.Debug("error", "[sky_phone] The animated payphone replacement prop is not networked.")
        SetEntityAsMissionEntity(replacement, true, true)
        DeleteEntity(replacement)
        visuals_starting = false
        SetModelAsNoLongerNeeded(replacement_hash)
        RemoveAnimDict(animation.Dictionary)
        return
    end
    SetNetworkIdCanMigrate(replacement_network_id, false)
    SetEntityVisible(original, false, false)
    hidden_prop = original
    replacement_prop = replacement

    local ped = PlayerPedId()
    network_animation_scene = NetworkCreateSynchronisedScene(
        coords.x,
        coords.y,
        coords.z,
        rotation.x,
        rotation.y,
        rotation.z,
        2,
        true,
        false,
        1.0,
        0.0,
        1.0
    )
    if not network_animation_scene or network_animation_scene == -1 then
        Bridge.Debug("error", "[sky_phone] The payphone network synchronized scene could not be created.")
        network_animation_scene = nil
        stop_call_visuals()
        return
    end
    animation_ped = ped
    local ped_coords = GetEntityCoords(animation_ped)
    local found_ground, ground_z = GetGroundZFor_3dCoord(
        ped_coords.x,
        ped_coords.y,
        ped_coords.z + 1.0,
        false
    )
    animation_floor_z = found_ground and ground_z or ped_coords.z
    NetworkAddPedToSynchronisedScene(
        ped,
        network_animation_scene,
        animation.Dictionary,
        animation.PedClip,
        8.0,
        -8.0,
        2,
        0,
        1000.0,
        0
    )
    NetworkAddEntityToSynchronisedScene(
        replacement,
        network_animation_scene,
        animation.Dictionary,
        animation.PropClip,
        8.0,
        -8.0,
        0
    )
    NetworkStartSynchronisedScene(network_animation_scene)

    local scene_deadline = GetGameTimer() + 1000
    repeat
        animation_scene = NetworkGetLocalSceneFromNetworkId(network_animation_scene)
        if animation_scene and animation_scene ~= -1 then
            break
        end
        Wait(0)
    until GetGameTimer() >= scene_deadline
    if not animation_scene or animation_scene == -1 then
        Bridge.Debug("error", "[sky_phone] The local handle for the payphone network scene was not created.")
        animation_scene = nil
        stop_call_visuals()
        return
    end
    visuals_starting = false
    SetModelAsNoLongerNeeded(replacement_hash)
end

local function booth_payload(booth)
    local coords = booth.coords
    return {
        model = booth.model,
        coords = { x = coords.x, y = coords.y, z = coords.z },
    }
end

local function payphone_open_payload()
    return {
        currency = Config.Payphones.Currency,
        maxNumberLength = Config.Sim.NumberLength,
        pricePerSecond = Config.Payphones.PricePerSecond,
        locales = locale.Nui.Payphone,
    }
end

local function close_payphone()
    local was_open = payphone_open
    payphone_open = false
    if was_open then
        TriggerEvent("sky_phone:client:setPayphoneFocus", false)
        SendNUIMessage({ type = "payphone:close" })
    end
    if not active_call_id then
        active_booth = nil
    end
end

local function format_duration(seconds)
    local duration = math.max(0, math.floor(tonumber(seconds) or 0))
    return ("%02d:%02d"):format(math.floor(duration / 60), duration % 60)
end

local function replace_placeholder(value, placeholder, replacement)
    return value:gsub("{" .. placeholder .. "}", tostring(replacement))
end

local function current_call_elapsed_seconds()
    if active_call_state ~= "connected" then
        return 0
    end
    return active_call_elapsed_seconds
        + math.max(0, math.floor((GetGameTimer() - active_call_elapsed_updated_at) / 1000))
end

local function call_help_message()
    local payphone_locale = locale.Payphone
    local message
    if active_call_state == "connected" then
        local elapsed_seconds = current_call_elapsed_seconds()
        message = payphone_locale.ConnectedHelp
        message = replace_placeholder(message, "duration", format_duration(elapsed_seconds))
        message = replace_placeholder(message, "currency", Config.Payphones.Currency)
        message = replace_placeholder(message, "cost", elapsed_seconds * (tonumber(Config.Payphones.PricePerSecond) or 0))
    else
        message = payphone_locale.RingingHelp
    end
    return replace_placeholder(message, "number", active_call_number or "")
end

local function apply_active_call_state(data)
    if active_call_id ~= data.id then
        hangup_requested = false
    end
    active_call_id = data.id
    active_call_state = data.state
    active_call_number = data.otherNumber or active_call_number
    if data.state == "connected" then
        active_call_elapsed_seconds = math.max(0, math.floor(tonumber(data.elapsedSeconds) or 0))
        active_call_elapsed_updated_at = GetGameTimer()
    else
        active_call_elapsed_seconds = 0
        active_call_elapsed_updated_at = 0
    end
    active_call_payload = data
end

local function clear_active_call_state()
    active_call_id = nil
    active_call_state = nil
    active_call_number = nil
    active_call_elapsed_seconds = 0
    active_call_elapsed_updated_at = 0
    active_call_payload = nil
    hangup_requested = false
end

local function open_payphone(booth)
    if payphone_open or active_call_id or IsNuiFocused() then
        return
    end
    active_booth = booth
    payphone_open = true
    TriggerEvent("sky_phone:client:setPayphoneFocus", true)
    SendNUIMessage({
        type = "payphone:open",
        data = payphone_open_payload(),
    })
end

RegisterNUICallback("payphone:dial", function(data, cb)
    if type(data) ~= "table" or not payphone_open or not active_booth or active_call_id then
        cb({ success = false, error = "invalid_request" })
        return
    end
    local payload = booth_payload(active_booth)
    payload.phoneNumber = data.phoneNumber
    local result = Bridge.Callbacks.Trigger("sky_phone:payphone:dial", payload)
    local call_started = type(result) == "table" and result.success and type(result.data) == "table"
        and (result.data.state == "ringing" or result.data.state == "connected")
    if call_started then
        apply_active_call_state(result.data)
    end
    cb(type(result) == "table" and result or { success = false, error = "request_failed" })
    if call_started then
        close_payphone()
        start_call_visuals()
    end
end)

RegisterNUICallback("payphone:hangup", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    if not active_call_id then
        cb({ success = false, error = "call_not_found" })
        return
    end
    local result = Bridge.Callbacks.Trigger("sky_phone:payphone:hangup", { id = active_call_id })
    cb(type(result) == "table" and result or { success = false, error = "request_failed" })
end)

RegisterNUICallback("payphone:close", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    if active_call_id then
        Bridge.Callbacks.Trigger("sky_phone:payphone:hangup", { id = active_call_id })
    end
    close_payphone()
    cb({ success = true })
end)

RegisterNetEvent("sky_phone:payphone:state", function(data)
    if type(data) ~= "table" or type(data.id) ~= "string" or type(data.state) ~= "string" then
        return
    end
    if data.state == "ringing" or data.state == "connected" then
        apply_active_call_state(data)
        close_payphone()
        start_call_visuals()
        if data.state == "connected" and data.channel and call_channel ~= tonumber(data.channel)
            and not join_call_voice(data.channel)
        then
            hangup_requested = true
            Bridge.Callbacks.Trigger("sky_phone:payphone:hangup", { id = active_call_id })
        end
    else
        clear_active_call_state()
        leave_call_voice()
        play_hangup_visuals()
    end
    SendNUIMessage({ type = "payphone:state", data = data })
end)

AddEventHandler("sky_phone:client:nuiReady", function()
    if payphone_open then
        TriggerEvent("sky_phone:client:setPayphoneFocus", true)
        SendNUIMessage({ type = "payphone:open", data = payphone_open_payload() })
    else
        TriggerEvent("sky_phone:client:setPayphoneFocus", false)
        SendNUIMessage({ type = "payphone:close" })
    end
    if active_call_payload then
        local payload = {}
        for key, value in pairs(active_call_payload) do
            payload[key] = value
        end
        payload.elapsedSeconds = current_call_elapsed_seconds()
        SendNUIMessage({ type = "payphone:state", data = payload })
    end
end)

CreateThread(function()
    while true do
        if not Config.Payphones.Enabled or payphone_open or active_call_id or visuals_ending then
            nearest_payphone = nil
            Wait(Config.Payphones.ScanIntervalMs)
        else
            local ped_coords = GetEntityCoords(PlayerPedId())
            local closest = nil
            local closest_distance = Config.Payphones.ScanDistance + 0.01
            for model_hash, model_name in pairs(configured_models) do
                local entity = GetClosestObjectOfType(
                    ped_coords.x,
                    ped_coords.y,
                    ped_coords.z,
                    Config.Payphones.ScanDistance,
                    model_hash,
                    false,
                    false,
                    false
                )
                if entity ~= 0 and DoesEntityExist(entity) then
                    local coords = GetEntityCoords(entity)
                    local distance = #(ped_coords - coords)
                    if distance < closest_distance then
                        closest_distance = distance
                        closest = { entity = entity, coords = coords, model = model_name, distance = distance }
                    end
                end
            end
            nearest_payphone = closest
            Wait(Config.Payphones.ScanIntervalMs)
        end
    end
end)

CreateThread(function()
    while true do
        if nearest_payphone and nearest_payphone.distance <= Config.Payphones.InteractionDistance and not IsNuiFocused() then
            Bridge.Framework.ShowHelpNotification(locale.Payphone.Interact, "E")
            if IsControlJustReleased(0, 38) then
                open_payphone(nearest_payphone)
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

CreateThread(function()
    while true do
        local has_visuals = next(remote_visuals) ~= nil
        if has_visuals then
            local player_coords = GetEntityCoords(PlayerPedId())
            for _, visual in pairs(remote_visuals) do
                if visual.hidden_entity and not DoesEntityExist(visual.hidden_entity) then
                    visual.hidden_entity = nil
                end
                if #(player_coords - visual.coords) <= Config.Payphones.ScanDistance then
                    if not visual.hidden_entity then
                        local entity = GetClosestObjectOfType(
                            visual.coords.x,
                            visual.coords.y,
                            visual.coords.z,
                            1.0,
                            visual.model_hash,
                            false,
                            false,
                            false
                        )
                        if entity ~= 0 and DoesEntityExist(entity) then
                            visual.hidden_entity = entity
                        end
                    end
                    if visual.hidden_entity then
                        SetEntityVisible(visual.hidden_entity, false, false)
                    end
                end
            end
            Wait(250)
        else
            Wait(1000)
        end
    end
end)

CreateThread(function()
    while true do
        local call_id = active_call_id
        local booth = active_booth
        if call_id and booth then
            keep_animation_ped_grounded()
            Bridge.Framework.ShowHelpNotification(call_help_message(), "E")
            if IsControlJustReleased(0, 38) and not hangup_requested then
                hangup_requested = true
                Bridge.Callbacks.Trigger("sky_phone:payphone:hangup", { id = call_id })
            end

            if active_call_id == call_id and active_booth == booth then
                local distance = #(GetEntityCoords(PlayerPedId()) - booth.coords)
                if distance > Config.Payphones.MaximumCallDistance and not hangup_requested then
                    hangup_requested = true
                    Bridge.Callbacks.Trigger("sky_phone:payphone:hangup", { id = call_id })
                end
            end
            Wait(0)
        elseif visuals_ending then
            keep_animation_ped_grounded()
            Wait(0)
        else
            Wait(250)
        end
    end
end)

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name ~= GetCurrentResourceName() then
        return
    end
    TriggerEvent("sky_phone:client:setPayphoneFocus", false)
    leave_call_voice()
    stop_call_visuals()
    clear_active_call_state()
    local visual_ids = {}
    for id in pairs(remote_visuals) do
        visual_ids[#visual_ids + 1] = id
    end
    for _, id in ipairs(visual_ids) do
        restore_remote_visual(id)
    end
    for _, entity in ipairs(custom_payphone_props) do
        if DoesEntityExist(entity) then
            SetEntityAsMissionEntity(entity, true, true)
            DeleteEntity(entity)
        end
    end
end)
