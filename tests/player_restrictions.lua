local function env()
    local e = setmetatable({}, { __index = _G })
    e.Config = { Phone = { BlockWhenDead = true, BlockWhenCuffed = true, Item = "phone" },
        Bridge = { Framework = "qb" }, Calls = { VoiceProvider = "pma" },
        Radio = { VoiceProvider = "pma", AllowSecondary = true } }
    e.handlers, e.net, e.events, e.threads = {}, {}, {}, {}
    e.players, e.metadata, e.resources, e.health = {}, {}, {}, {}
    e.now, e.source = 1000, 1
    e.Bridge = { Framework = { GetStatusData = function(src) return e.metadata[src or 1] or {} end,
        GetName = function() return "qb" end }, Radio = {}, Calls = {},
        Speaker = { IsEnabled = function() return true end }, Debug = function() end }
    e.Player = function(src) e.players[src] = e.players[src] or {}; return { state = e.players[src] } end
    e.GetPlayerPed = function(src) return src end
    e.GetEntityHealth = function(src) return e.health[src] or 200 end
    e.GetResourceState = function(name) return e.resources[name] or "stopped" end
    e.GetGameTimer = function() return e.now end
    e.GetCurrentResourceName = function() return "sky_phone" end
    e.CreateThread = function(fn) e.threads[#e.threads + 1] = coroutine.create(fn) end
    e.Wait = function() coroutine.yield() end
    e.AddEventHandler = function(name, fn)
        e.handlers[name] = e.handlers[name] or {}; table.insert(e.handlers[name], fn)
    end
    e.RegisterNetEvent = function(name, fn) e.net[name] = fn end
    e.TriggerEvent = function(name, ...)
        e.events[#e.events + 1] = { name, ... }
        for _, fn in ipairs(e.handlers[name] or {}) do fn(...) end
    end
    e.TriggerClientEvent = function(name, ...) e.events[#e.events+1] = { name, ... } end
    e.exports = {}
    return e
end
local function load(e, path) assert(loadfile("sky_phone/source/" .. path, "t", e))() end
local function tick(thread) local ok, err = coroutine.resume(thread); assert(ok, err) end

local e = env()
load(e, "shared/player_state.lua")
load(e, "bridge/server/player_state.lua")
local guard = e.Bridge.PlayerState
assert(guard.GetBlockReason(1) == nil)
for _, key in ipairs({ "isdead", "inlaststand" }) do
    e.metadata[1] = { [key] = true }
    assert(guard.GetBlockReason(1) == "player_incapacitated", key)
end
e.metadata[1] = { ishandcuffed = true }
assert(guard.GetBlockReason(1) == "player_cuffed")
e.Config.Phone.BlockWhenCuffed = false
assert(guard.GetBlockReason(1) == nil)
e.metadata[1] = { isdead = true }
e.Config.Phone.BlockWhenDead = false
assert(guard.GetBlockReason(1) == nil and guard.Get(1).dead, "Medical state must remain available to Salty mute restoration")
e.Config.Phone.BlockWhenDead, e.Config.Phone.BlockWhenCuffed = true, true
e.metadata[1] = {}
e.players[1] = { SaltyChat_IsAlive = false }
assert(guard.GetBlockReason(1) == nil, "Salty mute must never count as death")
-- Replicated framework status must remain readable after a phone restart
-- without accessing resource exports.
e.exports = setmetatable({}, { __index = function(_, resource)
    error("Player status must not access an export: " .. resource)
end })
for _, key in ipairs({ "dead", "isdead", "isDead" }) do
    e.players[1] = { [key] = true }
    assert(guard.GetBlockReason(1) == "player_incapacitated", key)
    e.players[1][key] = false
    assert(guard.GetBlockReason(1) == nil, key .. " must clear on revive")
end
for _, key in ipairs({ "ishandcuffed", "isHandcuffed", "handcuffed", "isCuffed" }) do
    e.players[1] = { [key] = true }
    assert(guard.GetBlockReason(1) == "player_cuffed", key)
    e.Config.Phone.BlockWhenCuffed = false
    assert(guard.GetBlockReason(1) == nil, "Disabling cuffs must leave death restrictions independent")
    e.players[1].dead = true
    assert(guard.GetBlockReason(1) == "player_incapacitated", "Medical death must still win")
    e.players[1].dead = false
    e.health[1] = 0
    assert(guard.GetBlockReason(1) == "player_incapacitated", "Cuffs cannot mask native death")
    e.health[1] = 200
    e.Config.Phone.BlockWhenCuffed = true
end
e.players[1] = { ishandcuffed = true }
e.net["sky_phone:player:status"]({ dead = false, cuffed = false, source = 2 })
assert(guard.GetBlockReason(1) == "player_cuffed", "A clear report must not override a replicated cuff flag")
for _, key in ipairs({ "ishandcuffed", "invBusy", "inv_busy", "busy", "isDead" }) do
    e.players[1][key] = false
end
assert(guard.GetBlockReason(1) == nil, "Framework clear-state sequence must unlock the phone")
e.players[1] = { invBusy = true, inv_busy = true, busy = true }
assert(guard.GetBlockReason(1) == nil, "Inventory activity alone must not restrict calls/radio")
e.players[1] = {}
e.net["sky_phone:player:status"]({ dead = true, cuffed = false, source = 2 })
assert(guard.GetBlockReason(1) == "player_incapacitated")
e.net["sky_phone:player:status"]({ dead = false, cuffed = false })
assert(guard.GetBlockReason(1) == nil, "Rapid valid revive reports must clear legacy state")
e.net["sky_phone:player:status"]({ dead = "false", cuffed = false })
assert(guard.GetBlockReason(1) == nil)
e.health[1] = 0; assert(guard.GetBlockReason(1) == "player_incapacitated")
e.health[1] = 200
e.metadata[1] = { isdead = true }; guard.Check(1)
e.net["sky_phone:player:status"]({ dead = false, cuffed = false })
e.metadata[1] = {}; assert(guard.GetBlockReason(1) == nil)
local event_count = #e.events
e.metadata[1] = { isdead = true }; guard.Check(1)
assert(#e.events > event_count, "A new death after revival must reapply cleanup")
print("PASS server state: native death, metadata, Sky state bags, cuff/death separation, mute isolation and self-only reports")

-- Client detects native ESX cuffs even without an export or after resource restart.
local c = env()
c.LocalPlayer = { state = {} }
c.PlayerPedId = function() return 1 end
local native_cuffed, native_dead = false, false
c.IsPedCuffed = function() return native_cuffed end
c.IsEntityDead = function() return native_dead end
c.TriggerServerEvent = function(name, data) c.report = data end
c.SetTimeout = function(_, fn) fn() end
load(c, "shared/player_state.lua"); load(c, "bridge/client/player_state.lua")
native_cuffed = true
assert(c.Bridge.PlayerState.GetBlockReason() == "player_cuffed")
tick(c.threads[1]); tick(c.threads[1]); assert(c.report.cuffed)
native_cuffed = false; tick(c.threads[1]); assert(not c.report.cuffed)
c.exports = setmetatable({}, { __index = function(_, resource)
    error("Player status must not access an export: " .. resource)
end })
c.Bridge.Framework.GetName = function() return "esx" end
c.TriggerEvent("esx:onPlayerDeath")
assert(c.Bridge.PlayerState.GetBlockReason() == "player_incapacitated", "Legacy ESX death must work without a medical bag")
c.TriggerEvent("esx:onPlayerSpawn")
assert(c.Bridge.PlayerState.GetBlockReason() == nil, "The ESX spawn event must clear its death state")
for _, key in ipairs({ "dead", "isdead", "isDead" }) do
    c.LocalPlayer.state[key] = true
    tick(c.threads[1])
    assert(c.report.dead and c.Bridge.PlayerState.GetBlockReason() == "player_incapacitated", key)
    c.LocalPlayer.state[key] = false
    tick(c.threads[1])
    assert(not c.report.dead and c.Bridge.PlayerState.GetBlockReason() == nil, key .. " revive")
end
c.LocalPlayer.state = { ishandcuffed = true }
tick(c.threads[1])
assert(c.report.cuffed and not c.report.dead, "Client must report framework cuffs separately from death")
assert(c.Bridge.PlayerState.GetBlockReason() == "player_cuffed")
c.Config.Phone.BlockWhenCuffed = false
assert(c.Bridge.PlayerState.GetBlockReason() == nil)
for _, key in ipairs({ "ishandcuffed", "invBusy", "inv_busy", "busy", "isDead" }) do
    c.LocalPlayer.state[key] = false
end
tick(c.threads[1]); assert(not c.report.cuffed and not c.report.dead)
c.Config.Phone.BlockWhenCuffed = true
native_dead = true; assert(c.Bridge.PlayerState.GetBlockReason() == "player_incapacitated")
print("PASS client state: cuffs, state-change reports, native death and ESX revive")

-- Execute each real framework server adapter against its documented player API.
for _, name in ipairs({ "esx", "qb", "qbox" }) do
    local f = env(); f.Bridge.Framework.Name = name
    f.resources.es_extended = "started"
    local player = { PlayerData = { metadata = { isdead = true, inlaststand = true, ishandcuffed = true } },
        get = function(key) return key == "dead" end }
    f.exports.es_extended = { getSharedObject = function() return { GetPlayerFromId = function() return player end } end }
    f.exports["qb-core"] = { GetCoreObject = function() return { Functions = { GetPlayer = function() return player end } } end }
    f.exports.qbx_core = { GetPlayer = function() return player end }
    load(f, "bridge/server/frameworks/" .. name .. ".lua")
    local status = f.Bridge.Framework.GetStatusData(1)
    assert(status.dead or status.isdead, name)
    if name ~= "esx" then assert(status.inlaststand and status.ishandcuffed, name) end
    if name == "esx" then
        player.get = function() return nil end
        player.dead = true
        assert(f.Bridge.Framework.GetStatusData(1).dead, "ESX xPlayer.dead must be respected")
    end
end
print("PASS real ESX/QBCore/Qbox status adapters")

-- Execute the actual server voice bridge for all three public radio APIs.
for _, provider in ipairs({ "pma", "yaca", "saltychat" }) do
    local v = env(); v.Config.Radio.VoiceProvider = provider
    local resource = ({ pma = "pma-voice", yaca = "yaca-voice", saltychat = "saltychat" })[provider]
    v.resources[resource] = "started"
    local removed = {}
    v.exports[resource] = {
        setPlayerRadio = function(_, src, freq) assert(src == 1 and freq == 0); removed.primary = true end,
        setPlayerRadioChannel = function(_, src, channel, freq) assert(src == 1 and freq == "0"); removed[channel] = true end,
        SetPlayerRadioChannel = function(_, src, freq, primary) assert(src == 1 and freq == ""); removed[primary and 1 or 2] = true end,
        SetPlayerRadioSpeaker = function(_, src, enabled) assert(src == 1 and not enabled) end,
    }
    load(v, "bridge/server/voice.lua")
    assert(v.Bridge.Radio.DisconnectPlayer(1))
    assert(provider == "pma" and removed.primary or removed[1] and removed[2], provider)
end
print("PASS PMA, Yaca and Salty server radio membership cleanup")

-- Real radio callbacks and periodic inventory enforcement, including a SQL-yield race.
local r = env()
r.IsDuplicityVersion = function() return false end
r.vector3 = function() return {} end
assert(loadfile("sky_phone/config/config.lua", "t", r))()
r.callbacks, r.disconnects, r.item_queries = {}, 0, 0
local owned = true
r.Bridge.Inventory = { GetSlotsWithItem = function(_, item)
    assert(item == r.Config.Phone.Item); r.item_queries = r.item_queries + 1
    return owned and { { count = 1 } } or {}
end }
r.Bridge.Framework.GetIdentifier = function(src) return "player-" .. src end
r.Bridge.Framework.GetJob = function() return { name = "civilian", grade = 0 } end
r.Bridge.Framework.GetCharacterName = function() return "Test", "Player" end
r.Bridge.Callbacks = { Register = function(name, fn) r.callbacks[name] = fn end }
r.Bridge.Radio = { SupportsSecondary = function() return true end, SupportsSpeaker = function() return true end,
    SetPlayerSpeaker = function() return true end, DisconnectPlayer = function() r.disconnects = r.disconnects + 1 end }
local on_query
r.Bridge.Database = { Query = function() if on_query then local fn = on_query; on_query = nil; fn() end; return {} end }
r.json = { encode = function() return "{}" end }
load(r, "shared/player_state.lua"); load(r, "bridge/server/player_state.lua"); load(r, "server/radio.lua")
local connect = r.callbacks["sky_phone:radio:connect"]
local get = r.callbacks["sky_phone:radio:get"]
local function join() r.now = r.now + 1000; return connect(1, { frequency = 150, secondaryFrequency = 160 }) end
tick(r.threads[1]); tick(r.threads[1]); assert(r.item_queries == 0, "Idle users must not trigger inventory scans")
assert(join().success)
local before = r.item_queries; tick(r.threads[1]); assert(r.item_queries == before + 1, "One item check per connected user and tick")
owned = false; tick(r.threads[1])
assert(r.disconnects == 1 and not get(1).data.connected and get(1).data.savedFrequency == 0)
assert(join().error == "phone_not_owned")
r.Config.Radio.RequirePhoneItem = false
before = r.item_queries; assert(join().success); tick(r.threads[1]); assert(r.item_queries == before)
r.players[1] = { dead = true, isdead = true }
tick(r.threads[1]); assert(not get(1).data.connected)
assert(join().error == "player_incapacitated")
r.Config.Phone.BlockWhenDead = false; assert(join().success)
r.players[1] = { dead = false, isdead = false, ishandcuffed = true }
r.Config.Phone.BlockWhenDead = true
tick(r.threads[1]); assert(not get(1).data.connected)
assert(join().error == "player_cuffed")
r.Config.Phone.BlockWhenCuffed = false; assert(join().success)
r.Config.Radio.RequirePhoneItem = true
r.TriggerEvent("sky_phone:configurator:serverUpdated"); assert(not get(1).data.connected)
owned = true; r.metadata[1] = {}; r.players[1] = {}; r.Config.Phone.BlockWhenCuffed = true
on_query = function() r.metadata[1] = { ishandcuffed = true } end
assert(join().error == "player_cuffed", "SQL completion must not reconnect a newly cuffed player")
assert(not get(1).data.connected)
print("PASS radio: idle cost, phone removal, both frequencies, independent toggles, live config, async revalidation")
