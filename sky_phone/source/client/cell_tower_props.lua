local visuals = {}
local models = {}
local generation = 0
local revision = -1
local interacting = false
local locale = SkyPhoneLocales.Resolve(Config.Bridge.Locale)

local function remove_visual(key)
    local visual = visuals[key]
    if not visual then return end
    for _, entity in ipairs({ visual.tower, visual.door, visual.panel }) do
        DeleteEntity(entity)
    end
    visuals[key] = nil
end

local function notify_failure(response)
    local reason = response and response.error or "request_failed"
    Bridge.Notifications.Show(locale.CellTower.Title,
        locale.CellTower.Errors[reason] or locale.CellTower.Errors.request_failed, "error")
end

local function create_prop(model, position, heading)
    local entity = CreateObjectNoOffset(model, position.x, position.y, position.z, false, false, false)
    if entity == 0 then error(("[sky_phone] Failed to create cell tower model %s."):format(model)) end
    SetEntityHeading(entity, heading)
    FreezeEntityPosition(entity, true)
    return entity
end

local function apply_state(payload)
    if payload.revision <= revision then return end
    revision = payload.revision
    SkyPhoneCellular.TowerStates = payload.states
    SendNUIMessage({ type = "cellular:update", data = SkyPhoneCellular.GetPayload() })
    for key, visual in pairs(visuals) do
        local state = payload.states[key]
        if not state then
            remove_visual(key)
        else
            if state.damaged ~= visual.damaged then
                DeleteEntity(visual.panel)
                visual.panel = create_prop(state.damaged and models.Damaged or models.Intact,
                    SkyPhoneCellular.PropPosition(visual.definition, Config.CellTowers.Props.PanelOffset),
                    visual.definition.Heading or 0.0)
                visual.damaged = state.damaged
            end
            if visual.open ~= state.open then ClearEntityLastWeaponDamage(visual.panel) end
            visual.open = state.open
            SetEntityCanBeDamaged(visual.panel, Config.CellTowers.Props.Destructible and state.open and not state.damaged)
        end
    end
end

RegisterNetEvent("sky_phone:cellular:props", apply_state)

local function request_action(key, action, data)
    if interacting then return end
    interacting = true
    Bridge.HelpNotify.Hide("cell_tower")
    local current_generation = generation
    CreateThread(function()
        data.key = key
        local response = Bridge.Callbacks.Trigger("sky_phone:cellular:" .. action, data)
        if current_generation ~= generation then
            Bridge.Callbacks.Trigger("sky_phone:cellular:cancel", { key = key })
            interacting = false
            return
        end
        if response and response.success and response.data then
            local completed, failure = Bridge.Progressbar.Run({
                duration = response.data.duration,
                label = action == "repair" and locale.CellTower.RepairProgress or locale.CellTower.LockpickProgress,
                cancelLabel = locale.CellTower.Cancel,
                animation = { dict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", clip = "machinic_loop_mechandplayer" },
                valid = function()
                    if current_generation ~= generation then return false end
                    local visual, state = visuals[key], SkyPhoneCellular.TowerStates[key]
                    if not visual or not state then return false end
                    if action == "repair" and (not state.open or not state.damaged)
                        or action == "door" and state.open then return false end
                    return #(GetEntityCoords(PlayerPedId())
                        - SkyPhoneCellular.PropPosition(visual.definition, Config.CellTowers.Props.CabinetOffset)) <= 2.5
                end,
            })
            if completed then
                data.finish = true
                response = Bridge.Callbacks.Trigger("sky_phone:cellular:" .. action, data)
            else
                Bridge.Callbacks.Trigger("sky_phone:cellular:cancel", { key = key })
                if current_generation == generation then
                    if failure then notify_failure({ error = failure })
                    else Bridge.Notifications.Show(locale.CellTower.Title, locale.CellTower.ActionCancelled, "info") end
                end
                interacting = false
                return
            end
        end
        interacting = false
        if current_generation ~= generation then return end
        if not response or not response.success then notify_failure(response) return end
        local message = action == "repair" and locale.CellTower.Repaired
            or data.open and locale.CellTower.Unlocked or locale.CellTower.Closed
        Bridge.Notifications.Show(locale.CellTower.Title, message, "success")
    end)
end

local function configure()
    generation = generation + 1
    local current_generation = generation
    for key in pairs(visuals) do remove_visual(key) end
    Bridge.Progressbar.Cancel()
    Bridge.HelpNotify.Hide("cell_tower")
    locale = SkyPhoneLocales.Resolve(Config.Bridge.Locale)
    for _, model in pairs(models) do SetModelAsNoLongerNeeded(model) end
    models = {}
    if not Config.CellTowers.Enabled or not Config.CellTowers.Props.Enabled then return end
    local props = Config.CellTowers.Props
    for name, model in pairs(props.Models) do models[name] = joaat(model) end

    CreateThread(function()
        for name, model in pairs(models) do
            if not IsModelInCdimage(model) then
                error(("[sky_phone] Cell tower model '%s' is missing from the resource stream."):format(props.Models[name]))
            end
            RequestModel(model)
        end
        local deadline = GetGameTimer() + 10000
        for name, model in pairs(models) do
            while not HasModelLoaded(model) do
                if current_generation ~= generation then return end
                if GetGameTimer() > deadline then
                    error(("[sky_phone] Cell tower model '%s' failed to load."):format(props.Models[name]))
                end
                Wait(0)
            end
        end
        while current_generation == generation do
            local player_coords = GetEntityCoords(PlayerPedId())
            for _, tower in ipairs(Config.CellTowers.Towers) do
                local key = SkyPhoneCellular.TowerKey(tower)
                local state = SkyPhoneCellular.TowerStates[key]
                if #(player_coords - tower.Coords) <= 450.0 and state then
                    if not visuals[key] then
                        local heading = tower.Heading or 0.0
                        local visual = { definition = tower, angle = state.open and props.DoorOpenAngle or props.DoorClosedAngle,
                            damaged = state.damaged, open = state.open }
                        visual.tower = create_prop(models.Tower, tower.Coords, heading)
                        visual.door = create_prop(models.Door,
                            SkyPhoneCellular.PropPosition(tower, props.DoorOffset), heading + visual.angle)
                        visual.panel = create_prop(state.damaged and models.Damaged or models.Intact,
                            SkyPhoneCellular.PropPosition(tower, props.PanelOffset), heading)
                        SetEntityCanBeDamaged(visual.tower, false)
                        SetEntityCanBeDamaged(visual.door, false)
                        SetEntityCanBeDamaged(visual.panel, props.Destructible and state.open and not state.damaged)
                        visuals[key] = visual
                    end
                elseif visuals[key] then
                    remove_visual(key)
                end
            end
            Wait(500)
        end
    end)

    CreateThread(function()
        local previous_time = GetGameTimer()
        while current_generation == generation do
            local now = GetGameTimer()
            local step = math.min(now - previous_time, 100) * 0.15
            previous_time = now
            local wait_time = 100
            local ped = PlayerPedId()
            local player_coords = GetEntityCoords(ped)
            local nearest_key, nearest_distance = nil, 2.5
            for key, visual in pairs(visuals) do
                local state = SkyPhoneCellular.TowerStates[key]
                local target_angle = state.open and props.DoorOpenAngle or props.DoorClosedAngle
                if visual.angle ~= target_angle then
                    wait_time = 0
                    visual.angle = visual.angle < target_angle and math.min(visual.angle + step, target_angle)
                        or math.max(visual.angle - step, target_angle)
                    SetEntityHeading(visual.door, (visual.definition.Heading or 0.0) + visual.angle)
                end
                if props.Destructible and state.open and not state.damaged and not visual.damage_pending
                    and HasEntityBeenDamagedByWeapon(visual.panel, 0, 2) then
                    ClearEntityLastWeaponDamage(visual.panel)
                    visual.damage_pending = true
                    CreateThread(function()
                        local response = Bridge.Callbacks.Trigger("sky_phone:cellular:damage", { key = key })
                        visual.damage_pending = false
                        if not response or not response.success then
                            Bridge.Debug("debug", "[sky_phone] Cell tower damage report failed: %s.",
                                response and response.error or "request_failed")
                        end
                    end)
                end
                local distance = #(player_coords - SkyPhoneCellular.PropPosition(visual.definition, props.CabinetOffset))
                if distance < nearest_distance then nearest_key, nearest_distance = key, distance end
            end

            if nearest_key and not IsEntityDead(ped) and not IsPedInAnyVehicle(ped, false) and not interacting then
                wait_time = 0
                local state = SkyPhoneCellular.TowerStates[nearest_key]
                local help = state.open and (state.damaged and locale.CellTower.BrokenHelp or locale.CellTower.OpenHelp)
                    or locale.CellTower.ClosedHelp
                Bridge.HelpNotify.Show(help:gsub("^~INPUT_CONTEXT~%s*", ""):gsub("~INPUT_DETONATE~", "[G]"), "E", "cell_tower")
                if IsControlJustReleased(0, 38) then
                    request_action(nearest_key, "door", { open = not state.open })
                elseif state.open and state.damaged and IsControlJustReleased(0, 47) then
                    request_action(nearest_key, "repair", {})
                end
            elseif not interacting then
                Bridge.HelpNotify.Hide("cell_tower")
            end
            Wait(wait_time)
        end
    end)
end

AddEventHandler("sky_phone:configurator:updated", configure)
AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    generation = generation + 1
    Bridge.HelpNotify.Hide("cell_tower")
    Bridge.Progressbar.Cancel()
    for key in pairs(visuals) do remove_visual(key) end
    for _, model in pairs(models) do SetModelAsNoLongerNeeded(model) end
end)

CreateThread(function()
    local response = Bridge.Callbacks.Trigger("sky_phone:cellular:props", {})
    if not response or not response.success then error("[sky_phone] Failed to load cell tower state.") end
    apply_state(response.data)
    configure()
end)
