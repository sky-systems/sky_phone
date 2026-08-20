local provider_name = "rtx"
local resource_name = "rtx_housing"

Bridge.Housing.RegisterClientProvider(provider_name, {
    execute = function(action, data)
        if action ~= "toggle_lock" then
            return false, "capability_unavailable"
        end
        if GetResourceState(resource_name) ~= "started" then
            return false, "provider_unavailable"
        end
        if type(data) ~= "table" or type(data.providerId) ~= "string" then
            return false, "invalid_request"
        end

        local result = Bridge.Callbacks.Trigger("sky_phone:housing:rtx:execute", {
            action = action,
            providerId = data.providerId,
        })
        if result and result.success then
            return true
        end
        return false, result and result.error or "provider_rejected"
    end,
})
