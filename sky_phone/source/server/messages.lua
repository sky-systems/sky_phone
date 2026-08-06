Bridge.Database.AfterMigration("sky_phone", function()

local allowed_voice_mimes = {
    ["audio/webm"] = true,
    ["audio/webm;codecs=opus"] = true,
}

local attachment_assets = {
    gif = {
        celebrate = true,
        hearts = true,
        party = true,
        thumbs_up = true,
        wow = true,
    },
    image = {
        ["camera-1"] = true,
        ["camera-2"] = true,
        ["camera-3"] = true,
        ["city-lights"] = true,
        ["desert-road"] = true,
        ["ocean-air"] = true,
        ["sunset-drive"] = true,
    },
    video = {
        ["city-loop"] = true,
        ["ocean-loop"] = true,
        ["sunset-loop"] = true,
    },
}

local attachment_mimes = {
    gif = "image/gif",
    image = "image/jpeg",
    video = "video/mp4",
}

local function allowed_media_url(value)
    if type(value) ~= "string" or #value == 0 or #value > Config.Media.UrlMaxLength then
        return false
    end
    local host = value:lower():match("^https://([^/:?#]+)")
    if not host then
        return false
    end
    for _, allowed_host in ipairs(Config.Media.AllowedGifHosts) do
        local suffix = "." .. allowed_host
        if host == allowed_host or host:sub(-#suffix) == suffix then
            return true
        end
    end
    return false
end

local function valid_attachment_asset(message_type, value)
    return attachment_assets[message_type][value]
        or message_type == "gif" and allowed_media_url(value)
end

local function valid_stored_attachment(message_type, value)
    if valid_attachment_asset(message_type, value) then
        return true
    end
    return (message_type == "image" or message_type == "video")
        and type(value) == "string"
        and #value <= Config.Media.UrlMaxLength
        and value:match("^https://") ~= nil
end

local function uuid()
    local rows = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    if not rows[1] or type(rows[1].id) ~= "string" then
        error("[sky_phone] Database did not generate an SMS UUID.")
    end
    return rows[1].id
end

local function trim(value)
    if type(value) ~= "string" then
        return nil
    end
    return value:match("^%s*(.-)%s*$")
end

local function current_device(source)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return nil, error_response
    end
    local device = SkyPhone.LoadDevice(session.imei)
    if not device then
        return nil, { success = false, error = "device_not_found" }
    end
    if not device.sim_id then
        return nil, { success = false, error = "no_sim" }
    end
    return device
end

local function format_message(row)
    row.media_duration_ms = tonumber(row.media_duration_ms)
    row.media_asset_id = nil
    if row.message_type == "voice" then
        local waveform = row.media_waveform and json.decode(row.media_waveform) or nil
        if type(waveform) ~= "table" then
            error(("[sky_phone] Voice message %s has an invalid waveform payload."):format(tostring(row.id)))
        end
        row.media_waveform = waveform
        row.media_payload = nil
    elseif attachment_assets[row.message_type] then
        if not valid_stored_attachment(row.message_type, row.media_payload) then
            error(("[sky_phone] Message %s has an invalid attachment asset."):format(tostring(row.id)))
        end
        row.media_asset_id = row.media_payload
        row.media_payload = nil
        row.media_waveform = nil
        if row.message_type ~= "video" then
            row.media_duration_ms = nil
        end
    else
        row.media_payload = nil
        row.media_duration_ms = nil
        row.media_mime = nil
        row.media_waveform = nil
    end
    return row
end

local function validate_attachment(source, device, message_type, data)
    if type(data.mediaAssetId) ~= "string" then
        return nil
    end
    local payload = data.mediaAssetId
    if not valid_attachment_asset(message_type, payload) then
        if message_type == "gif" then
            return nil
        end
        local media_id = tonumber(payload)
        if not media_id or media_id < 1 or media_id ~= math.floor(media_id) then
            return nil
        end
        local condition
        local params
        if device.account_id then
            condition = "`account_id` = ?"
            params = { media_id, tonumber(device.account_id) }
        else
            condition = "`account_id` IS NULL AND `device_imei` = ?"
            params = { media_id, device.imei }
        end
        local rows = Bridge.Database.Query(([[
            SELECT `url`, `media_type` FROM `sky_phone_media`
            WHERE `id` = ? AND %s
            LIMIT 1
        ]]):format(condition), params)
        local media = rows[1]
        local expected_type = message_type == "image" and "photo" or "video"
        if not media or media.media_type ~= expected_type
            or type(media.url) ~= "string"
            or #media.url > Config.Media.UrlMaxLength
            or not media.url:match("^https://")
        then
            Bridge.Debug("warn", ("[sky_phone] Rejected unowned SMS media from source %s."):format(tostring(source)))
            return nil
        end
        payload = media.url
    end
    local duration = nil
    if message_type == "video" and data.mediaDurationMs ~= nil then
        duration = tonumber(data.mediaDurationMs)
        if not duration or duration < 1000 or duration > Config.Messages.VideoMaxDurationMs then
            return nil
        end
        duration = math.floor(duration)
    end
    return {
        duration = duration,
        mime = attachment_mimes[message_type],
        payload = payload,
    }
end

local function validate_voice(data)
    if type(data.mediaPayload) ~= "string"
        or #data.mediaPayload == 0
        or #data.mediaPayload > Config.Messages.VoiceMaxBase64Length
        or data.mediaPayload:find("[^A-Za-z0-9+/=]") then
        return nil
    end
    if type(data.mediaMime) ~= "string" or not allowed_voice_mimes[data.mediaMime] then
        return nil
    end
    local duration = tonumber(data.mediaDurationMs)
    if not duration or duration < 300 or duration > Config.Messages.VoiceMaxDurationMs then
        return nil
    end
    if type(data.mediaWaveform) ~= "table"
        or #data.mediaWaveform < 8
        or #data.mediaWaveform > Config.Messages.VoiceWaveformSamples then
        return nil
    end
    local waveform = {}
    for index = 1, #data.mediaWaveform do
        local sample = tonumber(data.mediaWaveform[index])
        if not sample or sample < 0 or sample > 1 then
            return nil
        end
        waveform[index] = math.floor(sample * 1000 + 0.5) / 1000
    end
    return {
        duration = math.floor(duration),
        mime = data.mediaMime,
        payload = data.mediaPayload,
        waveform = json.encode(waveform),
    }
end

local function notify_sim(sim_id, event_name, data)
    local devices = Bridge.Database.Query([[
        SELECT d.`imei`, d.`device_name`, settings.`payload` AS `settings`
        FROM `sky_phone_devices` d
        LEFT JOIN `sky_phone_device_data` settings
            ON settings.`device_imei` = d.`imei` AND settings.`namespace` = 'settings'
        WHERE d.`sim_id` = ?
    ]], { sim_id })
    for _, device in ipairs(devices) do
        for _, player_source in ipairs(Bridge.Framework.GetPlayers()) do
            local source = tonumber(player_source) or player_source
            if SkyPhone.FindDeviceSlots(source, device.imei)[1] then
                local payload = {}
                for key, value in pairs(data) do
                    payload[key] = value
                end
                payload.device = {
                    imei = device.imei,
                    name = device.device_name,
                    settings = device.settings,
                }
                TriggerClientEvent(event_name, source, payload)
            end
        end
    end
end

Bridge.Callbacks.Register("sky_phone:messages:conversations", function(source)
    local device, error_response = current_device(source)
    if not device then
        return error_response
    end
    local rows = Bridge.Database.Query([[
        SELECT `id`, `sender_sim_id`, `recipient_sim_id`, `sender_number`, `recipient_number`,
            `message_type`, `body`, `read_at`, `created_at`
        FROM `sky_phone_sms_messages`
        WHERE `sender_sim_id` = ? OR `recipient_sim_id` = ?
        ORDER BY `created_at` DESC, `id` DESC LIMIT ?
    ]], { device.sim_id, device.sim_id, Config.Messages.ConversationScanLimit })
    local conversations = {}
    local ordered = {}
    for _, row in ipairs(rows) do
        local received = row.recipient_sim_id == device.sim_id
        local number = received and row.sender_number or row.recipient_number
        local conversation = conversations[number]
        if not conversation then
            conversation = {
                phoneNumber = number,
                lastMessage = row.body,
                lastMessageAt = row.created_at,
                lastMessageType = row.message_type,
                unread = 0,
            }
            conversations[number] = conversation
            ordered[#ordered + 1] = conversation
        end
        if received and not row.read_at then
            conversation.unread = conversation.unread + 1
        end
    end
    return { success = true, data = ordered }
end)

Bridge.Callbacks.Register("sky_phone:messages:thread", function(source, data)
    if type(data) ~= "table" then
        return { success = false, error = "invalid_request" }
    end
    local device, error_response = current_device(source)
    if not device then
        return error_response
    end
    local number = SkyPhoneSimNumber.Normalize(data.phoneNumber, Config.Sim.NumberLength, Config.Sim.NumberPrefix)
    if not number then
        return { success = false, error = "invalid_number" }
    end
    local rows = Bridge.Database.Query([[
        SELECT * FROM (
            SELECT `id`, `sender_number`, `recipient_number`, `message_type`, `body`, `media_payload`, `media_mime`,
                `media_duration_ms`, `media_waveform`, `read_at`, `created_at`,
                CASE WHEN `sender_sim_id` = ? THEN 'sent' ELSE 'received' END AS `direction`
            FROM `sky_phone_sms_messages`
            WHERE (`sender_sim_id` = ? AND `recipient_number` = ?)
                OR (`recipient_sim_id` = ? AND `sender_number` = ?)
            ORDER BY `created_at` DESC, `id` DESC LIMIT ?
        ) recent_messages
        ORDER BY `created_at` ASC, `id` ASC
    ]], { device.sim_id, device.sim_id, number, device.sim_id, number, Config.Messages.ThreadPageSize })
    for index = 1, #rows do
        rows[index] = format_message(rows[index])
    end
    Bridge.Database.Query([[
        UPDATE `sky_phone_sms_messages` SET `read_at` = CURRENT_TIMESTAMP
        WHERE `recipient_sim_id` = ? AND `sender_number` = ? AND `read_at` IS NULL
    ]], { device.sim_id, number })
    return { success = true, data = rows }
end)

Bridge.Callbacks.Register("sky_phone:messages:delete", function(source, data)
    if not SkyPhone.AllowOperation(source, "message_delete", 10, 60) then
        return { success = false, error = "rate_limited" }
    end
    if type(data) ~= "table" or type(data.phoneNumbers) ~= "table"
        or #data.phoneNumbers == 0 or #data.phoneNumbers > Config.Messages.DeleteBatchSize then
        return { success = false, error = "invalid_request" }
    end
    local device, error_response = current_device(source)
    if not device then
        return error_response
    end
    local numbers = {}
    local seen = {}
    for index = 1, #data.phoneNumbers do
        local number = SkyPhoneSimNumber.Normalize(
            data.phoneNumbers[index],
            Config.Sim.NumberLength,
            Config.Sim.NumberPrefix
        )
        if not number then
            return { success = false, error = "invalid_number" }
        end
        if not seen[number] then
            seen[number] = true
            numbers[#numbers + 1] = number
        end
    end
    local placeholders = {}
    for index = 1, #numbers do
        placeholders[index] = "?"
    end
    local values = { device.sim_id }
    for _, number in ipairs(numbers) do
        values[#values + 1] = number
    end
    values[#values + 1] = device.sim_id
    for _, number in ipairs(numbers) do
        values[#values + 1] = number
    end
    local list = table.concat(placeholders, ", ")
    Bridge.Database.Query(([[
        DELETE FROM `sky_phone_sms_messages`
        WHERE (`sender_sim_id` = ? AND `recipient_number` IN (%s))
            OR (`recipient_sim_id` = ? AND `sender_number` IN (%s))
    ]]):format(list, list), values)
    TriggerClientEvent("sky_phone:messages:changed", source, {})
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:messages:media", function(source, data)
    if not SkyPhone.AllowOperation(source, "message_media", Config.Messages.MediaLoadsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    if type(data) ~= "table" or type(data.id) ~= "string" then
        return { success = false, error = "invalid_request" }
    end
    local device, error_response = current_device(source)
    if not device then
        return error_response
    end
    local rows = Bridge.Database.Query([[
        SELECT `media_payload`, `media_mime`
        FROM `sky_phone_sms_messages`
        WHERE `id` = ? AND `message_type` = 'voice'
            AND (`sender_sim_id` = ? OR `recipient_sim_id` = ?)
        LIMIT 1
    ]], { data.id, device.sim_id, device.sim_id })
    if not rows[1] or type(rows[1].media_payload) ~= "string" then
        return { success = false, error = "message_not_found" }
    end
    return {
        success = true,
        data = {
            mime = rows[1].media_mime,
            payload = rows[1].media_payload,
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:messages:send", function(source, data)
    if not SkyPhone.AllowOperation(source, "message_send", Config.Messages.SendsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    if type(data) ~= "table" then
        return { success = false, error = "invalid_request" }
    end
    local device, error_response = current_device(source)
    if not device then
        return error_response
    end
    local number = SkyPhoneSimNumber.Normalize(data.phoneNumber, Config.Sim.NumberLength, Config.Sim.NumberPrefix)
    if not number then
        return { success = false, error = "invalid_number" }
    end
    if number == device.phone_number then
        return { success = false, error = "self_message" }
    end
    local message_type = data.messageType or "text"
    local body = trim(data.body) or ""
    local voice = nil
    local attachment = nil
    if message_type == "text" then
        if body == "" or #body > Config.Messages.BodyMaxLength then
            return { success = false, error = "invalid_message" }
        end
    elseif message_type == "voice" then
        voice = validate_voice(data)
        if not voice then
            return { success = false, error = "invalid_voice" }
        end
        body = ""
    elseif attachment_assets[message_type] then
        attachment = validate_attachment(source, device, message_type, data)
        if not attachment then
            return { success = false, error = "invalid_attachment" }
        end
        body = ""
    else
        return { success = false, error = "invalid_request" }
    end
    local recipients = Bridge.Database.Query(
        "SELECT `id`, `phone_number` FROM `sky_phone_sims` WHERE `phone_number` = ? LIMIT 1",
        { number }
    )
    local recipient = recipients[1]
    if not recipient then
        return { success = false, error = "recipient_not_found" }
    end
    local id = uuid()
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_sms_messages`
            (`id`, `sender_sim_id`, `recipient_sim_id`, `sender_number`, `recipient_number`, `message_type`,
                `body`, `media_payload`, `media_mime`, `media_duration_ms`, `media_waveform`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        id,
        device.sim_id,
        recipient.id,
        device.phone_number,
        number,
        message_type,
        body,
        voice and voice.payload or attachment and attachment.payload or nil,
        voice and voice.mime or attachment and attachment.mime or nil,
        voice and voice.duration or attachment and attachment.duration or nil,
        voice and voice.waveform or nil,
    })
    local rows = Bridge.Database.Query([[
        SELECT `id`, `sender_number`, `recipient_number`, `message_type`, `body`, `media_payload`, `media_mime`,
            `media_duration_ms`, `media_waveform`, `read_at`, `created_at`, 'sent' AS `direction`
        FROM `sky_phone_sms_messages` WHERE `id` = ? LIMIT 1
    ]], { id })
    local message = format_message(rows[1])
    TriggerClientEvent("sky_phone:messages:changed", source, { phoneNumber = number })
    notify_sim(recipient.id, "sky_phone:messages:new", {
        message = message,
        phoneNumber = device.phone_number,
        sender = device.phone_number,
        voice = message_type == "voice",
    })
    return { success = true, data = message }
end)

end)
