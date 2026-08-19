local RESOURCE_NAME = GetCurrentResourceName()
local providers = SkyPhoneCompatibility.Providers
local core = SkyPhoneApps.CompatibilityCore
local debug_custom_app = SkyPhoneApps.Debug or function() end
local provider_resources = {
    "lb-phone",
    "17mov_Phone",
    "high-phone",
    "qs-smartphone",
    "yseries",
}
local provider_apps = {}
local high_client_apps = {}
local high_server_apps = {}

local function get_calling_resource(export_name)
    local owner_resource = GetInvokingResource()
    if owner_resource then
        return owner_resource
    end

    Bridge.Debug("warn", "[%s] %s rejected: the export must be called by another resource.",
        RESOURCE_NAME,
        export_name
    )
    return nil, "invalid_owner"
end

local function copy_record_data(value)
    if type(value) ~= "table" then
        return nil
    end

    local copied = {}
    for key, nested_value in pairs(value) do
        copied[key] = nested_value
    end
    return copied
end

local function register_provider_app(provider, owner_resource, definition, vendor_data)
    local app_id = definition.id
    local existing = provider_apps[app_id]
    debug_custom_app(
        "provider",
        "registration requested provider=%s id=%s owner=%s operation=%s",
        tostring(provider),
        tostring(app_id),
        tostring(owner_resource),
        existing and "update" or "add"
    )
    if existing and (existing.owner_resource ~= owner_resource or existing.provider ~= provider) then
        debug_custom_app(
            "provider",
            "registration rejected provider=%s id=%s owner=%s existing_provider=%s existing_owner=%s error=duplicate_app_id",
            tostring(provider),
            tostring(app_id),
            tostring(owner_resource),
            tostring(existing.provider),
            tostring(existing.owner_resource)
        )
        return false, "duplicate_app_id"
    end

    local success, error_message
    if existing then
        success, error_message = core.Update(owner_resource, definition)
    else
        success, error_message = core.Add(owner_resource, definition)
    end
    if success then
        provider_apps[app_id] = {
            definition = definition,
            owner_resource = owner_resource,
            provider = provider,
            vendor_data = vendor_data,
        }
    end
    debug_custom_app(
        "provider",
        "registration result provider=%s id=%s owner=%s success=%s error=%s",
        tostring(provider),
        tostring(app_id),
        tostring(owner_resource),
        tostring(success),
        tostring(error_message)
    )
    return success, error_message
end

local function get_provider_app(owner_resource, app_id, allowed_providers)
    if type(app_id) ~= "string" then
        return nil, "invalid_app_id"
    end

    local record = provider_apps[app_id]
    if not record then
        return nil, "app_not_found"
    end
    if record.owner_resource ~= owner_resource then
        return nil, "app_owner_mismatch"
    end
    if allowed_providers and not allowed_providers[record.provider] then
        return nil, "app_provider_mismatch"
    end
    return record
end

local function remove_provider_app(owner_resource, app_id, allowed_providers)
    local record, record_error = get_provider_app(owner_resource, app_id, allowed_providers)
    if not record then
        return false, record_error
    end

    return core.Remove(owner_resource, app_id)
end

function SkyPhoneApps.RegisterCompatibilityExport(owner_resource, app_data)
    debug_custom_app(
        "provider",
        "compatibility export received owner=%s identifier=%s key=%s data_type=%s",
        tostring(owner_resource),
        type(app_data) == "table" and tostring(app_data.identifier) or "nil",
        type(app_data) == "table" and tostring(app_data.key) or "nil",
        type(app_data)
    )
    local provider
    local definition
    local definition_error
    if app_data.identifier ~= nil then
        provider = providers.lb
        definition, definition_error = SkyPhoneCompatibility.BuildLbDefinition(owner_resource, app_data)
    elseif app_data.key ~= nil then
        provider = providers.yseries
        definition, definition_error = SkyPhoneCompatibility.BuildYSeriesDefinition(app_data)
    else
        debug_custom_app(
            "provider",
            "compatibility export rejected owner=%s error=unknown_app_provider",
            tostring(owner_resource)
        )
        return false, "unknown_app_provider"
    end

    if not definition then
        debug_custom_app(
            "provider",
            "definition rejected provider=%s owner=%s error=%s",
            tostring(provider),
            tostring(owner_resource),
            tostring(definition_error)
        )
        Bridge.Debug("warn", "[%s] %s registration rejected for %s: %s.",
            RESOURCE_NAME,
            provider,
            owner_resource,
            definition_error
        )
        return false, definition_error
    end
    debug_custom_app(
        "provider",
        "definition built provider=%s id=%s owner=%s ui=%s icon=%s default_installed=%s fix_blur=%s",
        tostring(provider),
        tostring(definition.id),
        tostring(owner_resource),
        tostring(definition.ui),
        tostring(definition.icon),
        tostring(definition.defaultInstalled),
        definition.compatibility and tostring(definition.compatibility.fixBlur) or "nil"
    )
    return register_provider_app(provider, owner_resource, definition, copy_record_data(app_data))
end

SkyPhoneApps.OnCompatibilityAppRemoved = function(owner_resource, app_id)
    local record = provider_apps[app_id]
    if record and record.owner_resource == owner_resource then
        provider_apps[app_id] = nil
    end
end

local function add_17mov_application(app_data)
    local owner_resource, owner_error = get_calling_resource("AddApplication")
    if not owner_resource then
        return false, owner_error
    end

    local definition, definition_error = SkyPhoneCompatibility.Build17MovDefinition(app_data)
    if not definition then
        Bridge.Debug("warn", "[%s] 17mov registration rejected for %s: %s.",
            RESOURCE_NAME,
            owner_resource,
            definition_error
        )
        return false, definition_error
    end
    return register_provider_app(
        providers.seventeen,
        owner_resource,
        definition,
        copy_record_data(app_data)
    )
end

local function remove_17mov_application(app_name, _resource_name)
    local owner_resource, owner_error = get_calling_resource("RemoveApplication")
    if not owner_resource then
        return false, owner_error
    end

    local app_id = type(app_name) == "table" and app_name.name or app_name
    return remove_provider_app(owner_resource, app_id, {
        [providers.seventeen] = true,
    })
end

local function send_app_message(app_id, data)
    local owner_resource, owner_error = get_calling_resource("SendAppMessage")
    if not owner_resource then
        return false, owner_error
    end

    local record, record_error = get_provider_app(owner_resource, app_id, {
        [providers.seventeen] = true,
        [providers.yseries] = true,
    })
    if not record then
        return false, record_error
    end
    return core.SendMessage(owner_resource, app_id, data)
end

local function add_high_application(app_name, data, locales)
    local owner_resource, owner_error = get_calling_resource("addApplication")
    if not owner_resource then
        return false, owner_error
    end

    local definition, definition_error = SkyPhoneCompatibility.BuildHighDefinition(
        owner_resource,
        app_name,
        data,
        locales
    )
    if not definition then
        Bridge.Debug("warn", "[%s] High Phone registration rejected for %s: %s.",
            RESOURCE_NAME,
            owner_resource,
            definition_error
        )
        return false, definition_error
    end

    high_client_apps[app_name] = {
        definition = definition,
        owner_resource = owner_resource,
    }
    local server_record = high_server_apps[app_name]
    if server_record then
        if server_record.owner_resource ~= owner_resource then
            return false, "duplicate_app_id"
        end
        if server_record.registered then
            return true
        end
        return false, "server_definition_not_registered"
    end

    return register_provider_app(
        providers.high,
        owner_resource,
        definition,
        copy_record_data(data)
    )
end

local function send_high_app_nui(app_name, data)
    local owner_resource, owner_error = get_calling_resource("sendAppNui")
    if not owner_resource then
        return false, owner_error
    end

    local record, record_error = get_provider_app(owner_resource, app_name, {
        [providers.high] = true,
    })
    if not record then
        return false, record_error
    end
    return core.SendMessage(owner_resource, app_name, data)
end

local function add_quasar_app_for_owner(owner_resource, app_data)
    local definition, definition_error = SkyPhoneCompatibility.BuildQuasarDefinition(app_data)
    if not definition then
        Bridge.Debug("warn", "[%s] Quasar registration rejected for %s: %s.",
            RESOURCE_NAME,
            owner_resource,
            definition_error
        )
        return false, definition_error
    end

    return register_provider_app(
        providers.quasar,
        owner_resource,
        definition,
        SkyPhoneCompatibility.CopyQuasarData(app_data)
    )
end

local function add_quasar_app(app_data)
    local owner_resource, owner_error = get_calling_resource("addCustomApp")
    if not owner_resource then
        return false, owner_error
    end
    if type(app_data) ~= "table" then
        return false, "invalid_app_data"
    end
    return add_quasar_app_for_owner(owner_resource, app_data)
end

local function add_quasar_apps_batch(apps)
    local owner_resource, owner_error = get_calling_resource("addCustomAppsBatch")
    if not owner_resource then
        return false, owner_error
    end
    if type(apps) ~= "table" then
        return false, "invalid_app_batch"
    end

    for index = 1, #apps do
        local success, error_message = add_quasar_app_for_owner(owner_resource, apps[index])
        if not success then
            return false, error_message
        end
    end
    return true
end

local function update_quasar_app(app_id, patch)
    local owner_resource, owner_error = get_calling_resource("updateCustomApp")
    if not owner_resource then
        return false, owner_error
    end
    if type(patch) ~= "table" then
        return false, "invalid_patch"
    end

    local record, record_error = get_provider_app(owner_resource, app_id, {
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

    local success, error_message = core.Update(owner_resource, definition)
    if success then
        record.definition = definition
        record.vendor_data = SkyPhoneCompatibility.CopyQuasarData(merged)
    end
    return success, error_message
end

local function remove_quasar_app(app_id)
    local owner_resource, owner_error = get_calling_resource("removeCustomApp")
    if not owner_resource then
        return false, owner_error
    end
    return remove_provider_app(owner_resource, app_id, {
        [providers.quasar] = true,
    })
end

local function get_quasar_apps()
    local ids = {}
    for app_id, record in pairs(provider_apps) do
        if record.provider == providers.quasar then
            ids[#ids + 1] = app_id
        end
    end
    table.sort(ids)

    local apps = {}
    for index = 1, #ids do
        apps[index] = SkyPhoneCompatibility.CopyQuasarData(provider_apps[ids[index]].vendor_data)
    end
    return apps
end

local function open_quasar_app(app_id)
    local owner_resource, owner_error = get_calling_resource("OpenPhoneApp")
    if not owner_resource then
        return false, owner_error
    end

    local record, record_error = get_provider_app(owner_resource, app_id, {
        [providers.quasar] = true,
    })
    if not record then
        return false, record_error
    end
    return core.Open(owner_resource, app_id)
end

local function open_phone_app(app_id, data)
    local owner_resource, owner_error = get_calling_resource("OpenApp")
    if not owner_resource then
        return false, owner_error
    end

    local record, record_error = get_provider_app(owner_resource, app_id)
    if not record then
        return false, record_error
    end
    return core.Open(owner_resource, app_id, data)
end

local function close_phone_app(options)
    local owner_resource, owner_error = get_calling_resource("CloseApp")
    if not owner_resource then
        return false, owner_error
    end

    local app_id = type(options) == "table" and options.app or nil
    if app_id then
        local record, record_error = get_provider_app(owner_resource, app_id, {
            [providers.lb] = true,
            [providers.yseries] = true,
        })
        if not record then
            return false, record_error
        end
        return core.Close(owner_resource, app_id)
    end
    return core.CloseActive(owner_resource)
end

local function normalize_lb_notification_text(value, maximum_length, error_code)
    if type(value) ~= "string" then
        return nil, error_code
    end

    local normalized = value:match("^%s*(.-)%s*$")
    if normalized == "" or #normalized > maximum_length then
        return nil, error_code
    end
    return normalized
end

local function send_lb_notification(data)
    local owner_resource, owner_error = get_calling_resource("SendNotification")
    if not owner_resource then
        return false, owner_error
    end
    if type(data) ~= "table" then
        return false, "invalid_notification"
    end

    local app_id = data.app or data.identifier
    local valid_app_id, app_id_error = SkyPhoneApps.ValidateAppId(app_id)
    if not valid_app_id then
        return false, app_id_error
    end

    local registered_record = provider_apps[app_id]
    if registered_record then
        local record, record_error = get_provider_app(owner_resource, app_id, {
            [providers.lb] = true,
        })
        if not record then
            return false, record_error
        end
    elseif not SkyPhoneApps.ReservedAppIds[app_id] then
        return false, "app_not_found"
    end

    local title, title_error = normalize_lb_notification_text(
        data.title,
        128,
        "invalid_notification_title"
    )
    if not title then
        return false, title_error
    end

    local content, content_error = normalize_lb_notification_text(
        data.content or data.message or data.text,
        512,
        "invalid_notification_text"
    )
    if not content then
        return false, content_error
    end

    SendNUIMessage({
        type = "notification:show",
        data = {
            appId = app_id,
            route = "/apps/" .. app_id,
            text = content,
            title = title,
        },
    })
    return true
end

local function register_high_server_app(owner_resource, definition, revision)
    if type(owner_resource) ~= "string"
        or type(definition) ~= "table"
        or type(definition.id) ~= "string"
        or type(revision) ~= "number"
        or revision ~= math.floor(revision)
        or revision < 1
    then
        Bridge.Debug("warn", "[%s] Rejected invalid High Phone server application snapshot.", RESOURCE_NAME)
        return nil
    end

    local app_id = definition.id
    local existing = high_server_apps[app_id]
    if existing and revision <= existing.revision then
        if revision < existing.revision or existing.registered then
            return app_id
        end
        if existing.owner_resource ~= owner_resource then
            Bridge.Debug("warn", "[%s] Rejected conflicting High Phone owner for %s.",
                RESOURCE_NAME,
                app_id
            )
            return app_id
        end
    end

    local provider_record = provider_apps[app_id]
    local success, error_message
    local retained_registration = false
    if provider_record then
        if provider_record.owner_resource ~= owner_resource or provider_record.provider ~= providers.high then
            success, error_message = false, "duplicate_app_id"
        else
            retained_registration = true
            success, error_message = core.Update(owner_resource, definition)
        end
    else
        success, error_message = core.Add(owner_resource, definition)
    end

    high_server_apps[app_id] = {
        definition = definition,
        last_error = success and nil or error_message,
        owner_resource = owner_resource,
        registered = success or retained_registration,
        revision = revision,
    }
    if success then
        provider_apps[app_id] = {
            definition = definition,
            owner_resource = owner_resource,
            provider = providers.high,
        }
    elseif not existing or existing.revision ~= revision or existing.last_error ~= error_message then
        Bridge.Debug("error", "[%s] Could not register High Phone server application %s revision %s: %s.",
            RESOURCE_NAME,
            app_id,
            revision,
            error_message or "unknown_error"
        )
    end
    return app_id
end

local function remove_high_server_app(owner_resource, app_id)
    local record = high_server_apps[app_id]
    if not record or record.owner_resource ~= owner_resource then
        return
    end

    high_server_apps[app_id] = nil
    if record.registered then
        core.Remove(owner_resource, app_id)
    end

    local client_record = high_client_apps[app_id]
    if client_record then
        local success, error_message = register_provider_app(
            providers.high,
            client_record.owner_resource,
            client_record.definition,
            nil
        )
        if not success then
            Bridge.Debug("error", "[%s] Could not restore High Phone client application %s: %s.",
                RESOURCE_NAME,
                app_id,
                error_message or "unknown_error"
            )
        end
    end
end

RegisterNetEvent("sky_phone:compat:high:client:syncApplication", function(owner_resource, definition, revision)
    if source ~= 65535 then
        Bridge.Debug("warn", "[%s] Rejected locally invoked High Phone application sync.", RESOURCE_NAME)
        return
    end
    register_high_server_app(owner_resource, definition, revision)
end)

RegisterNetEvent("sky_phone:compat:high:client:removeApplication", function(owner_resource, app_id)
    if source ~= 65535 then
        Bridge.Debug("warn", "[%s] Rejected locally invoked High Phone application removal.", RESOURCE_NAME)
        return
    end
    if type(owner_resource) ~= "string" or type(app_id) ~= "string" then
        Bridge.Debug("warn", "[%s] Rejected invalid High Phone application removal.", RESOURCE_NAME)
        return
    end
    remove_high_server_app(owner_resource, app_id)
end)

RegisterNetEvent("sky_phone:compat:high:client:replaceSnapshot", function(snapshot)
    if source ~= 65535 then
        Bridge.Debug("warn", "[%s] Rejected locally invoked High Phone application snapshot.", RESOURCE_NAME)
        return
    end
    if type(snapshot) ~= "table" then
        Bridge.Debug("warn", "[%s] Rejected invalid High Phone application snapshot.", RESOURCE_NAME)
        return
    end

    local seen = {}
    for index = 1, #snapshot do
        local record = snapshot[index]
        if type(record) == "table" then
            local app_id = register_high_server_app(
                record.owner_resource,
                record.definition,
                record.revision
            )
            if app_id then
                seen[app_id] = true
            end
        end
    end

    local removed = {}
    for app_id, record in pairs(high_server_apps) do
        if not seen[app_id] then
            removed[#removed + 1] = {
                app_id = app_id,
                owner_resource = record.owner_resource,
            }
        end
    end
    for index = 1, #removed do
        remove_high_server_app(removed[index].owner_resource, removed[index].app_id)
    end
end)

AddEventHandler("onClientResourceStart", function(resource_name)
    for _, record in pairs(high_server_apps) do
        if record.owner_resource == resource_name and not record.registered then
            register_high_server_app(record.owner_resource, record.definition, record.revision)
        end
    end
end)

AddEventHandler("onClientResourceStop", function(resource_name)
    if resource_name == RESOURCE_NAME then
        for index = 1, #provider_resources do
            local provider_resource = provider_resources[index]
            debug_custom_app("provider", "emitting stop compatibility signals for %s", provider_resource)
            TriggerEvent("onClientResourceStop", provider_resource)
            TriggerEvent("onResourceStop", provider_resource)
        end
        return
    end

    for app_id, record in pairs(high_client_apps) do
        if record.owner_resource == resource_name then
            high_client_apps[app_id] = nil
        end
    end
end)

exports("AddApplication", add_17mov_application)
exports("RemoveApplication", remove_17mov_application)
exports("SendAppMessage", send_app_message)
exports("addApplication", add_high_application)
exports("sendAppNui", send_high_app_nui)
exports("addCustomApp", add_quasar_app)
exports("addCustomAppsBatch", add_quasar_apps_batch)
exports("updateCustomApp", update_quasar_app)
exports("removeCustomApp", remove_quasar_app)
exports("getCustomApps", get_quasar_apps)
exports("OpenPhoneApp", open_quasar_app)
exports("OpenApp", open_phone_app)
exports("CloseApp", close_phone_app)
exports("SendNotification", send_lb_notification)

SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "OpenApp", open_phone_app)
SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "CloseApp", close_phone_app)
SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "SendNotification", send_lb_notification)

SkyPhoneCompatibility.RegisterExportAlias("17mov_Phone", "AddApplication", add_17mov_application)
SkyPhoneCompatibility.RegisterExportAlias("17mov_Phone", "RemoveApplication", remove_17mov_application)
SkyPhoneCompatibility.RegisterExportAlias("17mov_Phone", "SendAppMessage", send_app_message)

SkyPhoneCompatibility.RegisterExportAlias("high-phone", "addApplication", add_high_application)
SkyPhoneCompatibility.RegisterExportAlias("high-phone", "sendAppNui", send_high_app_nui)

SkyPhoneCompatibility.RegisterExportAlias("qs-smartphone", "addCustomApp", add_quasar_app)
SkyPhoneCompatibility.RegisterExportAlias("qs-smartphone", "addCustomAppsBatch", add_quasar_apps_batch)
SkyPhoneCompatibility.RegisterExportAlias("qs-smartphone", "updateCustomApp", update_quasar_app)
SkyPhoneCompatibility.RegisterExportAlias("qs-smartphone", "removeCustomApp", remove_quasar_app)
SkyPhoneCompatibility.RegisterExportAlias("qs-smartphone", "getCustomApps", get_quasar_apps)
SkyPhoneCompatibility.RegisterExportAlias("qs-smartphone", "OpenPhoneApp", open_quasar_app)

SkyPhoneCompatibility.RegisterExportAlias("yseries", "SendAppMessage", send_app_message)
SkyPhoneCompatibility.RegisterExportAlias("yseries", "CloseApp", close_phone_app)
SkyPhoneCompatibility.RegisterExportAlias("yseries", "GetDataLoaded", function()
    return true
end)

CreateThread(function()
    Wait(500)
    debug_custom_app("provider", "requesting provider snapshots and emitting compatibility ready signals")
    TriggerServerEvent("sky_phone:compat:high:server:requestSnapshot")
    TriggerEvent("17mov_Phone:Client:Ready")

    for index = 1, #provider_resources do
        debug_custom_app(
            "provider",
            "emitting onResourceStart compatibility signal for %s (state=%s)",
            provider_resources[index],
            tostring(GetResourceState(provider_resources[index]))
        )
        TriggerEvent("onResourceStart", provider_resources[index])
    end
end)
