local event_handlers = {}
local migration_callbacks = {}
local ended_sources = {}
local notification_deliveries = {}
local active_calls = {
    [10] = {
        id = "550e8400-e29b-41d4-a716-446655440010",
        caller = { source = 10, number = "5550101" },
        callee = { source = 11, number = "5550111" },
        startedAt = 1700000000,
        anonymous = false,
        video = false,
    },
    [20] = {
        id = "550e8400-e29b-41d4-a716-446655440020",
        caller = { source = 20, number = "5550102" },
        callee = { source = 21, number = "5550121" },
        startedAt = 1700000001,
        anonymous = true,
        companyId = "police",
        video = false,
    },
}

Bridge = {
    Database = {
        AfterMigration = function(name, callback)
            assert(name == "sky_phone")
            migration_callbacks[#migration_callbacks + 1] = callback
        end,
    },
    Debug = function() end,
}

local phone_core = {
    FormatNumber = function(phone_number)
        return phone_number
    end,
    GetEquippedPhoneNumber = function(player_source)
        return player_source == 10 and "5550101" or nil
    end,
    GetSourceFromNumber = function(phone_number)
        return ({ ["5550101"] = 10, ["5550102"] = 20 })[tostring(phone_number)]
    end,
}
SkyPhoneApps = {}
SkyPhoneCalls = nil

function AddEventHandler(event_name, handler)
    local handlers = event_handlers[event_name] or {}
    handlers[#handlers + 1] = handler
    event_handlers[event_name] = handlers
end

function RegisterNetEvent(event_name, handler)
    AddEventHandler(event_name, handler)
end

function GetCurrentResourceName()
    return "sky_phone"
end

function GetInvokingResource()
    return "provider_test"
end

function TriggerClientEvent()
end

dofile("sky_phone/source/bridge/phones/shared.lua")
dofile("sky_phone/source/bridge/phones/shared/seventeen.lua")
dofile("sky_phone/source/bridge/phones/shared/high.lua")
dofile("sky_phone/source/bridge/phones/server/core.lua")
dofile("sky_phone/source/bridge/phones/server/high.lua")
dofile("sky_phone/source/bridge/phones/server/quasar.lua")
dofile("sky_phone/source/bridge/phones/server/seventeen.lua")

assert(SkyPhone == nil, "provider bridge must load before the migrated phone core exists")
assert(
    SkyPhoneCompatibilityServer.Phone == nil,
    "provider bridge must not cache a phone service before migration"
)
SkyPhone = phone_core
for index = 1, #migration_callbacks do
    migration_callbacks[index]()
end
assert(
    SkyPhoneCompatibilityServer.Phone == phone_core,
    "provider bridge must bind the migrated phone service"
)

SkyPhoneCalls = {
    EndForSource = function(player_source)
        ended_sources[#ended_sources + 1] = player_source
        if not active_calls[player_source] then
            return false, "call_not_found"
        end
        active_calls[player_source] = nil
        return true
    end,
    GetById = function(call_id)
        for _, call in pairs(active_calls) do
            if call.id == call_id then
                return call
            end
        end
        return nil, "call_not_found"
    end,
    GetForSource = function(player_source)
        local call = active_calls[player_source]
        if not call then
            return nil, "call_not_found"
        end
        return call
    end,
    IsActiveForSource = function(player_source)
        return active_calls[player_source] ~= nil
    end,
    TerminateForSource = function(player_source)
        ended_sources[#ended_sources + 1] = player_source
        if not active_calls[player_source] then
            return false, "call_not_found"
        end
        active_calls[player_source] = nil
        return true
    end,
}
SkyPhoneNotifications = {
    Send = function(target, notification)
        notification_deliveries[#notification_deliveries + 1] = {
            notification = notification,
            target = target,
        }
        return { delivered = target.kind == "all" and 2 or 1 }
    end,
}

local function get_alias(resource_name, export_name)
    local event_name = ("__cfx_export_%s_%s"):format(resource_name, export_name)
    local handlers = assert(event_handlers[event_name], "missing alias event: " .. event_name)
    local alias_handler
    handlers[#handlers](function(handler)
        alias_handler = handler
    end)
    return assert(alias_handler, "missing alias handler: " .. event_name)
end

local function assert_no_return(handler, ...)
    assert(table.pack(handler(...)).n == 0, "documented no-return export leaked a return value")
end

local high_end_call = get_alias("high-phone", "endCall")
assert_no_return(high_end_call, 10)
assert(ended_sources[#ended_sources] == 10)
local ended_count = #ended_sources
assert_no_return(high_end_call, "10")
assert(#ended_sources == ended_count, "High Phone must reject string player sources")

active_calls[10] = {
    id = "550e8400-e29b-41d4-a716-446655440011",
    caller = { source = 10, number = "5550101" },
    callee = { source = 11, number = "5550111" },
    startedAt = 1700000002,
    anonymous = false,
    video = false,
}
local quasar_is_in_call = get_alias("qs-smartphone", "isPlayerInCall")
local quasar_end_call = get_alias("qs-smartphone", "endCallBySource")
assert(quasar_is_in_call(10) == true)
assert(quasar_is_in_call("10") == false)
assert_no_return(quasar_end_call, 10)
assert(quasar_is_in_call(10) == false)
ended_count = #ended_sources
assert_no_return(quasar_end_call, 0)
assert(#ended_sources == ended_count, "Quasar must reject invalid player sources")

active_calls[10] = {
    id = "550e8400-e29b-41d4-a716-446655440012",
    caller = { source = 10, number = "5550101" },
    callee = { source = 11, number = "5550111" },
    startedAt = 1700000003,
    anonymous = false,
    video = false,
}
active_calls[20] = {
    id = "550e8400-e29b-41d4-a716-446655440020",
    caller = { source = 20, number = "5550102" },
    callee = { source = 21, number = "5550121" },
    startedAt = 1700000001,
    anonymous = true,
    companyId = "police",
    video = false,
}

local mov_end_by_source = get_alias("17mov_Phone", "PhoneApp_EndCallBySrc")
local mov_end_by_number = get_alias("17mov_Phone", "PhoneApp_EndCallByNumber")
local mov_is_in_call_by_source = get_alias("17mov_Phone", "PhoneApp_IsInCallBySrc")
local mov_is_in_call_by_number = get_alias("17mov_Phone", "PhoneApp_IsInCallByNumber")
local mov_get_id_by_source = get_alias("17mov_Phone", "PhoneApp_GetCallIdFromSrc")
local mov_get_id_by_number = get_alias("17mov_Phone", "PhoneApp_GetCallIdFromNumber")
local mov_get_data_by_source = get_alias("17mov_Phone", "PhoneApp_GetCallDataFromSrc")
local mov_get_data_by_number = get_alias("17mov_Phone", "PhoneApp_GetCallDataFromNumber")
local mov_get_data_by_id = get_alias("17mov_Phone", "PhoneApp_GetCallDataFromCallId")

assert(mov_is_in_call_by_source(10) == true)
assert(mov_is_in_call_by_source("10") == false)
assert(mov_is_in_call_by_number("5550102") == true)
assert(mov_is_in_call_by_number("5550999") == false)
assert(mov_get_id_by_source(10) == "550e8400-e29b-41d4-a716-446655440012")
assert(mov_get_id_by_source(30) == nil)
assert(mov_get_id_by_number("5550102") == "550e8400-e29b-41d4-a716-446655440020")
assert(mov_get_id_by_number("5550999") == nil)

local source_data = assert(mov_get_data_by_source(10))
assert(source_data.callId == "550e8400-e29b-41d4-a716-446655440012")
assert(source_data.fromId == 10 and source_data.fromNumber == "5550101")
assert(source_data.toId == 11 and source_data.toNumber == "5550111")
assert(source_data.callTime == 1700000003 and source_data.inCall == true)
assert(source_data.type == "phone" and source_data.isNumberHidden == false)
assert(source_data.isCompanyCall == false)

local number_data = assert(mov_get_data_by_number("5550102"))
assert(number_data.callId == "550e8400-e29b-41d4-a716-446655440020")
assert(number_data.isNumberHidden == true and number_data.isCompanyCall == true)
local id_data = assert(mov_get_data_by_id("550e8400-e29b-41d4-a716-446655440020"))
assert(id_data.callId == number_data.callId and id_data.fromId == 20 and id_data.toId == 21)
assert(mov_get_data_by_id("550e8400-e29b-41d4-a716-446655440099") == nil)
assert(mov_get_data_by_id("not-a-uuid") == nil)

assert(mov_end_by_number("5550102") == true)
assert(mov_end_by_number("5550102") == false)
assert(mov_end_by_source(10) == true)
assert(mov_end_by_source(10) == false)
assert(mov_end_by_source(0) == false)

local mov_notify_source = get_alias("17mov_Phone", "SendNotificationToSrc")
local mov_notify_number = get_alias("17mov_Phone", "SendNotificationToNumber")
local mov_notify_everyone = get_alias("17mov_Phone", "SendNotificationToEveryone")
local mov_notification = {
    app = "BANK",
    message = "Paid",
    title = "Bank",
}
assert_no_return(mov_notify_source, 10, mov_notification)
assert(notification_deliveries[#notification_deliveries].target.kind == "source")
assert(notification_deliveries[#notification_deliveries].target.value == 10)
assert(notification_deliveries[#notification_deliveries].notification.appId == "banking")
assert_no_return(mov_notify_number, "5550102", mov_notification)
assert(notification_deliveries[#notification_deliveries].target.kind == "number")
assert(notification_deliveries[#notification_deliveries].target.value == "5550102")
assert_no_return(mov_notify_everyone, mov_notification)
assert(notification_deliveries[#notification_deliveries].target.kind == "all")
local notification_count = #notification_deliveries
assert_no_return(mov_notify_everyone, {
    app = "SYSTEM",
    message = { key = "System:Message" },
    title = "System",
})
assert(#notification_deliveries == notification_count,
    "17Movement locale-object notifications must remain a documented partial")

local high_notify = get_alias("high-phone", "sendNotification")
local high_notification = {
    application = { name = "messages" },
    content = "High",
    duration = 5000,
    title = "Phone",
}
assert_no_return(high_notify, -1, high_notification)
assert(notification_deliveries[#notification_deliveries].target.kind == "all")
assert_no_return(high_notify, 10, high_notification)
assert(notification_deliveries[#notification_deliveries].target.kind == "source")
assert(notification_deliveries[#notification_deliveries].target.value == 10)
assert_no_return(high_notify, "5550102", high_notification)
assert(notification_deliveries[#notification_deliveries].target.kind == "number")
assert(notification_deliveries[#notification_deliveries].notification.appId == "messages")
notification_count = #notification_deliveries
assert_no_return(high_notify, true, high_notification)
assert(#notification_deliveries == notification_count, "High must reject ambiguous receiver types")

local quasar_notify = get_alias("qs-smartphone", "sendPhoneNotification")
assert_no_return(quasar_notify, 10, {
    appId = "messages",
    text = "Ready",
    title = "Order",
})
local quasar_delivery = notification_deliveries[#notification_deliveries]
assert(quasar_delivery.target.kind == "source" and quasar_delivery.target.value == 10)
assert(quasar_delivery.notification.appId == "messages")
assert(quasar_delivery.notification.text == "Ready")

print("Provider server compatibility tests passed")
