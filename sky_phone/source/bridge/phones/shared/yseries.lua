local compatibility = assert(SkyPhoneCompatibility, "Phone compatibility shared core must load before the YSeries provider")
local providers = assert(compatibility.Providers, "Phone compatibility providers are unavailable")

function compatibility.BuildYSeriesDefinition(app_data)
    if type(app_data) ~= "table" or type(app_data.key) ~= "string" then
        return nil, "invalid_app_data"
    end

    local icon = app_data.icon
    if type(icon) == "table" then
        icon = icon.yos or icon.humanoid
    end

    return {
        schemaVersion = 1,
        id = app_data.key,
        name = app_data.name,
        description = app_data.description or app_data.name,
        category = app_data.game and "games" or "utilities",
        ui = app_data.ui,
        bridgeMode = "legacy",
        icon = icon,
        defaultInstalled = app_data.defaultApp or false,
        removable = true,
        orientation = "portrait",
        compatibility = {
            provider = providers.yseries,
            apiVersion = 1,
        },
    }
end
