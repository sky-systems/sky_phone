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
