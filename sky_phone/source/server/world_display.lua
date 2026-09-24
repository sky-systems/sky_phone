-- Only pixels travel to spectators. Never send DOM, credentials or account state.
local sessions, attempts = {}, {}
local generation = 0

local function nearby(source, target)
    if GetPlayerRoutingBucket(source) ~= GetPlayerRoutingBucket(target) then return false end
    local a, b = GetPlayerPed(source), GetPlayerPed(target)
    if a == 0 or b == 0 then return false end
    return #(GetEntityCoords(a) - GetEntityCoords(b)) <= SkyPhoneProp.Range
end

local function valid_prop(source, net)
    if type(net) ~= "number" or net % 1 ~= 0 or net <= 0 or net > 65535 then return false end
    local entity, ped = NetworkGetEntityFromNetworkId(net), GetPlayerPed(source)
    if entity == 0 or ped == 0 or not DoesEntityExist(entity) then return false end
    if NetworkGetEntityOwner(entity) ~= source or not SkyPhoneProp.Models[GetEntityModel(entity)] then return false end
    return #(GetEntityCoords(entity) - GetEntityCoords(ped)) < 1.5
end

local function stop(source)
    local session = sessions[source]
    if not session then return end
    sessions[source] = nil
    for target in pairs(session.viewers) do
        TriggerClientEvent("sky_phone:display:stop", target, source, session.token, session.sequence)
    end
    TriggerClientEvent("sky_phone:display:permit", source, nil)
end

RegisterNetEvent("sky_phone:display:begin", function(net)
    if not SkyPhoneProp.DisplayEnabled() then return end
    local player = source
    local now = GetGameTimer()
    if attempts[player] and now - attempts[player] < 900 then return end
    attempts[player] = now
    if not SkyPhone or not SkyPhone.RequireDeviceSession(player) or not valid_prop(player, net) then return end
    if sessions[player] and sessions[player].net == net then
        TriggerClientEvent("sky_phone:display:permit", player, sessions[player].token, net)
        return
    end
    stop(player)
    generation = generation + 1
    sessions[player] = { token = generation, net = net, sequence = 0, viewers = {}, last = now, received = now - 500 }
    TriggerClientEvent("sky_phone:display:permit", player, generation, net)
end)

RegisterNetEvent("sky_phone:display:end", function(token)
    local session = sessions[source]
    if session and session.token == token then stop(source) end
end)

RegisterNetEvent("sky_phone:display:frame", function(token, sequence, jpeg)
    local player = source
    if not SkyPhoneProp.DisplayEnabled() then stop(player); return end
    local session, now = sessions[player], GetGameTimer()
    if not session or token ~= session.token then return end
    if type(sequence) ~= "number" or sequence % 1 ~= 0 or sequence <= session.sequence or sequence > 2147483647 then return end
    if now - session.received < SkyPhoneProp.IntervalMs - 40 then return end
    session.received = now
    if not SkyPhoneProp.ValidFrame(jpeg) then return end
    if not SkyPhone or not SkyPhone.RequireDeviceSession(player) or not valid_prop(player, session.net) then
        stop(player)
        return
    end
    session.sequence, session.last = sequence, now
    local viewers = {}
    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)
        if target ~= player and nearby(player, target) then
            viewers[target] = true
            TriggerLatentClientEvent("sky_phone:display:frame", target, 160000,
                player, session.token, session.net, sequence, jpeg)
        end
    end
    for target in pairs(session.viewers) do
        if not viewers[target] then TriggerClientEvent("sky_phone:display:stop", target, player, token, session.sequence) end
    end
    session.viewers = viewers
end)

CreateThread(function()
    while true do
        Wait(1000)
        local now = GetGameTimer()
        for player, session in pairs(sessions) do
            if not SkyPhoneProp.DisplayEnabled() or now - session.last > 5000 or not valid_prop(player, session.net)
                or not SkyPhone or not SkyPhone.RequireDeviceSession(player) then
                stop(player)
            else
                for target in pairs(session.viewers) do
                    if not nearby(player, target) then
                        TriggerClientEvent("sky_phone:display:stop", target, player, session.token, session.sequence)
                        session.viewers[target] = nil
                    end
                end
            end
        end
    end
end)

AddEventHandler("sky_phone:configurator:serverUpdated", function()
    if SkyPhoneProp.DisplayEnabled() then return end
    for player in pairs(sessions) do stop(player) end
end)

AddEventHandler("playerDropped", function()
    stop(source)
    attempts[source] = nil
    for _, session in pairs(sessions) do session.viewers[source] = nil end
end)
AddEventHandler("sky_phone:player:restricted", function(player) stop(player) end)
