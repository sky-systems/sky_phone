local registered_exports = {}
local triggered_events = {}
local invoking_resource = "creator_resource"
local calls = {}
local event_handlers = {}

Config = {
    CustomApps = {
        Enabled = true,
        ExternalApps = true,
    },
    Sim = {
        NumberGroups = { 3, 4 },
        NumberLength = 7,
        NumberPrefix = "",
    },
}

exports = function(name, handler)
    registered_exports[name] = handler
end

function GetInvokingResource()
    return invoking_resource
end

function AddEventHandler(name, handler)
    event_handlers[name] = handler
end

function TriggerEvent(name, ...)
    triggered_events[#triggered_events + 1] = { name = name, arguments = { ... } }
end

local function custom_app_handler(name)
    return function(...)
        calls.custom_app = { name = name, arguments = { ... } }
        return true
    end
end

SkyPhoneApps = {
    ClientPublicApi = {
        AddCustomApp = custom_app_handler("AddCustomApp"),
        AddCustomAppFromAdapter = custom_app_handler("AddCustomAppFromAdapter"),
        CloseActiveCustomAppFromAdapter = custom_app_handler("CloseActiveCustomAppFromAdapter"),
        CloseCustomApp = custom_app_handler("CloseCustomApp"),
        CloseCustomAppFromAdapter = custom_app_handler("CloseCustomAppFromAdapter"),
        GetCustomAppCapabilities = custom_app_handler("GetCustomAppCapabilities"),
        OpenCustomApp = custom_app_handler("OpenCustomApp"),
        OpenCustomAppFromAdapter = custom_app_handler("OpenCustomAppFromAdapter"),
        RemoveCustomApp = custom_app_handler("RemoveCustomApp"),
        RemoveCustomAppFromAdapter = custom_app_handler("RemoveCustomAppFromAdapter"),
        SendAppMessage = custom_app_handler("SendAppMessage"),
        SendCustomAppMessage = custom_app_handler("SendCustomAppMessage"),
        SendCustomAppMessageFromAdapter = custom_app_handler("SendCustomAppMessageFromAdapter"),
        SendCustomAppNotification = custom_app_handler("SendCustomAppNotification"),
        SendCustomAppNotificationFromAdapter = custom_app_handler(
            "SendCustomAppNotificationFromAdapter"
        ),
        UpdateCustomApp = custom_app_handler("UpdateCustomApp"),
        UpdateCustomAppFromAdapter = custom_app_handler("UpdateCustomAppFromAdapter"),
    },
    ProtocolVersion = 1,
}
SkyPhoneClient = {
    GetEquippedPhoneNumber = function()
        return "1234567"
    end,
    GetState = function()
        return { open = true }
    end,
    Toggle = function(open, no_focus)
        calls.toggle = { open, no_focus }
        return true
    end,
}
SkyPhoneNavigation = {
    Close = function(app_id)
        calls.close_app = app_id
        return true
    end,
    GetCurrent = function()
        return "messages"
    end,
    GetState = function()
        return { currentApp = "messages", installedApps = { messages = true } }
    end,
    IsDataLoaded = function()
        return true
    end,
    IsInstalled = function(app_id)
        return app_id == "messages"
    end,
    Open = function(app_id)
        calls.open_app = app_id
        return true
    end,
}
SkyPhoneCalls = {
    Answer = function() return true end,
    Decline = function() return true end,
    Dial = function(number, company)
        calls.dial = { number, company }
        return true
    end,
    GetActive = function() return { id = "call-id" } end,
    Hangup = function() return true end,
    IsActive = function() return true end,
    Terminate = function() return true end,
}
SkyPhoneCamera = {
    DisableWalkable = function()
        calls.walkable = false
    end,
    EnableWalkable = function(selfie)
        calls.walkable = true
        calls.walkable_selfie = selfie
    end,
    GetState = function()
        return { active = calls.walkable == true, frozen = calls.frozen == true }
    end,
    SetFlashlight = function(enabled)
        calls.flashlight = enabled
    end,
    SetSelfie = function(enabled)
        calls.selfie = enabled
    end,
    ToggleFrozen = function()
        calls.frozen = not calls.frozen
    end,
}
SkyPhoneFocus = {
    SetExternalGameInput = function(owner, enabled)
        calls.focus = { owner, enabled }
        return true
    end,
}

assert(loadfile("sky_phone/source/shared/imei.lua"))()
assert(loadfile("sky_phone/source/shared/sim_number.lua"))()
assert(loadfile("sky_phone/source/shared/public_api.lua"))()
assert(loadfile("sky_phone/source/client/public_api.lua"))()

assert(registered_exports.GetApiVersion() == "1.0.0")
assert(registered_exports.IsApiReady() == true)
assert(registered_exports.NormalizePhoneNumber("(123) 4567") == "1234567")
local invalid_number, invalid_number_error = registered_exports.NormalizePhoneNumber("123")
assert(invalid_number == nil and invalid_number_error == "invalid_phone_number")
assert(registered_exports.FormatPhoneNumber("1234567") == "123 4567")
local invalid_format, invalid_format_error = registered_exports.FormatPhoneNumber("123")
assert(invalid_format == nil and invalid_format_error == "invalid_phone_number")
assert(registered_exports.IsValidImei("123456789012347") == true)

local capabilities = registered_exports.GetApiCapabilities()
assert(capabilities.side == "client" and capabilities.features.calls.audio == true)
assert(capabilities.features.calls.video == false and capabilities.customAppProtocolVersion == 1)
assert(capabilities.features.customApps.enabled and capabilities.features.customApps.external)
assert(capabilities.features.notifications.customApps)
assert(capabilities.features.notifications.system == false)
capabilities.features.calls.audio = false
assert(registered_exports.GetApiCapabilities().features.calls.audio == true,
    "capability results must be isolated copies")

assert(registered_exports.TogglePhone(true, true))
assert(calls.toggle[1] == true and calls.toggle[2] == true)
assert(registered_exports.GetPhoneState().open == true)
assert(registered_exports.GetEquippedPhoneNumber() == "1234567")

assert(registered_exports.AddCustomApp({ id = "creator-app" }))
assert(calls.custom_app.name == "AddCustomApp")
assert(registered_exports.SendAppMessage("creator-app", { type = "refresh" }))
assert(calls.custom_app.name == "SendAppMessage")
assert(calls.custom_app.arguments[1] == "creator-app")
assert(registered_exports.SendCustomAppMessage("creator-app", { type = "refresh" }))
assert(calls.custom_app.name == "SendCustomAppMessage")
assert(registered_exports.SendCustomAppNotification("creator-app", {
    title = "Creator",
    text = "Updated",
}))
assert(calls.custom_app.name == "SendCustomAppNotification")

assert(registered_exports.OpenApp("messages"))
assert(calls.open_app == "messages")
assert(registered_exports.CloseApp("messages"))
assert(calls.close_app == "messages")
assert(registered_exports.GetCurrentApp() == "messages")
assert(registered_exports.IsAppDataLoaded())
assert(registered_exports.IsAppInstalled("messages"))

assert(registered_exports.Dial("1234567"))
assert(calls.dial[1] == "1234567")
assert(registered_exports.AnswerCall())
assert(registered_exports.DeclineCall())
assert(registered_exports.HangupCall())
assert(registered_exports.TerminateCall())
assert(registered_exports.IsInCall())
assert(registered_exports.GetActiveCall().id == "call-id")

assert(registered_exports.SendNotification == nil,
    "generic notifications must not bypass custom-app ownership")

local camera_success, camera_error = registered_exports.SetFlashlight("yes")
assert(not camera_success and camera_error == "invalid_state")
assert(calls.flashlight == nil)
camera_success, camera_error = registered_exports.SetCameraFrozen(true)
assert(not camera_success and camera_error == "camera_not_active")
camera_success, camera_error = registered_exports.ToggleCameraFrozen()
assert(not camera_success and camera_error == "camera_not_active")
invoking_resource = "other_resource"
assert(registered_exports.SetFlashlight(true),
    "an inactive freeze request must not retain the camera claim")
assert(registered_exports.ReleaseCamera())
invoking_resource = "creator_resource"
assert(registered_exports.SetFlashlight(true))
assert(calls.flashlight == true)
assert(registered_exports.SetSelfieCamera(false))
assert(calls.selfie == false)
assert(registered_exports.EnableWalkableCamera(true))
assert(calls.walkable and calls.walkable_selfie)
local frozen_success, camera_state = registered_exports.SetCameraFrozen(true)
assert(frozen_success and camera_state.frozen == true)
frozen_success, camera_state = registered_exports.SetCameraFrozen(true)
assert(frozen_success and camera_state.frozen == true,
    "SetCameraFrozen must be idempotent")
invoking_resource = "other_resource"
camera_success, camera_error = registered_exports.SetFlashlight(false)
assert(not camera_success and camera_error == "camera_claimed",
    "another resource must not control a claimed camera")
invoking_resource = "creator_resource"
assert(registered_exports.DisableWalkableCamera())
assert(calls.walkable == false and calls.flashlight == false and calls.selfie == false)

assert(registered_exports.EnableWalkableCamera(false))
assert(type(event_handlers.onClientResourceStop) == "function")
event_handlers.onClientResourceStop("creator_resource")
assert(calls.walkable == false and calls.flashlight == false and calls.selfie == false,
    "camera state must be released when its owner resource stops")

assert(registered_exports.SetPhoneGameInputEnabled(true))
assert(calls.focus[1] == "creator_resource" and calls.focus[2] == true)
invoking_resource = nil
local focus_success, focus_error = registered_exports.SetPhoneGameInputEnabled(false)
assert(not focus_success and focus_error == "resource_required")

assert(triggered_events[#triggered_events].name == "sky_phone:client:apiReady")
assert(triggered_events[#triggered_events].arguments[1] == "1.0.0")

print("Client public API tests passed")
