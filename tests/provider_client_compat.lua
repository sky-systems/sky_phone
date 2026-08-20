local alias_handlers = {}
local event_handlers = {}
local net_events = {}
local registered_commands = {}
local registered_exports = {}
local toggle_calls = {}
local flashlight_calls = {}
local selfie_calls = {}
local navigation_calls = {}
local focus_calls = {}
local dial_calls = {}
local terminate_calls = 0
local answer_calls = 0
local decline_calls = 0
local notification_calls = {}
local quasar_push_notifications = {}
local phone_state = {
    inCall = false,
    onScreen = true,
    open = true,
}

Config = {
    Sim = {
        NumberGroups = { 3, 4 },
        NumberLength = 7,
        NumberPrefix = "",
    },
}

Bridge = {
    Debug = function() end,
}

SkyPhoneApps = {
    CompatibilityCore = {
        Add = function() return true end,
        Close = function() return true end,
        CloseActive = function() return true end,
        Open = function() return true end,
        Remove = function() return true end,
        SendMessage = function() return true end,
        Update = function() return true end,
    },
    Debug = function() end,
}

SkyPhoneClient = {
    GetEquippedPhoneNumber = function()
        return "5550101"
    end,
    GetState = function()
        return phone_state
    end,
    Toggle = function(...)
        toggle_calls[#toggle_calls + 1] = table.pack(...)
        return true
    end,
}

SkyPhoneCalls = {
    Answer = function()
        answer_calls = answer_calls + 1
        return true
    end,
    Decline = function()
        decline_calls = decline_calls + 1
        return true
    end,
    Dial = function(phone_number)
        dial_calls[#dial_calls + 1] = phone_number
        if phone_number == "5559999" then
            return false, "target_unavailable"
        end
        return true
    end,
    Terminate = function()
        terminate_calls = terminate_calls + 1
        return true
    end,
}

SkyPhoneNotifications = {
    Send = function(notification)
        notification_calls[#notification_calls + 1] = notification
        return true
    end,
    Show = function()
        error("provider notifications must use the server-authoritative Send path")
    end,
}

SkyPhoneCamera = {
    DisableWalkable = function() end,
    EnableWalkable = function() end,
    GetState = function()
        return {
            active = false,
            flashEnabled = flashlight_calls[#flashlight_calls] == true,
            selfie = selfie_calls[#selfie_calls] == true,
            walkable = false,
        }
    end,
    SetFlashlight = function(enabled)
        flashlight_calls[#flashlight_calls + 1] = enabled
    end,
    SetSelfie = function(enabled)
        selfie_calls[#selfie_calls + 1] = enabled
    end,
    ToggleFrozen = function() end,
}

SkyPhoneNavigation = {
    Close = function(app_id)
        navigation_calls[#navigation_calls + 1] = { action = "close", appId = app_id }
        return true
    end,
    GetCurrent = function(app_id)
        if app_id ~= nil then
            return app_id == "messages"
        end
        return "messages"
    end,
    IsInstalled = function(app_id)
        return app_id == "messages"
    end,
    Open = function(app_id)
        navigation_calls[#navigation_calls + 1] = { action = "open", appId = app_id }
        if app_id == "messages" then
            return true
        end
        return false, "app_not_installed"
    end,
}

SkyPhoneFocus = {
    SetExternalGameInput = function(owner_resource, allow_game_input)
        focus_calls[#focus_calls + 1] = {
            allow = allow_game_input,
            owner = owner_resource,
        }
        return true
    end,
}

exports = setmetatable({}, {
    __call = function(_, export_name, handler)
        registered_exports[export_name] = handler
    end,
})

function GetCurrentResourceName()
    return "sky_phone"
end

function GetInvokingResource()
    return "provider_test"
end

function AddEventHandler(event_name, handler)
    local handlers = event_handlers[event_name] or {}
    handlers[#handlers + 1] = handler
    event_handlers[event_name] = handlers
end

function RegisterNetEvent(event_name, handler)
    net_events[event_name] = handler
end

function RegisterCommand(command_name, handler)
    registered_commands[command_name] = handler
end

function TriggerEvent(event_name, ...)
    local handlers = event_handlers[event_name] or {}
    for index = 1, #handlers do
        handlers[index](...)
    end
end

function SendNUIMessage() end

dofile("sky_phone/source/shared/sim_number.lua")
dofile("sky_phone/source/bridge/phones/shared.lua")
for _, path in ipairs({
    "sky_phone/source/bridge/phones/shared/lb.lua",
    "sky_phone/source/bridge/phones/shared/seventeen.lua",
    "sky_phone/source/bridge/phones/shared/high.lua",
    "sky_phone/source/bridge/phones/shared/quasar.lua",
    "sky_phone/source/bridge/phones/shared/yseries.lua",
}) do
    dofile(path)
end
for _, path in ipairs({
    "sky_phone/source/bridge/phones/client/core.lua",
    "sky_phone/source/bridge/phones/client/lb.lua",
    "sky_phone/source/bridge/phones/client/seventeen.lua",
    "sky_phone/source/bridge/phones/client/high.lua",
    "sky_phone/source/bridge/phones/client/quasar.lua",
    "sky_phone/source/bridge/phones/client/yseries.lua",
}) do
    dofile(path)
end

local function get_alias(resource_name, export_name)
    local event_name = ("__cfx_export_%s_%s"):format(resource_name, export_name)
    local handlers = assert(event_handlers[event_name], "missing alias event: " .. event_name)
    local alias_handler
    handlers[#handlers](function(handler)
        alias_handler = handler
    end)
    alias_handlers[event_name] = assert(alias_handler, "missing alias handler: " .. event_name)
    return alias_handler
end

local function assert_no_return(handler, ...)
    assert(table.pack(handler(...)).n == 0, "documented no-return export leaked a return value")
end

local mov_open = get_alias("17mov_Phone", "OpenPhone")
local mov_close = get_alias("17mov_Phone", "ClosePhone")
local mov_is_open = get_alias("17mov_Phone", "IsPhoneOpen")
local mov_get_number = get_alias("17mov_Phone", "GetPlayerNumber")
local mov_toggle_flashlight = get_alias("17mov_Phone", "ToggleFlashlight")
local mov_get_flashlight = get_alias("17mov_Phone", "GetFlashlightState")
local mov_create_notification = get_alias("17mov_Phone", "CreateNotification")
local mov_open_app = get_alias("17mov_Phone", "OpenApp")
local mov_close_app = get_alias("17mov_Phone", "CloseApp")

assert_no_return(mov_open)
assert(toggle_calls[#toggle_calls].n == 1 and toggle_calls[#toggle_calls][1] == true)
assert_no_return(mov_close)
assert(toggle_calls[#toggle_calls].n == 1 and toggle_calls[#toggle_calls][1] == false)
assert(mov_is_open() == true)
assert(mov_get_number() == "5550101")
local flashlight_count = #flashlight_calls
assert_no_return(mov_toggle_flashlight, "true")
assert(#flashlight_calls == flashlight_count, "17Movement flashlight must reject non-booleans")
assert_no_return(mov_toggle_flashlight, true)
assert(flashlight_calls[#flashlight_calls] == true and mov_get_flashlight() == true)
assert_no_return(mov_create_notification, {
    app = "MESSAGES",
    message = "Hello",
    title = "Message",
})
assert(notification_calls[#notification_calls].appId == "messages")
assert(notification_calls[#notification_calls].text == "Hello")
local notification_count = #notification_calls
assert_no_return(mov_create_notification, {
    app = "MESSAGES",
    message = { key = "Messages:NewMessage" },
    title = "Message",
})
assert(#notification_calls == notification_count,
    "17Movement locale-object notifications must remain visibly unsupported")
assert_no_return(mov_open_app, "messages")
assert(navigation_calls[#navigation_calls].action == "open" and navigation_calls[#navigation_calls].appId == "messages")
assert_no_return(mov_close_app, "messages")
assert(navigation_calls[#navigation_calls].action == "close" and navigation_calls[#navigation_calls].appId == "messages")

local high_close = get_alias("high-phone", "closePhone")
local high_start_call = get_alias("high-phone", "startCall")
local high_end_call = get_alias("high-phone", "endCall")
local high_send_notification = get_alias("high-phone", "sendNotification")
local high_set_facing = get_alias("high-phone", "setCameraFacing")
local high_format_number = get_alias("high-phone", "formatNumber")
local high_use_phone_item = get_alias("high-phone", "usePhoneItem")

assert_no_return(high_close)
assert(toggle_calls[#toggle_calls][1] == false)
assert_no_return(high_start_call, "5550101", false)
assert(dial_calls[#dial_calls] == "5550101")
local dial_count = #dial_calls
assert_no_return(high_start_call, "5550102", true)
assert(#dial_calls == dial_count, "High Phone video calls must be rejected")
assert_no_return(high_start_call, "5550102", "false")
assert(#dial_calls == dial_count, "High Phone must reject a non-boolean video flag")
assert_no_return(high_end_call)
assert(terminate_calls == 1)
assert_no_return(high_send_notification, {
    application = { name = "twizzler" },
    content = "World",
    duration = 5000,
    title = "Hello",
})
assert(notification_calls[#notification_calls].appId == "flare")
assert(notification_calls[#notification_calls].text == "World")
notification_count = #notification_calls
assert_no_return(high_send_notification, {
    content = "No application",
})
assert(#notification_calls == notification_count,
    "High notifications without an application remain a documented partial")
assert_no_return(high_set_facing, "front")
assert(selfie_calls[#selfie_calls] == true)
assert_no_return(high_set_facing, "rear")
assert(selfie_calls[#selfie_calls] == false)
local selfie_count = #selfie_calls
assert_no_return(high_set_facing, "side")
assert(#selfie_calls == selfie_count, "High Phone facing must reject unknown values")
assert(high_format_number("5550101") == "555 0101")
assert_no_return(high_use_phone_item, { ignored = true })
assert(toggle_calls[#toggle_calls][1] == true)

local quasar_is_open = get_alias("qs-smartphone", "IsPhoneOpen")
local quasar_call = get_alias("qs-smartphone", "call")
local quasar_open_app = get_alias("qs-smartphone", "OpenPhoneApp")
assert(quasar_is_open() == true)
local open_result = table.pack(quasar_open_app("messages"))
assert(open_result.n == 1 and open_result[1] == true, "Quasar OpenPhoneApp must return one boolean")
open_result = table.pack(quasar_open_app("missing"))
assert(open_result.n == 1 and open_result[1] == false, "Quasar OpenPhoneApp failure leaked an error")
local call_result = quasar_call("5550102", "audio")
assert(call_result.success == true and call_result.error == nil)
call_result = quasar_call("5559999", "audio")
assert(call_result.success == false and call_result.error == "target_unavailable")
dial_count = #dial_calls
call_result = quasar_call("5550103", "video")
assert(call_result.success == false and call_result.error == "video_unsupported")
assert(#dial_calls == dial_count, "Quasar video calls must be rejected before dialing")
call_result = quasar_call("5550103", "fax")
assert(call_result.success == false and call_result.error == "invalid_call_type")
assert(type(registered_commands["phone:toggle"]) == "function")
registered_commands["phone:toggle"]()
assert(toggle_calls[#toggle_calls].n == 0, "Quasar toggle command must use neutral toggle semantics")
assert(type(registered_commands["phone_peek_call_accept"]) == "function")
assert(type(registered_commands["phone_peek_call_reject"]) == "function")
registered_commands["phone_peek_call_accept"]()
registered_commands["phone_peek_call_reject"]()
assert(answer_calls == 1 and decline_calls == 1)
AddEventHandler("phone:pushNotification", function(notification)
    quasar_push_notifications[#quasar_push_notifications + 1] = notification
end)
TriggerEvent("sky_phone:client:pushNotification", {
    appId = "messages",
    text = "Push",
    title = "Quasar",
})
assert(#quasar_push_notifications == 1, "Quasar push notification event was not forwarded")
assert(quasar_push_notifications[1].appId == "messages")
assert(quasar_push_notifications[1].text == "Push")

local yseries_toggle = get_alias("yseries", "ToggleOpen")
local yseries_is_open = get_alias("yseries", "IsOpen")
local yseries_toggle_flashlight = get_alias("yseries", "ToggleFlashlight")
local yseries_get_flashlight = get_alias("yseries", "GetFlashlightState")
local yseries_close_app = get_alias("yseries", "CloseApp")
local yseries_is_app_installed = get_alias("yseries", "IsAppInstalled")
local yseries_get_current_app = get_alias("yseries", "GetCurrentAppId")
local yseries_set_focus = get_alias("yseries", "SetNuiFocusKeepInput")
local yseries_cancel_call = get_alias("yseries", "CancelCall")

assert_no_return(yseries_toggle, false)
assert(toggle_calls[#toggle_calls][1] == false and yseries_is_open() == true)
flashlight_count = #flashlight_calls
assert_no_return(yseries_toggle_flashlight, 1)
assert(#flashlight_calls == flashlight_count, "YSeries flashlight must reject non-booleans")
assert_no_return(yseries_toggle_flashlight, false)
assert(flashlight_calls[#flashlight_calls] == false and yseries_get_flashlight() == false)
assert_no_return(yseries_close_app)
assert(navigation_calls[#navigation_calls].action == "close" and navigation_calls[#navigation_calls].appId == nil)
assert(yseries_is_app_installed("messages") and not yseries_is_app_installed("mail"))
assert(yseries_get_current_app() == "messages")
assert(yseries_get_current_app("messages") and not yseries_get_current_app("mail"))
assert_no_return(yseries_set_focus, false)
assert(focus_calls[#focus_calls].owner == "provider_test" and focus_calls[#focus_calls].allow == false)
assert_no_return(yseries_cancel_call)
assert(terminate_calls == 2)

assert(next(registered_exports) == nil, "provider bridge must not publish bare vendor exports")
for _, path in ipairs({
    "sky_phone/source/bridge/phones/client/core.lua",
    "sky_phone/source/bridge/phones/client/lb.lua",
    "sky_phone/source/bridge/phones/client/seventeen.lua",
    "sky_phone/source/bridge/phones/client/high.lua",
    "sky_phone/source/bridge/phones/client/quasar.lua",
    "sky_phone/source/bridge/phones/client/yseries.lua",
    "sky_phone/source/bridge/phones/client/lifecycle.lua",
}) do
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    assert(not source:match("[^%a]exports%s*%("), "bare exports() registration found in " .. path)
end

print("Provider client compatibility tests passed")
