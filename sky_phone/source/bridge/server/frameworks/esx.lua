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

function Bridge.Framework.GetJob(source)
    local player = get_player(source)
    local job = player and player.getJob()
    if not job then
        return { name = "", label = "", grade = 0, gradeLabel = "" }
    end
    return {
        name = job.name or "",
        label = job.label or "",
        grade = tonumber(job.grade) or 0,
        gradeLabel = job.grade_label or job.label or "",
    }
end

function Bridge.Framework.RegisterUsableItem(item_name, callback)
    ESX.RegisterUsableItem(item_name, callback)
    return true
end
