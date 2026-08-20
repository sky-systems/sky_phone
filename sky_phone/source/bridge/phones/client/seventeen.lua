local client_bridge = SkyPhoneCompatibilityClient
local RESOURCE_NAME = client_bridge.ResourceName
local providers = client_bridge.Providers
local compatibility_core = client_bridge.Core
local phone = client_bridge.Phone
local notifications = client_bridge.Notifications
local camera = client_bridge.Camera
local navigation = SkyPhoneNavigation

local function add_application(app_data)
    local owner_resource, owner_error = client_bridge.GetCallingResource("AddApplication")
    if not owner_resource then
        return false, owner_error
    end

    local definition, definition_error = SkyPhoneCompatibility.Build17MovDefinition(app_data)
    if not definition then
        Bridge.Debug(
            "warn",
            "[%s] 17mov registration rejected for %s: %s.",
            RESOURCE_NAME,
            owner_resource,
            definition_error
        )
        return false, definition_error
    end
    return client_bridge.RegisterProviderApp(
        providers.seventeen,
        owner_resource,
        definition,
        client_bridge.CopyRecordData(app_data)
    )
end

local function remove_application(app_name, _resource_name)
    local owner_resource, owner_error = client_bridge.GetCallingResource("RemoveApplication")
    if not owner_resource then
        return false, owner_error
    end

    local app_id = type(app_name) == "table" and app_name.name or app_name
    return client_bridge.RemoveProviderApp(owner_resource, app_id, {
        [providers.seventeen] = true,
    })
end

local function send_app_message(app_id, data)
    local owner_resource, owner_error = client_bridge.GetCallingResource("SendAppMessage")
    if not owner_resource then
        return false, owner_error
    end

    local record, record_error = client_bridge.GetProviderApp(owner_resource, app_id, {
        [providers.seventeen] = true,
    })
    if not record then
        return false, record_error
    end
    return compatibility_core.SendMessage(owner_resource, app_id, data)
end

local function open_phone()
    phone.Toggle(true)
end

local function close_phone()
    phone.Toggle(false)
end

local function is_phone_open()
    return phone.GetState().open == true
end

local function toggle_flashlight(state)
    if type(state) ~= "boolean" then
        Bridge.Debug("error", "[%s] Rejected invalid 17Movement flashlight state.", RESOURCE_NAME)
        return
    end
    camera.SetFlashlight(state)
end

local function get_flashlight_state()
    return camera.GetState().flashEnabled == true
end

local function create_notification(notification)
    local mapped, map_error = SkyPhoneCompatibility.Map17MovNotification(notification)
    if not mapped then
        Bridge.Debug(
            "warn",
            "[%s] Rejected unsupported 17Movement notification: %s.",
            RESOURCE_NAME,
            tostring(map_error)
        )
        return
    end

    local success, notification_error = notifications.Send(mapped)
    if not success then
        Bridge.Debug(
            "warn",
            "[%s] Rejected 17Movement notification: %s.",
            RESOURCE_NAME,
            tostring(notification_error)
        )
    end
end

local function open_app(app_name)
    navigation.Open(app_name)
end

local function close_app(app_name)
    navigation.Close(app_name)
end

SkyPhoneCompatibility.RegisterExportAlias("17mov_Phone", "AddApplication", add_application)
SkyPhoneCompatibility.RegisterExportAlias("17mov_Phone", "RemoveApplication", remove_application)
SkyPhoneCompatibility.RegisterExportAlias("17mov_Phone", "SendAppMessage", send_app_message)
SkyPhoneCompatibility.RegisterExportAlias("17mov_Phone", "OpenPhone", open_phone)
SkyPhoneCompatibility.RegisterExportAlias("17mov_Phone", "ClosePhone", close_phone)
SkyPhoneCompatibility.RegisterExportAlias("17mov_Phone", "IsPhoneOpen", is_phone_open)
SkyPhoneCompatibility.RegisterExportAlias(
    "17mov_Phone",
    "CreateNotification",
    create_notification
)
SkyPhoneCompatibility.RegisterExportAlias(
    "17mov_Phone",
    "GetPlayerNumber",
    phone.GetEquippedPhoneNumber
)
SkyPhoneCompatibility.RegisterExportAlias("17mov_Phone", "ToggleFlashlight", toggle_flashlight)
SkyPhoneCompatibility.RegisterExportAlias("17mov_Phone", "GetFlashlightState", get_flashlight_state)
SkyPhoneCompatibility.RegisterExportAlias("17mov_Phone", "OpenApp", open_app)
SkyPhoneCompatibility.RegisterExportAlias("17mov_Phone", "CloseApp", close_app)
