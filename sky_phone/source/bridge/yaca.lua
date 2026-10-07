Bridge.Yaca = {}
local warned_about_legacy_yaca_status = false

-- Yaca added these exports over time. Only a genuinely absent export is optional;
-- a present export that fails must keep its error visible to the caller.
function Bridge.Yaca.GetOptionalExport(export_name)
    local success, handler = pcall(function()
        return exports["yaca-voice"][export_name]
    end)
    if success then return handler end
    local normalized = tostring(handler):lower()
    if normalized:find("no such export " .. export_name:lower() .. " in resource yaca-voice", 1, true) then
        return nil
    end
    error(handler, 0)
end

function Bridge.Yaca.IsEnabled()
    if GetResourceState("yaca-voice") ~= "started" then return false end
    local success, enabled = pcall(function()
        local status_export = Bridge.Yaca.GetOptionalExport("isEnabled")
        if status_export then return status_export(exports["yaca-voice"]) end
        if not warned_about_legacy_yaca_status then
            warned_about_legacy_yaca_status = true
            Bridge.Debug(
                "warn",
                "[sky_phone] Yaca does not expose isEnabled; using legacy compatibility because yaca-voice is started.",
                { always = true }
            )
        end
        return true
    end)
    if success then
        -- Yaca forwards GetConvarBool, which can cross the export as a numeric 1/0.
        if enabled == true or enabled == 1 then return true end
        if enabled == false or enabled == 0 then return false end
        Bridge.Debug(
            "error",
            "[sky_phone] Yaca returned an invalid enabled state: %s (%s).",
            tostring(enabled), type(enabled), { always = true }
        )
        return false
    end
    Bridge.Debug(
        "error", "[sky_phone] Yaca could not report its availability: %s",
        tostring(enabled), { always = true }
    )
    return false
end
