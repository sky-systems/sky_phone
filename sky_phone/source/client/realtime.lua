-- Voice providers expose state/range, not raw TeamSpeak audio. NUI captures the mic.
local salty = { talking = false, muted = false, enabled = true }
local yaca = { talking = false, muted = false, disabled = false }
local capturing = false
RegisterNetEvent("SaltyChat_TalkStateChanged", function(value) salty.talking = value == true end)
RegisterNetEvent("SaltyChat_MicStateChanged", function(value) salty.muted = value == true end)
RegisterNetEvent("SaltyChat_MicEnabledChanged", function(value) salty.enabled = value == true end)
AddEventHandler("yaca:external:isTalking", function(value) yaca.talking = value == true end)
AddEventHandler("yaca:external:voiceRangeUpdate", function(range)
    -- Early Yaca reports microphone mute as a zero voice-range event.
    if type(range) == "number" then yaca.muted = range <= 0 end
end)
AddEventHandler("yaca:external:muteStateChanged", function(value) yaca.muted = value == true end)
AddEventHandler("yaca:external:microphoneMuteStateChanged", function(value) yaca.muted = value == true end)
AddEventHandler("yaca:external:microphoneDisabledStateChanged", function(value) yaca.disabled = value == true end)
local function state()
    if Bridge.PlayerState and Bridge.PlayerState.GetBlockReason() then
        return { talking = false, enabled = false, range = 0 }
    end
    local provider = Bridge.Calls.GetProvider()
    if provider == "saltychat" then
        return { talking = salty.talking and not salty.muted and salty.enabled,
            enabled = salty.enabled and not salty.muted, range = exports.saltychat:GetVoiceRange() }
    elseif provider == "yaca" then
        if not Bridge.Yaca.IsEnabled() then return { talking = false, enabled = false, range = 0 } end
        local voice = exports["yaca-voice"]
        local muted_export = Bridge.Yaca.GetOptionalExport("getMicrophoneMuteState")
        local disabled_export = Bridge.Yaca.GetOptionalExport("getMicrophoneDisabledState")
        local talking_export = Bridge.Yaca.GetOptionalExport("isPlayerTalking")
        if muted_export then yaca.muted = muted_export(voice) == true end
        if disabled_export then yaca.disabled = disabled_export(voice) == true end
        local talking = yaca.talking
        if talking_export then
            talking = talking_export(voice, GetPlayerServerId(PlayerId())) == true
        elseif LocalPlayer and type(LocalPlayer.state["yaca:lipsync"]) == "boolean" then
            -- The provider owns this speaking state in every released version;
            -- it also seeds the old event API after a Phone-only restart.
            talking = LocalPlayer.state["yaca:lipsync"]
        end
        local enabled = not yaca.muted and not yaca.disabled
        return { talking = enabled and talking,
            enabled = enabled, range = exports["yaca-voice"]:getVoiceRange() }
    elseif provider == "pma" then
        return { talking = MumbleIsPlayerTalking(PlayerId()), enabled = true, range = MumbleGetTalkerProximity() }
    end
    return { talking = false, enabled = false, range = 0 }
end
local warned = false
local function voice_state()
    local ok, result = pcall(state)
    if ok then warned = false return result end
    if not warned then print("[sky_phone] Realtime voice state unavailable; microphone is muted.") warned = true end
    return { talking = false, enabled = false, range = 0 }
end
RegisterNUICallback("realtime:microphone", function(data, cb)
    capturing = type(data) == "table" and data.active == true
    cb({ success = true, data = voice_state() })
end)
for _, name in ipairs({ "room", "signal", "ended", "nearby" }) do
    RegisterNetEvent("sky_phone:realtime:" .. name, function(data)
        SendNUIMessage({ type = "realtime:" .. name, data = data })
    end)
end
CreateThread(function()
    local last_sent = 0
    while true do
        Wait(capturing and 100 or 1000)
        if Config.Realtime and Config.Realtime.Enabled then
            local current = voice_state()
            if capturing then SendNUIMessage({ type = "realtime:voice", data = current }) end
            if GetGameTimer() - last_sent >= 5000 then
                TriggerServerEvent("sky_phone:realtime:voice", { enabled = current.enabled, range = current.range })
                last_sent = GetGameTimer()
            end
        end
    end
end)
AddEventHandler("sky_phone:client:restricted", function()
    capturing = false
    SendNUIMessage({ type = "realtime:reset" })
end)
AddEventHandler("onResourceStop", function(resource)
    if resource == "yaca-voice" then
        yaca = { talking = false, muted = false, disabled = false }
    end
    if resource == GetCurrentResourceName() then
        SendNUIMessage({ type = "realtime:reset" })
    end
end)
