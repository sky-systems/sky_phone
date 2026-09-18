local server_bridge = SkyPhoneCompatibilityServer
local phone
local PROVIDER_NAME = "qs-smartphone"

---@param player_source number
---@return string|nil phone_number
local function get_current_phone_number(player_source)
    if not server_bridge.ValidatePlayerSource(
        PROVIDER_NAME,
        "GetCurrentPhoneNumber",
        player_source
    ) then
        return nil
    end

    return phone.GetEquippedPhoneNumber(player_source)
end

local function is_player_in_call(player_source)
    if not server_bridge.ValidatePlayerSource(
        PROVIDER_NAME,
        "isPlayerInCall",
        player_source
    ) then
        return false
    end

    local calls = server_bridge.GetCalls(PROVIDER_NAME, "isPlayerInCall")
    return calls and calls.IsActiveForSource(player_source) or false
end

local function end_call_by_source(player_source)
    if not server_bridge.ValidatePlayerSource(
        PROVIDER_NAME,
        "endCallBySource",
        player_source
    ) then
        return
    end

    local calls = server_bridge.GetCalls(PROVIDER_NAME, "endCallBySource")
    if calls then
        calls.TerminateForSource(player_source)
    end
end

local function send_phone_notification(player_source, notification)
    if not server_bridge.ValidatePlayerSource(
        PROVIDER_NAME,
        "sendPhoneNotification",
        player_source
    ) then
        return
    end

    local notifications = server_bridge.GetNotifications(
        PROVIDER_NAME,
        "sendPhoneNotification"
    )
    if not notifications then
        return
    end
    local result, notification_error = notifications.Send(
        { kind = "source", value = player_source },
        notification
    )
    if not result then
        Bridge.Debug(
            "warn",
            "[sky_phone] %s:sendPhoneNotification rejected a notification: %s.",
            PROVIDER_NAME,
            tostring(notification_error)
        )
    end
end

local function register_aliases(ready_phone)
    phone = ready_phone
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "GetCurrentPhoneNumber",
        get_current_phone_number
    )
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "isPlayerInCall",
        is_player_in_call
    )
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "endCallBySource",
        end_call_by_source
    )
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "sendPhoneNotification",
        send_phone_notification
    )
end

server_bridge.AfterPhoneReady(register_aliases)
