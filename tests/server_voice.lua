local resource_states = { ["yaca-voice"] = "started" }
local status_value = true
local status_error
local status_reads = 0
local debug_messages = {}
local phone_actions = {}

Config = {
    Calls = { VoiceProvider = "yaca" },
    Radio = { VoiceProvider = "yaca", AllowSecondary = true },
}
Bridge = {
    Calls = {},
    Radio = {},
    Speaker = { IsEnabled = function() return true end },
    Debug = function(level, message, ...)
        debug_messages[#debug_messages + 1] = { level = level, message = message, args = { ... } }
    end,
}
exports = {
    ["yaca-voice"] = setmetatable({
        isEnabled = function()
            status_reads = status_reads + 1
            if status_error then error(status_error) end
            return status_value
        end,
        callPlayer = function(_, caller, target, enabled)
            phone_actions[#phone_actions + 1] = { "call", caller, target, enabled }
        end,
        enablePhoneSpeaker = function(_, player_source, enabled)
            phone_actions[#phone_actions + 1] = { "speaker", player_source, enabled }
        end,
        muteOnPhone = function(_, player_source, enabled)
            phone_actions[#phone_actions + 1] = { "mute", player_source, enabled }
        end,
    }, {
        __index = function(_, export_name)
            error("No such export " .. export_name .. " in resource yaca-voice")
        end,
    }),
}

function GetResourceState(resource_name)
    return resource_states[resource_name] or "missing"
end

function CreateThread() end
function AddEventHandler() end

assert(loadfile("sky_phone/source/bridge/yaca.lua"))()
assert(loadfile("sky_phone/source/bridge/server/voice.lua"))()

for _, enabled in ipairs({ true, 1 }) do
    status_value = enabled
    assert(Bridge.Calls.IsAvailable(), "enabled Yaca status must allow answering calls: " .. tostring(enabled))
    local started, provider = Bridge.Calls.Start("test-call", { 10, 20 }, 42)
    assert(started and provider == "yaca", "enabled Yaca must start the provider call")
    local action = phone_actions[#phone_actions]
    assert(action[1] == "call" and action[2] == 10 and action[3] == 20 and action[4] == true)
end

for _, disabled in ipairs({ false, 0 }) do
    status_value = disabled
    local before = #phone_actions
    assert(not Bridge.Calls.IsAvailable(), "disabled Yaca status must block answering calls")
    local started, provider = Bridge.Calls.Start("disabled-call", { 10, 20 }, 42)
    assert(not started and provider == "yaca", "disabled Yaca must not start the provider call")
    assert(#phone_actions == before, "disabled calls must not mutate Yaca membership")
end

for _, invalid in ipairs({ "true", "1", 2, {} }) do
    status_value = invalid
    local before = #debug_messages
    assert(not Bridge.Calls.IsAvailable(), "invalid Yaca status must not enable calls")
    assert(#debug_messages == before + 1 and debug_messages[#debug_messages].level == "error",
        "invalid Yaca status must produce an English diagnostic")
end
status_value = nil
local before = #debug_messages
assert(not Bridge.Calls.IsAvailable(), "a missing status return must not enable calls")
assert(#debug_messages == before + 1, "a missing status return must produce a diagnostic")

status_error = "Yaca status handler failed"
assert(not Bridge.Calls.IsAvailable(), "a failing status handler must not use legacy compatibility")
assert(debug_messages[#debug_messages].level == "error")
status_error = nil

resource_states["yaca-voice"] = "stopped"
local reads_before = status_reads
assert(not Bridge.Calls.IsAvailable(), "stopped Yaca must remain unavailable")
assert(status_reads == reads_before, "stopped Yaca must not be queried")
resource_states["yaca-voice"] = "started"

-- Yaca v1.0.0 through v3.0.6 has the phone exports but no server status export.
exports["yaca-voice"].isEnabled = nil
local warnings_before = #debug_messages
assert(Bridge.Calls.IsAvailable(), "legacy Yaca must remain available without its status export")
assert(Bridge.Calls.IsAvailable(), "legacy availability checks must be repeatable")
assert(#debug_messages == warnings_before + 1 and debug_messages[#debug_messages].level == "warn",
    "legacy compatibility must warn once")
local started, provider = Bridge.Calls.Start("legacy-call", { 10, 20 }, 42)
assert(started and provider == "yaca", "legacy Yaca must use the stable phone exports")
assert(Bridge.Calls.SetSpeaker(10, true, provider))
assert(Bridge.Calls.SetMuted(10, true, provider))
Bridge.Calls.Stop("legacy-call", { 10, 20 }, provider)
local stop_action = phone_actions[#phone_actions]
assert(stop_action[1] == "call" and stop_action[2] == 10 and stop_action[3] == 20 and stop_action[4] == false)

Config.Calls.VoiceProvider = "yaca-voice"
assert(Bridge.Calls.GetProvider() == "yaca" and Bridge.Calls.IsAvailable(), "the Yaca alias must remain compatible")
Config.Calls.VoiceProvider = "auto"
assert(Bridge.Calls.GetProvider() == "yaca" and Bridge.Calls.IsAvailable(), "automatic Yaca discovery must remain compatible")

for _, provider_name in ipairs({ "pma", "saltychat" }) do
    Config.Calls.VoiceProvider = provider_name
    resource_states[provider_name == "pma" and "pma-voice" or "saltychat"] = "started"
    assert(Bridge.Calls.IsAvailable(), "other started voice providers must remain available")
end

print("server voice contracts passed")
