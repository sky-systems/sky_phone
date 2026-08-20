local event_handlers = {}
local migration_callbacks = {}
local registered_event_handlers = {}
local registered_exports = {}
local sent_events = {}
local triggered_events = {}
local invoking_resource = nil
local seam_calls = {
    equipped_number = {},
    formatted_number = {},
    source_from_number = {},
}
local directory_calls = {
    online_by_identifier = {},
    online_by_imei = {},
    online_by_source = {},
    stored_by_imei = {},
    stored_by_phone_number = {},
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
    return invoking_resource
end

function GetGameTimer()
    return 5000
end

function RegisterNetEvent(event_name, handler)
    event_handlers[event_name] = handler
end

function AddEventHandler(event_name, handler)
    local handlers = registered_event_handlers[event_name] or {}
    handlers[#handlers + 1] = handler
    registered_event_handlers[event_name] = handlers
end

function TriggerClientEvent(event_name, target, ...)
    sent_events[#sent_events + 1] = {
        arguments = { ... },
        event_name = event_name,
        target = target,
    }
end

function TriggerEvent(event_name, ...)
    triggered_events[#triggered_events + 1] = {
        arguments = { ... },
        event_name = event_name,
    }
end

dofile("sky_phone/source/shared/imei.lua")
dofile("sky_phone/source/bridge/shared.lua")
dofile("sky_phone/source/bridge/phones/shared.lua")
dofile("sky_phone/source/bridge/phones/shared/lb.lua")
dofile("sky_phone/source/bridge/phones/shared/seventeen.lua")
dofile("sky_phone/source/bridge/phones/shared/high.lua")
dofile("sky_phone/source/bridge/phones/shared/quasar.lua")
dofile("sky_phone/source/bridge/phones/shared/yseries.lua")
Bridge.Database = {
    AfterMigration = function(_, callback)
        migration_callbacks[#migration_callbacks + 1] = callback
    end,
}
local phone_core = {
    FormatNumber = function(value)
        seam_calls.formatted_number[#seam_calls.formatted_number + 1] = value
        return "formatted:" .. value
    end,
    GetEquippedPhoneNumber = function(player)
        seam_calls.equipped_number[#seam_calls.equipped_number + 1] = player
        if player == 42 then
            return "5550000042"
        end
        if player == 73 then
            return "5550000073"
        end
        if player == "char1:phone-owner" then
            return "5550000099"
        end
        return nil
    end,
    GetSourceFromNumber = function(phone_number)
        seam_calls.source_from_number[#seam_calls.source_from_number + 1] = phone_number
        if tostring(phone_number) == "5550000073" then
            return 73
        end
        return nil
    end,
}
SkyPhoneDeviceDirectory = {
    GetOnlineByIdentifier = function(identifier)
        directory_calls.online_by_identifier[#directory_calls.online_by_identifier + 1] = identifier
        if identifier == "char1:directory-owner" then
            return { source = 85 }
        end
        return nil, "player_unavailable"
    end,
    GetOnlineByImei = function(phone_imei)
        directory_calls.online_by_imei[#directory_calls.online_by_imei + 1] = phone_imei
        if phone_imei == "123456789012347" then
            return { source = 84 }
        end
        return nil, "player_unavailable"
    end,
    GetOnlineBySource = function(player_source)
        directory_calls.online_by_source[#directory_calls.online_by_source + 1] = player_source
        if player_source == 88 then
            return { imei = "523456789012343" }
        end
        return nil, "player_unavailable"
    end,
    GetStoredDeviceByImei = function(phone_imei)
        directory_calls.stored_by_imei[#directory_calls.stored_by_imei + 1] = phone_imei
        if phone_imei == "223456789012346" then
            return { phoneNumber = "5550000086" }
        end
        return nil, "device_not_found"
    end,
    GetStoredDeviceByPhoneNumber = function(phone_number)
        directory_calls.stored_by_phone_number[#directory_calls.stored_by_phone_number + 1]
            = phone_number
        if phone_number == "5550000087" then
            return { imei = "423456789012344" }
        end
        return nil, "device_not_found"
    end,
}
dofile("sky_phone/source/bridge/phones/server/core.lua")
dofile("sky_phone/source/bridge/phones/server/lb.lua")
dofile("sky_phone/source/bridge/phones/server/seventeen.lua")
dofile("sky_phone/source/bridge/phones/server/high.lua")
dofile("sky_phone/source/bridge/phones/server/quasar.lua")
dofile("sky_phone/source/bridge/phones/server/yseries.lua")
dofile("sky_phone/source/bridge/phones/server/lifecycle.lua")

assert(SkyPhone == nil, "all provider adapters must load before the phone core is ready")
assert(
    SkyPhoneCompatibilityServer.Phone == nil,
    "provider adapters must not cache the phone core before migration"
)
SkyPhone = phone_core
for index = 1, #migration_callbacks do
    migration_callbacks[index]()
end
assert(
    SkyPhoneCompatibilityServer.Phone == phone_core,
    "all provider adapters must bind the migrated phone core"
)

local function get_alias_export(resource_name, export_name)
    local alias_handlers = registered_event_handlers[
        ("__cfx_export_%s_%s"):format(resource_name, export_name)
    ]
    assert(alias_handlers and #alias_handlers == 1, ("Missing %s:%s export alias"):format(
        resource_name,
        export_name
    ))

    local export_handler
    local export_callback = setmetatable({
        __cfx_functionReference = "test-export-callback",
    }, {
        __call = function(_, handler)
            export_handler = handler
        end,
    })
    alias_handlers[1](export_callback)
    assert(type(export_handler) == "function", ("Invalid %s:%s export alias"):format(
        resource_name,
        export_name
    ))
    return export_handler
end

local function invoke_event_handlers(event_name, ...)
    local handlers = registered_event_handlers[event_name]
    assert(handlers and #handlers > 0, ("Missing %s event handler"):format(event_name))
    for index = 1, #handlers do
        handlers[index](...)
    end
end

assert(triggered_events[1].event_name == "onServerResourceStop", "LB server export caches must be invalidated")
assert(triggered_events[1].arguments[1] == "lb-phone", "LB server stop must use the provided resource name")
assert(triggered_events[2].event_name == "onResourceStop", "LB generic stop listeners must be notified")
assert(triggered_events[3].event_name == "onServerResourceStart", "LB server start listeners must be notified")
assert(triggered_events[4].event_name == "onResourceStart", "LB generic start listeners must be notified")

local lifecycle_event_offset = #triggered_events
invoke_event_handlers("sky_phone:server:phoneNumberChanged", 42, "5550000042")
invoke_event_handlers("sky_phone:server:phoneNumberGenerated", 42, "5550000043")
invoke_event_handlers("sky_phone:server:factoryReset", 42, "5550000044")
invoke_event_handlers(
    "sky_phone:server:galleryMediaDeleted",
    42,
    "5550000042",
    "https://media.example/deleted.png"
)
assert(
    triggered_events[lifecycle_event_offset + 1].event_name == "lb-phone:numberChanged",
    "LB number-change observer event must be preserved"
)
assert(
    triggered_events[lifecycle_event_offset + 2].event_name == "lb-phone:phoneNumberGenerated",
    "LB number-generation observer event must be preserved"
)
assert(
    triggered_events[lifecycle_event_offset + 3].event_name == "lb-phone:factoryReset",
    "LB factory-reset observer event must be preserved"
)
assert(
    triggered_events[lifecycle_event_offset + 4].event_name == "lb-phone:deletedFromGallery",
    "LB gallery-deletion observer event must be preserved"
)
assert(
    triggered_events[lifecycle_event_offset + 4].arguments[3]
        == "https://media.example/deleted.png",
    "LB gallery observer must preserve the deleted link"
)

local lb_get_equipped_number = get_alias_export("lb-phone", "GetEquippedPhoneNumber")
assert(
    lb_get_equipped_number(42) == "5550000042",
    "LB source lookup must use the equipped-number seam"
)
assert(
    lb_get_equipped_number("char1:phone-owner") == "5550000099",
    "LB identifier lookup must preserve its documented string contract"
)
assert(next(registered_exports) == nil, "Vendor exports must only be registered as provider aliases")

local seventeen_get_number_from_player = get_alias_export("17mov_Phone", "GetNumberFromPlayer")
local seventeen_get_number_from_identifier = get_alias_export(
    "17mov_Phone",
    "GetNumberFromIdentifier"
)
local seventeen_get_source_from_number = get_alias_export(
    "17mov_Phone",
    "GetPlayerSrcFromActiveNumber"
)
assert(
    seventeen_get_number_from_player(42) == "5550000042",
    "17Movement source lookup must use the equipped-number seam"
)
assert(
    seventeen_get_number_from_identifier("char1:phone-owner") == "5550000099",
    "17Movement identifier lookup must use the equipped-number seam"
)
assert(
    seventeen_get_source_from_number("5550000073") == 73,
    "17Movement active-number lookup must use the source seam"
)

local equipped_calls_before_invalid = #seam_calls.equipped_number
assert(seventeen_get_number_from_player("42") == nil, "17Movement must reject string sources")
assert(
    seventeen_get_number_from_identifier("   ") == nil,
    "17Movement must reject blank identifiers"
)
assert(
    #seam_calls.equipped_number == equipped_calls_before_invalid,
    "Invalid 17Movement identity arguments must not reach the phone core"
)

local source_calls_before_invalid = #seam_calls.source_from_number
assert(
    seventeen_get_source_from_number({}) == nil,
    "17Movement must reject non-scalar phone numbers"
)
assert(
    #seam_calls.source_from_number == source_calls_before_invalid,
    "Invalid 17Movement phone numbers must not reach the phone core"
)

local high_get_player_phone_number = get_alias_export("high-phone", "getPlayerPhoneNumber")
local high_format_number = get_alias_export("high-phone", "formatNumber")
assert(
    high_get_player_phone_number(42) == "5550000042",
    "High source lookup must use the equipped-number seam"
)
assert(
    high_format_number("5550000042") == "formatted:5550000042",
    "High number formatting must use the configured formatting seam"
)
local formatted_calls_before_invalid = #seam_calls.formatted_number
assert(high_format_number(5550000042) == nil, "High formatNumber must require a string")
assert(
    #seam_calls.formatted_number == formatted_calls_before_invalid,
    "Invalid High numbers must not reach the formatter"
)

local quasar_get_current_phone_number = get_alias_export(
    "qs-smartphone",
    "GetCurrentPhoneNumber"
)
assert(
    quasar_get_current_phone_number(42) == "5550000042",
    "Quasar source lookup must use the equipped-number seam"
)
assert(quasar_get_current_phone_number(0) == nil, "Quasar must reject invalid sources")

local yseries_get_source = get_alias_export("yseries", "GetPlayerSourceIdByPhoneNumber")
local yseries_get_number = get_alias_export("yseries", "GetPhoneNumberBySourceId")
local yseries_get_source_by_imei = get_alias_export(
    "yseries",
    "GetPlayerSourceIdByPhoneImei"
)
local yseries_get_source_by_identifier = get_alias_export(
    "yseries",
    "GetPlayerSourceIdByIdentifier"
)
local yseries_get_number_by_imei = get_alias_export("yseries", "GetPhoneNumberByImei")
local yseries_get_imei_by_number = get_alias_export(
    "yseries",
    "GetPhoneImeiByPhoneNumber"
)
local yseries_get_imei_by_source = get_alias_export("yseries", "GetPhoneImeiBySourceId")
assert(
    yseries_get_source(5550000073) == 73,
    "YSeries number lookup must accept its documented scalar number form"
)
assert(
    yseries_get_number(73) == "5550000073",
    "YSeries source lookup must use the equipped-number seam"
)
assert(yseries_get_source(math.huge) == nil, "YSeries must reject non-finite phone numbers")
assert(yseries_get_number(73.5) == nil, "YSeries must reject fractional sources")
assert(
    yseries_get_source_by_imei("123456789012347") == 84,
    "YSeries IMEI-to-source lookup must use the online device directory"
)
assert(
    yseries_get_source_by_identifier(" char1:directory-owner ") == 85,
    "YSeries identifier-to-source lookup must use the normalized online directory identity"
)
assert(
    yseries_get_number_by_imei("223456789012346") == "5550000086",
    "YSeries IMEI-to-number lookup must use the stored device directory"
)
assert(
    yseries_get_imei_by_number("5550000087") == "423456789012344",
    "YSeries number-to-IMEI lookup must use the stored device directory"
)
assert(
    yseries_get_imei_by_source(88) == "523456789012343",
    "YSeries source-to-IMEI lookup must use the online device directory"
)

assert(
    yseries_get_source_by_imei("999999999999994") == nil,
    "YSeries IMEI-to-source lookup must preserve a missing directory result as nil"
)
assert(
    yseries_get_source_by_identifier("char1:missing") == nil,
    "YSeries identifier-to-source lookup must preserve a missing directory result as nil"
)
assert(
    yseries_get_number_by_imei("888888888888885") == nil,
    "YSeries IMEI-to-number lookup must preserve a missing directory result as nil"
)
assert(
    yseries_get_imei_by_number("5550000999") == nil,
    "YSeries number-to-IMEI lookup must preserve a missing directory result as nil"
)
assert(
    yseries_get_imei_by_source(999) == nil,
    "YSeries source-to-IMEI lookup must preserve a missing directory result as nil"
)

local directory_calls_before_invalid = {
    online_by_identifier = #directory_calls.online_by_identifier,
    online_by_imei = #directory_calls.online_by_imei,
    online_by_source = #directory_calls.online_by_source,
    stored_by_imei = #directory_calls.stored_by_imei,
    stored_by_phone_number = #directory_calls.stored_by_phone_number,
}
assert(yseries_get_source_by_imei(123456789012345) == nil, "YSeries must reject numeric IMEIs")
assert(
    yseries_get_source_by_identifier(string.rep("x", 81)) == nil,
    "YSeries must reject overlong identifiers"
)
assert(yseries_get_number_by_imei("invalid-imei") == nil, "YSeries must reject invalid IMEIs")
assert(
    yseries_get_imei_by_number(5550000087) == nil,
    "YSeries number-to-IMEI must require its documented string argument"
)
assert(yseries_get_imei_by_source(88.5) == nil, "YSeries must reject fractional sources")
assert(
    #directory_calls.online_by_imei == directory_calls_before_invalid.online_by_imei
        and #directory_calls.online_by_identifier
            == directory_calls_before_invalid.online_by_identifier
        and #directory_calls.stored_by_imei == directory_calls_before_invalid.stored_by_imei
        and #directory_calls.stored_by_phone_number
            == directory_calls_before_invalid.stored_by_phone_number
        and #directory_calls.online_by_source == directory_calls_before_invalid.online_by_source,
    "Invalid YSeries identity arguments must not reach the device directory"
)

local high_add_application = get_alias_export("high-phone", "addApplication")

invoking_resource = "high_server_app"
local add_success, add_error = high_add_application("bankingv2", {
    externalUrl = "@high_server_app/ui/index.html",
}, {
    en = {
        label = "Banking",
        description = "Banking app",
    },
})
assert(add_success and add_error == nil, "High server addApplication must register")
assert(#sent_events == 1, "High server registration must broadcast an update")
assert(sent_events[1].event_name == "sky_phone:compat:high:client:syncApplication", "High sync event must be used")
assert(sent_events[1].arguments[1] == "high_server_app", "High sync must preserve the owner")

invoking_resource = "other_server_app"
local duplicate_success, duplicate_error = high_add_application("bankingv2", {
    externalUrl = "@other_server_app/ui/index.html",
})
assert(not duplicate_success and duplicate_error == "duplicate_app_id", "High cross-owner replacement must fail")

source = 42
event_handlers["sky_phone:compat:high:server:requestSnapshot"]()
assert(#sent_events == 2, "High snapshot request must emit one response")
assert(sent_events[2].event_name == "sky_phone:compat:high:client:replaceSnapshot", "High snapshot event must be used")
assert(sent_events[2].target == 42, "High snapshot must target only the requester")
assert(#sent_events[2].arguments[1] == 1, "High snapshot must include the registered app")

event_handlers["sky_phone:compat:high:server:requestSnapshot"]()
assert(#sent_events == 2, "High snapshot rate limiting must remain unchanged")

invoke_event_handlers("onResourceStop", "high_server_app")
assert(#sent_events == 3, "Stopping a High app owner must broadcast one removal")
assert(
    sent_events[3].event_name == "sky_phone:compat:high:client:removeApplication",
    "High owner cleanup must preserve the removal event"
)
assert(sent_events[3].arguments[2] == "bankingv2", "High owner cleanup must remove its app")

local shutdown_event_offset = #triggered_events
invoke_event_handlers("onResourceStop", "sky_phone")
assert(
    triggered_events[shutdown_event_offset + 1].event_name == "onServerResourceStop",
    "Sky Phone shutdown must invalidate the LB server cache"
)
assert(
    triggered_events[shutdown_event_offset + 2].event_name == "onResourceStop",
    "Sky Phone shutdown must notify LB generic stop listeners"
)

print("Custom app compatibility server tests passed")
