Bridge.Database.AfterMigration("sky_phone", function()
local account_types = { person = true, business = true, organization = true, media = true, event = true }
local visibilities = { public = true, followers = true, private = true }
local report_reasons = { spam = true, harassment = true, dangerous = true, illegal = true, other = true }
local report_actions = { dismiss = true, remove = true }
local music_tracks = {}
local music_track_list = {}

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

local function trim(value)
    if type(value) ~= "string" then return nil end
    return value:match("^%s*(.-)%s*$")
end

local function valid_text(value, minimum, maximum)
    local length = type(value) == "string" and utf8.len(value) or nil
    return length and length >= minimum and length <= maximum
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

local function profile_for_account(account)
    local rows = Bridge.Database.Query("SELECT * FROM `sky_phone_fliptok_profiles` WHERE `account_id` = ? LIMIT 1", { account.id })
    if rows[1] then return rows[1] end

    local base = account.email:match("^([^@]+)") or "user"
    base = base:lower():gsub("[^a-z0-9._]", ""):sub(1, 16)
    if #base < 3 then base = "user" end
    local handle = base
    local suffix = 0
    while Bridge.Database.Query("SELECT `id` FROM `sky_phone_fliptok_profiles` WHERE `handle` = ? LIMIT 1", { handle })[1] do
        suffix = suffix + 1
        handle = (base:sub(1, 18) .. tostring(account.id) .. tostring(suffix)):sub(1, 24)
    end
    Bridge.Database.Query([[INSERT INTO `sky_phone_fliptok_profiles`
        (`account_id`, `handle`, `display_name`) VALUES (?, ?, ?)]], { account.id, handle, base })
    return Bridge.Database.Query("SELECT * FROM `sky_phone_fliptok_profiles` WHERE `account_id` = ? LIMIT 1", { account.id })[1]
end

local function require_profile(source)
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then return nil, error_response end
    return profile_for_account(account), nil
end

local function hydrate_profile(profile, viewer_id)
    profile.id = tonumber(profile.id)
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
        SELECT p.*,
            EXISTS(SELECT 1 FROM `sky_phone_fliptok_follows` f WHERE f.`follower_id` = ? AND f.`following_id` = p.`id`) AS `is_following`,
            (SELECT COUNT(*) FROM `sky_phone_fliptok_follows` f WHERE f.`following_id` = p.`id`) AS `followers`,
            (SELECT COUNT(*) FROM `sky_phone_fliptok_follows` f WHERE f.`follower_id` = p.`id`) AS `following`,
            (SELECT COUNT(*) FROM `sky_phone_fliptok_videos` v WHERE v.`profile_id` = p.`id` AND v.`status` = 'published') AS `video_count`
        FROM `sky_phone_fliptok_profiles` p WHERE p.`id` = ? LIMIT 1
    ]], { viewer_id, profile_id })
    return rows[1] and hydrate_profile(rows[1], viewer_id) or nil
end

local function notify_profile(recipient_id, actor_id, kind, video_id)
    local rows = Bridge.Database.Query([[SELECT recipient.`account_id`, actor.`display_name` AS `actor_name`
        FROM `sky_phone_fliptok_profiles` recipient
        JOIN `sky_phone_fliptok_profiles` actor ON actor.`id` = ?
        WHERE recipient.`id` = ? LIMIT 1]], { actor_id, recipient_id })
    SkyPhone.NotifyAccountDevices(tonumber(rows[1].account_id), "sky_phone:fliptok:new", {
        actor = rows[1].actor_name,
        kind = kind,
        videoId = video_id,
    })
end

local function hydrate_videos(rows)
    for _, video in ipairs(rows) do
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
        video.music_title = track and track.title or ""
        video.music_artist = track and track.artist or ""
        video.music_url = track and track.url or ""
        video.created_at = (tonumber(video.created_at_unix) or 0) * 1000
        video.created_at_unix = nil
    end
    return rows
end

local function list_videos(viewer_id, where_clause, values, limit, offset, ranking)
    local parameters = { viewer_id, viewer_id, viewer_id, viewer_id }
    for _, value in ipairs(values) do parameters[#parameters + 1] = value end
    parameters[#parameters + 1] = limit
    parameters[#parameters + 1] = offset
    return hydrate_videos(Bridge.Database.Query(([[
        SELECT v.`id`, v.`profile_id`, v.`caption`, v.`location`, v.`comments_enabled`, v.`view_count`, v.`share_count`,
            v.`trim_start_ms`, v.`trim_end_ms`, v.`cover_time_ms`, v.`original_volume`, v.`music_volume`, v.`music_track`,
            m.`url`, UNIX_TIMESTAMP(v.`created_at`) AS `created_at_unix`, p.`handle`, p.`display_name`, p.`verified`,
            (v.`profile_id` = ?) AS `is_owner`,
            EXISTS(SELECT 1 FROM `sky_phone_fliptok_reactions` r WHERE r.`video_id` = v.`id` AND r.`profile_id` = ? AND r.`kind` = 'like') AS `is_liked`,
            EXISTS(SELECT 1 FROM `sky_phone_fliptok_reactions` r WHERE r.`video_id` = v.`id` AND r.`profile_id` = ? AND r.`kind` = 'save') AS `is_saved`,
            EXISTS(SELECT 1 FROM `sky_phone_fliptok_follows` f WHERE f.`follower_id` = ? AND f.`following_id` = v.`profile_id`) AS `is_following`,
            (SELECT COUNT(*) FROM `sky_phone_fliptok_reactions` r WHERE r.`video_id` = v.`id` AND r.`kind` = 'like') AS `like_count`,
            (SELECT COUNT(*) FROM `sky_phone_fliptok_comments` c WHERE c.`video_id` = v.`id` AND c.`status` = 'visible') AS `comment_count`
        FROM `sky_phone_fliptok_videos` v
        JOIN `sky_phone_fliptok_profiles` p ON p.`id` = v.`profile_id`
        JOIN `sky_phone_media` m ON m.`id` = v.`media_id`
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

Bridge.Callbacks.Register("sky_phone:fliptok:bootstrap", function(source)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    local result = feed(source, { mode = "for-you", offset = 0 })
    if not result.success then return result end
    return { success = true, data = {
        profile = load_profile(profile.id, profile.id),
        feed = result.data,
        isAdmin = Bridge.Framework.HasAdminGroup(source, Config.FlipTok.ReportAdminGroups),
        musicTracks = music_track_list,
    } }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:feed", feed)

Bridge.Callbacks.Register("sky_phone:fliptok:discover", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    local search = type(data) == "table" and trim(data.search) or ""
    if search and utf8.len(search) > 50 then return { success = false, error = "invalid_request" } end
    local pattern = "%" .. (search or "") .. "%"
    local rows = list_videos(profile.id, "v.`visibility` = 'public' AND (p.`handle` LIKE ? OR p.`display_name` LIKE ? OR v.`caption` LIKE ?)", { pattern, pattern, pattern, profile.id, profile.id }, Config.FlipTok.PageSize, 0, "v.`created_at` DESC")
    return { success = true, data = rows }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:publish", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    if not SkyPhone.AllowOperation(source, "fliptok:publish", 6, 60) then return { success = false, error = "rate_limited" } end
    if type(data) ~= "table" then return { success = false, error = "invalid_video" } end
    local media_id = tonumber(data.mediaId)
    local caption = trim(data.caption) or ""
    local location = trim(data.location) or ""
    local visibility = data.visibility or "public"
    local trim_start_ms = math.floor(tonumber(data.trimStartMs) or 0)
    local trim_end_ms = data.trimEndMs ~= nil and math.floor(tonumber(data.trimEndMs) or -1) or nil
    local cover_time_ms = math.floor(tonumber(data.coverTimeMs) or 0)
    local original_volume = math.floor(tonumber(data.originalVolume) or 100)
    local music_volume = math.floor(tonumber(data.musicVolume) or 0)
    local music_track = type(data.musicTrack) == "string" and data.musicTrack or ""
    if not media_id or media_id < 1 or media_id ~= math.floor(media_id)
        or not valid_text(caption, 0, Config.FlipTok.CaptionMaxLength)
        or not valid_text(location, 0, 80) or not visibilities[visibility]
        or type(data.commentsEnabled) ~= "boolean"
        or trim_start_ms < 0 or trim_start_ms > Config.FlipTok.MaxVideoDurationMs
        or (trim_end_ms and (trim_end_ms <= trim_start_ms or trim_end_ms > Config.FlipTok.MaxVideoDurationMs))
        or cover_time_ms < trim_start_ms or (trim_end_ms and cover_time_ms > trim_end_ms)
        or original_volume < 0 or original_volume > 100 or music_volume < 0 or music_volume > 100
        or (music_track ~= "" and not music_tracks[music_track])
    then return { success = false, error = "invalid_video" } end
    if music_track == "" then music_volume = 0 end
    if not SkyPhoneMedia.ResolveOwnedMedia(source, tostring(media_id), "video") then
        return { success = false, error = "invalid_media" }
    end
    local id = new_id()
    Bridge.Database.Query([[INSERT INTO `sky_phone_fliptok_videos`
        (`id`, `profile_id`, `media_id`, `caption`, `location`, `visibility`, `comments_enabled`, `trim_start_ms`, `trim_end_ms`,
            `cover_time_ms`, `original_volume`, `music_volume`, `music_track`, `status`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
        id, profile.id, media_id, caption, location, visibility, data.commentsEnabled and 1 or 0, trim_start_ms, trim_end_ms,
        cover_time_ms, original_volume, music_volume, music_track, data.draft == true and "draft" or "published",
    })
    return { success = true, data = { id = id } }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:react", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    if not SkyPhone.AllowOperation(source, "fliptok:react", 60, 60) then return { success = false, error = "rate_limited" } end
    if type(data) ~= "table" or type(data.id) ~= "string" or (data.kind ~= "like" and data.kind ~= "save") or type(data.active) ~= "boolean" then
        return { success = false, error = "invalid_request" }
    end
    local videos = Bridge.Database.Query("SELECT `profile_id` FROM `sky_phone_fliptok_videos` WHERE `id` = ? AND `status` = 'published' LIMIT 1", { data.id })
    if not videos[1] then return { success = false, error = "video_not_found" } end
    local owner_id = tonumber(videos[1].profile_id)
    if owner_id ~= profile.id and are_profiles_blocked(profile.id, owner_id) then
        return { success = false, error = "blocked" }
    end
    if data.active then
        local inserted = Bridge.Database.Query("INSERT IGNORE INTO `sky_phone_fliptok_reactions` (`video_id`, `profile_id`, `kind`) VALUES (?, ?, ?)", { data.id, profile.id, data.kind })
        if affected_rows(inserted) > 0 and data.kind == "like" and owner_id ~= profile.id then
            Bridge.Database.Query("INSERT INTO `sky_phone_fliptok_notifications` (`id`, `recipient_id`, `actor_id`, `video_id`, `kind`) VALUES (?, ?, ?, ?, 'like')", { new_id(), videos[1].profile_id, profile.id, data.id })
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
    local target_id = type(data) == "table" and tonumber(data.profileId) or nil
    if not target_id or target_id == profile.id or type(data.active) ~= "boolean" then return { success = false, error = "invalid_request" } end
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
    if type(data) ~= "table" or type(data.id) ~= "string" then return { success = false, error = "invalid_request" } end
    local rows = Bridge.Database.Query([[SELECT c.`id`, c.`body`, UNIX_TIMESTAMP(c.`created_at`) * 1000 AS `created_at`,
        p.`id` AS `profile_id`, p.`handle`, p.`display_name`, p.`verified`
        FROM `sky_phone_fliptok_comments` c JOIN `sky_phone_fliptok_profiles` p ON p.`id` = c.`profile_id`
        WHERE c.`video_id` = ? AND c.`status` = 'visible'
            AND NOT EXISTS(SELECT 1 FROM `sky_phone_fliptok_blocks` b WHERE
                (b.`blocker_id` = ? AND b.`blocked_id` = c.`profile_id`) OR (b.`blocked_id` = ? AND b.`blocker_id` = c.`profile_id`))
        ORDER BY c.`created_at` DESC LIMIT 100]], { data.id, profile.id, profile.id })
    for _, row in ipairs(rows) do row.verified = tonumber(row.verified) == 1 end
    return { success = true, data = rows }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:comment", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    if not SkyPhone.AllowOperation(source, "fliptok:comment", 20, 60) then return { success = false, error = "rate_limited" } end
    local body = type(data) == "table" and trim(data.body) or nil
    if type(data) ~= "table" or type(data.id) ~= "string" or not valid_text(body, 1, Config.FlipTok.CommentMaxLength) then return { success = false, error = "invalid_comment" } end
    local videos = Bridge.Database.Query("SELECT `profile_id` FROM `sky_phone_fliptok_videos` WHERE `id` = ? AND `status` = 'published' AND `comments_enabled` = 1 LIMIT 1", { data.id })
    if not videos[1] then return { success = false, error = "comments_disabled" } end
    local owner_id = tonumber(videos[1].profile_id)
    if owner_id ~= profile.id and are_profiles_blocked(profile.id, owner_id) then
        return { success = false, error = "blocked" }
    end
    Bridge.Database.Query("INSERT INTO `sky_phone_fliptok_comments` (`id`, `video_id`, `profile_id`, `body`) VALUES (?, ?, ?, ?)", { new_id(), data.id, profile.id, body })
    if tonumber(videos[1].profile_id) ~= profile.id then
        Bridge.Database.Query("INSERT INTO `sky_phone_fliptok_notifications` (`id`, `recipient_id`, `actor_id`, `video_id`, `kind`) VALUES (?, ?, ?, ?, 'comment')", { new_id(), videos[1].profile_id, profile.id, data.id })
        notify_profile(owner_id, profile.id, "comment", data.id)
    end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:view", function(source, data)
    local _, error_response = require_profile(source)
    if error_response then return error_response end
    if not SkyPhone.AllowOperation(source, "fliptok:view", 120, 60) then return { success = false, error = "rate_limited" } end
    if type(data) ~= "table" or type(data.id) ~= "string" then return { success = false, error = "invalid_request" } end
    Bridge.Database.Query("UPDATE `sky_phone_fliptok_videos` SET `view_count` = `view_count` + 1 WHERE `id` = ? AND `status` = 'published'", { data.id })
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:share", function(source, data)
    local _, error_response = require_profile(source)
    if error_response then return error_response end
    if not SkyPhone.AllowOperation(source, "fliptok:share", 30, 60) then return { success = false, error = "rate_limited" } end
    if type(data) ~= "table" or type(data.id) ~= "string" then return { success = false, error = "invalid_request" } end
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
    local videos = list_videos(viewer.id, "v.`profile_id` = ? AND (v.`visibility` = 'public' OR v.`profile_id` = ?)", { target.id, viewer.id, viewer.id, viewer.id }, 60, 0, "v.`created_at` DESC")
    return { success = true, data = { profile = target, videos = videos } }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:update-profile", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    local handle = type(data) == "table" and trim(data.handle) or nil
    local display_name = type(data) == "table" and trim(data.displayName) or nil
    local bio = type(data) == "table" and trim(data.bio) or nil
    local account_type = type(data) == "table" and data.accountType or nil
    if not handle or not handle:match("^[a-z0-9._]+$") or not valid_text(handle, 3, 24)
        or not valid_text(display_name, 1, 40) or not valid_text(bio, 0, Config.FlipTok.BioMaxLength) or not account_types[account_type]
    then return { success = false, error = "invalid_profile" } end
    local duplicate = Bridge.Database.Query("SELECT `id` FROM `sky_phone_fliptok_profiles` WHERE `handle` = ? AND `id` <> ? LIMIT 1", { handle, profile.id })
    if duplicate[1] then return { success = false, error = "handle_taken" } end
    Bridge.Database.Query("UPDATE `sky_phone_fliptok_profiles` SET `handle` = ?, `display_name` = ?, `bio` = ?, `account_type` = ? WHERE `id` = ?", { handle, display_name, bio, account_type, profile.id })
    return { success = true, data = load_profile(profile.id, profile.id) }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:activities", function(source)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    local rows = Bridge.Database.Query([[SELECT n.`id`, n.`kind`, n.`video_id`, n.`read_at`, UNIX_TIMESTAMP(n.`created_at`) * 1000 AS `created_at`,
        p.`id` AS `profile_id`, p.`handle`, p.`display_name`, p.`verified`
        FROM `sky_phone_fliptok_notifications` n JOIN `sky_phone_fliptok_profiles` p ON p.`id` = n.`actor_id`
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
    local videos = Bridge.Database.Query([[SELECT v.`profile_id` FROM `sky_phone_fliptok_videos` v
        WHERE v.`id` = ? AND v.`status` = 'published'
            AND (v.`profile_id` = ? OR v.`visibility` = 'public' OR
                (v.`visibility` = 'followers' AND EXISTS(SELECT 1 FROM `sky_phone_fliptok_follows` f
                    WHERE f.`follower_id` = ? AND f.`following_id` = v.`profile_id`)))
            AND NOT EXISTS(SELECT 1 FROM `sky_phone_fliptok_blocks` b WHERE
                (b.`blocker_id` = ? AND b.`blocked_id` = v.`profile_id`) OR
                (b.`blocked_id` = ? AND b.`blocker_id` = v.`profile_id`))
        LIMIT 1]], { data.id, profile.id, profile.id, profile.id, profile.id })
    if not videos[1] then return { success = false, error = "video_not_found" } end
    Bridge.Database.Query("INSERT IGNORE INTO `sky_phone_fliptok_reports` (`id`, `reporter_id`, `video_id`, `reason`, `details`) VALUES (?, ?, ?, ?, ?)", { new_id(), profile.id, data.id, reason, details })
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:admin-reports", function(source)
    local _, error_response = require_profile(source)
    if error_response then return error_response end
    if not Bridge.Framework.HasAdminGroup(source, Config.FlipTok.ReportAdminGroups) then
        return { success = false, error = "not_authorized" }
    end
    local rows = Bridge.Database.Query([[SELECT r.`id`, r.`video_id`, r.`reason`, r.`details`,
        UNIX_TIMESTAMP(r.`created_at`) * 1000 AS `created_at`, v.`caption`, m.`url`,
        reporter.`handle` AS `reporter_handle`, reporter.`display_name` AS `reporter_display_name`,
        creator.`handle` AS `creator_handle`, creator.`display_name` AS `creator_display_name`
        FROM `sky_phone_fliptok_reports` r
        JOIN `sky_phone_fliptok_videos` v ON v.`id` = r.`video_id`
        JOIN `sky_phone_media` m ON m.`id` = v.`media_id`
        JOIN `sky_phone_fliptok_profiles` reporter ON reporter.`id` = r.`reporter_id`
        JOIN `sky_phone_fliptok_profiles` creator ON creator.`id` = v.`profile_id`
        WHERE r.`status` = 'open' ORDER BY r.`created_at` ASC LIMIT 200]], {})
    return { success = true, data = rows }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:admin-resolve-report", function(source, data)
    local _, error_response = require_profile(source)
    if error_response then return error_response end
    if not Bridge.Framework.HasAdminGroup(source, Config.FlipTok.ReportAdminGroups) then
        return { success = false, error = "not_authorized" }
    end
    local id = type(data) == "table" and data.id or nil
    local action = type(data) == "table" and data.action or nil
    if type(id) ~= "string" or not report_actions[action] then
        return { success = false, error = "invalid_request" }
    end
    local reports = Bridge.Database.Query("SELECT `video_id` FROM `sky_phone_fliptok_reports` WHERE `id` = ? AND `status` = 'open' LIMIT 1", { id })
    if not reports[1] then return { success = false, error = "report_not_found" } end
    if action == "remove" then
        Bridge.Database.Transaction({
            { query = "UPDATE `sky_phone_fliptok_videos` SET `status` = 'removed' WHERE `id` = ?", params = { reports[1].video_id } },
            { query = "UPDATE `sky_phone_fliptok_reports` SET `status` = 'reviewed' WHERE `video_id` = ? AND `status` = 'open'", params = { reports[1].video_id } },
        })
    else
        Bridge.Database.Query("UPDATE `sky_phone_fliptok_reports` SET `status` = 'dismissed' WHERE `id` = ?", { id })
    end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:fliptok:block", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    local target_id = type(data) == "table" and tonumber(data.profileId) or nil
    if not target_id or target_id == profile.id then return { success = false, error = "invalid_request" } end
    Bridge.Database.Transaction({
        { query = "INSERT IGNORE INTO `sky_phone_fliptok_blocks` (`blocker_id`, `blocked_id`) VALUES (?, ?)", params = { profile.id, target_id } },
        { query = "DELETE FROM `sky_phone_fliptok_follows` WHERE (`follower_id` = ? AND `following_id` = ?) OR (`follower_id` = ? AND `following_id` = ?)", params = { profile.id, target_id, target_id, profile.id } },
    })
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

RegisterCommand(Config.FlipTok.VerifyCommand, function(source, arguments)
    local command_locale = (Locales[Config.Bridge.Locale] or Locales["en"]).FlipTokCommand
    local function command_message(template, values)
        return template:gsub("{(%w+)}", function(key) return values[key] or "" end)
    end
    local function send_command_feedback(message, notification_type)
        if source == 0 then
            print(message)
            return
        end

        TriggerClientEvent("sky_phone:fliptok:command-feedback", source, {
            message = message,
            notificationType = notification_type,
        })
    end
    if source ~= 0 and not Bridge.Framework.HasAdminGroup(source, Config.FlipTok.AdminGroups) then
        send_command_feedback(command_locale.noPermission, "error")
        print(("[sky_phone] Player %d attempted to use the FlipTok verification command without an admin group."):format(source))
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
end, false)
end)
