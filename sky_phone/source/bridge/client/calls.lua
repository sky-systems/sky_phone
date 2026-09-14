local provider_resources = {
    yaca = "yaca-voice",
    pma = "pma-voice",
    saltychat = "saltychat",
}
local provider_aliases = {
    ["yaca-voice"] = "yaca",
    ["pma-voice"] = "pma",
    salty = "saltychat",
}

local function resolve_provider()
    local configured = tostring(Config.Calls.VoiceProvider or "")
    if configured == "auto" then
        for _, candidate in ipairs({ "yaca", "pma", "saltychat" }) do
            if GetResourceState(provider_resources[candidate]) == "started" then
                return candidate
            end
        end
        return nil
    end

    local selected = provider_aliases[configured] or configured
    local resource_name = provider_resources[selected]
    if resource_name and GetResourceState(resource_name) == "started" then
        return selected
    end
    return nil
end

function Bridge.Calls.GetProvider()
    return resolve_provider()
end

function Bridge.Calls.SupportsSpeaker()
    local selected = resolve_provider()
    return Bridge.Speaker.IsEnabled() and (selected == "yaca" or selected == "saltychat" or selected == "pma")
end

function Bridge.Calls.SupportsMute()
    return resolve_provider() ~= nil
end

-- Global microphone mute for PMA, kept entirely inside sky_phone. Incoming audio
-- and call membership stay intact. PMA may restore its target/range on reconnect
-- or a voice-mode change, so enforce only while the phone's mute is active.
local pma_muted = false
local mute_generation = 0
local function apply_pma_mute()
    MumbleSetVoiceTarget(0)
    MumbleSetAudioInputDistance(0.0)
end
local function set_pma_muted(enabled)
    if enabled == pma_muted then return end
    pma_muted = enabled
    mute_generation = mute_generation + 1
    local generation = mute_generation
    if enabled then
        apply_pma_mute()
        CreateThread(function()
            while pma_muted and generation == mute_generation do
                apply_pma_mute()
                Wait(0)
            end
        end)
    else
        MumbleSetVoiceTarget(1) -- PMA's standard voice target.
        -- PMA sets both distances to its current talker proximity. Preserve voice
        -- mode changes made while muted instead of restoring a fixed 9999 metres.
        MumbleSetAudioInputDistance(MumbleGetTalkerProximity() + 0.0)
    end
end

function Bridge.Calls.Join(channel)
    local selected = resolve_provider()
    if selected == "pma" then
        local call_channel = tonumber(channel) or 0
        if call_channel <= 0 then
            Bridge.Debug("error", "[sky_phone] Refused to join an invalid PMA call channel.", { always = true })
            return false
        end
        exports["pma-voice"]:setCallChannel(call_channel)
        return true
    end

    if selected == "yaca" or selected == "saltychat" then
        -- Yaca and SaltyChat call membership is owned by the server bridge.
        return true
    end

    Bridge.Debug(
        "error",
        "[sky_phone] Configured call voice provider '%s' is not supported or not started.",
        tostring(Config.Calls.VoiceProvider),
        { always = true }
    )
    return false
end

function Bridge.Calls.Leave()
    set_pma_muted(false)
    if resolve_provider() == "pma" then
        exports["pma-voice"]:setCallChannel(0)
    end
end

RegisterNetEvent("sky_phone:calls:pma-muted", function(enabled)
    if type(enabled) ~= "boolean" or resolve_provider() ~= "pma" then return end
    set_pma_muted(enabled)
end)
AddEventHandler("onClientResourceStop", function(resource)
    if resource == GetCurrentResourceName() or resource == "pma-voice" then set_pma_muted(false) end
end)
