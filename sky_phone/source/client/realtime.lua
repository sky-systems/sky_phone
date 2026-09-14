-- Voice providers expose state/range, not raw TeamSpeak audio. NUI captures the mic.
local salty = { talking = false, muted = false, enabled = true }
local capturing = false
RegisterNetEvent("SaltyChat_TalkStateChanged", function(value) salty.talking = value == true end)
RegisterNetEvent("SaltyChat_MicStateChanged", function(value) salty.muted = value == true end)
RegisterNetEvent("SaltyChat_MicEnabledChanged", function(value) salty.enabled = value == true end)
local function state()
    local provider = Bridge.Calls.GetProvider()
    if provider == "saltychat" then
        return { talking = salty.talking and not salty.muted and salty.enabled,
            enabled = salty.enabled and not salty.muted, range = exports.saltychat:GetVoiceRange() }
    elseif provider == "yaca" then
        local enabled = exports["yaca-voice"]:isEnabled()
            and not exports["yaca-voice"]:getMicrophoneMuteState()
            and not exports["yaca-voice"]:getMicrophoneDisabledState()
        return { talking = enabled and exports["yaca-voice"]:isPlayerTalking(GetPlayerServerId(PlayerId())),
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
AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        SendNUIMessage({ type = "realtime:reset" })
    end
end)
