local function player_coordinates()
    local coords = GetEntityCoords(PlayerPedId())
    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
    }
end

RegisterNUICallback("map:getPlayerCoords", function(data, cb)
    if type(data) ~= "table" then
        cb({ success = false, error = "invalid_request" })
        return
    end

    cb({ success = true, data = { coords = player_coordinates() } })
end)

RegisterNUICallback("map:setWaypoint", function(data, cb)
    local coords = type(data) == "table" and data.coords or nil
    local x = type(coords) == "table" and tonumber(coords.x) or nil
    local y = type(coords) == "table" and tonumber(coords.y) or nil
    if not x or not y or x ~= x or y ~= y or math.abs(x) > 10000.0 or math.abs(y) > 10000.0 then
        cb({ success = false, error = "invalid_marker" })
        return
    end

    SetNewWaypoint(x, y)
    cb({ success = true })
end)

RegisterNUICallback("skyride:get-player-coords", function(_, cb)
    cb({ success = true, data = { coords = player_coordinates() } })
end)
