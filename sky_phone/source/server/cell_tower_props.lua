local states = SkyPhoneCellular.TowerStates
local actions = {}
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
    actions = {}
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

-- Both timed actions share one reservation per cabinet. Inventory is checked
-- before starting and consumed only after an authorized, elapsed completion.
local function progress_action(player_source, data, state, kind)
    local props = Config.CellTowers.Props
    local item = kind == "repair" and props.RepairItem or props.LockpickItem
    local missing = kind == "repair" and "repair_item_required" or "lockpick_required"
    local not_ready = kind == "repair" and "repair_not_ready" or "lockpick_not_ready"
    local action = actions[data.key]
    if data.finish == true then
        if not action or action.source ~= player_source or action.kind ~= kind or GetGameTimer() < action.ends then
            return reject(player_source, not_ready)
        end
        actions[data.key] = nil
        state.busy = true
        local removed = Bridge.Inventory.RemoveItem(player_source, item, 1)
        state.busy = nil
        if removed ~= 1 then return reject(player_source, missing) end
        return { success = true }
    end
    if data.finish ~= nil and data.finish ~= false then return reject(player_source, "invalid_state") end
    if action then return reject(player_source, "busy") end
    state.busy = true
    local slots = Bridge.Inventory.GetSlotsWithItem(player_source, item)
    state.busy = nil
    if not next(slots) then return reject(player_source, missing) end
    local duration = (kind == "repair" and props.RepairSeconds or props.LockpickSeconds) * 1000
    action = { source = player_source, kind = kind, ends = GetGameTimer() + duration }
    actions[data.key] = action
    local function check_action()
        if actions[data.key] ~= action then return end
        local current = resolve_tower(player_source, data, 2.5)
        if not current or kind == "repair" and (not current.open or not current.damaged or not can_repair(player_source))
            or kind == "lockpick" and current.open or GetGameTimer() > action.ends + 15000 then
            actions[data.key] = nil
            return
        end
        SetTimeout(250, check_action)
    end
    SetTimeout(250, check_action)
    return { success = true, data = { duration = duration } }
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
        actions[data.key] = nil
    else
        local result = progress_action(player_source, data, state, "lockpick")
        if not result.success or not data.finish then return result end
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
    local result = progress_action(player_source, data, state, "repair")
    if not result.success or not data.finish then return result end
    state.damaged = false
    state.open = false
    damage[data.key] = nil
    SetResourceKvp("sky_phone:cell_towers:damage", json.encode(damage))
    publish()
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:cellular:cancel", function(player_source, data)
    if type(data) ~= "table" or type(data.key) ~= "string" then return reject(player_source, "invalid_tower") end
    local action = actions[data.key]
    if action and action.source == player_source then actions[data.key] = nil end
    return { success = true }
end)

AddEventHandler("playerDropped", function()
    local player_source = source
    for key, action in pairs(actions) do
        if action.source == player_source then actions[key] = nil end
    end
end)
AddEventHandler("sky_phone:configurator:serverUpdated", reconcile)
Citizen.Await(SkyPhoneConfigurator.Ready)
reconcile()
ready:resolve(true)
