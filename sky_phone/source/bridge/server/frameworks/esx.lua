if Bridge.Framework.Name ~= "esx" then
    return
end

local ESX = exports["es_extended"]:getSharedObject()

local function get_player(source)
    return ESX.GetPlayerFromId(source)
end

function Bridge.Framework.GetPlayers()
    local players = {}
    for _, player in pairs(ESX.GetExtendedPlayers()) do
        players[#players + 1] = player.source
    end
    return players
end

function Bridge.Framework.GetIdentifier(source)
    local player = get_player(source)
    return player and player.identifier or nil
end

function Bridge.Framework.GetFirstname(source)
    local player = get_player(source)
    return player and player.get("firstName") or nil
end

function Bridge.Framework.GetLastname(source)
    local player = get_player(source)
    return player and player.get("lastName") or nil
end

function Bridge.Framework.GetBirthdate(source)
    local player = get_player(source)
    return player and (player.get("dateofbirth") or player.get("dob")) or nil
end

function Bridge.Framework.RegisterUsableItem(item_name, callback)
    ESX.RegisterUsableItem(item_name, callback)
    return true
end
