local compatibility = assert(SkyPhoneCompatibility, "Phone compatibility shared core must load before the 17mov provider")
local providers = assert(compatibility.Providers, "Phone compatibility providers are unavailable")

local NOTIFICATION_APP_IDS = {
    BANK = "banking",
    MESSAGES = "messages",
    SYSTEM = "settings",
}

function compatibility.Map17MovNotification(notification)
    if type(notification) ~= "table"
        or type(notification.app) ~= "string"
        or type(notification.title) ~= "string"
        or type(notification.message) ~= "string"
    then
        return nil, "unsupported_notification"
    end

    local app_name = notification.app:match("^%s*(.-)%s*$")
    local app_id = NOTIFICATION_APP_IDS[app_name:upper()] or app_name:lower()
    return {
        appId = app_id,
        text = notification.message,
        title = notification.title,
    }
end

function compatibility.Build17MovDefinition(app_data)
    if type(app_data) ~= "table" or type(app_data.name) ~= "string" then
        return nil, "invalid_app_data"
    end

    return {
        schemaVersion = 1,
        id = app_data.name,
        name = app_data.label,
        description = app_data.description or app_data.label,
        category = "utilities",
        ui = app_data.ui,
        bridgeMode = "legacy",
        icon = app_data.icon,
        iconBackground = type(app_data.iconBackground) == "string" and app_data.iconBackground or nil,
        defaultInstalled = app_data.default or app_data.preInstalled or false,
        removable = not app_data.default,
        orientation = "portrait",
        compatibility = {
            provider = providers.seventeen,
            apiVersion = 1,
        },
    }
end
