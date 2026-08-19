local resource_name = "sn_properties"

Bridge.Housing.RegisterClientProvider("sn", {
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

        local result = Bridge.Callbacks.Trigger("sky_phone:housing:sn:execute", {
            action = action,
            propertyId = data.propertyId,
            providerId = data.providerId,
            identifier = data.identifier,
        })
        if type(result) == "table" and result.success then
            return true
        end
        return false, type(result) == "table" and result.error or "provider_rejected"
    end,
})
