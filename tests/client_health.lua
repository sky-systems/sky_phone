local events, reports = {}, {}
local now = 0
local position = { x = 0.0, y = 0.0, z = 0.0 }
local movement = {}
local movement_queries = 0
local exists = true
local sampler

Config = { Health = {
    SampleIntervalMs = 500,
    MaximumSpeedMetersPerSecond = 12.0,
    ReportIntervalSeconds = 30,
} }
Bridge = { Callbacks = { Trigger = function() return { success = true } end } }
function CreateThread(callback) sampler = coroutine.create(callback) end
function Wait(delay) return coroutine.yield(delay) end
function GetGameTimer() return now end
function PlayerPedId() return 7 end
function DoesEntityExist(ped) assert(ped == 7); return exists end
function GetEntityCoords(ped) assert(ped == 7); return position end
function GetCurrentResourceName() return "sky_phone" end
function AddEventHandler(name, callback) events[name] = callback end
function RegisterNUICallback() end
function RegisterNetEvent() end
function TriggerServerEvent(name, payload)
    assert(name == "sky_phone:health:record-activity")
    reports[#reports + 1] = payload
end
for native, key in pairs({
    IsPedOnFoot = "on_foot", IsPedDeadOrDying = "dead", IsPedFalling = "falling",
    IsPedRagdoll = "ragdoll", IsPedWalking = "walking", IsPedRunning = "running", IsPedSprinting = "sprinting",
}) do
    _G[native] = function(ped)
        assert(ped == 7)
        movement_queries = movement_queries + 1
        return movement[key] or false
    end
end

dofile("sky_phone/source/client/health.lua")
local function resume()
    local ok, delay = coroutine.resume(sampler)
    assert(ok, delay)
    assert(delay == Config.Health.SampleIntervalMs, "activity sampling cadence must remain configured")
end
local function sample(distance)
    now = now + Config.Health.SampleIntervalMs
    position = { x = position.x + (distance or 0.0), y = 0.0, z = 0.0 }
    resume()
end
local function flush()
    events.onResourceStop("sky_phone")
    return reports[#reports]
end

resume()
movement = { on_foot = true }
for _ = 1, 60 do sample() end
assert(movement_queries == 0, "stationary sampling must not query movement natives")
assert(#reports == 0, "standing still must not emit activity reports")

movement = { on_foot = true, walking = true }
for _ = 1, 4 do sample(0.75) end
local report = flush()
assert(report.steps == 4 and report.distanceMeters == 3 and report.activeSeconds == 2,
    "walking must retain the same steps, distance and elapsed activity")

movement = { on_foot = true, running = true }
for _ = 1, 4 do sample(1.0) end
report = flush()
assert(report.steps == 4 and report.distanceMeters == 4 and report.activeSeconds == 2,
    "running must retain its configured stride behavior")

movement = { on_foot = true, sprinting = true }
for _ = 1, 4 do sample(1.15) end
report = flush()
assert(report.steps == 4 and report.distanceMeters == 5 and report.activeSeconds == 2,
    "sprinting must retain its stride and reporting rounding")

local reports_before = #reports
local queries_before = movement_queries
sample(100.0)
assert(movement_queries == queries_before, "teleports must be rejected before querying movement state")
for _, excluded in ipairs({ "dead", "falling", "ragdoll", "vehicle", "stationary" }) do
    movement = { on_foot = excluded ~= "vehicle", walking = excluded ~= "stationary", [excluded] = true }
    sample(1.0)
end
flush()
assert(#reports == reports_before, "invalid movement states must not add activity")

movement = { on_foot = true, walking = true }
events.playerSpawned()
sample(3.0)
flush()
assert(#reports == reports_before, "respawning must reset the position baseline")
exists = false
sample()
exists = true
sample(3.0)
flush()
assert(#reports == reports_before, "a recreated player ped must establish a fresh baseline")
sample(0.75)
report = flush()
assert(#reports == reports_before + 1 and report.steps == 1, "valid activity must resume after a ped change")

print("Client health sampling tests passed (zero movement queries while stationary)")
