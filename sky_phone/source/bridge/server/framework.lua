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
