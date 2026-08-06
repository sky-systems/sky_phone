if Bridge.Framework.Name ~= "qb" then
    return
end

local QBCore = exports["qb-core"]:GetCoreObject()

local function get_player(source)
    return QBCore.Functions.GetPlayer(tonumber(source))
end

function Bridge.Framework.GetPlayers()
    local players = {}
    for player_source in pairs(QBCore.Functions.GetQBPlayers()) do
        players[#players + 1] = tonumber(player_source)
    end
    return players
end

function Bridge.Framework.GetIdentifier(source)
    local player = get_player(source)
    return player and player.PlayerData and tostring(player.PlayerData.citizenid) or nil
end

local function get_character_info(source)
    local player = get_player(source)
    return player and player.PlayerData and player.PlayerData.charinfo or nil
end

function Bridge.Framework.GetFirstname(source)
    local character = get_character_info(source)
    return character and character.firstname or nil
end

function Bridge.Framework.GetLastname(source)
    local character = get_character_info(source)
    return character and character.lastname or nil
end

function Bridge.Framework.GetBirthdate(source)
    local character = get_character_info(source)
    return character and character.birthdate or nil
end

function Bridge.Framework.GetJob(source)
    local player = get_player(source)
    local job = player and player.PlayerData and player.PlayerData.job
    local grade = job and job.grade
    return {
        name = job and job.name or "",
        label = job and job.label or "",
        grade = type(grade) == "table" and tonumber(grade.level) or tonumber(grade) or 0,
        gradeLabel = type(grade) == "table" and (grade.name or job.label) or (job and job.label or ""),
    }
end

function Bridge.Framework.RegisterUsableItem(item_name, callback)
    QBCore.Functions.CreateUseableItem(item_name, callback)
    return true
end
