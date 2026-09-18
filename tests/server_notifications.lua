local migration_callback
local client_events = {}
local registered_callbacks = {}
local players = {}
local source_lookup_counts = {}
local volatile_source

Config = {
    Sim = {
        NumberLength = 6,
        NumberPrefix = "",
    },
}

local online_by_source = {
    [10] = {
        imei = "123456789012347",
        phoneNumber = "555010",
        source = 10,
    },
    [30] = {
        imei = "223456789012346",
        phoneNumber = "555030",
        source = 30,
    },
}

Bridge = {
    Callbacks = {
        Register = function(name, handler)
            registered_callbacks[name] = handler
        end,
    },
    Database = {
        AfterMigration = function(name, callback)
            assert(name == "sky_phone")
            migration_callback = callback
        end,
        Query = function(query, parameters)
            assert(query:find("sky_phone_devices", 1, true), "device context query changed")
            local imei = parameters[1]
            local identities = {
                ["123456789012347"] = {
                    device_name = "Phone 10",
                    imei = "123456789012347",
                    settings = [[{"version":1,"source":10}]],
                },
                ["223456789012346"] = {
                    device_name = "Phone 30",
                    imei = "223456789012346",
                    settings = [[{"version":1,"source":30}]],
                },
                ["323456789012345"] = {
                    device_name = "Phone 40",
                    imei = "323456789012345",
                    settings = [[{"version":1,"source":40}]],
                },
            }
            return identities[imei] and { identities[imei] } or {}
        end,
    },
    Debug = function() end,
    Framework = {
        GetPlayers = function()
            return players
        end,
    },
}

SkyPhoneApps = {
    ValidateAppId = function(app_id)
        return type(app_id) == "string"
            and #app_id <= 64
            and app_id:match("^[a-z0-9][a-z0-9._-]+$") ~= nil
    end,
}

SkyPhoneDeviceDirectory = {
    GetOnlineBySource = function(player_source)
        source_lookup_counts[player_source] = (source_lookup_counts[player_source] or 0) + 1
        if player_source == volatile_source and source_lookup_counts[player_source] >= 3 then
            return nil, "device_not_equipped"
        end
        return online_by_source[player_source]
    end,
    GetOnlineByPhoneNumber = function(phone_number)
        if phone_number == "555030" then
            return online_by_source[30]
        end
        if phone_number == "555099" then
            return {
                imei = "223456789012346",
                phoneNumber = "555099",
                source = 30,
            }
        end
        return nil, "player_unavailable"
    end,
    GetOnlineByImei = function(imei)
        if imei == "123456789012347" then
            return online_by_source[10]
        end
        return nil, "player_unavailable"
    end,
}

function TriggerClientEvent(name, target, payload)
    client_events[#client_events + 1] = {
        name = name,
        payload = payload,
        target = target,
    }
end

assert(loadfile("sky_phone/source/shared/imei.lua"))()
assert(loadfile("sky_phone/source/shared/sim_number.lua"))()
assert(loadfile("sky_phone/source/server/notifications.lua"))()
assert(type(migration_callback) == "function", "notification router must wait for migrations")
migration_callback()
local self_notification = assert(registered_callbacks["sky_phone:notifications:self"],
    "self notification callback must be registered after migration")

local notification = {
    app_id = "messages",
    body = "  Body  ",
    title = "  Title  ",
    url = "https://invalid.example",
}

local result, error_code = SkyPhoneNotifications.Send(
    { kind = "source", value = "10" },
    notification
)
assert(result == nil and error_code == "invalid_target", "source targets must remain strictly typed")
assert(#client_events == 0, "invalid targets must not deliver")

result, error_code = SkyPhoneNotifications.Send(
    { kind = "number", value = "not-a-number" },
    notification
)
assert(result == nil and error_code == "invalid_target", "malformed numbers must be rejected")

result, error_code = SkyPhoneNotifications.Send(
    { kind = "device", value = "invalid-imei" },
    notification
)
assert(result == nil and error_code == "invalid_target", "malformed IMEIs must be rejected")

result, error_code = SkyPhoneNotifications.Send(
    { kind = "source", value = 10 },
    {
        appId = "messages",
        title = string.rep("x", 161),
        text = "Body",
    }
)
assert(result == nil and error_code == "invalid_title", "server payload bounds must be enforced")

source_lookup_counts = {}
result = assert(SkyPhoneNotifications.Send({ kind = "source", value = 10 }, notification))
assert(result.delivered == 1, "equipped source target must receive one notification")
assert(client_events[1].name == "sky_phone:notifications:show", "notification event name changed")
assert(client_events[1].target == 10, "notification source target changed")
assert(client_events[1].payload.appId == "messages", "app_id alias was not normalized")
assert(client_events[1].payload.title == "Title" and client_events[1].payload.text == "Body",
    "notification text was not normalized")
assert(client_events[1].payload.url == nil, "unsafe fields must not cross the server boundary")
assert(client_events[1].payload.device.imei == "123456789012347",
    "the final equipped IMEI must be attached")
assert(client_events[1].payload.device.name == "Phone 10",
    "the final device name must be attached")
assert(client_events[1].payload.device.settings == [[{"version":1,"source":10}]],
    "the final device settings must be attached")
assert(source_lookup_counts[10] == 3, "delivery must revalidate after loading device context")

source_lookup_counts = {}
local self_result = self_notification(10, notification)
assert(self_result.success and self_result.data.delivered == 1,
    "self notifications must resolve the caller's equipped device")
assert(client_events[#client_events].payload.device.imei == "123456789012347",
    "self notifications must carry the authoritative equipped IMEI")
client_events[#client_events] = nil

local unavailable_self_result = self_notification(20, notification)
assert(not unavailable_self_result.success and unavailable_self_result.error == "device_not_equipped",
    "self notifications without an equipped device must fail visibly")

source_lookup_counts = {}
result = assert(SkyPhoneNotifications.Send({ kind = "source", value = 20 }, notification))
assert(result.delivered == 0, "players without an equipped device must not receive notifications")
assert(#client_events == 1, "no-delivery results must not emit an event")

source_lookup_counts = {}
result = assert(SkyPhoneNotifications.Send({ kind = "number", value = "555099" }, notification))
assert(result.delivered == 0, "changed phone-number ownership must fail revalidation")
assert(#client_events == 1, "failed number revalidation must not deliver")

source_lookup_counts = {}
result = assert(SkyPhoneNotifications.Send(
    { kind = "device", value = "123456789012347" },
    notification
))
assert(result.delivered == 1, "equipped device targets must deliver")
assert(client_events[2].target == 10, "device target resolved to the wrong source")
assert(client_events[2].payload.device.imei == "123456789012347")

players = { 40 }
online_by_source[40] = {
    imei = "323456789012345",
    phoneNumber = "555040",
    source = 40,
}
source_lookup_counts = {}
volatile_source = 40
result = assert(SkyPhoneNotifications.Send({ kind = "all" }, notification))
assert(result.delivered == 0, "a device switch during delivery must fail final revalidation")
assert(#client_events == 2, "stale broadcast candidates must not receive notifications")

players = { "10", 10, 20, 30, "30" }
source_lookup_counts = {}
volatile_source = nil
result = assert(SkyPhoneNotifications.Send({ kind = "all" }, notification))
assert(result.delivered == 2, "broadcast must deduplicate equipped online players")
assert(#client_events == 4, "broadcast count must match emitted events")

local broadcast_targets = {}
for index = 1, #client_events do
    local event = client_events[index]
    assert(event.target ~= -1, "notification broadcasts must never use blind -1 delivery")
    if index >= 3 then
        broadcast_targets[event.target] = (broadcast_targets[event.target] or 0) + 1
    end
end
assert(broadcast_targets[10] == 1 and broadcast_targets[30] == 1,
    "broadcast recipients must be unique and equipped")

result, error_code = SkyPhoneNotifications.Send({ kind = "all", value = true }, notification)
assert(result == nil and error_code == "invalid_target", "all targets must reject extra values")

print("Server notification router tests passed")
