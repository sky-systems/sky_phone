local invoking_resource = "creator_resource"
local client_events = {}
local encoded_value
local notification_requests = {}

Config = {
    CustomApps = {
        BundledApps = false,
        Enabled = true,
        ExternalApps = true,
        MaximumMessageBytes = 64,
        TrustedAdapters = {},
    },
}

json = {
    decode = function(encoded)
        if encoded:sub(1, 1) == '"' then
            return encoded:sub(2, -2)
        end
        return encoded_value
    end,
    encode = function(value)
        if type(value) == "function" then
            error("unsupported")
        end
        if type(value) == "string" then
            return '"' .. value .. '"'
        end
        encoded_value = value
        return "{}"
    end,
}

SkyPhoneNotifications = {
    Send = function(target, notification)
        notification_requests[#notification_requests + 1] = {
            notification = notification,
            target = target,
        }
        return { delivered = target.value == 10 and 1 or 0 }
    end,
}

Bridge = {
    Debug = function() end,
    Framework = {
        GetIdentifier = function(source)
            return source == 10 and "license:online" or nil
        end,
    },
}

function AddEventHandler() end
function GetCurrentResourceName() return "sky_phone" end
function GetInvokingResource() return invoking_resource end
function GetResourceState() return "started" end
function TriggerClientEvent(name, target, ...)
    client_events[#client_events + 1] = {
        arguments = { ... },
        name = name,
        target = target,
    }
end

assert(loadfile("sky_phone/source/shared/custom_apps.lua"))()
assert(loadfile("sky_phone/source/server/custom_apps.lua"))()

local api = assert(SkyPhoneApps.ServerPublicApi)
local capabilities = api.GetCustomAppCapabilities()
assert(capabilities.enabled and capabilities.externalApps)
assert(capabilities.messageDispatch and capabilities.notificationDispatch)
assert(api.AddCustomAppPolicy({
    id = "creator-app",
    permissions = { "app.open", "notifications" },
}))

assert(api.SendAppMessage(10, "creator-app", {
    action = "refresh",
    revision = 2,
}))
assert(#client_events == 1, "valid server app messages must emit exactly one client event")
assert(client_events[1].name == "sky_phone:custom-app:message")
assert(client_events[1].target == 10)
assert(client_events[1].arguments[1] == "creator_resource",
    "the server must bind messages to the invoking owner resource")
assert(client_events[1].arguments[2] == "creator-app")
assert(client_events[1].arguments[3].action == "refresh")

local notification_success, notification_result = api.SendCustomAppNotification(
    10,
    "creator-app",
    {
        title = "Creator",
        content = "Updated",
    }
)
assert(notification_success and notification_result.delivered == 1)
assert(#notification_requests == 1)
assert(notification_requests[1].target.kind == "source")
assert(notification_requests[1].target.value == 10)
assert(notification_requests[1].notification.appId == "creator-app")
assert(notification_requests[1].notification.text == "Updated")

notification_success, notification_result = api.SendCustomAppNotification(
    20,
    "creator-app",
    {
        title = "Creator",
        text = "Offline",
    }
)
assert(not notification_success and notification_result == "device_not_equipped")

notification_success, notification_result = api.SendCustomAppNotification(
    10,
    "creator-app",
    {
        appId = "other-app",
        title = "Creator",
        text = "Spoofed",
    }
)
assert(not notification_success and notification_result == "invalid_app_id")

local success, error_code = api.SendCustomAppMessage("10", "creator-app", {})
assert(not success and error_code == "invalid_source", "message targets must remain strictly typed")

success, error_code = api.SendCustomAppMessage(20, "creator-app", {})
assert(not success and error_code == "player_unavailable", "offline message targets must fail visibly")

success, error_code = api.SendCustomAppMessage(10, "creator-app", string.rep("x", 65))
assert(not success and error_code == "payload_too_large", "message payload limits must be server enforced")

success, error_code = api.SendCustomAppMessage(10, "creator-app", function() end)
assert(not success and error_code == "invalid_payload", "non-JSON message payloads must be rejected")

invoking_resource = "other_resource"
success, error_code = api.SendCustomAppMessage(10, "creator-app", {})
assert(not success and error_code == "app_owner_mismatch",
    "a different resource must not message another owner's app")
assert(#client_events == 1, "rejected messages must not reach a client")

notification_success, notification_result = api.SendCustomAppNotification(
    10,
    "creator-app",
    { title = "Creator", text = "Spoofed" }
)
assert(not notification_success and notification_result == "app_owner_mismatch")

print("Custom app server messaging tests passed")
