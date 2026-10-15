-- Run from the repository root with Lua 5.4.
local handlers, reads = {}, {}
local environment = setmetatable({ Config = { Bridge = { Locale = "de-DE" } },
    GetCurrentResourceName = function() return "sky_phone" end,
    AddEventHandler = function(name, callback) handlers[name] = callback end,
    LoadResourceFile = function(resource, path)
        assert(resource == "sky_phone" and path:match("^config/locales/%l%l%.lua$"))
        reads[path] = (reads[path] or 0) + 1
        local file = io.open("sky_phone/" .. path, "rb")
        if not file then return nil end
        local content = file:read("*a")
        file:close()
        return content
    end,
}, { __index = _G })
assert(loadfile("sky_phone/config/init.lua", "t", environment))()
assert(loadfile("sky_phone/source/server/locales.lua", "t", environment))()
local count = 0
for _ in pairs(environment.Locales) do count = count + 1 end
assert(count == 2 and environment.Locales.en and environment.Locales.de,
    "Startup must load only English and the configured language")
local german, code = environment.SkyPhoneLocales.Resolve("de_DE")
assert(code == "de" and german.Nui and reads["config/locales/de.lua"] == 1)
assert(environment.SkyPhoneLocales.Resolve("de") == german, "Merged locales must be reused")
for alias, language in pairs({ zh = "cn", cs = "cz", jp = "ja", sr = "rs", sv = "se" }) do
    local locale, resolved = environment.SkyPhoneLocales.Resolve(alias)
    assert(resolved == language and locale.Nui and reads["config/locales/" .. language .. ".lua"] == 1)
end
environment.Config.Bridge.Locale = "fr"
handlers["sky_phone:configurator:serverUpdated"]()
assert(environment.Locales.fr and not environment.Locales.it,
    "Configurator language changes must load the new locale without loading unrelated languages")
local fallback, resolved = environment.SkyPhoneLocales.Resolve("xx")
assert(resolved == "en" and fallback == environment.Locales.en)
environment.SkyPhoneLocales.Resolve("xx")
assert(reads["config/locales/xx.lua"] == 1, "Missing languages must not be retried per request")
local bad = environment.SkyPhoneLocales.Resolve("../../private")
assert(bad == environment.Locales.en, "Invalid locale paths must fall back without file access")
local english_only = setmetatable({ Config = { Bridge = { Locale = "en" } },
    GetCurrentResourceName = environment.GetCurrentResourceName,
    AddEventHandler = function() end,
    LoadResourceFile = environment.LoadResourceFile,
}, { __index = _G })
assert(loadfile("sky_phone/config/init.lua", "t", english_only))()
assert(loadfile("sky_phone/source/server/locales.lua", "t", english_only))()
assert(next(english_only.Locales, "en") == nil, "English-only servers must not load another language")
print("PASS: selective server locales, cached fallback/merge, aliases, configurator updates and safe paths")
