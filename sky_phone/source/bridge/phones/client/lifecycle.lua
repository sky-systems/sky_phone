local client_bridge = SkyPhoneCompatibilityClient
local RESOURCE_NAME = client_bridge.ResourceName
local debug_custom_app = client_bridge.Debug
local provider_resources = {
    "lb-phone",
    "17mov_Phone",
    "high-phone",
    "qs-smartphone",
    "yseries",
}
local provider_registration_exports = {
    { resource = "lb-phone", export = "AddCustomApp" },
    { resource = "17mov_Phone", export = "AddApplication" },
    { resource = "high-phone", export = "addApplication" },
    { resource = "qs-smartphone", export = "addCustomApp" },
    { resource = "yseries", export = "AddCustomApp" },
}

local function emit_provider_stop_signals(reason)
    for index = 1, #provider_resources do
        local provider_resource = provider_resources[index]
        debug_custom_app(
            "provider",
            "emitting stop compatibility signals for %s reason=%s",
            provider_resource,
            reason
        )
        TriggerEvent("onClientResourceStop", provider_resource)
        TriggerEvent("onResourceStop", provider_resource)
    end
end

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

AddEventHandler("onResourceStop", function(resource_name)
    if resource_name ~= RESOURCE_NAME then
        return
    end

    emit_provider_stop_signals("resource_stop")
end)

CreateThread(function()
    report_provider_export_collisions()
    emit_provider_stop_signals("startup_reset")
    debug_custom_app("provider", "requesting provider snapshots and emitting compatibility ready signals")
    TriggerServerEvent("sky_phone:compat:high:server:requestSnapshot")
    TriggerEvent("17mov_Phone:Client:Ready")

    for index = 1, #provider_resources do
        debug_custom_app(
            "provider",
            "emitting onResourceStart compatibility signal for %s (state=%s)",
            provider_resources[index],
            tostring(GetResourceState(provider_resources[index]))
        )
        TriggerEvent("onResourceStart", provider_resources[index])
    end
end)
