local event_handlers = {}
local nui_callbacks = {}
local nui_messages = {}
local phone_open = false

function AddEventHandler(event_name, handler)
    event_handlers[event_name] = handler
end

function GetCurrentResourceName()
    return "sky_phone"
end

function RegisterNUICallback(callback_name, handler)
    nui_callbacks[callback_name] = handler
end

function SendNUIMessage(message)
    nui_messages[#nui_messages + 1] = message
end

SkyPhoneApps = {
    ValidateAppId = function(app_id)
        return type(app_id) == "string" and app_id:match("^[a-z0-9][a-z0-9._-]+$") ~= nil
    end,
}

SkyPhoneClient = {
    GetState = function()
        return { open = phone_open }
    end,
}

dofile("sky_phone/source/client/navigation.lua")

local callback_result
nui_callbacks["navigation:state"]({
    currentApp = "messages",
    installedApps = { "messages", "camera", "custom-app" },
}, function(result)
    callback_result = result
end)
assert(callback_result.success, "valid navigation state must be accepted")
assert(SkyPhoneNavigation.IsDataLoaded(), "accepted renderer state must mark navigation data loaded")

local closed_success, closed_error = SkyPhoneNavigation.Open("messages")
assert(not closed_success and closed_error == "phone_closed", "closed phones must reject navigation")

phone_open = true
assert(SkyPhoneNavigation.IsInstalled("messages"), "installed app lookup must use renderer state")
assert(not SkyPhoneNavigation.IsInstalled("mail"), "missing apps must not report installed")
assert(SkyPhoneNavigation.GetCurrent() == "messages", "current app lookup must preserve the renderer route")
assert(SkyPhoneNavigation.GetCurrent("messages"), "current app predicate must match")
assert(not SkyPhoneNavigation.GetCurrent("camera"), "current app predicate must reject another app")
local missing_success, missing_error = SkyPhoneNavigation.Open("mail")
assert(not missing_success and missing_error == "app_not_installed", "uninstalled apps must be rejected")

local open_success, open_error = SkyPhoneNavigation.Open("camera")
assert(open_success and open_error == nil, "installed apps must open")
assert(nui_messages[1].type == "navigation:open-app", "open must use the neutral NUI route")
assert(nui_messages[1].data.appId == "camera", "open must preserve the app id")

local wrong_close_success, wrong_close_error = SkyPhoneNavigation.Close("messages")
assert(not wrong_close_success and wrong_close_error == "app_not_active", "targeted close must match the active app")

local close_success, close_error = SkyPhoneNavigation.Close("camera")
assert(close_success and close_error == nil, "the active app must close")
assert(nui_messages[2].type == "navigation:close-app", "close must use the neutral NUI route")
assert(nui_messages[2].data.appId == "camera", "close must guard against stale router commands")

nui_callbacks["navigation:state"]({
    currentApp = nil,
    installedApps = { "messages" },
}, function(result)
    callback_result = result
end)
assert(callback_result.success, "home navigation state must be accepted")
assert(SkyPhoneNavigation.GetCurrent() == "home", "an open phone without an app must report home")

phone_open = false
event_handlers["sky_phone:client:phoneToggled"](false)
local reset_state = SkyPhoneNavigation.GetState()
assert(reset_state.currentApp == nil and reset_state.installedApps.messages,
    "phone close must preserve the loaded device app catalog")
assert(reset_state.dataLoaded and SkyPhoneNavigation.IsDataLoaded(),
    "closing the UI must not make durable app data unavailable")
assert(SkyPhoneNavigation.GetCurrent() == nil, "a closed phone must not report a current app")
assert(not SkyPhoneNavigation.GetCurrent("messages"), "a closed phone must fail current app predicates")

nui_callbacks["navigation:state"]({
    currentApp = false,
    installedApps = { "messages" },
}, function(result)
    callback_result = result
end)
assert(not callback_result.success and callback_result.error == "invalid_current_app", "invalid state must be rejected")

print("Client navigation tests passed")
