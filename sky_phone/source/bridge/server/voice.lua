local call_provider_resources = {
    yaca = "yaca-voice",
    pma = "pma-voice",
    saltychat = "saltychat",
}
local call_provider_aliases = {
    ["yaca-voice"] = "yaca",
    ["pma-voice"] = "pma",
    salty = "saltychat",
}
local radio_provider_resources = {
    yaca = "yaca-voice",
    pma = "pma-voice",
    saltychat = "saltychat",
}
local radio_provider_aliases = {
    ["yaca-voice"] = "yaca",
    ["pma-voice"] = "pma",
    salty = "saltychat",
}

local function yaca_is_enabled()
    if GetResourceState("yaca-voice") ~= "started" then
        return false
    end

    local success, enabled = pcall(function()
        return exports["yaca-voice"]:isEnabled()
    end)
    if not success then
        Bridge.Debug(
            "error",
            "[sky_phone] Yaca could not report its availability: %s",
            tostring(enabled),
            { always = true }
        )
        return false
    end
    return enabled == true
end

local function resolve_call_provider()
    local configured = tostring(Config.Calls.VoiceProvider or "")
    local selected = call_provider_aliases[configured] or configured
    local resource_name = call_provider_resources[selected]
    if resource_name and GetResourceState(resource_name) == "started" then
        return selected
    end
    return nil
end

local function resolve_radio_provider()
    local configured = tostring(Config.Radio.VoiceProvider or "")
    if configured ~= "auto" then
        local selected = radio_provider_aliases[configured] or configured
        local resource_name = radio_provider_resources[selected]
        if resource_name and GetResourceState(resource_name) == "started" then
            return selected
        end
        return nil
    end

    for _, candidate in ipairs({ "yaca", "pma", "saltychat" }) do
        if GetResourceState(radio_provider_resources[candidate]) == "started" then
            return candidate
        end
    end
    return nil
end

function Bridge.Calls.GetProvider()
    return resolve_call_provider()
end

function Bridge.Calls.IsAvailable()
    local selected = resolve_call_provider()
    return selected ~= nil and (selected ~= "yaca" or yaca_is_enabled())
end

function Bridge.Calls.SupportsSpeaker()
    local selected = resolve_call_provider()
    return Bridge.Speaker.IsEnabled() and (selected == "yaca" or selected == "saltychat")
end

function Bridge.Calls.SupportsMute()
    return resolve_call_provider() == "yaca"
end

function Bridge.Calls.Start(identifier, player_handles)
    local selected = resolve_call_provider()
    if selected == "pma" then
        return true, selected
    end
    if selected == "yaca" then
        if not yaca_is_enabled() then
            return false, selected
        end
        local caller_source = tonumber(player_handles[1])
        local target_source = tonumber(player_handles[2])
        if not caller_source or not target_source then
            Bridge.Debug(
                "error",
                "[sky_phone] Yaca refused call %s because a player source was invalid.",
                tostring(identifier),
                { always = true }
            )
            return false, selected
        end

        local success, error_message = pcall(function()
            exports["yaca-voice"]:callPlayer(caller_source, target_source, true)
        end)
        if not success then
            Bridge.Debug(
                "error",
                "[sky_phone] Yaca could not start call %s: %s",
                tostring(identifier),
                tostring(error_message),
                { always = true }
            )
            return false, selected
        end
        return true, selected
    end
    if selected ~= "saltychat" then
        return false, nil
    end

    local success, error_message = pcall(function()
        exports.saltychat:AddPlayersToCall(tostring(identifier), player_handles)
    end)
    if not success then
        Bridge.Debug(
            "error",
            "[sky_phone] SaltyChat could not add players to call %s: %s",
            tostring(identifier),
            tostring(error_message),
            { always = true }
        )
        return false, selected
    end
    return true, selected
end

function Bridge.Calls.Stop(identifier, player_handles, provider)
    local selected = provider or resolve_call_provider()
    if selected == "yaca" then
        if GetResourceState("yaca-voice") ~= "started" then
            return
        end
        local caller_source = tonumber(player_handles[1])
        local target_source = tonumber(player_handles[2])
        if not caller_source or not target_source then
            Bridge.Debug(
                "error",
                "[sky_phone] Yaca could not stop call %s because a player source was invalid.",
                tostring(identifier),
                { always = true }
            )
            return
        end

        local success, error_message = pcall(function()
            exports["yaca-voice"]:callPlayer(caller_source, target_source, false)
        end)
        if not success then
            Bridge.Debug(
                "error",
                "[sky_phone] Yaca could not stop call %s: %s",
                tostring(identifier),
                tostring(error_message),
                { always = true }
            )
        end
        return
    end
    if selected ~= "saltychat" or GetResourceState("saltychat") ~= "started" then
        return
    end

    local success, error_message = pcall(function()
        exports.saltychat:RemovePlayersFromCall(tostring(identifier), player_handles)
    end)
    if not success then
        Bridge.Debug(
            "error",
            "[sky_phone] SaltyChat could not remove players from call %s: %s",
            tostring(identifier),
            tostring(error_message),
            { always = true }
        )
    end
end

function Bridge.Calls.SetSpeaker(player_source, enabled, provider)
    if enabled == true and not Bridge.Speaker.IsEnabled() then
        return false
    end
    local selected = provider or resolve_call_provider()
    local resource_name = call_provider_resources[selected]
    if (selected ~= "yaca" and selected ~= "saltychat")
        or GetResourceState(resource_name) ~= "started"
    then
        return false
    end

    local success, error_message = pcall(function()
        if selected == "yaca" then
            exports["yaca-voice"]:enablePhoneSpeaker(tonumber(player_source), enabled == true)
        else
            exports.saltychat:SetPhoneSpeaker(tonumber(player_source), enabled == true)
        end
    end)
    if not success then
        Bridge.Debug(
            "error",
            "[sky_phone] %s could not update the phone speaker for source %s: %s",
            selected == "yaca" and "Yaca" or "SaltyChat",
            tostring(player_source),
            tostring(error_message),
            { always = true }
        )
        return false
    end
    return true
end

function Bridge.Calls.SetMuted(player_source, enabled, provider)
    local selected = provider or resolve_call_provider()
    if selected ~= "yaca" or GetResourceState("yaca-voice") ~= "started" then
        return false
    end

    local success, error_message = pcall(function()
        exports["yaca-voice"]:muteOnPhone(tonumber(player_source), enabled == true)
    end)
    if not success then
        Bridge.Debug(
            "error",
            "[sky_phone] Yaca could not update the phone mute state for source %s: %s",
            tostring(player_source),
            tostring(error_message),
            { always = true }
        )
        return false
    end
    return true
end

function Bridge.Radio.GetProvider()
    return resolve_radio_provider()
end

function Bridge.Radio.SupportsSecondary()
    local selected = resolve_radio_provider()
    return Config.Radio.AllowSecondary and (selected == "yaca" or selected == "saltychat")
end

function Bridge.Radio.SupportsSpeaker()
    return Bridge.Speaker.IsEnabled() and resolve_radio_provider() == "saltychat"
end

function Bridge.Radio.SetPlayerSpeaker(player_source, enabled)
    if enabled == true and not Bridge.Speaker.IsEnabled() then
        return false
    end
    if resolve_radio_provider() ~= "saltychat" then
        return false
    end

    local success, error_message = pcall(function()
        exports.saltychat:SetPlayerRadioSpeaker(tonumber(player_source), enabled == true)
    end)
    if not success then
        Bridge.Debug(
            "error",
            "[sky_phone] SaltyChat could not update the radio speaker for source %s: %s",
            tostring(player_source),
            tostring(error_message),
            { always = true }
        )
        return false
    end
    return true
end
