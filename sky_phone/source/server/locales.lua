local resource_name = GetCurrentResourceName()
local missing_locales = {}

function SkyPhoneLocales.Load(language)
    if Locales[language] or missing_locales[language] or not language:match("^[a-z][a-z]$") then return end
    local path = ("config/locales/%s.lua"):format(language)
    local content = LoadResourceFile(resource_name, path)
    if not content then
        if language == "en" then error("[sky_phone] Required English locale is missing.") end
        missing_locales[language] = true
        print(("[sky_phone] Locale '%s' not found; using English."):format(language))
        return
    end
    local chunk, message = load(content, "@" .. resource_name .. "/" .. path, "t", _ENV)
    if not chunk then error(message) end
    chunk()
    assert(type(Locales[language]) == "table", "[sky_phone] Locale file did not define its language: " .. language)
end

SkyPhoneLocales.Resolve(Config.Bridge.Locale)
AddEventHandler("sky_phone:configurator:serverUpdated", function()
    SkyPhoneLocales.Resolve(Config.Bridge.Locale)
end)
