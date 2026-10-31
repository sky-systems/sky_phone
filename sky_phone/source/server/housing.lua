SkyPhoneHousing = {}

function SkyPhoneHousing.ResolveShare(source, property_id)
    if SkyPhoneAppDatabase and not SkyPhoneAppDatabase.Enabled("house") then
        return nil
    end
    local overview = Bridge.Housing.GetOverview(source)
    if not overview or type(overview.properties) ~= "table" then
        return nil
    end
    for _, property in ipairs(overview.properties) do
        if property.id == property_id then
            return {
                title = property.name,
                subtitle = property.access,
                copyText = property.name,
                link = "skyphone://house/property/" .. property.id,
                meta = { access = property.access, entrance = property.entrance },
            }
        end
    end
    return nil
end

Bridge.Callbacks.Register("sky_phone:housing:overview", function(source)
    if not SkyPhone.AllowOperation(
        source,
        "housing_overview",
        Config.Housing.OverviewRequestsPerMinute,
        60
    ) then
        return { success = false, error = "rate_limited" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end
    local overview, error_code = Bridge.Housing.GetOverview(source)
    if not overview then
        return { success = false, error = error_code or "request_failed" }
    end
    return { success = true, data = overview }
end)

Bridge.Callbacks.Register("sky_phone:housing:prepare", function(source, data)
    if not SkyPhone.AllowOperation(source, "housing_action", Config.Housing.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end
    if type(data) ~= "table" or type(data.action) ~= "string" then
        return { success = false, error = "invalid_request" }
    end
    local allowed_actions = {
        grant_key = true,
        key_candidates = true,
        open_cctv = true,
        revoke_key = true,
        set_waypoint = true,
        toggle_lock = true,
    }
    if not allowed_actions[data.action] then
        return { success = false, error = "invalid_action" }
    end
    local prepared, error_code = Bridge.Housing.Prepare(source, data.action, data)
    if not prepared then
        return { success = false, error = error_code or "action_failed" }
    end
    return { success = true, data = prepared }
end)
