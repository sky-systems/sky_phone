local NOTIFICATION_TEXT_MAX_LENGTH = 2000
local NOTIFICATION_TITLE_MAX_LENGTH = 160
local DEVICE_NAME_MAX_LENGTH = 128

SkyPhoneNotifications = {}

local function trim(value)
    return value:match("^%s*(.-)%s*$")
end

local function normalize_text(value, error_code, maximum_length)
    if type(value) ~= "string" then
        return nil, error_code
    end

    local normalized = trim(value)
    if normalized == "" or #normalized > maximum_length then
        return nil, error_code
    end
    return normalized
end

local function resolve_alias(data, primary_key, alternate_key, error_code)
    local primary = data[primary_key]
    local alternate = data[alternate_key]
    if primary ~= nil and alternate ~= nil and primary ~= alternate then
        return nil, error_code
    end
    return primary ~= nil and primary or alternate
end

local function normalize_notification(notification)
    if type(notification) ~= "table" then
        return nil, "invalid_notification"
    end

    local app_id = resolve_alias(notification, "appId", "app_id", "invalid_app_id")
    local valid_app_id = SkyPhoneApps.ValidateAppId(app_id)
    if not valid_app_id or not SkyPhoneApps.CanReceiveNotification(app_id) then
        return nil, "invalid_app_id"
    end

    local title, title_error = normalize_text(
        notification.title,
        "invalid_title",
        NOTIFICATION_TITLE_MAX_LENGTH
    )
    if not title then
        return nil, title_error
    end

    local raw_text = resolve_alias(notification, "text", "body", "invalid_text")
    local notification_text, text_error = normalize_text(
        raw_text,
        "invalid_text",
        NOTIFICATION_TEXT_MAX_LENGTH
    )
    if not notification_text then
        return nil, text_error
    end

    return {
        appId = app_id,
        route = "/apps/" .. app_id,
        text = notification_text,
        title = title,
    }
end

local function normalize_server_device(device)
    if type(device) ~= "table"
        or not SkyPhoneImei.IsValid(device.imei)
    then
        return nil, "invalid_device"
    end

    local name, name_error = normalize_text(
        device.name,
        "invalid_device",
        DEVICE_NAME_MAX_LENGTH
    )
    if not name then
        return nil, name_error
    end
    if device.settings ~= nil
        and type(device.settings) ~= "string"
        and type(device.settings) ~= "table"
    then
        return nil, "invalid_device"
    end

    return {
        imei = device.imei,
        name = name,
        settings = device.settings,
    }
end

local function show_normalized(notification)
    SendNUIMessage({
        type = "notification:show",
        data = notification,
    })
end

function SkyPhoneNotifications.Show(notification)
    local normalized, error_code = normalize_notification(notification)
    if not normalized then
        return false, error_code
    end

    show_normalized(normalized)
    return true
end

function SkyPhoneNotifications.Send(notification)
    local normalized, error_code = normalize_notification(notification)
    if not normalized then
        return false, error_code
    end

    local result = Bridge.Callbacks.Trigger("sky_phone:notifications:self", normalized)
    if type(result) ~= "table" or result.success ~= true then
        return false, type(result) == "table" and result.error or "request_failed"
    end
    return true, result.data
end

RegisterNetEvent("sky_phone:notifications:show", function(notification)
    if source ~= 65535 then
        Bridge.Debug("warn", "[sky_phone] Rejected a client-triggered notification delivery event.")
        return
    end

    local normalized, notification_error = normalize_notification(notification)
    local device
    local device_error = "invalid_device"
    if type(notification) == "table" then
        device, device_error = normalize_server_device(notification.device)
    end
    if not normalized or not device then
        Bridge.Debug(
            "warn",
            "[sky_phone] Rejected an invalid server notification: %s.",
            tostring(notification_error or device_error)
        )
        return
    end

    normalized.device = device
    show_normalized(normalized)
    TriggerEvent("sky_phone:client:pushNotification", {
        appId = normalized.appId,
        text = normalized.text,
        title = normalized.title,
    })
end)

local phone_locale = SkyPhoneLocales.Resolve(Config.Bridge.Locale)
local app_locales = phone_locale.Nui.Apps

AddEventHandler("sky_phone:configurator:updated", function()
    phone_locale = SkyPhoneLocales.Resolve(Config.Bridge.Locale)
    app_locales = phone_locale.Nui.Apps
end)

RegisterNetEvent("sky_phone:mail:new", function(data)
    local locale = app_locales.mail
    data.title = locale.name
    data.text = locale.newMessage:gsub("{sender}", tostring(data.sender))
    SendNUIMessage({ type = "mail:new", data = data })
end)

RegisterNetEvent("sky_phone:citywarn:changed", function(data)
    if type(data) ~= "table" then
        return
    end
    local locale = app_locales.citywarn
    data.title = locale.name
    data.text = locale.notifications[data.kind] or locale.notifications.update
    SendNUIMessage({ type = "citywarn:changed", data = data })
end)

RegisterNetEvent("sky_phone:companies:notification", function(data)
    local locale = app_locales.companies
    data.title = locale.name
    data.text = locale.notifications[data.kind] or locale.notifications.requestUpdated
    SendNUIMessage({ type = "companies:notification", data = data })
end)

RegisterNetEvent("sky_phone:fliptok:command-feedback", function(data)
    Bridge.Framework.Notify("FlipTok", data.message, data.notificationType, 5000)
end)

RegisterNetEvent("sky_phone:fliptok:new", function(data)
    local locale = app_locales.fliptok
    local notification_text = locale.notifications[data.kind] or locale.notifications.default
    data.title = locale.name
    data.text = notification_text:gsub("{actor}", tostring(data.actor or ""))
    SendNUIMessage({ type = "fliptok:new", data = data })
end)

RegisterNetEvent("sky_phone:picstagram:command-feedback", function(data)
    Bridge.Framework.Notify("Picstagram", data.message, data.notificationType, 5000)
end)

RegisterNetEvent("sky_phone:picstagram:new", function(data)
    local locale = app_locales.picstagram
    local notification_text = locale.notifications[data.kind] or locale.notifications.default
    data.title = locale.name
    data.text = notification_text:gsub("{actor}", tostring(data.actor or ""))
    SendNUIMessage({ type = "picstagram:new", data = data })
end)

RegisterNetEvent("sky_phone:feather:new", function(data)
    local locale = app_locales.feather
    local notification_text = locale.notifications[data.kind] or locale.notifications.default
    data.title = locale.name
    data.text = notification_text:gsub("{actor}", tostring(data.actor or ""))
    SendNUIMessage({ type = "feather:new", data = data })
end)

RegisterNetEvent("sky_phone:marketplace:new-message", function(data)
    local locale = app_locales.citymarkt
    data.title = locale.name
    if data.kind == "offer" then
        data.text = locale.newOffer
            :gsub("{sender}", tostring(data.sender))
            :gsub("{price}", tostring(data.amount))
    elseif data.kind == "offer-response" and data.action == "accepted" then
        data.text = locale.offerAcceptedNotification
            :gsub("{sender}", tostring(data.sender))
            :gsub("{price}", tostring(data.amount))
    elseif data.kind == "offer-response" and data.action == "rejected" then
        data.text = locale.offerRejectedNotification
            :gsub("{sender}", tostring(data.sender))
            :gsub("{price}", tostring(data.amount))
    else
        data.text = locale.newMessage:gsub("{sender}", tostring(data.sender))
    end
    SendNUIMessage({ type = "marketplace:new-message", data = data })
end)

RegisterNetEvent("sky_phone:calendar:reminder", function(data)
    local locale = app_locales.calendar
    data.title = locale.name
    data.text = locale.reminder:gsub("{title}", tostring(data.eventTitle))
    SendNUIMessage({ type = "calendar:reminder", data = data })
end)

RegisterNetEvent("sky_phone:flare:match", function(data)
    local locale = app_locales.flare
    data.title = locale.name
    data.text = locale.newMatchNotification:gsub("{sender}", tostring(data.sender))
    SendNUIMessage({ type = "flare:new-match", data = data })
end)

RegisterNetEvent("sky_phone:flare:message", function(data)
    local locale = app_locales.flare
    data.title = locale.name
    data.text = locale.newMessageNotification:gsub("{sender}", tostring(data.sender))
    SendNUIMessage({ type = "flare:new-message", data = data })
end)

RegisterNetEvent("sky_phone:billing:new", function(data)
    local locale = app_locales.billing
    data.title = locale.name
    data.text = locale.notifications.newInvoice
        :gsub("{issuer}", tostring(data.issuer))
        :gsub("{amount}", ("%s %s"):format(tostring(data.amount), Config.Billing.Currency))
    SendNUIMessage({ type = "billing:new", data = data })
end)

RegisterNetEvent("sky_phone:crewlink:notification", function(data)
    local locale = app_locales.crewlink
    local notification_text = locale.notifications[data.kind] or locale.notifications.default
    data.title = locale.name
    data.text = notification_text
        :gsub("{actor}", tostring(data.actor or ""))
        :gsub("{group}", tostring(data.groupName or ""))
        :gsub("{ping}", tostring(data.pingLabel or ""))
    SendNUIMessage({ type = "crewlink:notification", data = data })
end)

RegisterNetEvent("sky_phone:messages:new", function(data)
    local locale = app_locales.messages
    data.title = locale.name
    data.text = locale.newMessage:gsub("{sender}", tostring(data.sender))
    SendNUIMessage({ type = "messages:new", data = data })
end)

RegisterNetEvent("sky_phone:darkchat:new", function(data)
    local locale = app_locales.darkchat
    data.title = locale.name
    if data.notificationMode == "private" then
        data.sender = nil
        data.text = locale.privateNotification
    elseif data.notificationMode == "hidden" then
        data.sender = nil
        data.text = ""
    else
        data.text = locale.newMessage:gsub("{sender}", tostring(data.sender))
    end
    SendNUIMessage({ type = "darkchat:new", data = data })
end)
