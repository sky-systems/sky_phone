local registered_exports = {}
local registered_event_handlers = {}
local registered_nui_callbacks = {}
local triggered_events = {}
local nui_messages = {}
local collision_messages = {}
local registered_commands = {}
local invoking_resource = nil

Config = {
    Bridge = {
        Locale = "en",
    },
    Sim = {
        NumberGroups = { 3, 4 },
        NumberLength = 7,
        NumberPrefix = "",
    },
    CustomApps = {
        BundledApps = false,
        Debug = true,
        Enabled = true,
        ExternalApps = true,
        MaximumMessageBytes = 65536,
        MaximumStorageBytesPerApp = 262144,
        MaximumStorageKeyLength = 64,
        MaximumStorageValueBytes = 65536,
        ReadyTimeoutMs = 8000,
        TrustedAdapters = {},
    },
}

local encoded_json_value = nil
json = {
    decode = function(encoded)
        if encoded == "null" then
            return nil, 5
        end
        return encoded_json_value
    end,
    encode = function(value)
        if value == nil then
            return "null"
        end
        encoded_json_value = value
        return "{}"
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
    return invoking_resource
end

function GetResourceState(resource_name)
    if resource_name == "missing_resource" or resource_name == "ui" then
        return "missing"
    end
    return "started"
end

function RegisterNUICallback(callback_name, handler)
    registered_nui_callbacks[callback_name] = handler
end
function RegisterCommand(command_name, handler)
    registered_commands[command_name] = handler
end
function RegisterNetEvent(event_name, handler)
    if handler then
        AddEventHandler(event_name, handler)
    end
end
function AddEventHandler(event_name, handler)
    local handlers = registered_event_handlers[event_name] or {}
    handlers[#handlers + 1] = handler
    registered_event_handlers[event_name] = handlers
end
function SendNUIMessage(message)
    nui_messages[#nui_messages + 1] = message
end
function TriggerServerEvent() end
function TriggerEvent(event_name, ...)
    local arguments = { ... }
    triggered_events[#triggered_events + 1] = {
        event_name = event_name,
        arguments = arguments,
    }

    if event_name:sub(1, 13) == "__cfx_export_"
        or event_name == "sky_phone:client:customAppRemoved"
    then
        local handlers = registered_event_handlers[event_name] or {}
        for index = 1, #handlers do
            handlers[index](table.unpack(arguments))
        end
    end
end

function CreateThread(handler)
    handler()
end

AddEventHandler("__cfx_export_lb-phone_AddCustomApp", function(set_callback)
    set_callback(function()
        return false, "App already exists"
    end)
end)

dofile("sky_phone/source/bridge/shared.lua")
local bridge_debug = Bridge.Debug
Bridge.Debug = function(level, message, ...)
    if level == "error" then
        local arguments = { ... }
        collision_messages[#collision_messages + 1] = #arguments > 0
            and message:format(table.unpack(arguments))
            or message
    end
    bridge_debug(level, message, ...)
end
dofile("sky_phone/source/shared/custom_apps.lua")
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
dofile("sky_phone/source/client/custom_apps.lua")
local custom_app_capabilities = SkyPhoneApps.ClientPublicApi.GetCustomAppCapabilities()
assert(custom_app_capabilities.enabled and custom_app_capabilities.externalApps)
assert(custom_app_capabilities.messageDispatch)
local has_send_app_message = false
for index = 1, #custom_app_capabilities.exports do
    if custom_app_capabilities.exports[index] == "SendAppMessage" then
        has_send_app_message = true
        break
    end
end
assert(has_send_app_message, "Creator capability discovery must expose SendAppMessage")
SkyPhoneClient = {
    Dial = function() return true end,
    FormatNumber = function(value) return value end,
    GetState = function()
        return { inCall = false, onScreen = false, open = false, phoneNumber = nil }
    end,
    GetEquippedPhoneNumber = function() return nil end,
    OpenMessages = function() return true end,
    Toggle = function() return true end,
}
SkyPhoneCalls = {
    Dial = function() return true end,
}
SkyPhoneNotifications = {
    Send = function(notification)
        SendNUIMessage({
            type = "notification:show",
            data = {
                appId = notification.appId,
                route = "/apps/" .. notification.appId,
                text = notification.text,
                title = notification.title,
            },
        })
        return true
    end,
}
SkyPhoneCamera = {
    DisableWalkable = function() end,
    EnableWalkable = function() end,
    GetState = function()
        return { active = false, flashEnabled = false, selfie = false, walkable = false }
    end,
    SetFlashlight = function() end,
    SetSelfie = function() end,
    ToggleFrozen = function() end,
}
SkyPhoneNavigation = {
    Close = function() return true end,
    GetCurrent = function() return "home" end,
    IsDataLoaded = function() return true end,
    IsInstalled = function() return false end,
    Open = function() return false end,
}
SkyPhoneFocus = {
    SetExternalGameInput = function() return true end,
}
for _, path in ipairs({
    "sky_phone/source/bridge/phones/client/core.lua",
    "sky_phone/source/bridge/phones/client/lb.lua",
    "sky_phone/source/bridge/phones/client/seventeen.lua",
    "sky_phone/source/bridge/phones/client/high.lua",
    "sky_phone/source/bridge/phones/client/quasar.lua",
    "sky_phone/source/bridge/phones/client/yseries.lua",
    "sky_phone/source/bridge/phones/client/lifecycle.lua",
}) do
    dofile(path)
end

local function get_alias_export(resource_name, export_name)
    local event_name = ("__cfx_export_%s_%s"):format(resource_name, export_name)
    local handlers = registered_event_handlers[event_name]
    assert(handlers and #handlers >= 1, ("Missing %s:%s export alias"):format(resource_name, export_name))

    local alias_handler
    local export_callback = setmetatable({
        __cfx_functionReference = "test-export-callback",
    }, {
        __call = function(_, handler)
            alias_handler = handler
        end,
    })
    handlers[#handlers](export_callback)
    assert(type(alias_handler) == "function", ("Invalid %s:%s export alias"):format(resource_name, export_name))
    return alias_handler
end

local function make_cfx_function_reference(reference, handler)
    return setmetatable({
        __cfx_functionReference = reference,
    }, {
        __call = function(_, ...)
            return handler(...)
        end,
    })
end

local lb_add_custom_app = get_alias_export("lb-phone", "AddCustomApp")
local lb_remove_custom_app = get_alias_export("lb-phone", "RemoveCustomApp")
local lb_send_custom_app_message = get_alias_export("lb-phone", "SendCustomAppMessage")
local lb_open_app = get_alias_export("lb-phone", "OpenApp")
local lb_close_app = get_alias_export("lb-phone", "CloseApp")
local lb_send_notification = get_alias_export("lb-phone", "SendNotification")
local mov_add_application = get_alias_export("17mov_Phone", "AddApplication")
local mov_remove_application = get_alias_export("17mov_Phone", "RemoveApplication")
local mov_send_app_message = get_alias_export("17mov_Phone", "SendAppMessage")
local high_add_application = get_alias_export("high-phone", "addApplication")
local high_send_app_nui = get_alias_export("high-phone", "sendAppNui")
local quasar_add_custom_app = get_alias_export("qs-smartphone", "addCustomApp")
local quasar_add_custom_apps_batch = get_alias_export("qs-smartphone", "addCustomAppsBatch")
local quasar_update_custom_app = get_alias_export("qs-smartphone", "updateCustomApp")
local quasar_remove_custom_app = get_alias_export("qs-smartphone", "removeCustomApp")
local quasar_get_custom_apps = get_alias_export("qs-smartphone", "getCustomApps")
local yseries_add_custom_app = get_alias_export("yseries", "AddCustomApp")
local yseries_remove_custom_app = get_alias_export("yseries", "RemoveCustomApp")
local yseries_send_app_message = get_alias_export("yseries", "SendAppMessage")
local yseries_get_data_loaded = get_alias_export("yseries", "GetDataLoaded")

assert(registered_event_handlers["__cfx_export_17mov_Phone_OpenApp"], "17Movement must own its navigation OpenApp")
assert(registered_event_handlers["__cfx_export_17mov_Phone_CloseApp"], "17Movement must own its navigation CloseApp")
assert(registered_event_handlers["__cfx_export_qs-smartphone_OpenPhoneApp"], "Quasar must use neutral navigation")
assert(registered_event_handlers["__cfx_export_yseries_CloseApp"], "YSeries must own its navigation CloseApp")
assert(registered_exports.OpenApp == nil, "compatibility bridge must not publish a bare OpenApp export")
assert(registered_exports.CloseApp == nil, "compatibility bridge must not publish a bare CloseApp export")
assert(registered_exports.OpenPhoneApp == nil, "compatibility bridge must not publish a bare OpenPhoneApp export")
assert(type(registered_commands["phone:toggle"]) == "function", "Quasar phone:toggle command must be registered")

local expected_provider_resources = {
    ["lb-phone"] = true,
    ["17mov_Phone"] = true,
    ["high-phone"] = true,
    ["qs-smartphone"] = true,
    ["yseries"] = true,
}
assert(
    collision_messages[1]
        and collision_messages[1]:find("Compatibility collision: lb-phone:AddCustomApp has 2 providers", 1, true),
    "concurrent original phone providers must emit an actionable compatibility error"
)
local provider_lifecycle_events = {}
for index = 1, #triggered_events do
    local event = triggered_events[index]
    local resource_name = event.arguments[1]
    if expected_provider_resources[resource_name]
        and (event.event_name == "onClientResourceStop"
            or event.event_name == "onResourceStop"
            or event.event_name == "onResourceStart")
    then
        local lifecycle = provider_lifecycle_events[resource_name] or {}
        lifecycle[#lifecycle + 1] = event.event_name
        provider_lifecycle_events[resource_name] = lifecycle
    end
end
for resource_name in pairs(expected_provider_resources) do
    local lifecycle = assert(provider_lifecycle_events[resource_name])
    assert(lifecycle[1] == "onClientResourceStop", ("Missing %s provider cache reset signal"):format(resource_name))
    assert(lifecycle[2] == "onResourceStop", ("Missing %s provider stop signal"):format(resource_name))
    assert(lifecycle[3] == "onResourceStart", ("Missing %s provider start signal"):format(resource_name))
end
assert(yseries_get_data_loaded(), "YSeries must see the compatibility provider as loaded")

invoking_resource = "provider_test"
assert(lb_send_notification({
    app = "calendar",
    title = "Hospital",
    content = "Your appointment has been confirmed.",
}), "LB notifications for bundled phone apps must be accepted")
local lb_notification_message = nui_messages[#nui_messages]
assert(lb_notification_message.type == "notification:show", "LB notifications must reach the phone notification UI")
assert(lb_notification_message.data.appId == "calendar", "LB notifications must preserve the target app")
assert(lb_notification_message.data.route == "/apps/calendar", "LB notifications must link to the target app")
assert(lb_notification_message.data.text == "Your appointment has been confirmed.", "LB notification content must be preserved")

local unknown_notification_success, unknown_notification_error = lb_send_notification({
    app = "unknown-provider-app",
    title = "Hospital",
    content = "Unknown target",
})
assert(not unknown_notification_success and unknown_notification_error == "app_not_found", "LB notifications must reject unknown app IDs")

invoking_resource = "lb_app"
local lifecycle_response_delivered = false
local install_hook_after_response = false
local delete_hook_after_response = false
local open_hook_after_response = false
local lb_definition = {
    identifier = "dispatch",
    name = "Dispatch",
    description = "Dispatch terminal",
    defaultApp = false,
    fixBlur = true,
    ui = "ui/index.html",
    onInstall = make_cfx_function_reference("install-hook", function()
        install_hook_after_response = lifecycle_response_delivered
        error("vendor install failure")
    end),
    onDelete = make_cfx_function_reference("delete-hook", function()
        delete_hook_after_response = lifecycle_response_delivered
    end),
    onOpen = make_cfx_function_reference("open-hook", function()
        open_hook_after_response = lifecycle_response_delivered
        error(5)
    end),
}
local lb_success, lb_error = lb_add_custom_app(lb_definition)
assert(lb_success and lb_error == nil, "LB AddCustomApp must register through the shared export")
lb_definition.name = "Dispatch Updated"
local retry_success, retry_error = lb_add_custom_app(lb_definition)
assert(retry_success and retry_error == nil, "same-owner LB registration retries must update in place")

local lifecycle_callback = assert(registered_nui_callbacks["custom-app:lifecycle"])
local lifecycle_response
SkyPhoneApps.SetPhoneOpen(true)
local retry_catalog = nui_messages[#nui_messages]
local retried_app
for index = 1, #retry_catalog.data.apps do
    if retry_catalog.data.apps[index].id == "dispatch" then
        retried_app = retry_catalog.data.apps[index]
        break
    end
end
assert(retried_app and retried_app.name == "Dispatch Updated", "same-owner retry must publish the updated app")
assert(not retried_app.defaultInstalled, "LB defaultApp=false must keep the app available for App Store installation")
assert(retried_app.compatibility.fixBlur, "LB fixBlur must be preserved for every provider app")
local catalog_debug_response
assert(registered_nui_callbacks["custom-app:catalog-debug"])({
    acceptedCount = 1,
    acceptedIds = { "dispatch" },
    receivedCount = 1,
}, function(response)
    catalog_debug_response = response
end)
assert(catalog_debug_response.success, "the NUI catalog acknowledgement must be accepted")
lifecycle_response_delivered = false
lifecycle_callback({ appId = "dispatch", event = "install" }, function(response)
    lifecycle_response = response
    lifecycle_response_delivered = true
end)
assert(lifecycle_response.success, "a vendor install hook failure must not fail installation")
assert(install_hook_after_response, "a vendor install hook must run after the NUI response")
lifecycle_response_delivered = false
lifecycle_callback({ appId = "dispatch", event = "delete" }, function(response)
    lifecycle_response = response
    lifecycle_response_delivered = true
end)
assert(lifecycle_response.success, "a vendor delete hook must not fail uninstallation")
assert(delete_hook_after_response, "a vendor delete hook must run after the NUI response")
lifecycle_response_delivered = false
lifecycle_callback({ appId = "dispatch", event = "open" }, function(response)
    lifecycle_response = response
    lifecycle_response_delivered = true
end)
assert(lifecycle_response.success, "a vendor open hook failure must not prevent opening the app")
assert(open_hook_after_response, "a vendor open hook must run after the NUI response")
lifecycle_callback({ appId = "dispatch", event = "ready" }, function(response)
    lifecycle_response = response
end)
assert(lifecycle_response.success, "ready must complete after a failed vendor open hook")

local server_message_handler = assert(
    registered_event_handlers["sky_phone:custom-app:message"][1],
    "server custom app messages must have a client delivery handler"
)
source = 65535
server_message_handler("lb_app", "dispatch", { type = "server-refresh" })
local server_message = nui_messages[#nui_messages]
assert(server_message.type == "custom-app:message", "server app messages must reach the active frame")
assert(server_message.data.appId == "dispatch", "server app messages must preserve the app ID")
assert(server_message.data.payload.type == "server-refresh", "server app messages must preserve JSON data")
local message_count = #nui_messages
source = 42
server_message_handler("lb_app", "dispatch", { type = "spoofed" })
assert(#nui_messages == message_count, "client-triggered server app messages must be rejected")
source = nil

SkyPhoneApps.SetPhoneOpen(false)

invoking_resource = "another_app"
local duplicate_success, duplicate_error = lb_add_custom_app({
    identifier = "dispatch",
    name = "Hijack",
    description = "Hijack",
    ui = "ui/index.html",
})
assert(not duplicate_success and duplicate_error == "duplicate_app_id", "cross-owner IDs must be rejected")

local remove_success, remove_error = lb_remove_custom_app("dispatch")
assert(not remove_success and remove_error == "app_owner_mismatch", "cross-owner removal must be rejected")

invoking_resource = "lb_app"
local inactive_message_success, inactive_message_error = lb_send_custom_app_message("dispatch", { type = "ping" })
assert(not inactive_message_success and inactive_message_error == "app_not_active", "LB message alias must preserve app state checks")
local closed_open_success, closed_open_error = lb_open_app("dispatch")
assert(not closed_open_success and closed_open_error == "phone_closed", "LB open alias must preserve phone state checks")
local inactive_close_success, inactive_close_error = lb_close_app({ app = "dispatch" })
assert(not inactive_close_success and inactive_close_error == "app_not_active", "LB close alias must preserve app state checks")
assert(lb_remove_custom_app("dispatch"), "the LB owner must be able to remove its app")

assert(lb_add_custom_app({
    identifier = "remote-dashboard",
    name = "Remote Dashboard",
    description = "Hosted dashboard",
    ui = "https://apps.example.com/dashboard/index.html",
    icon = "https://cdn.example.com/dashboard.png",
}), "secure remote LB assets must register without a manual origin allowlist")
SkyPhoneApps.SetPhoneOpen(true)
SkyPhoneApps.SendCatalog()
local remote_catalog = nui_messages[#nui_messages]
local remote_app
for index = 1, #remote_catalog.data.apps do
    if remote_catalog.data.apps[index].id == "remote-dashboard" then
        remote_app = remote_catalog.data.apps[index]
        break
    end
end
assert(remote_app, "the remote LB app must be present in the catalog")
assert(
    remote_app.ui == "https://apps.example.com/dashboard/index.html",
    "the registered HTTPS UI origin must be derived automatically"
)
assert(
    remote_app.icon == "https://cdn.example.com/dashboard.png",
    "the registered HTTPS icon origin must be derived automatically"
)
SkyPhoneApps.SetPhoneOpen(false)
assert(lb_remove_custom_app("remote-dashboard"), "the remote LB app must remain owner-removable")

invoking_resource = "phone_adapter"
assert(lb_add_custom_app({
    identifier = "manufacturer-app",
    name = "Manufacturer App",
    description = "Manufacturer-owned UI assets",
    ui = "manufacturer_app/ui/index.html",
    icon = "nui://manufacturer_app/ui/icon.png",
}), "LB resource-prefixed assets must register through an adapter")
SkyPhoneApps.SetPhoneOpen(true)
SkyPhoneApps.SendCatalog()
local catalog_message = nui_messages[#nui_messages]
local manufacturer_app
for index = 1, #catalog_message.data.apps do
    if catalog_message.data.apps[index].id == "manufacturer-app" then
        manufacturer_app = catalog_message.data.apps[index]
        break
    end
end
assert(manufacturer_app, "manufacturer app must be present in the catalog")
assert(
    manufacturer_app.ui == "https://cfx-nui-manufacturer_app/ui/index.html",
    "LB resource-prefixed UI must preserve its asset resource"
)
assert(
    manufacturer_app.icon == "https://cfx-nui-manufacturer_app/ui/icon.png",
    "LB resource-prefixed icon must preserve its asset resource"
)
SkyPhoneApps.SetPhoneOpen(false)

invoking_resource = "yseries_app"
assert(yseries_add_custom_app({
    key = "slots",
    name = "Slots",
    ui = "https://cfx-nui-yseries_app/ui/index.html",
    icon = {
        yos = "https://cdn.example.com/slots.png",
    },
}), "YSeries AddCustomApp must be selected from the key field")
local yseries_message_success, yseries_message_error = yseries_send_app_message("slots", { type = "ping" })
assert(not yseries_message_success and yseries_message_error == "app_not_active", "YSeries message alias must preserve app state checks")
assert(yseries_remove_custom_app("slots"), "YSeries RemoveCustomApp must use the provider alias")

local native_success, native_error = SkyPhoneApps.ClientPublicApi.AddCustomApp({
    identifier = "provider-only-shape",
    name = "Provider-only shape",
    ui = "ui/index.html",
})
assert(not native_success and native_error == "invalid_app_id", "native Sky exports must not route vendor schemas")

invoking_resource = "mov_app"
assert(mov_add_application({
    name = "market",
    label = "Market",
    ui = "https://cfx-nui-mov_app/ui/index.html",
}), "17mov AddApplication must register")
local mov_message_success, mov_message_error = mov_send_app_message("market", { type = "ping" })
assert(not mov_message_success and mov_message_error == "app_not_active", "17mov message alias must preserve app state checks")
assert(mov_remove_application("market"), "17mov RemoveApplication must use the provider alias")

invoking_resource = "high_app"
assert(high_add_application("bankingv2", {
    externalUrl = "@high_app/ui/index.html",
}, {
    en = {
        label = "Banking",
        description = "Banking app",
    },
}), "High addApplication must register")
local high_message_success, high_message_error = high_send_app_nui("bankingv2", { type = "ping" })
assert(not high_message_success and high_message_error == "app_not_active", "High message alias must preserve app state checks")

local high_server_definition = assert(SkyPhoneCompatibility.BuildHighDefinition(
    "high_server_owner",
    "server-owned",
    { externalUrl = "@high_server_owner/ui/index.html" },
    { en = { label = "Server App", description = "Server-owned app" } }
))
source = 65535
assert(registered_event_handlers["sky_phone:compat:high:client:syncApplication"][1](
    "high_server_owner",
    high_server_definition,
    1
) == nil)
invoking_resource = "high_server_owner"
local authority_update_success, authority_update_error =
    SkyPhoneApps.ClientPublicApi.UpdateCustomApp(high_server_definition)
assert(not authority_update_success and authority_update_error == "app_authority_mismatch",
    "direct client updates must not overwrite a server-authorized app")
local authority_remove_success, authority_remove_error =
    SkyPhoneApps.ClientPublicApi.RemoveCustomApp("server-owned")
assert(not authority_remove_success and authority_remove_error == "app_authority_mismatch",
    "direct client removal must not delete a server-authorized app")
invoking_resource = "high_conflicting_owner"
local high_conflict_success, high_conflict_error = high_add_application("server-owned", {
    externalUrl = "@high_conflicting_owner/ui/index.html",
}, {
    en = {
        label = "Conflicting App",
        description = "Must never be retained",
    },
})
assert(not high_conflict_success and high_conflict_error == "duplicate_app_id",
    "High client registrations must reject a conflicting server owner")
registered_event_handlers["sky_phone:compat:high:client:removeApplication"][1](
    "high_server_owner",
    "server-owned"
)
local retained_success, retained_error = high_send_app_nui("server-owned", { type = "ping" })
assert(not retained_success and retained_error == "app_not_found",
    "rejected High registrations must not reappear after the server owner stops")

local high_server_only_definition = assert(SkyPhoneCompatibility.BuildHighDefinition(
    "missing_resource",
    "server-only",
    { externalUrl = "https://apps.example.com/server-only/index.html" },
    { en = { label = "Server Only", description = "Server-only resource app" } }
))
source = 42
registered_event_handlers["sky_phone:compat:high:client:syncApplication"][1](
    "missing_resource",
    high_server_only_definition,
    1
)
assert(SkyPhoneCompatibilityClient.FindProviderApp("server-only") == nil,
    "locally invoked High server syncs must be rejected")
source = 65535
registered_event_handlers["sky_phone:compat:high:client:syncApplication"][1](
    "missing_resource",
    high_server_only_definition,
    1
)
local high_server_only_record = SkyPhoneCompatibilityClient.GetProviderApp(
    "missing_resource",
    "server-only",
    { [SkyPhoneCompatibility.Providers.high] = true }
)
assert(high_server_only_record,
    "server-authorized High apps must not require a downloaded client resource")
registered_event_handlers["sky_phone:compat:high:client:removeApplication"][1](
    "missing_resource",
    "server-only"
)
assert(SkyPhoneCompatibilityClient.FindProviderApp("server-only") == nil,
    "server-only High apps must follow the authoritative server lifecycle")

local high_owner_a_definition = assert(SkyPhoneCompatibility.BuildHighDefinition(
    "high_owner_a",
    "owner-pinned",
    { externalUrl = "https://apps.example.com/owner-a/index.html" },
    { en = { label = "Owner A", description = "First owner" } }
))
local high_owner_b_definition = assert(SkyPhoneCompatibility.BuildHighDefinition(
    "high_owner_b",
    "owner-pinned",
    { externalUrl = "https://apps.example.com/owner-b/index.html" },
    { en = { label = "Owner B", description = "Conflicting owner" } }
))
registered_event_handlers["sky_phone:compat:high:client:syncApplication"][1](
    "high_owner_a",
    high_owner_a_definition,
    1
)
registered_event_handlers["sky_phone:compat:high:client:syncApplication"][1](
    "high_owner_b",
    high_owner_b_definition,
    2
)
assert(SkyPhoneCompatibilityClient.GetProviderApp(
    "high_owner_a",
    "owner-pinned",
    { [SkyPhoneCompatibility.Providers.high] = true }
), "the first server-authorized High owner must remain pinned")
registered_event_handlers["sky_phone:compat:high:client:removeApplication"][1](
    "high_owner_b",
    "owner-pinned"
)
assert(SkyPhoneCompatibilityClient.FindProviderApp("owner-pinned"),
    "a conflicting owner must not remove the pinned server app")
registered_event_handlers["sky_phone:compat:high:client:removeApplication"][1](
    "high_owner_a",
    "owner-pinned"
)
assert(SkyPhoneCompatibilityClient.FindProviderApp("owner-pinned") == nil)

local high_restart_definition = assert(SkyPhoneCompatibility.BuildHighDefinition(
    "high_restart_owner",
    "restartable-server-app",
    { externalUrl = "https://apps.example.com/restartable/index.html" },
    { en = { label = "Restartable", description = "Client restart lifecycle" } }
))
registered_event_handlers["sky_phone:compat:high:client:syncApplication"][1](
    "high_restart_owner",
    high_restart_definition,
    1
)
for index = 1, #registered_event_handlers.onClientResourceStop do
    registered_event_handlers.onClientResourceStop[index]("high_restart_owner")
end
assert(SkyPhoneCompatibilityClient.FindProviderApp("restartable-server-app") == nil,
    "client owner stop must remove the local server-authorized projection")
for index = 1, #registered_event_handlers.onClientResourceStart do
    registered_event_handlers.onClientResourceStart[index]("high_restart_owner")
end
assert(SkyPhoneCompatibilityClient.GetProviderApp(
    "high_restart_owner",
    "restartable-server-app",
    { [SkyPhoneCompatibility.Providers.high] = true }
), "client owner restart must restore the authoritative High server record")
registered_event_handlers["sky_phone:compat:high:client:removeApplication"][1](
    "high_restart_owner",
    "restartable-server-app"
)
source = nil

invoking_resource = "quasar_app"
assert(quasar_add_custom_app({
    id = "services",
    label = "Services",
    iframe = {
        url = "https://cfx-nui-quasar_app/ui/index.html",
    },
}), "Quasar addCustomApp must register")

local quasar_apps = quasar_get_custom_apps()
assert(#quasar_apps == 1 and quasar_apps[1].id == "services", "Quasar getCustomApps must expose the registry")
assert(quasar_update_custom_app("services", {
    label = "City Services",
}), "Quasar updateCustomApp must update an owned app")
assert(quasar_remove_custom_app("services"), "Quasar removeCustomApp must remove an owned app")
assert(quasar_add_custom_apps_batch({}), "Quasar batch alias must accept an empty batch")

local resource_stop_handlers = assert(registered_event_handlers["onResourceStop"])
for index = 1, #resource_stop_handlers do
    resource_stop_handlers[index]("sky_phone")
end

local client_stop_events = {}
local resource_stop_events = {}
for index = 1, #triggered_events do
    local event = triggered_events[index]
    local resource_name = event.arguments[1]
    if event.event_name == "onClientResourceStop" then
        client_stop_events[resource_name] = true
    elseif event.event_name == "onResourceStop" then
        resource_stop_events[resource_name] = true
    end
end
for resource_name in pairs(expected_provider_resources) do
    assert(client_stop_events[resource_name], ("Missing %s provider client stop signal"):format(resource_name))
    assert(resource_stop_events[resource_name], ("Missing %s provider stop signal"):format(resource_name))
end

print("Custom app compatibility client tests passed")
