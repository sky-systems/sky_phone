local is_open = false
local open_requested = false
local notification_focus = false
local device_payload = nil
local sim_picker_open = false
local call_channel = 0

Bridge.Debug("debug", "[sky_phone] Client script initialized.", { always = true })

local server_callbacks = {
    "device:save",
    "device:factory-reset",
    "account:login",
    "account:register",
    "account:logout",
    "account:devices",
    "account:remove-device",
    "notes:list",
    "notes:create",
    "notes:update",
    "notes:delete",
    "mail:register",
    "mail:login",
    "mail:logout",
    "mail:counts",
    "mail:list",
    "mail:get",
    "mail:get-draft",
    "mail:save-draft",
    "mail:delete-draft",
    "mail:send",
    "mail:set-read",
    "mail:trash",
    "mail:restore",
    "mail:delete-forever",
    "mail:empty-trash",
    "marketplace:list",
    "marketplace:get",
    "marketplace:list-own",
    "marketplace:create",
    "marketplace:update",
    "marketplace:set-status",
    "marketplace:favorite",
    "marketplace:counts",
    "marketplace:list-inquiries",
    "marketplace:get-inquiry",
    "marketplace:send-message",
    "marketplace:make-offer",
    "marketplace:respond-offer",
    "marketplace:report",
    "marketplace:block",
    "pages:list",
    "pages:get",
    "pages:list-own",
    "pages:create",
    "pages:share-citymarkt",
    "pages:react",
    "pages:delete",
    "calendar:list",
    "calendar:create",
    "calendar:update",
    "calendar:delete",
    "sim:insert",
    "sim:eject",
    "contacts:list",
    "contacts:save",
    "contacts:delete",
    "calls:recents",
    "calls:dial",
    "calls:answer",
    "calls:decline",
    "calls:hangup",
    "messages:conversations",
    "messages:thread",
    "messages:send",
    "messages:media",
    "messages:delete",
    "messages:gifs",
    "darkchat:bootstrap",
    "darkchat:update-profile",
    "darkchat:start",
    "darkchat:thread",
    "darkchat:send",
    "darkchat:media",
    "darkchat:react",
    "darkchat:message-action",
    "darkchat:update-conversation",
    "darkchat:add-contact",
    "darkchat:remove-contact",
    "darkchat:block",
    "darkchat:report",
    "darkchat:clear",
    "gallery:list",
    "media:config",
}

local function get_locale()
    return Locales[Config.Bridge.Locale] or Locales["en"]
end

local function send_open_message()
    if not device_payload then
        return
    end

    local payload = device_payload
    payload.lang = Config.Bridge.Locale
    payload.locales = get_locale().Nui
    SendNUIMessage({
        type = "app:open",
        data = payload,
    })
end

local function open_phone()
    if is_open or not device_payload then
        return
    end

    send_open_message()
end

local function close_phone()
    open_requested = false
    if not is_open then
        return
    end

    is_open = false
    TriggerEvent("sky_phone:nuiClosed")
    SetNuiFocus(notification_focus or sim_picker_open, notification_focus or sim_picker_open)
    SendNUIMessage({ type = "app:close" })
    Bridge.Callbacks.Trigger("sky_phone:device:close", {})
end

local function leave_call_voice()
    if call_channel == 0 then
        return
    end
    if Config.Calls.VoiceProvider == "pma" and GetResourceState("pma-voice") == "started" then
        exports["pma-voice"]:setCallChannel(0)
    end
    call_channel = 0
end

local function join_call_voice(channel)
    if Config.Calls.VoiceProvider ~= "pma" then
        Bridge.Debug("error", "[sky_phone] Unsupported voice provider '%s'.", tostring(Config.Calls.VoiceProvider))
        return false
    end
    if GetResourceState("pma-voice") ~= "started" then
        Bridge.Debug("error", "[sky_phone] Configured pma-voice provider is not started.")
        return false
    end
    call_channel = tonumber(channel) or 0
    exports["pma-voice"]:setCallChannel(call_channel)
    return true
end

if Config.Phone.DevelopmentCommand then
    RegisterCommand(Config.Command, function()
        if is_open then
            close_phone()
            return
        end
        Bridge.Callbacks.Trigger("sky_phone:device:development-open", {})
    end, false)
end

RegisterNUICallback("ui:ready", function(_, cb)
    Bridge.Debug("debug", "[sky_phone] NUI reported ready.", { always = true })
    if open_requested and device_payload then
        send_open_message()
    end

    cb({ success = true })
end)

RegisterNUICallback("ui:opened", function(_, cb)
    if not open_requested or not device_payload then
        Bridge.Debug(
            "warn",
            "[sky_phone] Ignored a NUI open confirmation without a pending device open.",
            { always = true }
        )
        cb({ success = false, error = "open_not_requested" })
        return
    end

    is_open = true
    notification_focus = false
    SetNuiFocus(true, true)
    cb({ success = true })
end)

RegisterNUICallback("close", function(_, cb)
    close_phone()
    cb({ success = true })
end)

RegisterNUICallback("notification:focus", function(data, cb)
    notification_focus = data.active == true and not is_open
    SetNuiFocus(is_open or notification_focus, is_open or notification_focus)
    cb({ success = true })
end)

RegisterNUICallback("sim:picker-close", function(_, cb)
    sim_picker_open = false
    SetNuiFocus(is_open or notification_focus, is_open or notification_focus)
    cb({ success = true })
end)

RegisterNUICallback("map:getPlayerCoords", function(_, cb)
    local coords = GetEntityCoords(PlayerPedId())
    cb({
        success = true,
        data = {
            coords = {
                x = coords.x,
                y = coords.y,
                z = coords.z
            }
        }
    })
end)

local weather_types = {
    [joaat("EXTRASUNNY")] = "sunny",
    [joaat("CLEAR")] = "clear",
    [joaat("CLOUDS")] = "partly_cloudy",
    [joaat("OVERCAST")] = "cloudy",
    [joaat("RAIN")] = "rain",
    [joaat("CLEARING")] = "rain",
    [joaat("THUNDER")] = "thunder",
    [joaat("SMOG")] = "fog",
    [joaat("FOGGY")] = "fog",
    [joaat("NEUTRAL")] = "cloudy",
    [joaat("SNOW")] = "snow",
    [joaat("BLIZZARD")] = "snow",
    [joaat("SNOWLIGHT")] = "snow",
    [joaat("XMAS")] = "snow",
    [joaat("HALLOWEEN")] = "cloudy",
}

local function weather_region(coords)
    if coords.x > 2500.0 and coords.y < -3000.0 then
        return "cayo_perico"
    end
    if coords.y > 900.0 then
        return "blaine_county"
    end
    return "los_santos"
end

RegisterNUICallback("weather:get", function(_, cb)
    local coords = GetEntityCoords(PlayerPedId())
    local weather_hash = GetPrevWeatherTypeHashName()
    cb({
        success = true,
        data = {
            condition = weather_types[weather_hash] or "clear",
            region = weather_region(coords),
            clock = {
                year = GetClockYear(),
                month = GetClockMonth() + 1,
                day = GetClockDayOfMonth(),
                hour = GetClockHours(),
                minute = GetClockMinutes(),
            },
            windSpeed = math.max(0.0, GetWindSpeed()),
            rainLevel = math.max(0.0, math.min(1.0, GetRainLevel())),
        },
    })
end)

for _, callback_name in ipairs(server_callbacks) do
    RegisterNUICallback(callback_name, function(data, cb)
        local result = Bridge.Callbacks.Trigger("sky_phone:" .. callback_name, data)
        if result then
            cb(result)
            return
        end

        cb({ success = false, error = "request_failed" })
    end)
end

RegisterNetEvent("sky_phone:device:open", function(data)
    Bridge.Debug(
        "debug",
        "[sky_phone] Client received device open for IMEI %s account_linked=%s.",
        tostring(data.device.imei),
        tostring(data.account ~= nil),
        { always = true }
    )
    device_payload = data
    open_requested = true
    open_phone()
end)

RegisterNetEvent("sky_phone:device:updated", function(data)
    device_payload = data
    SendNUIMessage({ type = "device:updated", data = data })
end)

RegisterNetEvent("sky_phone:device:invalidated", function()
    open_requested = false
    device_payload = nil
    close_phone()
end)

RegisterNetEvent("sky_phone:device:error", function(error_code)
    Bridge.Debug(
        "debug",
        "[sky_phone] Client received device error: %s.",
        tostring(error_code),
        { always = true }
    )
    local message = get_locale().DeviceErrors[error_code] or get_locale().DeviceErrors.default
    Bridge.Framework.Notify("iFruit", message, "error", 5000)
end)

RegisterNetEvent("sky_phone:mail:changed", function(data)
    SendNUIMessage({ type = "mail:changed", data = data })
end)

RegisterNetEvent("sky_phone:mail:new", function(data)
    local mail_locale = get_locale().Nui.Apps.mail
    data.title = mail_locale.name
    data.text = mail_locale.newMessage:gsub("{sender}", tostring(data.sender))
    SendNUIMessage({ type = "mail:new", data = data })
end)

RegisterNetEvent("sky_phone:marketplace:changed", function(data)
    SendNUIMessage({ type = "marketplace:changed", data = data })
end)

RegisterNetEvent("sky_phone:marketplace:new-message", function(data)
    local marketplace_locale = get_locale().Nui.Apps.citymarkt
    data.title = marketplace_locale.name
    if data.kind == "offer" then
        data.text = marketplace_locale.newOffer
            :gsub("{sender}", tostring(data.sender))
            :gsub("{price}", tostring(data.amount))
    elseif data.kind == "offer-response" and data.action == "accepted" then
        data.text = marketplace_locale.offerAcceptedNotification
            :gsub("{sender}", tostring(data.sender))
            :gsub("{price}", tostring(data.amount))
    elseif data.kind == "offer-response" and data.action == "rejected" then
        data.text = marketplace_locale.offerRejectedNotification
            :gsub("{sender}", tostring(data.sender))
            :gsub("{price}", tostring(data.amount))
    else
        data.text = marketplace_locale.newMessage:gsub("{sender}", tostring(data.sender))
    end
    SendNUIMessage({ type = "marketplace:new-message", data = data })
end)

RegisterNetEvent("sky_phone:calendar:reminder", function(data)
    local calendar_locale = get_locale().Nui.Apps.calendar
    data.title = calendar_locale.name
    data.text = calendar_locale.reminder:gsub("{title}", tostring(data.eventTitle))
    SendNUIMessage({ type = "calendar:reminder", data = data })
end)

RegisterNetEvent("sky_phone:sim:picker", function(data)
    sim_picker_open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ type = "sim:picker", data = data })
end)

RegisterNetEvent("sky_phone:sim:picker-close", function()
    sim_picker_open = false
    SetNuiFocus(is_open or notification_focus, is_open or notification_focus)
    SendNUIMessage({ type = "sim:picker-close" })
end)

RegisterNetEvent("sky_phone:contacts:changed", function()
    SendNUIMessage({ type = "contacts:changed" })
end)

RegisterNetEvent("sky_phone:calls:changed", function()
    SendNUIMessage({ type = "calls:changed" })
end)

RegisterNetEvent("sky_phone:messages:changed", function(data)
    SendNUIMessage({ type = "messages:changed", data = data })
end)

RegisterNetEvent("sky_phone:messages:new", function(data)
    local messages_locale = get_locale().Nui.Apps.messages
    data.title = messages_locale.name
    data.text = messages_locale.newMessage:gsub("{sender}", tostring(data.sender))
    SendNUIMessage({ type = "messages:new", data = data })
end)

RegisterNetEvent("sky_phone:darkchat:changed", function(data)
    SendNUIMessage({ type = "darkchat:changed", data = data })
end)

RegisterNetEvent("sky_phone:darkchat:new", function(data)
    local darkchat_locale = get_locale().Nui.Apps.darkchat
    data.title = darkchat_locale.name
    if data.notificationMode == "private" then
        data.sender = nil
        data.text = darkchat_locale.privateNotification
    elseif data.notificationMode == "hidden" then
        data.sender = nil
        data.text = ""
    else
        data.text = darkchat_locale.newMessage:gsub("{sender}", tostring(data.sender))
    end
    SendNUIMessage({ type = "darkchat:new", data = data })
end)

RegisterNetEvent("sky_phone:call:incoming", function(data)
    notification_focus = true
    SetNuiFocus(true, true)
    SendNUIMessage({ type = "call:incoming", data = data })
end)

RegisterNetEvent("sky_phone:call:state", function(data)
    if data.state == "connected" and data.channel then
        if not join_call_voice(data.channel) then
            TriggerEvent("sky_phone:device:error", "voice_unavailable")
        end
    elseif data.state ~= "ringing" then
        leave_call_voice()
    end
    SendNUIMessage({ type = "call:state", data = data })
end)

CreateThread(function()
    if Config.Phone.DevelopmentCommand then
        TriggerEvent("chat:addSuggestion", "/" .. Config.Command, get_locale().CommandDescription)
    end
end)

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name ~= GetCurrentResourceName() then
        return
    end

    if is_open or notification_focus then
        SetNuiFocus(false, false)
    end

    leave_call_voice()

    if Config.Phone.DevelopmentCommand then
        TriggerEvent("chat:removeSuggestion", "/" .. Config.Command)
    end
end)
