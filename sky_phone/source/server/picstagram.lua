Bridge.Database.AfterMigration("sky_phone", function()
local report_reasons = {}
local password_pepper = ""

local function refresh_runtime_configuration()
    password_pepper = tostring(Config.Server.PicstagramPasswordPepper or "")
    report_reasons = {}
    for index = 1, #Config.Picstagram.ReportReasons do
        report_reasons[Config.Picstagram.ReportReasons[index]] = true
    end
end

refresh_runtime_configuration()

if password_pepper == "" then
    Bridge.Debug(
        "warn",
        "[sky_phone] Config.Server.PicstagramPasswordPepper is empty. Picstagram passwords still work, but their hashes lack the required server-side secret. Set a stable random value in config/config.lua before production; changing it later invalidates existing Picstagram passwords.",
        { always = true }
    )
end

AddEventHandler("sky_phone:configurator:serverUpdated", function()
    refresh_runtime_configuration()
end)

local function trim(value)
    if type(value) ~= "string" then
        return nil
    end
    return value:match("^%s*(.-)%s*$")
end

local function valid_text(value, minimum, maximum)
    local length = type(value) == "string" and utf8.len(value) or nil
    return length and length >= minimum and length <= maximum
end

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end
    if type(result) == "table" then
        return tonumber(result.affectedRows) or tonumber(result.affected_rows) or 0
    end
    return 0
end

local function new_id()
    local rows = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    if not rows[1] or type(rows[1].id) ~= "string" then
        error("[sky_phone] Database did not generate a Picstagram id.")
    end
    return rows[1].id
end

local function valid_id(value)
    return type(value) == "string" and #value == 36 and value:match("^[0-9a-fA-F%-]+$") ~= nil
end

local function normalize_handle(value)
    local handle = trim(value)
    if not handle then
        return nil
    end
    handle = handle:lower():gsub("^@", "")
    if #handle < 3
        or #handle > 24
        or not handle:match("^[a-z0-9][a-z0-9._]*[a-z0-9]$")
        or handle:find("..", 1, true)
    then
        return nil
    end
    return handle
end

local function valid_password(value)
    local length = type(value) == "string" and utf8.len(value) or nil
    return length
        and length >= Config.Picstagram.PasswordMinLength
        and length <= Config.Picstagram.PasswordMaxLength
end

local function are_profiles_blocked(first_id, second_id)
    local rows = Bridge.Database.Query([[
        SELECT `id` FROM `sky_phone_picstagram_blocks`
        WHERE (`blocker_id` = ? AND `blocked_id` = ?)
            OR (`blocker_id` = ? AND `blocked_id` = ?)
        LIMIT 1
    ]], { first_id, second_id, second_id, first_id })
    return rows[1] ~= nil
end

local function profile_for_session(source)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return nil, error_response
    end
    local rows = Bridge.Database.Query([[
        SELECT p.* FROM `sky_phone_picstagram_sessions` s
        JOIN `sky_phone_picstagram_profiles` p ON p.`id` = s.`profile_id`
        WHERE s.`device_imei` = ? LIMIT 1
    ]], { session.imei })
    if not rows[1] then
        return nil, { success = false, error = "picstagram_not_authenticated" }
    end
    if rows[1].status ~= "active" then
        return nil, { success = false, error = "profile_unavailable" }
    end
    return rows[1]
end

local function hydrate_profile(profile, viewer_id)
    profile.private = tonumber(profile.private) == 1
    profile.verified = tonumber(profile.verified) == 1
    profile.is_owner = viewer_id == profile.id
    profile.followers = tonumber(profile.followers) or 0
    profile.following = tonumber(profile.following) or 0
    profile.post_count = tonumber(profile.post_count) or 0
    profile.avatar_media_id = tonumber(profile.avatar_media_id)
    profile.follow_status = profile.follow_status ~= "" and profile.follow_status or nil
    profile.is_following = profile.follow_status == "accepted"
    profile.is_requested = profile.follow_status == "pending"
    profile.locked = profile.private and not profile.is_owner and not profile.is_following
    return profile
end

local function load_profile(profile_id, viewer_id)
    local rows = Bridge.Database.Query([[
        SELECT p.`id`, p.`handle`, p.`display_name`, p.`bio`, p.`avatar_media_id`, p.`private`, p.`verified`, p.`status`,
            avatar.`url` AS `avatar_url`,
            COALESCE((SELECT f.`status` FROM `sky_phone_picstagram_follows` f
                WHERE f.`follower_id` = ? AND f.`following_id` = p.`id` LIMIT 1), '') AS `follow_status`,
            (SELECT COUNT(*) FROM `sky_phone_picstagram_follows` f
                WHERE f.`following_id` = p.`id` AND f.`status` = 'accepted') AS `followers`,
            (SELECT COUNT(*) FROM `sky_phone_picstagram_follows` f
                WHERE f.`follower_id` = p.`id` AND f.`status` = 'accepted') AS `following`,
            (SELECT COUNT(*) FROM `sky_phone_picstagram_posts` post
                WHERE post.`profile_id` = p.`id` AND post.`status` = 'published') AS `post_count`
        FROM `sky_phone_picstagram_profiles` p
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = p.`avatar_media_id`
        WHERE p.`id` = ? AND p.`status` = 'active'
            AND NOT EXISTS(SELECT 1 FROM `sky_phone_picstagram_blocks` b
                WHERE (b.`blocker_id` = ? AND b.`blocked_id` = p.`id`)
                    OR (b.`blocker_id` = p.`id` AND b.`blocked_id` = ?))
        LIMIT 1
    ]], { viewer_id, profile_id, viewer_id, viewer_id })
    return rows[1] and hydrate_profile(rows[1], viewer_id) or nil
end

local function load_post_media(posts)
    if #posts == 0 then
        return posts
    end
    local placeholders = {}
    local values = {}
    local by_id = {}
    for index = 1, #posts do
        local post = posts[index]
        placeholders[index] = "?"
        values[index] = post.id
        post.media = {}
        by_id[post.id] = post
    end
    local rows = Bridge.Database.Query(([[
        SELECT pm.`post_id`, pm.`position`, m.`id`, m.`url`, m.`media_type`
        FROM `sky_phone_picstagram_post_media` pm
        JOIN `sky_phone_media` m ON m.`id` = pm.`media_id`
        WHERE pm.`post_id` IN (%s)
        ORDER BY pm.`post_id`, pm.`position`
    ]]):format(table.concat(placeholders, ", ")), values)
    for index = 1, #rows do
        local media = rows[index]
        local post = by_id[media.post_id]
        if post then
            post.media[#post.media + 1] = {
                id = tonumber(media.id),
                media_type = media.media_type,
                position = tonumber(media.position),
                url = media.url,
            }
        end
    end
    return posts
end

local function hydrate_posts(rows)
    for index = 1, #rows do
        local post = rows[index]
        post.comments_enabled = tonumber(post.comments_enabled) == 1
        post.is_owner = tonumber(post.is_owner) == 1
        post.is_liked = tonumber(post.is_liked) == 1
        post.is_saved = tonumber(post.is_saved) == 1
        post.verified = tonumber(post.verified) == 1
        post.private = tonumber(post.private) == 1
        post.like_count = tonumber(post.like_count) or 0
        post.comment_count = tonumber(post.comment_count) or 0
        post.created_at = (tonumber(post.created_at_unix) or 0) * 1000
        post.created_at_unix = nil
    end
    return load_post_media(rows)
end

local function parse_cursor(value)
    if value == nil or value == "" then
        return nil, nil
    end
    if type(value) ~= "string" or #value > 64 then
        return false, false
    end
    local timestamp, id = value:match("^(%d+):([%x%-]+)$")
    if not timestamp or not valid_id(id) then
        return false, false
    end
    return tonumber(timestamp), id
end

local function list_posts(viewer_id, where_clause, values, cursor_value)
    local cursor_time, cursor_id = parse_cursor(cursor_value)
    if cursor_time == false then
        return nil, "invalid_cursor"
    end
    local parameters = { viewer_id, viewer_id, viewer_id }
    for index = 1, #values do
        parameters[#parameters + 1] = values[index]
    end
    local cursor_clause = ""
    if cursor_time then
        cursor_clause = " AND (post.`created_at` < FROM_UNIXTIME(?) OR (post.`created_at` = FROM_UNIXTIME(?) AND post.`id` < ?))"
        parameters[#parameters + 1] = cursor_time
        parameters[#parameters + 1] = cursor_time
        parameters[#parameters + 1] = cursor_id
    end
    parameters[#parameters + 1] = viewer_id
    parameters[#parameters + 1] = viewer_id
    parameters[#parameters + 1] = Config.Picstagram.PageSize + 1
    local rows = hydrate_posts(Bridge.Database.Query(([[
        SELECT post.`id`, post.`profile_id`, post.`caption`, post.`location`, post.`comments_enabled`,
            UNIX_TIMESTAMP(post.`created_at`) AS `created_at_unix`, profile.`handle`, profile.`display_name`,
            profile.`verified`, profile.`private`, avatar.`url` AS `avatar_url`,
            (post.`profile_id` = ?) AS `is_owner`,
            EXISTS(SELECT 1 FROM `sky_phone_picstagram_reactions` reaction
                WHERE reaction.`post_id` = post.`id` AND reaction.`profile_id` = ? AND reaction.`kind` = 'like') AS `is_liked`,
            EXISTS(SELECT 1 FROM `sky_phone_picstagram_reactions` reaction
                WHERE reaction.`post_id` = post.`id` AND reaction.`profile_id` = ? AND reaction.`kind` = 'save') AS `is_saved`,
            (SELECT COUNT(*) FROM `sky_phone_picstagram_reactions` reaction
                WHERE reaction.`post_id` = post.`id` AND reaction.`kind` = 'like') AS `like_count`,
            (SELECT COUNT(*) FROM `sky_phone_picstagram_comments` comment
                WHERE comment.`post_id` = post.`id` AND comment.`status` = 'visible') AS `comment_count`
        FROM `sky_phone_picstagram_posts` post
        JOIN `sky_phone_picstagram_profiles` profile ON profile.`id` = post.`profile_id`
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = profile.`avatar_media_id`
        WHERE post.`status` = 'published' AND profile.`status` = 'active' AND %s%s
            AND NOT EXISTS(SELECT 1 FROM `sky_phone_picstagram_blocks` block
                WHERE (block.`blocker_id` = ? AND block.`blocked_id` = post.`profile_id`)
                    OR (block.`blocked_id` = ? AND block.`blocker_id` = post.`profile_id`))
        ORDER BY post.`created_at` DESC, post.`id` DESC
        LIMIT ?
    ]]):format(where_clause, cursor_clause), parameters))
    local has_more = #rows > Config.Picstagram.PageSize
    if has_more then
        rows[#rows] = nil
    end
    local last = rows[#rows]
    local next_cursor = last and ((math.floor(last.created_at / 1000)) .. ":" .. last.id) or nil
    return { items = rows, hasMore = has_more, nextCursor = next_cursor }
end

local function find_accessible_post(post_id, viewer_id)
    local rows = Bridge.Database.Query([[
        SELECT post.`id`, post.`profile_id`, post.`comments_enabled`, profile.`account_id`
        FROM `sky_phone_picstagram_posts` post
        JOIN `sky_phone_picstagram_profiles` profile ON profile.`id` = post.`profile_id`
        WHERE post.`id` = ? AND post.`status` = 'published' AND profile.`status` = 'active'
            AND (profile.`private` = 0 OR post.`profile_id` = ? OR EXISTS(
                SELECT 1 FROM `sky_phone_picstagram_follows` follow
                WHERE follow.`follower_id` = ? AND follow.`following_id` = post.`profile_id`
                    AND follow.`status` = 'accepted'))
            AND NOT EXISTS(SELECT 1 FROM `sky_phone_picstagram_blocks` block
                WHERE (block.`blocker_id` = ? AND block.`blocked_id` = post.`profile_id`)
                    OR (block.`blocked_id` = ? AND block.`blocker_id` = post.`profile_id`))
        LIMIT 1
    ]], { post_id, viewer_id, viewer_id, viewer_id, viewer_id })
    return rows[1]
end

local function create_activity(recipient_id, actor_id, kind, post_id)
    if recipient_id == actor_id then
        return
    end
    local id = new_id()
    if post_id then
        Bridge.Database.Query([[
            INSERT INTO `sky_phone_picstagram_activities`
                (`id`, `recipient_id`, `actor_id`, `post_id`, `kind`)
            VALUES (?, ?, ?, ?, ?)
        ]], { id, recipient_id, actor_id, post_id, kind })
    else
        Bridge.Database.Query([[
            INSERT INTO `sky_phone_picstagram_activities`
                (`id`, `recipient_id`, `actor_id`, `kind`)
            VALUES (?, ?, ?, ?)
        ]], { id, recipient_id, actor_id, kind })
    end
    local rows = Bridge.Database.Query([[
        SELECT recipient.`account_id`, actor.`display_name` AS `actor_name`
        FROM `sky_phone_picstagram_profiles` recipient
        JOIN `sky_phone_picstagram_profiles` actor ON actor.`id` = ?
        WHERE recipient.`id` = ? LIMIT 1
    ]], { actor_id, recipient_id })
    if not rows[1] then
        error("[sky_phone] Picstagram activity references a missing profile.")
    end
    SkyPhone.NotifyAccountDevices(tonumber(rows[1].account_id), "sky_phone:picstagram:new", {
        actor = rows[1].actor_name,
        kind = kind,
        postId = post_id,
    })
end

local function is_admin(source)
    return Bridge.Framework.HasAdminGroup(source, Config.Picstagram.AdminGroups)
end

Bridge.Callbacks.Register("sky_phone:picstagram:register", function(source, data)
    if not SkyPhone.AllowOperation(source, "picstagram:register", 5, 60) then
        return { success = false, error = "rate_limited" }
    end
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then
        return error_response
    end
    if type(data) ~= "table" then
        return { success = false, error = "invalid_request" }
    end
    local handle = normalize_handle(data.handle)
    local display_name = trim(data.displayName)
    if not handle then
        return { success = false, error = "invalid_handle" }
    end
    if not valid_text(display_name, 1, 40) then
        return { success = false, error = "invalid_display_name" }
    end
    if not valid_password(data.password) then
        return { success = false, error = "invalid_password" }
    end
    if Bridge.Database.Query(
        "SELECT `id` FROM `sky_phone_picstagram_profiles` WHERE `account_id` = ? LIMIT 1",
        { account.id }
    )[1] then
        return { success = false, error = "already_registered" }
    end
    if Bridge.Database.Query(
        "SELECT `id` FROM `sky_phone_picstagram_profiles` WHERE `handle` = ? LIMIT 1",
        { handle }
    )[1] then
        return { success = false, error = "handle_taken" }
    end
    local entropy = Bridge.Database.Query("SELECT UUID() AS `id`, REPLACE(UUID(), '-', '') AS `salt`", {})[1]
    if not entropy or not valid_id(entropy.id) or type(entropy.salt) ~= "string" then
        error("[sky_phone] Database did not generate Picstagram registration entropy.")
    end
    if not Bridge.Database.Transaction({
        {
            query = [[INSERT INTO `sky_phone_picstagram_profiles`
                (`id`, `account_id`, `handle`, `display_name`) VALUES (?, ?, ?, ?)]],
            params = { entropy.id, account.id, handle, display_name },
        },
        {
            query = [[INSERT INTO `sky_phone_picstagram_credentials`
                (`profile_id`, `password_hash`, `password_salt`)
                VALUES (?, UNHEX(SHA2(CONCAT(?, ?, ?), 256)), ?)]],
            params = { entropy.id, password_pepper, entropy.salt, data.password, entropy.salt },
        },
        {
            query = [[INSERT INTO `sky_phone_picstagram_sessions` (`device_imei`, `profile_id`)
                VALUES (?, ?) ON DUPLICATE KEY UPDATE `profile_id` = VALUES(`profile_id`), `updated_at` = CURRENT_TIMESTAMP]],
            params = { account.imei, entropy.id },
        },
    }) then
        return { success = false, error = "request_failed" }
    end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:login", function(source, data)
    if not SkyPhone.AllowOperation(source, "picstagram:login", 10, 60) then
        return { success = false, error = "rate_limited" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end
    if type(data) ~= "table" then
        return { success = false, error = "invalid_credentials" }
    end
    local handle = normalize_handle(data.handle)
    if not handle or not valid_password(data.password) then
        return { success = false, error = "invalid_credentials" }
    end
    local profiles = Bridge.Database.Query([[
        SELECT profile.`id` FROM `sky_phone_picstagram_profiles` profile
        JOIN `sky_phone_picstagram_credentials` credentials ON credentials.`profile_id` = profile.`id`
        WHERE profile.`handle` = ? AND profile.`status` = 'active'
            AND credentials.`password_hash` = UNHEX(SHA2(CONCAT(?, credentials.`password_salt`, ?), 256))
        LIMIT 1
    ]], { handle, password_pepper, data.password })
    if not profiles[1] then
        return { success = false, error = "invalid_credentials" }
    end
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_picstagram_sessions` (`device_imei`, `profile_id`)
        VALUES (?, ?) ON DUPLICATE KEY UPDATE `profile_id` = VALUES(`profile_id`), `updated_at` = CURRENT_TIMESTAMP
    ]], { session.imei, profiles[1].id })
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:logout", function(source)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end
    Bridge.Database.Query("DELETE FROM `sky_phone_picstagram_sessions` WHERE `device_imei` = ?", { session.imei })
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:bootstrap", function(source)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end
    local profile = profile_for_session(source)
    if not profile then
        return { success = true, data = { authenticated = false, isAdmin = is_admin(source) } }
    end
    local hydrated = load_profile(profile.id, profile.id)
    if not hydrated then
        return { success = false, error = "profile_unavailable" }
    end
    local feed, feed_error = list_posts(
        profile.id,
        [[post.`profile_id` = ? OR EXISTS(SELECT 1 FROM `sky_phone_picstagram_follows` follow
            WHERE follow.`follower_id` = ? AND follow.`following_id` = post.`profile_id`
                AND follow.`status` = 'accepted')]],
        { profile.id, profile.id },
        nil
    )
    if not feed then
        return { success = false, error = feed_error }
    end
    return {
        success = true,
        data = {
            authenticated = true,
            feed = feed,
            isAdmin = is_admin(source),
            profile = hydrated,
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:feed", function(source, data)
    local profile, error_response = profile_for_session(source)
    if not profile then
        return error_response
    end
    data = type(data) == "table" and data or {}
    local result, list_error = list_posts(
        profile.id,
        [[post.`profile_id` = ? OR EXISTS(SELECT 1 FROM `sky_phone_picstagram_follows` follow
            WHERE follow.`follower_id` = ? AND follow.`following_id` = post.`profile_id`
                AND follow.`status` = 'accepted')]],
        { profile.id, profile.id },
        data.cursor
    )
    return result and { success = true, data = result } or { success = false, error = list_error }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:post", function(source, data)
    local profile, error_response = profile_for_session(source)
    if not profile then
        return error_response
    end
    if not SkyPhone.AllowOperation(source, "picstagram:post", 60, 60) then
        return { success = false, error = "rate_limited" }
    end
    local post_id = type(data) == "table" and data.id or nil
    if not valid_id(post_id) then
        return { success = false, error = "post_not_found" }
    end
    local result, list_error = list_posts(
        profile.id,
        [[post.`id` = ? AND (profile.`private` = 0 OR post.`profile_id` = ? OR EXISTS(
            SELECT 1 FROM `sky_phone_picstagram_follows` follow
            WHERE follow.`follower_id` = ? AND follow.`following_id` = post.`profile_id`
                AND follow.`status` = 'accepted'))]],
        { post_id, profile.id, profile.id },
        nil
    )
    if not result then
        return { success = false, error = list_error }
    end
    return result.items[1]
        and { success = true, data = result.items[1] }
        or { success = false, error = "post_not_found" }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:explore", function(source, data)
    local profile, error_response = profile_for_session(source)
    if not profile then
        return error_response
    end
    data = type(data) == "table" and data or {}
    local result, list_error = list_posts(profile.id, "profile.`private` = 0", {}, data.cursor)
    return result and { success = true, data = result } or { success = false, error = list_error }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:search", function(source, data)
    if not SkyPhone.AllowOperation(source, "picstagram:search", 40, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = profile_for_session(source)
    if not profile then
        return error_response
    end
    local search = trim(type(data) == "table" and data.search or nil)
    if not search or not valid_text(search, 1, 80) then
        return { success = false, error = "invalid_search" }
    end
    local pattern = "%" .. search:lower():gsub("^[@#]", "") .. "%"
    local profiles = Bridge.Database.Query([[
        SELECT candidate.`id`, candidate.`handle`, candidate.`display_name`, candidate.`bio`, candidate.`avatar_media_id`, candidate.`private`, candidate.`status`,
            candidate.`verified`, avatar.`url` AS `avatar_url`,
            COALESCE((SELECT f.`status` FROM `sky_phone_picstagram_follows` f
                WHERE f.`follower_id` = ? AND f.`following_id` = candidate.`id` LIMIT 1), '') AS `follow_status`,
            (SELECT COUNT(*) FROM `sky_phone_picstagram_follows` f
                WHERE f.`following_id` = candidate.`id` AND f.`status` = 'accepted') AS `followers`,
            (SELECT COUNT(*) FROM `sky_phone_picstagram_follows` f
                WHERE f.`follower_id` = candidate.`id` AND f.`status` = 'accepted') AS `following`,
            (SELECT COUNT(*) FROM `sky_phone_picstagram_posts` post
                WHERE post.`profile_id` = candidate.`id` AND post.`status` = 'published') AS `post_count`
        FROM `sky_phone_picstagram_profiles` candidate
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = candidate.`avatar_media_id`
        WHERE candidate.`status` = 'active'
            AND (LOWER(candidate.`handle`) LIKE ? OR LOWER(candidate.`display_name`) LIKE ?)
            AND NOT EXISTS(SELECT 1 FROM `sky_phone_picstagram_blocks` block
                WHERE (block.`blocker_id` = ? AND block.`blocked_id` = candidate.`id`)
                    OR (block.`blocked_id` = ? AND block.`blocker_id` = candidate.`id`))
        ORDER BY candidate.`verified` DESC, candidate.`handle` LIMIT 20
    ]], { profile.id, pattern, pattern, profile.id, profile.id })
    for index = 1, #profiles do
        hydrate_profile(profiles[index], profile.id)
    end
    local posts = list_posts(
        profile.id,
        "profile.`private` = 0 AND (LOWER(post.`caption`) LIKE ? OR LOWER(post.`location`) LIKE ?)",
        { pattern, pattern },
        nil
    )
    return { success = true, data = { profiles = profiles, posts = posts and posts.items or {} } }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:saved", function(source, data)
    local profile, error_response = profile_for_session(source)
    if not profile then
        return error_response
    end
    data = type(data) == "table" and data or {}
    local result, list_error = list_posts(
        profile.id,
        [[EXISTS(SELECT 1 FROM `sky_phone_picstagram_reactions` saved
            WHERE saved.`post_id` = post.`id` AND saved.`profile_id` = ? AND saved.`kind` = 'save')]],
        { profile.id },
        data.cursor
    )
    return result and { success = true, data = result } or { success = false, error = list_error }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:profile", function(source, data)
    local viewer, error_response = profile_for_session(source)
    if not viewer then
        return error_response
    end
    data = type(data) == "table" and data or {}
    local target_id = valid_id(data.profileId) and data.profileId or nil
    if not target_id and type(data.handle) == "string" then
        local handle = normalize_handle(data.handle)
        local rows = handle and Bridge.Database.Query(
            "SELECT `id` FROM `sky_phone_picstagram_profiles` WHERE `handle` = ? LIMIT 1",
            { handle }
        ) or {}
        target_id = rows[1] and rows[1].id or nil
    end
    if not target_id then
        return { success = false, error = "profile_not_found" }
    end
    local target = load_profile(target_id, viewer.id)
    if not target then
        return { success = false, error = "profile_not_found" }
    end
    local posts = { items = {}, hasMore = false, nextCursor = nil }
    if not target.locked then
        local list_error
        posts, list_error = list_posts(viewer.id, "post.`profile_id` = ?", { target.id }, data.cursor)
        if not posts then
            return { success = false, error = list_error }
        end
    end
    return { success = true, data = { profile = target, posts = posts } }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:connections", function(source, data)
    local viewer, error_response = profile_for_session(source)
    if not viewer then
        return error_response
    end
    local target_id = type(data) == "table" and data.profileId or nil
    local mode = type(data) == "table" and data.mode or nil
    if not valid_id(target_id) or (mode ~= "followers" and mode ~= "following") then
        return { success = false, error = "invalid_request" }
    end
    if target_id ~= viewer.id and are_profiles_blocked(viewer.id, target_id) then
        return { success = false, error = "profile_not_found" }
    end
    local join_column = mode == "followers" and "follow.`follower_id`" or "follow.`following_id`"
    local filter_column = mode == "followers" and "follow.`following_id`" or "follow.`follower_id`"
    local rows = Bridge.Database.Query(([[
        SELECT candidate.`id`, candidate.`handle`, candidate.`display_name`, candidate.`bio`,
            candidate.`avatar_media_id`, candidate.`private`, candidate.`verified`, candidate.`status`,
            avatar.`url` AS `avatar_url`,
            COALESCE((SELECT own_follow.`status` FROM `sky_phone_picstagram_follows` own_follow
                WHERE own_follow.`follower_id` = ? AND own_follow.`following_id` = candidate.`id` LIMIT 1), '') AS `follow_status`,
            (SELECT COUNT(*) FROM `sky_phone_picstagram_follows` followers
                WHERE followers.`following_id` = candidate.`id` AND followers.`status` = 'accepted') AS `followers`,
            (SELECT COUNT(*) FROM `sky_phone_picstagram_follows` following
                WHERE following.`follower_id` = candidate.`id` AND following.`status` = 'accepted') AS `following`,
            (SELECT COUNT(*) FROM `sky_phone_picstagram_posts` post
                WHERE post.`profile_id` = candidate.`id` AND post.`status` = 'published') AS `post_count`
        FROM `sky_phone_picstagram_follows` follow
        JOIN `sky_phone_picstagram_profiles` candidate ON candidate.`id` = %s
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = candidate.`avatar_media_id`
        WHERE %s = ? AND follow.`status` = 'accepted' AND candidate.`status` = 'active'
            AND NOT EXISTS(SELECT 1 FROM `sky_phone_picstagram_blocks` block
                WHERE (block.`blocker_id` = ? AND block.`blocked_id` = candidate.`id`)
                    OR (block.`blocked_id` = ? AND block.`blocker_id` = candidate.`id`))
        ORDER BY candidate.`display_name`, candidate.`handle` LIMIT 200
    ]]):format(join_column, filter_column), { viewer.id, target_id, viewer.id, viewer.id })
    for index = 1, #rows do
        hydrate_profile(rows[index], viewer.id)
    end
    return { success = true, data = rows }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:update-profile", function(source, data)
    local profile, error_response = profile_for_session(source)
    if not profile then
        return error_response
    end
    if type(data) ~= "table" or type(data.private) ~= "boolean" then
        return { success = false, error = "invalid_profile" }
    end
    local handle = normalize_handle(data.handle)
    local display_name = trim(data.displayName)
    local bio = trim(data.bio) or ""
    if not handle or not valid_text(display_name, 1, 40) or not valid_text(bio, 0, Config.Picstagram.BioMaxLength) then
        return { success = false, error = "invalid_profile" }
    end
    local avatar_media_id = tonumber(data.avatarMediaId) or 0
    if avatar_media_id ~= math.floor(avatar_media_id) or avatar_media_id < 0 then
        return { success = false, error = "invalid_media" }
    end
    if avatar_media_id > 0 and not SkyPhoneMedia.ResolveOwnedMedia(source, tostring(avatar_media_id), "photo") then
        return { success = false, error = "invalid_media" }
    end
    if Bridge.Database.Query(
        "SELECT `id` FROM `sky_phone_picstagram_profiles` WHERE `handle` = ? AND `id` <> ? LIMIT 1",
        { handle, profile.id }
    )[1] then
        return { success = false, error = "handle_taken" }
    end
    Bridge.Database.Query([[
        UPDATE `sky_phone_picstagram_profiles`
        SET `handle` = ?, `display_name` = ?, `bio` = ?, `private` = ?, `avatar_media_id` = NULLIF(?, 0)
        WHERE `id` = ?
    ]], { handle, display_name, bio, data.private and 1 or 0, avatar_media_id, profile.id })
    return { success = true, data = load_profile(profile.id, profile.id) }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:publish-post", function(source, data)
    if not SkyPhone.AllowOperation(source, "picstagram:publish", Config.Picstagram.PostsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = profile_for_session(source)
    if not profile then
        return error_response
    end
    if type(data) ~= "table" or type(data.mediaIds) ~= "table" or type(data.commentsEnabled) ~= "boolean"
        or (data.mediaType ~= "photo" and data.mediaType ~= "video")
    then
        return { success = false, error = "invalid_post" }
    end
    local caption = trim(data.caption) or ""
    local location = trim(data.location) or ""
    if not valid_text(caption, 0, Config.Picstagram.CaptionMaxLength)
        or not valid_text(location, 0, Config.Picstagram.LocationMaxLength)
        or #data.mediaIds < 1
        or #data.mediaIds > Config.Picstagram.MaxPostMedia
        or (data.mediaType == "video" and #data.mediaIds ~= 1)
    then
        return { success = false, error = "invalid_post" }
    end
    local media_ids = {}
    local seen = {}
    for index = 1, #data.mediaIds do
        local media_id = tonumber(data.mediaIds[index])
        if not media_id or media_id < 1 or media_id ~= math.floor(media_id) or seen[media_id] then
            return { success = false, error = "invalid_media" }
        end
        if not SkyPhoneMedia.ResolveOwnedMedia(source, tostring(media_id), data.mediaType) then
            return { success = false, error = "invalid_media" }
        end
        seen[media_id] = true
        media_ids[index] = media_id
    end
    local id = new_id()
    local statements = {
        {
            query = [[INSERT INTO `sky_phone_picstagram_posts`
                (`id`, `profile_id`, `caption`, `location`, `comments_enabled`)
                VALUES (?, ?, ?, ?, ?)]],
            params = { id, profile.id, caption, location, data.commentsEnabled == false and 0 or 1 },
        },
    }
    for index = 1, #media_ids do
        statements[#statements + 1] = {
            query = [[INSERT INTO `sky_phone_picstagram_post_media`
                (`post_id`, `media_id`, `position`) VALUES (?, ?, ?)]],
            params = { id, media_ids[index], index },
        }
    end
    if not Bridge.Database.Transaction(statements) then
        return { success = false, error = "request_failed" }
    end
    return { success = true, data = { id = id } }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:update-post", function(source, data)
    local profile, error_response = profile_for_session(source)
    if not profile then
        return error_response
    end
    if type(data) ~= "table" or not valid_id(data.id) or type(data.commentsEnabled) ~= "boolean" then
        return { success = false, error = "invalid_post" }
    end
    local caption = trim(data.caption) or ""
    local location = trim(data.location) or ""
    if not valid_text(caption, 0, Config.Picstagram.CaptionMaxLength)
        or not valid_text(location, 0, Config.Picstagram.LocationMaxLength)
    then
        return { success = false, error = "invalid_post" }
    end
    local result = Bridge.Database.Query([[
        UPDATE `sky_phone_picstagram_posts`
        SET `caption` = ?, `location` = ?, `comments_enabled` = ?
        WHERE `id` = ? AND `profile_id` = ? AND `status` IN ('published', 'archived')
    ]], { caption, location, data.commentsEnabled == false and 0 or 1, data.id, profile.id })
    return affected_rows(result) > 0
        and { success = true }
        or { success = false, error = "post_not_found" }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:set-post-status", function(source, data)
    local profile, error_response = profile_for_session(source)
    if not profile then
        return error_response
    end
    if type(data) ~= "table" or not valid_id(data.id) then
        return { success = false, error = "invalid_post" }
    end
    local target = data.status
    local current = Bridge.Database.Query(
        "SELECT `status` FROM `sky_phone_picstagram_posts` WHERE `id` = ? AND `profile_id` = ? LIMIT 1",
        { data.id, profile.id }
    )[1]
    if not current then
        return { success = false, error = "post_not_found" }
    end
    local allowed = (current.status == "published" and (target == "archived" or target == "removed"))
        or (current.status == "archived" and (target == "published" or target == "removed"))
    if not allowed then
        return { success = false, error = "invalid_status" }
    end
    Bridge.Database.Query(
        "UPDATE `sky_phone_picstagram_posts` SET `status` = ? WHERE `id` = ? AND `profile_id` = ?",
        { target, data.id, profile.id }
    )
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:react", function(source, data)
    if not SkyPhone.AllowOperation(source, "picstagram:react", 80, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = profile_for_session(source)
    if not profile then
        return error_response
    end
    if type(data) ~= "table"
        or not valid_id(data.id)
        or (data.kind ~= "like" and data.kind ~= "save")
        or type(data.active) ~= "boolean"
    then
        return { success = false, error = "invalid_request" }
    end
    local post = find_accessible_post(data.id, profile.id)
    if not post then
        return { success = false, error = "post_not_found" }
    end
    if data.active then
        local result = Bridge.Database.Query([[
            INSERT IGNORE INTO `sky_phone_picstagram_reactions` (`post_id`, `profile_id`, `kind`)
            VALUES (?, ?, ?)
        ]], { data.id, profile.id, data.kind })
        if data.kind == "like" and affected_rows(result) > 0 then
            create_activity(post.profile_id, profile.id, "like", data.id)
        end
    else
        Bridge.Database.Query([[
            DELETE FROM `sky_phone_picstagram_reactions`
            WHERE `post_id` = ? AND `profile_id` = ? AND `kind` = ?
        ]], { data.id, profile.id, data.kind })
    end
    return { success = true, data = { active = data.active == true } }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:follow", function(source, data)
    if not SkyPhone.AllowOperation(source, "picstagram:follow", 40, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = profile_for_session(source)
    if not profile then
        return error_response
    end
    if type(data) ~= "table"
        or not valid_id(data.profileId)
        or data.profileId == profile.id
        or type(data.active) ~= "boolean"
    then
        return { success = false, error = "invalid_profile" }
    end
    if are_profiles_blocked(profile.id, data.profileId) then
        return { success = false, error = "blocked" }
    end
    local target = Bridge.Database.Query([[
        SELECT `id`, `private` FROM `sky_phone_picstagram_profiles`
        WHERE `id` = ? AND `status` = 'active' LIMIT 1
    ]], { data.profileId })[1]
    if not target then
        return { success = false, error = "profile_not_found" }
    end
    if not data.active then
        Bridge.Database.Query(
            "DELETE FROM `sky_phone_picstagram_follows` WHERE `follower_id` = ? AND `following_id` = ?",
            { profile.id, target.id }
        )
        return { success = true, data = { status = false } }
    end
    local status = tonumber(target.private) == 1 and "pending" or "accepted"
    local existing = Bridge.Database.Query([[
        SELECT `status` FROM `sky_phone_picstagram_follows`
        WHERE `follower_id` = ? AND `following_id` = ? LIMIT 1
    ]], { profile.id, target.id })[1]
    if not existing or existing.status ~= status then
        Bridge.Database.Query([[
            INSERT INTO `sky_phone_picstagram_follows` (`follower_id`, `following_id`, `status`)
            VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `status` = VALUES(`status`), `updated_at` = CURRENT_TIMESTAMP
        ]], { profile.id, target.id, status })
        create_activity(target.id, profile.id, status == "pending" and "follow_request" or "follow", nil)
    end
    return { success = true, data = { status = status } }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:respond-follow", function(source, data)
    local profile, error_response = profile_for_session(source)
    if not profile then
        return error_response
    end
    if type(data) ~= "table" or not valid_id(data.profileId) or type(data.accept) ~= "boolean" then
        return { success = false, error = "invalid_profile" }
    end
    local request = Bridge.Database.Query([[
        SELECT `id` FROM `sky_phone_picstagram_follows`
        WHERE `follower_id` = ? AND `following_id` = ? AND `status` = 'pending' LIMIT 1
    ]], { data.profileId, profile.id })[1]
    if not request then
        return { success = false, error = "request_not_found" }
    end
    if data.accept then
        Bridge.Database.Query(
            "UPDATE `sky_phone_picstagram_follows` SET `status` = 'accepted' WHERE `id` = ?",
            { request.id }
        )
        create_activity(data.profileId, profile.id, "request_accepted", nil)
    else
        Bridge.Database.Query("DELETE FROM `sky_phone_picstagram_follows` WHERE `id` = ?", { request.id })
    end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:comments", function(source, data)
    local profile, error_response = profile_for_session(source)
    if not profile then
        return error_response
    end
    if type(data) ~= "table" or not valid_id(data.id) or not find_accessible_post(data.id, profile.id) then
        return { success = false, error = "post_not_found" }
    end
    local rows = Bridge.Database.Query([[
        SELECT comment.`id`, comment.`profile_id`, comment.`parent_id`, comment.`body`,
            UNIX_TIMESTAMP(comment.`created_at`) AS `created_at_unix`, author.`handle`,
            author.`display_name`, author.`verified`, avatar.`url` AS `avatar_url`,
            parent_author.`handle` AS `reply_to_handle`,
            (comment.`profile_id` = ?) AS `is_owner`,
            EXISTS(SELECT 1 FROM `sky_phone_picstagram_comment_reactions` reaction
                WHERE reaction.`comment_id` = comment.`id` AND reaction.`profile_id` = ?) AS `is_liked`,
            (SELECT COUNT(*) FROM `sky_phone_picstagram_comment_reactions` reaction
                WHERE reaction.`comment_id` = comment.`id`) AS `like_count`
        FROM `sky_phone_picstagram_comments` comment
        JOIN `sky_phone_picstagram_profiles` author ON author.`id` = comment.`profile_id`
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = author.`avatar_media_id`
        LEFT JOIN `sky_phone_picstagram_comments` parent ON parent.`id` = comment.`parent_id`
        LEFT JOIN `sky_phone_picstagram_profiles` parent_author ON parent_author.`id` = parent.`profile_id`
        WHERE comment.`post_id` = ? AND comment.`status` = 'visible' AND author.`status` = 'active'
            AND NOT EXISTS(SELECT 1 FROM `sky_phone_picstagram_blocks` block
                WHERE (block.`blocker_id` = ? AND block.`blocked_id` = comment.`profile_id`)
                    OR (block.`blocked_id` = ? AND block.`blocker_id` = comment.`profile_id`))
        ORDER BY COALESCE(parent.`created_at`, comment.`created_at`),
            comment.`parent_id` IS NOT NULL, comment.`created_at`, comment.`id` LIMIT ?
    ]], { profile.id, profile.id, data.id, profile.id, profile.id, Config.Picstagram.CommentPageSize })
    for index = 1, #rows do
        rows[index].verified = tonumber(rows[index].verified) == 1
        rows[index].is_owner = tonumber(rows[index].is_owner) == 1
        rows[index].is_liked = tonumber(rows[index].is_liked) == 1
        rows[index].like_count = tonumber(rows[index].like_count) or 0
        rows[index].created_at = (tonumber(rows[index].created_at_unix) or 0) * 1000
        rows[index].created_at_unix = nil
    end
    return { success = true, data = rows }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:comment-react", function(source, data)
    local profile, error_response = profile_for_session(source)
    if not profile then
        return error_response
    end
    if not SkyPhone.AllowOperation(source, "picstagram:comment-react", 60, 60) then
        return { success = false, error = "rate_limited" }
    end
    local comment_id = type(data) == "table" and data.id or nil
    if not valid_id(comment_id) or type(data.active) ~= "boolean" then
        return { success = false, error = "invalid_request" }
    end
    local comment = Bridge.Database.Query([[
        SELECT comment.`profile_id`, comment.`post_id`
        FROM `sky_phone_picstagram_comments` comment
        WHERE comment.`id` = ? AND comment.`status` = 'visible' LIMIT 1
    ]], { comment_id })[1]
    if not comment or not find_accessible_post(comment.post_id, profile.id) then
        return { success = false, error = "invalid_comment" }
    end
    if are_profiles_blocked(profile.id, comment.profile_id) then
        return { success = false, error = "blocked" }
    end
    if data.active then
        local result = Bridge.Database.Query([[
            INSERT IGNORE INTO `sky_phone_picstagram_comment_reactions` (`comment_id`, `profile_id`)
            VALUES (?, ?)
        ]], { comment_id, profile.id })
        if affected_rows(result) > 0 then
            create_activity(comment.profile_id, profile.id, "comment_like", comment.post_id)
        end
    else
        Bridge.Database.Query([[
            DELETE FROM `sky_phone_picstagram_comment_reactions`
            WHERE `comment_id` = ? AND `profile_id` = ?
        ]], { comment_id, profile.id })
    end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:comment", function(source, data)
    if not SkyPhone.AllowOperation(source, "picstagram:comment", Config.Picstagram.CommentsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = profile_for_session(source)
    if not profile then
        return error_response
    end
    if type(data) ~= "table" or not valid_id(data.id) then
        return { success = false, error = "invalid_comment" }
    end
    local body = trim(data.body)
    if not valid_text(body, 1, Config.Picstagram.CommentMaxLength) then
        return { success = false, error = "invalid_comment" }
    end
    local post = find_accessible_post(data.id, profile.id)
    if not post then
        return { success = false, error = "post_not_found" }
    end
    if tonumber(post.comments_enabled) ~= 1 then
        return { success = false, error = "comments_disabled" }
    end
    if data.replyToId ~= nil and not valid_id(data.replyToId) then
        return { success = false, error = "invalid_comment" }
    end
    local parent_id
    local reply_target
    if data.replyToId then
        reply_target = Bridge.Database.Query([[
            SELECT `id`, `profile_id`, `parent_id` FROM `sky_phone_picstagram_comments`
            WHERE `id` = ? AND `post_id` = ? AND `status` = 'visible' LIMIT 1
        ]], { data.replyToId, data.id })[1]
        if not reply_target or are_profiles_blocked(profile.id, reply_target.profile_id) then
            return { success = false, error = "invalid_comment" }
        end
        parent_id = reply_target.parent_id or reply_target.id
    elseif data.parentId then
        if not valid_id(data.parentId) then
            return { success = false, error = "invalid_comment" }
        end
        reply_target = Bridge.Database.Query([[
            SELECT `id`, `profile_id`, `parent_id` FROM `sky_phone_picstagram_comments`
            WHERE `id` = ? AND `post_id` = ? AND `parent_id` IS NULL AND `status` = 'visible' LIMIT 1
        ]], { data.parentId, data.id })[1]
        if not reply_target or are_profiles_blocked(profile.id, reply_target.profile_id) then
            return { success = false, error = "invalid_comment" }
        end
        parent_id = reply_target.id
    end
    local id = new_id()
    if parent_id then
        Bridge.Database.Query([[
            INSERT INTO `sky_phone_picstagram_comments` (`id`, `post_id`, `profile_id`, `parent_id`, `body`)
            VALUES (?, ?, ?, ?, ?)
        ]], { id, data.id, profile.id, parent_id, body })
    else
        Bridge.Database.Query([[
            INSERT INTO `sky_phone_picstagram_comments` (`id`, `post_id`, `profile_id`, `body`)
            VALUES (?, ?, ?, ?)
        ]], { id, data.id, profile.id, body })
    end
    if reply_target then
        create_activity(reply_target.profile_id, profile.id, "reply", data.id)
    end
    if not reply_target or reply_target.profile_id ~= post.profile_id then
        create_activity(post.profile_id, profile.id, "comment", data.id)
    end
    return { success = true, data = { id = id } }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:remove-comment", function(source, data)
    local profile, error_response = profile_for_session(source)
    if not profile then
        return error_response
    end
    if type(data) ~= "table" or not valid_id(data.id) then
        return { success = false, error = "invalid_comment" }
    end
    local rows = Bridge.Database.Query([[
        SELECT comment.`profile_id`, post.`profile_id` AS `post_owner_id`
        FROM `sky_phone_picstagram_comments` comment
        JOIN `sky_phone_picstagram_posts` post ON post.`id` = comment.`post_id`
        WHERE comment.`id` = ? AND comment.`status` = 'visible' LIMIT 1
    ]], { data.id })
    local comment = rows[1]
    if not comment or (comment.profile_id ~= profile.id and comment.post_owner_id ~= profile.id) then
        return { success = false, error = "not_authorized" }
    end
    Bridge.Database.Query(
        "UPDATE `sky_phone_picstagram_comments` SET `status` = 'removed' WHERE `id` = ?",
        { data.id }
    )
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:publish-story", function(source, data)
    if not SkyPhone.AllowOperation(source, "picstagram:story", Config.Picstagram.StoriesPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = profile_for_session(source)
    if not profile then
        return error_response
    end
    if type(data) ~= "table" or (data.mediaType ~= "photo" and data.mediaType ~= "video") then
        return { success = false, error = "invalid_story" }
    end
    local media_id = tonumber(data.mediaId)
    local body = trim(data.body) or ""
    if not media_id or media_id < 1 or media_id ~= math.floor(media_id)
        or not valid_text(body, 0, Config.Picstagram.StoryTextMaxLength)
        or not SkyPhoneMedia.ResolveOwnedMedia(source, tostring(media_id), data.mediaType)
    then
        return { success = false, error = "invalid_story" }
    end
    local id = new_id()
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_picstagram_stories`
            (`id`, `profile_id`, `media_id`, `body`, `expires_at`)
        VALUES (?, ?, ?, ?, FROM_UNIXTIME(?))
    ]], { id, profile.id, media_id, body, os.time() + Config.Picstagram.StoryLifetimeSeconds })
    return { success = true, data = { id = id } }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:stories", function(source)
    local profile, error_response = profile_for_session(source)
    if not profile then
        return error_response
    end
    local rows = Bridge.Database.Query([[
        SELECT story.`id`, story.`profile_id`, story.`body`, media.`url`, media.`media_type`, author.`handle`,
            author.`display_name`, author.`verified`, avatar.`url` AS `avatar_url`,
            UNIX_TIMESTAMP(story.`created_at`) AS `created_at_unix`,
            UNIX_TIMESTAMP(story.`expires_at`) AS `expires_at_unix`,
            EXISTS(SELECT 1 FROM `sky_phone_picstagram_story_views` view
                WHERE view.`story_id` = story.`id` AND view.`profile_id` = ?) AS `seen`,
            (story.`profile_id` = ?) AS `is_owner`,
            (SELECT COUNT(*) FROM `sky_phone_picstagram_story_views` view
                WHERE view.`story_id` = story.`id`) AS `view_count`
        FROM `sky_phone_picstagram_stories` story
        JOIN `sky_phone_picstagram_profiles` author ON author.`id` = story.`profile_id`
        JOIN `sky_phone_media` media ON media.`id` = story.`media_id`
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = author.`avatar_media_id`
        WHERE story.`status` = 'active' AND story.`expires_at` > CURRENT_TIMESTAMP
            AND author.`status` = 'active'
            AND (story.`profile_id` = ? OR EXISTS(SELECT 1 FROM `sky_phone_picstagram_follows` follow
                WHERE follow.`follower_id` = ? AND follow.`following_id` = story.`profile_id`
                    AND follow.`status` = 'accepted'))
            AND NOT EXISTS(SELECT 1 FROM `sky_phone_picstagram_blocks` block
                WHERE (block.`blocker_id` = ? AND block.`blocked_id` = story.`profile_id`)
                    OR (block.`blocked_id` = ? AND block.`blocker_id` = story.`profile_id`))
        ORDER BY story.`profile_id` = ? DESC, story.`created_at`
    ]], { profile.id, profile.id, profile.id, profile.id, profile.id, profile.id, profile.id })
    for index = 1, #rows do
        local story = rows[index]
        story.verified = tonumber(story.verified) == 1
        story.seen = tonumber(story.seen) == 1
        story.is_owner = tonumber(story.is_owner) == 1
        story.view_count = tonumber(story.view_count) or 0
        story.created_at = (tonumber(story.created_at_unix) or 0) * 1000
        story.expires_at = (tonumber(story.expires_at_unix) or 0) * 1000
        story.created_at_unix = nil
        story.expires_at_unix = nil
    end
    return { success = true, data = rows }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:view-story", function(source, data)
    if not SkyPhone.AllowOperation(source, "picstagram:story-view", 120, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = profile_for_session(source)
    if not profile then
        return error_response
    end
    if type(data) ~= "table" or not valid_id(data.id) then
        return { success = false, error = "story_not_found" }
    end
    local story = Bridge.Database.Query([[
        SELECT story.`id`, story.`profile_id` FROM `sky_phone_picstagram_stories` story
        JOIN `sky_phone_picstagram_profiles` author ON author.`id` = story.`profile_id`
        WHERE story.`id` = ? AND story.`status` = 'active' AND story.`expires_at` > CURRENT_TIMESTAMP
            AND author.`status` = 'active'
            AND (author.`private` = 0 OR story.`profile_id` = ? OR EXISTS(
                SELECT 1 FROM `sky_phone_picstagram_follows` follow
                WHERE follow.`follower_id` = ? AND follow.`following_id` = story.`profile_id`
                    AND follow.`status` = 'accepted'))
        LIMIT 1
    ]], { data.id, profile.id, profile.id })[1]
    if not story or are_profiles_blocked(profile.id, story.profile_id) then
        return { success = false, error = "story_not_found" }
    end
    if story.profile_id ~= profile.id then
        Bridge.Database.Query([[
            INSERT IGNORE INTO `sky_phone_picstagram_story_views` (`story_id`, `profile_id`)
            VALUES (?, ?)
        ]], { story.id, profile.id })
    end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:story-viewers", function(source, data)
    local profile, error_response = profile_for_session(source)
    if not profile then
        return error_response
    end
    if type(data) ~= "table" or not valid_id(data.id) then
        return { success = false, error = "story_not_found" }
    end
    if not Bridge.Database.Query(
        "SELECT `id` FROM `sky_phone_picstagram_stories` WHERE `id` = ? AND `profile_id` = ? LIMIT 1",
        { data.id, profile.id }
    )[1] then
        return { success = false, error = "story_not_found" }
    end
    local rows = Bridge.Database.Query([[
        SELECT viewer.`id`, viewer.`handle`, viewer.`display_name`, viewer.`verified`,
            avatar.`url` AS `avatar_url`, UNIX_TIMESTAMP(viewed.`created_at`) AS `created_at_unix`
        FROM `sky_phone_picstagram_story_views` viewed
        JOIN `sky_phone_picstagram_profiles` viewer ON viewer.`id` = viewed.`profile_id`
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = viewer.`avatar_media_id`
        WHERE viewed.`story_id` = ? ORDER BY viewed.`created_at` DESC
    ]], { data.id })
    for index = 1, #rows do
        rows[index].verified = tonumber(rows[index].verified) == 1
        rows[index].created_at = (tonumber(rows[index].created_at_unix) or 0) * 1000
        rows[index].created_at_unix = nil
    end
    return { success = true, data = rows }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:remove-story", function(source, data)
    local profile, error_response = profile_for_session(source)
    if not profile then
        return error_response
    end
    if type(data) ~= "table" or not valid_id(data.id) then
        return { success = false, error = "story_not_found" }
    end
    local result = Bridge.Database.Query([[
        UPDATE `sky_phone_picstagram_stories` SET `status` = 'removed'
        WHERE `id` = ? AND `profile_id` = ? AND `status` = 'active'
    ]], { data.id, profile.id })
    return affected_rows(result) > 0
        and { success = true }
        or { success = false, error = "story_not_found" }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:activities", function(source)
    local profile, error_response = profile_for_session(source)
    if not profile then
        return error_response
    end
    local rows = Bridge.Database.Query([[
        SELECT activity.`id`, activity.`kind`, activity.`post_id`, activity.`read_at`,
            UNIX_TIMESTAMP(activity.`created_at`) AS `created_at_unix`, actor.`id` AS `profile_id`,
            actor.`handle`, actor.`display_name`, actor.`verified`, avatar.`url` AS `avatar_url`,
            cover.`url` AS `post_url`
        FROM `sky_phone_picstagram_activities` activity
        JOIN `sky_phone_picstagram_profiles` actor ON actor.`id` = activity.`actor_id`
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = actor.`avatar_media_id`
        LEFT JOIN `sky_phone_picstagram_post_media` post_media
            ON post_media.`post_id` = activity.`post_id` AND post_media.`position` = 1
        LEFT JOIN `sky_phone_media` cover ON cover.`id` = post_media.`media_id`
        WHERE activity.`recipient_id` = ?
            AND NOT EXISTS(SELECT 1 FROM `sky_phone_picstagram_blocks` block
                WHERE (block.`blocker_id` = ? AND block.`blocked_id` = activity.`actor_id`)
                    OR (block.`blocked_id` = ? AND block.`blocker_id` = activity.`actor_id`))
        ORDER BY activity.`created_at` DESC LIMIT 100
    ]], { profile.id, profile.id, profile.id })
    for index = 1, #rows do
        rows[index].verified = tonumber(rows[index].verified) == 1
        rows[index].created_at = (tonumber(rows[index].created_at_unix) or 0) * 1000
        rows[index].created_at_unix = nil
    end
    return { success = true, data = rows }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:mark-activities", function(source)
    local profile, error_response = profile_for_session(source)
    if not profile then
        return error_response
    end
    Bridge.Database.Query([[
        UPDATE `sky_phone_picstagram_activities` SET `read_at` = CURRENT_TIMESTAMP
        WHERE `recipient_id` = ? AND `read_at` IS NULL
    ]], { profile.id })
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:block", function(source, data)
    local profile, error_response = profile_for_session(source)
    if not profile then
        return error_response
    end
    if type(data) ~= "table"
        or not valid_id(data.profileId)
        or data.profileId == profile.id
        or type(data.active) ~= "boolean"
    then
        return { success = false, error = "invalid_profile" }
    end
    if not Bridge.Database.Query(
        "SELECT `id` FROM `sky_phone_picstagram_profiles` WHERE `id` = ? AND `status` = 'active' LIMIT 1",
        { data.profileId }
    )[1] then
        return { success = false, error = "profile_not_found" }
    end
    if data.active == false then
        Bridge.Database.Query(
            "DELETE FROM `sky_phone_picstagram_blocks` WHERE `blocker_id` = ? AND `blocked_id` = ?",
            { profile.id, data.profileId }
        )
        return { success = true }
    end
    if not Bridge.Database.Transaction({
        {
            query = [[INSERT IGNORE INTO `sky_phone_picstagram_blocks` (`blocker_id`, `blocked_id`)
                VALUES (?, ?)]],
            params = { profile.id, data.profileId },
        },
        {
            query = [[DELETE FROM `sky_phone_picstagram_follows`
                WHERE (`follower_id` = ? AND `following_id` = ?)
                    OR (`follower_id` = ? AND `following_id` = ?)]],
            params = { profile.id, data.profileId, data.profileId, profile.id },
        },
    }) then
        return { success = false, error = "request_failed" }
    end
    return { success = true }
end)

local function valid_report_target(target_type, target_id)
    if target_type == "profile" then
        return Bridge.Database.Query(
            "SELECT `id` FROM `sky_phone_picstagram_profiles` WHERE `id` = ? AND `status` = 'active' LIMIT 1",
            { target_id }
        )[1] ~= nil
    end
    local tables = {
        post = "sky_phone_picstagram_posts",
        story = "sky_phone_picstagram_stories",
        comment = "sky_phone_picstagram_comments",
    }
    local table_name = tables[target_type]
    if not table_name then
        return false
    end
    return Bridge.Database.Query(("SELECT `id` FROM `%s` WHERE `id` = ? LIMIT 1"):format(table_name), { target_id })[1] ~= nil
end

Bridge.Callbacks.Register("sky_phone:picstagram:report", function(source, data)
    if not SkyPhone.AllowOperation(source, "picstagram:report", 10, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = profile_for_session(source)
    if not profile then
        return error_response
    end
    if type(data) ~= "table" or not valid_id(data.targetId) or not report_reasons[data.reason] then
        return { success = false, error = "invalid_report" }
    end
    local details = trim(data.details) or ""
    if not valid_text(details, 0, Config.Picstagram.ReportDetailsMaxLength)
        or not valid_report_target(data.targetType, data.targetId)
    then
        return { success = false, error = "invalid_report" }
    end
    local result = Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_picstagram_reports`
            (`id`, `reporter_id`, `target_type`, `target_id`, `reason`, `details`)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { new_id(), profile.id, data.targetType, data.targetId, data.reason, details })
    return affected_rows(result) > 0
        and { success = true }
        or { success = false, error = "already_reported" }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:admin-reports", function(source)
    if not is_admin(source) then
        return { success = false, error = "not_authorized" }
    end
    local rows = Bridge.Database.Query([[
        SELECT report.`id`, report.`target_type`, report.`target_id`, report.`reason`, report.`details`,
            UNIX_TIMESTAMP(report.`created_at`) AS `created_at_unix`, reporter.`handle` AS `reporter_handle`,
            reporter.`display_name` AS `reporter_display_name`
        FROM `sky_phone_picstagram_reports` report
        JOIN `sky_phone_picstagram_profiles` reporter ON reporter.`id` = report.`reporter_id`
        WHERE report.`status` = 'open' ORDER BY report.`created_at` LIMIT 100
    ]], {})
    for index = 1, #rows do
        rows[index].created_at = (tonumber(rows[index].created_at_unix) or 0) * 1000
        rows[index].created_at_unix = nil
    end
    return { success = true, data = rows }
end)

Bridge.Callbacks.Register("sky_phone:picstagram:admin-resolve-report", function(source, data)
    if not is_admin(source) then
        return { success = false, error = "not_authorized" }
    end
    local allowed_actions = { dismiss = true, hide = true, remove = true, restore = true }
    if type(data) ~= "table" or not valid_id(data.id) or not allowed_actions[data.action] then
        return { success = false, error = "invalid_request" }
    end
    local report = Bridge.Database.Query([[
        SELECT * FROM `sky_phone_picstagram_reports` WHERE `id` = ? AND `status` = 'open' LIMIT 1
    ]], { data.id })[1]
    if not report then
        return { success = false, error = "report_not_found" }
    end
    local statements = {}
    if data.action ~= "dismiss" then
        local targets = {
            profile = { table = "sky_phone_picstagram_profiles", hidden = "hidden", removed = "removed", restored = "active" },
            post = { table = "sky_phone_picstagram_posts", hidden = "hidden", removed = "removed", restored = "published" },
            story = { table = "sky_phone_picstagram_stories", hidden = "removed", removed = "removed", restored = "active" },
            comment = { table = "sky_phone_picstagram_comments", hidden = "removed", removed = "removed", restored = "visible" },
        }
        local target = targets[report.target_type]
        if not target then
            return { success = false, error = "invalid_request" }
        end
        local status = data.action == "hide" and target.hidden
            or data.action == "remove" and target.removed
            or target.restored
        statements[#statements + 1] = {
            query = ("UPDATE `%s` SET `status` = ? WHERE `id` = ?"):format(target.table),
            params = { status, report.target_id },
        }
    end
    statements[#statements + 1] = {
        query = [[UPDATE `sky_phone_picstagram_reports`
            SET `status` = ?, `resolved_action` = ?, `resolved_at` = CURRENT_TIMESTAMP
            WHERE `id` = ?]],
        params = { data.action == "dismiss" and "dismissed" or "reviewed", data.action, report.id },
    }
    statements[#statements + 1] = {
        query = [[INSERT INTO `sky_phone_picstagram_moderation_audit`
            (`id`, `report_id`, `moderator_identifier`, `action`, `target_type`, `target_id`)
            VALUES (?, ?, ?, ?, ?, ?)]],
        params = {
            new_id(),
            report.id,
            Bridge.Framework.GetIdentifier(source) or ("source:%s"):format(source),
            data.action,
            report.target_type,
            report.target_id,
        },
    }
    if not Bridge.Database.Transaction(statements) then
        return { success = false, error = "request_failed" }
    end
    return { success = true }
end)

local active_verify_command = nil
local registered_verify_commands = {}

local function run_verify_command(source, args)
    local command_locale = SkyPhoneLocales.Resolve(Config.Bridge.Locale).PicstagramCommand
    local function command_message(template, values)
        return template:gsub("{(%w+)}", function(key)
            return values[key] or ""
        end)
    end
    local function send_command_feedback(message, notification_type)
        if source == 0 then
            Bridge.Debug(notification_type == "error" and "error" or "info", message)
            return
        end
        TriggerClientEvent("sky_phone:picstagram:command-feedback", source, {
            message = message,
            notificationType = notification_type,
        })
    end
    if source ~= 0 and not Bridge.Framework.HasAdminGroup(source, Config.Picstagram.AdminGroups) then
        send_command_feedback(command_locale.noPermission, "error")
        Bridge.Debug(
            "warn",
            "[sky_phone] Source %s attempted to use the Picstagram verification command without an admin group.",
            tostring(source)
        )
        return
    end
    local handle = normalize_handle(args[1])
    local state = args[2] == "on" and 1 or args[2] == "off" and 0 or nil
    if not handle or state == nil then
        send_command_feedback(
            command_message(command_locale.usage, { command = Config.Picstagram.VerifyCommand }),
            "error"
        )
        return
    end
    local target = Bridge.Database.Query(
        "SELECT `id` FROM `sky_phone_picstagram_profiles` WHERE `handle` = ? LIMIT 1",
        { handle }
    )[1]
    if not target then
        send_command_feedback(command_message(command_locale.notFound, { handle = handle }), "error")
        return
    end
    Bridge.Database.Query(
        "UPDATE `sky_phone_picstagram_profiles` SET `verified` = ? WHERE `id` = ?",
        { state, target.id }
    )
    TriggerClientEvent("sky_phone:picstagram:verification-changed", -1, {
        profileId = target.id,
        verified = state == 1,
    })
    send_command_feedback(command_message(command_locale.updated, {
        handle = handle,
        state = state == 1 and command_locale.verified or command_locale.unverified,
    }), "success")
end

local function refresh_verify_command()
    local command_name = Config.Picstagram.VerifyCommand
    if type(command_name) ~= "string" or command_name == "" then
        error("[sky_phone] Config.Picstagram.VerifyCommand must be a non-empty command name.")
    end
    active_verify_command = command_name
    if registered_verify_commands[command_name] then
        return
    end
    registered_verify_commands[command_name] = true
    RegisterCommand(command_name, function(source, args)
        if active_verify_command == command_name then
            run_verify_command(source, args)
        end
    end, false)
end

refresh_verify_command()

AddEventHandler("sky_phone:configurator:serverUpdated", refresh_verify_command)
end)
