-- Lua 5.4: execute the actual shared/server modules against inventory and clock fakes.
local vector_meta = {}
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, vector_meta) end
vector_meta.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, a.z - b.z) end
vector_meta.__len = function(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end
function joaat(value) return value end
promise = { new = function()
    return { resolve = function(self) self.resolved = true end }
end }
Citizen = { Await = function(pending)
    if not pending.resolved then coroutine.yield("awaiting_configuration") end
    assert(pending.resolved, "Configuration must finish loading before tower initialization")
end }
SkyPhoneConfigurator = { Ready = promise.new() }
SkyPhoneConfigurator.Ready:resolve(true)
Config = { Bridge = {}, CellTowers = {
    Enabled = true, Props = { Enabled = false, Destructible = true, LockpickItem = "lockpick",
        RepairItem = "radiotowerparts", RepairJobs = {}, RepairSeconds = 10,
        CabinetOffset = vector3(0, -1.55, 1.3) },
    Towers = { { Coords = vector3(0, 0, 0), Heading = 0, Range = 100 } },
} }
local callbacks, events, timers, saved = {}, {}, {}, nil
local now, bucket, health, broadcasts = 0, 0, 100, 0
local inventory, removed = { lockpick = 2, radiotowerparts = 2 }, { lockpick = 0, radiotowerparts = 0 }
local position, job = vector3(0, -1.55, 1.3), "unemployed"
local during_remove, during_check
function GetGameTimer() return now end
function SetTimeout(delay, callback) timers[#timers + 1] = { at = now + delay, callback = callback } end
function AddEventHandler(name, callback) events[name] = callback end
function GetResourceKvpString() return saved end
function SetResourceKvp(_, value) saved = value end
function GetPlayerPed() return 10 end
function GetEntityHealth() return health end
function GetEntityCoords() return position end
function GetPlayerRoutingBucket() return bucket end
json = {
    encode = function(value)
        local copy = {}
        for key, state in pairs(value) do copy[key] = state end
        return copy
    end,
    decode = function(value) return value end,
}
Bridge = {
    Debug = function() end,
    Callbacks = { Register = function(name, callback) callbacks[name] = callback end },
    Network = { SendClient = function() broadcasts = broadcasts + 1 end },
    Framework = { GetJob = function() return { name = job } end },
    Inventory = {
        GetSlotsWithItem = function(_, item)
            assert(item == "radiotowerparts")
            if during_check then during_check() end
            return inventory[item] > 0 and { { slot = 2, count = inventory[item] } } or {}
        end,
        RemoveItem = function(_, item, count)
            assert(inventory[item] and count == 1)
            if during_remove then during_remove() end
            if inventory[item] == 0 then return 0 end
            inventory[item], removed[item] = inventory[item] - 1, removed[item] + 1
            return 1
        end,
    },
}
dofile("sky_phone/source/shared/cellular.lua")
dofile("sky_phone/source/shared/cell_tower_props.lua")
dofile("sky_phone/source/server/cell_tower_props.lua")
local key = SkyPhoneCellular.TowerKey(Config.CellTowers.Towers[1])
local function action(name, values, player)
    values = values or {}
    values.key = values.key or key
    return callbacks["sky_phone:cellular:" .. name](player or 7, values)
end
local function tick(milliseconds)
    local until_time = now + milliseconds
    while true do
        table.sort(timers, function(a, b) return a.at < b.at end)
        if not timers[1] or timers[1].at > until_time then break end
        local timer = table.remove(timers, 1)
        now = timer.at
        timer.callback()
    end
    now = until_time
end
assert(action("door", { open = true }).error == "disabled")
assert(removed.lockpick == 0 and Config.CellTowers.Props.Enabled == false)
Config.CellTowers.Props.Enabled = true
position = vector3(3000, 0, 0)
assert(action("door", { open = true, coords = vector3(0, 0, 0) }).error == "too_far")
position = vector3(0, -1.55, 1.3)
bucket = 1
assert(action("door", { open = true }).error == "too_far")
bucket = 0
assert(action("damage").error == "invalid_state", "Closed cabinet protects the interior")
inventory.lockpick = 0
assert(action("door", { open = true }).error == "lockpick_required")
inventory.lockpick = 2
during_remove = function()
    assert(action("door", { open = true }, 8).error == "busy", "Unlocking must serialize inventory consumption")
end
assert(action("door", { open = true }).success)
during_remove = nil
assert(removed.lockpick == 1 and inventory.lockpick == 1)
assert(action("door", { open = true }).error == "invalid_state")
Config.CellTowers.Props.Destructible = false
assert(action("damage").error == "indestructible")
assert(SkyPhoneCellular.Level(vector3(0, 0, 0)) == 1, "Indestructible towers retain coverage")
assert(not SkyPhoneCellular.TowerStates[key].damaged)
Config.CellTowers.Props.Destructible = true
assert(action("damage").success)
assert(SkyPhoneCellular.Level(vector3(0, 0, 0)) == 0, "Broken tower must cease providing coverage")
assert(action("damage").error == "invalid_state")
Config.CellTowers.Props.Destructible = false
assert(SkyPhoneCellular.Level(vector3(0, 0, 0)) == 0, "Disabling new damage does not repair existing damage")
Config.CellTowers.Towers[2] = { Coords = vector3(50, 0, 0), Heading = 0, Range = 100 }
events["sky_phone:configurator:serverUpdated"]()
assert(SkyPhoneCellular.Level(vector3(0, 0, 0)) == .5, "Healthy overlapping tower must remain available")
Config.CellTowers.Props.Enabled = false
assert(SkyPhoneCellular.Level(vector3(0, 0, 0)) == 1, "Disabling props restores virtual coverage")
Config.CellTowers.Props.Enabled = true
Config.CellTowers.Props.RepairJobs = { "mechanic" }
assert(action("repair").error == "not_authorized")
job = "mechanic"
assert(action("repair", { finish = true }).error == "repair_not_ready")
inventory.radiotowerparts = 0
assert(action("repair").error == "repair_item_required")
inventory.radiotowerparts = 2
during_check = function()
    assert(action("repair", nil, 8).error == "busy", "Inventory checks must serialize repair starts")
    assert(action("door", { open = false }).error == "busy")
end
assert(action("repair").data.duration == 10000)
during_check = nil
assert(inventory.radiotowerparts == 2 and removed.radiotowerparts == 0)
assert(action("repair", nil, 8).error == "busy")
assert(action("repair", { finish = true }).error == "repair_not_ready")
tick(4000)
position = vector3(20, 0, 0)
tick(250)
position = vector3(0, -1.55, 1.3)
tick(6000)
assert(action("repair", { finish = true }).error == "repair_not_ready", "Leaving cancels the server's repair")
assert(action("repair").success)
job = "unemployed"
tick(250)
job = "mechanic"
tick(10000)
assert(action("repair", { finish = true }).error == "repair_not_ready", "Losing the permitted job cancels repair")
assert(inventory.radiotowerparts == 2 and removed.radiotowerparts == 0, "Cancelled repairs consume no material")
Config.CellTowers.Props.RepairJobs = {}
job = "unemployed"
assert(action("repair").success)
tick(10000)
inventory.radiotowerparts = 0
assert(action("repair", { finish = true }).error == "repair_item_required")
assert(SkyPhoneCellular.TowerStates[key].damaged and removed.radiotowerparts == 0)
inventory.radiotowerparts = 2
assert(action("repair", { finish = true }).error == "repair_not_ready")
assert(action("repair").success)
tick(10000)
during_remove = function()
    assert(action("repair", { finish = true }).error == "busy", "Completing must consume material only once")
    assert(action("door", { open = false }).error == "busy")
end
assert(action("repair", { finish = true }).success)
during_remove = nil
assert(inventory.radiotowerparts == 1 and removed.radiotowerparts == 1)
assert(action("repair", { finish = true }).error == "invalid_state")
assert(removed.radiotowerparts == 1, "Repeated completion must not consume another part")
assert(SkyPhoneCellular.Level(vector3(0, 0, 0)) == 1 and not next(saved))
assert(not SkyPhoneCellular.TowerStates[key].open, "Repair closes the cabinet")
assert(action("door", { open = true }).success and removed.lockpick == 2)
Config.CellTowers.Props.Destructible = true
assert(action("damage").success)
Config.CellTowers.Towers[1], Config.CellTowers.Towers[2] = Config.CellTowers.Towers[2], Config.CellTowers.Towers[1]
events["sky_phone:configurator:serverUpdated"]()
assert(SkyPhoneCellular.TowerStates[key].damaged, "Reordering must preserve tower identity")
SkyPhoneCellular.TowerStates = {}
dofile("sky_phone/source/server/cell_tower_props.lua")
assert(SkyPhoneCellular.TowerStates[key].damaged and not SkyPhoneCellular.TowerStates[key].open,
    "Damage survives restart, while the cabinet is closed")
assert(broadcasts > 0)

-- Resource scripts continue loading while the configurator awaits its SQL row.
-- No default-site reconciliation may discard damage for a saved custom site.
local custom_tower = { Coords = vector3(200, 300, 40), Heading = 90, Range = 100 }
local custom_key = SkyPhoneCellular.TowerKey(custom_tower)
saved = { [custom_key] = true }
SkyPhoneCellular.TowerStates = {}
SkyPhoneConfigurator.Ready = promise.new()
local initialization = coroutine.create(function()
    dofile("sky_phone/source/server/cell_tower_props.lua")
end)
local started, waiting = coroutine.resume(initialization)
assert(started and waiting == "awaiting_configuration", "Tower initialization must await the saved config")
assert(saved[custom_key], "Loading defaults must not discard saved custom-site damage")
local initial_response
local initial_request = coroutine.create(function()
    initial_response = callbacks["sky_phone:cellular:props"]()
end)
local requested, request_waiting = coroutine.resume(initial_request)
assert(requested and request_waiting == "awaiting_configuration", "Clients must wait for reconciled tower states")
Config.CellTowers.Towers = { custom_tower }
SkyPhoneConfigurator.Ready:resolve(true)
local initialized, initialize_error = coroutine.resume(initialization)
assert(initialized, initialize_error)
assert(coroutine.status(initialization) == "dead")
local answered, answer_error = coroutine.resume(initial_request)
assert(answered, answer_error)
assert(initial_response.success and initial_response.data.states[custom_key].damaged)
assert(not initial_response.data.states[key] and saved[custom_key])
print("Physical cell tower inventory, damage, coverage, permission, repair and persistence tests passed")
