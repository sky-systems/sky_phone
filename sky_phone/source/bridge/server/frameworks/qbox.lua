if Bridge.Framework.Name ~= "qbox" then
    return
end

local function get_player(source)
    return exports.qbx_core:GetPlayer(tonumber(source))
end

function Bridge.Framework.GetPlayers()
    local players = {}
    for _, player_source in ipairs(GetPlayers()) do
        players[#players + 1] = tonumber(player_source)
    end
    return players
end

function Bridge.Framework.GetIdentifier(source)
    local player = get_player(source)
    return player and player.PlayerData and tostring(player.PlayerData.citizenid) or nil
end

function Bridge.Framework.HasAdminGroup(source, groups)
    local player = get_player(source)
    if not player then
        return false
    end

    for _, group in ipairs(groups) do
        if IsPlayerAceAllowed(tostring(source), group) then
            return true
        end
    end

    return exports.qbx_core:HasGroup(source, groups)
end

function Bridge.Framework.GetMoney(source, account)
    return exports.qbx_core:GetMoney(tonumber(source), account)
end

function Bridge.Framework.AddMoney(source, account, amount)
    return exports.qbx_core:AddMoney(tonumber(source), account, amount)
end

function Bridge.Framework.RemoveMoney(source, account, amount)
    return exports.qbx_core:RemoveMoney(tonumber(source), account, amount)
end

local function get_character_info(source)
    local player = get_player(source)
    return player and player.PlayerData and player.PlayerData.charinfo or nil
end

function Bridge.Framework.GetCharacterName(source)
    local character = get_character_info(source)
    if not character then
        return nil, nil
    end
    return character.firstname, character.lastname
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
        onDuty = job ~= nil and job.onduty ~= false,
    }
end

function Bridge.Framework.RegisterUsableItem(item_name, callback)
    exports.qbx_core:CreateUseableItem(item_name, callback)
    return true
end
