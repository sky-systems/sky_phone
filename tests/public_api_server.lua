local registered_exports = {}
local migration_callback
local triggered_events = {}
local service_calls = {}

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

local function custom_app_handler(name)
    return function(...)
        service_calls.custom_app = { name = name, arguments = { ... } }
        return true
    end
end

SkyPhoneApps = {
    ServerPublicApi = {
        AddCustomAppPolicy = custom_app_handler("AddCustomAppPolicy"),
        AddCustomAppPolicyFromAdapter = custom_app_handler("AddCustomAppPolicyFromAdapter"),
        GetCustomAppCapabilities = custom_app_handler("GetCustomAppCapabilities"),
        GetCustomAppPolicy = custom_app_handler("GetCustomAppPolicy"),
        HasCustomAppPermission = custom_app_handler("HasCustomAppPermission"),
        RemoveCustomAppPolicy = custom_app_handler("RemoveCustomAppPolicy"),
        RemoveCustomAppPolicyFromAdapter = custom_app_handler("RemoveCustomAppPolicyFromAdapter"),
        SendAppMessage = custom_app_handler("SendAppMessage"),
        SendCustomAppMessage = custom_app_handler("SendCustomAppMessage"),
        SendCustomAppNotification = custom_app_handler("SendCustomAppNotification"),
        UpdateCustomAppPolicy = custom_app_handler("UpdateCustomAppPolicy"),
        UpdateCustomAppPolicyFromAdapter = custom_app_handler("UpdateCustomAppPolicyFromAdapter"),
    },
}

exports = function(name, handler)
    registered_exports[name] = handler
end

function TriggerEvent(name, ...)
    triggered_events[#triggered_events + 1] = { name = name, arguments = { ... } }
end

Bridge = {
    Database = {
        AfterMigration = function(name, callback)
            assert(name == "sky_phone")
            migration_callback = callback
        end,
    },
    Debug = function() end,
}

assert(loadfile("sky_phone/source/shared/imei.lua"))()
assert(loadfile("sky_phone/source/shared/sim_number.lua"))()
assert(loadfile("sky_phone/source/shared/public_api.lua"))()
assert(loadfile("sky_phone/source/server/public_api.lua"))()

assert(registered_exports.GetApiVersion() == "1.0.0")
local invalid_format, invalid_format_error = registered_exports.FormatPhoneNumber("123")
assert(invalid_format == nil and invalid_format_error == "invalid_phone_number")
assert(registered_exports.IsApiReady() == false)
local unavailable, unavailable_error = registered_exports.GetEquippedPhoneNumber(10)
assert(unavailable == nil and unavailable_error == "api_not_ready")

SkyPhone = {
    GetEquippedPhoneNumber = function(player)
        service_calls.player = player
        return player == 10 and "1234567" or nil
    end,
    GetSourceFromNumber = function(number)
        service_calls.number = number
        return number == "1234567" and 10 or nil
    end,
}
SkyPhoneDeviceDirectory = {
    GetOnlineBySource = function(source)
        return { source = source, imei = "123456789012347" }
    end,
    GetOnlineByPhoneNumber = function(number)
        return { phoneNumber = number, source = 10 }
    end,
    GetOnlineByIdentifier = function(identifier)
        return { identifier = identifier, source = 10 }
    end,
    GetOnlineByImei = function(imei)
        return { imei = imei, source = 10 }
    end,
    GetStoredDeviceByImei = function(imei)
        return { imei = imei, online = false }
    end,
    GetStoredDeviceByPhoneNumber = function(number)
        return { phoneNumber = number, online = false }
    end,
    GetStoredDeviceByIdentifier = function(identifier)
        return { identifier = identifier, online = false }
    end,
    GetStoredSimByPhoneNumber = function(number)
        return { phoneNumber = number, simId = "sim-1" }
    end,
}
SkyPhoneCalls = {
    EndForSource = function(source)
        service_calls.end_source = source
        return true
    end,
    GetById = function(id)
        return { id = id }
    end,
    GetForSource = function(source)
        return { source = source }
    end,
    IsActiveForSource = function(source)
        return source == 10
    end,
    TerminateForSource = function(source)
        service_calls.terminate_source = source
        return true
    end,
}
SkyPhoneNotifications = {
    Send = function(target, notification)
        service_calls.notification = { target, notification }
        return { delivered = 1 }
    end,
}

assert(type(migration_callback) == "function")
migration_callback()
assert(registered_exports.IsApiReady() == true)

local capabilities = registered_exports.GetApiCapabilities()
assert(capabilities.ready and capabilities.side == "server")
assert(capabilities.features.deviceDirectory and capabilities.features.calls.video == false)
assert(capabilities.features.customApps.enabled and capabilities.features.customApps.external)
assert(capabilities.features.notifications.customApps)
assert(capabilities.features.notifications.system == false)
capabilities.features.deviceDirectory = false
assert(registered_exports.GetApiCapabilities().features.deviceDirectory == true,
    "server capability results must be isolated copies")

assert(registered_exports.GetEquippedPhoneNumber(10) == "1234567")
assert(service_calls.player == 10)
assert(registered_exports.GetSourceFromPhoneNumber("1234567") == 10)
assert(service_calls.number == "1234567")
assert(registered_exports.AddCustomAppPolicy({ id = "creator-app" }))
assert(service_calls.custom_app.name == "AddCustomAppPolicy")
assert(registered_exports.SendAppMessage(10, "creator-app", { type = "refresh" }))
assert(service_calls.custom_app.name == "SendAppMessage")
assert(service_calls.custom_app.arguments[1] == 10)
assert(registered_exports.SendCustomAppMessage(10, "creator-app", { type = "refresh" }))
assert(service_calls.custom_app.name == "SendCustomAppMessage")
assert(registered_exports.SendCustomAppNotification(10, "creator-app", {
    title = "Creator",
    text = "Updated",
}))
assert(service_calls.custom_app.name == "SendCustomAppNotification")
assert(registered_exports.GetOnlineDeviceBySource(10).imei == "123456789012347")
assert(registered_exports.GetOnlineDeviceByPhoneNumber("1234567").source == 10)
assert(registered_exports.GetOnlineDeviceByIdentifier("license:test").source == 10)
assert(registered_exports.GetOnlineDeviceByImei("123456789012347").source == 10)
assert(registered_exports.GetStoredDeviceByImei("123456789012347").online == false)
assert(registered_exports.GetStoredDeviceByPhoneNumber("1234567").online == false)
assert(registered_exports.GetStoredDeviceByIdentifier("license:test").online == false)
assert(registered_exports.GetStoredSimByPhoneNumber("1234567").simId == "sim-1")

assert(registered_exports.GetActiveCallBySource(10).source == 10)
assert(registered_exports.GetActiveCallById("call-id").id == "call-id")
assert(registered_exports.IsPlayerInCall(10))
assert(registered_exports.EndCallForSource(10))
assert(service_calls.end_source == 10)
assert(registered_exports.TerminateCallForSource(10))
assert(service_calls.terminate_source == 10)

assert(registered_exports.SendNotification == nil,
    "generic notifications must not bypass custom-app ownership")

assert(triggered_events[#triggered_events].name == "sky_phone:server:apiReady")
assert(triggered_events[#triggered_events].arguments[1] == "1.0.0")

print("Server public API tests passed")
