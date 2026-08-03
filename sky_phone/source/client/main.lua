local is_open = false

local function get_locale()
    return Locales[Sky.Config.locale] or Locales["en"]
end

local function send_open_message()
    SendNUIMessage({
        type = "app:open",
        data = {
            lang = Sky.Config.locale,
            locales = get_locale().Nui,
        },
    })
end

local function open_phone()
    if is_open then
        return
    end

    is_open = true
    SetNuiFocus(true, true)
    send_open_message()
end

local function close_phone()
    if not is_open then
        return
    end

    is_open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = "app:close" })
end

RegisterCommand(Config.Command, function()
    if is_open then
        close_phone()
        return
    end

    open_phone()
end, false)

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

CreateThread(function()
    TriggerEvent("chat:addSuggestion", "/" .. Config.Command, get_locale().CommandDescription)
end)

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name ~= GetCurrentResourceName() then
        return
    end

    if is_open then
        SetNuiFocus(false, false)
    end

    TriggerEvent("chat:removeSuggestion", "/" .. Config.Command)
end)
