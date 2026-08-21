local api_ready = false

local SERVER_CAPABILITIES = {
    apiVersion = SkyPhonePublicApi.Version,
    features = {
        calls = {
            audio = true,
            company = true,
            video = false,
        },
        customApps = {
            enabled = Config.CustomApps.Enabled == true,
            external = Config.CustomApps.Enabled == true
                and Config.CustomApps.ExternalApps == true,
        },
        deviceDirectory = true,
        notifications = {
            customApps = Config.CustomApps.Enabled == true
                and Config.CustomApps.ExternalApps == true,
            system = false,
        },
        phoneNumberLookup = true,
    },
    ready = false,
    side = "server",
}

local custom_app_api = SkyPhoneApps.ServerPublicApi
if type(custom_app_api) ~= "table" then
    error("[sky_phone] Server public API initialized before the custom app policy API.")
end

local function get_api_capabilities()
    local capabilities = SkyPhonePublicApi.Copy(SERVER_CAPABILITIES)
    capabilities.ready = api_ready
    return capabilities
end

local function is_api_ready()
    return api_ready
end

local function invoke(service_name, method_name, ...)
    if not api_ready then
        return nil, "api_not_ready"
    end

    local service = _G[service_name]
    local handler = type(service) == "table" and service[method_name] or nil
    if type(handler) ~= "function" then
        Bridge.Debug(
            "error",
            "[sky_phone] Public API service %s.%s is unavailable.",
            service_name,
            method_name
        )
        return nil, "api_not_ready"
    end
    return handler(...)
end

local function bind(service_name, method_name)
    return function(...)
        return invoke(service_name, method_name, ...)
    end
end

exports("GetApiCapabilities", get_api_capabilities)
exports("IsApiReady", is_api_ready)

exports("GetEquippedPhoneNumber", bind("SkyPhone", "GetEquippedPhoneNumber"))
exports("GetSourceFromPhoneNumber", bind("SkyPhone", "GetSourceFromNumber"))

exports("GetOnlineDeviceBySource", bind("SkyPhoneDeviceDirectory", "GetOnlineBySource"))
exports(
    "GetOnlineDeviceByPhoneNumber",
    bind("SkyPhoneDeviceDirectory", "GetOnlineByPhoneNumber")
)
exports(
    "GetOnlineDeviceByIdentifier",
    bind("SkyPhoneDeviceDirectory", "GetOnlineByIdentifier")
)
exports("GetOnlineDeviceByImei", bind("SkyPhoneDeviceDirectory", "GetOnlineByImei"))
exports("GetStoredDeviceByImei", bind("SkyPhoneDeviceDirectory", "GetStoredDeviceByImei"))
exports(
    "GetStoredDeviceByPhoneNumber",
    bind("SkyPhoneDeviceDirectory", "GetStoredDeviceByPhoneNumber")
)
exports(
    "GetStoredDeviceByIdentifier",
    bind("SkyPhoneDeviceDirectory", "GetStoredDeviceByIdentifier")
)
exports(
    "GetStoredSimByPhoneNumber",
    bind("SkyPhoneDeviceDirectory", "GetStoredSimByPhoneNumber")
)

exports("GetActiveCallBySource", bind("SkyPhoneCalls", "GetForSource"))
exports("GetActiveCallById", bind("SkyPhoneCalls", "GetById"))
exports("IsPlayerInCall", bind("SkyPhoneCalls", "IsActiveForSource"))
exports("EndCallForSource", bind("SkyPhoneCalls", "EndForSource"))
exports("TerminateCallForSource", bind("SkyPhoneCalls", "TerminateForSource"))

exports("AddCustomAppPolicy", custom_app_api.AddCustomAppPolicy)
exports("AddCustomAppPolicyFromAdapter", custom_app_api.AddCustomAppPolicyFromAdapter)
exports("GetCustomAppCapabilities", custom_app_api.GetCustomAppCapabilities)
exports("GetCustomAppPolicy", custom_app_api.GetCustomAppPolicy)
exports("HasCustomAppPermission", custom_app_api.HasCustomAppPermission)
exports("RemoveCustomAppPolicy", custom_app_api.RemoveCustomAppPolicy)
exports("RemoveCustomAppPolicyFromAdapter", custom_app_api.RemoveCustomAppPolicyFromAdapter)
exports("SendAppMessage", custom_app_api.SendAppMessage)
exports("SendCustomAppMessage", custom_app_api.SendCustomAppMessage)
exports("SendCustomAppNotification", custom_app_api.SendCustomAppNotification)
exports("UpdateCustomAppPolicy", custom_app_api.UpdateCustomAppPolicy)
exports("UpdateCustomAppPolicyFromAdapter", custom_app_api.UpdateCustomAppPolicyFromAdapter)

Bridge.Database.AfterMigration("sky_phone", function()
    local required_services = {
        SkyPhone,
        SkyPhoneCalls,
        SkyPhoneDeviceDirectory,
        SkyPhoneNotifications,
    }
    for index = 1, #required_services do
        if type(required_services[index]) ~= "table" then
            error("[sky_phone] Server public API initialized before its domain services.")
        end
    end

    api_ready = true
    TriggerEvent("sky_phone:server:apiReady", SkyPhonePublicApi.Version)
end)
