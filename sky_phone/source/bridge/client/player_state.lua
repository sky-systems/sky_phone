local esx_dead = false
local last_status, last_reason

function Bridge.PlayerState.Get()
    local bag = LocalPlayer.state
    local status = Bridge.PlayerState.FromData(bag)
    local flags = Bridge.PlayerState.FromData(Bridge.Framework.GetStatusData())
    local ped = PlayerPedId()
    local legacy_esx_dead = esx_dead and Bridge.Framework.GetName() == "esx"
    status.dead = status.dead or flags.dead or legacy_esx_dead or IsEntityDead(ped)
    status.cuffed = status.cuffed or flags.cuffed or IsPedCuffed(ped)
    return status
end

function Bridge.PlayerState.GetBlockReason()
    if Config.Phone.BlockWhenDead == false and Config.Phone.BlockWhenCuffed == false then return nil end
    return Bridge.PlayerState.Reason(Bridge.PlayerState.Get())
end

local function refresh(force)
    local status = Bridge.PlayerState.Get()
    local reason = Bridge.PlayerState.Reason(status)
    if reason and reason ~= last_reason then TriggerEvent("sky_phone:client:restricted", reason) end
    last_reason = reason
    if force or not last_status or last_status.dead ~= status.dead or last_status.cuffed ~= status.cuffed then
        last_status = status
        TriggerServerEvent("sky_phone:player:status", status)
    end
end

RegisterNetEvent("sky_phone:player:restricted", function(reason)
    TriggerEvent("sky_phone:client:restricted", reason)
end)
AddEventHandler("sky_phone:client:restricted", function()
    TriggerEvent("sky_phone:client:forceClose")
    TriggerEvent("sky_phone:animation:reset")
end)
AddEventHandler("esx:onPlayerDeath", function() esx_dead = true; refresh() end)
AddEventHandler("esx:onPlayerSpawn", function() esx_dead = false; refresh() end)
AddEventHandler("playerSpawned", function() esx_dead = false; refresh(true) end)
RegisterNetEvent("esx:playerLoaded", function() esx_dead = false; refresh(true) end)
RegisterNetEvent("QBCore:Player:SetPlayerData", function() SetTimeout(0, function() refresh() end) end)
AddEventHandler("sky_phone:configurator:updated", function() last_reason = nil; refresh(true) end)

-- No per-frame scan or inventory work. Native cuffs also catch legacy ESX's
-- uncuff timer and allow correct detection after a phone resource restart.
CreateThread(function()
    Wait(1000)
    refresh(true)
    while true do
        Wait(250)
        refresh()
    end
end)
