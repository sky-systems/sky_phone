SkyPhoneMediaProviderConfig = {}

local function trim_key(value)
    if type(value) ~= "string" then
        return ""
    end
    return value:match("^%s*(.-)%s*$")
end

function SkyPhoneMediaProviderConfig.FiveManageApiKey(override_key)
    local api_key = trim_key(override_key)
    if api_key ~= "" then
        return api_key
    end

    return trim_key(Config.Media.FiveManage.ApiKey)
end

function SkyPhoneMediaProviderConfig.FiveManageSetupHint()
    if Config.PhoneConfigurator.Enabled == true then
        return "Add a FiveManage V3 token with Media access to FiveManage.ApiKey in /phonepanel > Phone Configurator and save with the green check. The token applies immediately; config/media.lua is ignored while the Phone Configurator is enabled."
    end

    return "Add a FiveManage V3 token with Media access to Config.Media.FiveManage.ApiKey in config/media.lua and restart sky_phone."
end
