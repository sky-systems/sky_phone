local reports, applied, last_reports = {}, {}, {}

function Bridge.PlayerState.Get(player_source)
    local player = Player(player_source)
    local context = {
        isServer = true,
        source = player_source,
        ped = GetPlayerPed(player_source),
        state = player and player.state or {},
        framework = Bridge.Framework.GetStatusData(player_source) or {},
        report = reports[player_source] or {},
        legacyDead = false,
    }
    return {
        dead = PhoneFunctions.IsDead(context),
        cuffed = PhoneFunctions.IsHandcuffed(context),
    }
end

function Bridge.PlayerState.GetBlockReason(player_source)
    if Config.Phone.BlockWhenDead == false and Config.Phone.BlockWhenCuffed == false then return nil end
    local reason = Bridge.PlayerState.Reason(Bridge.PlayerState.Get(player_source))
    -- Admission after revival also resets the transition latch if all old
    -- sessions ended before the server observed the clear status report.
    if not reason then applied[player_source] = nil end
    return reason
end

function Bridge.PlayerState.Check(player_source)
    local reason = Bridge.PlayerState.GetBlockReason(player_source)
    if reason ~= applied[player_source] then
        applied[player_source] = reason
        if reason then
            TriggerEvent("sky_phone:player:restricted", player_source, reason)
            TriggerClientEvent("sky_phone:player:restricted", player_source, reason)
        end
    end
    return reason
end

-- Legacy ESX police/death state is client-owned. A report can only restrict its
-- sender; false never overrides server metadata, replicated state or ped health.
RegisterNetEvent("sky_phone:player:status", function(data)
    local player_source = source
    if type(data) ~= "table" or type(data.dead) ~= "boolean" or type(data.cuffed) ~= "boolean" then return end
    local now = GetGameTimer()
    local quota = last_reports[player_source]
    if not quota or now - quota.at >= 1000 then quota = { at = now, count = 0 }; last_reports[player_source] = quota end
    quota.count = quota.count + 1
    if quota.count > 20 then return end
    reports[player_source] = { dead = data.dead, cuffed = data.cuffed }
    Bridge.PlayerState.Check(player_source)
end)

AddEventHandler("playerDropped", function()
    reports[source], applied[source], last_reports[source] = nil, nil, nil
end)
AddEventHandler("sky_phone:configurator:serverUpdated", function()
    applied = {}
    for player_source in pairs(reports) do Bridge.PlayerState.Check(player_source) end
end)
