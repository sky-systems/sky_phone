local client_bridge = SkyPhoneCompatibilityClient
local RESOURCE_NAME = client_bridge.ResourceName
local providers = client_bridge.Providers
local compatibility_core = client_bridge.Core
local phone = client_bridge.Phone
local calls = client_bridge.Calls
local navigation = SkyPhoneNavigation

local function add_app_for_owner(owner_resource, app_data)
    local definition, definition_error = SkyPhoneCompatibility.BuildQuasarDefinition(app_data)
    if not definition then
        Bridge.Debug(
            "warn",
            "[%s] Quasar registration rejected for %s: %s.",
            RESOURCE_NAME,
            owner_resource,
            definition_error
        )
        return false, definition_error
    end

    return client_bridge.RegisterProviderApp(
        providers.quasar,
        owner_resource,
        definition,
        SkyPhoneCompatibility.CopyQuasarData(app_data)
    )
end

local function add_custom_app(app_data)
    local owner_resource, owner_error = client_bridge.GetCallingResource("addCustomApp")
    if not owner_resource then
        return false, owner_error
    end
    if type(app_data) ~= "table" then
        return false, "invalid_app_data"
    end
    return add_app_for_owner(owner_resource, app_data)
end

local function add_custom_apps_batch(apps)
    local owner_resource, owner_error = client_bridge.GetCallingResource("addCustomAppsBatch")
    if not owner_resource then
        return false, owner_error
    end
    if type(apps) ~= "table" then
        return false, "invalid_app_batch"
    end

    for index = 1, #apps do
        local success, error_message = add_app_for_owner(owner_resource, apps[index])
        if not success then
            return false, error_message
        end
    end
    return true
end

local function update_custom_app(app_id, patch)
    local owner_resource, owner_error = client_bridge.GetCallingResource("updateCustomApp")
    if not owner_resource then
        return false, owner_error
    end
    if type(patch) ~= "table" then
        return false, "invalid_patch"
    end

    local record, record_error = client_bridge.GetProviderApp(owner_resource, app_id, {
        [providers.quasar] = true,
    })
    if not record then
        return false, record_error
    end

    local merged = SkyPhoneCompatibility.CopyQuasarData(record.vendor_data)
    for key, value in pairs(patch) do
        if key == "iframe" and type(value) == "table" then
            merged.iframe = merged.iframe or {}
            for iframe_key, iframe_value in pairs(value) do
                merged.iframe[iframe_key] = iframe_value
            end
        elseif key ~= "id" then
            merged[key] = value
        end
    end
    merged.id = app_id

    local definition, definition_error = SkyPhoneCompatibility.BuildQuasarDefinition(merged)
    if not definition then
        return false, definition_error
    end

    local success, error_message = compatibility_core.Update(owner_resource, definition)
    if success then
        record.definition = definition
        record.vendor_data = SkyPhoneCompatibility.CopyQuasarData(merged)
    end
    return success, error_message
end

local function remove_custom_app(app_id)
    local owner_resource, owner_error = client_bridge.GetCallingResource("removeCustomApp")
    if not owner_resource then
        return false, owner_error
    end
    return client_bridge.RemoveProviderApp(owner_resource, app_id, {
        [providers.quasar] = true,
    })
end

local function get_custom_apps()
    local records = client_bridge.GetProviderApps(providers.quasar)
    local apps = {}
    for index = 1, #records do
        apps[index] = SkyPhoneCompatibility.CopyQuasarData(records[index].vendor_data)
    end
    return apps
end

local function is_phone_open()
    return phone.GetState().open == true
end

local function start_call(phone_number, call_type)
    if type(phone_number) ~= "string" or not phone_number:match("%S") then
        return { success = false, error = "invalid_phone_number" }
    end
    if call_type ~= "audio" then
        if call_type == "video" then
            return { success = false, error = "video_unsupported" }
        end
        return { success = false, error = "invalid_call_type" }
    end

    local success, error_message = calls.Dial(phone_number)
    if success then
        return { success = true }
    end
    return { success = false, error = error_message or "request_failed" }
end

local function open_phone_app(app_id)
    local success = navigation.Open(app_id)
    return success == true
end

SkyPhoneCompatibility.RegisterExportAlias("qs-smartphone", "addCustomApp", add_custom_app)
SkyPhoneCompatibility.RegisterExportAlias("qs-smartphone", "addCustomAppsBatch", add_custom_apps_batch)
SkyPhoneCompatibility.RegisterExportAlias("qs-smartphone", "updateCustomApp", update_custom_app)
SkyPhoneCompatibility.RegisterExportAlias("qs-smartphone", "removeCustomApp", remove_custom_app)
SkyPhoneCompatibility.RegisterExportAlias("qs-smartphone", "getCustomApps", get_custom_apps)
SkyPhoneCompatibility.RegisterExportAlias("qs-smartphone", "IsPhoneOpen", is_phone_open)
SkyPhoneCompatibility.RegisterExportAlias("qs-smartphone", "call", start_call)
SkyPhoneCompatibility.RegisterExportAlias("qs-smartphone", "OpenPhoneApp", open_phone_app)

RegisterCommand("phone:toggle", function()
    phone.Toggle()
end, false)

RegisterCommand("phone_peek_call_accept", function()
    calls.Answer()
end, false)

RegisterCommand("phone_peek_call_reject", function()
    calls.Decline()
end, false)

AddEventHandler("sky_phone:client:pushNotification", function(notification)
    if type(notification) ~= "table" then
        return
    end
    TriggerEvent("phone:pushNotification", {
        appId = notification.appId,
        text = notification.text,
        title = notification.title,
    })
end)
