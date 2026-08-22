Bridge.Database.AfterMigration("sky_phone", function()
local account_types = { person = true, business = true, organization = true, media = true, event = true }
local visibilities = { public = true, followers = true, private = true }
local report_reasons = { spam = true, harassment = true, dangerous = true, illegal = true, other = true }
local music_tracks = {}
local music_track_list = {}
local custom_music_extensions = {
    aac = true,
    m4a = true,
    mp3 = true,
    oga = true,
    ogg = true,
    opus = true,
    wav = true,
    webm = true,
}
local password_pepper = ""

local function refresh_runtime_configuration()
    password_pepper = tostring(Config.Server.FlipTokPasswordPepper or "")
    music_tracks = {}
    music_track_list = {}
    for _, track in ipairs(Config.FlipTok.MusicTracks) do
        local id = tostring(track.Id or track.id or "")
        local title = tostring(track.Title or track.title or "")
        local artist = tostring(track.Artist or track.artist or "")
        local url = tostring(track.Url or track.url or "")
        if id == "" or title == "" or artist == "" or url == "" then
            error("[sky_phone] Every configured FlipTok music track requires Id, Title, Artist, and Url.")
        end
        local item = { id = id, title = title, artist = artist, url = url }
        music_tracks[id] = item
        music_track_list[#music_track_list + 1] = item
    end
end

refresh_runtime_configuration()

if password_pepper == "" then
    Bridge.Debug(
        "warn",
        "[sky_phone] Config.Server.FlipTokPasswordPepper is empty. FlipTok passwords still work, but their hashes lack the required server-side secret. Set a stable random value in config/config.lua before production; changing it later invalidates existing FlipTok passwords.",
        { always = true }
    )
end

AddEventHandler("sky_phone:configurator:serverUpdated", function()
    refresh_runtime_configuration()
end)

local function trim(value)
    if type(value) ~= "string" then return nil end
    return value:match("^%s*(.-)%s*$")
end

local function valid_text(value, minimum, maximum)
    local length = type(value) == "string" and utf8.len(value) or nil
    return length and length >= minimum and length <= maximum
end

local function valid_custom_music_url(value)
    if type(value) ~= "string" or value == "" or #value > Config.Media.UrlMaxLength
        or value:find("[^\33-\126]")
    then
        return false
    end

    local authority = value:match("^https://([^/%?#]+)")
    if not authority or authority:find("@", 1, true) then return false end

    local host = authority:match("^([^:]+)")
    local port = host and authority:sub(#host + 1) or ""
    if not host or (port ~= "" and port ~= ":443") then return false end

    host = host:lower()
    if host == "localhost" or host:match("%.localhost$") or host:match("%.local$") or host:match("%.internal$")
        or host:match("^%d+%.%d+%.%d+%.%d+$") or not host:find("%.")
        or host:find("[^a-z0-9%.%-]")
    then
        return false
    end

    for label in host:gmatch("[^.]+") do
        if #label > 63 or label:match("^%-") or label:match("%-$") then return false end
    end

    local path = value:match("^https://[^/]+(/[^?#]*)") or ""
    local extension = path:match("%.([%w]+)$")
    return extension and custom_music_extensions[extension:lower()] == true or false
end

local function affected_rows(result)
    if type(result) == "number" then return result end
    if type(result) == "table" then return tonumber(result.affectedRows) or tonumber(result.affected_rows) or 0 end
    return 0
end

local function are_profiles_blocked(first_id, second_id)
    return Bridge.Database.Query([[SELECT `id` FROM `sky_phone_fliptok_blocks` WHERE
        (`blocker_id` = ? AND `blocked_id` = ?) OR (`blocker_id` = ? AND `blocked_id` = ?) LIMIT 1]], {
        first_id, second_id, second_id, first_id,
    })[1] ~= nil
end

local function new_id()
    local rows = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    if not rows[1] or type(rows[1].id) ~= "string" then
        error("[sky_phone] Database did not generate a FlipTok id.")
    end
    return rows[1].id
end

local function normalize_handle(value)
    local handle = trim(value)
    if not handle then return nil end
    handle = handle:lower():gsub("^@", "")
    if #handle < 3 or #handle > 24 or not handle:match("^[a-z0-9][a-z0-9._]*[a-z0-9]$") or handle:find("..", 1, true) then
        return nil
    end
    return handle
end

local function valid_password(value)
    local length = type(value) == "string" and utf8.len(value) or nil
    return length and length >= Config.FlipTok.PasswordMinLength and length <= Config.FlipTok.PasswordMaxLength
end

local function profile_for_session(source)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then return nil, error_response end
    local rows = Bridge.Database.Query([[SELECT p.* FROM `sky_phone_fliptok_sessions` s
        JOIN `sky_phone_fliptok_profiles` p ON p.`id` = s.`profile_id`
        WHERE s.`device_imei` = ? LIMIT 1]], { session.imei })
    if not rows[1] then return nil, { success = false, error = "fliptok_not_authenticated" } end
    return rows[1], nil
end

local function require_profile(source)
    return profile_for_session(source)
end

local function hydrate_profile(profile, viewer_id)
    profile.id = tonumber(profile.id)
    profile.avatar_media_id = tonumber(profile.avatar_media_id)
    profile.verified = tonumber(profile.verified) == 1
    profile.is_following = viewer_id and tonumber(profile.is_following) == 1 or false
    profile.is_owner = viewer_id and profile.id == viewer_id or false
    profile.followers = tonumber(profile.followers) or 0
    profile.following = tonumber(profile.following) or 0
    profile.video_count = tonumber(profile.video_count) or 0
    return profile
end

local function load_profile(profile_id, viewer_id)
    local rows = Bridge.Database.Query([[
        SELECT p.*, avatar.`url` AS `avatar_url`,
            EXISTS(SELECT 1 FROM `sky_phone_fliptok_follows` f WHERE f.`follower_id` = ? AND f.`following_id` = p.`id`) AS `is_following`,
            (SELECT COUNT(*) FROM `sky_phone_fliptok_follows` f WHERE f.`following_id` = p.`id`) AS `followers`,
            (SELECT COUNT(*) FROM `sky_phone_fliptok_follows` f WHERE f.`follower_id` = p.`id`) AS `following`,
            (SELECT COUNT(*) FROM `sky_phone_fliptok_videos` v WHERE v.`profile_id` = p.`id` AND v.`status` = 'published') AS `video_count`
        FROM `sky_phone_fliptok_profiles` p
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = p.`avatar_media_id`
        WHERE p.`id` = ? LIMIT 1
    ]], { viewer_id, profile_id })
    return rows[1] and hydrate_profile(rows[1], viewer_id) or nil
end

local function load_accessible_video(video_id, viewer_id)
    if type(video_id) ~= "string" or video_id == "" or #video_id > 64 then return nil end
    local rows = Bridge.Database.Query([[SELECT v.`profile_id`, v.`comments_enabled`
        FROM `sky_phone_fliptok_videos` v
        WHERE v.`id` = ? AND v.`status` = 'published'
            AND (v.`profile_id` = ? OR v.`visibility` = 'public' OR
                (v.`visibility` = 'followers' AND EXISTS(
                    SELECT 1 FROM `sky_phone_fliptok_follows` follow
                    WHERE follow.`follower_id` = ? AND follow.`following_id` = v.`profile_id`)))
            AND NOT EXISTS(SELECT 1 FROM `sky_phone_fliptok_blocks` block WHERE
                (block.`blocker_id` = ? AND block.`blocked_id` = v.`profile_id`) OR
                (block.`blocked_id` = ? AND block.`blocker_id` = v.`profile_id`))
        LIMIT 1]], { video_id, viewer_id, viewer_id, viewer_id, viewer_id })
    return rows[1]
end

local function notify_profile(recipient_id, actor_id, kind, video_id)
    local rows = Bridge.Database.Query([[SELECT recipient.`account_id`, actor.`display_name` AS `actor_name`
        FROM `sky_phone_fliptok_profiles` recipient
        JOIN `sky_phone_fliptok_profiles` actor ON actor.`id` = ?
        WHERE recipient.`id` = ? LIMIT 1]], { actor_id, recipient_id })
    if not rows[1] then
        Bridge.Debug("warn", "[sky_phone] FlipTok notification target or actor no longer exists.", { always = true })
        return
    end
    SkyPhone.NotifyAccountDevices(tonumber(rows[1].account_id), "sky_phone:fliptok:new", {
        actor = rows[1].actor_name,
        kind = kind,
        videoId = video_id,
    })
end

local function hydrate_videos(rows)
    local by_video = {}
    local video_ids = {}
    for _, video in ipairs(rows) do
        by_video[video.id] = video
        video_ids[#video_ids + 1] = video.id
        video.media_id = tonumber(video.media_id)
        video.profile_id = tonumber(video.profile_id)
        video.verified = tonumber(video.verified) == 1
        video.comments_enabled = tonumber(video.comments_enabled) == 1
        video.is_liked = tonumber(video.is_liked) == 1
        video.is_saved = tonumber(video.is_saved) == 1
        video.is_following = tonumber(video.is_following) == 1
        video.is_owner = tonumber(video.is_owner) == 1
        video.like_count = tonumber(video.like_count) or 0
        video.comment_count = tonumber(video.comment_count) or 0
        video.view_count = tonumber(video.view_count) or 0
        video.share_count = tonumber(video.share_count) or 0
        video.trim_start_ms = tonumber(video.trim_start_ms) or 0
        video.trim_end_ms = tonumber(video.trim_end_ms)
        video.cover_time_ms = tonumber(video.cover_time_ms) or 0
        video.original_volume = tonumber(video.original_volume) or 100
        video.music_volume = tonumber(video.music_volume) or 0
        local track = music_tracks[video.music_track]
        local custom_music_url = type(video.custom_music_url) == "string" and video.custom_music_url or ""
        local youtube_id = SkyPhoneYouTube.ParseId(custom_music_url)
        video.music_title = track and track.title or video.custom_music_title or ""
        video.music_artist = track and track.artist or video.custom_music_artist or ""
        video.music_url = track and track.url or (youtube_id and "" or custom_music_url)
        video.music_source = track and "audio" or (youtube_id and "youtube" or (custom_music_url ~= "" and "audio" or ""))
        video.music_video_id = youtube_id or ""
        video.custom_music_url = nil
        video.custom_music_title = nil
        video.custom_music_artist = nil
        video.created_at = (tonumber(video.created_at_unix) or 0) * 1000
        video.created_at_unix = nil
        video.media = {}
    end
    if #video_ids > 0 then
        local placeholders = {}
        for index = 1, #video_ids do placeholders[index] = "?" end
        local media_rows = Bridge.Database.Query(([=[
            SELECT relation.`video_id`, media.`id`, media.`url`, media.`media_type`
            FROM `sky_phone_fliptok_video_media` relation
            JOIN `sky_phone_media` media ON media.`id` = relation.`media_id`
            WHERE relation.`video_id` IN (%s)
            ORDER BY relation.`video_id`, relation.`sort_order`
        ]=]):format(table.concat(placeholders, ",")), video_ids)
        for _, media in ipairs(media_rows) do
            local video = by_video[media.video_id]
            if video then
                video.media[#video.media + 1] = {
                    id = tonumber(media.id),
                    mediaType = media.media_type,
                    url = media.url,
                }
            end
        end
    end
    for _, video in ipairs(rows) do
        if #video.media == 0 then
            video.media[1] = { id = video.media_id, mediaType = video.media_type, url = video.url }
        end
        video.media_type = video.media[1].mediaType
    end
    return rows
end

local function report_webhook_url()
    local value = trim(GetConvar(Config.FlipTok.ReportWebhookConvar, "")) or ""
    if value:match("^https://discord%.com/api/webhooks/%d+/[%w%-%_]+$")
        or value:match("^https://discordapp%.com/api/webhooks/%d+/[%w%-%_]+$")
    then
        return value
    end
    return nil
end

local function truncate_discord_text(value, maximum_characters)
    if type(value) ~= "string" then return "" end
    local length = utf8.len(value)
    if not length or length <= maximum_characters then return value end
    local boundary = utf8.offset(value, maximum_characters + 1)
    return boundary and value:sub(1, boundary - 1) .. "…" or value
end

local function list_videos(viewer_id, where_clause, values, limit, offset, ranking)
    local parameters = { viewer_id, viewer_id, viewer_id, viewer_id }
    for _, value in ipairs(values) do parameters[#parameters + 1] = value end
    parameters[#parameters + 1] = limit
    parameters[#parameters + 1] = offset
    return hydrate_videos(Bridge.Database.Query(([[
        SELECT v.`id`, v.`profile_id`, v.`caption`, v.`location`, v.`comments_enabled`, v.`view_count`, v.`share_count`,
            v.`trim_start_ms`, v.`trim_end_ms`, v.`cover_time_ms`, v.`original_volume`, v.`music_volume`, v.`music_track`,
            v.`custom_music_url`, v.`custom_music_title`, v.`custom_music_artist`,
            m.`id` AS `media_id`, m.`media_type`, m.`url`, UNIX_TIMESTAMP(v.`created_at`) AS `created_at_unix`, p.`handle`, p.`display_name`, p.`verified`,
            avatar.`url` AS `avatar_url`,
            (v.`profile_id` = ?) AS `is_owner`,
            EXISTS(SELECT 1 FROM `sky_phone_fliptok_reactions` r WHERE r.`video_id` = v.`id` AND r.`profile_id` = ? AND r.`kind` = 'like') AS `is_liked`,
            EXISTS(SELECT 1 FROM `sky_phone_fliptok_reactions` r WHERE r.`video_id` = v.`id` AND r.`profile_id` = ? AND r.`kind` = 'save') AS `is_saved`,
            EXISTS(SELECT 1 FROM `sky_phone_fliptok_follows` f WHERE f.`follower_id` = ? AND f.`following_id` = v.`profile_id`) AS `is_following`,
            (SELECT COUNT(*) FROM `sky_phone_fliptok_reactions` r WHERE r.`video_id` = v.`id` AND r.`kind` = 'like') AS `like_count`,
            (SELECT COUNT(*) FROM `sky_phone_fliptok_comments` c WHERE c.`video_id` = v.`id` AND c.`status` = 'visible') AS `comment_count`
        FROM `sky_phone_fliptok_videos` v
        JOIN `sky_phone_fliptok_profiles` p ON p.`id` = v.`profile_id`
        JOIN `sky_phone_media` m ON m.`id` = v.`media_id`
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = p.`avatar_media_id`
        WHERE v.`status` = 'published' AND %s
            AND NOT EXISTS(SELECT 1 FROM `sky_phone_fliptok_blocks` b WHERE
                (b.`blocker_id` = ? AND b.`blocked_id` = v.`profile_id`) OR (b.`blocked_id` = ? AND b.`blocker_id` = v.`profile_id`))
        ORDER BY %s LIMIT ? OFFSET ?
    ]]):format(where_clause, ranking), parameters))
end

local function feed(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    data = type(data) == "table" and data or {}
    local offset = math.max(0, math.floor(tonumber(data.offset) or 0))
    local limit = Config.FlipTok.PageSize
    local where = "v.`visibility` = 'public'"
    local ranking = "(v.`view_count` + v.`share_count` * 8 + (SELECT COUNT(*) FROM `sky_phone_fliptok_reactions` rr WHERE rr.`video_id` = v.`id`) * 4) DESC, v.`created_at` DESC"
    if data.mode == "following" then
        where = "v.`visibility` IN ('public', 'followers') AND EXISTS(SELECT 1 FROM `sky_phone_fliptok_follows` ff WHERE ff.`follower_id` = ? AND ff.`following_id` = v.`profile_id`)"
        ranking = "v.`created_at` DESC"
    end
    local values = data.mode == "following" and { profile.id, profile.id, profile.id } or { profile.id, profile.id }
    local rows = list_videos(profile.id, where, values, limit + 1, offset, ranking)
    local has_more = #rows > limit
    if has_more then rows[#rows] = nil end
    return { success = true, data = { items = rows, offset = offset, hasMore = has_more } }
end

Bridge.Callbacks.Register("sky_phone:fliptok:register", function(source, data)
    if not SkyPhone.AllowOperation(source, "fliptok:register", 5, 60) then
        return { success = false, error = "rate_limited" }
    end
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then return error_response end
    if type(data) ~= "table" then return { success = false, error = "invalid_request" } end

    local handle = normalize_handle(data.handle)
    local display_name = trim(data.displayName)
    if not handle then return { success = false, error = "invalid_handle" } end
    if not valid_text(display_name, 1, 40) then return { success = false, error = "invalid_display_name" } end
    if not valid_password(data.password) then return { success = false, error = "invalid_password" } end

    local profiles = Bridge.Database.Query("SELECT `id` FROM `sky_phone_fliptok_profiles` WHERE `account_id` = ? LIMIT 1", { account.id })
    local profile_id = profiles[1] and tonumber(profiles[1].id) or nil
    local duplicates = profile_id and Bridge.Database.Query(
        "SELECT `id` FROM `sky_phone_fliptok_profiles` WHERE `handle` = ? AND `id` <> ? LIMIT 1",
        { handle, profile_id }
    ) or Bridge.Database.Query(
        "SELECT `id` FROM `sky_phone_fliptok_profiles` WHERE `handle` = ? LIMIT 1",
        { handle }
    )
    if duplicates[1] then return { success = false, error = "handle_taken" } end

    if profile_id then
        local credentials = Bridge.Database.Query("SELECT `profile_id` FROM `sky_phone_fliptok_credentials` WHERE `profile_id` = ? LIMIT 1", { profile_id })
        if credentials[1] then return { success = false, error = "already_registered" } end
        Bridge.Database.Query("UPDATE `sky_phone_fliptok_profiles` SET `handle` = ?, `display_name` = ? WHERE `id` = ?", {
            handle, display_name, profile_id,
        })
    else
        local result = Bridge.Database.Query([[INSERT IGNORE INTO `sky_phone_fliptok_profiles`
            (`account_id`, `handle`, `display_name`) VALUES (?, ?, ?)]], { account.id, handle, display_name })
        if affected_rows(result) ~= 1 then return { success = false, error = "handle_taken" } end
        local created = Bridge.Database.Query("SELECT `id` FROM `sky_phone_fliptok_profiles` WHERE `account_id` = ? LIMIT 1", { account.id })
        if not created[1] then error("[sky_phone] FlipTok profile insert did not return the created profile.") end
        profile_id = tonumber(created[1].id)
    end

    local salts = Bridge.Database.Query("SELECT REPLACE(UUID(), '-', '') AS `salt`", {})
    local salt = salts[1] and salts[1].salt
    if type(salt) ~= "string" or #salt ~= 32 then error("[sky_phone] Database did not generate a FlipTok password salt.") end
    local credential_result = Bridge.Database.Query([[INSERT IGNORE INTO `sky_phone_fliptok_credentials`
        (`profile_id`, `password_hash`, `password_salt`) VALUES (?, UNHEX(SHA2(CONCAT(?, ?, ?), 256)), ?)]], {
        profile_id, password_pepper, salt, data.password, salt,
    })
    if affected_rows(credential_result) ~= 1 then return { success = false, error = "already_registered" } end
    Bridge.Database.Query([[INSERT INTO `sky_phone_fliptok_sessions` (`device_imei`, `profile_id`) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE `profile_id` = VALUES(`profile_id`), `updated_at` = CURRENT_TIMESTAMP]], {
        account.imei, profile_id,
    })
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:login", function(source, data)
    if not SkyPhone.AllowOperation(source, "fliptok:login", 10, 60) then
        return { success = false, error = "rate_limited" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then return error_response end
    if type(data) ~= "table" then return { success = false, error = "invalid_credentials" } end
    local handle = normalize_handle(data.handle)
    if not handle or not valid_password(data.password) then
        return { success = false, error = "invalid_credentials" }
    end
    local profiles = Bridge.Database.Query([[SELECT p.`id` FROM `sky_phone_fliptok_profiles` p
        JOIN `sky_phone_fliptok_credentials` c ON c.`profile_id` = p.`id`
        WHERE p.`handle` = ?
            AND c.`password_hash` = UNHEX(SHA2(CONCAT(?, c.`password_salt`, ?), 256))
        LIMIT 1]], { handle, password_pepper, data.password })
    if not profiles[1] then return { success = false, error = "invalid_credentials" } end
    Bridge.Database.Query([[INSERT INTO `sky_phone_fliptok_sessions` (`device_imei`, `profile_id`) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE `profile_id` = VALUES(`profile_id`), `updated_at` = CURRENT_TIMESTAMP]], {
        session.imei, profiles[1].id,
    })
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:logout", function(source)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then return error_response end
    Bridge.Database.Query("DELETE FROM `sky_phone_fliptok_sessions` WHERE `device_imei` = ?", { session.imei })
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:bootstrap", function(source)
    local profile, error_response = require_profile(source)
    if not profile then
        if error_response.error == "fliptok_not_authenticated" then
            return { success = true, data = { authenticated = false, musicTracks = music_track_list } }
        end
        return error_response
    end
    local result = feed(source, { mode = "for-you", offset = 0 })
    if not result.success then return result end
    return { success = true, data = {
        authenticated = true,
        profile = load_profile(profile.id, profile.id),
        feed = result.data,
        musicTracks = music_track_list,
    } }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:feed", feed)

Bridge.Callbacks.Register("sky_phone:fliptok:video", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    if not SkyPhone.AllowOperation(source, "fliptok:video", 60, 60) then
        return { success = false, error = "rate_limited" }
    end
    local video_id = type(data) == "table" and data.id or nil
    if type(video_id) ~= "string" or #video_id > 64 then
        return { success = false, error = "video_not_found" }
    end
    local rows = list_videos(
        profile.id,
        [[v.`id` = ? AND (v.`visibility` = 'public' OR v.`profile_id` = ? OR
            (v.`visibility` = 'followers' AND EXISTS(
                SELECT 1 FROM `sky_phone_fliptok_follows` follow
                WHERE follow.`follower_id` = ? AND follow.`following_id` = v.`profile_id`)))]],
        { video_id, profile.id, profile.id, profile.id, profile.id },
        1,
        0,
        "v.`created_at` DESC"
    )
    return rows[1]
        and { success = true, data = rows[1] }
        or { success = false, error = "video_not_found" }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:discover", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    local search = type(data) == "table" and trim(data.search) or ""
    if search and utf8.len(search) > 50 then return { success = false, error = "invalid_request" } end
    local pattern = "%" .. (search or "") .. "%"
    local rows = list_videos(profile.id, "v.`visibility` = 'public' AND (p.`handle` LIKE ? OR p.`display_name` LIKE ? OR v.`caption` LIKE ?)", { pattern, pattern, pattern, profile.id, profile.id }, Config.FlipTok.PageSize, 0, "v.`created_at` DESC")
    return { success = true, data = rows }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:music-metadata", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    if not SkyPhone.AllowOperation(source, "fliptok:music-metadata", 12, 60) then
        return { success = false, error = "rate_limited" }
    end
    local value = trim(type(data) == "table" and data.url or nil)
    local video_id = SkyPhoneYouTube.ParseId(value)
    if not video_id then return { success = false, error = "invalid_music_url" } end

    local metadata = SkyPhoneYouTube.FetchMetadata(video_id)
    return { success = true, data = {
        url = SkyPhoneYouTube.WatchUrl(video_id),
        videoId = video_id,
        title = metadata and metadata.title or "YouTube " .. video_id,
        artist = metadata and metadata.artist or "YouTube",
    } }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:publish", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    if not SkyPhone.AllowOperation(source, "fliptok:publish", 6, 60) then return { success = false, error = "rate_limited" } end
    if type(data) ~= "table" then return { success = false, error = "invalid_video" } end
    local media_id = tonumber(data.mediaId)
    local media_type = data.mediaType == "photo" and "photo" or "video"
    local submitted_media_ids = type(data.mediaIds) == "table" and data.mediaIds or { media_id }
    local media_ids = {}
    local seen_media_ids = {}
    local caption = trim(data.caption) or ""
    local location = trim(data.location) or ""
    local visibility = data.visibility or "public"
    local trim_start_ms = math.floor(tonumber(data.trimStartMs) or 0)
    local trim_end_ms = data.trimEndMs ~= nil and math.floor(tonumber(data.trimEndMs) or -1) or nil
    local cover_time_ms = math.floor(tonumber(data.coverTimeMs) or 0)
    local original_volume = math.floor(tonumber(data.originalVolume) or 100)
    local music_volume = math.floor(tonumber(data.musicVolume) or 0)
    local music_track = type(data.musicTrack) == "string" and data.musicTrack or ""
    local custom_music_url = trim(data.customMusicUrl) or ""
    local custom_music_title = ""
    local custom_music_artist = ""
    if not media_id or media_id < 1 or media_id ~= math.floor(media_id)
        or #submitted_media_ids < 1 or #submitted_media_ids > Config.FlipTok.MaxPostMedia
        or (media_type == "video" and #submitted_media_ids ~= 1)
        or not valid_text(caption, 0, Config.FlipTok.CaptionMaxLength)
        or not valid_text(location, 0, 80) or not visibilities[visibility]
        or type(data.commentsEnabled) ~= "boolean"
        or trim_start_ms < 0 or trim_start_ms > Config.FlipTok.MaxVideoDurationMs
        or (trim_end_ms and (trim_end_ms <= trim_start_ms or trim_end_ms > Config.FlipTok.MaxVideoDurationMs))
        or cover_time_ms < trim_start_ms or (trim_end_ms and cover_time_ms > trim_end_ms)
        or original_volume < 0 or original_volume > 100 or music_volume < 0 or music_volume > 100
        or (music_track ~= "" and not music_tracks[music_track])
    then return { success = false, error = "invalid_video" } end
    for _, value in ipairs(submitted_media_ids) do
        local normalized = tonumber(value)
        if not normalized or normalized < 1 or normalized ~= math.floor(normalized)
            or seen_media_ids[normalized]
            or not SkyPhoneMedia.ResolveOwnedMedia(source, tostring(normalized), media_type)
        then
            return { success = false, error = "invalid_media" }
        end
        seen_media_ids[normalized] = true
        media_ids[#media_ids + 1] = normalized
    end
    media_id = media_ids[1]
    if media_type == "photo" then
        trim_start_ms = 0
        trim_end_ms = nil
        cover_time_ms = 0
        original_volume = 0
    end
    if custom_music_url ~= "" then
        if music_track ~= "" then return { success = false, error = "invalid_music_url" } end
        local youtube_id = SkyPhoneYouTube.ParseId(custom_music_url)
        if youtube_id then
            local metadata = SkyPhoneYouTube.FetchMetadata(youtube_id)
            custom_music_url = SkyPhoneYouTube.WatchUrl(youtube_id)
            custom_music_title = metadata and metadata.title or "YouTube " .. youtube_id
            custom_music_artist = metadata and metadata.artist or "YouTube"
        elseif not valid_custom_music_url(custom_music_url) then
            return { success = false, error = "invalid_music_url" }
        end
    end
    if music_track == "" and custom_music_url == "" then music_volume = 0 end
    local id = new_id()
    local queries = {{ query = [[INSERT INTO `sky_phone_fliptok_videos`
        (`id`, `profile_id`, `media_id`, `caption`, `location`, `visibility`, `comments_enabled`, `trim_start_ms`, `trim_end_ms`,
            `cover_time_ms`, `original_volume`, `music_volume`, `music_track`, `custom_music_url`, `custom_music_title`,
            `custom_music_artist`, `status`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        params = {
            id, profile.id, media_id, caption, location, visibility, data.commentsEnabled and 1 or 0, trim_start_ms, trim_end_ms,
            cover_time_ms, original_volume, music_volume, music_track, custom_music_url, custom_music_title, custom_music_artist,
            data.draft == true and "draft" or "published",
        }
    }}
    for index, current_media_id in ipairs(media_ids) do
        queries[#queries + 1] = {
            query = "INSERT INTO `sky_phone_fliptok_video_media` (`video_id`, `media_id`, `sort_order`) VALUES (?, ?, ?)",
            params = { id, current_media_id, index },
        }
    end
    if not Bridge.Database.Transaction(queries) then
        return { success = false, error = "request_failed" }
    end
    return { success = true, data = { id = id } }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:react", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    if not SkyPhone.AllowOperation(source, "fliptok:react", 60, 60) then return { success = false, error = "rate_limited" } end
    if type(data) ~= "table" or type(data.id) ~= "string" or (data.kind ~= "like" and data.kind ~= "save") or type(data.active) ~= "boolean" then
        return { success = false, error = "invalid_request" }
    end
    local video = load_accessible_video(data.id, profile.id)
    if not video then return { success = false, error = "video_not_found" } end
    local owner_id = tonumber(video.profile_id)
    if data.active then
        local inserted = Bridge.Database.Query("INSERT IGNORE INTO `sky_phone_fliptok_reactions` (`video_id`, `profile_id`, `kind`) VALUES (?, ?, ?)", { data.id, profile.id, data.kind })
        if affected_rows(inserted) > 0 and data.kind == "like" and owner_id ~= profile.id then
            Bridge.Database.Query("INSERT INTO `sky_phone_fliptok_notifications` (`id`, `recipient_id`, `actor_id`, `video_id`, `kind`) VALUES (?, ?, ?, ?, 'like')", { new_id(), video.profile_id, profile.id, data.id })
            notify_profile(owner_id, profile.id, "like", data.id)
        end
    else
        Bridge.Database.Query("DELETE FROM `sky_phone_fliptok_reactions` WHERE `video_id` = ? AND `profile_id` = ? AND `kind` = ?", { data.id, profile.id, data.kind })
    end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:follow", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    if not SkyPhone.AllowOperation(source, "fliptok:follow", 30, 60) then
        return { success = false, error = "rate_limited" }
    end
    local target_id = type(data) == "table" and tonumber(data.profileId) or nil
    if not target_id or target_id == profile.id or type(data.active) ~= "boolean" then return { success = false, error = "invalid_request" } end
    local targets = Bridge.Database.Query("SELECT `id` FROM `sky_phone_fliptok_profiles` WHERE `id` = ? LIMIT 1", { target_id })
    if not targets[1] then return { success = false, error = "profile_not_found" } end
    if are_profiles_blocked(profile.id, target_id) then return { success = false, error = "blocked" } end
    if data.active then
        local inserted = Bridge.Database.Query("INSERT IGNORE INTO `sky_phone_fliptok_follows` (`follower_id`, `following_id`) SELECT ?, `id` FROM `sky_phone_fliptok_profiles` WHERE `id` = ?", { profile.id, target_id })
        if affected_rows(inserted) > 0 then
            Bridge.Database.Query("INSERT INTO `sky_phone_fliptok_notifications` (`id`, `recipient_id`, `actor_id`, `kind`) VALUES (?, ?, ?, 'follow')", { new_id(), target_id, profile.id })
            notify_profile(target_id, profile.id, "follow")
        end
    else
        Bridge.Database.Query("DELETE FROM `sky_phone_fliptok_follows` WHERE `follower_id` = ? AND `following_id` = ?", { profile.id, target_id })
    end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:comments", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    if type(data) ~= "table" or not load_accessible_video(data.id, profile.id) then
        return { success = false, error = "video_not_found" }
    end
    local rows = Bridge.Database.Query([[SELECT c.`id`, c.`parent_id`, c.`body`, UNIX_TIMESTAMP(c.`created_at`) * 1000 AS `created_at`,
        p.`id` AS `profile_id`, p.`handle`, p.`display_name`, p.`verified`, avatar.`url` AS `avatar_url`,
        parent_author.`handle` AS `reply_to_handle`,
        EXISTS(SELECT 1 FROM `sky_phone_fliptok_comment_reactions` reaction
            WHERE reaction.`comment_id` = c.`id` AND reaction.`profile_id` = ?) AS `is_liked`,
        (SELECT COUNT(*) FROM `sky_phone_fliptok_comment_reactions` reaction
            WHERE reaction.`comment_id` = c.`id`) AS `like_count`
        FROM `sky_phone_fliptok_comments` c
        JOIN `sky_phone_fliptok_profiles` p ON p.`id` = c.`profile_id`
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = p.`avatar_media_id`
        LEFT JOIN `sky_phone_fliptok_comments` parent ON parent.`id` = c.`parent_id`
        LEFT JOIN `sky_phone_fliptok_profiles` parent_author ON parent_author.`id` = parent.`profile_id`
        WHERE c.`video_id` = ? AND c.`status` = 'visible'
            AND NOT EXISTS(SELECT 1 FROM `sky_phone_fliptok_blocks` b WHERE
                (b.`blocker_id` = ? AND b.`blocked_id` = c.`profile_id`) OR (b.`blocked_id` = ? AND b.`blocker_id` = c.`profile_id`))
        ORDER BY COALESCE(parent.`created_at`, c.`created_at`) DESC,
            c.`parent_id` IS NOT NULL, c.`created_at` ASC LIMIT 100]], {
        profile.id, data.id, profile.id, profile.id,
    })
    for _, row in ipairs(rows) do
        row.verified = tonumber(row.verified) == 1
        row.is_liked = tonumber(row.is_liked) == 1
        row.like_count = tonumber(row.like_count) or 0
    end
    return { success = true, data = rows }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:comment", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    if not SkyPhone.AllowOperation(source, "fliptok:comment", 20, 60) then return { success = false, error = "rate_limited" } end
    local body = type(data) == "table" and trim(data.body) or nil
    local parent_id = type(data) == "table" and trim(data.parentId) or nil
    if type(data) ~= "table" or type(data.id) ~= "string" or not valid_text(body, 1, Config.FlipTok.CommentMaxLength) then return { success = false, error = "invalid_comment" } end
    if parent_id and #parent_id ~= 36 then return { success = false, error = "invalid_comment" } end
    local video = load_accessible_video(data.id, profile.id)
    if not video then return { success = false, error = "video_not_found" } end
    if tonumber(video.comments_enabled) ~= 1 then return { success = false, error = "comments_disabled" } end
    local owner_id = tonumber(video.profile_id)
    if parent_id then
        local parents = Bridge.Database.Query([[SELECT c.`id`, c.`parent_id`, c.`profile_id` FROM `sky_phone_fliptok_comments` c
            WHERE c.`id` = ? AND c.`video_id` = ? AND c.`status` = 'visible' LIMIT 1]], { parent_id, data.id })
        if not parents[1] or are_profiles_blocked(profile.id, tonumber(parents[1].profile_id)) then
            return { success = false, error = "invalid_comment" }
        end
        parent_id = parents[1].parent_id or parents[1].id
    end
    local comment_id = new_id()
    Bridge.Database.Query("INSERT INTO `sky_phone_fliptok_comments` (`id`, `video_id`, `profile_id`, `parent_id`, `body`) VALUES (?, ?, ?, ?, ?)", {
        comment_id, data.id, profile.id, parent_id, body,
    })
    if owner_id ~= profile.id then
        Bridge.Database.Query("INSERT INTO `sky_phone_fliptok_notifications` (`id`, `recipient_id`, `actor_id`, `video_id`, `kind`) VALUES (?, ?, ?, ?, 'comment')", { new_id(), video.profile_id, profile.id, data.id })
        notify_profile(owner_id, profile.id, "comment", data.id)
    end
    return { success = true, data = { id = comment_id } }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:comment-react", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    if not SkyPhone.AllowOperation(source, "fliptok:comment-react", 60, 60) then
        return { success = false, error = "rate_limited" }
    end
    local comment_id = type(data) == "table" and data.id or nil
    if type(comment_id) ~= "string" or #comment_id ~= 36 or type(data.active) ~= "boolean" then
        return { success = false, error = "invalid_request" }
    end
    local comments = Bridge.Database.Query([[SELECT c.`profile_id`, c.`video_id` FROM `sky_phone_fliptok_comments` c
        JOIN `sky_phone_fliptok_videos` v ON v.`id` = c.`video_id`
        WHERE c.`id` = ? AND c.`status` = 'visible' AND v.`status` = 'published' LIMIT 1]], { comment_id })
    if not comments[1] then return { success = false, error = "invalid_comment" } end
    if not load_accessible_video(comments[1].video_id, profile.id) then
        return { success = false, error = "video_not_found" }
    end
    if are_profiles_blocked(profile.id, tonumber(comments[1].profile_id)) then
        return { success = false, error = "blocked" }
    end
    if data.active then
        Bridge.Database.Query([[INSERT IGNORE INTO `sky_phone_fliptok_comment_reactions`
            (`comment_id`, `profile_id`) VALUES (?, ?)]], { comment_id, profile.id })
    else
        Bridge.Database.Query([[DELETE FROM `sky_phone_fliptok_comment_reactions`
            WHERE `comment_id` = ? AND `profile_id` = ?]], { comment_id, profile.id })
    end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:view", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    if not SkyPhone.AllowOperation(source, "fliptok:view", 120, 60) then return { success = false, error = "rate_limited" } end
    if type(data) ~= "table" or not load_accessible_video(data.id, profile.id) then
        return { success = false, error = "video_not_found" }
    end
    Bridge.Database.Query("UPDATE `sky_phone_fliptok_videos` SET `view_count` = `view_count` + 1 WHERE `id` = ? AND `status` = 'published'", { data.id })
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:share", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    if not SkyPhone.AllowOperation(source, "fliptok:share", 30, 60) then return { success = false, error = "rate_limited" } end
    if type(data) ~= "table" or not load_accessible_video(data.id, profile.id) then
        return { success = false, error = "video_not_found" }
    end
    Bridge.Database.Query("UPDATE `sky_phone_fliptok_videos` SET `share_count` = `share_count` + 1 WHERE `id` = ? AND `status` = 'published'", { data.id })
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:profile", function(source, data)
    local viewer, error_response = require_profile(source)
    if not viewer then return error_response end
    local handle = type(data) == "table" and trim(data.handle) or nil
    local id = type(data) == "table" and tonumber(data.profileId) or viewer.id
    local rows = handle and Bridge.Database.Query("SELECT `id` FROM `sky_phone_fliptok_profiles` WHERE `handle` = ? LIMIT 1", { handle }) or { { id = id } }
    if not rows[1] then return { success = false, error = "profile_not_found" } end
    if tonumber(rows[1].id) ~= viewer.id and are_profiles_blocked(viewer.id, tonumber(rows[1].id)) then
        return { success = false, error = "profile_not_found" }
    end
    local target = load_profile(tonumber(rows[1].id), viewer.id)
    if not target then return { success = false, error = "profile_not_found" } end
    local videos = list_videos(viewer.id, [[v.`profile_id` = ? AND (v.`visibility` = 'public' OR v.`profile_id` = ? OR
        (v.`visibility` = 'followers' AND EXISTS(SELECT 1 FROM `sky_phone_fliptok_follows` profile_follow
            WHERE profile_follow.`follower_id` = ? AND profile_follow.`following_id` = v.`profile_id`)))]],
        { target.id, viewer.id, viewer.id, viewer.id, viewer.id }, 60, 0, "v.`created_at` DESC")
    return { success = true, data = { profile = target, videos = videos } }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:connections", function(source, data)
    local viewer, error_response = require_profile(source)
    if not viewer then return error_response end
    local target_id = type(data) == "table" and tonumber(data.profileId) or nil
    local mode = type(data) == "table" and data.mode or nil
    if not target_id or (mode ~= "followers" and mode ~= "following") then
        return { success = false, error = "invalid_request" }
    end
    if target_id ~= viewer.id and are_profiles_blocked(viewer.id, target_id) then
        return { success = false, error = "profile_not_found" }
    end
    local join_column = mode == "followers" and "f.`follower_id`" or "f.`following_id`"
    local filter_column = mode == "followers" and "f.`following_id`" or "f.`follower_id`"
    local rows = Bridge.Database.Query(([[SELECT p.*, avatar.`url` AS `avatar_url`,
        EXISTS(SELECT 1 FROM `sky_phone_fliptok_follows` own_follow
            WHERE own_follow.`follower_id` = ? AND own_follow.`following_id` = p.`id`) AS `is_following`,
        (SELECT COUNT(*) FROM `sky_phone_fliptok_follows` followers WHERE followers.`following_id` = p.`id`) AS `followers`,
        (SELECT COUNT(*) FROM `sky_phone_fliptok_follows` following WHERE following.`follower_id` = p.`id`) AS `following`,
        (SELECT COUNT(*) FROM `sky_phone_fliptok_videos` video WHERE video.`profile_id` = p.`id` AND video.`status` = 'published') AS `video_count`
        FROM `sky_phone_fliptok_follows` f
        JOIN `sky_phone_fliptok_profiles` p ON p.`id` = %s
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = p.`avatar_media_id`
        WHERE %s = ? AND NOT EXISTS(SELECT 1 FROM `sky_phone_fliptok_blocks` block WHERE
            (block.`blocker_id` = ? AND block.`blocked_id` = p.`id`) OR
            (block.`blocked_id` = ? AND block.`blocker_id` = p.`id`))
        ORDER BY p.`display_name`, p.`handle` LIMIT 200]]):format(join_column, filter_column), {
        viewer.id, target_id, viewer.id, viewer.id,
    })
    for _, row in ipairs(rows) do hydrate_profile(row, viewer.id) end
    return { success = true, data = rows }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:update-profile", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    if type(data) ~= "table" then return { success = false, error = "invalid_request" } end
    local handle = normalize_handle(data.handle)
    local display_name = trim(data.displayName)
    local bio = trim(data.bio)
    local account_type = data.accountType
    if not handle
        or not valid_text(display_name, 1, 40) or not valid_text(bio, 0, Config.FlipTok.BioMaxLength) or not account_types[account_type]
    then return { success = false, error = "invalid_profile" } end
    local avatar_media_id = profile.avatar_media_id and tonumber(profile.avatar_media_id) or nil
    if data.avatarMediaId ~= nil then
        local requested_avatar_id = tonumber(data.avatarMediaId)
        if not requested_avatar_id or requested_avatar_id < 0 or requested_avatar_id ~= math.floor(requested_avatar_id) then
            return { success = false, error = "invalid_profile_image" }
        end
        if requested_avatar_id > 0 and not SkyPhoneMedia.ResolveOwnedMedia(source, requested_avatar_id, "photo") then
            return { success = false, error = "invalid_profile_image" }
        end
        avatar_media_id = requested_avatar_id > 0 and requested_avatar_id or nil
    end
    local duplicate = Bridge.Database.Query("SELECT `id` FROM `sky_phone_fliptok_profiles` WHERE `handle` = ? AND `id` <> ? LIMIT 1", { handle, profile.id })
    if duplicate[1] then return { success = false, error = "handle_taken" } end
    Bridge.Database.Query("UPDATE `sky_phone_fliptok_profiles` SET `handle` = ?, `display_name` = ?, `bio` = ?, `account_type` = ?, `avatar_media_id` = ? WHERE `id` = ?", {
        handle, display_name, bio, account_type, avatar_media_id, profile.id,
    })
    return { success = true, data = load_profile(profile.id, profile.id) }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:activities", function(source)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    local rows = Bridge.Database.Query([[SELECT n.`id`, n.`kind`, n.`video_id`, n.`read_at`, UNIX_TIMESTAMP(n.`created_at`) * 1000 AS `created_at`,
        p.`id` AS `profile_id`, p.`handle`, p.`display_name`, p.`verified`, avatar.`url` AS `avatar_url`
        FROM `sky_phone_fliptok_notifications` n JOIN `sky_phone_fliptok_profiles` p ON p.`id` = n.`actor_id`
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = p.`avatar_media_id`
        WHERE n.`recipient_id` = ?
            AND (n.`kind` = 'verified' OR NOT EXISTS(SELECT 1 FROM `sky_phone_fliptok_blocks` b WHERE
                (b.`blocker_id` = n.`recipient_id` AND b.`blocked_id` = n.`actor_id`) OR
                (b.`blocked_id` = n.`recipient_id` AND b.`blocker_id` = n.`actor_id`)))
        ORDER BY n.`created_at` DESC LIMIT 100]], { profile.id })
    for _, row in ipairs(rows) do row.verified = tonumber(row.verified) == 1 end
    return { success = true, data = rows }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:mark-activities", function(source)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    Bridge.Database.Query("UPDATE `sky_phone_fliptok_notifications` SET `read_at` = NOW() WHERE `recipient_id` = ? AND `read_at` IS NULL", { profile.id })
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:report", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    if not SkyPhone.AllowOperation(source, "fliptok:report", 10, 60) then return { success = false, error = "rate_limited" } end
    local reason = type(data) == "table" and data.reason or nil
    local details = type(data) == "table" and trim(data.details) or ""
    if type(data) ~= "table" or type(data.id) ~= "string" or not report_reasons[reason] or not valid_text(details, 0, 500) then return { success = false, error = "invalid_report" } end
    local videos = Bridge.Database.Query([[SELECT v.`profile_id`, v.`caption`, creator.`handle`, creator.`display_name`, media.`url`
        FROM `sky_phone_fliptok_videos` v
        JOIN `sky_phone_fliptok_profiles` creator ON creator.`id` = v.`profile_id`
        JOIN `sky_phone_media` media ON media.`id` = v.`media_id`
        WHERE v.`id` = ? AND v.`status` = 'published'
            AND (v.`profile_id` = ? OR v.`visibility` = 'public' OR
                (v.`visibility` = 'followers' AND EXISTS(SELECT 1 FROM `sky_phone_fliptok_follows` f
                    WHERE f.`follower_id` = ? AND f.`following_id` = v.`profile_id`)))
            AND NOT EXISTS(SELECT 1 FROM `sky_phone_fliptok_blocks` b WHERE
                (b.`blocker_id` = ? AND b.`blocked_id` = v.`profile_id`) OR
                (b.`blocked_id` = ? AND b.`blocker_id` = v.`profile_id`))
        LIMIT 1]], { data.id, profile.id, profile.id, profile.id, profile.id })
    if not videos[1] then return { success = false, error = "video_not_found" } end
    local webhook = report_webhook_url()
    if not webhook then
        Bridge.Debug("warn", "[sky_phone] FlipTok report webhook is not configured.", { always = true })
        return { success = false, error = "report_unavailable" }
    end
    local video = videos[1]
    local payload = {
        username = "Sky Phone · FlipTok Reports",
        allowed_mentions = { parse = {} },
        embeds = {{
            title = "New FlipTok report",
            color = 16723285,
            url = video.url,
            description = details ~= "" and details or "No additional details supplied.",
            fields = {
                { name = "Reason", value = reason, inline = true },
                { name = "Video", value = tostring(data.id), inline = true },
                { name = "Creator", value = ("@%s (%s)"):format(video.handle, video.display_name), inline = false },
                { name = "Reporter", value = ("@%s (%s)"):format(profile.handle, profile.display_name), inline = false },
                { name = "Caption", value = video.caption ~= "" and truncate_discord_text(video.caption, 240) or "—", inline = false },
            },
            footer = { text = "sky_phone FlipTok" },
        }},
    }
    PerformHttpRequest(webhook, function(status)
        local status_code = tonumber(status) or 0
        if status_code < 200 or status_code >= 300 then
            Bridge.Debug("warn", "[sky_phone] FlipTok Discord report webhook returned HTTP %s.", status_code, { always = true })
        end
    end, "POST", json.encode(payload), { ["Content-Type"] = "application/json" })
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:block", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    if not SkyPhone.AllowOperation(source, "fliptok:block", 20, 60) then
        return { success = false, error = "rate_limited" }
    end
    local target_id = type(data) == "table" and tonumber(data.profileId) or nil
    if not target_id or target_id == profile.id then return { success = false, error = "invalid_request" } end
    local targets = Bridge.Database.Query("SELECT `id` FROM `sky_phone_fliptok_profiles` WHERE `id` = ? LIMIT 1", { target_id })
    if not targets[1] then return { success = false, error = "profile_not_found" } end
    if not Bridge.Database.Transaction({
        { query = "INSERT IGNORE INTO `sky_phone_fliptok_blocks` (`blocker_id`, `blocked_id`) VALUES (?, ?)", params = { profile.id, target_id } },
        { query = "DELETE FROM `sky_phone_fliptok_follows` WHERE (`follower_id` = ? AND `following_id` = ?) OR (`follower_id` = ? AND `following_id` = ?)", params = { profile.id, target_id, target_id, profile.id } },
    }) then return { success = false, error = "request_failed" } end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:delete", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    if type(data) ~= "table" or type(data.id) ~= "string" then return { success = false, error = "video_not_found" } end
    local result = Bridge.Database.Query("UPDATE `sky_phone_fliptok_videos` SET `status` = 'removed' WHERE `id` = ? AND `profile_id` = ?", { data.id, profile.id })
    local affected = type(result) == "number" and result or type(result) == "table" and tonumber(result.affectedRows) or 0
    return affected > 0 and { success = true } or { success = false, error = "video_not_found" }
end)

local active_verify_command = nil
local registered_verify_commands = {}

local function run_verify_command(source, arguments)
    local command_locale = SkyPhoneLocales.Resolve(Config.Bridge.Locale).FlipTokCommand
    local function command_message(template, values)
        return template:gsub("{(%w+)}", function(key) return values[key] or "" end)
    end
    local function send_command_feedback(message, notification_type)
        if source == 0 then
            Bridge.Debug(notification_type == "error" and "error" or "info", message)
            return
        end

        TriggerClientEvent("sky_phone:fliptok:command-feedback", source, {
            message = message,
            notificationType = notification_type,
        })
    end
    if source ~= 0 and not Bridge.Framework.HasAdminGroup(source, Config.FlipTok.AdminGroups) then
        send_command_feedback(command_locale.noPermission, "error")
        Bridge.Debug(
            "warn",
            "[sky_phone] Player %d attempted to use the FlipTok verification command without an admin group.",
            source
        )
        return
    end
    local handle = type(arguments[1]) == "string" and arguments[1]:lower():gsub("^@", "") or ""
    local requested = type(arguments[2]) == "string" and arguments[2]:lower() or nil
    if handle == "" or (requested and requested ~= "on" and requested ~= "off") then
        local message = command_message(command_locale.usage, { command = Config.FlipTok.VerifyCommand })
        send_command_feedback(message, "error")
        return
    end
    local rows = Bridge.Database.Query("SELECT `id`, `verified` FROM `sky_phone_fliptok_profiles` WHERE `handle` = ? LIMIT 1", { handle })
    if not rows[1] then
        local message = command_message(command_locale.notFound, { handle = handle })
        send_command_feedback(message, "error")
        return
    end
    local verified
    if requested then
        verified = requested == "on"
    else
        verified = tonumber(rows[1].verified) ~= 1
    end
    Bridge.Database.Query("UPDATE `sky_phone_fliptok_profiles` SET `verified` = ? WHERE `id` = ?", { verified and 1 or 0, rows[1].id })
    if verified then
        Bridge.Database.Query("INSERT INTO `sky_phone_fliptok_notifications` (`id`, `recipient_id`, `actor_id`, `kind`) VALUES (?, ?, ?, 'verified')", {
            new_id(), rows[1].id, rows[1].id,
        })
        notify_profile(tonumber(rows[1].id), tonumber(rows[1].id), "verified")
    end
    TriggerClientEvent("sky_phone:fliptok:verification-changed", -1, {
        profileId = tonumber(rows[1].id),
        verified = verified,
    })
    local message = command_message(command_locale.updated, {
        handle = handle,
        state = verified and command_locale.verified or command_locale.unverified,
    })
    send_command_feedback(message, "success")
end

local function refresh_verify_command()
    local command_name = Config.FlipTok.VerifyCommand
    if type(command_name) ~= "string" or command_name == "" then
        error("[sky_phone] Config.FlipTok.VerifyCommand must be a non-empty command name.")
    end
    active_verify_command = command_name
    if registered_verify_commands[command_name] then
        return
    end
    registered_verify_commands[command_name] = true
    RegisterCommand(command_name, function(source, arguments)
        if active_verify_command == command_name then
            run_verify_command(source, arguments)
        end
    end, false)
end

refresh_verify_command()

AddEventHandler("sky_phone:configurator:serverUpdated", refresh_verify_command)
end)
