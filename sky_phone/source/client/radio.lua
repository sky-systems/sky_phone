local current_volume = math.max(0, math.min(100, tonumber(Config.Radio.DefaultVolume) or 50))
local current_primary = 0
local current_secondary = 0
local radio_settings = {
    autoRejoin = Config.Radio.AutoRejoin,
    notifications = Config.Radio.Notifications,
}
local auto_rejoin_pending = false

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

    local data = approved.data or {}
    local approved_primary = tonumber(data.frequency) or 0
    local approved_secondary = tonumber(data.secondaryFrequency) or 0
    if not Bridge.Radio.Join(approved_primary, approved_secondary) then
        request("disconnect")
        return { success = false, error = "voice_unavailable" }
    end

    current_primary = approved_primary
    current_secondary = approved_secondary
    Bridge.Radio.SetVolume(current_volume)
    data.secondaryFrequency = approved_secondary
    data.provider = Bridge.Radio.GetProvider()
    data.secondarySupported = Bridge.Radio.SupportsSecondary()
    return { success = true, data = data }
end

local function leave_radio()
    Bridge.Radio.Leave()
    current_primary = 0
    current_secondary = 0
    return request("disconnect")
end

RegisterNUICallback("radio:get", function(_, cb)
    local result = request("get")
    if result.success then
        apply_server_state(result.data)
        result.data.volume = current_volume
        result.data.provider = Bridge.Radio.GetProvider()
        result.data.secondarySupported = Bridge.Radio.SupportsSecondary()
    end
    cb(result)
end)

RegisterNUICallback("radio:connect", function(data, cb)
    cb(join_radio(data.frequency, data.secondaryFrequency))
end)

RegisterNUICallback("radio:disconnect", function(_, cb)
    cb(leave_radio())
end)

RegisterNUICallback("radio:set-volume", function(data, cb)
    local volume = tonumber(data.volume)
    if not volume then
        cb({ success = false, error = "invalid_volume" })
        return
    end
    current_volume = math.max(0, math.min(100, math.floor(volume + 0.5)))
    Bridge.Radio.SetVolume(current_volume)
    cb({ success = true, data = { volume = current_volume } })
end)

RegisterNUICallback("radio:save-settings", function(data, cb)
    local result = request("save-settings", data)
    if result.success then
        apply_server_state({ settings = result.data })
    end
    cb(result)
end)

RegisterNUICallback("radio:save-badge", function(data, cb)
    cb(request("save-badge", data))
end)

RegisterNUICallback("radio:save-display-name", function(data, cb)
    cb(request("save-display-name", data))
end)

RegisterNetEvent("sky_phone:radio:members", function(data)
    if tonumber(data.frequency) ~= current_primary then
        return
    end
    SendNUIMessage({ type = "radio:updated", data = data })
end)

RegisterNetEvent("sky_phone:radio:notification", function(data)
    if not radio_settings.notifications or current_primary <= 0 then
        return
    end
    local locale = (Locales[Config.Bridge.Locale] or Locales.en).Nui.Apps.radio
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
        current_primary = value
        if value == 0 then
            current_secondary = 0
            request("disconnect")
        else
            request("connect", { frequency = current_primary, secondaryFrequency = current_secondary })
        end
    elseif channel_id == 2 then
        current_secondary = value == current_primary and 0 or value
        if current_primary > 0 then
            request("connect", { frequency = current_primary, secondaryFrequency = current_secondary })
        end
    end
end)
