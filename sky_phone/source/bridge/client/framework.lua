local framework_name
local esx
local qb

local function resolve_framework()
    local configured = Config.Bridge.Framework
    if configured ~= "auto" then
        return configured
    end

    if GetResourceState("es_extended") == "started" then
        return "esx"
    end
    if GetResourceState("qbx_core") == "started" then
        return "qbox"
    end
    if GetResourceState("qb-core") == "started" then
        return "qb"
    end

    return nil
end

framework_name = resolve_framework()
if not framework_name then
    error("[sky_phone] No supported framework is running. Configure Config.Bridge.Framework.")
end

function Bridge.Framework.GetName()
    return framework_name
end

function Bridge.Framework.Notify(title, message, notification_type, duration)
    if framework_name == "esx" then
        esx = esx or exports["es_extended"]:getSharedObject()
        esx.ShowNotification(message, notification_type, duration, title)
        return
    end

    if framework_name == "qbox" then
        exports.qbx_core:Notify(message, notification_type, duration, title)
        return
    end

    if framework_name == "qb" then
        qb = qb or exports["qb-core"]:GetCoreObject()
        qb.Functions.Notify(message, notification_type, duration)
        return
    end

    Bridge.Debug("error", "[sky_phone] Notification requested for unsupported framework '%s'.", tostring(framework_name))
end

function Bridge.Framework.ShowHelpNotification(message, key)
    local control = key == "E" and "~INPUT_CONTEXT~" or ("[%s]"):format(tostring(key or "E"))
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(("%s  %s"):format(control, tostring(message or "")))
    EndTextCommandDisplayHelp(0, false, false, -1)
end
