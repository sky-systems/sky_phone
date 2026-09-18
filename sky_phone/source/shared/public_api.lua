SkyPhonePublicApi = {}

local API_VERSION = "1.0.0"

local function copy_value(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, nested_value in pairs(value) do
        copy[key] = copy_value(nested_value)
    end
    return copy
end

local function get_api_version()
    return API_VERSION
end

local function normalize_phone_number(phone_number)
    local normalized = SkyPhoneSimNumber.Normalize(
        phone_number,
        Config.Sim.NumberLength,
        Config.Sim.NumberPrefix
    )
    if not normalized then
        return nil, "invalid_phone_number"
    end
    return normalized
end

local function format_phone_number(phone_number)
    local normalized, normalize_error = normalize_phone_number(phone_number)
    if not normalized then
        return nil, normalize_error
    end
    return SkyPhoneSimNumber.Format(
        normalized,
        Config.Sim.NumberGroups,
        Config.Sim.NumberLength,
        Config.Sim.NumberPrefix
    )
end

SkyPhonePublicApi.Copy = copy_value
SkyPhonePublicApi.Version = API_VERSION

exports("GetApiVersion", get_api_version)
exports("NormalizePhoneNumber", normalize_phone_number)
exports("FormatPhoneNumber", format_phone_number)
exports("IsValidImei", SkyPhoneImei.IsValid)
