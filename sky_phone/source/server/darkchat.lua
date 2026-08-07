Bridge.Database.AfterMigration("sky_phone", function()

local allowed_voice_mimes = {
    ["audio/webm"] = true,
    ["audio/webm;codecs=opus"] = true,
}

local report_reasons = {
    spam = true,
    harassment = true,
    threats = true,
    illegal = true,
    other = true,
}

local notification_modes = {
    full = true,
    private = true,
    hidden = true,
}

local function allowed_gif_url(value)
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

local reaction_values = {
    ["❤️"] = true,
    ["👍"] = true,
    ["👎"] = true,
    ["😂"] = true,
    ["‼️"] = true,
    ["❓"] = true,
}

local function trim(value)
    if type(value) ~= "string" then
        return nil
    end
    return value:match("^%s*(.-)%s*$")
end

local function uuid()
    local rows = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    if not rows[1] or type(rows[1].id) ~= "string" then
        error("[sky_phone] Database did not generate a DarkChat UUID.")
    end
    return rows[1].id
end

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end
    return type(result) == "table" and tonumber(result.affectedRows) or 0
end

local function profile_payload(row)
    return {
        id = tonumber(row.id),
        darkId = row.dark_id,
        inviteCode = row.invite_code,
        alias = row.alias,
        avatarSeed = tonumber(row.avatar_seed),
        notificationMode = row.notification_mode,
        activityVisible = row.activity_visible == 1 or row.activity_visible == true,
        createdAt = row.created_at,
    }
end

local function load_profile(account_id)
    local rows = Bridge.Database.Query([[
        SELECT `id`, `dark_id`, `invite_code`, `alias`, `avatar_seed`, `notification_mode`,
            `activity_visible`, `created_at`
        FROM `sky_phone_darkchat_profiles`
        WHERE `account_id` = ? LIMIT 1
    ]], { account_id })
    return rows[1]
end

local function create_profile(account_id)
    for _ = 1, 10 do
        local entropy = uuid():gsub("%-", ""):upper()
        local dark_id = ("dark:%s-%s"):format(entropy:sub(1, 4), entropy:sub(5, 8))
        local invite_code = ("DC-%s-%s"):format(entropy:sub(9, 12), entropy:sub(13, 16))
        local seed = tonumber(entropy:sub(17, 23), 16) or 1
        local result = Bridge.Database.Query([[
            INSERT IGNORE INTO `sky_phone_darkchat_profiles`
                (`account_id`, `dark_id`, `invite_code`, `alias`, `avatar_seed`)
            VALUES (?, ?, ?, ?, ?)
        ]], { account_id, dark_id, invite_code, "Shadow " .. entropy:sub(1, 4), seed })
        if affected_rows(result) > 0 then
            return load_profile(account_id)
        end
        local existing = load_profile(account_id)
        if existing then
            return existing
        end
    end
    error("[sky_phone] Could not generate a unique DarkChat profile after 10 attempts.")
end

local function require_profile(source)
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then
        return nil, nil, error_response
    end
    local profile = load_profile(account.id) or create_profile(account.id)
    return profile, account
end

local function load_membership(profile_id, conversation_id)
    local rows = Bridge.Database.Query([[
        SELECT mine.`conversation_id`, mine.`notifications_enabled`, mine.`read_receipts`, mine.`cleared_at`,
            conversation.`disappearing_seconds`, conversation.`created_at` AS `conversation_created_at`,
            peer.`id` AS `peer_id`, peer.`account_id` AS `peer_account_id`, peer.`dark_id` AS `peer_dark_id`,
            peer.`alias` AS `peer_alias`, peer.`avatar_seed` AS `peer_avatar_seed`,
            peer.`activity_visible` AS `peer_activity_visible`, peer_member.`last_read_at` AS `peer_last_read_at`,
            contact.`id` AS `contact_id`, contact.`alias_override`, block_mine.`id` AS `blocked_by_me`,
            block_peer.`id` AS `blocked_by_peer`
        FROM `sky_phone_darkchat_members` mine
        JOIN `sky_phone_darkchat_conversations` conversation ON conversation.`id` = mine.`conversation_id`
        JOIN `sky_phone_darkchat_members` peer_member
            ON peer_member.`conversation_id` = mine.`conversation_id` AND peer_member.`profile_id` <> mine.`profile_id`
        JOIN `sky_phone_darkchat_profiles` peer ON peer.`id` = peer_member.`profile_id`
        LEFT JOIN `sky_phone_darkchat_contacts` contact
            ON contact.`profile_id` = mine.`profile_id` AND contact.`contact_profile_id` = peer.`id`
        LEFT JOIN `sky_phone_darkchat_blocks` block_mine
            ON block_mine.`blocker_profile_id` = mine.`profile_id` AND block_mine.`blocked_profile_id` = peer.`id`
        LEFT JOIN `sky_phone_darkchat_blocks` block_peer
            ON block_peer.`blocker_profile_id` = peer.`id` AND block_peer.`blocked_profile_id` = mine.`profile_id`
        WHERE mine.`profile_id` = ? AND mine.`conversation_id` = ?
        LIMIT 1
    ]], { profile_id, conversation_id })
    return rows[1]
end

local function peer_payload(row)
    return {
        id = tonumber(row.peer_id),
        darkId = row.peer_dark_id,
        alias = row.alias_override or row.peer_alias,
        originalAlias = row.peer_alias,
        avatarSeed = tonumber(row.peer_avatar_seed),
        activityVisible = row.peer_activity_visible == 1 or row.peer_activity_visible == true,
        isContact = row.contact_id ~= nil,
        blocked = row.blocked_by_me ~= nil,
    }
end

local function decode_array(value, context)
    if value == nil then
        return {}
    end
    local decoded = json.decode(value)
    if type(decoded) ~= "table" then
        error(("[sky_phone] Invalid DarkChat JSON in %s."):format(context))
    end
    return decoded
end

local function message_payload(row, profile_id)
    local deleted_for = decode_array(row.deleted_for_profiles, "deleted_for_profiles")
    for _, deleted_profile_id in ipairs(deleted_for) do
        if tonumber(deleted_profile_id) == tonumber(profile_id) then
            return nil
        end
    end
    local deleted_everywhere = row.deleted_for_everyone == 1 or row.deleted_for_everyone == true
    local reactions = decode_array(row.reactions, "reactions")
    local waveform = row.media_waveform and decode_array(row.media_waveform, "media_waveform") or nil
    return {
        id = row.id,
        conversationId = row.conversation_id,
        direction = tonumber(row.sender_profile_id) == tonumber(profile_id) and "sent" or "received",
        senderProfileId = tonumber(row.sender_profile_id),
        messageType = deleted_everywhere and "system" or row.message_type,
        body = deleted_everywhere and "message_deleted" or row.body,
        mediaMime = deleted_everywhere and nil or row.media_mime,
        mediaPayload = not deleted_everywhere and row.message_type ~= "voice" and row.media_payload or nil,
        mediaDurationMs = deleted_everywhere and nil or tonumber(row.media_duration_ms),
        mediaWaveform = deleted_everywhere and nil or waveform,
        replyToId = row.reply_to_id,
        replyBody = row.reply_body,
        reactions = reactions,
        expiresAt = row.expires_at,
        createdAt = row.created_at,
        readAt = row.peer_last_read_at and row.peer_last_read_at >= row.created_at and row.peer_last_read_at or nil,
        deletedForEveryone = deleted_everywhere,
    }
end

local function list_contacts(profile_id)
    local rows = Bridge.Database.Query([[
        SELECT target.`id`, target.`dark_id`, target.`alias`, target.`avatar_seed`, contact.`alias_override`,
            contact.`created_at`
        FROM `sky_phone_darkchat_contacts` contact
        JOIN `sky_phone_darkchat_profiles` target ON target.`id` = contact.`contact_profile_id`
        WHERE contact.`profile_id` = ?
        ORDER BY COALESCE(contact.`alias_override`, target.`alias`) ASC
    ]], { profile_id })
    local contacts = {}
    for index, row in ipairs(rows) do
        contacts[index] = {
            id = tonumber(row.id),
            darkId = row.dark_id,
            alias = row.alias_override or row.alias,
            originalAlias = row.alias,
            avatarSeed = tonumber(row.avatar_seed),
            createdAt = row.created_at,
        }
    end
    return contacts
end

local function list_conversations(profile_id)
    local rows = Bridge.Database.Query([[
        SELECT conversation.`id`, conversation.`disappearing_seconds`, conversation.`updated_at`,
            peer.`id` AS `peer_id`, peer.`dark_id` AS `peer_dark_id`, peer.`alias` AS `peer_alias`,
            peer.`avatar_seed` AS `peer_avatar_seed`, peer.`activity_visible`, contact.`alias_override`,
            block_mine.`id` AS `blocked_by_me`, latest.`body` AS `last_body`, latest.`message_type` AS `last_type`,
            latest.`created_at` AS `last_at`, latest.`deleted_for_everyone`,
            (SELECT COUNT(*) FROM `sky_phone_darkchat_messages` unread
                WHERE unread.`conversation_id` = conversation.`id`
                    AND unread.`sender_profile_id` <> mine.`profile_id`
                    AND unread.`created_at` > COALESCE(mine.`last_read_at`, '1970-01-01')
                    AND (unread.`expires_at` IS NULL OR unread.`expires_at` > CURRENT_TIMESTAMP)) AS `unread`
        FROM `sky_phone_darkchat_members` mine
        JOIN `sky_phone_darkchat_conversations` conversation ON conversation.`id` = mine.`conversation_id`
        JOIN `sky_phone_darkchat_members` peer_member
            ON peer_member.`conversation_id` = conversation.`id` AND peer_member.`profile_id` <> mine.`profile_id`
        JOIN `sky_phone_darkchat_profiles` peer ON peer.`id` = peer_member.`profile_id`
        LEFT JOIN `sky_phone_darkchat_contacts` contact
            ON contact.`profile_id` = mine.`profile_id` AND contact.`contact_profile_id` = peer.`id`
        LEFT JOIN `sky_phone_darkchat_blocks` block_mine
            ON block_mine.`blocker_profile_id` = mine.`profile_id` AND block_mine.`blocked_profile_id` = peer.`id`
        LEFT JOIN `sky_phone_darkchat_messages` latest ON latest.`id` = (
            SELECT message.`id` FROM `sky_phone_darkchat_messages` message
            WHERE message.`conversation_id` = conversation.`id`
                AND message.`created_at` >= COALESCE(mine.`cleared_at`, '1970-01-01')
                AND (message.`expires_at` IS NULL OR message.`expires_at` > CURRENT_TIMESTAMP)
            ORDER BY message.`created_at` DESC, message.`id` DESC LIMIT 1
        )
        WHERE mine.`profile_id` = ?
        ORDER BY COALESCE(latest.`created_at`, conversation.`updated_at`) DESC
    ]], { profile_id })
    local conversations = {}
    for index, row in ipairs(rows) do
        conversations[index] = {
            id = row.id,
            peer = {
                id = tonumber(row.peer_id),
                darkId = row.peer_dark_id,
                alias = row.alias_override or row.peer_alias,
                avatarSeed = tonumber(row.peer_avatar_seed),
                activityVisible = row.activity_visible == 1 or row.activity_visible == true,
            },
            disappearingSeconds = tonumber(row.disappearing_seconds),
            blocked = row.blocked_by_me ~= nil,
            lastMessage = row.deleted_for_everyone == 1 and "message_deleted" or row.last_body or "",
            lastMessageType = row.deleted_for_everyone == 1 and "system" or row.last_type or "system",
            lastMessageAt = row.last_at or row.updated_at,
            unread = tonumber(row.unread) or 0,
        }
    end
    return conversations
end

local function notify_profile(profile_id, event_name, data)
    local rows = Bridge.Database.Query([[
        SELECT `account_id`, `notification_mode` FROM `sky_phone_darkchat_profiles`
        WHERE `id` = ? LIMIT 1
    ]], { profile_id })
    local target = rows[1]
    if not target then
        return
    end
    if event_name == "sky_phone:darkchat:new" and data.conversationId then
        local members = Bridge.Database.Query([[
            SELECT `notifications_enabled` FROM `sky_phone_darkchat_members`
            WHERE `profile_id` = ? AND `conversation_id` = ? LIMIT 1
        ]], { profile_id, data.conversationId })
        if not members[1] or members[1].notifications_enabled == 0 then
            return
        end
    end
    data.notificationMode = target.notification_mode
    SkyPhone.NotifyAccountDevices(target.account_id, event_name, data)
end

local function valid_voice(data)
    if type(data.mediaPayload) ~= "string" or #data.mediaPayload == 0
        or #data.mediaPayload > Config.DarkChat.VoiceMaxBase64Length
        or data.mediaPayload:find("[^A-Za-z0-9+/=]") then
        return nil
    end
    if type(data.mediaMime) ~= "string" or not allowed_voice_mimes[data.mediaMime] then
        return nil
    end
    local duration = tonumber(data.mediaDurationMs)
    if not duration or duration < 300 or duration > Config.DarkChat.VoiceMaxDurationMs then
        return nil
    end
    if type(data.mediaWaveform) ~= "table" or #data.mediaWaveform < 8
        or #data.mediaWaveform > Config.DarkChat.VoiceWaveformSamples then
        return nil
    end
    local waveform = {}
    for index, value in ipairs(data.mediaWaveform) do
        local sample = tonumber(value)
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

Bridge.Callbacks.Register("sky_phone:darkchat:bootstrap", function(source)
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    return {
        success = true,
        data = {
            profile = profile_payload(profile),
            contacts = list_contacts(profile.id),
            conversations = list_conversations(profile.id),
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:darkchat:update-profile", function(source, data)
    if not SkyPhone.AllowOperation(source, "darkchat_profile", 10, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, account, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local alias = trim(data and data.alias)
    local mode = data and data.notificationMode
    if not alias or alias == "" or #alias > Config.DarkChat.AliasMaxLength
        or not notification_modes[mode] or type(data.activityVisible) ~= "boolean" then
        return { success = false, error = "invalid_profile" }
    end
    Bridge.Database.Query([[
        UPDATE `sky_phone_darkchat_profiles`
        SET `alias` = ?, `notification_mode` = ?, `activity_visible` = ?
        WHERE `id` = ?
    ]], { alias, mode, data.activityVisible and 1 or 0, profile.id })
    return { success = true, data = profile_payload(load_profile(account.id)) }
end)

Bridge.Callbacks.Register("sky_phone:darkchat:start", function(source, data)
    if not SkyPhone.AllowOperation(source, "darkchat_start", 20, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local identifier = trim(data and data.identifier)
    if not identifier or #identifier > 32 then
        return { success = false, error = "invalid_dark_id" }
    end
    local targets = Bridge.Database.Query([[
        SELECT `id` FROM `sky_phone_darkchat_profiles`
        WHERE UPPER(`dark_id`) = UPPER(?) OR UPPER(`invite_code`) = UPPER(?)
        LIMIT 1
    ]], { identifier, identifier })
    local target = targets[1]
    if not target then
        return { success = false, error = "profile_not_found" }
    end
    if tonumber(target.id) == tonumber(profile.id) then
        return { success = false, error = "self_chat" }
    end
    local existing = Bridge.Database.Query([[
        SELECT mine.`conversation_id`
        FROM `sky_phone_darkchat_members` mine
        JOIN `sky_phone_darkchat_members` peer ON peer.`conversation_id` = mine.`conversation_id`
        WHERE mine.`profile_id` = ? AND peer.`profile_id` = ?
        LIMIT 1
    ]], { profile.id, target.id })
    local conversation_id = existing[1] and existing[1].conversation_id
    if not conversation_id then
        conversation_id = uuid()
        local created = Bridge.Database.Transaction({
            {
                query = "INSERT INTO `sky_phone_darkchat_conversations` (`id`) VALUES (?)",
                params = { conversation_id },
            },
            {
                query = "INSERT INTO `sky_phone_darkchat_members` (`conversation_id`, `profile_id`) VALUES (?, ?)",
                params = { conversation_id, profile.id },
            },
            {
                query = "INSERT INTO `sky_phone_darkchat_members` (`conversation_id`, `profile_id`) VALUES (?, ?)",
                params = { conversation_id, target.id },
            },
        })
        if not created then
            error("[sky_phone] Failed to create a DarkChat conversation transaction.")
        end
    end
    return { success = true, data = { conversationId = conversation_id } }
end)

Bridge.Callbacks.Register("sky_phone:darkchat:thread", function(source, data)
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local conversation_id = data and data.conversationId
    if type(conversation_id) ~= "string" or #conversation_id ~= 36 then
        return { success = false, error = "invalid_conversation" }
    end
    local membership = load_membership(profile.id, conversation_id)
    if not membership then
        return { success = false, error = "conversation_not_found" }
    end
    Bridge.Database.Query([[
        UPDATE `sky_phone_darkchat_members` SET `last_read_at` = CURRENT_TIMESTAMP
        WHERE `conversation_id` = ? AND `profile_id` = ?
    ]], { conversation_id, profile.id })
    if tonumber(membership.disappearing_seconds) == -1 then
        Bridge.Database.Query([[
            UPDATE `sky_phone_darkchat_messages`
            SET `expires_at` = DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 1 SECOND)
            WHERE `conversation_id` = ? AND `sender_profile_id` <> ? AND `expires_at` IS NULL
        ]], { conversation_id, profile.id })
    end
    local rows = Bridge.Database.Query([[
        SELECT message.*, reply.`body` AS `reply_body`, peer_member.`last_read_at` AS `peer_last_read_at`
        FROM `sky_phone_darkchat_messages` message
        JOIN `sky_phone_darkchat_members` mine
            ON mine.`conversation_id` = message.`conversation_id` AND mine.`profile_id` = ?
        JOIN `sky_phone_darkchat_members` peer_member
            ON peer_member.`conversation_id` = message.`conversation_id` AND peer_member.`profile_id` <> ?
        LEFT JOIN `sky_phone_darkchat_messages` reply ON reply.`id` = message.`reply_to_id`
        WHERE message.`conversation_id` = ?
            AND message.`created_at` >= COALESCE(mine.`cleared_at`, '1970-01-01')
            AND (message.`expires_at` IS NULL OR message.`expires_at` > CURRENT_TIMESTAMP)
        ORDER BY message.`created_at` DESC, message.`id` DESC LIMIT ?
    ]], { profile.id, profile.id, conversation_id, Config.DarkChat.ThreadPageSize })
    local messages = {}
    for index = #rows, 1, -1 do
        local formatted = message_payload(rows[index], profile.id)
        if formatted then
            messages[#messages + 1] = formatted
        end
    end
    return {
        success = true,
        data = {
            conversation = {
                id = conversation_id,
                peer = peer_payload(membership),
                disappearingSeconds = tonumber(membership.disappearing_seconds),
                notificationsEnabled = membership.notifications_enabled == 1 or membership.notifications_enabled == true,
                readReceipts = membership.read_receipts == 1 or membership.read_receipts == true,
                blockedByPeer = membership.blocked_by_peer ~= nil,
                createdAt = membership.conversation_created_at,
            },
            messages = messages,
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:darkchat:send", function(source, data)
    if not SkyPhone.AllowOperation(source, "darkchat_send", Config.DarkChat.SendsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    if type(data) ~= "table" then
        return { success = false, error = "invalid_request" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local conversation_id = data and data.conversationId
    local membership = type(conversation_id) == "string" and load_membership(profile.id, conversation_id) or nil
    if not membership then
        return { success = false, error = "conversation_not_found" }
    end
    if membership.blocked_by_me or membership.blocked_by_peer then
        return { success = false, error = "blocked" }
    end
    local message_type = data.messageType
    local body = trim(data.body) or ""
    local media_payload
    local media_mime
    local media_duration
    local media_waveform
    if message_type == "text" or message_type == "emoji" then
        if body == "" or #body > Config.DarkChat.BodyMaxLength then
            return { success = false, error = "invalid_message" }
        end
    elseif message_type == "gif" then
        if not allowed_gif_url(data.mediaPayload) then
            return { success = false, error = "invalid_gif" }
        end
        media_payload = data.mediaPayload
        media_mime = "image/gif"
    elseif message_type == "voice" then
        local voice = valid_voice(data)
        if not voice then
            return { success = false, error = "invalid_voice" }
        end
        media_payload = voice.payload
        media_mime = voice.mime
        media_duration = voice.duration
        media_waveform = voice.waveform
    elseif message_type == "image" or message_type == "video" then
        local media_type = message_type == "image" and "photo" or "video"
        local media_url, media_error = SkyPhoneMedia.ResolveOwnedMedia(source, data.mediaAssetId, media_type)
        if not media_url then
            return { success = false, error = media_error }
        end
        media_payload = media_url
        media_mime = message_type == "image" and "image/jpeg" or "video/mp4"
    else
        return { success = false, error = "invalid_message" }
    end
    local reply_to = data.replyToId
    if reply_to ~= nil then
        local reply = Bridge.Database.Query([[
            SELECT `id` FROM `sky_phone_darkchat_messages`
            WHERE `id` = ? AND `conversation_id` = ? LIMIT 1
        ]], { reply_to, conversation_id })
        if not reply[1] then
            return { success = false, error = "invalid_reply" }
        end
    end
    local timer = tonumber(membership.disappearing_seconds) or 0
    local id = uuid()
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_darkchat_messages`
            (`id`, `conversation_id`, `sender_profile_id`, `message_type`, `body`, `media_payload`,
                `media_mime`, `media_duration_ms`, `media_waveform`, `reply_to_id`, `expires_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
            IF(? > 0, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL ? SECOND), NULL))
    ]], {
        id, conversation_id, profile.id, message_type, body, media_payload, media_mime,
        media_duration, media_waveform, reply_to, timer, timer,
    })
    Bridge.Database.Query(
        "UPDATE `sky_phone_darkchat_conversations` SET `updated_at` = CURRENT_TIMESTAMP WHERE `id` = ?",
        { conversation_id }
    )
    local rows = Bridge.Database.Query([[
        SELECT message.*, reply.`body` AS `reply_body`, NULL AS `peer_last_read_at`
        FROM `sky_phone_darkchat_messages` message
        LEFT JOIN `sky_phone_darkchat_messages` reply ON reply.`id` = message.`reply_to_id`
        WHERE message.`id` = ? LIMIT 1
    ]], { id })
    local message = message_payload(rows[1], profile.id)
    TriggerClientEvent("sky_phone:darkchat:changed", source, { conversationId = conversation_id })
    notify_profile(tonumber(membership.peer_id), "sky_phone:darkchat:new", {
        conversationId = conversation_id,
        sender = profile.alias,
        messageType = message_type,
        preview = (message_type == "text" or message_type == "emoji") and body or message_type,
    })
    return { success = true, data = message }
end)

Bridge.Callbacks.Register("sky_phone:darkchat:media", function(source, data)
    if not SkyPhone.AllowOperation(source, "darkchat_media", Config.DarkChat.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local rows = Bridge.Database.Query([[
        SELECT message.`media_payload`, message.`media_mime`
        FROM `sky_phone_darkchat_messages` message
        JOIN `sky_phone_darkchat_members` member ON member.`conversation_id` = message.`conversation_id`
        WHERE message.`id` = ? AND member.`profile_id` = ? AND message.`message_type` = 'voice'
            AND (message.`expires_at` IS NULL OR message.`expires_at` > CURRENT_TIMESTAMP)
        LIMIT 1
    ]], { data and data.messageId, profile.id })
    if not rows[1] or type(rows[1].media_payload) ~= "string" then
        return { success = false, error = "message_not_found" }
    end
    return { success = true, data = { payload = rows[1].media_payload, mime = rows[1].media_mime } }
end)

Bridge.Callbacks.Register("sky_phone:darkchat:react", function(source, data)
    if not SkyPhone.AllowOperation(source, "darkchat_react", Config.DarkChat.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    if not reaction_values[data and data.reaction] then
        return { success = false, error = "invalid_reaction" }
    end
    local rows = Bridge.Database.Query([[
        SELECT message.`id`, message.`conversation_id`, message.`reactions`
        FROM `sky_phone_darkchat_messages` message
        JOIN `sky_phone_darkchat_members` member ON member.`conversation_id` = message.`conversation_id`
        WHERE message.`id` = ? AND member.`profile_id` = ? LIMIT 1
    ]], { data.messageId, profile.id })
    local message = rows[1]
    if not message then
        return { success = false, error = "message_not_found" }
    end
    local reactions = decode_array(message.reactions, "reactions")
    local key = tostring(profile.id)
    if reactions[key] == data.reaction then
        reactions[key] = nil
    else
        reactions[key] = data.reaction
    end
    Bridge.Database.Query("UPDATE `sky_phone_darkchat_messages` SET `reactions` = ? WHERE `id` = ?", {
        json.encode(reactions), message.id,
    })
    TriggerClientEvent("sky_phone:darkchat:changed", source, { conversationId = message.conversation_id })
    local membership = load_membership(profile.id, message.conversation_id)
    notify_profile(tonumber(membership.peer_id), "sky_phone:darkchat:changed", {
        conversationId = message.conversation_id,
    })
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:darkchat:message-action", function(source, data)
    if not SkyPhone.AllowOperation(source, "darkchat_message_action", Config.DarkChat.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local rows = Bridge.Database.Query([[
        SELECT message.* FROM `sky_phone_darkchat_messages` message
        JOIN `sky_phone_darkchat_members` member ON member.`conversation_id` = message.`conversation_id`
        WHERE message.`id` = ? AND member.`profile_id` = ? LIMIT 1
    ]], { data and data.messageId, profile.id })
    local message = rows[1]
    if not message then
        return { success = false, error = "message_not_found" }
    end
    if data.action == "delete_me" then
        local deleted_for = decode_array(message.deleted_for_profiles, "deleted_for_profiles")
        local already_deleted = false
        for _, value in ipairs(deleted_for) do
            already_deleted = already_deleted or tonumber(value) == tonumber(profile.id)
        end
        if not already_deleted then
            deleted_for[#deleted_for + 1] = tonumber(profile.id)
        end
        Bridge.Database.Query("UPDATE `sky_phone_darkchat_messages` SET `deleted_for_profiles` = ? WHERE `id` = ?", {
            json.encode(deleted_for), message.id,
        })
    elseif data.action == "delete_all" then
        if tonumber(message.sender_profile_id) ~= tonumber(profile.id) then
            return { success = false, error = "not_message_owner" }
        end
        Bridge.Database.Query([[
            UPDATE `sky_phone_darkchat_messages`
            SET `deleted_for_everyone` = 1, `body` = '', `media_payload` = NULL,
                `media_mime` = NULL, `media_duration_ms` = NULL, `media_waveform` = NULL
            WHERE `id` = ?
        ]], { message.id })
    else
        return { success = false, error = "invalid_action" }
    end
    local membership = load_membership(profile.id, message.conversation_id)
    TriggerClientEvent("sky_phone:darkchat:changed", source, { conversationId = message.conversation_id })
    notify_profile(tonumber(membership.peer_id), "sky_phone:darkchat:changed", {
        conversationId = message.conversation_id,
    })
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:darkchat:update-conversation", function(source, data)
    if not SkyPhone.AllowOperation(source, "darkchat_conversation_settings", Config.DarkChat.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local membership = load_membership(profile.id, data and data.conversationId)
    if not membership then
        return { success = false, error = "conversation_not_found" }
    end
    if type(data.notificationsEnabled) ~= "boolean" or type(data.readReceipts) ~= "boolean" then
        return { success = false, error = "invalid_settings" }
    end
    local timer = tonumber(data.disappearingSeconds)
    if not timer or not Config.DarkChat.AllowedDisappearTimers[timer] then
        return { success = false, error = "invalid_timer" }
    end
    Bridge.Database.Transaction({
        {
            query = "UPDATE `sky_phone_darkchat_members` SET `notifications_enabled` = ?, `read_receipts` = ? WHERE `conversation_id` = ? AND `profile_id` = ?",
            params = { data.notificationsEnabled and 1 or 0, data.readReceipts and 1 or 0, data.conversationId, profile.id },
        },
        {
            query = "UPDATE `sky_phone_darkchat_conversations` SET `disappearing_seconds` = ? WHERE `id` = ?",
            params = { timer, data.conversationId },
        },
        {
            query = "INSERT INTO `sky_phone_darkchat_messages` (`id`, `conversation_id`, `message_type`, `body`) VALUES (?, ?, 'system', ?)",
            params = { uuid(), data.conversationId, "timer_changed:" .. tostring(timer) },
        },
    })
    TriggerClientEvent("sky_phone:darkchat:changed", source, { conversationId = data.conversationId })
    notify_profile(tonumber(membership.peer_id), "sky_phone:darkchat:changed", {
        conversationId = data.conversationId,
    })
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:darkchat:add-contact", function(source, data)
    if not SkyPhone.AllowOperation(source, "darkchat_contact", Config.DarkChat.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local membership = load_membership(profile.id, data and data.conversationId)
    local alias = trim(data and data.alias)
    if not membership or not alias or alias == "" or #alias > Config.DarkChat.AliasMaxLength then
        return { success = false, error = "invalid_contact" }
    end
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_darkchat_contacts` (`profile_id`, `contact_profile_id`, `alias_override`)
        VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `alias_override` = VALUES(`alias_override`)
    ]], { profile.id, membership.peer_id, alias })
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:darkchat:remove-contact", function(source, data)
    if not SkyPhone.AllowOperation(source, "darkchat_contact", Config.DarkChat.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local membership = load_membership(profile.id, data and data.conversationId)
    if not membership then
        return { success = false, error = "conversation_not_found" }
    end
    Bridge.Database.Query([[
        DELETE FROM `sky_phone_darkchat_contacts` WHERE `profile_id` = ? AND `contact_profile_id` = ?
    ]], { profile.id, membership.peer_id })
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:darkchat:block", function(source, data)
    if not SkyPhone.AllowOperation(source, "darkchat_block", Config.DarkChat.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local membership = load_membership(profile.id, data and data.conversationId)
    if not membership or type(data.blocked) ~= "boolean" then
        return { success = false, error = "invalid_request" }
    end
    if data.blocked then
        Bridge.Database.Query([[
            INSERT IGNORE INTO `sky_phone_darkchat_blocks` (`blocker_profile_id`, `blocked_profile_id`)
            VALUES (?, ?)
        ]], { profile.id, membership.peer_id })
    else
        Bridge.Database.Query([[
            DELETE FROM `sky_phone_darkchat_blocks` WHERE `blocker_profile_id` = ? AND `blocked_profile_id` = ?
        ]], { profile.id, membership.peer_id })
    end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:darkchat:report", function(source, data)
    if not SkyPhone.AllowOperation(source, "darkchat_report", Config.DarkChat.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local membership = load_membership(profile.id, data and data.conversationId)
    local reason = data and data.reason
    local details = trim(data and data.details) or ""
    if not membership or not report_reasons[reason] or #details > 500 then
        return { success = false, error = "invalid_report" }
    end
    local count = Bridge.Database.Query([[
        SELECT COUNT(*) AS `count` FROM `sky_phone_darkchat_reports`
        WHERE `reporter_profile_id` = ? AND `created_at` >= DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 DAY)
    ]], { profile.id })
    if tonumber(count[1] and count[1].count) >= Config.DarkChat.ReportsPerDay then
        return { success = false, error = "rate_limited" }
    end
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_darkchat_reports`
            (`id`, `reporter_profile_id`, `reported_profile_id`, `conversation_id`, `message_id`, `reason`, `details`)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { uuid(), profile.id, membership.peer_id, data.conversationId, data.messageId, reason, details })
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:darkchat:clear", function(source, data)
    if not SkyPhone.AllowOperation(source, "darkchat_clear", Config.DarkChat.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local membership = load_membership(profile.id, data and data.conversationId)
    if not membership then
        return { success = false, error = "conversation_not_found" }
    end
    Bridge.Database.Query([[
        UPDATE `sky_phone_darkchat_members` SET `cleared_at` = CURRENT_TIMESTAMP
        WHERE `conversation_id` = ? AND `profile_id` = ?
    ]], { data.conversationId, profile.id })
    return { success = true }
end)

CreateThread(function()
    while true do
        Wait(Config.DarkChat.CleanupIntervalSeconds * 1000)
        Bridge.Database.Query([[
            DELETE FROM `sky_phone_darkchat_messages`
            WHERE `expires_at` IS NOT NULL AND `expires_at` <= CURRENT_TIMESTAMP
        ]], {})
    end
end)

end)
