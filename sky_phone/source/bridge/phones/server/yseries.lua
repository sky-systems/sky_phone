local server_bridge = SkyPhoneCompatibilityServer
local phone
local PROVIDER_NAME = "yseries"

local function reject_imei(export_name)
    Bridge.Debug(
        "warn",
        "[sky_phone] %s:%s rejected: phone IMEI must be a valid IMEI string.",
        PROVIDER_NAME,
        export_name
    )
    return false
end

---@param export_name string
---@param phone_imei unknown
---@return boolean
local function validate_phone_imei(export_name, phone_imei)
    if SkyPhoneImei.IsValid(phone_imei) then
        return true
    end

    return reject_imei(export_name)
end

---@param export_name string
---@param identifier unknown
---@return string|nil identifier
local function normalize_identifier(export_name, identifier)
    if not server_bridge.ValidateIdentifier(PROVIDER_NAME, export_name, identifier) then
        return nil
    end

    identifier = identifier:match("^%s*(.-)%s*$")
    if #identifier <= 80 then
        return identifier
    end

    Bridge.Debug(
        "warn",
        "[sky_phone] %s:%s rejected: identifier must not exceed 80 characters.",
        PROVIDER_NAME,
        export_name
    )
    return nil
end

---@param phone_number string|number
---@return number|nil player_source
local function get_player_source_by_phone_number(phone_number)
    if not server_bridge.ValidatePhoneNumber(
        PROVIDER_NAME,
        "GetPlayerSourceIdByPhoneNumber",
        phone_number
    ) then
        return nil
    end

    return phone.GetSourceFromNumber(phone_number)
end

---@param player_source number
---@return string|nil phone_number
local function get_phone_number_by_source(player_source)
    if not server_bridge.ValidatePlayerSource(
        PROVIDER_NAME,
        "GetPhoneNumberBySourceId",
        player_source
    ) then
        return nil
    end

    return phone.GetEquippedPhoneNumber(player_source)
end

---@param phone_imei string
---@return number|nil player_source
local function get_player_source_by_phone_imei(phone_imei)
    if not validate_phone_imei("GetPlayerSourceIdByPhoneImei", phone_imei) then
        return nil
    end

    local identity = SkyPhoneDeviceDirectory.GetOnlineByImei(phone_imei)
    return identity and identity.source or nil
end

---@param identifier string
---@return number|nil player_source
local function get_player_source_by_identifier(identifier)
    identifier = normalize_identifier("GetPlayerSourceIdByIdentifier", identifier)
    if not identifier then
        return nil
    end

    local identity = SkyPhoneDeviceDirectory.GetOnlineByIdentifier(identifier)
    return identity and identity.source or nil
end

---@param phone_imei string
---@return string|nil phone_number
local function get_phone_number_by_imei(phone_imei)
    if not validate_phone_imei("GetPhoneNumberByImei", phone_imei) then
        return nil
    end

    local identity = SkyPhoneDeviceDirectory.GetStoredDeviceByImei(phone_imei)
    return identity and identity.phoneNumber or nil
end

---@param phone_number string
---@return string|nil phone_imei
local function get_phone_imei_by_phone_number(phone_number)
    if not server_bridge.ValidatePhoneNumberString(
        PROVIDER_NAME,
        "GetPhoneImeiByPhoneNumber",
        phone_number
    ) then
        return nil
    end

    local identity = SkyPhoneDeviceDirectory.GetStoredDeviceByPhoneNumber(phone_number)
    return identity and identity.imei or nil
end

---@param player_source number
---@return string|nil phone_imei
local function get_phone_imei_by_source(player_source)
    if not server_bridge.ValidatePlayerSource(
        PROVIDER_NAME,
        "GetPhoneImeiBySourceId",
        player_source
    ) then
        return nil
    end

    local identity = SkyPhoneDeviceDirectory.GetOnlineBySource(player_source)
    return identity and identity.imei or nil
end

local function register_aliases(ready_phone)
    phone = ready_phone
    assert(
        type(SkyPhoneDeviceDirectory) == "table",
        "[sky_phone] YSeries identity compatibility requires the device directory."
    )
    assert(
        type(SkyPhoneDeviceDirectory.GetOnlineByImei) == "function"
            and type(SkyPhoneDeviceDirectory.GetOnlineByIdentifier) == "function"
            and type(SkyPhoneDeviceDirectory.GetOnlineBySource) == "function"
            and type(SkyPhoneDeviceDirectory.GetStoredDeviceByImei) == "function"
            and type(SkyPhoneDeviceDirectory.GetStoredDeviceByPhoneNumber) == "function",
        "[sky_phone] YSeries identity compatibility requires the complete device directory."
    )

    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "GetPlayerSourceIdByPhoneNumber",
        get_player_source_by_phone_number
    )
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "GetPhoneNumberBySourceId",
        get_phone_number_by_source
    )
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "GetPlayerSourceIdByPhoneImei",
        get_player_source_by_phone_imei
    )
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "GetPlayerSourceIdByIdentifier",
        get_player_source_by_identifier
    )
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "GetPhoneNumberByImei",
        get_phone_number_by_imei
    )
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "GetPhoneImeiByPhoneNumber",
        get_phone_imei_by_phone_number
    )
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "GetPhoneImeiBySourceId",
        get_phone_imei_by_source
    )
end

server_bridge.AfterPhoneReady(register_aliases)
