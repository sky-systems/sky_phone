local client_bridge = SkyPhoneCompatibilityClient
local RESOURCE_NAME = client_bridge.ResourceName
local providers = client_bridge.Providers
local compatibility_core = client_bridge.Core
local phone = client_bridge.Phone
local calls = client_bridge.Calls
local camera = client_bridge.Camera
local focus = SkyPhoneFocus
local navigation = SkyPhoneNavigation

local function add_custom_app(app_data)
    local owner_resource, owner_error = client_bridge.GetCallingResource("AddCustomApp")
    if not owner_resource then
        return false, owner_error
    end
    if type(app_data) ~= "table" or app_data.key == nil then
        return false, "invalid_definition"
    end

    local definition, definition_error = SkyPhoneCompatibility.BuildYSeriesDefinition(app_data)
    if not definition then
        Bridge.Debug(
            "warn",
            "[%s] %s registration rejected for %s: %s.",
            RESOURCE_NAME,
            providers.yseries,
            owner_resource,
            definition_error
        )
        return false, definition_error
    end

    return client_bridge.RegisterProviderApp(
        providers.yseries,
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
        [providers.yseries] = true,
    })
end

local function send_app_message(app_id, data)
    local owner_resource, owner_error = client_bridge.GetCallingResource("SendAppMessage")
    if not owner_resource then
        return false, owner_error
    end

    local record, record_error = client_bridge.GetProviderApp(owner_resource, app_id, {
        [providers.yseries] = true,
    })
    if not record then
        return false, record_error
    end
    return compatibility_core.SendMessage(owner_resource, app_id, data)
end

local function toggle_open(open)
    phone.Toggle(open)
end

local function is_open()
    return phone.GetState().open == true
end

local function toggle_flashlight(enabled)
    if type(enabled) ~= "boolean" then
        Bridge.Debug("error", "[%s] Rejected invalid YSeries flashlight state.", RESOURCE_NAME)
        return
    end
    camera.SetFlashlight(enabled)
end

local function get_flashlight_state()
    return camera.GetState().flashEnabled == true
end

local function close_app()
    navigation.Close()
end

local function cancel_call()
    calls.Terminate()
end

local function set_nui_focus_keep_input(allow_game_input)
    local owner_resource = client_bridge.GetCallingResource("SetNuiFocusKeepInput")
    if not owner_resource then
        return
    end
    if type(allow_game_input) ~= "boolean" then
        Bridge.Debug("error", "[%s] Rejected invalid YSeries game input state.", RESOURCE_NAME)
        return
    end
    focus.SetExternalGameInput(owner_resource, allow_game_input)
end

SkyPhoneCompatibility.RegisterExportAlias("yseries", "SendAppMessage", send_app_message)
SkyPhoneCompatibility.RegisterExportAlias("yseries", "AddCustomApp", add_custom_app)
SkyPhoneCompatibility.RegisterExportAlias("yseries", "RemoveCustomApp", remove_custom_app)
SkyPhoneCompatibility.RegisterExportAlias("yseries", "GetDataLoaded", function()
    return navigation.IsDataLoaded()
end)
SkyPhoneCompatibility.RegisterExportAlias("yseries", "ToggleOpen", toggle_open)
SkyPhoneCompatibility.RegisterExportAlias("yseries", "IsOpen", is_open)
SkyPhoneCompatibility.RegisterExportAlias("yseries", "ToggleFlashlight", toggle_flashlight)
SkyPhoneCompatibility.RegisterExportAlias("yseries", "GetFlashlightState", get_flashlight_state)
SkyPhoneCompatibility.RegisterExportAlias("yseries", "CloseApp", close_app)
SkyPhoneCompatibility.RegisterExportAlias("yseries", "IsAppInstalled", navigation.IsInstalled)
SkyPhoneCompatibility.RegisterExportAlias("yseries", "GetCurrentAppId", navigation.GetCurrent)
SkyPhoneCompatibility.RegisterExportAlias("yseries", "CancelCall", cancel_call)
SkyPhoneCompatibility.RegisterExportAlias(
    "yseries",
    "SetNuiFocusKeepInput",
    set_nui_focus_keep_input
)
