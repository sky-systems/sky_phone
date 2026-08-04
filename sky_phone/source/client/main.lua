local is_open = false
local notification_focus = false
local device_payload = nil

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
}

local function get_locale()
    return Locales[Sky.Config.locale] or Locales["en"]
end

local function send_open_message()
    if not device_payload then
        return
    end

    local payload = device_payload
    payload.lang = Sky.Config.locale
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

    is_open = true
    notification_focus = false
    SetNuiFocus(true, true)
    send_open_message()
end

local function close_phone()
    if not is_open then
        return
    end

    is_open = false
    SetNuiFocus(notification_focus, notification_focus)
    SendNUIMessage({ type = "app:close" })
    Sky.Cb.Trigger("sky_phone:device:close", {})
end

if Config.Phone.DevelopmentCommand then
    RegisterCommand(Config.Command, function()
        if is_open then
            close_phone()
            return
        end
        Sky.Cb.Trigger("sky_phone:device:development-open", {})
    end, false)
end

RegisterNUICallback("ui:ready", function(_, cb)
    if is_open then
        send_open_message()
    end

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

for _, callback_name in ipairs(server_callbacks) do
    RegisterNUICallback(callback_name, function(data, cb)
        local result = Sky.Cb.Trigger("sky_phone:" .. callback_name, data)
        if result then
            cb(result)
            return
        end

        cb({ success = false, error = "request_failed" })
    end)
end

RegisterNetEvent("sky_phone:device:open", function(data)
    device_payload = data
    open_phone()
end)

RegisterNetEvent("sky_phone:device:updated", function(data)
    device_payload = data
    SendNUIMessage({ type = "device:updated", data = data })
end)

RegisterNetEvent("sky_phone:device:invalidated", function()
    device_payload = nil
    close_phone()
end)

RegisterNetEvent("sky_phone:device:error", function(error_code)
    local message = get_locale().DeviceErrors[error_code] or get_locale().DeviceErrors.default
    Sky.Show.Notification("iFruit", message, "error", 5000)
end)

RegisterNetEvent("sky_phone:mail:changed", function(data)
    SendNUIMessage({ type = "mail:changed", data = data })
end)

RegisterNetEvent("sky_phone:mail:new", function(data)
    SendNUIMessage({ type = "mail:new", data = data })
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

    if Config.Phone.DevelopmentCommand then
        TriggerEvent("chat:removeSuggestion", "/" .. Config.Command)
    end
end)
