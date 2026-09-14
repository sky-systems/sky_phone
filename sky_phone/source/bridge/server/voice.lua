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
local warned_about_legacy_yaca_status = false

local function is_missing_yaca_status_export(error_message)
    local normalized = tostring(error_message):lower()
    return normalized:find("isenabled", 1, true) ~= nil
        and normalized:find("no such export", 1, true) ~= nil
end

local function yaca_is_enabled()
    if GetResourceState("yaca-voice") ~= "started" then
        return false
    end

    local success, enabled = pcall(function()
        return exports["yaca-voice"]:isEnabled()
    end)
    if success then
        return enabled == true
    end
    if is_missing_yaca_status_export(enabled) then
        if not warned_about_legacy_yaca_status then
            warned_about_legacy_yaca_status = true
            Bridge.Debug(
                "warn",
                "[sky_phone] Yaca does not expose the server isEnabled status; using legacy compatibility because yaca-voice is started.",
                { always = true }
            )
        end
        return true
    end

    Bridge.Debug(
        "error",
        "[sky_phone] Yaca could not report its availability: %s",
        tostring(enabled),
        { always = true }
    )
    return false
end

local function resolve_call_provider()
    local configured = tostring(Config.Calls.VoiceProvider or "")
    if configured == "auto" then
        for _, candidate in ipairs({ "yaca", "pma", "saltychat" }) do
            if GetResourceState(call_provider_resources[candidate]) == "started" then
                return candidate
            end
        end
        return nil
    end

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
    return Bridge.Speaker.IsEnabled() and (selected == "yaca" or selected == "saltychat" or selected == "pma")
end

function Bridge.Calls.SupportsMute()
    return resolve_call_provider() ~= nil
end

-- SaltyChat's alive export controls general speech, not just the telephone.
-- Remember the pre-mute voice state; never revive a dead/downed player on unmute.
local salty_muted = {}
local function player_is_dead(player_source)
    local player = Player(player_source)
    local state = player and player.state
    if state and (state.isDead or state.dead or state.isdead or state.inlaststand) then return true end
    local ped = GetPlayerPed(player_source)
    return not ped or ped == 0 or GetEntityHealth(ped) <= 0
end
local function set_salty_muted(player_source, enabled)
    if GetResourceState("saltychat") ~= "started" then return false end
    local success, err = pcall(function()
        local previous = salty_muted[player_source]
        if enabled then
            if previous then return end
            local alive = exports.saltychat:GetPlayerAlive(player_source)
            assert(type(alive) == "boolean", "SaltyChat returned an invalid alive state")
            exports.saltychat:SetPlayerAlive(player_source, false)
            salty_muted[player_source] = { alive = alive }
        elseif previous then
            exports.saltychat:SetPlayerAlive(player_source, previous.alive and not player_is_dead(player_source))
            salty_muted[player_source] = nil
        end
    end)
    if not success then
        Bridge.Debug("error", "[sky_phone] SaltyChat could not update mute for source %s: %s",
            tostring(player_source), tostring(err), { always = true })
    end
    return success
end
CreateThread(function()
    while true do
        Wait(next(salty_muted) and 250 or 1000)
        if GetResourceState("saltychat") == "started" then
            for player_source, previous in pairs(salty_muted) do
                local success, err = pcall(function()
                    if player_is_dead(player_source) then previous.alive = false end
                    -- A revive/voice refresh can restore alive while the call is muted.
                    if exports.saltychat:GetPlayerAlive(player_source) then
                        previous.alive = not player_is_dead(player_source)
                        exports.saltychat:SetPlayerAlive(player_source, false)
                    end
                end)
                if not success then
                    Bridge.Debug("error", "[sky_phone] SaltyChat could not maintain mute for source %s: %s",
                        tostring(player_source), tostring(err), { always = true })
                end
            end
        end
    end
end)
AddEventHandler("playerDropped", function() salty_muted[source] = nil end)
AddEventHandler("onResourceStop", function(resource)
    if resource == "saltychat" then salty_muted = {} return end
    if resource == GetCurrentResourceName() then
        for player_source in pairs(salty_muted) do set_salty_muted(player_source, false) end
    end
end)

function Bridge.Calls.Start(identifier, player_handles, channel)
    local selected = resolve_call_provider()
    if selected == "pma" then
        return SkyPhonePmaCalls.Start(identifier, player_handles, channel), selected
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
    if selected == "pma" then SkyPhonePmaCalls.Stop(identifier) return end
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

    for _, player_source in ipairs(player_handles) do set_salty_muted(tonumber(player_source), false) end
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
    if selected == "pma" then
        return SkyPhonePmaCalls.Set(tonumber(player_source), "speakers", enabled)
    end
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
    if selected == "pma" then
        return SkyPhonePmaCalls.Set(tonumber(player_source), "muted", enabled)
    end
    if selected == "saltychat" then return set_salty_muted(tonumber(player_source), enabled == true) end
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
