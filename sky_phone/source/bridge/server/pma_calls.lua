-- PMA speaker guests join the ordinary call channel and can hear AND speak.
-- All code runs in sky_phone; only PMA's public setPlayerCall export is used.
SkyPhonePmaCalls = {}
local active, guests = {}, {}
local speaker_range = 3.0

local function channel_of(player)
    local state = Player(player).state
    return tonumber(state.callChannel) or 0
end
local function set_channel(player, channel)
    local ok, err = pcall(function() exports["pma-voice"]:setPlayerCall(player, channel) end)
    if not ok then
        Bridge.Debug("error", "[sky_phone] PMA could not update speaker guest %s: %s",
            tostring(player), tostring(err), { always = true })
    end
    return ok
end
local function release_guest(player)
    local channel = guests[player]
    if not channel then return end
    -- Never remove a player from a different call started by another resource.
    if channel_of(player) == channel and not set_channel(player, 0) then return false end
    guests[player] = nil
    return true
end
local function refresh()
    if GetResourceState("pma-voice") ~= "started" then guests = {} return end
    local desired, participants = {}, {}
    for _, call in pairs(active) do
        for _, player in ipairs(call.players) do participants[player] = true end
    end
    local has_speaker = false
    for _, call in pairs(active) do
        if next(call.speakers) then has_speaker = true break end
    end
    if has_speaker and Bridge.Speaker.IsEnabled() then
        local positions = {}
        for _, handle in ipairs(next(active) and GetPlayers() or {}) do
            local player = tonumber(handle)
            local ped = player and GetPlayerPed(player)
            if ped and ped ~= 0 then
                positions[player] = { coords = GetEntityCoords(ped), bucket = GetPlayerRoutingBucket(player) }
            end
        end
        for _, call in pairs(active) do
            for holder, enabled in pairs(call.speakers) do
                local position = enabled and positions[holder]
                if position then
                    for player, target in pairs(positions) do
                        local channel = channel_of(player)
                        if not participants[player] and target.bucket == position.bucket
                            and not SkyPhoneCalls.IsActiveForSource(player)
                            and not (Bridge.PlayerState and Bridge.PlayerState.GetBlockReason(player))
                            and (channel == 0 or channel == guests[player]) then
                            local a, b = position.coords, target.coords
                            local distance = (a.x-b.x)^2 + (a.y-b.y)^2 + (a.z-b.z)^2
                            local previous = desired[player]
                            if distance <= speaker_range^2 and (not previous or distance < previous.distance
                                or (distance == previous.distance and call.channel < previous.channel)) then
                                desired[player] = { channel = call.channel, distance = distance }
                            end
                        end
                    end
                end
            end
        end
    end
    for player, channel in pairs(guests) do
        if not desired[player] or desired[player].channel ~= channel then release_guest(player) end
    end
    for player, target in pairs(desired) do
        if not guests[player] and set_channel(player, target.channel) then guests[player] = target.channel end
    end
end
function SkyPhonePmaCalls.Start(id, players, channel)
    if type(channel) ~= "number" or channel <= 0 then return false end
    for _, player in ipairs(players) do
        if release_guest(tonumber(player)) == false then return false end
    end
    active[id] = { players = { tonumber(players[1]), tonumber(players[2]) },
        channel = channel, speakers = {}, muted = {} }
    return true
end
function SkyPhonePmaCalls.Stop(id)
    local call = active[id]
    if call then
        if GetResourceState("pma-voice") == "started" then
            for _, player in ipairs(call.players) do
                if channel_of(player) == call.channel then set_channel(player, 0) end
            end
        end
        for player in pairs(call.muted) do TriggerClientEvent("sky_phone:calls:pma-muted", player, false) end
    end
    active[id] = nil
    refresh()
end
function SkyPhonePmaCalls.Set(player, kind, enabled)
    if kind ~= "speakers" and kind ~= "muted" then return false end
    for _, call in pairs(active) do
        if call.players[1] == player or call.players[2] == player then
            call[kind][player] = enabled == true or nil
            if kind == "muted" then
                TriggerClientEvent("sky_phone:calls:pma-muted", player, enabled == true)
            else refresh() end
            return true
        end
    end
    return false
end
CreateThread(function()
    while true do
        Wait(next(active) and 300 or 1000)
        if next(active) or next(guests) then refresh() end
    end
end)
AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() and resource ~= "pma-voice" then return end
    for id in pairs(active) do SkyPhonePmaCalls.Stop(id) end
    refresh()
end)
AddEventHandler("playerDropped", function()
    guests[source] = nil
    for id, call in pairs(active) do
        if call.players[1] == source or call.players[2] == source then SkyPhonePmaCalls.Stop(id) end
    end
    refresh()
end)
