local framework_name
local esx
local qb
local esx_player_data
local qb_metadata

local function resolve_framework()
    local configured = Config.Bridge.Framework
    if configured ~= "auto" then
        return configured
    end

    if GetResourceState("es_extended") == "started" then
        return "esx"
    end
    if GetResourceState("qbx_core") == "started" then
        return "qbox"
    end
    if GetResourceState("qb-core") == "started" then
        return "qb"
    end

    return nil
end

local function refresh_framework()
    local resolved = resolve_framework()
    if resolved ~= "esx" and resolved ~= "qbox" and resolved ~= "qb" then
        error("[sky_phone] No supported framework is running. Configure Config.Bridge.Framework.")
    end
    if resolved == framework_name then
        return
    end

    framework_name = resolved
    esx = nil
    qb = nil
    esx_player_data = nil
    qb_metadata = nil
end

refresh_framework()

AddEventHandler("sky_phone:configurator:updated", refresh_framework)

-- ESX function references serialize their complete return value across resources.
-- Keep the status snapshot current through the same events as ESX's imports.lua.
AddEventHandler("esx:setPlayerData", function(key, value)
    if framework_name == "esx" and GetInvokingResource() == "es_extended" and esx_player_data then
        esx_player_data[key] = value
    end
end)

RegisterNetEvent("esx:playerLoaded", function(player_data)
    if framework_name == "esx" then
        esx_player_data = player_data
    end
end)

RegisterNetEvent("esx:onPlayerLogout", function()
    if framework_name == "esx" then
        esx_player_data = {}
    end
end)

-- Qbox's playerdata module and QBCore publish complete replacements on this
-- event. Seed once after a Phone restart instead of serializing them every poll.
RegisterNetEvent("QBCore:Player:SetPlayerData", function(player_data)
    if framework_name ~= "qbox" and framework_name ~= "qb" then return end
    local owner = framework_name == "qbox" and "qbx_core" or "qb-core"
    local invoker = GetInvokingResource()
    if invoker and invoker ~= owner then return end
    qb_metadata = type(player_data) == "table" and player_data.metadata or nil
    qb_metadata = qb_metadata or {}
end)

RegisterNetEvent("QBCore:Client:OnPlayerUnload", function()
    if framework_name == "qbox" or framework_name == "qb" then
        qb_metadata = {}
    end
end)

RegisterNetEvent("QBCore:Client:OnPlayerLoaded", function()
    if framework_name == "qbox" or framework_name == "qb" then
        qb_metadata = nil
    end
end)

for _, event_name in ipairs({ "esx:addInventoryItem", "esx:removeInventoryItem" }) do
    RegisterNetEvent(event_name, function(item, count)
        if framework_name ~= "esx" or not esx_player_data or not count then return end
        for _, entry in pairs(esx_player_data.inventory or {}) do
            if entry.name == item then
                entry.count = count
                break
            end
        end
    end)
end

RegisterNetEvent("esx:addLoadoutItem", function(weapon_name, weapon_label, ammo)
    if framework_name ~= "esx" or not esx_player_data or not esx_player_data.loadout then return end
    esx_player_data.loadout[#esx_player_data.loadout + 1] = {
        name = weapon_name, label = weapon_label, ammo = ammo, components = {}, tintIndex = 0,
    }
end)

RegisterNetEvent("esx:removeLoadoutItem", function(weapon_name)
    if framework_name ~= "esx" or not esx_player_data then return end
    for index, entry in ipairs(esx_player_data.loadout or {}) do
        if entry.name == weapon_name then
            table.remove(esx_player_data.loadout, index)
            break
        end
    end
end)

AddEventHandler("onClientResourceStop", function(resource)
    if resource == "es_extended" then
        esx = nil
        esx_player_data = {}
    elseif (framework_name == "qbox" and resource == "qbx_core")
        or (framework_name == "qb" and resource == "qb-core") then
        qb = nil
        qb_metadata = {}
    end
end)

AddEventHandler("onClientResourceStart", function(resource)
    if resource == "es_extended" then
        esx = nil
        esx_player_data = nil
    elseif (framework_name == "qbox" and resource == "qbx_core")
        or (framework_name == "qb" and resource == "qb-core") then
        qb = nil
        qb_metadata = nil
    end
end)

function Bridge.Framework.GetName()
    return framework_name
end

function Bridge.Framework.Notify(title, message, notification_type, duration)
    if framework_name == "esx" then
        esx = esx or exports["es_extended"]:getSharedObject()
        esx.ShowNotification(message, notification_type, duration, title)
        return
    end

    if framework_name == "qbox" then
        exports.qbx_core:Notify(message, notification_type, duration, title)
        return
    end

    if framework_name == "qb" then
        qb = qb or exports["qb-core"]:GetCoreObject()
        qb.Functions.Notify(message, notification_type, duration)
        return
    end

    Bridge.Debug("error", "[sky_phone] Notification requested for unsupported framework '%s'.", tostring(framework_name))
end

function Bridge.Framework.ShowHelpNotification(message, key)
    local control = key == "E" and "~INPUT_CONTEXT~" or ("[%s]"):format(tostring(key or "E"))
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(("%s  %s"):format(control, tostring(message or "")))
    EndTextCommandDisplayHelp(0, false, false, -1)
end

function Bridge.Framework.GetStatusData()
    if framework_name == "esx" then
        if not esx_player_data then
            esx = esx or exports["es_extended"]:getSharedObject()
            if not esx.IsPlayerLoaded() then return {} end
            esx_player_data = esx.GetPlayerData()
        end
        return esx_player_data
    elseif framework_name == "qbox" then
        if not qb_metadata then
            local data = exports.qbx_core:GetPlayerData()
            qb_metadata = data and data.metadata or {}
        end
        return qb_metadata
    elseif framework_name == "qb" then
        if not qb_metadata then
            qb = qb or exports["qb-core"]:GetCoreObject()
            local data = qb.Functions.GetPlayerData()
            qb_metadata = data and data.metadata or {}
        end
        return qb_metadata
    end
    return {}
end
