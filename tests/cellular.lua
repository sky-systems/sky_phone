-- Lua 5.4. Real coverage, policy and callback transport; clients cannot supply their position.
Config = {}
function IsDuplicityVersion() return true end
function vector3(x, y, z) return { x = x, y = y, z = z } end
dofile("sky_phone/config/config.lua")
dofile("sky_phone/source/shared/cellular.lua")
for app in pairs(Config.Apps) do
    assert(type(Config.CellTowers.OfflineApps[app]) == "boolean", "Missing default offline policy: " .. app)
end
local original = Config.CellTowers.Towers
assert(#original == 18)
for _, tower in ipairs(original) do
    assert(SkyPhoneCellular.Level(tower.Coords) == 1)
end
for _, point in ipairs({
    vector3(0, -1000, 0), vector3(-1600, -1000, 0), vector3(-1050, -2750, 0),
    vector3(1000, -2900, 0), vector3(1800, 3600, 0), vector3(-200, 6350, 0),
    vector3(4000, -4650, 0), vector3(4500, -4500, 0), vector3(5000, -5200, 0),
    vector3(5000, -5800, 0),
}) do assert(SkyPhoneCellular.Level(point) > 0, "Populated area has no coverage") end
assert(SkyPhoneCellular.Level(vector3(0, -6000, 0)) == 0, "Ocean must have dead zones")
Config.CellTowers.Towers = {
    { Coords = vector3(0, 0, 300), Range = 100 },
    { Coords = vector3(150, 0, 0), Range = 1000 },
}
assert(SkyPhoneCellular.Level(vector3(50, 0, 10000)) == 0.9, "Strongest coverage must win regardless of height")
assert(SkyPhoneCellular.Level(vector3(1150, 0, 0)) == 0, "Boundary is out of range")
Config.CellTowers.Towers = {}
assert(SkyPhoneCellular.Level(vector3(0, 0, 0)) == 0, "Empty enabled network must have no reception")
Config.CellTowers.Enabled = false
assert(SkyPhoneCellular.Level(vector3(0, 0, 0)) == 1, "Master switch must restore full reception")
Config.CellTowers.Enabled = true
for _, endpoint in ipairs({
    "calls:dial", "calls:answer", "calls:video", "messages:send", "messages:media",
    "feather:feed", "fliptok:publish", "picstagram:feed", "weazel-news:list",
    "banking:transfer", "crypto:execute", "crewlink:bootstrap", "weather:get",
    "custom-app:storage:set", "media:import:url", "music:add-youtube", "knoway:quote", "knoway:request",
}) do assert(SkyPhoneCellular.RequiresSignal(endpoint), endpoint .. " must require reception") end
for _, endpoint in ipairs({
    "contacts:list", "calls:recents", "messages:thread", "notes:create", "calendar:update",
    "camera:setActive", "media:requestUpload", "memos:requestUpload", "gallery:list",
    "music:bootstrap", "radio:connect", "map:setWaypoint", "health:overview",
    "admin:delete-social-post", "calls:hangup", "calls:decline", "realtime:leave",
    "close", "device:open", "navigation:state", "security:unlock",
    "knoway:bootstrap", "knoway:start", "knoway:cancel",
}) do assert(not SkyPhoneCellular.RequiresSignal(endpoint), endpoint .. " must work offline") end

Config.CellTowers.OfflineApps["offline-custom"] = true
assert(not SkyPhoneCellular.RequiresSignal("custom-app:storage:set", { appId = "offline-custom" }))
assert(SkyPhoneCellular.RequiresSignal("custom-app:storage:set", { appId = "online-custom" }))
assert(SkyPhoneCellular.RequiresSignal("custom-app:storage:set", { appId = {} }))

local handlers, response, called = {}, nil, 0
Bridge = {
    Debug = function() end,
    Callbacks = {},
    Network = { SendClient = function(_, _, _, result) response = result return true end },
}
function RegisterNetEvent(name, callback) handlers[name] = callback end
function GetPlayerPed(player) assert(player == "7") return 70 end
local position = vector3(200, 0, 0)
function GetEntityCoords(ped) assert(ped == 70) return position end
dofile("sky_phone/source/server/cellular.lua")
dofile("sky_phone/source/bridge/server/callbacks.lua")
Config.CellTowers.Towers = { { Coords = vector3(0, 0, 0), Range = 100 } }
Bridge.Callbacks.Register("sky_phone:banking:transfer", function()
    called = called + 1
    return { success = true }
end)
source = 7
handlers["sky_phone:bridge:callback:request"]("sky_phone:banking:transfer", 1, { coords = vector3(0, 0, 0) })
assert(response.error == "no_signal" and called == 0, "Spoofed client coordinates must not authorize requests")
position = vector3(50, 0, 0)
handlers["sky_phone:bridge:callback:request"]("sky_phone:banking:transfer", 2, {})
assert(response.success and called == 1, "Reception recovery must allow requests")
position = vector3(200, 0, 0)
Config.CellTowers.Enabled = false
handlers["sky_phone:bridge:callback:request"]("sky_phone:banking:transfer", 3, {})
assert(response.success and called == 2, "Master switch must bypass coverage server-side")
local knoway_called = 0
for _, action in ipairs({ "bootstrap", "start", "cancel", "quote", "request" }) do
    Bridge.Callbacks.Register("sky_phone:knoway:" .. action, function()
        knoway_called = knoway_called + 1
        return { success = true }
    end)
end
Config.CellTowers.Enabled = true
for _, offline in ipairs({ false, true }) do
    Config.CellTowers.OfflineApps.knoway = offline
    for _, action in ipairs({ "bootstrap", "start", "cancel" }) do
        handlers["sky_phone:bridge:callback:request"]("sky_phone:knoway:" .. action, 4, {})
        assert(response.success, "Accepted KnoWay rides must remain readable and controllable offline")
    end
    local before_booking = knoway_called
    for _, action in ipairs({ "quote", "request" }) do
        handlers["sky_phone:bridge:callback:request"]("sky_phone:knoway:" .. action, 5, {})
        assert(response.error == "no_signal" and knoway_called == before_booking,
            "New KnoWay bookings must require reception even when the app is marked offline")
    end
end
assert(knoway_called == 6)
position = vector3(50, 0, 0)
for _, action in ipairs({ "quote", "request" }) do
    handlers["sky_phone:bridge:callback:request"]("sky_phone:knoway:" .. action, 6, {})
    assert(response.success, "Reception recovery must restore KnoWay bookings")
end
position = vector3(200, 0, 0)
Config.CellTowers.Enabled = false
for _, action in ipairs({ "quote", "request" }) do
    handlers["sky_phone:bridge:callback:request"]("sky_phone:knoway:" .. action, 7, {})
    assert(response.success, "The cellular master switch must bypass KnoWay coverage requirements")
end
assert(knoway_called == 10)
print("Cellular coverage, offline policy and authoritative transport tests passed")
