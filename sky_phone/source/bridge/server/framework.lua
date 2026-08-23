local configured_framework = Config.Bridge.Framework

if configured_framework == "auto" then
    if GetResourceState("es_extended") == "started" then
        configured_framework = "esx"
    elseif GetResourceState("qbx_core") == "started" then
        configured_framework = "qbox"
    elseif GetResourceState("qb-core") == "started" then
        configured_framework = "qb"
    end
end

if configured_framework ~= "esx" and configured_framework ~= "qbox" and configured_framework ~= "qb" then
    error(("[sky_phone] Unsupported or unavailable framework '%s'."):format(tostring(configured_framework)))
end

Bridge.Framework.Name = configured_framework

function Bridge.Framework.GetName()
    return Bridge.Framework.Name
end

function Bridge.Framework.HasPermission(source, permission)
    if type(permission) ~= "string" or permission == "" then
        error("[sky_phone] Permission identifiers must be non-empty strings.")
    end

    local groups = Config.CommandPermissions[permission]
    if type(groups) ~= "table" or #groups == 0 then
        local message = "[sky_phone] Config.CommandPermissions.%s must contain at least one group."
        error(message:format(permission))
    end
    for index, group in ipairs(groups) do
        if type(group) ~= "string" or group == "" then
            local message = "[sky_phone] Config.CommandPermissions.%s[%s] must be a non-empty string."
            error(message:format(permission, index))
        end
    end

    return Bridge.Framework.HasAdminGroup(source, groups)
end
