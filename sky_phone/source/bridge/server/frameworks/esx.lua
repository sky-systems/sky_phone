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

function Bridge.Framework.HasAdminGroup(source, groups)
    local player = get_player(source)
    if not player then
        return false
    end
    local player_group = player.getGroup()
    for _, group in ipairs(groups) do
        if player_group == group then
            return true
        end
    end
    return false
end

function Bridge.Framework.GetMoney(source, account)
    local player = get_player(source)
    if not player then
        return nil
    end
    if account == "cash" then
        account = "money"
    end
    local account_data = player.getAccount(account)
    return account_data and account_data.money or nil
end

function Bridge.Framework.AddMoney(source, account, amount)
    local player = get_player(source)
    if not player then
        return false
    end
    if account == "cash" then
        account = "money"
    end
    player.addAccountMoney(account, amount)
    return true
end

function Bridge.Framework.RemoveMoney(source, account, amount)
    local player = get_player(source)
    if not player then
        return false
    end
    if account == "cash" then
        account = "money"
    end
    local account_data = player.getAccount(account)
    if not account_data or account_data.money < amount then
        return false
    end
    player.removeAccountMoney(account, amount)
    return true
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
