SkyPhoneCompatibilityServer = {}

local RESOURCE_NAME = GetCurrentResourceName()

local function reject_argument(provider_name, export_name, argument_name, expectation)
    Bridge.Debug(
        "warn",
        "[sky_phone] %s:%s rejected: %s must be %s.",
        provider_name,
        export_name,
        argument_name,
        expectation
    )
    return false
end

local function is_finite_integer(value)
    return type(value) == "number"
        and value == value
        and value > -math.huge
        and value < math.huge
        and value == math.floor(value)
end

local function require_phone_core()
    local phone = SkyPhone
    assert(
        type(phone) == "table",
        "[sky_phone] Phone compatibility bridge initialized before the phone core."
    )
    assert(
        type(phone.GetEquippedPhoneNumber) == "function",
        "[sky_phone] Phone compatibility bridge requires GetEquippedPhoneNumber."
    )
    assert(
        type(phone.GetSourceFromNumber) == "function",
        "[sky_phone] Phone compatibility bridge requires GetSourceFromNumber."
    )
    assert(
        type(phone.FormatNumber) == "function",
        "[sky_phone] Phone compatibility bridge requires FormatNumber."
    )

    return phone
end

SkyPhoneCompatibilityServer.ResourceName = RESOURCE_NAME
SkyPhoneCompatibilityServer.Phone = nil

function SkyPhoneCompatibilityServer.AfterPhoneReady(callback)
    assert(type(callback) == "function", "Phone compatibility callback must be a function")

    local function run_callback()
        local phone = require_phone_core()
        SkyPhoneCompatibilityServer.Phone = phone
        callback(phone)
    end

    Bridge.Database.AfterMigration("sky_phone", run_callback)
end

function SkyPhoneCompatibilityServer.GetCalls(provider_name, export_name)
    local calls = SkyPhoneCalls
    if type(calls) == "table"
        and type(calls.GetForSource) == "function"
        and type(calls.GetById) == "function"
        and type(calls.IsActiveForSource) == "function"
        and type(calls.EndForSource) == "function"
        and type(calls.TerminateForSource) == "function"
    then
        return calls
    end

    Bridge.Debug(
        "error",
        "[sky_phone] %s:%s unavailable: the call service is not ready.",
        provider_name,
        export_name
    )
    return nil
end

function SkyPhoneCompatibilityServer.GetNotifications(provider_name, export_name)
    local notifications = SkyPhoneNotifications
    if type(notifications) == "table" and type(notifications.Send) == "function" then
        return notifications
    end

    Bridge.Debug(
        "error",
        "[sky_phone] %s:%s unavailable: the notification service is not ready.",
        provider_name,
        export_name
    )
    return nil
end

function SkyPhoneCompatibilityServer.ValidatePlayerSource(
    provider_name,
    export_name,
    player_source
)
    if is_finite_integer(player_source) and player_source > 0 then
        return true
    end

    return reject_argument(
        provider_name,
        export_name,
        "player source",
        "a positive integer"
    )
end

function SkyPhoneCompatibilityServer.ValidateIdentifier(provider_name, export_name, identifier)
    if type(identifier) == "string" and identifier:match("%S") then
        return true
    end

    return reject_argument(
        provider_name,
        export_name,
        "identifier",
        "a non-empty string"
    )
end

function SkyPhoneCompatibilityServer.ValidatePhoneNumber(provider_name, export_name, phone_number)
    if type(phone_number) == "string" and phone_number:match("%S") then
        return true
    end
    if is_finite_integer(phone_number) and phone_number >= 0 then
        return true
    end

    return reject_argument(
        provider_name,
        export_name,
        "phone number",
        "a non-empty string or non-negative integer"
    )
end

function SkyPhoneCompatibilityServer.ValidatePhoneNumberString(
    provider_name,
    export_name,
    phone_number
)
    if type(phone_number) == "string" and phone_number:match("%S") then
        return true
    end

    return reject_argument(
        provider_name,
        export_name,
        "phone number",
        "a non-empty string"
    )
end
