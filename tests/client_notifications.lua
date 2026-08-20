local net_events = {}
local nui_messages = {}
local registered_apps = {
    ["custom-chat"] = true,
    messages = true,
}

Config = {
    Bridge = {
        Locale = "en",
    },
}

SkyPhoneApps = {
    CanReceiveNotification = function(app_id)
        return registered_apps[app_id] == true
    end,
    ValidateAppId = function(app_id)
        return type(app_id) == "string"
            and #app_id <= 64
            and app_id:match("^[a-z0-9][a-z0-9._-]+$") ~= nil
    end,
}

SkyPhoneLocales = {
    Resolve = function()
        return {
            Nui = {
                Apps = {},
            },
        }
    end,
}

SkyPhoneNavigation = nil

Bridge = {
    Callbacks = {
        Trigger = function(name, notification)
            assert(name == "sky_phone:notifications:self")
            assert(notification.device == nil, "self notifications must not carry caller device data")
            return { success = true, data = { delivered = 1 } }
        end,
    },
    Debug = function() end,
    Framework = {
        Notify = function() end,
    },
}

function RegisterNetEvent(name, callback)
    net_events[name] = callback
end

function SendNUIMessage(message)
    nui_messages[#nui_messages + 1] = message
end

function TriggerEvent()
end

assert(loadfile("sky_phone/source/shared/imei.lua"))()
assert(loadfile("sky_phone/source/client/notifications.lua"))()

local success, error_code = SkyPhoneNotifications.Show(nil)
assert(not success and error_code == "invalid_notification", "non-table notifications must be rejected")

success, error_code = SkyPhoneNotifications.Show({
    appId = "messages",
    app_id = "mail",
    title = "Title",
    text = "Text",
})
assert(not success and error_code == "invalid_app_id", "conflicting app aliases must be rejected")

success, error_code = SkyPhoneNotifications.Show({
    appId = "missing-app",
    title = "Title",
    text = "Text",
})
assert(not success and error_code == "invalid_app_id", "unknown apps must not receive notifications")

success, error_code = SkyPhoneNotifications.Show({
    appId = "messages",
    title = string.rep("x", 161),
    text = "Text",
})
assert(not success and error_code == "invalid_title", "notification titles must be bounded")

success, error_code = SkyPhoneNotifications.Show({
    app_id = "custom-chat",
    body = "  Custom body  ",
    device = {
        imei = "123456789012347",
        name = "Spoofed",
    },
    title = "  Custom title  ",
    url = "https://invalid.example",
})
assert(success, error_code)
assert(#nui_messages == 1, "valid local notifications must reach NUI while the phone is closed")
assert(nui_messages[1].type == "notification:show", "notification NUI route changed")
assert(nui_messages[1].data.appId == "custom-chat", "app_id alias was not normalized")
assert(nui_messages[1].data.route == "/apps/custom-chat", "safe app route was not generated")
assert(nui_messages[1].data.title == "Custom title", "title was not normalized")
assert(nui_messages[1].data.text == "Custom body", "body alias was not normalized")
assert(nui_messages[1].data.device == nil, "local callers must not inject a device context")
assert(nui_messages[1].data.url == nil, "arbitrary URLs must not cross the notification boundary")

local send_result
success, send_result = SkyPhoneNotifications.Send({
    appId = "messages",
    title = "Server-routed",
    text = "Authoritative device",
})
assert(success and send_result.delivered == 1, "self notifications must use the server router")
assert(#nui_messages == 1, "self notifications must wait for authoritative server delivery")

source = 42
net_events["sky_phone:notifications:show"]({
    appId = "messages",
    device = {
        imei = "123456789012347",
        name = "Phone",
    },
    title = "Spoofed",
    text = "Spoofed",
})
assert(#nui_messages == 1, "client-triggered delivery events must be rejected")

source = 65535
net_events["sky_phone:notifications:show"]({
    appId = "messages",
    title = "Missing device",
    text = "Rejected",
})
assert(#nui_messages == 1, "server deliveries without a device must be rejected")

net_events["sky_phone:notifications:show"]({
    appId = "messages",
    device = {
        imei = "123456789012347",
        name = "  Work Phone  ",
        settings = [[{"version":1}]],
    },
    title = "Server",
    text = "Delivered",
})
assert(#nui_messages == 2, "server-originated delivery must reach NUI while navigation is empty")
local delivered = nui_messages[2].data
assert(delivered.device.imei == "123456789012347", "server IMEI context was dropped")
assert(delivered.device.name == "Work Phone", "server device name was not normalized")
assert(delivered.device.settings == [[{"version":1}]], "server device settings were dropped")
assert(delivered.route == "/apps/messages", "server notification route changed")

net_events["sky_phone:notifications:show"]({
    appId = "messages",
    device = {
        imei = "invalid",
        name = "Phone",
    },
    title = "Invalid",
    text = "Rejected",
})
assert(#nui_messages == 2, "invalid server device contexts must be rejected")

print("Client notification router tests passed")
