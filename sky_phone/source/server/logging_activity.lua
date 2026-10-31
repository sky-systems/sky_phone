-- Local Phonepanel history shares the server mutation catalog with Discord,
-- but never requires a webhook or an outbound HTTP request.
local ready = false
local next_prune_at = 0

Bridge.Database.AfterMigration("sky_phone", function()
    ready = true
end)

function SkyPhoneLog.ActivityEnabled()
    return ready and Config.AdminPanel.Enabled
end

function SkyPhoneLog.RecordActivity(category, action, status, source, details, actor, owner_identifier)
    if not SkyPhoneLog.ActivityEnabled() then return false end
    if owner_identifier == nil and source and source > 0 then
        owner_identifier = Bridge.Framework.GetIdentifier(source)
    end
    local encoded_details = json.encode(details or {})
    if #encoded_details > 16384 then
        encoded_details = json.encode({ logLimit = "Activity details exceeded the storage limit" })
    end
    local actor_name = tostring(actor.name or "Server")
    local name_end = utf8.offset(actor_name, 121)
    if name_end then actor_name = actor_name:sub(1, name_end - 1) end
    local result = Bridge.Database.Query([[
        INSERT INTO `sky_phone_activity_log`
            (`owner_identifier`, `actor_source`, `actor_name`, `device_imei`, `phone_number`,
                `category`, `action`, `status`, `details`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        owner_identifier or "", source or 0, actor_name,
        actor.imei or "", actor.phoneNumber or "", category, action, status, encoded_details,
    })
    local affected = type(result) == "number" and result
        or type(result) == "table" and tonumber(result.affectedRows)
    if affected ~= 1 then
        error("[sky_phone] Phone activity insert did not affect exactly one row.")
    end

    -- No timer or read-side writes. Bounded retention maintenance is paid once
    -- per ten minutes of mutation traffic, never once per action or panel poll.
    local now = os.time()
    if now >= next_prune_at then
        next_prune_at = now + 600
        local ok = pcall(Bridge.Database.Query, [[
            DELETE FROM `sky_phone_activity_log`
            WHERE `created_at` < DATE_SUB(NOW(), INTERVAL 30 DAY)
            ORDER BY `created_at`, `id` LIMIT 1000
        ]], {})
        if not ok then
            Bridge.Debug("warn", "[sky_phone] Could not prune expired phone activity records.")
        end
    end
    return true
end
