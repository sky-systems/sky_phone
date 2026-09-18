local events, handlers, threads = {}, {}, {}
local target, input_distance, proximity, channel = 1, 3.0, 3.0, 0
local provider_state = "started"
Config = { Calls = { VoiceProvider = "pma" } }
Bridge = { Calls = {}, Speaker = { IsEnabled = function() return true end }, Debug = function() end }
exports = { ["pma-voice"] = { setCallChannel = function(_, value) channel = value end } }
function GetResourceState() return provider_state end
function GetCurrentResourceName() return "sky_phone" end
function RegisterNetEvent(name, fn) events[name] = fn end
function AddEventHandler(name, fn) handlers[name] = fn end
function CreateThread(fn) threads[#threads+1] = coroutine.create(fn) end
function Wait() coroutine.yield() end
function MumbleSetVoiceTarget(value) target = value end
function MumbleSetAudioInputDistance(value) input_distance = value end
function MumbleGetTalkerProximity() return proximity end
dofile("sky_phone/source/bridge/client/calls.lua")
assert(Bridge.Calls.SupportsMute() and Bridge.Calls.SupportsSpeaker(), "Stock PMA needs no extension")
assert(Bridge.Calls.Join(101) and channel == 101)
local mute = events["sky_phone:calls:pma-muted"]
mute("true"); assert(target == 1, "Only boolean mute states are accepted")
mute(true); assert(target == 0 and input_distance == 0 and channel == 101,
    "Mute must stop sending while retaining call membership and incoming audio")
-- Simulate a PMA reconnect or voice-mode change while muted.
target=1; input_distance=15; proximity=15
local ok,err=coroutine.resume(threads[1]); assert(ok,err)
assert(target == 0 and input_distance == 0)
mute(false); assert(target == 1 and input_distance == 15, "Unmute uses current PMA range instead of a fixed distance")
mute(true); Bridge.Calls.Leave(); assert(target == 1 and input_distance == 15 and channel == 0)
mute(true); handlers.onClientResourceStop("sky_phone"); assert(target == 1)
mute(true); handlers.onClientResourceStop("pma-voice"); assert(target == 1)
Config.Calls.VoiceProvider="saltychat"
assert(Bridge.Calls.SupportsMute() and Bridge.Calls.SupportsSpeaker())
mute(true); assert(target == 1, "PMA natives must not run for SaltyChat")
Config.Calls.VoiceProvider="yaca"; assert(Bridge.Calls.SupportsMute())
provider_state="stopped"; assert(not Bridge.Calls.SupportsMute() and not Bridge.Calls.SupportsSpeaker())
print("PASS integrated PMA mute: no extension, preserved receive path, range changes and cleanup")
