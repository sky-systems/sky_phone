local compatibility = assert(SkyPhoneCompatibility, "Phone compatibility shared core must load before the High provider")
local providers = assert(compatibility.Providers, "Phone compatibility providers are unavailable")
local normalize_at_resource_url = assert(
    compatibility.NormalizeAtResourceUrl,
    "Phone compatibility URL validator is unavailable"
)

local NOTIFICATION_APP_IDS = {
    bank = "banking",
    banking = "banking",
    mail = "mail",
    messages = "messages",
    phone = "phone",
    settings = "settings",
    twizzler = "flare",
}

function compatibility.MapHighNotification(notification)
    local application = type(notification) == "table" and notification.application or nil
    if type(notification) ~= "table"
        or type(application) ~= "table"
        or type(application.name) ~= "string"
        or type(notification.title) ~= "string"
        or type(notification.content) ~= "string"
    then
        return nil, "unsupported_notification"
    end

    local app_name = application.name:match("^%s*(.-)%s*$"):lower()
    return {
        appId = NOTIFICATION_APP_IDS[app_name] or app_name,
        text = notification.content,
        title = notification.title,
    }
end

local function build_locale_maps(app_name, locales)
    local names = {}
    local descriptions = {}

    if type(locales) == "table" then
        for locale, locale_data in pairs(locales) do
            if type(locale) == "string" and type(locale_data) == "table" then
                if type(locale_data.label) == "string" and locale_data.label ~= "" then
                    names[locale] = locale_data.label
                end
                if type(locale_data.description) == "string" and locale_data.description ~= "" then
                    descriptions[locale] = locale_data.description
                end
            end
        end
    end

    if not next(names) then
        return app_name, app_name
    end
    for locale, label in pairs(names) do
        if not descriptions[locale] then
            descriptions[locale] = label
        end
    end
    return names, descriptions
end

function compatibility.BuildHighDefinition(owner_resource, app_name, data, locales)
    if type(owner_resource) ~= "string" or type(app_name) ~= "string" or type(data) ~= "table" then
        return nil, "invalid_app_data"
    end
    if #app_name > 64 or not app_name:match("^[a-z0-9][a-z0-9._-]+$") then
        return nil, "invalid_app_id"
    end

    local external_url, url_error = normalize_at_resource_url(
        owner_resource,
        data.externalUrl,
        "external_url"
    )
    if not external_url then
        return nil, url_error
    end

    local name, description = build_locale_maps(app_name, locales)
    local icon = type(data.icon) == "table" and data.icon.imageUrl or data.icon
    return {
        schemaVersion = 1,
        id = app_name,
        name = name,
        description = description,
        developer = data.developer,
        category = "utilities",
        ui = external_url,
        bridgeMode = "legacy",
        icon = icon,
        iconBackground = type(data.icon) == "table" and data.icon.background or nil,
        defaultInstalled = data.preAdded or false,
        removable = data.removable ~= false,
        orientation = "portrait",
        compatibility = {
            provider = providers.high,
            apiVersion = 1,
        },
    }
end
