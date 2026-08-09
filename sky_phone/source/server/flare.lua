Bridge.Database.AfterMigration("sky_phone", function()
local genders = { woman = true, man = true, nonbinary = true }
local interests = { woman = true, man = true, nonbinary = true, everyone = true }
local looking_for = { longTerm = true, dates = true, friends = true }
local message_types = { text = true, image = true, gif = true, video = true }

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

local function is_enabled(value)
    return value == true or tonumber(value) == 1
end

local function text_length(value)
    return type(value) == "string" and utf8.len(value) or nil
end

local function trim(value)
    if type(value) ~= "string" then
        return nil
    end
    return value:match("^%s*(.-)%s*$")
end

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end
    return type(result) == "table" and tonumber(result.affectedRows) or 0
end

local function uuid()
    local rows = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    if not rows[1] or type(rows[1].id) ~= "string" then
        error("[sky_phone] Database did not generate a Flare UUID.")
    end
    return rows[1].id
end

local function decode_interests(value)
    if type(value) ~= "string" or value == "" then
        return {}
    end
    local decoded = json.decode(value)
    if type(decoded) ~= "table" then
        error("[sky_phone] Invalid Flare interests JSON.")
    end
    local result = {}
    for _, interest in ipairs(decoded) do
        if type(interest) == "string" then
            result[#result + 1] = interest
        end
    end
    return result
end

local function attach_profile_photos(rows, id_field)
    id_field = id_field or "id"
    local profile_ids = {}
    local seen = {}
    for _, row in ipairs(rows) do
        local profile_id = tonumber(row[id_field])
        if profile_id and not seen[profile_id] then
            seen[profile_id] = true
            profile_ids[#profile_ids + 1] = profile_id
        end
    end
    if #profile_ids == 0 then
        return rows
    end

    local placeholders = {}
    for index = 1, #profile_ids do
        placeholders[index] = "?"
    end
    local photo_rows = Bridge.Database.Query(([[
        SELECT photo.`profile_id`, photo.`media_id`, media.`url`
        FROM `sky_phone_flare_profile_photos` photo
        JOIN `sky_phone_flare_profiles` profile ON profile.`id` = photo.`profile_id`
        JOIN `sky_phone_media` media
            ON media.`id` = photo.`media_id`
            AND media.`account_id` = profile.`account_id`
            AND media.`media_type` = 'photo'
        WHERE photo.`profile_id` IN (%s)
            AND media.`url` LIKE 'https://%%'
        ORDER BY photo.`profile_id`, photo.`sort_order`, photo.`id`
    ]]):format(table.concat(placeholders, ", ")), profile_ids)
    local photos_by_profile = {}
    for _, photo in ipairs(photo_rows) do
        local profile_id = tonumber(photo.profile_id)
        if profile_id and type(photo.url) == "string" then
            local bucket = photos_by_profile[profile_id]
            if not bucket then
                bucket = { media_ids = {}, urls = {} }
                photos_by_profile[profile_id] = bucket
            end
            bucket.media_ids[#bucket.media_ids + 1] = tonumber(photo.media_id)
            bucket.urls[#bucket.urls + 1] = photo.url
        end
    end
    for _, row in ipairs(rows) do
        local bucket = photos_by_profile[tonumber(row[id_field])] or { media_ids = {}, urls = {} }
        row.photo_media_ids = bucket.media_ids
        row.photo_urls = bucket.urls
    end
    return rows
end

local function profile_payload(row, include_preferences)
    local payload = {
        id = tonumber(row.id),
        name = row.name,
        age = tonumber(row.age),
        bio = row.bio,
        gender = row.gender,
        avatar = tonumber(row.avatar),
        interests = decode_interests(row.interests),
        lookingFor = row.looking_for,
        photoUrls = row.photo_urls or {},
    }
    if include_preferences then
        payload.discoverable = is_enabled(row.discoverable)
        payload.interestedIn = row.interested_in
        payload.minAge = tonumber(row.min_age)
        payload.maxAge = tonumber(row.max_age)
        payload.photoMediaIds = row.photo_media_ids or {}
    end
    return payload
end

local function load_profile(account_id)
    local rows = Bridge.Database.Query([[
        SELECT `id`, `name`, `age`, `bio`, `gender`, `interested_in`, `min_age`, `max_age`,
            `discoverable`,
            `avatar`, `interests`, `looking_for`
        FROM `sky_phone_flare_profiles`
        WHERE `account_id` = ? LIMIT 1
    ]], { account_id })
    attach_profile_photos(rows)
    return rows[1]
end

local function list_suggestions(account_id, profile)
    if not profile or not is_enabled(profile.discoverable) then
        return {}
    end
    local rows = Bridge.Database.Query([[
        SELECT target.`id`, target.`name`, target.`age`, target.`bio`, target.`gender`,
            target.`avatar`, target.`interests`, target.`looking_for`
        FROM `sky_phone_flare_profiles` mine
        JOIN `sky_phone_flare_profiles` target ON target.`account_id` <> mine.`account_id`
        LEFT JOIN `sky_phone_flare_swipes` swipe
            ON swipe.`swiper_account_id` = mine.`account_id`
            AND swipe.`target_account_id` = target.`account_id`
        LEFT JOIN `sky_phone_flare_matches` matched
            ON (matched.`account_a_id` = mine.`account_id` AND matched.`account_b_id` = target.`account_id`)
            OR (matched.`account_b_id` = mine.`account_id` AND matched.`account_a_id` = target.`account_id`)
        WHERE mine.`account_id` = ?
            AND mine.`discoverable` = 1
            AND target.`discoverable` = 1
            AND swipe.`id` IS NULL
            AND matched.`id` IS NULL
            AND target.`age` BETWEEN mine.`min_age` AND mine.`max_age`
            AND mine.`age` BETWEEN target.`min_age` AND target.`max_age`
            AND (mine.`interested_in` = 'everyone' OR mine.`interested_in` = target.`gender`)
            AND (target.`interested_in` = 'everyone' OR target.`interested_in` = mine.`gender`)
        ORDER BY target.`updated_at` DESC, target.`id`
        LIMIT 30
    ]], { account_id })
    attach_profile_photos(rows)
    local suggestions = {}
    for _, row in ipairs(rows) do
        suggestions[#suggestions + 1] = profile_payload(row, false)
    end
    return suggestions
end

local function list_likes(account_id)
    local rows = Bridge.Database.Query([[
        SELECT profile.`id`, profile.`name`, profile.`age`, profile.`bio`, profile.`gender`,
            profile.`avatar`, profile.`interests`, profile.`looking_for`, incoming.`choice`
        FROM `sky_phone_flare_swipes` incoming
        JOIN `sky_phone_flare_profiles` profile
            ON profile.`account_id` = incoming.`swiper_account_id`
        LEFT JOIN `sky_phone_flare_swipes` response
            ON response.`swiper_account_id` = incoming.`target_account_id`
            AND response.`target_account_id` = incoming.`swiper_account_id`
        LEFT JOIN `sky_phone_flare_matches` matched
            ON (matched.`account_a_id` = incoming.`swiper_account_id`
                AND matched.`account_b_id` = incoming.`target_account_id`)
            OR (matched.`account_b_id` = incoming.`swiper_account_id`
                AND matched.`account_a_id` = incoming.`target_account_id`)
        WHERE incoming.`target_account_id` = ?
            AND incoming.`choice` IN ('like', 'superlike')
            AND response.`id` IS NULL
            AND matched.`id` IS NULL
        ORDER BY incoming.`choice` = 'superlike' DESC, incoming.`updated_at` DESC
        LIMIT 100
    ]], { account_id })
    attach_profile_photos(rows)
    local likes = {}
    for _, row in ipairs(rows) do
        local payload = profile_payload(row, false)
        payload.superLiked = row.choice == "superlike"
        likes[#likes + 1] = payload
    end
    return likes
end

local function list_matches(account_id)
    local rows = Bridge.Database.Query([[
        SELECT match_row.`id`, match_row.`created_at`,
            profile.`id` AS `profile_id`, profile.`name`, profile.`age`, profile.`bio`,
            profile.`gender`, profile.`avatar`, profile.`interests`, profile.`looking_for`,
            latest.`body` AS `last_message`, latest.`message_type` AS `last_message_type`,
            UNIX_TIMESTAMP(latest.`created_at`) * 1000 AS `last_message_at`,
            (SELECT COUNT(*) FROM `sky_phone_flare_messages` unread
                WHERE unread.`match_id` = match_row.`id`
                    AND unread.`sender_account_id` <> ?
                    AND unread.`read_at` IS NULL) AS `unread`
        FROM `sky_phone_flare_matches` match_row
        JOIN `sky_phone_flare_profiles` profile ON profile.`account_id` =
            IF(match_row.`account_a_id` = ?, match_row.`account_b_id`, match_row.`account_a_id`)
        LEFT JOIN `sky_phone_flare_messages` latest ON latest.`id` = (
            SELECT message.`id` FROM `sky_phone_flare_messages` message
            WHERE message.`match_id` = match_row.`id`
            ORDER BY message.`created_at` DESC, message.`id` DESC LIMIT 1
        )
        WHERE match_row.`account_a_id` = ? OR match_row.`account_b_id` = ?
        ORDER BY COALESCE(latest.`created_at`, match_row.`created_at`) DESC
        LIMIT 100
    ]], { account_id, account_id, account_id, account_id })
    attach_profile_photos(rows, "profile_id")
    local matches = {}
    for _, row in ipairs(rows) do
        matches[#matches + 1] = {
            id = row.id,
            profile = profile_payload({
                id = row.profile_id,
                name = row.name,
                age = row.age,
                bio = row.bio,
                gender = row.gender,
                avatar = row.avatar,
                interests = row.interests,
                looking_for = row.looking_for,
                photo_urls = row.photo_urls,
            }, false),
            lastMessage = row.last_message or "",
            lastMessageAt = tonumber(row.last_message_at),
            lastMessageType = row.last_message_type,
            unread = tonumber(row.unread) or 0,
        }
    end
    return matches
end

local function bootstrap(account_id)
    local profile = load_profile(account_id)
    return {
        profile = profile and profile_payload(profile, true) or nil,
        suggestions = list_suggestions(account_id, profile),
        likes = list_likes(account_id),
        matches = list_matches(account_id),
    }
end

local function validate_profile(source, data)
    if type(data) ~= "table" then
        return nil
    end
    local name = trim(data.name)
    local bio = trim(data.bio) or ""
    local name_length = text_length(name)
    local bio_length = text_length(bio)
    local age = math.floor(tonumber(data.age) or 0)
    local min_age = math.floor(tonumber(data.minAge) or 0)
    local max_age = math.floor(tonumber(data.maxAge) or 0)
    local avatar = math.floor(tonumber(data.avatar) or -1)
    if not name_length or name_length < 2 or name_length > 32
        or not bio_length or bio_length > 300
        or age < 18 or age > 99
        or min_age < 18 or min_age > 99
        or max_age < min_age or max_age > 99
        or avatar < 0 or avatar > 5
        or not genders[data.gender]
        or not interests[data.interestedIn]
        or not looking_for[data.lookingFor]
    then
        return nil
    end
    local clean_interests = {}
    if type(data.interests) == "table" then
        for _, value in ipairs(data.interests) do
            local interest = trim(value)
            local length = text_length(interest)
            if length and length > 0 and length <= 24 and #clean_interests < 5 then
                clean_interests[#clean_interests + 1] = interest
            end
        end
    end
    local photo_media_ids = nil
    local replace_photos = data.photoMediaIds ~= nil
    if replace_photos then
        if type(data.photoMediaIds) ~= "table" or #data.photoMediaIds > 6 then
            return nil, "invalid_profile_photos"
        end
        photo_media_ids = {}
        local seen_media = {}
        for key in pairs(data.photoMediaIds) do
            if type(key) ~= "number" or key < 1 or key > #data.photoMediaIds
                or key ~= math.floor(key)
            then
                return nil, "invalid_profile_photos"
            end
        end
        for _, value in ipairs(data.photoMediaIds) do
            local media_id = tonumber(value)
            if not media_id or media_id < 1 or media_id ~= math.floor(media_id)
                or seen_media[media_id]
                or not SkyPhoneMedia.ResolveOwnedMedia(source, media_id, "photo")
            then
                return nil, "invalid_profile_photos"
            end
            seen_media[media_id] = true
            photo_media_ids[#photo_media_ids + 1] = media_id
        end
    end
    return {
        name = name,
        age = age,
        bio = bio,
        gender = data.gender,
        interested_in = data.interestedIn,
        min_age = min_age,
        max_age = max_age,
        avatar = avatar,
        interests = json.encode(clean_interests),
        looking_for = data.lookingFor,
        photo_media_ids = photo_media_ids,
        replace_photos = replace_photos,
    }, nil
end

local function load_match(account_id, match_id)
    if type(match_id) ~= "string" or #match_id ~= 36 then
        return nil
    end
    local rows = Bridge.Database.Query([[
        SELECT `id`, `account_a_id`, `account_b_id`
        FROM `sky_phone_flare_matches`
        WHERE `id` = ? AND (`account_a_id` = ? OR `account_b_id` = ?)
        LIMIT 1
    ]], { match_id, account_id, account_id })
    return rows[1]
end

local function validate_message(source, data)
    if type(data) ~= "table" then
        return nil, "invalid_message"
    end
    local message_type = data.messageType or "text"
    if not message_types[message_type] then
        return nil, "invalid_message"
    end
    if message_type == "text" then
        local body = trim(data.body)
        local length = text_length(body)
        if not length or length < 1 or length > 1000 then
            return nil, "invalid_message"
        end
        return { body = body, message_type = message_type }
    end

    if type(data.mediaAssetId) ~= "string" then
        return nil, "invalid_attachment"
    end
    local media_url
    if message_type == "gif" then
        if not allowed_gif_url(data.mediaAssetId) then
            return nil, "invalid_attachment"
        end
        media_url = data.mediaAssetId
    else
        local media_id = tonumber(data.mediaAssetId)
        local expected_type = message_type == "image" and "photo" or "video"
        if not media_id or media_id < 1 or media_id ~= math.floor(media_id) then
            return nil, "invalid_attachment"
        end
        media_url = SkyPhoneMedia.ResolveOwnedMedia(source, media_id, expected_type)
        if type(media_url) ~= "string" or #media_url > Config.Media.UrlMaxLength
            or not media_url:match("^https://")
        then
            Bridge.Debug("warn", ("[sky_phone] Rejected unowned Flare media from source %s."):format(tostring(source)))
            return nil, "invalid_attachment"
        end
    end

    local duration = nil
    if message_type == "video" and data.mediaDurationMs ~= nil then
        duration = tonumber(data.mediaDurationMs)
        if not duration or duration < 1000 or duration > Config.Messages.VideoMaxDurationMs then
            return nil, "invalid_attachment"
        end
        duration = math.floor(duration)
    end
    return {
        body = "",
        media_duration_ms = duration,
        media_url = media_url,
        message_type = message_type,
    }
end

local function message_payload(row, account_id)
    return {
        id = row.id,
        direction = tonumber(row.sender_account_id) == tonumber(account_id) and "sent" or "received",
        body = row.body or "",
        createdAt = tonumber(row.created_at_ms),
        messageType = row.message_type or "text",
        mediaUrl = row.media_url,
        mediaDurationMs = tonumber(row.media_duration_ms),
    }
end

Bridge.Callbacks.Register("sky_phone:flare:bootstrap", function(source)
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then
        return error_response
    end
    return { success = true, data = bootstrap(account.id) }
end)

Bridge.Callbacks.Register("sky_phone:flare:save-profile", function(source, data)
    if not SkyPhone.AllowOperation(source, "flare_profile", 12, 60) then
        return { success = false, error = "rate_limited" }
    end
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then
        return error_response
    end
    local profile, validation_error = validate_profile(source, data)
    if not profile then
        return { success = false, error = validation_error or "invalid_profile" }
    end
    local statements = {{
        query = [[
            INSERT INTO `sky_phone_flare_profiles`
                (`account_id`, `name`, `age`, `bio`, `gender`, `interested_in`, `min_age`, `max_age`,
                    `avatar`, `interests`, `looking_for`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                `name` = VALUES(`name`), `age` = VALUES(`age`), `bio` = VALUES(`bio`),
                `gender` = VALUES(`gender`), `interested_in` = VALUES(`interested_in`),
                `min_age` = VALUES(`min_age`), `max_age` = VALUES(`max_age`),
                `avatar` = VALUES(`avatar`), `interests` = VALUES(`interests`),
                `looking_for` = VALUES(`looking_for`)
        ]],
        params = {
            account.id, profile.name, profile.age, profile.bio, profile.gender,
            profile.interested_in, profile.min_age, profile.max_age, profile.avatar,
            profile.interests, profile.looking_for,
        },
    }}
    if profile.replace_photos then
        statements[#statements + 1] = {
            query = [[
                DELETE photo FROM `sky_phone_flare_profile_photos` photo
                JOIN `sky_phone_flare_profiles` profile ON profile.`id` = photo.`profile_id`
                WHERE profile.`account_id` = ?
            ]],
            params = { account.id },
        }
        for index, media_id in ipairs(profile.photo_media_ids) do
            statements[#statements + 1] = {
                query = [[
                    INSERT INTO `sky_phone_flare_profile_photos`
                        (`profile_id`, `media_id`, `sort_order`)
                    SELECT `id`, ?, ? FROM `sky_phone_flare_profiles` WHERE `account_id` = ?
                ]],
                params = { media_id, index, account.id },
            }
        end
    end
    if not Bridge.Database.Transaction(statements) then
        return { success = false, error = "request_failed" }
    end
    return { success = true, data = bootstrap(account.id) }
end)

Bridge.Callbacks.Register("sky_phone:flare:set-discovery", function(source, data)
    if not SkyPhone.AllowOperation(source, "flare_discovery", 20, 60) then
        return { success = false, error = "rate_limited" }
    end
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then
        return error_response
    end
    if type(data) ~= "table" or type(data.enabled) ~= "boolean" then
        return { success = false, error = "invalid_discovery" }
    end
    if not load_profile(account.id) then
        return { success = false, error = "invalid_profile" }
    end
    Bridge.Database.Query([[
        UPDATE `sky_phone_flare_profiles` SET `discoverable` = ? WHERE `account_id` = ?
    ]], { data.enabled and 1 or 0, account.id })
    return { success = true, data = bootstrap(account.id) }
end)

Bridge.Callbacks.Register("sky_phone:flare:swipe", function(source, data)
    if not SkyPhone.AllowOperation(source, "flare_swipe", 120, 60) then
        return { success = false, error = "rate_limited" }
    end
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then
        return error_response
    end
    local own_profile = load_profile(account.id)
    if not own_profile then
        return { success = false, error = "invalid_profile" }
    end
    if not is_enabled(own_profile.discoverable) then
        return { success = false, error = "discovery_disabled" }
    end
    local target_id = math.floor(tonumber(data and data.targetId) or 0)
    local choice = data and data.choice
    if target_id <= 0 or (choice ~= "like" and choice ~= "pass" and choice ~= "superlike") then
        return { success = false, error = "invalid_choice" }
    end
    local targets = Bridge.Database.Query([[
        SELECT target.`account_id`
        FROM `sky_phone_flare_profiles` mine
        JOIN `sky_phone_flare_profiles` target ON target.`id` = ?
        WHERE mine.`account_id` = ?
            AND target.`account_id` <> mine.`account_id`
            AND mine.`discoverable` = 1
            AND target.`discoverable` = 1
            AND target.`age` BETWEEN mine.`min_age` AND mine.`max_age`
            AND mine.`age` BETWEEN target.`min_age` AND target.`max_age`
            AND (mine.`interested_in` = 'everyone' OR mine.`interested_in` = target.`gender`)
            AND (target.`interested_in` = 'everyone' OR target.`interested_in` = mine.`gender`)
        LIMIT 1
    ]], { target_id, account.id })
    local target_account_id = targets[1] and tonumber(targets[1].account_id)
    if not target_account_id then
        return { success = false, error = "invalid_target" }
    end
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_flare_swipes` (`swiper_account_id`, `target_account_id`, `choice`)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE `choice` = VALUES(`choice`), `updated_at` = CURRENT_TIMESTAMP
    ]], { account.id, target_account_id, choice })
    if choice == "pass" then
        return { success = true, data = { match = nil } }
    end
    local reciprocal = Bridge.Database.Query([[
        SELECT `id` FROM `sky_phone_flare_swipes`
        WHERE `swiper_account_id` = ? AND `target_account_id` = ?
            AND `choice` IN ('like', 'superlike')
        LIMIT 1
    ]], { target_account_id, account.id })
    if not reciprocal[1] then
        return { success = true, data = { match = nil } }
    end
    local account_a = math.min(account.id, target_account_id)
    local account_b = math.max(account.id, target_account_id)
    local insert_result = Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_flare_matches` (`id`, `account_a_id`, `account_b_id`)
        VALUES (?, ?, ?)
    ]], { uuid(), account_a, account_b })
    local match_created = affected_rows(insert_result) > 0
    local matches = list_matches(account.id)
    local created_match = nil
    for _, match in ipairs(matches) do
        if tonumber(match.profile.id) == target_id then
            created_match = match
            break
        end
    end
    if created_match and match_created then
        SkyPhone.NotifyAccountDevices(target_account_id, "sky_phone:flare:match", {
            matchId = created_match.id,
            sender = own_profile.name,
        })
    end
    return { success = true, data = { match = created_match } }
end)

Bridge.Callbacks.Register("sky_phone:flare:rewind", function(source)
    if not SkyPhone.AllowOperation(source, "flare_rewind", 20, 60) then
        return { success = false, error = "rate_limited" }
    end
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then
        return error_response
    end
    local rows = Bridge.Database.Query([[
        SELECT `id`, `target_account_id`
        FROM `sky_phone_flare_swipes`
        WHERE `swiper_account_id` = ?
        ORDER BY `updated_at` DESC, `id` DESC
        LIMIT 1
    ]], { account.id })
    local swipe = rows[1]
    if not swipe then
        return { success = false, error = "nothing_to_rewind" }
    end
    local target_account_id = tonumber(swipe.target_account_id)
    local matched = Bridge.Database.Query([[
        SELECT `id` FROM `sky_phone_flare_matches`
        WHERE (`account_a_id` = ? AND `account_b_id` = ?)
            OR (`account_a_id` = ? AND `account_b_id` = ?)
        LIMIT 1
    ]], { account.id, target_account_id, target_account_id, account.id })
    if matched[1] then
        return { success = false, error = "cannot_rewind_match" }
    end
    Bridge.Database.Query([[
        DELETE FROM `sky_phone_flare_swipes` WHERE `id` = ? AND `swiper_account_id` = ?
    ]], { swipe.id, account.id })
    return { success = true, data = bootstrap(account.id) }
end)

Bridge.Callbacks.Register("sky_phone:flare:unmatch", function(source, data)
    if not SkyPhone.AllowOperation(source, "flare_unmatch", 20, 60) then
        return { success = false, error = "rate_limited" }
    end
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then
        return error_response
    end
    local match = load_match(account.id, data and data.matchId)
    if not match then
        return { success = false, error = "match_not_found" }
    end
    Bridge.Database.Query([[
        DELETE FROM `sky_phone_flare_matches`
        WHERE `id` = ? AND (`account_a_id` = ? OR `account_b_id` = ?)
    ]], { match.id, account.id, account.id })
    return { success = true, data = { matches = list_matches(account.id) } }
end)

Bridge.Callbacks.Register("sky_phone:flare:thread", function(source, data)
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then
        return error_response
    end
    local match = load_match(account.id, data and data.matchId)
    if not match then
        return { success = false, error = "match_not_found" }
    end
    Bridge.Database.Query([[
        UPDATE `sky_phone_flare_messages` SET `read_at` = CURRENT_TIMESTAMP
        WHERE `match_id` = ? AND `sender_account_id` <> ? AND `read_at` IS NULL
    ]], { match.id, account.id })
    local rows = Bridge.Database.Query([[
        SELECT `id`, `sender_account_id`, `body`, `message_type`, `media_url`,
            `media_duration_ms`, UNIX_TIMESTAMP(`created_at`) * 1000 AS `created_at_ms`
        FROM `sky_phone_flare_messages`
        WHERE `match_id` = ?
        ORDER BY `created_at`, `id`
        LIMIT 500
    ]], { match.id })
    local messages = {}
    for _, row in ipairs(rows) do
        messages[#messages + 1] = message_payload(row, account.id)
    end
    return { success = true, data = { messages = messages } }
end)

Bridge.Callbacks.Register("sky_phone:flare:send", function(source, data)
    if not SkyPhone.AllowOperation(source, "flare_message", 60, 60) then
        return { success = false, error = "rate_limited" }
    end
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then
        return error_response
    end
    local match = load_match(account.id, data and data.matchId)
    if not match then
        return { success = false, error = "match_not_found" }
    end
    local message, validation_error = validate_message(source, data)
    if not message then
        return { success = false, error = validation_error }
    end
    local id = uuid()
    local own_profile = load_profile(account.id)
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_flare_messages`
            (`id`, `match_id`, `sender_account_id`, `body`, `message_type`, `media_url`,
                `media_duration_ms`)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        id, match.id, account.id, message.body, message.message_type, message.media_url,
        message.media_duration_ms,
    })
    local recipient_account_id = tonumber(match.account_a_id) == tonumber(account.id)
        and tonumber(match.account_b_id) or tonumber(match.account_a_id)
    SkyPhone.NotifyAccountDevices(recipient_account_id, "sky_phone:flare:message", {
        matchId = match.id,
        body = message.body,
        sender = own_profile and own_profile.name or "",
    })
    return {
        success = true,
        data = message_payload({
            id = id,
            sender_account_id = account.id,
            body = message.body,
            created_at_ms = os.time() * 1000,
            message_type = message.message_type,
            media_url = message.media_url,
            media_duration_ms = message.media_duration_ms,
        }, account.id),
    }
end)
end)
