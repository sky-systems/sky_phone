(SkyPhoneAppDatabase and SkyPhoneAppDatabase.Bind("feather") or function(start)
    Bridge.Database.AfterMigration("sky_phone", start)
end)(function()
local reaction_kinds = { like = true, bookmark = true }
local report_reasons = { spam = true, harassment = true, dangerous = true, illegal = true, other = true }

local function trim(value)
    if type(value) ~= "string" then return nil end
    return value:match("^%s*(.-)%s*$")
end

local function valid_text(value, minimum, maximum)
    local length = type(value) == "string" and utf8.len(value) or nil
    return length and length >= minimum and length <= maximum
end

local function new_id()
    local rows = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    if not rows[1] or type(rows[1].id) ~= "string" then
        error("[sky_phone] Database did not generate a Feather id.")
    end
    return rows[1].id
end

local function normalize_handle(value)
    local handle = trim(value)
    if not handle then return nil end
    handle = handle:lower():gsub("^@", "")
    if #handle < 3 or #handle > Config.Feather.HandleMaxLength
        or not handle:match("^[a-z0-9][a-z0-9_]*[a-z0-9]$")
    then
        return nil
    end
    return handle
end

local function require_profile(source)
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then return nil, error_response end
    local rows = Bridge.Database.Query(
        "SELECT * FROM `sky_phone_feather_profiles` WHERE `account_id` = ? LIMIT 1",
        { account.id }
    )
    if not rows[1] then return nil, { success = false, error = "feather_profile_required" } end
    return rows[1], nil
end

local function are_blocked(first_id, second_id)
    return Bridge.Database.Query([[SELECT `id` FROM `sky_phone_feather_blocks` WHERE
        (`blocker_id` = ? AND `blocked_id` = ?) OR (`blocker_id` = ? AND `blocked_id` = ?) LIMIT 1]], {
        first_id, second_id, second_id, first_id,
    })[1] ~= nil
end

local function hydrate_profile(profile, viewer_id)
    profile.id = tonumber(profile.id)
    profile.verified = tonumber(profile.verified) == 1
    profile.is_owner = profile.id == viewer_id
    profile.is_following = tonumber(profile.is_following) == 1
    profile.followers = tonumber(profile.followers) or 0
    profile.following = tonumber(profile.following) or 0
    profile.post_count = tonumber(profile.post_count) or 0
    return profile
end

local function load_profile(profile_id, viewer_id)
    local rows = Bridge.Database.Query([[
        SELECT p.`id`, p.`handle`, p.`display_name`, p.`bio`, p.`verified`, m.`url` AS `avatar_url`,
            EXISTS(SELECT 1 FROM `sky_phone_feather_follows` f WHERE f.`follower_id` = ? AND f.`following_id` = p.`id`) AS `is_following`,
            (SELECT COUNT(*) FROM `sky_phone_feather_follows` f WHERE f.`following_id` = p.`id`) AS `followers`,
            (SELECT COUNT(*) FROM `sky_phone_feather_follows` f WHERE f.`follower_id` = p.`id`) AS `following`,
            (SELECT COUNT(*) FROM `sky_phone_feather_posts` fp WHERE fp.`profile_id` = p.`id` AND fp.`status` = 'published') AS `post_count`
        FROM `sky_phone_feather_profiles` p
        LEFT JOIN `sky_phone_media` m ON m.`id` = p.`avatar_media_id`
        WHERE p.`id` = ? LIMIT 1
    ]], { viewer_id, profile_id })
    return rows[1] and hydrate_profile(rows[1], viewer_id) or nil
end

local function hydrate_posts(rows, viewer_id)
    local ids = {}
    for _, post in ipairs(rows) do
        post.profile_id = tonumber(post.profile_id)
        post.verified = tonumber(post.verified) == 1
        post.is_owner = post.profile_id == viewer_id
        post.is_following = tonumber(post.is_following) == 1
        post.is_liked = tonumber(post.is_liked) == 1
        post.is_bookmarked = tonumber(post.is_bookmarked) == 1
        post.like_count = tonumber(post.like_count) or 0
        post.reply_count = tonumber(post.reply_count) or 0
        post.created_at = (tonumber(post.created_at_unix) or 0) * 1000
        post.created_at_unix = nil
        post.media = {}
        ids[#ids + 1] = post.id
    end
    if #ids == 0 then return rows end

    local placeholders = {}
    for index = 1, #ids do placeholders[index] = "?" end
    local media_rows = Bridge.Database.Query(([[
        SELECT pm.`post_id`, pm.`media_id` AS `id`, m.`url`, m.`media_type`
        FROM `sky_phone_feather_post_media` pm
        JOIN `sky_phone_media` m ON m.`id` = pm.`media_id`
        WHERE pm.`post_id` IN (%s) ORDER BY pm.`post_id`, pm.`sort_order`
    ]]):format(table.concat(placeholders, ",")), ids)
    local posts = {}
    for _, post in ipairs(rows) do posts[post.id] = post end
    for _, media in ipairs(media_rows) do
        media.id = tonumber(media.id)
        posts[media.post_id].media[#posts[media.post_id].media + 1] = media
    end
    return rows
end

local function list_posts(viewer_id, condition, values, ranking, offset)
    local parameters = { viewer_id, viewer_id, viewer_id, viewer_id }
    for _, value in ipairs(values) do parameters[#parameters + 1] = value end
    parameters[#parameters + 1] = viewer_id
    parameters[#parameters + 1] = viewer_id
    parameters[#parameters + 1] = Config.Feather.PageSize + 1
    parameters[#parameters + 1] = offset
    local rows = Bridge.Database.Query(([[
        SELECT fp.`id`, fp.`profile_id`, fp.`body`, fp.`reply_to_id`, fp.`quote_id`,
            UNIX_TIMESTAMP(fp.`created_at`) AS `created_at_unix`, p.`handle`, p.`display_name`, p.`verified`, avatar.`url` AS `avatar_url`,
            (fp.`profile_id` = ?) AS `is_owner`,
            EXISTS(SELECT 1 FROM `sky_phone_feather_follows` f WHERE f.`follower_id` = ? AND f.`following_id` = fp.`profile_id`) AS `is_following`,
            EXISTS(SELECT 1 FROM `sky_phone_feather_reactions` r WHERE r.`profile_id` = ? AND r.`post_id` = fp.`id` AND r.`kind` = 'like') AS `is_liked`,
            EXISTS(SELECT 1 FROM `sky_phone_feather_reactions` r WHERE r.`profile_id` = ? AND r.`post_id` = fp.`id` AND r.`kind` = 'bookmark') AS `is_bookmarked`,
            (SELECT COUNT(*) FROM `sky_phone_feather_reactions` r WHERE r.`post_id` = fp.`id` AND r.`kind` = 'like') AS `like_count`,
            (SELECT COUNT(*) FROM `sky_phone_feather_posts` reply WHERE reply.`reply_to_id` = fp.`id` AND reply.`status` = 'published') AS `reply_count`
        FROM `sky_phone_feather_posts` fp
        JOIN `sky_phone_feather_profiles` p ON p.`id` = fp.`profile_id`
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = p.`avatar_media_id`
        WHERE fp.`status` = 'published' AND %s
            AND NOT EXISTS(SELECT 1 FROM `sky_phone_feather_blocks` b WHERE
                (b.`blocker_id` = ? AND b.`blocked_id` = fp.`profile_id`) OR
                (b.`blocked_id` = ? AND b.`blocker_id` = fp.`profile_id`))
        ORDER BY %s LIMIT ? OFFSET ?
    ]]):format(condition, ranking), parameters)
    local has_more = #rows > Config.Feather.PageSize
    if has_more then rows[#rows] = nil end
    return { items = hydrate_posts(rows, viewer_id), offset = offset, hasMore = has_more }
end

local function notify_profile(recipient_id, actor, kind, post_id)
    if recipient_id == tonumber(actor.id) then return end
    local recipients = Bridge.Database.Query(
        "SELECT `account_id` FROM `sky_phone_feather_profiles` WHERE `id` = ? LIMIT 1",
        { recipient_id }
    )
    if not recipients[1] then return end
    Bridge.Database.Query([[INSERT INTO `sky_phone_feather_notifications`
        (`id`, `recipient_id`, `actor_id`, `post_id`, `kind`) VALUES (?, ?, ?, ?, ?)]], {
        new_id(), recipient_id, actor.id, post_id, kind,
    })
    SkyPhone.NotifyAccountDevices(tonumber(recipients[1].account_id), "sky_phone:feather:new", {
        actor = actor.display_name,
        kind = kind,
        postId = post_id,
    })
end

local function suggestions(profile_id)
    local rows = Bridge.Database.Query([[
        SELECT p.`id`, p.`handle`, p.`display_name`, p.`bio`, p.`verified`, m.`url` AS `avatar_url`,
            0 AS `is_following`,
            (SELECT COUNT(*) FROM `sky_phone_feather_follows` f WHERE f.`following_id` = p.`id`) AS `followers`,
            (SELECT COUNT(*) FROM `sky_phone_feather_follows` f WHERE f.`follower_id` = p.`id`) AS `following`,
            (SELECT COUNT(*) FROM `sky_phone_feather_posts` fp WHERE fp.`profile_id` = p.`id` AND fp.`status` = 'published') AS `post_count`
        FROM `sky_phone_feather_profiles` p
        LEFT JOIN `sky_phone_media` m ON m.`id` = p.`avatar_media_id`
        WHERE p.`id` <> ? AND NOT EXISTS(SELECT 1 FROM `sky_phone_feather_follows` f WHERE f.`follower_id` = ? AND f.`following_id` = p.`id`)
            AND NOT EXISTS(SELECT 1 FROM `sky_phone_feather_blocks` b WHERE
                (b.`blocker_id` = ? AND b.`blocked_id` = p.`id`) OR
                (b.`blocked_id` = ? AND b.`blocker_id` = p.`id`))
        ORDER BY `followers` DESC, p.`created_at` DESC LIMIT 5
    ]], { profile_id, profile_id, profile_id, profile_id })
    for _, row in ipairs(rows) do hydrate_profile(row, profile_id) end
    return rows
end

local function search_profiles(profile_id, search)
    local pattern = "%" .. search:gsub("[%%_]", "\\%0") .. "%"
    local prefix = search:gsub("[%%_]", "\\%0") .. "%"
    local rows = Bridge.Database.Query([[
        SELECT p.`id`, p.`handle`, p.`display_name`, p.`bio`, p.`verified`, m.`url` AS `avatar_url`,
            EXISTS(SELECT 1 FROM `sky_phone_feather_follows` f WHERE f.`follower_id` = ? AND f.`following_id` = p.`id`) AS `is_following`,
            (SELECT COUNT(*) FROM `sky_phone_feather_follows` f WHERE f.`following_id` = p.`id`) AS `followers`,
            (SELECT COUNT(*) FROM `sky_phone_feather_follows` f WHERE f.`follower_id` = p.`id`) AS `following`,
            (SELECT COUNT(*) FROM `sky_phone_feather_posts` fp WHERE fp.`profile_id` = p.`id` AND fp.`status` = 'published') AS `post_count`
        FROM `sky_phone_feather_profiles` p
        LEFT JOIN `sky_phone_media` m ON m.`id` = p.`avatar_media_id`
        WHERE p.`id` <> ? AND (p.`handle` LIKE ? OR p.`display_name` LIKE ?)
            AND NOT EXISTS(SELECT 1 FROM `sky_phone_feather_blocks` b WHERE
                (b.`blocker_id` = ? AND b.`blocked_id` = p.`id`) OR
                (b.`blocked_id` = ? AND b.`blocker_id` = p.`id`))
        ORDER BY (p.`handle` = ?) DESC, (p.`handle` LIKE ?) DESC, `followers` DESC, p.`created_at` DESC
        LIMIT ?
    ]], {
        profile_id, profile_id, pattern, pattern, profile_id, profile_id,
        search, prefix, Config.Feather.PageSize,
    })
    for _, row in ipairs(rows) do hydrate_profile(row, profile_id) end
    return rows
end

local function list_connections(profile_id, viewer_id, mode)
    local join_condition = mode == "followers"
        and "connection.`follower_id` = p.`id`"
        or "connection.`following_id` = p.`id`"
    local owner_condition = mode == "followers"
        and "connection.`following_id` = ?"
        or "connection.`follower_id` = ?"
    local rows = Bridge.Database.Query(([[
        SELECT p.`id`, p.`handle`, p.`display_name`, p.`bio`, p.`verified`, avatar.`url` AS `avatar_url`,
            EXISTS(SELECT 1 FROM `sky_phone_feather_follows` viewer_follow WHERE viewer_follow.`follower_id` = ? AND viewer_follow.`following_id` = p.`id`) AS `is_following`,
            (SELECT COUNT(*) FROM `sky_phone_feather_follows` f WHERE f.`following_id` = p.`id`) AS `followers`,
            (SELECT COUNT(*) FROM `sky_phone_feather_follows` f WHERE f.`follower_id` = p.`id`) AS `following`,
            (SELECT COUNT(*) FROM `sky_phone_feather_posts` fp WHERE fp.`profile_id` = p.`id` AND fp.`status` = 'published') AS `post_count`
        FROM `sky_phone_feather_follows` connection
        JOIN `sky_phone_feather_profiles` p ON %s
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = p.`avatar_media_id`
        WHERE %s AND NOT EXISTS(SELECT 1 FROM `sky_phone_feather_blocks` b WHERE
            (b.`blocker_id` = ? AND b.`blocked_id` = p.`id`) OR
            (b.`blocked_id` = ? AND b.`blocker_id` = p.`id`))
        ORDER BY p.`display_name`, p.`handle`
    ]]):format(join_condition, owner_condition), { viewer_id, profile_id, viewer_id, viewer_id })
    for _, row in ipairs(rows) do hydrate_profile(row, viewer_id) end
    return rows
end

local function extract_hashtags(body)
    local hashtags = {}
    local seen = {}
    for tag in body:gmatch("#([%w_]+)") do
        local normalized = tag:lower()
        if #normalized <= Config.Feather.HashtagMaxLength and not seen[normalized] then
            seen[normalized] = true
            hashtags[#hashtags + 1] = normalized
        end
    end
    return hashtags
end

local function trending_hashtags()
    local rows = Bridge.Database.Query([[
        SELECT h.`tag`, COUNT(*) AS `post_count`
        FROM `sky_phone_feather_hashtags` h
        JOIN `sky_phone_feather_posts` fp ON fp.`id` = h.`post_id` AND fp.`status` = 'published'
        GROUP BY h.`tag`
        ORDER BY `post_count` DESC, h.`tag` ASC
        LIMIT ?
    ]], { Config.Feather.TrendingTopicLimit })
    local topics = {}
    for _, row in ipairs(rows) do
        topics[#topics + 1] = { tag = "#" .. row.tag, count = tonumber(row.post_count) or 0 }
    end
    return topics
end

local function backfill_hashtags()
    local posts = Bridge.Database.Query([[
        SELECT fp.`id`, fp.`body` FROM `sky_phone_feather_posts` fp
        WHERE fp.`status` = 'published' AND fp.`body` LIKE '%#%'
    ]], {})
    local statements = {}
    for _, post in ipairs(posts) do
        for _, tag in ipairs(extract_hashtags(post.body)) do
            statements[#statements + 1] = {
                query = "INSERT IGNORE INTO `sky_phone_feather_hashtags` (`post_id`, `tag`) VALUES (?, ?)",
                params = { post.id, tag },
            }
            if #statements == 500 then
                if not Bridge.Database.Transaction(statements) then
                    error("[sky_phone] Failed to backfill Feather hashtags.")
                end
                statements = {}
            end
        end
    end
    if #statements > 0 and not Bridge.Database.Transaction(statements) then
        error("[sky_phone] Failed to backfill Feather hashtags.")
    end
end

backfill_hashtags()

Bridge.Callbacks.Register("sky_phone:feather:bootstrap", function(source)
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then return error_response end
    local rows = Bridge.Database.Query("SELECT `id` FROM `sky_phone_feather_profiles` WHERE `account_id` = ? LIMIT 1", { account.id })
    if not rows[1] then
        return { success = true, data = { onboarded = false, topics = trending_hashtags() } }
    end
    local profile_id = tonumber(rows[1].id)
    return { success = true, data = {
        onboarded = true,
        profile = load_profile(profile_id, profile_id),
        feed = list_posts(profile_id, "fp.`reply_to_id` IS NULL", {}, "fp.`created_at` DESC", 0),
        suggestions = suggestions(profile_id),
        topics = trending_hashtags(),
    } }
end)

Bridge.Callbacks.Register("sky_phone:feather:create-profile", function(source, data)
    if not SkyPhone.AllowOperation(source, "feather:create-profile", 5, 60) then
        return { success = false, error = "rate_limited" }
    end
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then return error_response end
    data = type(data) == "table" and data or {}
    local handle = normalize_handle(data.handle)
    local display_name = trim(data.displayName)
    local bio = trim(data.bio) or ""
    if not handle then return { success = false, error = "invalid_handle" } end
    if not valid_text(display_name, 1, Config.Feather.DisplayNameMaxLength) then return { success = false, error = "invalid_display_name" } end
    if not valid_text(bio, 0, Config.Feather.BioMaxLength) then return { success = false, error = "invalid_bio" } end
    local avatar_id = nil
    if data.avatarId then
        local media, media_error = SkyPhoneMedia.ResolveOwnedMedia(source, data.avatarId, "photo")
        if not media then return { success = false, error = media_error } end
        avatar_id = math.floor(tonumber(data.avatarId))
    end
    local existing = Bridge.Database.Query("SELECT `id` FROM `sky_phone_feather_profiles` WHERE `account_id` = ? LIMIT 1", { account.id })
    if existing[1] then return { success = false, error = "already_registered" } end
    local duplicate = Bridge.Database.Query("SELECT `id` FROM `sky_phone_feather_profiles` WHERE `handle` = ? LIMIT 1", { handle })
    if duplicate[1] then return { success = false, error = "handle_taken" } end
    Bridge.Database.Query([[INSERT INTO `sky_phone_feather_profiles`
        (`account_id`, `handle`, `display_name`, `bio`, `avatar_media_id`) VALUES (?, ?, ?, ?, ?)]], {
        account.id, handle, display_name, bio, avatar_id,
    })
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:feather:update-profile", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    data = type(data) == "table" and data or {}
    local display_name = trim(data.displayName)
    local bio = trim(data.bio) or ""
    if not valid_text(display_name, 1, Config.Feather.DisplayNameMaxLength) then return { success = false, error = "invalid_display_name" } end
    if not valid_text(bio, 0, Config.Feather.BioMaxLength) then return { success = false, error = "invalid_bio" } end
    local avatar_id = profile.avatar_media_id and tonumber(profile.avatar_media_id) or nil
    if data.avatarId then
        local media, media_error = SkyPhoneMedia.ResolveOwnedMedia(source, data.avatarId, "photo")
        if not media then return { success = false, error = media_error } end
        avatar_id = math.floor(tonumber(data.avatarId))
    end
    Bridge.Database.Query("UPDATE `sky_phone_feather_profiles` SET `display_name` = ?, `bio` = ?, `avatar_media_id` = ? WHERE `id` = ?", {
        display_name, bio, avatar_id, profile.id,
    })
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:feather:feed", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    data = type(data) == "table" and data or {}
    local offset = math.max(0, math.floor(tonumber(data.offset) or 0))
    local condition = "fp.`reply_to_id` IS NULL"
    local values = {}
    local ranking = "(SELECT COUNT(*) FROM `sky_phone_feather_reactions` rank_reactions WHERE rank_reactions.`post_id` = fp.`id`) DESC, fp.`created_at` DESC"
    if data.mode == "following" then
        condition = "fp.`reply_to_id` IS NULL AND (fp.`profile_id` = ? OR EXISTS(SELECT 1 FROM `sky_phone_feather_follows` follow_filter WHERE follow_filter.`follower_id` = ? AND follow_filter.`following_id` = fp.`profile_id`))"
        values = { profile.id, profile.id }
        ranking = "fp.`created_at` DESC"
    end
    return { success = true, data = list_posts(tonumber(profile.id), condition, values, ranking, offset) }
end)

Bridge.Callbacks.Register("sky_phone:feather:explore", function(source, data)
    if not SkyPhone.AllowOperation(source, "feather:explore", Config.Feather.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    data = type(data) == "table" and data or {}
    local search = trim(data.search) or ""
    if not valid_text(search, 0, Config.Feather.SearchMaxLength) then return { success = false, error = "invalid_search" } end
    local condition = "fp.`reply_to_id` IS NULL"
    local values = {}
    if search ~= "" then
        condition = "fp.`body` LIKE ?"
        local pattern = "%" .. search:gsub("[%%_]", "\\%0") .. "%"
        values = { pattern }
    end
    return { success = true, data = {
        posts = list_posts(tonumber(profile.id), condition, values, "fp.`created_at` DESC", 0).items,
        profiles = suggestions(tonumber(profile.id)),
        topics = search == "" and trending_hashtags() or nil,
    } }
end)

Bridge.Callbacks.Register("sky_phone:feather:network", function(source, data)
    if not SkyPhone.AllowOperation(source, "feather:network", Config.Feather.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    data = type(data) == "table" and data or {}
    local search = trim(data.search) or ""
    if not valid_text(search, 0, Config.Feather.SearchMaxLength) then
        return { success = false, error = "invalid_search" }
    end
    search = search:gsub("^@", "")
    local profile_id = tonumber(profile.id)
    return { success = true, data = {
        results = search ~= "" and search_profiles(profile_id, search) or {},
        suggestions = suggestions(profile_id),
    } }
end)

Bridge.Callbacks.Register("sky_phone:feather:create-post", function(source, data)
    if not SkyPhone.AllowOperation(source, "feather:create-post", Config.Feather.PostsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    data = type(data) == "table" and data or {}
    local body = trim(data.body) or ""
    local media_ids = type(data.mediaIds) == "table" and data.mediaIds or {}
    if not valid_text(body, #media_ids > 0 and 0 or 1, Config.Feather.TextMaxLength) then return { success = false, error = "invalid_post" } end
    if #media_ids > Config.Feather.MaxImages then return { success = false, error = "too_many_images" } end
    local reply_to_id = type(data.replyToId) == "string" and data.replyToId or nil
    local quote_id = type(data.quoteId) == "string" and data.quoteId or nil
    local target_id = reply_to_id or quote_id
    local target = nil
    if target_id then
        local targets = Bridge.Database.Query([[SELECT fp.`id`, fp.`profile_id` FROM `sky_phone_feather_posts` fp
            WHERE fp.`id` = ? AND fp.`status` = 'published' LIMIT 1]], { target_id })
        target = targets[1]
        if not target then return { success = false, error = "post_not_found" } end
        if are_blocked(tonumber(profile.id), tonumber(target.profile_id)) then return { success = false, error = "profile_blocked" } end
    end
    local normalized_media = {}
    local seen = {}
    for _, value in ipairs(media_ids) do
        local id = tonumber(value)
        if not id or seen[id] then return { success = false, error = "invalid_attachment" } end
        local media, media_error = SkyPhoneMedia.ResolveOwnedMedia(source, id, "photo")
        if not media then return { success = false, error = media_error } end
        seen[id] = true
        normalized_media[#normalized_media + 1] = math.floor(id)
    end
    local post_id = new_id()
    local statements = {{
        query = "INSERT INTO `sky_phone_feather_posts` (`id`, `profile_id`, `body`, `reply_to_id`, `quote_id`) VALUES (?, ?, ?, ?, ?)",
        params = { post_id, profile.id, body, reply_to_id, quote_id },
    }}
    for index, media_id in ipairs(normalized_media) do
        statements[#statements + 1] = {
            query = "INSERT INTO `sky_phone_feather_post_media` (`post_id`, `media_id`, `sort_order`) VALUES (?, ?, ?)",
            params = { post_id, media_id, index - 1 },
        }
    end
    for _, tag in ipairs(extract_hashtags(body)) do
        statements[#statements + 1] = {
            query = "INSERT INTO `sky_phone_feather_hashtags` (`post_id`, `tag`) VALUES (?, ?)",
            params = { post_id, tag },
        }
    end
    if not Bridge.Database.Transaction(statements) then return { success = false, error = "request_failed" } end
    if target then notify_profile(tonumber(target.profile_id), profile, reply_to_id and "reply" or "quote", post_id) end
    return { success = true, data = { id = post_id } }
end)

Bridge.Callbacks.Register("sky_phone:feather:react", function(source, data)
    if not SkyPhone.AllowOperation(source, "feather:react", Config.Feather.ActionsPerMinute, 60) then return { success = false, error = "rate_limited" } end
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    data = type(data) == "table" and data or {}
    local kind = data.kind
    if not reaction_kinds[kind] or type(data.id) ~= "string" or type(data.active) ~= "boolean" then return { success = false, error = "invalid_request" } end
    local posts = Bridge.Database.Query("SELECT `profile_id` FROM `sky_phone_feather_posts` WHERE `id` = ? AND `status` = 'published' LIMIT 1", { data.id })
    if not posts[1] then return { success = false, error = "post_not_found" } end
    if are_blocked(tonumber(profile.id), tonumber(posts[1].profile_id)) then return { success = false, error = "profile_blocked" } end
    if data.active then
        Bridge.Database.Query("INSERT IGNORE INTO `sky_phone_feather_reactions` (`post_id`, `profile_id`, `kind`) VALUES (?, ?, ?)", { data.id, profile.id, kind })
        if kind ~= "bookmark" then notify_profile(tonumber(posts[1].profile_id), profile, kind, data.id) end
    else
        Bridge.Database.Query("DELETE FROM `sky_phone_feather_reactions` WHERE `post_id` = ? AND `profile_id` = ? AND `kind` = ?", { data.id, profile.id, kind })
    end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:feather:follow", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    data = type(data) == "table" and data or {}
    local target_id = math.floor(tonumber(data.profileId) or 0)
    if target_id < 1 or target_id == tonumber(profile.id) or type(data.active) ~= "boolean" then return { success = false, error = "invalid_request" } end
    local targets = Bridge.Database.Query("SELECT `id` FROM `sky_phone_feather_profiles` WHERE `id` = ? LIMIT 1", { target_id })
    if not targets[1] then return { success = false, error = "profile_not_found" } end
    if are_blocked(tonumber(profile.id), target_id) then return { success = false, error = "profile_blocked" } end
    if data.active then
        Bridge.Database.Query("INSERT IGNORE INTO `sky_phone_feather_follows` (`follower_id`, `following_id`) VALUES (?, ?)", { profile.id, target_id })
        notify_profile(target_id, profile, "follow", nil)
    else
        Bridge.Database.Query("DELETE FROM `sky_phone_feather_follows` WHERE `follower_id` = ? AND `following_id` = ?", { profile.id, target_id })
    end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:feather:connections", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    data = type(data) == "table" and data or {}
    local target_id = math.floor(tonumber(data.profileId) or tonumber(profile.id))
    local mode = data.mode
    if target_id < 1 or (mode ~= "followers" and mode ~= "following") then
        return { success = false, error = "invalid_request" }
    end
    local target = load_profile(target_id, tonumber(profile.id))
    if not target then return { success = false, error = "profile_not_found" } end
    if are_blocked(tonumber(profile.id), target_id) then return { success = false, error = "profile_blocked" } end
    return { success = true, data = {
        items = list_connections(target_id, tonumber(profile.id), mode),
    } }
end)

Bridge.Callbacks.Register("sky_phone:feather:remove-connection", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    data = type(data) == "table" and data or {}
    local target_id = math.floor(tonumber(data.profileId) or 0)
    local mode = data.mode
    if target_id < 1 or target_id == tonumber(profile.id) or (mode ~= "followers" and mode ~= "following") then
        return { success = false, error = "invalid_request" }
    end
    if mode == "followers" then
        Bridge.Database.Query("DELETE FROM `sky_phone_feather_follows` WHERE `follower_id` = ? AND `following_id` = ?", { target_id, profile.id })
    else
        Bridge.Database.Query("DELETE FROM `sky_phone_feather_follows` WHERE `follower_id` = ? AND `following_id` = ?", { profile.id, target_id })
    end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:feather:profile", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    data = type(data) == "table" and data or {}
    local target_id = tonumber(data.profileId) or tonumber(profile.id)
    if data.handle then
        local handle = normalize_handle(data.handle)
        local rows = handle and Bridge.Database.Query("SELECT `id` FROM `sky_phone_feather_profiles` WHERE `handle` = ? LIMIT 1", { handle }) or {}
        target_id = rows[1] and tonumber(rows[1].id) or 0
    end
    local target = load_profile(target_id, tonumber(profile.id))
    if not target then return { success = false, error = "profile_not_found" } end
    if are_blocked(tonumber(profile.id), target_id) then return { success = false, error = "profile_blocked" } end
    return { success = true, data = {
        profile = target,
        posts = list_posts(tonumber(profile.id), "fp.`profile_id` = ?", { target_id }, "fp.`created_at` DESC", 0).items,
    } }
end)

Bridge.Callbacks.Register("sky_phone:feather:bookmarks", function(source)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    local bookmarked = list_posts(
        tonumber(profile.id),
        "EXISTS(SELECT 1 FROM `sky_phone_feather_reactions` saved WHERE saved.`profile_id` = ? AND saved.`post_id` = fp.`id` AND saved.`kind` = 'bookmark')",
        { profile.id },
        "fp.`created_at` DESC",
        0
    )
    return { success = true, data = bookmarked }
end)

Bridge.Callbacks.Register("sky_phone:feather:thread", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    if type(data) ~= "table" or type(data.id) ~= "string" then return { success = false, error = "invalid_request" } end
    local parent = list_posts(tonumber(profile.id), "fp.`id` = ?", { data.id }, "fp.`created_at` DESC", 0).items
    if not parent[1] then return { success = false, error = "post_not_found" } end
    local replies = list_posts(tonumber(profile.id), "fp.`reply_to_id` = ?", { data.id }, "fp.`created_at` ASC", 0).items
    return { success = true, data = { post = parent[1], replies = replies } }
end)

Bridge.Callbacks.Register("sky_phone:feather:activities", function(source)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    local rows = Bridge.Database.Query([[
        SELECT n.`id`, n.`kind`, n.`post_id`, UNIX_TIMESTAMP(n.`created_at`) AS `created_at_unix`, n.`read_at`,
            actor.`id` AS `profile_id`, actor.`handle`, actor.`display_name`, actor.`verified`, avatar.`url` AS `avatar_url`
        FROM `sky_phone_feather_notifications` n
        JOIN `sky_phone_feather_profiles` actor ON actor.`id` = n.`actor_id`
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = actor.`avatar_media_id`
        WHERE n.`recipient_id` = ? ORDER BY n.`created_at` DESC LIMIT 100
    ]], { profile.id })
    for _, row in ipairs(rows) do
        row.profile_id = tonumber(row.profile_id)
        row.verified = tonumber(row.verified) == 1
        row.read = row.read_at ~= nil
        row.read_at = nil
        row.created_at = (tonumber(row.created_at_unix) or 0) * 1000
        row.created_at_unix = nil
    end
    return { success = true, data = rows }
end)

Bridge.Callbacks.Register("sky_phone:feather:mark-activities", function(source)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    Bridge.Database.Query("UPDATE `sky_phone_feather_notifications` SET `read_at` = COALESCE(`read_at`, NOW()) WHERE `recipient_id` = ?", { profile.id })
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:feather:delete", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    if type(data) ~= "table" or type(data.id) ~= "string" then return { success = false, error = "invalid_request" } end
    Bridge.Database.Query("UPDATE `sky_phone_feather_posts` SET `status` = 'removed' WHERE `id` = ? AND `profile_id` = ?", { data.id, profile.id })
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:feather:block", function(source, data)
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    local target_id = type(data) == "table" and math.floor(tonumber(data.profileId) or 0) or 0
    if target_id < 1 or target_id == tonumber(profile.id) then return { success = false, error = "invalid_request" } end
    local targets = Bridge.Database.Query("SELECT `id` FROM `sky_phone_feather_profiles` WHERE `id` = ? LIMIT 1", { target_id })
    if not targets[1] then return { success = false, error = "profile_not_found" } end
    if not Bridge.Database.Transaction({
        { query = "INSERT IGNORE INTO `sky_phone_feather_blocks` (`blocker_id`, `blocked_id`) VALUES (?, ?)", params = { profile.id, target_id } },
        { query = "DELETE FROM `sky_phone_feather_follows` WHERE (`follower_id` = ? AND `following_id` = ?) OR (`follower_id` = ? AND `following_id` = ?)", params = { profile.id, target_id, target_id, profile.id } },
    }) then return { success = false, error = "request_failed" } end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:feather:report", function(source, data)
    if not SkyPhone.AllowOperation(source, "feather:report", Config.Feather.ReportsPerDay, 86400) then return { success = false, error = "rate_limited" } end
    local profile, error_response = require_profile(source)
    if not profile then return error_response end
    data = type(data) == "table" and data or {}
    local reason = data.reason
    local details = trim(data.details) or ""
    if type(data.id) ~= "string" or not report_reasons[reason] or not valid_text(details, 0, Config.Feather.ReportDetailsMaxLength) then
        return { success = false, error = "invalid_request" }
    end
    local posts = Bridge.Database.Query("SELECT `id` FROM `sky_phone_feather_posts` WHERE `id` = ? AND `status` = 'published' LIMIT 1", { data.id })
    if not posts[1] then return { success = false, error = "post_not_found" } end
    Bridge.Database.Query([[INSERT IGNORE INTO `sky_phone_feather_reports`
        (`id`, `reporter_id`, `post_id`, `reason`, `details`) VALUES (?, ?, ?, ?, ?)]], {
        new_id(), profile.id, data.id, reason, details,
    })
    return { success = true }
end)
end)
