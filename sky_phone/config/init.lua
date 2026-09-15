Config = Config or {}
Locales = Locales or {}
SkyPhoneLocales = SkyPhoneLocales or {}

local resolved_locales = {}
local locale_aliases = { zh = "cn", cs = "cz", sr = "rs", sv = "se" }

local function clone_locale(value)
    if type(value) ~= "table" then
        return value
    end

    local copied = {}
    for key, nested in pairs(value) do
        copied[key] = clone_locale(nested)
    end
    return copied
end

local function merge_locale(target, values)
    for key, value in pairs(values) do
        if type(value) == "table" and type(target[key]) == "table" then
            merge_locale(target[key], value)
        else
            target[key] = clone_locale(value)
        end
    end
end

function SkyPhoneLocales.Resolve(requested_locale)
    local normalized = type(requested_locale) == "string" and requested_locale:lower():gsub("_", "-") or "en"
    local base = normalized:match("^([^-]+)") or "en"
    base = locale_aliases[base] or base
    local locale_name = Locales[normalized] and normalized or (Locales[base] and base or "en")
    local selected = Locales[locale_name] or Locales.en or {}
    local english = Locales.en or {}

    if selected == english then
        return english, "en"
    end

    if not resolved_locales[locale_name] then
        resolved_locales[locale_name] = clone_locale(english)
        merge_locale(resolved_locales[locale_name], selected)
    end

    return resolved_locales[locale_name], locale_name
end

