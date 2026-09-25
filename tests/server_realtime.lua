local offline = {}
SkyPhoneCellular = { HasSignal = function(source) return not offline[source] end }
-- Run with Lua 5.4 from the repository root. No network or FiveM server required.
local callbacks, handlers, threads, events, requests = {}, {}, {}, {}, {}
local now, sequence = 100, 0
local profiles, blocked, buckets, positions = {}, {}, {}, {}
for id = 1, 12 do profiles[id] = { id = id, display_name = "Player " .. id }; positions[id] = id end
local function encode(value)
    if type(value) ~= "table" then return tostring(value) end
    local parts = {}
    for k,v in pairs(value) do parts[#parts + 1] = tostring(k) .. ":" .. encode(v) end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
end
local env = setmetatable({ Config = {}, IsDuplicityVersion = function() return true end,
    vector3 = function(x,y,z) return { x=x,y=y,z=z } end,
    os = { time = function() return now end }, json = { encode = encode },
    GetPlayerRoutingBucket = function(src) return buckets[src] or 0 end,
    GetPlayerPed = function(src) return src end, GetEntityHealth = function() return 100 end,
    GetPlayerName = function(src) return profiles[src] and "Player" end,
    GetCurrentResourceName = function() return "sky_phone" end,
    GetEntityCoords = function(ped)
        return setmetatable({ x = positions[ped] }, { __sub = function(a,b)
            return setmetatable({}, { __len = function() return math.abs(a.x-b.x) end })
        end })
    end,
    RegisterNetEvent = function(name, fn) handlers[name] = fn end,
    AddEventHandler = function(name, fn) handlers[name] = fn end,
    TriggerClientEvent = function(name, src, data) events[#events+1] = {name=name,src=src,data=data} end,
    CreateThread = function(fn) local thread = coroutine.create(fn); threads[#threads+1]=thread; assert(coroutine.resume(thread)) end,
    Wait = function() coroutine.yield() end,
}, { __index = _G })
assert(loadfile("sky_phone/config/config.lua", "t", env))()
env.Bridge = { Debug = function() end, Callbacks = { Register = function(name,fn) callbacks[name]=fn end }, Database = {
    Query = function() sequence=sequence+1; return {{ id="live-"..sequence }} end,
} }
local call = { id="test-call", state="connected", video=true, caller={source=1}, callee={source=2} }
env.SkyPhoneCalls = { GetForSource = function(src) return (src==1 or src==2) and call or nil end,
    StopVideo = function() call.video=false end }
-- Exercise the actual deferred migration lifecycle; an eagerly mocked SkyPhone
-- hides voice events that arrive before the phone module exists or is ready.
assert(loadfile("sky_phone/source/bridge/server/migrations.lua", "t", env))()
local rate_allowed, rate_requests = true, {}
env.Bridge.Database.AfterMigration("sky_phone", function()
    env.SkyPhone = {}
    coroutine.yield("phone_initializing")
    env.SkyPhone.AllowOperation = function(src, operation, maximum, window)
        rate_requests[#rate_requests + 1] = { src=src, operation=operation, maximum=maximum, window=window }
        return rate_allowed
    end
    env.SkyPhone.RequireSession = function(src) return profiles[src] end
end)
env.SkyPhoneRealtimeCloudflare = { Ice = function() return {{ urls="stun:test" }} end,
    Sfu = function(session,op,payload)
        requests[#requests+1]={session=session,op=op,payload=payload}
        if op=="create" then return {sessionId="cf-"..#requests} end
        local result = {tracks={}}
        for i,track in ipairs(payload.tracks or {}) do result.tracks[i]={mid=track.mid or tostring(i),trackName=track.trackName} end
        return result
    end }
assert(loadfile("sky_phone/source/server/realtime.lua", "t", env))()
for _, app in ipairs({"picstagram","fliptok"}) do env.SkyPhoneRealtime.Apps[app] = {
    profile = function(src) return profiles[src] end,
    canView = function(profile) return not blocked[profile.id] end,
} end
local function invoke(name,src,data) return assert(callbacks["sky_phone:realtime:"..name])(src,data or {}) end
local function success(result) assert(result.success,result.error); return result.data end
local function tick() now=now+1; assert(coroutine.resume(threads[1])) end
local function create(app)
    local joined=success(invoke("create",1,{kind="live",app=app,title="Test"}))
    success(invoke("ready",1,{id=joined.room.id}))
    return joined.room.id
end
local function join(src,id)
    success(invoke("join",src,{id=id})); return success(invoke("ready",src,{id=id}))
end
env.source=5
for _=1,3 do
    handlers["sky_phone:realtime:voice"]({enabled=true,range=10})
    tick()
end
assert(env.SkyPhone==nil and #rate_requests==0 and not next(callbacks),
    "Voice heartbeats must wait while the database migration is pending")
local initialization=coroutine.create(function() env.Bridge.Database.CompleteMigration("sky_phone") end)
local ok, status=coroutine.resume(initialization)
assert(ok and status=="phone_initializing")
handlers["sky_phone:realtime:voice"]({enabled=true,range=10})
assert(#rate_requests==0 and not next(callbacks), "A partially initialized phone must not receive realtime operations")
assert(coroutine.resume(initialization))
assert(coroutine.status(initialization)=="dead")
assert(success(invoke("config",1,{})).enabled, "Realtime callbacks must become available after phone initialization")
rate_allowed=false
assert(invoke("create",1,{kind="live",app="picstagram",title="Limited"}).error=="rate_limited")
handlers["sky_phone:realtime:voice"]({enabled=true,range=10})
local voice_request=rate_requests[#rate_requests]
assert(voice_request.src==5 and voice_request.operation=="realtime_voice"
    and voice_request.maximum==90 and voice_request.window==60, "Voice must retain the shared rate limit after startup")
rate_allowed=true
local id=create("picstagram")
tick()
for _,event in ipairs(events) do
    assert(event.name~="sky_phone:realtime:nearby", "Early or rate-limited voice reports must not be retained")
end
print("PASS realtime startup: delayed migration, partial phone initialization, recovery and rate limits")
local live_entries = success(invoke("list",2,{app="picstagram"}))
assert(#live_entries == 1 and live_entries[1].profileId == "1", "Live avatars need the public profile identity")
blocked[3]=true
assert(#success(invoke("list",3,{app="picstagram"}))==0, "Blocked streams must never produce live avatar links")
assert(not invoke("join",3,{id=id}).success)
assert(not invoke("chat",3,{id=id,text="forged"}).success)
local unready=success(invoke("join",2,{id=id}))
assert(unready.room.viewers==0)
assert(not invoke("signal",1,{id=id,target=2,signal={type="offer",sdp="x"}}).success)
assert(success(invoke("ready",2,{id=id})).viewers==1)
join(4,id)
assert(not invoke("signal",2,{id=id,target=4,signal={type="offer"}}).success,"viewers cannot signal each other")
success(invoke("chat",2,{id=id,text=" Hello ",name="forged"}))
local state=success(invoke("heartbeat",1,{id=id}))
assert(state.messages[1].name=="Player 2" and state.messages[1].text=="Hello")
assert(not invoke("chat",2,{id=id,text=string.rep("x",301)}).success)
for i=1,55 do success(invoke("chat",2,{id=id,text=tostring(i)})) end
assert(#success(invoke("heartbeat",1,{id=id})).messages==50)
success(invoke("leave",4,{id=id}));assert(success(invoke("heartbeat",1,{id=id})).viewers==1)
env.source=5;handlers["sky_phone:realtime:voice"]({enabled=true,range=10});tick()
local near=join(5,id);assert(near.role=="nearby" and #near.peers==1 and near.peers[1].sends)
assert(not invoke("chat",5,{id=id,text="ambient"}).success)
buckets[5]=2;tick();assert(not invoke("heartbeat",5,{id=id}).success)
env.Config.Realtime.MaxViewers=1
assert(not invoke("join",4,{id=id}).success)
blocked[2]=true;assert(not invoke("heartbeat",2,{id=id}).success)
assert(success(invoke("heartbeat",1,{id=id})).viewers==0)
success(invoke("leave",1,{id=id}));assert(#success(invoke("list",1,{app="picstagram"}))==0)
blocked[2]=nil;env.Config.Realtime.Transport="cloudflare"
id=create("fliptok");join(2,id)
success(invoke("sfu",1,{id=id,operation="create"}));success(invoke("sfu",2,{id=id,operation="create"}))
assert(not invoke("sfu",2,{id=id,operation="publish",tracks={{mid="0",kind="audio",trackName="bad"}}}).success)
success(invoke("sfu",1,{id=id,operation="publish",tracks={{mid="0",kind="video",trackName="camera"}},sessionDescription={type="offer",sdp="test"}}))
success(invoke("sfu",2,{id=id,operation="pull",target=1,tracks={{sessionId="forged",trackName="private"}}}))
assert(requests[#requests].payload.tracks[1].trackName=="camera")
assert(not invoke("sfu",2,{id=id,operation="close",mids={"forged"}}).success)
assert(not invoke("sfu",2,{id=id,operation="pull",target=3}).success)
env.source=1;handlers.playerDropped();assert(not invoke("heartbeat",2,{id=id}).success)
call.video=true
env.Config.Realtime.Transport="p2p"
local video=success(invoke("create",2,{kind="call",id="test-call"}))
assert(video.room.role=="call")
local first_ready=success(invoke("ready",2,{id=video.room.id}))
assert(#first_ready.peers==0 and first_ready.revision, "The first ready participant needs a versioned empty snapshot")
local second=success(invoke("create",1,{kind="call",id="test-call"}))
assert(#second.room.peers==0, "Media must be ready before peers can connect")
local second_ready=success(invoke("ready",1,{id=video.room.id}))
local both_ready=success(invoke("heartbeat",2,{id=video.room.id}))
assert(#second_ready.peers==1 and #both_ready.peers==1)
assert(both_ready.revision>first_ready.revision, "An earlier ready reply must not overwrite the later peer broadcast")
local previous_events=#events
tick()
assert(#events==previous_events, "Unchanged rooms must not generate per-tick broadcasts")
assert(success(invoke("heartbeat",2,{id=video.room.id})).revision==both_ready.revision,
    "An unchanged heartbeat must retain its revision")
success(invoke("signal",1,{id=video.room.id,target=2,signal={type="offer",sdp="direct-video"}}))
assert(events[#events].name=="sky_phone:realtime:signal" and events[#events].src==2)
assert(not invoke("join",3,{id=video.room.id}).success)
success(invoke("leave",2,{id=video.room.id}));assert(not call.video)
-- Losing reception removes viewers/nearby participants and stops a disconnected host.
id = create("picstagram")
join(2, id)
offline[2], offline[5] = true, true
buckets[5] = 0
env.source = 5
handlers["sky_phone:realtime:voice"]({ enabled = true, range = 10 })
tick()
assert(success(invoke("heartbeat", 1, { id = id })).viewers == 0)
assert(not invoke("heartbeat", 2, { id = id }).success)
assert(not invoke("heartbeat", 5, { id = id }).success, "Disconnected nearby participants must not be re-added")
offline[1] = true
tick()
assert(not invoke("heartbeat", 1, { id = id }).success, "Broadcast must stop when its host loses reception")
offline = {}

-- The real profile adapters query SQL. Two users can finish that query together.
env.Config.Realtime.MaxBroadcasts = 1
env.SkyPhoneRealtime.Apps.picstagram.publicProfile = function(profile_id)
    coroutine.yield("loading_profile")
    return profiles[profile_id]
end
local created = {}
local creators = {}
for player = 3, 4 do
    creators[player] = coroutine.create(function()
        created[player] = invoke("create", player, { kind = "live", app = "picstagram", title = "Concurrent" })
    end)
    local resumed, phase = coroutine.resume(creators[player])
    assert(resumed and phase == "loading_profile")
end
for player = 3, 4 do assert(coroutine.resume(creators[player])) end
assert(created[3].success and not created[4].success, "Concurrent profile loads must not exceed MaxBroadcasts")
success(invoke("leave", 3, { id = created[3].data.room.id }))
print("Realtime authorization, topology, livechat, viewers, proximity, capacity and SFU tests passed")
