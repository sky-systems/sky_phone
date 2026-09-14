local events, handlers, threads, joined = {}, {}, {}, {}
local coords = { [1] = { x = 100, y = 0, z = 0 }, [2] = { x = 0, y = 0, z = 0 },
    [3] = { x = 1, y = 0, z = 0 }, [4] = { x = 9, y = 0, z = 0 }, [5] = { x = 1, y = 0, z = 0 } }
local buckets, states, busy = { [5] = 1 }, {}, {}
local speaker_enabled = true
local resource_state = "started"
Bridge = { Speaker = { IsEnabled = function() return speaker_enabled end }, Debug = function() end }
SkyPhoneCalls = { IsActiveForSource = function(player) return busy[player] == true end }
function GetPlayers() return { "1", "2", "3", "4", "5" } end
function GetPlayerPed(player) return player end
function GetEntityCoords(player) return coords[player] end
function GetPlayerRoutingBucket(player) return buckets[player] or 0 end
function GetResourceState() return resource_state end
function Player(player)
    states[player] = states[player] or { callChannel = 0 }
    return { state = states[player] }
end
exports = { ["pma-voice"] = { setPlayerCall = function(_, player, channel)
    Player(player).state.callChannel = channel
    joined[#joined+1] = { player, channel }
end } }
function TriggerClientEvent(name, player, payload)
    assert(name == "sky_phone:calls:pma-muted")
    events[player] = payload
end
function AddEventHandler(name, callback) handlers[name] = callback end
function CreateThread(callback) threads[#threads + 1] = coroutine.create(callback) end
function Wait() coroutine.yield() end
function GetCurrentResourceName() return "sky_phone" end
local function tick()
    local ok, err = coroutine.resume(threads[1]); assert(ok, err)
end
dofile("sky_phone/source/bridge/server/pma_calls.lua")
assert(SkyPhonePmaCalls.Start("call", { 1, 2 }, 101))
assert(#joined == 0, "Private calls must not pull in bystanders")
assert(not SkyPhonePmaCalls.Set(3, "speakers", true), "Only actual callers may toggle speaker")
assert(not SkyPhonePmaCalls.Set(1, "invalid", true))
assert(SkyPhonePmaCalls.Set(2, "speakers", true))
assert(Player(3).state.callChannel == 101, "Nearby player joins the ordinary bidirectional PMA call")
assert(Player(4).state.callChannel == 0 and Player(5).state.callChannel == 0, "Range and bucket isolation")
local count = #joined
tick(); tick(); assert(#joined == count, "Stable guest membership must not be rejoined on every poll")
assert(SkyPhonePmaCalls.Set(1, "muted", true) and events[1] == true)
assert(Player(3).state.callChannel == 101, "Muting a caller must leave the group and incoming audio intact")
SkyPhonePmaCalls.Set(1, "muted", false); assert(events[1] == false)
coords[3].x = 5; tick(); assert(Player(3).state.callChannel == 0, "Walking away leaves speaker call")
coords[3].x = 1; tick(); assert(Player(3).state.callChannel == 101)
busy[3] = true; tick(); assert(Player(3).state.callChannel == 0, "A new incoming/outgoing call releases the guest")
busy[3] = nil
Player(3).state.callChannel = 999; tick(); assert(Player(3).state.callChannel == 999, "Existing external calls must not be stolen")
Player(3).state.callChannel = 0; tick(); assert(Player(3).state.callChannel == 101)
Player(3).state.callChannel = 999
SkyPhonePmaCalls.Set(2, "speakers", false)
assert(Player(3).state.callChannel == 999, "Cleanup cannot clear another resource's new call")
Player(3).state.callChannel = 0
SkyPhonePmaCalls.Set(2, "speakers", true)
speaker_enabled = false; tick(); assert(Player(3).state.callChannel == 0)
speaker_enabled = true; tick(); assert(Player(3).state.callChannel == 101)
-- Overlapping speaker circles choose a single nearest call; tie breaks are stable.
coords[4].x = 1.5; coords[5].x = 100; buckets[5] = 0
assert(SkyPhonePmaCalls.Start("other", {4,5}, 102))
SkyPhonePmaCalls.Set(4, "speakers", true)
assert(Player(3).state.callChannel == 102)
coords[4].x = 2; tick(); assert(Player(3).state.callChannel == 101, "Equal distance chooses lower channel")
SkyPhonePmaCalls.Stop("other")
SkyPhonePmaCalls.Set(1, "muted", true)
SkyPhonePmaCalls.Stop("call")
assert(events[1] == false and Player(3).state.callChannel == 0)
assert(SkyPhonePmaCalls.Start("next", {1,2}, 103))
SkyPhonePmaCalls.Set(2, "speakers", true)
source = 1; handlers.playerDropped(); assert(Player(3).state.callChannel == 0)
assert(SkyPhonePmaCalls.Start("restart", {1,2}, 104))
SkyPhonePmaCalls.Set(2, "speakers", true); SkyPhonePmaCalls.Set(2, "muted", true)
handlers.onResourceStop("sky_phone")
assert(Player(3).state.callChannel == 0 and events[2] == false)
print("PASS integrated PMA speaker: bidirectional membership, range, buckets, collisions, mute and cleanup")

-- Exercise the production server bridge for SaltyChat too (including failed exports).
local alive, health, writes, fail_export = { [1]=true, [2]=false }, { [1]=200, [2]=200 }, {}, false
exports.saltychat = {
    GetPlayerAlive = function(_, player) return alive[player] end,
    SetPlayerAlive = function(_, player, value)
        if fail_export then error("provider unavailable") end
        alive[player] = value; writes[#writes+1] = { player, value }
    end,
    AddPlayersToCall = function() end,
    RemovePlayersFromCall = function() end,
}
Config = { Calls = { VoiceProvider = "saltychat" }, Radio = { VoiceProvider = "saltychat" } }
Bridge.Calls, Bridge.Radio = {}, {}
function GetEntityHealth(player) return health[player] or 200 end
dofile("sky_phone/source/bridge/server/voice.lua")
local function salty_tick() local ok,err=coroutine.resume(threads[2]); assert(ok,err) end
assert(Bridge.Calls.SupportsMute() and Bridge.Calls.SupportsSpeaker())
assert(Bridge.Calls.SetMuted(1,true) and alive[1] == false)
assert(Bridge.Calls.SetMuted(1,false) and alive[1] == true)
assert(Bridge.Calls.SetMuted(2,true) and Bridge.Calls.SetMuted(2,false) and alive[2] == false,
    "An already-dead voice state must never be revived")
Bridge.Calls.SetMuted(1,true); health[1]=0
Bridge.Calls.SetMuted(1,false); assert(alive[1] == false, "Death during mute stays dead")
health[1]=200; alive[1]=true; Bridge.Calls.SetMuted(1,true)
Player(1).state.isDead=true
Bridge.Calls.SetMuted(1,false); assert(alive[1] == false, "Framework death state survives with positive ped health")
Player(1).state.isDead=nil; alive[1]=true; Bridge.Calls.SetMuted(1,true)
alive[1]=true; salty_tick(); salty_tick(); assert(alive[1] == false, "Voice refresh must not undo active mute")
Bridge.Calls.Stop("salty",{1,2},"saltychat"); assert(alive[1] == true)
Bridge.Calls.SetMuted(1,true); handlers.onResourceStop("sky_phone"); assert(alive[1] == true)
fail_export=true; assert(not Bridge.Calls.SetMuted(1,true))
fail_export=false; assert(Bridge.Calls.SetMuted(1,true), "A failed mute must remain retryable")
source=1; handlers.playerDropped(); local before=#writes
handlers.onResourceStop("sky_phone"); assert(#writes==before, "Dropped source must never be restored after ID recycling")
print("PASS SaltyChat mute: exports, alive restoration, death/downed guards, refresh, errors and cleanup")
