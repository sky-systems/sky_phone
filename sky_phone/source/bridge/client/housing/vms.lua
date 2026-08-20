local provider_name = "vms"
local resource_name = "vms_housing"

Bridge.Housing.RegisterClientProvider(provider_name, {
    execute = function()
        if GetResourceState(resource_name) ~= "started" then
            return false, "provider_unavailable"
        end
        return false, "capability_unavailable"
    end,
})
