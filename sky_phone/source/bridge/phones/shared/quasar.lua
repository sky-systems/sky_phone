local compatibility = assert(SkyPhoneCompatibility, "Phone compatibility shared core must load before the Quasar provider")
local providers = assert(compatibility.Providers, "Phone compatibility providers are unavailable")

function compatibility.CopyQuasarData(app_data)
    local copy = {}
    for key, value in pairs(app_data) do
        if key == "iframe" and type(value) == "table" then
            copy.iframe = {}
            for iframe_key, iframe_value in pairs(value) do
                copy.iframe[iframe_key] = iframe_value
            end
        else
            copy[key] = value
        end
    end
    return copy
end

function compatibility.BuildQuasarDefinition(app_data)
    local iframe_url = type(app_data) == "table"
        and type(app_data.iframe) == "table"
        and app_data.iframe.url
        or nil
    if type(app_data) ~= "table"
        or type(app_data.id) ~= "string"
        or type(app_data.label) ~= "string"
        or type(iframe_url) ~= "string"
    then
        return nil, "invalid_app_data"
    end

    return {
        schemaVersion = 1,
        id = app_data.id,
        name = app_data.label,
        description = app_data.description or app_data.label,
        category = "utilities",
        ui = iframe_url,
        bridgeMode = "legacy",
        icon = app_data.icon,
        defaultInstalled = app_data.defaultInstalled or false,
        removable = true,
        orientation = "portrait",
        compatibility = {
            provider = providers.quasar,
            apiVersion = 1,
        },
    }
end
