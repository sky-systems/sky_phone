-- Run from the repository root with Lua 5.4.
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end

local function new_client(loaded)
    local e = setmetatable({}, { __index = _G })
    e.Config = { Bridge = { Framework = "esx" } }
    e.Bridge = { Framework = {} }
    e.handlers, e.reads, e.exports_read = {}, 0, 0
    e.loaded, e.invoker = loaded, "es_extended"
    e.player = { dead = false, job = { name = "police" }, inventory = { { name = "phone", count = 1 } },
        loadout = {}, custom = { restricted = false } }
    e.GetInvokingResource = function() return e.invoker end
    e.GetResourceState = function() return "started" end
    e.AddEventHandler = function(name, fn)
        e.handlers[name] = e.handlers[name] or {}
        table.insert(e.handlers[name], fn)
    end
    e.RegisterNetEvent = e.AddEventHandler
    e.emit = function(name, ...)
        for _, fn in ipairs(e.handlers[name] or {}) do fn(...) end
    end
    e.exports = {
        es_extended = { getSharedObject = function()
            e.exports_read = e.exports_read + 1
            return {
                IsPlayerLoaded = function() return e.loaded end,
                GetPlayerData = function() e.reads = e.reads + 1; return copy(e.player) end,
            }
        end },
        qbx_core = { GetPlayerData = function() return { metadata = e.qb_metadata } end },
        ["qb-core"] = { GetCoreObject = function()
            return { Functions = { GetPlayerData = function() return { metadata = e.qb_metadata } end } }
        end },
    }
    assert(loadfile("sky_phone/source/bridge/client/framework.lua", "t", e))()
    return e
end

local e = new_client(true)
for _ = 1, 100 do
    local data = e.Bridge.Framework.GetStatusData()
    assert(data.job.name == "police" and data.inventory[1].count == 1 and not data.custom.restricted)
end
assert(e.reads == 1 and e.exports_read == 1, "status polling must not repeatedly serialize ESX PlayerData")
e.emit("esx:setPlayerData", "dead", true)
assert(e.Bridge.Framework.GetStatusData().dead)
e.emit("esx:setPlayerData", "dead", false)
assert(e.Bridge.Framework.GetStatusData().dead == false)
e.emit("esx:setPlayerData", "custom", { restricted = true })
assert(e.Bridge.Framework.GetStatusData().custom.restricted)
e.emit("esx:setPlayerData", "custom", nil)
assert(e.Bridge.Framework.GetStatusData().custom == nil)
e.invoker = "another_resource"
e.emit("esx:setPlayerData", "dead", true)
assert(e.Bridge.Framework.GetStatusData().dead == false, "only ESX owns its player-data events")
e.invoker = "es_extended"
e.emit("esx:addInventoryItem", "phone", 5)
assert(e.Bridge.Framework.GetStatusData().inventory[1].count == 5)
e.emit("esx:removeInventoryItem", "phone", 2)
assert(e.Bridge.Framework.GetStatusData().inventory[1].count == 2, "inventory counts are totals")
e.emit("esx:addInventoryItem", "phone", false)
assert(e.Bridge.Framework.GetStatusData().inventory[1].count == 2, "notification-only events do not change inventory")
e.emit("esx:addLoadoutItem", "WEAPON_PISTOL", "Pistol", 12)
local weapon = e.Bridge.Framework.GetStatusData().loadout[1]
assert(weapon.name == "WEAPON_PISTOL" and weapon.ammo == 12 and weapon.tintIndex == 0)
e.emit("esx:removeLoadoutItem", "WEAPON_PISTOL")
assert(#e.Bridge.Framework.GetStatusData().loadout == 0)
e.emit("esx:setPlayerData", "inventory", { [4] = { name = "phone", count = 3 } })
assert(e.Bridge.Framework.GetStatusData().inventory[4].count == 3, "custom inventory replacements must propagate")
assert(e.reads == 1, "ESX events must update status without fetching the complete snapshot again")
print("PASS: one ESX read across 100 polls; immediate status/custom/inventory/loadout updates")

e.emit("esx:onPlayerLogout")
assert(next(e.Bridge.Framework.GetStatusData()) == nil and e.reads == 1,
    "logout must not refill the previous character from stale ESX PlayerData")
e.emit("esx:playerLoaded", { dead = true, job = { name = "ambulance" }, inventory = {}, loadout = {} })
assert(e.Bridge.Framework.GetStatusData().dead and e.Bridge.Framework.GetStatusData().job.name == "ambulance")
e.emit("onClientResourceStop", "unrelated")
assert(e.Bridge.Framework.GetStatusData().dead)
e.emit("onClientResourceStop", "es_extended")
assert(next(e.Bridge.Framework.GetStatusData()) == nil and e.exports_read == 1)
e.player = { dead = false, inventory = {}, loadout = {}, character = "new" }
e.emit("onClientResourceStart", "es_extended")
assert(e.Bridge.Framework.GetStatusData().character == "new" and e.reads == 2 and e.exports_read == 2)
e.Config.Bridge.Framework = "qbox"
e.qb_metadata = { inlaststand = true }
e.emit("sky_phone:configurator:updated")
assert(e.Bridge.Framework.GetStatusData() == e.qb_metadata)
e.Config.Bridge.Framework = "qb"
e.emit("sky_phone:configurator:updated")
assert(e.Bridge.Framework.GetStatusData() == e.qb_metadata)
e.Config.Bridge.Framework = "esx"
e.emit("sky_phone:configurator:updated")
assert(e.Bridge.Framework.GetStatusData().character == "new" and e.reads == 3)
local before_login = new_client(false)
assert(next(before_login.Bridge.Framework.GetStatusData()) == nil and before_login.reads == 0)
before_login.emit("esx:playerLoaded", { dead = true })
assert(before_login.Bridge.Framework.GetStatusData().dead)
local during_spawn = new_client(false)
assert(next(during_spawn.Bridge.Framework.GetStatusData()) == nil)
during_spawn.loaded = true
assert(during_spawn.Bridge.Framework.GetStatusData().job.name == "police" and during_spawn.reads == 1,
    "a phone restart after playerLoaded but before ESX finishes spawning must still initialize")
print("PASS: logout, character switch, provider restart, initial login and QB/Qbox contracts")

local reads = {}
e.IsEntityDead, e.IsPedCuffed = function() return false end, function() return false end
assert(loadfile("sky_phone/config/functions.lua", "t", e))()
local state = setmetatable({}, { __index = function(_, key)
    reads[key] = (reads[key] or 0) + 1
    return false
end })
local context = { isServer = false, ped = 1, state = state, framework = {}, report = {} }
assert(not e.PhoneFunctions.IsDead(context) and not e.PhoneFunctions.IsHandcuffed(context))
local count = 0
for key, amount in pairs(reads) do
    assert(amount == 1, "state-bag flag read twice: " .. key)
    count = count + 1
end
assert(count == 10)
print("PASS: each of the 10 state-bag flags is read once per status check")
