local registered_exports = {}
local registered_event_handlers = {}
local registered_nui_callbacks = {}
local triggered_events = {}
local nui_messages = {}
local waits = {}
local invoking_resource = nil

Config = {
    Bridge = {
        Locale = "en",
    },
    CustomApps = {
        AllowRemoteOrigins = {},
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
function RegisterNetEvent() end
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
    triggered_events[#triggered_events + 1] = {
        event_name = event_name,
        arguments = { ... },
    }
end

function CreateThread(handler)
    handler()
end
function Wait(milliseconds)
    waits[#waits + 1] = milliseconds
end

dofile("sky_phone/source/bridge/shared.lua")
dofile("sky_phone/source/shared/custom_apps.lua")
dofile("sky_phone/source/shared/custom_app_compat.lua")
dofile("sky_phone/source/client/custom_apps.lua")
dofile("sky_phone/source/client/custom_app_compat.lua")

local function get_alias_export(resource_name, export_name)
    local event_name = ("__cfx_export_%s_%s"):format(resource_name, export_name)
    local handlers = registered_event_handlers[event_name]
    assert(handlers and #handlers == 1, ("Missing %s:%s export alias"):format(resource_name, export_name))

    local alias_handler
    local export_callback = setmetatable({
        __cfx_functionReference = "test-export-callback",
    }, {
        __call = function(_, handler)
            alias_handler = handler
        end,
    })
    handlers[1](export_callback)
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
local quasar_open_phone_app = get_alias_export("qs-smartphone", "OpenPhoneApp")
local yseries_add_custom_app = get_alias_export("yseries", "AddCustomApp")
local yseries_remove_custom_app = get_alias_export("yseries", "RemoveCustomApp")
local yseries_send_app_message = get_alias_export("yseries", "SendAppMessage")
local yseries_close_app = get_alias_export("yseries", "CloseApp")
local yseries_get_data_loaded = get_alias_export("yseries", "GetDataLoaded")

local expected_provider_resources = {
    ["lb-phone"] = true,
    ["17mov_Phone"] = true,
    ["high-phone"] = true,
    ["qs-smartphone"] = true,
    ["yseries"] = true,
}
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
assert(waits[1] == 500, "compatibility ready signals must wait for dependent LB apps to initialize")
assert(yseries_get_data_loaded(), "YSeries must see the compatibility provider as loaded")

invoking_resource = "sky_base"
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
local yseries_close_success, yseries_close_error = yseries_close_app({ app = "slots" })
assert(not yseries_close_success and yseries_close_error == "app_not_active", "YSeries close alias must preserve app state checks")
assert(yseries_remove_custom_app("slots"), "YSeries RemoveCustomApp must use the provider alias")

local ambiguous_success, ambiguous_error = registered_exports.AddCustomApp({
    id = "ambiguous",
    identifier = "ambiguous",
    name = "Ambiguous",
    ui = "ui/index.html",
})
assert(not ambiguous_success and ambiguous_error == "ambiguous_app_provider", "ambiguous schemas must fail")

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
local quasar_open_success, quasar_open_error = quasar_open_phone_app("services")
assert(not quasar_open_success and quasar_open_error == "phone_closed", "Quasar open alias must preserve phone state checks")
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
