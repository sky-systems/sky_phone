SkyPhoneRealtime = SkyPhoneRealtime or { Apps = {} }
local rooms, voice_states = {}, {}
local member_locks = {}
local cf = SkyPhoneRealtimeCloudflare
local function failure(err) return { success = false, error = err or "request_failed" } end
local function valid_id(id) return type(id) == "string" and #id > 0 and #id <= 80 and id:match("^[%w:_-]+$") end
local function allowed(source, operation, limit)
    return SkyPhone.AllowOperation(source, "realtime_" .. operation, limit, 60)
end
local function own_profile(source, app)
    local adapter = SkyPhoneRealtime.Apps[app]
    if not adapter or not Config.Realtime[app == "picstagram" and "Picstagram" or "FlipTok"]
        or Config.Apps[app] == false then return nil end
    return adapter.profile(source)
end
local function can_view(source, room)
    local viewer = own_profile(source, room.app)
    return viewer and SkyPhoneRealtime.Apps[room.app].canView(viewer, room.profileId)
end
local function call_for(source, id)
    local call = SkyPhoneCalls.GetForSource(source)
    if call and call.id == id and call.state == "connected" and call.video then return call end
end
local function nearby_distance(source, host)
    local voice = voice_states[source]
    if not voice or os.time() - voice.at > 15 or not voice.enabled then return nil end
    if GetPlayerRoutingBucket(source) ~= GetPlayerRoutingBucket(host) then return nil end
    local ped, host_ped = GetPlayerPed(source), GetPlayerPed(host)
    if ped == 0 or host_ped == 0 or GetEntityHealth(ped) <= 0 then return nil end
    local distance = #(GetEntityCoords(ped) - GetEntityCoords(host_ped))
    local range = math.min(Config.Realtime.NearbyDistance, voice.range)
    if distance > range or range <= 0 then return nil end
    return distance, math.max(0, 1 - distance / range) ^ 2
end
local function edge(room, sender, receiver)
    local from, target = room.members[sender], room.members[receiver]
    if not from or not target or not from.ready or not target.ready or sender == receiver then return false end
    if room.kind == "call" then return from.role == "call" and target.role == "call" end
    if from.role == "host" and target.role == "viewer" then return true end
    return from.role == "nearby" and target.role == "host" and nearby_distance(sender, receiver) ~= nil
end
local function public_config()
    return {
        enabled = Config.Realtime.Enabled, transport = Config.Realtime.Transport,
        videoCalls = Config.Realtime.VideoCalls, picstagram = Config.Realtime.Picstagram,
        fliptok = Config.Realtime.FlipTok, fps = Config.Realtime.FrameRate,
        bitrate = Config.Realtime.VideoBitrateKbps * 1000, edge = Config.Realtime.MaxVideoEdge,
        nearbyAudio = Config.Realtime.NearbyAudio,
        iceTransportPolicy = Config.Realtime.ForceRelay and Config.Realtime.Transport == "p2p" and "relay" or "all",
    }
end
local function snapshot(room, source)
    local member = room.members[source]
    local peers, viewers = {}, 0
    for id, other in pairs(room.members) do
        if other.role == "viewer" and other.ready then viewers = viewers + 1 end
        local receives, sends = edge(room, id, source), edge(room, source, id)
        if receives or sends then
            local tracks = {}
            if receives then
                for _, track in ipairs(other.tracks or {}) do
                    tracks[#tracks + 1] = { sessionId = other.session, trackName = track.trackName, kind = track.kind }
                end
            end
            peers[#peers + 1] = { id = id, role = other.role, receives = receives, sends = sends,
                gain = math.floor((other.gain or 1) * 20) / 20, tracks = tracks }
        end
    end
    table.sort(peers, function(a, b) return a.id < b.id end)
    return { id = room.id, kind = room.kind, app = room.app, title = room.title, description = room.description, hostName = room.hostName, profileId = tostring(room.profileId or ""), hostAvatar = room.hostAvatar,
        role = member.role, self = source, peers = peers, viewers = viewers, transport = room.transport,
        messages = member.role ~= "nearby" and room.messages or {} }
end
local function broadcast(room)
    for source, member in pairs(room.members) do
        if member.ready then
            local data = snapshot(room, source)
            local encoded = json.encode(data)
            if member.lastSnapshot ~= encoded then
                member.lastSnapshot = encoded
                TriggerClientEvent("sky_phone:realtime:room", source, data)
            end
        end
    end
end
local function release(member)
    if not member.session then return end
    local tracks = {}
    for mid in pairs(member.mids or {}) do tracks[#tracks + 1] = { mid = mid } end
    if #tracks > 0 then
        CreateThread(function() cf.Sfu(member.session, "close", { tracks = tracks, force = true }, member.cloudflare) end)
    end
end
local function remove_member(room, source, reason)
    local member = room.members[source]
    if not member then return end
    room.members[source] = nil
    release(member)
    TriggerClientEvent("sky_phone:realtime:ended", source, { id = room.id, reason = reason or "ended" })
    broadcast(room)
end
local function end_room(room, reason)
    rooms[room.id] = nil
    if room.kind == "call" and SkyPhoneCalls.StopVideo then SkyPhoneCalls.StopVideo(room.callId) end
    for source, member in pairs(room.members) do
        release(member)
        TriggerClientEvent("sky_phone:realtime:ended", source, { id = room.id, reason = reason or "ended" })
    end
    room.members = {}
end
local function authorized(source, room, member)
    if not room or not member or rooms[room.id] ~= room or room.members[source] ~= member or not Config.Realtime.Enabled then return false end
    if room.kind == "call" then return call_for(source, room.callId) ~= nil end
    if member.role == "nearby" then
        return Config.Realtime.NearbyAudio and nearby_distance(source, room.host) ~= nil
    end
    local profile = own_profile(source, room.app)
    if not profile then return false end
    if rooms[room.id] ~= room or room.members[source] ~= member then return false end
    if member.role == "host" then return tostring(profile.id) == tostring(room.profileId) end
    return SkyPhoneRealtime.Apps[room.app].canView(profile, room.profileId)
        and rooms[room.id] == room and room.members[source] == member
end
local function join(source, room, member)
    if not authorized(source, room, member) then return failure("not_authorized") end
    local ice, err = cf.Ice(source)
    if not ice then return failure(err) end
    if not authorized(source, room, member) or room.members[source] ~= member then return failure("ended") end
    member.at = os.time()
    local config = public_config()
    config.transport = room.transport
    config.iceServers = ice
    return { success = true, data = { room = snapshot(room, source), config = config } }
end
local function new_member(role) return { role = role, at = os.time(), tracks = {}, mids = {}, subscriptions = {} } end
local function new_room(source, data)
    if not valid_id(data.id or "new") then return nil end
    if data.kind == "call" then
        local call = call_for(source, data.id)
        if not call or not Config.Realtime.VideoCalls or call.payphone then return nil end
        local id = "call:" .. call.id
        if rooms[id] then return rooms[id] end
        local caller, callee = call.caller.source, call.callee.source
        if not caller or not callee then return nil end
        local room = { id = id, callId = call.id, kind = "call", members = {
            [caller] = new_member("call"), [callee] = new_member("call"),
        }, host = caller, created = os.time(), transport = Config.Realtime.Transport }
        rooms[id] = room
        return room
    end
    if data.app ~= "picstagram" and data.app ~= "fliptok" then return nil end
    local profile = own_profile(source, data.app)
    if not profile then return nil end
    local rows = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    if not rows[1] or not valid_id(rows[1].id) then return nil end
    local broadcasts = 0
    for _, room in pairs(rooms) do
        if room.kind == "live" then
            broadcasts = broadcasts + 1
            if room.host == source or (room.app == data.app and tostring(room.profileId) == tostring(profile.id)) then return nil end
        end
    end
    if broadcasts >= Config.Realtime.MaxBroadcasts then return nil end
    local title = type(data.title) == "string" and data.title:match("^%s*(.-)%s*$") or ""
    local description = type(data.description) == "string" and data.description or ""
    local title_length, description_length = utf8.len(title), utf8.len(description)
    if #title > 480 or not title_length or title_length > 120 or title_length == 0
        or #description > 4000 or not description_length or description_length > 1000 then return nil end
    local adapter = SkyPhoneRealtime.Apps[data.app]
    local public_profile = adapter.publicProfile and adapter.publicProfile(profile.id, profile.id) or profile
    local room = { id = rows[1].id, kind = "live", app = data.app, profileId = profile.id,
        hostAvatar = public_profile and public_profile.avatar_url,
        hostName = profile.display_name or profile.username, title = title, description = description, messages = {}, messageSequence = 0, host = source, members = { [source] = new_member("host") },
        created = os.time(), transport = Config.Realtime.Transport }
    rooms[room.id] = room
    return room
end

Bridge.Database.AfterMigration("sky_phone", function()
    local function register(name, limit, handler)
        Bridge.Callbacks.Register("sky_phone:realtime:" .. name, function(source, data)
            if type(data) ~= "table" then return failure("invalid_request") end
            if not Config.Realtime.Enabled and name ~= "config" and name ~= "leave" then return failure("feature_disabled") end
            if not allowed(source, name, limit) then return failure("rate_limited") end
            return handler(source, data)
        end)
    end
    register("config", 30, function(source)
        local session, err = SkyPhone.RequireSession(source)
        if not session then return err end
        return { success = true, data = public_config() }
    end)
    register("list", 30, function(source, data)
        if not own_profile(source, data.app) then return failure("not_authorized") end
        local entries = {}
        for _, room in pairs(rooms) do
            if room.kind == "live" and room.app == data.app and room.members[room.host] and room.members[room.host].ready and can_view(source, room) then
                local viewers = 0
                for _, member in pairs(room.members) do if member.role == "viewer" and member.ready then viewers = viewers + 1 end end
                entries[#entries + 1] = { id = room.id, title = room.title, hostName = room.hostName, profileId = tostring(room.profileId), hostAvatar = room.hostAvatar, viewers = viewers }
            end
        end
        return { success = true, data = entries }
    end)
    register("create", 10, function(source, data)
        if member_locks[source] then return failure("busy") end
        member_locks[source] = true
        local ok, result = pcall(function()
            local room = new_room(source, data)
            if not room then return failure("not_authorized") end
            local response = join(source, room, room.members[source])
            if not response.success and room.host == source then end_room(room, response.error) end
            return response
        end)
        member_locks[source] = nil
        if not ok then print("[sky_phone] Realtime session creation failed.") return failure("request_failed") end
        return result
    end)
    register("join", 30, function(source, data)
        local room = valid_id(data.id) and rooms[data.id]
        if not room then return failure("ended") end
        local member = room.members[source]
        if not member then
            if room.kind ~= "live" or not can_view(source, room) then return failure("not_authorized") end
            if rooms[room.id] ~= room then return failure("ended") end
            if room.members[source] then return join(source, room, room.members[source]) end
            local viewers = 0
            for _, other in pairs(room.members) do if other.role == "viewer" then viewers = viewers + 1 end end
            if viewers >= Config.Realtime.MaxViewers then return failure("viewer_limit") end
            member = new_member("viewer")
            room.members[source] = member
        end
        local response = join(source, room, member)
        if not response.success then remove_member(room, source, response.error) end
        return response
    end)
    register("ready", 30, function(source, data)
        local room = valid_id(data.id) and rooms[data.id]
        local member = room and room.members[source]
        if not authorized(source, room, member) then return failure("ended") end
        member.ready, member.at = true, os.time()
        broadcast(room)
        return { success = true, data = snapshot(room, source) }
    end)
    register("drop", 60, function(source, data)
        local room = valid_id(data.id) and rooms[data.id]
        local target = tonumber(data.target)
        if not room or room.kind ~= "live" or room.host ~= source or not target or target == source
            or not authorized(source, room, room.members[source]) then return failure("not_authorized") end
        remove_member(room, target, "connection_failed")
        return { success = true }
    end)
    register("chat", 20, function(source, data)
        local room = valid_id(data.id) and rooms[data.id]
        local member = room and room.members[source]
        if not room or room.kind ~= "live" or not member or not member.ready
            or (member.role ~= "host" and member.role ~= "viewer")
            or not authorized(source, room, member) then return failure("not_authorized") end
        if type(data.text) ~= "string" or #data.text > 1200 then return failure("invalid_message") end
        local message = data.text:gsub("[%z\1-\31]", " "):match("^%s*(.-)%s*$")
        local length = utf8.len(message)
        if not length or length == 0 or length > 300 then return failure("invalid_message") end
        local profile = own_profile(source, room.app)
        if not profile or rooms[room.id] ~= room or room.members[source] ~= member then return failure("ended") end
        room.messageSequence = room.messageSequence + 1
        room.messages[#room.messages + 1] = { id = room.messageSequence, name = profile.display_name or profile.username,
            text = message, host = member.role == "host", at = os.time() }
        if #room.messages > 50 then table.remove(room.messages, 1) end
        broadcast(room)
        return { success = true }
    end)
    register("leave", 60, function(source, data)
        local room = valid_id(data.id) and rooms[data.id]
        if room and room.members[source] then
            if source == room.host or room.kind == "call" then end_room(room) else remove_member(room, source) end
        end
        return { success = true }
    end)
    register("heartbeat", 60, function(source, data)
        local room = valid_id(data.id) and rooms[data.id]
        local member = room and room.members[source]
        if not authorized(source, room, member) then
            if room and member then
                if room.host == source or room.kind == "call" then end_room(room) else remove_member(room, source) end
            end
            return failure("ended")
        end
        member.at = os.time()
        return { success = true, data = snapshot(room, source) }
    end)
    register("signal", 240, function(source, data)
        local room = valid_id(data.id) and rooms[data.id]
        local target = tonumber(data.target)
        if not room or room.transport ~= "p2p" or not target
            or not authorized(source, room, room.members[source])
            or not authorized(target, room, room.members[target])
            or not (edge(room, source, target) or edge(room, target, source)) then return failure("not_authorized") end
        local signal = data.signal
        if type(signal) ~= "table" or #json.encode(signal) > 70000 then return failure("invalid_request") end
        if signal.type ~= "offer" and signal.type ~= "answer" and signal.type ~= "candidate" then return failure("invalid_request") end
        TriggerClientEvent("sky_phone:realtime:signal", target, { id = room.id, from = source, signal = signal })
        return { success = true }
    end)
    register("sfu", 180, function(source, data)
        local room = valid_id(data.id) and rooms[data.id]
        local member = room and room.members[source]
        if not room or room.transport ~= "cloudflare" or not authorized(source, room, member) or not member.ready then
            return failure("not_authorized")
        end
        if member.busy then return failure("busy") end
        member.busy = true
        local ok, response = pcall(function()
            local op, payload = data.operation, nil
            if op == "create" then
                if member.session then return { success = true, data = { sessionId = member.session } } end
                local secrets = Config.RealtimeSecrets or {}
                member.cloudflare = { AppId = secrets.AppId, AppSecret = secrets.AppSecret }
            elseif not member.session then return failure("session_not_found")
            elseif op == "publish" then
                if member.role == "viewer" or #member.tracks > 0 or type(data.tracks) ~= "table"
                    or #data.tracks < 1 or #data.tracks > (member.role == "host" and 2 or 1) then return failure("invalid_request") end
                local tracks, kinds = {}, {}
                for _, track in ipairs(data.tracks) do
                    if type(track) ~= "table" or not valid_id(track.mid) or not valid_id(track.trackName)
                        or (track.kind ~= "video" and track.kind ~= "audio") or kinds[track.kind]
                        or (member.role == "nearby" and track.kind ~= "audio")
                        or (member.role == "call" and track.kind ~= "video") then return failure("invalid_request") end
                    kinds[track.kind] = true
                    tracks[#tracks + 1] = { location = "local", mid = track.mid, trackName = track.trackName }
                end
                payload = { tracks = tracks, sessionDescription = data.sessionDescription }
            elseif op == "pull" then
                local target = tonumber(data.target)
                if not target or not edge(room, target, source) or not authorized(target, room, room.members[target]) then
                    return failure("not_authorized")
                end
                if member.subscriptions[target] then return failure("already_subscribed") end
                local mid_count = 0
                for _ in pairs(member.mids) do mid_count = mid_count + 1 end
                if mid_count >= 62 then return failure("track_limit") end
                local other, tracks = room.members[target], {}
                for _, track in ipairs(other.tracks) do
                    tracks[#tracks + 1] = { location = "remote", sessionId = other.session, trackName = track.trackName }
                end
                if #tracks == 0 then return failure("stream_not_ready") end
                payload = { tracks = tracks }
            elseif op == "renegotiate" then payload = { sessionDescription = data.sessionDescription }
            elseif op == "close" then
                if type(data.mids) ~= "table" or #data.mids > 64 then return failure("invalid_request") end
                local tracks = {}
                for _, mid in ipairs(data.mids) do
                    if not member.mids[mid] then return failure("not_authorized") end
                    tracks[#tracks + 1] = { mid = mid }
                end
                payload = { tracks = tracks, force = true }
            else return failure("invalid_request") end
            if op == "publish" or op == "renegotiate" then
                local sdp = data.sessionDescription
                if type(sdp) ~= "table" or type(sdp.sdp) ~= "string" or #sdp.sdp > 65535
                    or sdp.type ~= (op == "publish" and "offer" or "answer") then return failure("invalid_request") end
            end
            local result, err = cf.Sfu(member.session, op, payload, member.cloudflare)
            if not result then return failure(err) end
            if op == "create" then
                if not valid_id(result.sessionId) then return failure("cloudflare_failed") end
                member.session = result.sessionId
            end
            for _, track in ipairs(result.tracks or {}) do
                if track.mid then member.mids[track.mid] = true end
            end
            if not authorized(source, room, member) or room.members[source] ~= member then release(member) return failure("ended") end
            if op == "publish" or op == "pull" then
                if type(result.tracks) ~= "table" or #result.tracks ~= #payload.tracks then return failure("cloudflare_failed") end
                if op == "pull" then member.subscriptions[tonumber(data.target)] = {} end
                for index, track in ipairs(result.tracks or {}) do
                    if not track.mid or track.errorCode then return failure("cloudflare_failed") end
                    if track.mid then member.mids[track.mid] = true end
                    if op == "pull" then member.subscriptions[tonumber(data.target)][track.mid] = true end
                    if op == "publish" then
                        member.tracks[#member.tracks + 1] = { mid = track.mid,
                            trackName = track.trackName, kind = data.tracks[index] and data.tracks[index].kind }
                    end
                end
                if op == "publish" then broadcast(room) end
            elseif op == "close" then
                for _, mid in ipairs(data.mids) do
                    member.mids[mid] = nil
                    for target, mids in pairs(member.subscriptions) do
                        mids[mid] = nil
                        if not next(mids) then member.subscriptions[target] = nil end
                    end
                end
            end
            return { success = true, data = result }
        end)
        member.busy = false
        if not ok then print("[sky_phone] Realtime SFU operation failed.") return failure("request_failed") end
        return response
    end)
end)

RegisterNetEvent("sky_phone:realtime:voice", function(data)
    local src = source
    if not Config.Realtime.Enabled or type(data) ~= "table" or not allowed(src, "voice", 90) then return end
    local range = tonumber(data.range)
    if not range or range ~= range then return end
    voice_states[src] = { range = math.max(0, math.min(30, range)), enabled = data.enabled == true, at = os.time() }
end)

CreateThread(function()
    while true do
        Wait(1000)
        local now = os.time()
        for _, room in pairs(rooms) do
            local host = room.members[room.host]
            if not Config.Realtime.Enabled or not host or now - host.at > 30
                or now - room.created > Config.Realtime.MaxDurationMinutes * 60
                or (room.kind == "call" and not call_for(room.host, room.callId)) then
                end_room(room)
            else
                for src, member in pairs(room.members) do
                    if now - member.at > 30 then remove_member(room, src, "session_timeout")
                    elseif member.role == "nearby" then
                        local distance, gain = nearby_distance(src, room.host)
                        if not Config.Realtime.NearbyAudio or not distance then remove_member(room, src)
                        else member.gain = gain end
                    end
                end
                if room.kind == "live" and Config.Realtime.NearbyAudio and host.ready then
                    local near_count = 0
                    for _, member in pairs(room.members) do if member.role == "nearby" then near_count = near_count + 1 end end
                    for src in pairs(voice_states) do
                        if near_count >= Config.Realtime.NearbyMaxSpeakers then break end
                        if src ~= room.host and not room.members[src] and GetPlayerName(src) and nearby_distance(src, room.host) then
                            room.members[src] = new_member("nearby")
                            near_count = near_count + 1
                            TriggerClientEvent("sky_phone:realtime:nearby", src, { id = room.id, hostName = room.hostName })
                        end
                    end
                end
                broadcast(room)
            end
        end
    end
end)
AddEventHandler("playerDropped", function()
    local src = source
    voice_states[src], member_locks[src] = nil, nil
    for _, room in pairs(rooms) do
        if room.host == src or (room.kind == "call" and room.members[src]) then end_room(room)
        else remove_member(room, src) end
    end
end)
AddEventHandler("sky_phone:configurator:serverUpdated", function()
    for _, room in pairs(rooms) do end_room(room, "configuration_changed") end
end)
AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then for _, room in pairs(rooms) do end_room(room) end end
end)
