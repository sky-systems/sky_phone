-- Official provider state controls microphone transmission; no TeamSpeak PCM export exists.
local events,callbacks={},{}
local provider="saltychat"
local enabled,muted,disabled,talking=true,false,false,true
local exports={saltychat={GetVoiceRange=function() return 8 end},["yaca-voice"]={
    isEnabled=function() return enabled end,
    getMicrophoneMuteState=function() return muted end,
    getMicrophoneDisabledState=function() return disabled end,
    isPlayerTalking=function(_,id) assert(id==42);return talking end,
    getVoiceRange=function() return 12 end,
}}
local env=setmetatable({Bridge={Calls={GetProvider=function() return provider end},Debug=function() end},exports=exports,
    RegisterNetEvent=function(name,fn) events[name]=fn end,AddEventHandler=function(name,fn) events[name]=fn end,
    GetResourceState=function() return "started" end,
    RegisterNUICallback=function(name,fn) callbacks[name]=fn end,CreateThread=function() end,
    GetPlayerServerId=function() return 42 end,PlayerId=function() return 3 end,
    MumbleIsPlayerTalking=function() return talking end,MumbleGetTalkerProximity=function() return 5 end,
},{__index=_G})
assert(loadfile("sky_phone/source/bridge/yaca.lua","t",env))()
assert(loadfile("sky_phone/source/client/realtime.lua","t",env))()
local function state()
    local result;callbacks["realtime:microphone"]({active=true},function(value) result=value end)
    assert(result.success);return result.data
end
assert(not state().talking)
events.SaltyChat_TalkStateChanged(true);assert(state().talking and state().range==8)
events.SaltyChat_MicStateChanged(true);assert(not state().talking)
events.SaltyChat_MicStateChanged(false);events.SaltyChat_MicEnabledChanged(false);assert(not state().talking)
provider="yaca";assert(state().talking and state().range==12)
muted=true;assert(not state().talking);muted=false;disabled=true;assert(not state().talking)
disabled=false;enabled=false;assert(not state().talking);enabled=true;talking=false;assert(not state().talking)
provider="pma";talking=true;assert(state().talking and state().range==5)
provider=nil;assert(not state().enabled and not state().talking)
provider="yaca";exports["yaca-voice"].isEnabled=function() error("provider stopped") end
assert(not state().talking)
exports["yaca-voice"].isEnabled=function() return 1 end;talking=true
assert(state().talking, "numeric enabled status must allow realtime microphone capture")
exports["yaca-voice"].isEnabled=function() return 0 end
assert(not state().enabled and not state().talking, "numeric disabled status must block capture")

-- Legacy Yaca has official speaking/mute events instead of these newer getters.
exports["yaca-voice"].isEnabled=nil
exports["yaca-voice"].isPlayerTalking=nil
exports["yaca-voice"].getMicrophoneMuteState=nil
exports["yaca-voice"].getMicrophoneDisabledState=nil
events["yaca:external:isTalking"](true)
assert(state().talking and state().range==12)
events["yaca:external:voiceRangeUpdate"](0);assert(not state().talking)
events["yaca:external:voiceRangeUpdate"](12);assert(state().talking)
events["yaca:external:muteStateChanged"](true);assert(not state().talking)
events["yaca:external:microphoneMuteStateChanged"](false);assert(state().talking)
events["yaca:external:microphoneDisabledStateChanged"](true);assert(not state().talking)
events["yaca:external:microphoneDisabledStateChanged"](false)
events["yaca:external:isTalking"](false);assert(not state().talking)
env.LocalPlayer={state={["yaca:lipsync"]=true}}
assert(state().talking, "legacy speaking state must survive a Phone-only restart")
env.LocalPlayer.state["yaca:lipsync"]=false;assert(not state().talking)
exports["yaca-voice"].getMicrophoneMuteState=function() error("mute export failed") end
assert(not state().talking, "a failing present export must not silently use event state")
print("Realtime SaltyChat/YACA/PMA voice gating and failure cleanup passed")
