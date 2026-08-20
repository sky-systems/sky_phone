local client_bridge = SkyPhoneCompatibilityClient
local RESOURCE_NAME = client_bridge.ResourceName
local providers = client_bridge.Providers
local compatibility_core = client_bridge.Core
local phone = client_bridge.Phone
local calls = client_bridge.Calls
local notifications = client_bridge.Notifications
local camera = client_bridge.Camera
local high_client_apps = {}
local high_server_apps = {}

local function add_application(app_name, data, locales)
    local owner_resource, owner_error = client_bridge.GetCallingResource("addApplication")
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
        Bridge.Debug(
            "warn",
            "[%s] High Phone registration rejected for %s: %s.",
            RESOURCE_NAME,
            owner_resource,
            definition_error
        )
        return false, definition_error
    end

    local server_record = high_server_apps[app_name]
    if server_record and server_record.owner_resource ~= owner_resource then
        return false, "duplicate_app_id"
    end

    if server_record then
        if server_record.registered then
            high_client_apps[app_name] = {
                definition = definition,
                owner_resource = owner_resource,
            }
            return true
        end
        return false, "server_definition_not_registered"
    end

    local success, register_error = client_bridge.RegisterProviderApp(
        providers.high,
        owner_resource,
        definition,
        client_bridge.CopyRecordData(data)
    )
    if success then
        high_client_apps[app_name] = {
            definition = definition,
            owner_resource = owner_resource,
        }
    end
    return success, register_error
end

local function send_app_nui(app_name, data)
    local owner_resource, owner_error = client_bridge.GetCallingResource("sendAppNui")
    if not owner_resource then
        return false, owner_error
    end

    local record, record_error = client_bridge.GetProviderApp(owner_resource, app_name, {
        [providers.high] = true,
    })
    if not record then
        return false, record_error
    end
    return compatibility_core.SendMessage(owner_resource, app_name, data)
end

local function register_server_app(owner_resource, definition, revision)
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
    if existing and existing.owner_resource ~= owner_resource then
        Bridge.Debug("warn", "[%s] Rejected conflicting High Phone owner for %s.", RESOURCE_NAME, app_id)
        return app_id
    end
    if existing and revision <= existing.revision then
        if revision < existing.revision or existing.registered then
            return app_id
        end
    end

    local provider_record = client_bridge.FindProviderApp(app_id)
    local success, error_message
    if provider_record then
        if provider_record.owner_resource ~= owner_resource or provider_record.provider ~= providers.high then
            success, error_message = false, "duplicate_app_id"
        else
            success, error_message = compatibility_core.UpdateServerAuthorized(
                owner_resource,
                providers.high,
                definition
            )
        end
    else
        success, error_message = compatibility_core.AddServerAuthorized(
            owner_resource,
            providers.high,
            definition
        )
    end

    high_server_apps[app_id] = {
        definition = definition,
        last_error = success and nil or error_message,
        owner_resource = owner_resource,
        registered = success == true,
        revision = revision,
    }
    if success then
        client_bridge.TrackProviderApp(providers.high, owner_resource, definition, nil)
    elseif not existing or existing.revision ~= revision or existing.last_error ~= error_message then
        Bridge.Debug(
            "error",
            "[%s] Could not register High Phone server application %s revision %s: %s.",
            RESOURCE_NAME,
            app_id,
            revision,
            error_message or "unknown_error"
        )
    end
    return app_id
end

local function remove_server_app(owner_resource, app_id)
    local record = high_server_apps[app_id]
    if not record or record.owner_resource ~= owner_resource then
        return
    end

    high_server_apps[app_id] = nil
    if record.registered then
        compatibility_core.RemoveServerAuthorized(owner_resource, providers.high, app_id)
    end

    local client_record = high_client_apps[app_id]
    if client_record then
        local provider_record = client_bridge.FindProviderApp(app_id)
        if provider_record
            and provider_record.owner_resource == client_record.owner_resource
            and provider_record.provider == providers.high
        then
            return
        end
        local success, error_message = client_bridge.RegisterProviderApp(
            providers.high,
            client_record.owner_resource,
            client_record.definition,
            nil
        )
        if not success then
            Bridge.Debug(
                "error",
                "[%s] Could not restore High Phone client application %s: %s.",
                RESOURCE_NAME,
                app_id,
                error_message or "unknown_error"
            )
        end
    end
end

local function close_phone()
    phone.Toggle(false)
end

local function start_call(phone_number, video)
    if type(phone_number) ~= "string" or not phone_number:match("%S") then
        Bridge.Debug("error", "[%s] Rejected invalid High Phone call target.", RESOURCE_NAME)
        return
    end
    if video ~= nil and type(video) ~= "boolean" then
        Bridge.Debug("error", "[%s] Rejected invalid High Phone video-call state.", RESOURCE_NAME)
        return
    end
    if video then
        Bridge.Debug("warn", "[%s] High Phone video calls are not supported.", RESOURCE_NAME)
        return
    end

    local success, error_message = calls.Dial(phone_number)
    if not success then
        Bridge.Debug(
            "warn",
            "[%s] High Phone audio call could not be started: %s.",
            RESOURCE_NAME,
            tostring(error_message or "request_failed")
        )
    end
end

local function end_call()
    calls.Terminate()
end

local function send_notification(notification)
    local mapped, map_error = SkyPhoneCompatibility.MapHighNotification(notification)
    if not mapped then
        Bridge.Debug(
            "warn",
            "[%s] Rejected unsupported High Phone notification: %s.",
            RESOURCE_NAME,
            tostring(map_error)
        )
        return
    end

    local success, notification_error = notifications.Send(mapped)
    if not success then
        Bridge.Debug(
            "warn",
            "[%s] Rejected High Phone notification: %s.",
            RESOURCE_NAME,
            tostring(notification_error)
        )
    end
end

local function set_camera_facing(facing)
    if facing ~= "front" and facing ~= "rear" then
        Bridge.Debug("error", "[%s] Rejected invalid High Phone camera facing.", RESOURCE_NAME)
        return
    end
    camera.SetSelfie(facing == "front")
end

local function use_phone_item()
    phone.Toggle(true)
end

RegisterNetEvent("sky_phone:compat:high:client:syncApplication", function(owner_resource, definition, revision)
    if source ~= 65535 then
        Bridge.Debug("warn", "[%s] Rejected locally invoked High Phone application sync.", RESOURCE_NAME)
        return
    end
    register_server_app(owner_resource, definition, revision)
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
    remove_server_app(owner_resource, app_id)
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
            local app_id = register_server_app(record.owner_resource, record.definition, record.revision)
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
        remove_server_app(removed[index].owner_resource, removed[index].app_id)
    end
end)

AddEventHandler("sky_phone:client:customAppRemoved", function(owner_resource, app_id)
    local record = high_server_apps[app_id]
    if record and record.owner_resource == owner_resource then
        record.registered = false
        record.last_error = "registration_removed"
    end
end)

AddEventHandler("onClientResourceStart", function(resource_name)
    for _, record in pairs(high_server_apps) do
        if record.owner_resource == resource_name and not record.registered then
            register_server_app(record.owner_resource, record.definition, record.revision)
        end
    end
end)

AddEventHandler("onClientResourceStop", function(resource_name)
    for app_id, record in pairs(high_client_apps) do
        if record.owner_resource == resource_name then
            high_client_apps[app_id] = nil
        end
    end
end)

SkyPhoneCompatibility.RegisterExportAlias("high-phone", "addApplication", add_application)
SkyPhoneCompatibility.RegisterExportAlias("high-phone", "sendAppNui", send_app_nui)
SkyPhoneCompatibility.RegisterExportAlias("high-phone", "closePhone", close_phone)
SkyPhoneCompatibility.RegisterExportAlias("high-phone", "startCall", start_call)
SkyPhoneCompatibility.RegisterExportAlias("high-phone", "endCall", end_call)
SkyPhoneCompatibility.RegisterExportAlias("high-phone", "sendNotification", send_notification)
SkyPhoneCompatibility.RegisterExportAlias("high-phone", "setCameraFacing", set_camera_facing)
SkyPhoneCompatibility.RegisterExportAlias("high-phone", "formatNumber", client_bridge.FormatNumber)
SkyPhoneCompatibility.RegisterExportAlias("high-phone", "usePhoneItem", use_phone_item)
