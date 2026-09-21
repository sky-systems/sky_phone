-- Keep the phone's transport independent from other resources. Measure the exact
-- wire arguments once; passing the packed string to the public helpers packs twice.
Bridge.Network = {}
local latent_threshold = 4096
local latent_bps = 1000000
local traffic = {}

local function pack_event(event_name, ...)
    local success, payload = pcall(msgpack.pack_args, ...)
    if not success then
        Bridge.Debug("error", "[sky_phone] Could not pack network event '%s': %s", event_name, tostring(payload))
        return nil
    end
    return payload
end

local function record_send(event_name, payload, latent)
    local entry = traffic[event_name]
    if not entry then
        entry = { calls = 0, bytes = 0, largest = 0, latent = 0 }
        traffic[event_name] = entry
    end
    entry.calls = entry.calls + 1
    entry.bytes = entry.bytes + #payload
    entry.largest = math.max(entry.largest, #payload)
    entry.latent = entry.latent + (latent and 1 or 0)
end

if IsDuplicityVersion() then
    function Bridge.Network.SendClient(event_name, target, ...)
        local payload = pack_event(event_name, ...)
        if not payload then return false end
        local latent = #payload >= latent_threshold
        local success, reason
        if latent then
            success, reason = pcall(TriggerLatentClientEventInternal,
                event_name, tostring(target), payload, #payload, latent_bps)
        else
            success, reason = pcall(TriggerClientEventInternal, event_name, tostring(target), payload, #payload)
        end
        if not success then
            Bridge.Debug("error", "[sky_phone] Could not send network event '%s': %s", event_name, tostring(reason))
            return false
        end
        record_send(event_name, payload, latent)
        return true
    end

    -- Console-only diagnostics. Counts are logical sends, not delivery ACKs or
    -- recipient-multiplied broadcast bytes. Never print payloads or player data.
    RegisterCommand("sky_phone_netstats", function(player_source, arguments)
        if player_source ~= 0 then return end
        if arguments[1] == "reset" then
            traffic = {}
            print("[sky_phone] Network counters reset.")
            return
        end
        print("[sky_phone] Network logical sends: event | calls | latent | bytes | largest bytes")
        local names = {}
        for name in pairs(traffic) do names[#names + 1] = name end
        table.sort(names)
        for _, name in ipairs(names) do
            local entry = traffic[name]
            print(("[sky_phone] %s | %d | %d | %d | %d"):format(
                name, entry.calls, entry.latent, entry.bytes, entry.largest))
        end
    end, true)
else
    function Bridge.Network.SendServer(event_name, ...)
        local payload = pack_event(event_name, ...)
        if not payload then return false end
        local latent = #payload >= latent_threshold
        local success, reason
        if latent then
            success, reason = pcall(TriggerLatentServerEventInternal, event_name, payload, #payload, latent_bps)
        else
            success, reason = pcall(TriggerServerEventInternal, event_name, payload, #payload)
        end
        if not success then
            Bridge.Debug("error", "[sky_phone] Could not send network event '%s': %s", event_name, tostring(reason))
            return false
        end
        return true
    end
end
