local server_bridge = SkyPhoneCompatibilityServer
local phone
local PROVIDER_NAME = "17mov_Phone"

---@param player_source number
---@return string|nil phone_number
local function get_number_from_player(player_source)
    if not server_bridge.ValidatePlayerSource(
        PROVIDER_NAME,
        "GetNumberFromPlayer",
        player_source
    ) then
        return nil
    end

    return phone.GetEquippedPhoneNumber(player_source)
end

---@param identifier string
---@return string|nil phone_number
local function get_number_from_identifier(identifier)
    if not server_bridge.ValidateIdentifier(
        PROVIDER_NAME,
        "GetNumberFromIdentifier",
        identifier
    ) then
        return nil
    end

    return phone.GetEquippedPhoneNumber(identifier)
end

---@param phone_number string|number
---@return number|nil player_source
local function get_player_source_from_active_number(phone_number)
    if not server_bridge.ValidatePhoneNumber(
        PROVIDER_NAME,
        "GetPlayerSrcFromActiveNumber",
        phone_number
    ) then
        return nil
    end

    return phone.GetSourceFromNumber(phone_number)
end

local function is_finite_source(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
        and value > 0
        and value == math.floor(value)
end

local function is_uuid(value)
    return type(value) == "string"
        and value:match(
            "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
        ) ~= nil
end

local function get_call_source_from_number(export_name, phone_number)
    if not server_bridge.ValidatePhoneNumber(PROVIDER_NAME, export_name, phone_number) then
        return nil
    end
    return phone.GetSourceFromNumber(phone_number)
end

local function build_phone_call(call)
    if call == nil then
        return nil
    end

    local caller = type(call) == "table" and call.caller or nil
    local callee = type(call) == "table" and call.callee or nil
    local valid = type(call) == "table"
        and is_uuid(call.id)
        and type(caller) == "table"
        and is_finite_source(caller.source)
        and type(caller.number) == "string"
        and type(callee) == "table"
        and is_finite_source(callee.source)
        and type(callee.number) == "string"
        and type(call.startedAt) == "number"
        and call.startedAt == call.startedAt
        and call.startedAt ~= math.huge
        and call.startedAt ~= -math.huge
    if not valid then
        Bridge.Debug(
            "error",
            "[sky_phone] Could not project an invalid call snapshot for 17Movement."
        )
        return nil
    end

    return {
        callId = call.id,
        fromId = caller.source,
        fromNumber = caller.number,
        toId = callee.source,
        toNumber = callee.number,
        callTime = call.startedAt,
        inCall = true,
        type = call.video and "video" or "phone",
        isNumberHidden = call.anonymous == true,
        isCompanyCall = call.companyId ~= nil,
    }
end

local function end_call_by_source(player_source)
    if not server_bridge.ValidatePlayerSource(
        PROVIDER_NAME,
        "PhoneApp_EndCallBySrc",
        player_source
    ) then
        return false
    end
    local calls = server_bridge.GetCalls(PROVIDER_NAME, "PhoneApp_EndCallBySrc")
    return calls and calls.TerminateForSource(player_source) == true or false
end

local function end_call_by_number(phone_number)
    local player_source = get_call_source_from_number(
        "PhoneApp_EndCallByNumber",
        phone_number
    )
    if not player_source then
        return false
    end
    local calls = server_bridge.GetCalls(PROVIDER_NAME, "PhoneApp_EndCallByNumber")
    return calls and calls.TerminateForSource(player_source) == true or false
end

local function is_in_call_by_source(player_source)
    if not server_bridge.ValidatePlayerSource(
        PROVIDER_NAME,
        "PhoneApp_IsInCallBySrc",
        player_source
    ) then
        return false
    end
    local calls = server_bridge.GetCalls(PROVIDER_NAME, "PhoneApp_IsInCallBySrc")
    return calls and calls.IsActiveForSource(player_source) or false
end

local function is_in_call_by_number(phone_number)
    local player_source = get_call_source_from_number(
        "PhoneApp_IsInCallByNumber",
        phone_number
    )
    if not player_source then
        return false
    end
    local calls = server_bridge.GetCalls(PROVIDER_NAME, "PhoneApp_IsInCallByNumber")
    return calls and calls.IsActiveForSource(player_source) or false
end

local function get_call_by_source(export_name, player_source)
    if not server_bridge.ValidatePlayerSource(PROVIDER_NAME, export_name, player_source) then
        return nil
    end
    local calls = server_bridge.GetCalls(PROVIDER_NAME, export_name)
    return calls and calls.GetForSource(player_source) or nil
end

local function get_call_by_number(export_name, phone_number)
    local player_source = get_call_source_from_number(export_name, phone_number)
    if not player_source then
        return nil
    end
    local calls = server_bridge.GetCalls(PROVIDER_NAME, export_name)
    return calls and calls.GetForSource(player_source) or nil
end

local function get_call_id_by_source(player_source)
    local call = get_call_by_source("PhoneApp_GetCallIdFromSrc", player_source)
    return type(call) == "table" and is_uuid(call.id) and call.id or nil
end

local function get_call_id_by_number(phone_number)
    local call = get_call_by_number("PhoneApp_GetCallIdFromNumber", phone_number)
    return type(call) == "table" and is_uuid(call.id) and call.id or nil
end

local function get_call_data_by_source(player_source)
    return build_phone_call(get_call_by_source("PhoneApp_GetCallDataFromSrc", player_source))
end

local function get_call_data_by_number(phone_number)
    return build_phone_call(get_call_by_number("PhoneApp_GetCallDataFromNumber", phone_number))
end

local function get_call_data_by_id(call_id)
    if not is_uuid(call_id) then
        Bridge.Debug(
            "warn",
            "[sky_phone] 17mov_Phone:PhoneApp_GetCallDataFromCallId rejected: call ID must be a UUID."
        )
        return nil
    end
    local calls = server_bridge.GetCalls(PROVIDER_NAME, "PhoneApp_GetCallDataFromCallId")
    return build_phone_call(calls and calls.GetById(call_id) or nil)
end

local function send_notification(export_name, target, notification)
    local mapped, map_error = SkyPhoneCompatibility.Map17MovNotification(notification)
    if not mapped then
        Bridge.Debug(
            "warn",
            "[sky_phone] %s:%s rejected an unsupported notification: %s.",
            PROVIDER_NAME,
            export_name,
            tostring(map_error)
        )
        return
    end

    local notifications = server_bridge.GetNotifications(PROVIDER_NAME, export_name)
    if not notifications then
        return
    end
    local result, notification_error = notifications.Send(target, mapped)
    if not result then
        Bridge.Debug(
            "warn",
            "[sky_phone] %s:%s rejected a notification: %s.",
            PROVIDER_NAME,
            export_name,
            tostring(notification_error)
        )
    end
end

local function send_notification_to_source(player_source, notification)
    if not server_bridge.ValidatePlayerSource(
        PROVIDER_NAME,
        "SendNotificationToSrc",
        player_source
    ) then
        return
    end
    send_notification(
        "SendNotificationToSrc",
        { kind = "source", value = player_source },
        notification
    )
end

local function send_notification_to_number(phone_number, notification)
    if not server_bridge.ValidatePhoneNumberString(
        PROVIDER_NAME,
        "SendNotificationToNumber",
        phone_number
    ) then
        return
    end
    send_notification(
        "SendNotificationToNumber",
        { kind = "number", value = phone_number },
        notification
    )
end

local function send_notification_to_everyone(notification)
    send_notification(
        "SendNotificationToEveryone",
        { kind = "all" },
        notification
    )
end

local function register_aliases(ready_phone)
    phone = ready_phone
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "GetNumberFromPlayer",
        get_number_from_player
    )
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "GetNumberFromIdentifier",
        get_number_from_identifier
    )
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "GetPlayerSrcFromActiveNumber",
        get_player_source_from_active_number
    )
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "PhoneApp_EndCallBySrc",
        end_call_by_source
    )
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "PhoneApp_EndCallByNumber",
        end_call_by_number
    )
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "PhoneApp_IsInCallBySrc",
        is_in_call_by_source
    )
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "PhoneApp_IsInCallByNumber",
        is_in_call_by_number
    )
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "PhoneApp_GetCallIdFromSrc",
        get_call_id_by_source
    )
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "PhoneApp_GetCallIdFromNumber",
        get_call_id_by_number
    )
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "PhoneApp_GetCallDataFromSrc",
        get_call_data_by_source
    )
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "PhoneApp_GetCallDataFromNumber",
        get_call_data_by_number
    )
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "PhoneApp_GetCallDataFromCallId",
        get_call_data_by_id
    )
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "SendNotificationToSrc",
        send_notification_to_source
    )
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "SendNotificationToNumber",
        send_notification_to_number
    )
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "SendNotificationToEveryone",
        send_notification_to_everyone
    )
end

server_bridge.AfterPhoneReady(register_aliases)
