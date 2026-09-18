local client_bridge = SkyPhoneCompatibilityClient
local RESOURCE_NAME = client_bridge.ResourceName
local providers = client_bridge.Providers
local compatibility_core = client_bridge.Core
local phone = client_bridge.Phone
local calls = client_bridge.Calls
local notifications = client_bridge.Notifications
local camera = client_bridge.Camera
local debug_custom_app = client_bridge.Debug

local function add_custom_app(app_data)
    local owner_resource, owner_error = client_bridge.GetCallingResource("AddCustomApp")
    if not owner_resource then
        return false, owner_error
    end
    if type(app_data) ~= "table" or app_data.identifier == nil then
        return false, "invalid_definition"
    end

    debug_custom_app(
        "provider",
        "compatibility export received owner=%s identifier=%s data_type=%s",
        tostring(owner_resource),
        tostring(app_data.identifier),
        tostring(type(app_data))
    )
    local definition, definition_error = SkyPhoneCompatibility.BuildLbDefinition(owner_resource, app_data)
    if not definition then
        debug_custom_app(
            "provider",
            "definition rejected provider=%s owner=%s error=%s",
            tostring(providers.lb),
            tostring(owner_resource),
            tostring(definition_error)
        )
        Bridge.Debug(
            "warn",
            "[%s] %s registration rejected for %s: %s.",
            RESOURCE_NAME,
            providers.lb,
            owner_resource,
            definition_error
        )
        return false, definition_error
    end

    return client_bridge.RegisterProviderApp(
        providers.lb,
        owner_resource,
        definition,
        client_bridge.CopyRecordData(app_data)
    )
end

local function remove_custom_app(app_id)
    local owner_resource, owner_error = client_bridge.GetCallingResource("RemoveCustomApp")
    if not owner_resource then
        return false, owner_error
    end
    return client_bridge.RemoveProviderApp(owner_resource, app_id, {
        [providers.lb] = true,
    })
end

local function send_custom_app_message(app_id, data)
    local owner_resource, owner_error = client_bridge.GetCallingResource("SendCustomAppMessage")
    if not owner_resource then
        return false, owner_error
    end
    local record, record_error = client_bridge.GetProviderApp(owner_resource, app_id, {
        [providers.lb] = true,
    })
    if not record then
        return false, record_error
    end
    return compatibility_core.SendMessage(owner_resource, app_id, data)
end

local function open_app(app_id, data)
    local owner_resource, owner_error = client_bridge.GetCallingResource("OpenApp")
    if not owner_resource then
        return false, owner_error
    end

    local record, record_error = client_bridge.GetProviderApp(owner_resource, app_id, {
        [providers.lb] = true,
    })
    if not record then
        return false, record_error
    end
    return compatibility_core.Open(owner_resource, app_id, data)
end

local function close_app(options)
    local owner_resource, owner_error = client_bridge.GetCallingResource("CloseApp")
    if not owner_resource then
        return false, owner_error
    end

    local app_id = type(options) == "table" and options.app or nil
    if app_id then
        local record, record_error = client_bridge.GetProviderApp(owner_resource, app_id, {
            [providers.lb] = true,
        })
        if not record then
            return false, record_error
        end
        return compatibility_core.Close(owner_resource, app_id)
    end
    return compatibility_core.CloseActive(owner_resource)
end

local function normalize_notification_text(value, maximum_length, error_code)
    if type(value) ~= "string" then
        return nil, error_code
    end

    local normalized = value:match("^%s*(.-)%s*$")
    if normalized == "" or #normalized > maximum_length then
        return nil, error_code
    end
    return normalized
end

local function send_notification(data)
    local owner_resource, owner_error = client_bridge.GetCallingResource("SendNotification")
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

    local registered_record = client_bridge.FindProviderApp(app_id)
    if registered_record then
        local record, record_error = client_bridge.GetProviderApp(owner_resource, app_id, {
            [providers.lb] = true,
        })
        if not record then
            return false, record_error
        end
    elseif not SkyPhoneApps.ReservedAppIds[app_id] then
        return false, "app_not_found"
    end

    local title, title_error = normalize_notification_text(
        data.title,
        128,
        "invalid_notification_title"
    )
    if not title then
        return false, title_error
    end

    local content, content_error = normalize_notification_text(
        data.content or data.message or data.text,
        512,
        "invalid_notification_text"
    )
    if not content then
        return false, content_error
    end

    return notifications.Send({
        appId = app_id,
        text = content,
        title = title,
    })
end

local function create_call(options)
    if type(options) ~= "table"
        or (type(options.number) ~= "string" and type(options.company) ~= "string")
    then
        Bridge.Debug("error", "[%s] Rejected invalid LB Phone CreateCall options.", RESOURCE_NAME)
        return false, "invalid_request"
    end
    return calls.Dial(options.number, options.company)
end

local function create_sms(options)
    local phone_number = type(options) == "table" and (options.number or options.phoneNumber) or options
    if type(phone_number) ~= "string" or phone_number == "" then
        Bridge.Debug("error", "[%s] Rejected invalid LB Phone CreateSMS target.", RESOURCE_NAME)
        return false, "invalid_number"
    end

    SendNUIMessage({
        type = "compat:open-messages",
        data = { phoneNumber = phone_number },
    })
    return true
end

local function get_phone_state_value(key)
    return phone.GetState()[key]
end

local function get_camera_state_value(key)
    return camera.GetState()[key]
end

SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "AddCustomApp", add_custom_app)
SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "RemoveCustomApp", remove_custom_app)
SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "SendCustomAppMessage", send_custom_app_message)
SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "OpenApp", open_app)
SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "CloseApp", close_app)
SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "SendNotification", send_notification)
SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "ToggleOpen", function(open, no_focus)
    return phone.Toggle(open, no_focus)
end)
SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "FormatNumber", client_bridge.FormatNumber)
SkyPhoneCompatibility.RegisterExportAlias(
    "lb-phone",
    "GetEquippedPhoneNumber",
    phone.GetEquippedPhoneNumber
)
SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "IsOpen", function()
    return get_phone_state_value("open")
end)
SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "IsPhoneOnScreen", function()
    return get_phone_state_value("onScreen")
end)
SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "IsInCall", function()
    return get_phone_state_value("inCall")
end)
SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "CreateCall", create_call)
SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "CreateSMS", create_sms)
SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "EnableWalkableCam", camera.EnableWalkable)
SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "DisableWalkableCam", camera.DisableWalkable)
SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "ToggleSelfieCam", camera.SetSelfie)
SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "ToggleCameraFrozen", camera.ToggleFrozen)
SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "ToggleFlashlight", camera.SetFlashlight)
SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "GetFlashlight", function()
    return get_camera_state_value("flashEnabled")
end)
SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "IsWalkingCamEnabled", function()
    return get_camera_state_value("walkable")
end)
SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "IsSelfieCam", function()
    return get_camera_state_value("selfie")
end)
SkyPhoneCompatibility.RegisterExportAlias("lb-phone", "IsCameraOpen", function()
    return get_camera_state_value("active")
end)

AddEventHandler("sky_phone:client:phoneNumberChanged", function(phone_number)
    TriggerEvent("lb-phone:numberChanged", phone_number)
end)

AddEventHandler("sky_phone:client:phoneToggled", function(open)
    TriggerEvent("lb-phone:phoneToggled", open)
end)

AddEventHandler("sky_phone:client:cameraActiveChanged", function(active)
    TriggerEvent("lb-phone:toggleHud", active)
end)
