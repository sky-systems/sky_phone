local required_services = {
    { name = "SkyPhoneApps", service = SkyPhoneApps },
    { name = "SkyPhoneCalls", service = SkyPhoneCalls },
    { name = "SkyPhoneCamera", service = SkyPhoneCamera },
    { name = "SkyPhoneClient", service = SkyPhoneClient },
    { name = "SkyPhoneFocus", service = SkyPhoneFocus },
    { name = "SkyPhoneNavigation", service = SkyPhoneNavigation },
    { name = "SkyPhonePublicApi", service = SkyPhonePublicApi },
}

for index = 1, #required_services do
    local entry = required_services[index]
    if type(entry.service) ~= "table" then
        error(("[sky_phone] Client public API initialized before %s."):format(entry.name))
    end
end

local CLIENT_CAPABILITIES = {
    apiVersion = SkyPhonePublicApi.Version,
    customAppProtocolVersion = SkyPhoneApps.ProtocolVersion,
    features = {
        calls = {
            audio = true,
            company = true,
            video = false,
        },
        camera = true,
        customApps = {
            enabled = Config.CustomApps.Enabled == true,
            external = Config.CustomApps.Enabled == true
                and Config.CustomApps.ExternalApps == true,
        },
        equippedPhoneNumber = true,
        navigation = true,
        notifications = {
            customApps = Config.CustomApps.Enabled == true
                and Config.CustomApps.ExternalApps == true,
            system = false,
        },
        phoneGameInput = true,
        phoneState = true,
    },
    ready = true,
    side = "client",
}

local custom_app_api = SkyPhoneApps.ClientPublicApi
if type(custom_app_api) ~= "table" then
    error("[sky_phone] Client public API initialized before the custom app API.")
end

local camera_owner_resource

local function get_calling_resource(error_code)
    local owner_resource = GetInvokingResource()
    if type(owner_resource) ~= "string" or owner_resource == "" then
        return nil, error_code or "resource_required"
    end
    return owner_resource
end

local function claim_camera()
    local owner_resource, owner_error = get_calling_resource()
    if not owner_resource then
        return nil, owner_error
    end
    if camera_owner_resource and camera_owner_resource ~= owner_resource then
        return nil, "camera_claimed"
    end
    if not camera_owner_resource and SkyPhoneCamera.GetState().active then
        return nil, "camera_in_use"
    end

    camera_owner_resource = owner_resource
    return owner_resource
end

local function verify_camera_owner()
    local owner_resource, owner_error = get_calling_resource()
    if not owner_resource then
        return nil, owner_error
    end
    if camera_owner_resource and camera_owner_resource ~= owner_resource then
        return nil, "camera_claimed"
    end
    return owner_resource
end

local function release_camera_state()
    SkyPhoneCamera.DisableWalkable()
    SkyPhoneCamera.SetFlashlight(false)
    SkyPhoneCamera.SetSelfie(false)
    camera_owner_resource = nil
end

local function get_api_capabilities()
    return SkyPhonePublicApi.Copy(CLIENT_CAPABILITIES)
end

local function is_api_ready()
    return true
end

local function set_phone_game_input_enabled(enabled)
    if type(enabled) ~= "boolean" then
        return false, "invalid_focus_claim"
    end

    local owner_resource = GetInvokingResource()
    if type(owner_resource) ~= "string" or owner_resource == "" then
        return false, "resource_required"
    end
    return SkyPhoneFocus.SetExternalGameInput(owner_resource, enabled)
end

local function set_flashlight(enabled)
    if type(enabled) ~= "boolean" then
        return false, "invalid_state"
    end
    local owner_resource, owner_error
    if enabled then
        owner_resource, owner_error = claim_camera()
    else
        owner_resource, owner_error = verify_camera_owner()
    end
    if not owner_resource then
        return false, owner_error
    end
    SkyPhoneCamera.SetFlashlight(enabled)
    return true
end

local function set_selfie_camera(enabled)
    if type(enabled) ~= "boolean" then
        return false, "invalid_state"
    end
    local owner_resource, owner_error
    if enabled then
        owner_resource, owner_error = claim_camera()
    else
        owner_resource, owner_error = verify_camera_owner()
    end
    if not owner_resource then
        return false, owner_error
    end
    SkyPhoneCamera.SetSelfie(enabled)
    return true
end

local function enable_walkable_camera(selfie)
    if selfie ~= nil and type(selfie) ~= "boolean" then
        return false, "invalid_state"
    end
    local owner_resource, owner_error = claim_camera()
    if not owner_resource then
        return false, owner_error
    end
    SkyPhoneCamera.EnableWalkable(selfie == true)
    return true
end

local function disable_walkable_camera()
    local owner_resource, owner_error = verify_camera_owner()
    if not owner_resource then
        return false, owner_error
    end
    if camera_owner_resource == owner_resource then
        release_camera_state()
    end
    return true
end

local function toggle_camera_frozen()
    if not SkyPhoneCamera.GetState().active then
        return false, "camera_not_active"
    end
    local owner_resource, owner_error = claim_camera()
    if not owner_resource then
        return false, owner_error
    end
    SkyPhoneCamera.ToggleFrozen()
    return true, SkyPhoneCamera.GetState()
end

local function set_camera_frozen(frozen)
    if type(frozen) ~= "boolean" then
        return false, "invalid_state"
    end
    local camera_state = SkyPhoneCamera.GetState()
    if not camera_state.active then
        return false, "camera_not_active"
    end
    local owner_resource, owner_error = claim_camera()
    if not owner_resource then
        return false, owner_error
    end

    if camera_state.frozen ~= frozen then
        SkyPhoneCamera.ToggleFrozen()
        camera_state = SkyPhoneCamera.GetState()
    end
    return true, camera_state
end

local function release_camera()
    local owner_resource, owner_error = verify_camera_owner()
    if not owner_resource then
        return false, owner_error
    end
    if camera_owner_resource == owner_resource then
        release_camera_state()
    end
    return true
end

exports("GetApiCapabilities", get_api_capabilities)
exports("IsApiReady", is_api_ready)

exports("TogglePhone", SkyPhoneClient.Toggle)
exports("GetPhoneState", SkyPhoneClient.GetState)
exports("GetEquippedPhoneNumber", SkyPhoneClient.GetEquippedPhoneNumber)

exports("OpenApp", SkyPhoneNavigation.Open)
exports("CloseApp", SkyPhoneNavigation.Close)
exports("GetNavigationState", SkyPhoneNavigation.GetState)
exports("GetCurrentApp", SkyPhoneNavigation.GetCurrent)
exports("IsAppDataLoaded", SkyPhoneNavigation.IsDataLoaded)
exports("IsAppInstalled", SkyPhoneNavigation.IsInstalled)

exports("Dial", SkyPhoneCalls.Dial)
exports("AnswerCall", SkyPhoneCalls.Answer)
exports("DeclineCall", SkyPhoneCalls.Decline)
exports("HangupCall", SkyPhoneCalls.Hangup)
exports("TerminateCall", SkyPhoneCalls.Terminate)
exports("GetActiveCall", SkyPhoneCalls.GetActive)
exports("IsInCall", SkyPhoneCalls.IsActive)

exports("GetCameraState", SkyPhoneCamera.GetState)
exports("SetFlashlight", set_flashlight)
exports("SetSelfieCamera", set_selfie_camera)
exports("EnableWalkableCamera", enable_walkable_camera)
exports("DisableWalkableCamera", disable_walkable_camera)
exports("SetCameraFrozen", set_camera_frozen)
exports("ToggleCameraFrozen", toggle_camera_frozen)
exports("ReleaseCamera", release_camera)

exports("SetPhoneGameInputEnabled", set_phone_game_input_enabled)

exports("AddCustomApp", custom_app_api.AddCustomApp)
exports("AddCustomAppFromAdapter", custom_app_api.AddCustomAppFromAdapter)
exports("CloseActiveCustomAppFromAdapter", custom_app_api.CloseActiveCustomAppFromAdapter)
exports("CloseCustomApp", custom_app_api.CloseCustomApp)
exports("CloseCustomAppFromAdapter", custom_app_api.CloseCustomAppFromAdapter)
exports("GetCustomAppCapabilities", custom_app_api.GetCustomAppCapabilities)
exports("OpenCustomApp", custom_app_api.OpenCustomApp)
exports("OpenCustomAppFromAdapter", custom_app_api.OpenCustomAppFromAdapter)
exports("RemoveCustomApp", custom_app_api.RemoveCustomApp)
exports("RemoveCustomAppFromAdapter", custom_app_api.RemoveCustomAppFromAdapter)
exports("SendAppMessage", custom_app_api.SendAppMessage)
exports("SendCustomAppMessage", custom_app_api.SendCustomAppMessage)
exports("SendCustomAppMessageFromAdapter", custom_app_api.SendCustomAppMessageFromAdapter)
exports("SendCustomAppNotification", custom_app_api.SendCustomAppNotification)
exports(
    "SendCustomAppNotificationFromAdapter",
    custom_app_api.SendCustomAppNotificationFromAdapter
)
exports("UpdateCustomApp", custom_app_api.UpdateCustomApp)
exports("UpdateCustomAppFromAdapter", custom_app_api.UpdateCustomAppFromAdapter)

AddEventHandler("onClientResourceStop", function(resource_name)
    if resource_name == camera_owner_resource then
        release_camera_state()
    end
end)

TriggerEvent("sky_phone:client:apiReady", SkyPhonePublicApi.Version)
