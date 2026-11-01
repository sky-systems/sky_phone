local client_bridge = SkyPhoneCompatibilityClient
local RESOURCE_NAME = client_bridge.ResourceName
local debug_custom_app = client_bridge.Debug
local provider_registration_exports = {
    { resource = "lb-phone", export = "AddCustomApp" },
    { resource = "17mov_Phone", export = "AddApplication" },
    { resource = "high-phone", export = "addApplication" },
    { resource = "qs-smartphone", export = "addCustomApp" },
    { resource = "yseries", export = "AddCustomApp" },
}

local function report_provider_export_collisions()
    for index = 1, #provider_registration_exports do
        local provider_export = provider_registration_exports[index]
        local provider_count = 0
        TriggerEvent(
            ("__cfx_export_%s_%s"):format(provider_export.resource, provider_export.export),
            function()
                provider_count = provider_count + 1
            end
        )

        if provider_count > 1 then
            Bridge.Debug(
                "error",
                "[%s] Compatibility collision: %s:%s has %s providers. Stop the original phone resource; otherwise custom apps can register in the wrong phone.",
                RESOURCE_NAME,
                provider_export.resource,
                provider_export.export,
                provider_count
            )
        end
    end
end

CreateThread(function()
    report_provider_export_collisions()
    debug_custom_app("provider", "requesting provider snapshots and emitting compatibility ready signals")
    TriggerServerEvent("sky_phone:compat:high:server:requestSnapshot")
    TriggerEvent("17mov_Phone:Client:Ready")
    TriggerEvent("sky_phone:client:compatReady")
end)
