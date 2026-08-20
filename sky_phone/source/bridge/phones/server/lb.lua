local server_bridge = SkyPhoneCompatibilityServer
local phone
local PROVIDER_NAME = "lb-phone"

local function register_aliases(ready_phone)
    phone = ready_phone
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "GetEquippedPhoneNumber",
        phone.GetEquippedPhoneNumber
    )
    SkyPhoneCompatibility.RegisterExportAlias(
        PROVIDER_NAME,
        "GetSourceFromNumber",
        phone.GetSourceFromNumber
    )
    SkyPhoneCompatibility.RegisterExportAlias(PROVIDER_NAME, "FormatNumber", phone.FormatNumber)
end

server_bridge.AfterPhoneReady(register_aliases)
