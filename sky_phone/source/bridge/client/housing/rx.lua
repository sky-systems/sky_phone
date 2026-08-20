local provider_name = "rx"
local resource_name = "RxHousing"

Bridge.Housing.RegisterClientProvider(provider_name, {
    execute = function(action, data)
        if action ~= "grant_key" and action ~= "revoke_key" then
            return false, "capability_unavailable"
        end
        if GetResourceState(resource_name) ~= "started" then
            return false, "provider_unavailable"
        end
        if type(data) ~= "table" then
            return false, "invalid_request"
        end

        local result = Bridge.Callbacks.Trigger("sky_phone:housing:rx:execute", {
            action = action,
            providerId = data.providerId,
            target = data.target,
            identifier = data.identifier,
        })
        if result and result.success then
            return true
        end
        return false, result and result.error or "provider_rejected"
    end,
})
