SkyPhoneNavigation = {}

local installed_apps = {}
local current_app_id = nil
local data_loaded = false

local function reset_navigation_state()
    installed_apps = {}
    current_app_id = nil
    data_loaded = false
end

local function close_navigation_state()
    current_app_id = nil
end

local function normalize_app_id(app_id)
    local valid_id = SkyPhoneApps.ValidateAppId(app_id)
    if not valid_id then
        return nil
    end
    return app_id
end

local function sync_navigation_state(data)
    if type(data) ~= "table" or type(data.installedApps) ~= "table" then
        return false, "invalid_navigation_state"
    end
    if #data.installedApps > 256 then
        return false, "invalid_navigation_state"
    end

    local next_installed_apps = {}
    for index = 1, #data.installedApps do
        local app_id = normalize_app_id(data.installedApps[index])
        if not app_id then
            return false, "invalid_navigation_app"
        end
        next_installed_apps[app_id] = true
    end

    local next_current_app_id = data.currentApp
    if next_current_app_id ~= nil then
        next_current_app_id = normalize_app_id(next_current_app_id)
        if not next_current_app_id then
            return false, "invalid_current_app"
        end
    end

    installed_apps = next_installed_apps
    current_app_id = next_current_app_id
    data_loaded = true
    return true
end

function SkyPhoneNavigation.Open(app_id)
    local normalized_app_id = normalize_app_id(app_id)
    if not normalized_app_id then
        return false, "invalid_app_id"
    end
    if not SkyPhoneClient.GetState().open then
        return false, "phone_closed"
    end
    if not installed_apps[normalized_app_id] then
        return false, "app_not_installed"
    end

    current_app_id = normalized_app_id
    SendNUIMessage({
        type = "navigation:open-app",
        data = { appId = normalized_app_id },
    })
    return true
end

function SkyPhoneNavigation.Close(app_id)
    if not SkyPhoneClient.GetState().open then
        return false, "phone_closed"
    end
    if app_id ~= nil then
        local normalized_app_id = normalize_app_id(app_id)
        if not normalized_app_id then
            return false, "invalid_app_id"
        end
        if current_app_id ~= normalized_app_id then
            return false, "app_not_active"
        end
    elseif not current_app_id then
        return false, "app_not_active"
    end

    local closing_app_id = current_app_id
    current_app_id = nil
    SendNUIMessage({
        type = "navigation:close-app",
        data = { appId = closing_app_id },
    })
    return true
end

function SkyPhoneNavigation.GetState()
    local copied_installed_apps = {}
    for app_id in pairs(installed_apps) do
        copied_installed_apps[app_id] = true
    end
    return {
        currentApp = current_app_id,
        dataLoaded = data_loaded,
        installedApps = copied_installed_apps,
    }
end

function SkyPhoneNavigation.IsDataLoaded()
    return data_loaded
end

function SkyPhoneNavigation.IsInstalled(app_id)
    local normalized_app_id = normalize_app_id(app_id)
    if not normalized_app_id then
        return false
    end
    return installed_apps[normalized_app_id] == true
end

function SkyPhoneNavigation.GetCurrent(app_id)
    if not SkyPhoneClient.GetState().open then
        if app_id == nil then
            return nil
        end
        return false
    end

    local visible_app_id = current_app_id or "home"
    if app_id == nil then
        return visible_app_id
    end

    local normalized_app_id = normalize_app_id(app_id)
    return normalized_app_id ~= nil and visible_app_id == normalized_app_id
end

function SkyPhoneNavigation.Reset()
    reset_navigation_state()
end

RegisterNUICallback("navigation:state", function(data, cb)
    local success, error_code = sync_navigation_state(data)
    cb(success and { success = true } or { success = false, error = error_code })
end)

AddEventHandler("sky_phone:client:phoneToggled", function(open)
    if not open then
        close_navigation_state()
    end
end)

AddEventHandler("onClientResourceStop", function(resource_name)
    if resource_name == GetCurrentResourceName() then
        reset_navigation_state()
    end
end)
