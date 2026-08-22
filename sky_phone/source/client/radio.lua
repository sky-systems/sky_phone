local current_volume = math.max(0, math.min(100, tonumber(Config.Radio.DefaultVolume) or 50))
local current_primary = 0
local current_secondary = 0
local radio_settings = {
    autoRejoin = Config.Radio.AutoRejoin,
    notifications = Config.Radio.Notifications,
}
local auto_rejoin_pending = false
local hud_members = { [1] = {}, [2] = {} }
local hud_talking = {}

local function get_hud_config()
    local hud = type(Config.Radio.Hud) == "table" and Config.Radio.Hud or {}
    local position = type(hud.Position) == "table" and hud.Position or {}
    return {
        enabled = hud.Enabled == true,
        horizontal = position.Horizontal == "left" and "left" or "right",
        vertical = position.Vertical == "bottom" and "bottom" or "top",
        horizontalOffset = math.max(0.0, math.min(100.0, tonumber(position.HorizontalOffset) or 2.0)),
        verticalOffset = math.max(0.0, math.min(100.0, tonumber(position.VerticalOffset) or 30.0)),
        speakerPersistMilliseconds = math.max(
            0,
            math.min(10000, math.floor(tonumber(hud.SpeakerPersistMilliseconds) or 3000))
        ),
    }
end

local function send_hud_config()
    SendNUIMessage({ type = "radio:hud-config", data = get_hud_config() })
end

AddEventHandler("sky_phone:configurator:updated", function()
    send_hud_config()
end)

local function send_hud_members()
    local combined = {}
    for channel_id = 1, 2 do
        for player_id, member in pairs(hud_members[channel_id]) do
            if not combined[player_id] then
                local talking = hud_talking[player_id]
                combined[player_id] = {
                    id = player_id,
                    name = member.name,
                    badge = member.badge,
                    talking = talking and talking.state or false,
                    channel = talking and talking.channel or channel_id,
                }
            end
        end
    end

    local members = {}
    for _, member in pairs(combined) do
        members[#members + 1] = member
    end
    table.sort(members, function(left, right)
        return left.name:lower() < right.name:lower()
    end)
    SendNUIMessage({ type = "radio:hud-update", data = { members = members } })
end

local function clear_hud_members()
    hud_members = { [1] = {}, [2] = {} }
    hud_talking = {}
    send_hud_members()
end

local function set_hud_members(channel_id, members)
    local channel_members = {}
    if type(members) == "table" then
        for _, member in ipairs(members) do
            local player_id = tonumber(member.id)
            if player_id then
                channel_members[player_id] = {
                    name = tostring(member.name or ("ID " .. player_id)),
                    badge = tostring(member.badge or ""),
                }
            end
        end
    end
    hud_members[channel_id] = channel_members
    send_hud_members()
end

local function set_hud_talking(player_id, state, channel_id)
    player_id = tonumber(player_id)
    if not player_id then
        return
    end
    hud_talking[player_id] = state and { state = true, channel = channel_id == 2 and 2 or 1 } or nil
    send_hud_members()
end

local function request(name, data)
    local result = Bridge.Callbacks.Trigger("sky_phone:radio:" .. name, data or {})
    if type(result) ~= "table" then
        return { success = false, error = "request_failed" }
    end
    return result
end

local function apply_server_state(data)
    if type(data) ~= "table" then
        return
    end
    current_primary = tonumber(data.frequency) or current_primary
    current_secondary = tonumber(data.secondaryFrequency) or current_secondary
    if type(data.settings) == "table" then
        radio_settings.autoRejoin = data.settings.autoRejoin == true
        radio_settings.notifications = data.settings.notifications == true
    end
end

local function join_radio(primary, secondary)
    if not Bridge.Radio.SupportsSecondary() then
        secondary = 0
    end
    local approved = request("connect", {
        frequency = primary,
        secondaryFrequency = secondary,
    })
    if not approved.success then
        return approved
    end

    if type(approved.data) ~= "table" then
        return { success = false, error = "request_failed" }
    end
    local data = approved.data
    local approved_primary = tonumber(data.frequency) or 0
    local approved_secondary = tonumber(data.secondaryFrequency) or 0
    if not Bridge.Radio.Join(approved_primary, approved_secondary) then
        request("disconnect")
        return { success = false, error = "voice_unavailable" }
    end

    if current_primary ~= approved_primary or current_secondary ~= approved_secondary then
        clear_hud_members()
    end
    current_primary = approved_primary
    current_secondary = approved_secondary
    Bridge.Radio.SetVolume(current_volume)
    data.secondaryFrequency = approved_secondary
    data.provider = Bridge.Radio.GetProvider()
    data.secondarySupported = Bridge.Radio.SupportsSecondary()
    data.speakerSupported = Bridge.Radio.SupportsSpeaker()
    data.speakerEnabled = data.speakerSupported and data.speakerEnabled == true
    if data.speakerSupported and Bridge.Radio.GetSpeaker() ~= data.speakerEnabled then
        Bridge.Radio.SetSpeaker(data.speakerEnabled)
    end
    return { success = true, data = data }
end

local function leave_radio()
    Bridge.Radio.Leave()
    current_primary = 0
    current_secondary = 0
    clear_hud_members()
    return request("disconnect")
end

AddEventHandler("sky_phone:client:radioProviderUpdated", function()
    if current_primary <= 0 then
        return
    end
    if not Bridge.Radio.Join(current_primary, current_secondary) then
        request("disconnect")
        current_primary = 0
        current_secondary = 0
        clear_hud_members()
        return
    end

    Bridge.Radio.SetVolume(current_volume)
end)

RegisterNUICallback("radio:get", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    local result = request("get")
    if result.success and type(result.data) == "table" then
        apply_server_state(result.data)
        result.data.volume = current_volume
        result.data.provider = Bridge.Radio.GetProvider()
        result.data.secondarySupported = Bridge.Radio.SupportsSecondary()
        result.data.speakerSupported = Bridge.Radio.SupportsSpeaker()
        result.data.speakerEnabled = result.data.speakerSupported and result.data.speakerEnabled == true
        if result.data.speakerSupported and Bridge.Radio.GetSpeaker() ~= result.data.speakerEnabled then
            Bridge.Radio.SetSpeaker(result.data.speakerEnabled)
        end
    elseif result.success then
        result = { success = false, error = "request_failed" }
    end
    cb(result)
end)

RegisterNUICallback("radio:connect", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    cb(join_radio(data.frequency, data.secondaryFrequency))
end)

RegisterNUICallback("radio:disconnect", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    cb(leave_radio())
end)

RegisterNUICallback("radio:set-volume", function(data, cb)
    local volume = type(data) == "table" and tonumber(data.volume) or nil
    if not volume then
        cb({ success = false, error = "invalid_volume" })
        return
    end
    current_volume = math.max(0, math.min(100, math.floor(volume + 0.5)))
    Bridge.Radio.SetVolume(current_volume)
    cb({ success = true, data = { volume = current_volume } })
end)

RegisterNUICallback("radio:set-speaker", function(data, cb)
    if type(data) ~= "table" or type(data.enabled) ~= "boolean" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    local result = request("set-speaker", { enabled = data.enabled })
    if not result.success then
        cb(result)
        return
    end
    Bridge.Radio.SetSpeaker(data.enabled)
    result.data = {
        speakerEnabled = data.enabled,
        speakerSupported = true,
    }
    cb(result)
end)

RegisterNUICallback("radio:save-settings", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    local result = request("save-settings", data)
    if result.success then
        apply_server_state({ settings = result.data })
    end
    cb(result)
end)

RegisterNUICallback("radio:save-badge", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    cb(request("save-badge", data))
end)

RegisterNUICallback("radio:save-display-name", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end
    cb(request("save-display-name", data))
end)

RegisterNetEvent("sky_phone:radio:members", function(data)
    if type(data) ~= "table" then
        return
    end
    local frequency = tonumber(data.frequency)
    local channel_id = frequency == current_primary and 1 or frequency == current_secondary and 2 or nil
    if not channel_id then
        return
    end
    set_hud_members(channel_id, data.members)
    if channel_id == 1 then
        SendNUIMessage({ type = "radio:updated", data = data })
    end
end)

RegisterNetEvent("yaca:external:isRadioReceiving", function(state, channel, player_id)
    if Bridge.Radio.GetProvider() ~= "yaca" then
        return
    end
    set_hud_talking(player_id, state == true, tonumber(channel) or 1)
end)

RegisterNetEvent("yaca:external:isRadioTalking", function(state, channel)
    if Bridge.Radio.GetProvider() ~= "yaca" then
        return
    end
    set_hud_talking(GetPlayerServerId(PlayerId()), state == true, tonumber(channel) or 1)
end)

RegisterNetEvent("yaca:external:isRadioEnabled", function(state)
    if Bridge.Radio.GetProvider() == "yaca" and not state then
        clear_hud_members()
    end
end)

AddEventHandler("sky_phone:client:nuiReady", function()
    send_hud_config()
    send_hud_members()
end)

RegisterNetEvent("sky_phone:radio:notification", function(data)
    if not radio_settings.notifications or current_primary <= 0 then
        return
    end
    local locale = SkyPhoneLocales.Resolve(Config.Bridge.Locale).Nui.Apps.radio
    local template = data.joined and locale.memberJoined or locale.memberLeft
    SendNUIMessage({
        type = "notification:show",
        data = {
            appId = "radio",
            title = locale.name,
            text = template:gsub("{name}", tostring(data.playerName or locale.unknownMember)),
        },
    })
end)

local function try_auto_rejoin()
    if auto_rejoin_pending or current_primary > 0 then
        return
    end
    auto_rejoin_pending = true
    local result = request("get")
    if result.success then
        apply_server_state(result.data)
        local data = result.data or {}
        if radio_settings.autoRejoin and tonumber(data.savedFrequency) and tonumber(data.savedFrequency) > 0 then
            local joined = join_radio(data.savedFrequency, data.savedSecondaryFrequency)
            if not joined.success then
                Bridge.Debug("warn", "[sky_phone] Radio auto-rejoin failed: %s", tostring(joined.error))
            end
        end
    end
    auto_rejoin_pending = false
end

AddEventHandler("playerSpawned", function()
    SetTimeout(2000, try_auto_rejoin)
end)

AddEventHandler("onResourceStart", function(resource_name)
    if resource_name == GetCurrentResourceName() then
        SetTimeout(5000, try_auto_rejoin)
    end
end)

RegisterNetEvent("yaca:external:setRadioFrequency", function(channel, frequency)
    if Bridge.Radio.GetProvider() ~= "yaca" then
        return
    end
    local channel_id = tonumber(channel)
    local value = math.max(0, tonumber(frequency) or 0)
    if channel_id == 1 then
        hud_members[1] = {}
        current_primary = value
        if value == 0 then
            current_secondary = 0
            hud_members[2] = {}
            hud_talking = {}
            request("disconnect")
        else
            request("connect", { frequency = current_primary, secondaryFrequency = current_secondary })
        end
    elseif channel_id == 2 then
        hud_members[2] = {}
        current_secondary = value == current_primary and 0 or value
        if current_primary > 0 then
            request("connect", { frequency = current_primary, secondaryFrequency = current_secondary })
        end
    end
    send_hud_members()
end)
