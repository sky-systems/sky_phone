local states = SkyPhoneCellular.TowerStates
local repairs = {}
local revision = 0
local ready = promise.new()
local stored_damage = GetResourceKvpString("sky_phone:cell_towers:damage")
local damage = stored_damage and json.decode(stored_damage) or {}

local function publish()
    revision = revision + 1
    Bridge.Network.SendClient("sky_phone:cellular:props", -1, { revision = revision, states = states })
end

local function reconcile()
    local configured = {}
    for _, tower in ipairs(Config.CellTowers.Towers) do
        local key = SkyPhoneCellular.TowerKey(tower)
        configured[key] = true
        states[key] = states[key] or { open = false, damaged = damage[key] == true }
    end
    for key in pairs(states) do
        if not configured[key] then states[key] = nil end
    end
    for key in pairs(damage) do
        if not configured[key] then damage[key] = nil end
    end
    repairs = {}
    SetResourceKvp("sky_phone:cell_towers:damage", json.encode(damage))
    publish()
end

local function reject(player_source, reason)
    Bridge.Debug("debug", "[sky_phone] Cell tower action rejected for source %s: %s.", tostring(player_source), reason)
    return { success = false, error = reason }
end

local function resolve_tower(player_source, data, maximum_distance)
    Citizen.Await(ready)
    if not Config.CellTowers.Enabled or not Config.CellTowers.Props.Enabled then return nil, "disabled" end
    if type(data) ~= "table" or type(data.key) ~= "string" or #data.key > 80 then return nil, "invalid_tower" end
    local state = states[data.key]
    if not state then return nil, "invalid_tower" end
    if state.busy then return nil, "busy" end
    if GetPlayerRoutingBucket(player_source) ~= 0 then return nil, "too_far" end
    local ped = GetPlayerPed(tostring(player_source))
    if ped == 0 or GetEntityHealth(ped) <= 0 then return nil, "player_unavailable" end
    for _, tower in ipairs(Config.CellTowers.Towers) do
        if SkyPhoneCellular.TowerKey(tower) == data.key then
            local position = SkyPhoneCellular.PropPosition(tower, Config.CellTowers.Props.CabinetOffset)
            if #(GetEntityCoords(ped) - position) > maximum_distance then return nil, "too_far" end
            return state
        end
    end
    return nil, "invalid_tower"
end

local function can_repair(player_source)
    local jobs = Config.CellTowers.Props.RepairJobs
    if #jobs == 0 then return true end
    local job = Bridge.Framework.GetJob(player_source).name
    for _, allowed in ipairs(jobs) do
        if job == allowed then return true end
    end
    return false
end

Bridge.Callbacks.Register("sky_phone:cellular:props", function()
    Citizen.Await(ready)
    return { success = true, data = { revision = revision, states = states } }
end)

Bridge.Callbacks.Register("sky_phone:cellular:door", function(player_source, data)
    local state, reason = resolve_tower(player_source, data, 2.5)
    if not state then return reject(player_source, reason) end
    if type(data.open) ~= "boolean" or data.open == state.open then return reject(player_source, "invalid_state") end
    if state.open then
        state.open = false
        repairs[data.key] = nil
    else
        state.busy = true
        local removed = Bridge.Inventory.RemoveItem(player_source, Config.CellTowers.Props.LockpickItem, 1)
        state.busy = nil
        if removed ~= 1 then return reject(player_source, "lockpick_required") end
        state.open = true
    end
    publish()
    return { success = true }
end)

-- GTA weapon collision is detected by the client that simulates the local
-- panel. The server owns the permitted transition and validates proximity,
-- routing bucket and the unlocked state; this report is not anti-cheat proof.
Bridge.Callbacks.Register("sky_phone:cellular:damage", function(player_source, data)
    local state, reason = resolve_tower(player_source, data, 500.0)
    if not state then return reject(player_source, reason) end
    if not Config.CellTowers.Props.Destructible then return reject(player_source, "indestructible") end
    if not state.open or state.damaged then return reject(player_source, "invalid_state") end
    state.damaged = true
    damage[data.key] = true
    SetResourceKvp("sky_phone:cell_towers:damage", json.encode(damage))
    publish()
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:cellular:repair", function(player_source, data)
    local state, reason = resolve_tower(player_source, data, 2.5)
    if not state then return reject(player_source, reason) end
    if not can_repair(player_source) then return reject(player_source, "not_authorized") end
    if not state.open or not state.damaged then return reject(player_source, "invalid_state") end
    local repair = repairs[data.key]
    if data.finish == true then
        if not repair or repair.source ~= player_source or GetGameTimer() < repair.ends then
            return reject(player_source, "repair_not_ready")
        end
        repairs[data.key] = nil
        state.busy = true
        local removed = Bridge.Inventory.RemoveItem(player_source, Config.CellTowers.Props.RepairItem, 1)
        state.busy = nil
        if removed ~= 1 then return reject(player_source, "repair_item_required") end
        state.damaged = false
        state.open = false
        damage[data.key] = nil
        SetResourceKvp("sky_phone:cell_towers:damage", json.encode(damage))
        publish()
        return { success = true }
    end
    if data.finish ~= nil and data.finish ~= false then return reject(player_source, "invalid_state") end
    if repair then return reject(player_source, "busy") end
    state.busy = true
    local parts = Bridge.Inventory.GetSlotsWithItem(player_source, Config.CellTowers.Props.RepairItem)
    state.busy = nil
    if not next(parts) then
        return reject(player_source, "repair_item_required")
    end
    local duration = Config.CellTowers.Props.RepairSeconds * 1000
    repair = { source = player_source, ends = GetGameTimer() + duration }
    repairs[data.key] = repair
    local function check_repair()
        if repairs[data.key] ~= repair then return end
        local current = resolve_tower(player_source, data, 2.5)
        if not current or not current.open or not current.damaged or not can_repair(player_source)
            or GetGameTimer() > repair.ends + 5000 then
            repairs[data.key] = nil
            return
        end
        SetTimeout(250, check_repair)
    end
    SetTimeout(250, check_repair)
    return { success = true, data = { duration = duration } }
end)

AddEventHandler("playerDropped", function()
    local player_source = source
    for key, repair in pairs(repairs) do
        if repair.source == player_source then repairs[key] = nil end
    end
end)
AddEventHandler("sky_phone:configurator:serverUpdated", reconcile)
Citizen.Await(SkyPhoneConfigurator.Ready)
reconcile()
ready:resolve(true)
