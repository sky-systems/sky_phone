-- Provider contracts copied from Sky Base 43cec3f6080a3e23f4e31f3341afc2bb22355dca.
-- Standalone Phone bridge: no Sky runtime dependency.

Bridge.Notifications = {}
local providers = {}

do
    providers["zenit_hud"] = function(title, message, type, time)
        exports["zenit_hud"]:showNotify(title, message, type, time)
    end
end

do
    local types = { warn = "info", warning = "info", inform = "info" }

    providers["codem-supreme-notification"] = function(title, message, type, time)
        title, message = title or "", message or ""
        type = types[type] or type or "info"
        local text = message
        if title ~= "" then
            text = title .. (message ~= "" and ": " .. message or "")
        end
        exports["codem-supreme-notification"]:Notify(type, text, time or 5000)
    end
end

do
    -- Explicit event exception for CodeM mNotification; its public API documents no export.
    local types = { warn = "info", warning = "info", inform = "info", primary = "info" }

    providers["codem-notification"] = function(title, message, type, time)
        type = types[type] or type or "info"
        TriggerEvent("codem-notification:Create", message or "", type, title or "", time or 5000)
    end
end

do
    local types = { success = "check", warn = "info", warning = "info", inform = "info" }

    providers["Venice-Notification"] = function(title, message, type, time)
        title, message = title or "", message or ""
        type = types[type] or type or "info"
        local text = message
        if title ~= "" then
            text = title .. (message ~= "" and ": " .. message or "")
        end
        exports["Venice-Notification"]:Notify(text, time or 5000, type)
    end
end

do
    local types = { warn = "info", warning = "info", inform = "info" }

    providers["17mov_Hud"] = function(title, message, type, time)
        title, message = title or "", message or ""
        type = types[type] or type or "info"
        exports["17mov_Hud"]:ShowNotification(message, type, title, time or 5000)
    end
end

do
    providers["prims_hud"] = function(title, message, type, time)
        title, message = title or "", message or ""
        if type == "warn" then type = "warning" end
        if type == "inform" then type = "info" end
        type = type or "info"
        local text = message
        if title ~= "" then
            text = title .. (message ~= "" and ": " .. message or "")
        end
        exports.prims_hud:prims_Notification_show({ msg = text, type = type, time = time or 5000 })
    end
end

do
    providers["aty_uikitv2"] = function(title, message, type, time)
        title, message = title or "", message or ""
        if type == "warn" then type = "warning" end
        if type == "inform" then type = "info" end
        type = type or "info"
        exports["aty_uikitv2"]:AddNotify({ title = title, message = message, type = type, duration = time or 5000 })
    end
end

do
    local types = { warn = "info", warning = "info", inform = "info" }

    providers["aty_ui"] = function(title, message, type, time)
        title, message = title or "", message or ""
        type = types[type] or type or "info"
        exports["aty_ui"]:GetAtyUI().sendNotify(title, message, type, time or 5000)
    end
end

do
    local types = { warn = "info", warning = "info", inform = "info" }

    providers["risk-notify"] = function(title, message, type, time)
        title, message = title or "", message or ""
        type = types[type] or type or "info"
        exports["risk-notify"]:Notify({ title = title, message = message, type = type, duration = time or 5000 })
    end
end

do
    providers["prism_uipack"] = function(title, message, type, time)
        title, message = title or "", message or ""
        if type == "warn" then type = "warning" end
        if type == "inform" then type = "info" end
        type = type or "info"
        exports["prism_uipack"]:Notify({ title = title, description = message, type = type, duration = time or 5000 })
    end
end

do
    providers["core_notify"] = function(title, message, type, time)
        title, message = title or "", message or ""
        if type == "warn" then type = "warning" end
        if type == "inform" then type = "info" end
        type = type or "info"
        local text = message
        if title ~= "" then
            text = title .. (message ~= "" and ": " .. message or "")
        end
        exports["core_notify"]:ShowNotification({ text = text, type = type, duration = time or 5000, flash = true })
    end
end

do
    -- Provider-specific defaults; Sky's notification signature has no author or sound argument.
    local author = ""
    local sound = true
    local icons = {
        info = "fa-solid fa-circle-info",
        success = "fa-solid fa-circle-check",
        error = "fa-solid fa-circle-xmark",
        warning = "fa-solid fa-triangle-exclamation",
    }

    providers["cp_notify"] = function(title, message, type, time)
        if type == "warn" then type = "warning" end
        if type == "inform" then type = "info" end
        type = type or "info"
        exports["cp_notify"]:Notify(title or "", message or "", type, author, icons[type] or icons.info, time or 5000, sound)
    end
end

do
    providers["rtx_notify"] = function(title, message, type, time)
        title, message = title or "", message or ""
        if type == "warn" then type = "warning" end
        if type == "inform" then type = "info" end
        type = type or "info"
        exports["rtx_notify"]:Notify(title, message, time or 5000, type)
    end
end

do
    -- VMS accepts explicit colors/icons instead of a severity argument.
    local styles = {
        info = { color = "#3b82f6", icon = "fa-solid fa-circle-info" },
        success = { color = "#22c55e", icon = "fa-solid fa-circle-check" },
        error = { color = "#ef4444", icon = "fa-solid fa-circle-xmark" },
        warning = { color = "#f59e0b", icon = "fa-solid fa-triangle-exclamation" },
    }

    providers["vms_notifyv2"] = function(title, message, type, time)
        title, message = title or "", message or ""
        if type == "warn" then type = "warning" end
        if type == "inform" then type = "info" end
        type = type or "info"
        local style = styles[type] or styles.info
        exports["vms_notifyv2"]:Notification({
            title = title,
            description = message,
            time = time or 5000,
            color = style.color,
            icon = style.icon,
        })
    end
end

do
    providers["brutal_notify"] = function(title, message, type, time)
        title, message = title or "", message or ""
        if type == "warn" then type = "warning" end
        if type == "inform" then type = "info" end
        type = type or "info"
        exports["brutal_notify"]:SendAlert(title, message, time or 5000, type, true)
    end
end

do
    providers["frkn-uikit"] = function(title, message, type, time)
        title, message = title or "", message or ""
        if type == "warn" then type = "warning" end
        if type == "inform" then type = "info" end
        type = type or "info"
        local text = message
        if title ~= "" then
            text = title .. (message ~= "" and ": " .. message or "")
        end
        exports["frkn-uikit"]:Notify(type, time or 5000, text)
    end
end

do
    local types = { warning = "warn", inform = "info" }

    providers["RxNotify"] = function(title, message, type, time)
        title, message = title or "", message or ""
        type = types[type] or type or "info"
        exports["RxNotify"]:Notify(title, message, type, time or 5000)
    end
end

do
    local types = { info = "primary", inform = "primary", warning = "primary", warn = "primary" }

    providers["cs_hud"] = function(title, message, type, time)
        title, message = title or "", message or ""
        type = types[type] or type or "primary"
        exports["cs_hud"]:Alert(title, message, time or 5000, type)
    end
end

do
    providers["lation_ui"] = function(title, message, type, time)
        if type == "warn" then type = "warning" end
        exports.lation_ui:notify({
            title = title or "",
            message = message or "",
            type = type or "info",
            duration = time or 5000,
        })
    end
end

do
    -- AddNotify accepts an icon instead of a notification type.
    local icons = {
        info = "fa-solid fa-circle-info",
        inform = "fa-solid fa-circle-info",
        success = "fa-solid fa-circle-check",
        error = "fa-solid fa-circle-xmark",
        warning = "fa-solid fa-triangle-exclamation",
        warn = "fa-solid fa-triangle-exclamation",
    }

    providers["qs-interface"] = function(title, message, type, time)
        exports["qs-interface"]:AddNotify(message or "", title or "", time or 5000, icons[type] or icons.info)
    end
end

do
    providers["okokNotify"] = function(title, message, type, time)
        if type == "warn" then type = "warning" end
        exports["okokNotify"]:Alert(title or "", message or "", time or 5000, type or "info")
    end
end

do
    providers["wasabi_uikit"] = function(title, message, type, time)
        if type == "warn" then type = "warning" end
        exports.wasabi_uikit:Notification(title or "", message or "", type or "info", time or 5000)
    end
end

do
    providers["wasabi_notify"] = function(title, message, type, time)
        if type == "warn" then type = "warning" end
        exports.wasabi_notify:notify(title or "", message or "", time or 5000, type or "info")
    end
end

do
    -- Mythic's documented styles are inform, success and error.
    local notificationTypes = { info = "inform", warning = "inform", warn = "inform" }

    providers["mythic_notify"] = function(title, message, type, time)
        local text = message or ""
        if title and title ~= "" then
            text = title .. (text ~= "" and (": " .. text) or "")
        end
        exports["mythic_notify"]:DoCustomHudText(notificationTypes[type] or type or "inform", text, time or 5000)
    end
end

do
    providers["esx_notify"] = function(title, message, type, time)
        if type == "warn" then type = "warning" end
        -- esx_notify takes duration before message (see the provider's Notify.lua).
        exports["esx_notify"]:Notify(type or "info", time or 5000, message or "", title or "")
    end
end

do
    providers["msk_core"] = function(title, message, type, time)
        title, message = title or "", message or ""
        if type == "warn" then type = "warning" end
        if type == "inform" then type = "info" end
        type = type or "info"
        exports.msk_core:Notification({ title = title, message = message, type = type, duration = time or 5000 })
    end
end

do
    local notificationTypes = { info = "inform", warn = "warning" }

    providers["qbox"] = function(title, message, type, time)
        exports.qbx_core:Notify({
            text = title or "",
            caption = message or "",
        }, notificationTypes[type] or type or "inform", time or 5000)
    end
end

do
    local notificationTypes = { info = "primary", inform = "primary", warn = "warning" }

    providers["qb"] = function(title, message, type, time)
        local framework = exports["qb-core"]:GetCoreObject()
        framework.Functions.Notify({
            text = title or "",
            caption = message or "",
        }, notificationTypes[type] or type or "primary", time or 5000)
    end
end

do
    providers["esx"] = function(title, message, type, time)
        if type == "warn" then type = "warning" end
        local framework = exports["es_extended"]:getSharedObject()
        framework.ShowNotification(message or "", type or "info", time or 5000, title or "")
    end
end

do
    local notificationTypes = { info = "inform", warn = "warning" }

    providers["ox_lib"] = function(title, message, type, time)
        exports.ox_lib:notify({
            title = title or "",
            description = message or "",
            type = notificationTypes[type] or type or "inform",
            duration = time or 5000,
        })
    end
end

providers.hex = function(title, message, severity, duration, resource)
    exports[resource]:Notify(title, message, severity, duration)
end

providers.ZSX_UIV2 = function(title, message, severity, duration)
    local icons = { info = "fas fa-info-circle", success = "fas fa-check-circle",
        error = "fas fa-times-circle", warning = "fas fa-exclamation-triangle" }
    exports["ZSX_UIV2"]:Notification(title, message, icons[severity] or icons.info, duration)
end

local priority = {
    { "zenit_hud", "zenit_hud" },
    { "hex_4_hud", "hex" },
    { "hex_2_hud", "hex" },
    { "hex_1_hud", "hex" },
    { "hex_final_hud", "hex" },
    { "hex_finalhud_v2", "hex" },
    { "hex_future_hud", "hex" },
    { "hex_genesis_hud", "hex" },
    { "hex_hud_prem", "hex" },
    { "codem-supreme-notification", "codem-supreme-notification" },
    { "codem-notification", "codem-notification" },
    { "Venice-Notification", "Venice-Notification" },
    { "17mov_Hud", "17mov_Hud" },
    { "ZSX_UIV2", "ZSX_UIV2" },
    { "prims_hud", "prims_hud" },
    { "aty_uikitv2", "aty_uikitv2" },
    { "aty_ui", "aty_ui" },
    { "risk-notify", "risk-notify" },
    { "prism_uipack", "prism_uipack" },
    { "core_notify", "core_notify" },
    { "cp_notify", "cp_notify" },
    { "rtx_notify", "rtx_notify" },
    { "vms_notifyv2", "vms_notifyv2" },
    { "brutal_notify", "brutal_notify" },
    { "frkn-uikit", "frkn-uikit" },
    { "RxNotify", "RxNotify" },
    { "cs_hud", "cs_hud" },
    { "lation_ui", "lation_ui" },
    { "qs-interface", "qs-interface" },
    { "okokNotify", "okokNotify" },
    { "wasabi_uikit", "wasabi_uikit" },
    { "wasabi_notify", "wasabi_notify" },
    { "mythic_notify", "mythic_notify" },
    { "esx_notify", "esx_notify" },
    { "msk_core", "msk_core" },
    { "qbx_core", "qbox" },
    { "qb-core", "qb" },
    { "es_extended", "esx" },
    { "ox_lib", "ox_lib" },

}

function Bridge.Notifications.Show(title, message, severity, duration)
    title, message, severity, duration = title or "", message or "", severity or "info", duration or 5000
    if severity == "warn" then severity = "warning" end
    for _, candidate in ipairs(priority) do
        if GetResourceState(candidate[1]) == "started" then
            providers[candidate[2]](title, message, severity, duration, candidate[1])
            return
        end
    end
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(title .. "~n~" .. message)
    EndTextCommandThefeedPostTicker(false, false)
end
