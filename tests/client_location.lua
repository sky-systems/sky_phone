local nui_callbacks = {}
local waypoint = nil

function RegisterNUICallback(name, callback)
    nui_callbacks[name] = callback
end

function PlayerPedId()
    return 7
end

function GetEntityCoords(ped)
    assert(ped == 7, "location must use the local player ped")
    return { x = 12.5, y = -4.0, z = 80.25 }
end

function SetNewWaypoint(x, y)
    waypoint = { x = x, y = y }
end

dofile("sky_phone/source/client/location.lua")

local coords_result
nui_callbacks["map:getPlayerCoords"]({}, function(result)
    coords_result = result
end)
assert(coords_result.success and coords_result.data.coords.z == 80.25, "map coordinates changed")

local marker_result
nui_callbacks["map:setWaypoint"]({ coords = { x = 100, y = 200 } }, function(result)
    marker_result = result
end)
assert(marker_result.success and waypoint.x == 100 and waypoint.y == 200, "valid waypoint must reach the native")

nui_callbacks["map:setWaypoint"]({ coords = { x = 10001, y = 0 } }, function(result)
    marker_result = result
end)
assert(not marker_result.success and marker_result.error == "invalid_marker", "out-of-world waypoint must be rejected")

local skyride_result
nui_callbacks["skyride:get-player-coords"]({}, function(result)
    skyride_result = result
end)
assert(skyride_result.success and skyride_result.data.coords.x == 12.5, "SkyRide must reuse the location owner")

print("Client location tests passed")
