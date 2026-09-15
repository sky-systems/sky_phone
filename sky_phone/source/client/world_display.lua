local displays, versions, slots = {}, {}, {}
local token, net_id, last_begin, last_signal = nil, nil, 0, 0
local resource = GetCurrentResourceName()
local boundary = {}
local screen = SkyPhoneProp.Screen
local half_w, half_h, radius = screen.width / 2, screen.height / 2, screen.radius
for _, corner in ipairs({
    { half_w - radius, half_h - radius, 0 },
    { -half_w + radius, half_h - radius, 90 },
    { -half_w + radius, -half_h + radius, 180 },
    { half_w - radius, -half_h + radius, 270 },
}) do
    for i = 0, 6 do
        local angle = math.rad(corner[3] + i * 90 / 6)
        local x, z = corner[1] + radius * math.cos(angle), corner[2] + radius * math.sin(angle)
        boundary[#boundary + 1] = { x = x, z = z, u = x / screen.width + 0.5, v = 0.5 - z / screen.height }
    end
end

local function destroy(player)
    local display = displays[player]
    if not display then return end
    DestroyDui(display.dui)
    slots[display.slot] = nil
    displays[player] = nil
end

local function eligible(player, net)
    if not SkyPhoneProp.DisplayEnabled() then return nil end
    local index = GetPlayerFromServerId(player)
    if index == -1 or not NetworkDoesEntityExistWithNetworkId(net) then return nil end
    local entity, ped = NetToObj(net), GetPlayerPed(index)
    if not DoesEntityExist(entity) or not SkyPhoneProp.Models[GetEntityModel(entity)]
        or GetEntityAttachedTo(entity) ~= ped then return nil end
    local coords = GetEntityCoords(PlayerPedId())
    if #(GetEntityCoords(ped) - coords) > SkyPhoneProp.Range then return nil end
    return entity, ped
end

local function receive(player, generation, net, sequence, jpeg)
    if type(player) ~= "number" or type(generation) ~= "number" or type(net) ~= "number"
        or type(sequence) ~= "number" or type(jpeg) ~= "string" or #jpeg > SkyPhoneProp.MaxFrameBytes then return end
    local version = versions[player]
    if version and (generation < version.token or (generation == version.token and sequence <= version.sequence)) then return end
    if not eligible(player, net) then return end
    local display = displays[player]
    if display and (display.token ~= generation or display.net ~= net) then destroy(player); display = nil end
    if not display then
        local slot
        for i = 1, SkyPhoneProp.MaxDisplays do if not slots[i] then slot = i; break end end
        if not slot then return end
        local dui = CreateDui(("https://cfx-nui-%s/source/html/display.html"):format(resource), SkyPhoneProp.Width, SkyPhoneProp.Height)
        if not dui or dui == 0 then
            Bridge.Debug("error", "[sky_phone] Could not create the phone display browser.")
            return
        end
        slots[slot] = true
        display = { dui = dui, slot = slot, txd = "sky_phone_display_" .. slot,
            token = generation, net = net, started = GetGameTimer() }
        displays[player] = display
    end
    versions[player] = { token = generation, sequence = sequence }
    display.sequence, display.jpeg, display.updated = sequence, jpeg, GetGameTimer()
    if display.ready then
        SendDuiMessage(display.dui, json.encode({ type = 'frame', sequence = sequence, jpeg = jpeg }))
        display.sent = sequence
    end
end

RegisterNetEvent("sky_phone:display:frame", receive)
RegisterNetEvent("sky_phone:display:stop", function(player, generation, sequence)
    local version = versions[player]
    if not version or generation > version.token or (generation == version.token and sequence >= version.sequence) then
        versions[player] = { token = generation, sequence = sequence }
        destroy(player)
    end
end)
RegisterNetEvent("sky_phone:display:permit", function(next_token, net)
    if not SkyPhoneProp.DisplayEnabled() then next_token = nil end
    if next_token and net ~= net_id then return end
    token = next_token
    SendNUIMessage({ type = "phone:world-display", token = token or false })
end)

RegisterNUICallback("worldDisplay:frame", function(data, cb)
    if not SkyPhoneProp.DisplayEnabled() or type(data) ~= "table" or not token or data.token ~= token
        or type(data.sequence) ~= "number" or type(data.jpeg) ~= "string"
        or not SkyPhoneProp.ValidFrame(data.jpeg) then
        cb({ success = false, error = "display_inactive" })
        return
    end
    if not SkyPhoneClient or not SkyPhoneClient.GetState().open then
        cb({ success = false, error = "display_inactive" })
        return
    end
    receive(GetPlayerServerId(PlayerId()), token, net_id, data.sequence, data.jpeg)
    TriggerLatentServerEvent("sky_phone:display:frame", 160000, token, data.sequence, data.jpeg)
    cb({ success = true })
end)

RegisterNUICallback("worldDisplay:color", function(data, cb)
    if type(data) ~= "table" or not SkyPhoneProp.Frames[data.frame] then
        cb({ success = false, error = "invalid_frame" })
        return
    end
    SkyPhoneAnimations.SetFrame(data.frame)
    cb({ success = true })
end)

local function end_capture()
    if token then TriggerServerEvent("sky_phone:display:end", token) end
    token, net_id = nil, nil
    SendNUIMessage({ type = "phone:world-display", token = false })
    destroy(GetPlayerServerId(PlayerId()))
end

CreateThread(function()
    while true do
        Wait(250)
        local prop = SkyPhoneAnimations.GetProp()
        local open = SkyPhoneClient and SkyPhoneClient.GetState().open
        if not SkyPhoneProp.DisplayEnabled() or not open or not prop
            or not DoesEntityExist(prop) or not SkyPhoneProp.Models[GetEntityModel(prop)] then
            if net_id then end_capture() end
        else
            local net = ObjToNet(prop)
            if net ~= net_id then end_capture(); net_id = net; last_begin = 0 end
            if not token and GetGameTimer() - last_begin >= 1000 then
                last_begin = GetGameTimer()
                TriggerServerEvent("sky_phone:display:begin", net_id)
            end
        end
        local now = GetGameTimer()
        if token and now - last_signal >= 1000 then
            last_signal = now
            SendNUIMessage({ type = 'phone:world-display', token = token })
        end
        for player, display in pairs(displays) do
            if not eligible(player, display.net) or now - display.updated > 3000 then
                destroy(player)
            elseif not display.ready then
                if IsDuiAvailable(display.dui) then
                    local txd = CreateRuntimeTxd(display.txd)
                    CreateRuntimeTextureFromDuiHandle(txd, "screen", GetDuiHandle(display.dui))
                    display.ready = true
                    -- Keep the newest frame for delivery after the browser has initialized.
                    display.sent = 0
                elseif now - display.started > 5000 then
                    Bridge.Debug("error", "[sky_phone] Phone display browser timed out.")
                    destroy(player)
                end
            end
            if displays[player] and display.ready and display.sent ~= display.sequence then
                SendDuiMessage(display.dui, json.encode({ type = "frame", sequence = display.sequence, jpeg = display.jpeg }))
                display.sent = display.sequence
            end
        end
    end
end)

CreateThread(function()
    while true do
        local active = false
        for player, display in pairs(displays) do
            local entity, ped
            if display.ready then entity, ped = eligible(player, display.net) end
            if entity then
                active = true
                -- Refresh the prop from the current hand pose before sampling it.
                -- Otherwise sprinting can leave the overlay at the previous attachment pose.
                ProcessEntityAttachments(ped)
                if IsEntityOnScreen(entity) then
                    -- Sample one transform for the whole polygon, after attachments update.
                    local forward, right, up, position = GetEntityMatrix(entity)
                    local center = position + forward * screen.y
                    local view = GetFinalRenderedCamCoord() - center
                    if forward.x * view.x + forward.y * view.y + forward.z * view.z < 0 then
                        -- The textured polygons are depth-tested by GTA. A separate LOS test
                        -- from the player's body can hide a screen visible to the camera.
                        local points = {}
                        for i, p in ipairs(boundary) do
                            points[i] = center + right * p.x + up * p.z
                        end
                        for i, a in ipairs(boundary) do
                            local j = i % #boundary + 1
                            local b, p, q = boundary[j], points[i], points[j]
                            DrawTexturedPoly(center.x, center.y, center.z, p.x, p.y, p.z, q.x, q.y, q.z,
                                255, 255, 255, 255, display.txd, "screen",
                                0.5, 0.5, 1.0, a.u, a.v, 1.0, b.u, b.v, 1.0)
                        end
                    end
                end
            end
        end
        -- A culled frame must not pause a nearby active screen for 100 ms.
        Wait(active and 0 or 100)
    end
end)

AddEventHandler("sky_phone:configurator:updated", function()
    if SkyPhoneProp.DisplayEnabled() then return end
    end_capture()
    for player in pairs(displays) do destroy(player) end
end)

AddEventHandler("sky_phone:animation:reset", end_capture)
AddEventHandler("onResourceStop", function(name)
    if name ~= resource then return end
    end_capture()
    for player in pairs(displays) do destroy(player) end
end)
