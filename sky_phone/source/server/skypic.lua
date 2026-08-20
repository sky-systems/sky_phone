Bridge.Database.AfterMigration("sky_phone", function()
local settings = Config.SkyPic or {}
local json_null = type(json) == "table" and json.null or nil

local function nullable(value)
    if value == nil then
        return json_null
    end
    return value
end

local function limit(name, fallback)
    local value = tonumber(settings[name])
    if not value or value < 1 then
        return fallback
    end
    return math.floor(value)
end

local function trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return value:match("^%s*(.-)%s*$") or ""
end

local function text_length(value)
    local ok, length = pcall(utf8.len, value)
    if not ok then
        return nil
    end
    return length
end

local function valid_text(value, minimum, maximum)
    if type(value) ~= "string" then
        return false
    end
    local length = text_length(value)
    return length ~= nil and length >= minimum and length <= maximum
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

-- Keep the denormalized counters authoritative for strict, concurrent friend
-- limit enforcement and repair any drift left by older resource versions.
Bridge.Database.Query([[
    UPDATE `sky_phone_skypic_profiles` profile
    LEFT JOIN (
        SELECT sides.`profile_id`, COUNT(*) AS `friend_count`
        FROM (
            SELECT friendship.`profile_a_id` AS `profile_id`
            FROM `sky_phone_skypic_friendships` friendship
            WHERE friendship.`status` = 'accepted'
            UNION ALL
            SELECT friendship.`profile_b_id` AS `profile_id`
            FROM `sky_phone_skypic_friendships` friendship
            WHERE friendship.`status` = 'accepted'
        ) sides
        GROUP BY sides.`profile_id`
    ) counts ON counts.`profile_id` = profile.`id`
    SET profile.`friend_count` = COALESCE(counts.`friend_count`, 0)
]], {})

local function new_id()
    local rows = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    if not rows[1] or type(rows[1].id) ~= "string" then
        error("[sky_phone] Database did not generate a SkyPic id.")
    end
    return rows[1].id
end

local function valid_id(value)
    return type(value) == "string"
        and value:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

local function valid_integer(value, minimum, maximum)
    if type(value) ~= "number" or value ~= math.floor(value) or value < minimum or value > maximum then
        return nil
    end
    return value
end

local function normalize_handle(value)
    local handle = trim(value):lower()
    if #handle < limit("HandleMinLength", 3) or #handle > limit("HandleMaxLength", 24)
        or handle:match("^[a-z0-9._]+$") == nil
    then
        return nil
    end
    return handle
end

local function normalize_color(value)
    if type(value) ~= "string" or value:match("^#%x%x%x%x%x%x$") == nil then
        return nil
    end
    return value:upper()
end

local function normalized_pair(first_id, second_id)
    if first_id < second_id then
        return first_id, second_id
    end
    return second_id, first_id
end

local function is_true(value)
    return value == true or tonumber(value) == 1
end

local function summary_from_row(row, status_override, friendship_id_override)
    if not row then
        return nil
    end
    local friendship_id = friendship_id_override
    if friendship_id == nil then
        friendship_id = row.friendship_id
    end
    local summary = {
        id = row.profile_id or row.id,
        handle = row.handle,
        displayName = row.display_name,
        avatarUrl = nullable(row.avatar_url),
        avatarSeed = tonumber(row.avatar_seed) or 1,
        snapScore = tonumber(row.snap_score) or 0,
    }
    summary.friendshipId = nullable(friendship_id)
    summary.friendshipStatus = status_override or row.friendship_status or "none"
    return summary
end

local function profile_from_row(row)
    local profile = summary_from_row(row, nil, nil)
    profile.avatarMediaId = nullable(tonumber(row.avatar_media_id))
    profile.bio = row.bio or ""
    profile.storyPrivacy = row.story_privacy == "everyone" and "everyone" or "friends"
    profile.showInQuickAdd = is_true(row.quick_add)
    profile.allowStoryReplies = is_true(row.allow_story_replies)
    profile.friendCount = tonumber(row.friend_count) or 0
    return profile
end

local function require_profile(source)
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then
        return nil, nil, error_response
    end
    local rows = Bridge.Database.Query([[
        SELECT profile.`id` AS `profile_id`, profile.`handle`, profile.`display_name`, profile.`bio`,
            profile.`avatar_media_id`, profile.`avatar_seed`, profile.`story_privacy`, profile.`quick_add`,
            profile.`allow_story_replies`, profile.`snap_score`, avatar.`url` AS `avatar_url`,
            (SELECT COUNT(*) FROM `sky_phone_skypic_friendships` friendship
                WHERE friendship.`status` = 'accepted'
                    AND (friendship.`profile_a_id` = profile.`id` OR friendship.`profile_b_id` = profile.`id`)) AS `friend_count`
        FROM `sky_phone_skypic_profiles` profile
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = profile.`avatar_media_id`
        WHERE profile.`account_id` = ? AND profile.`status` = 'active'
        LIMIT 1
    ]], { account.id })
    if not rows[1] then
        return nil, account, { success = false, error = "profile_required" }
    end
    return rows[1], account
end

local function optional_profile(source)
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then
        return nil, nil, error_response
    end
    local rows = Bridge.Database.Query([[
        SELECT profile.`id` AS `profile_id`, profile.`handle`, profile.`display_name`, profile.`bio`,
            profile.`avatar_media_id`, profile.`avatar_seed`, profile.`story_privacy`, profile.`quick_add`,
            profile.`allow_story_replies`, profile.`snap_score`, avatar.`url` AS `avatar_url`,
            (SELECT COUNT(*) FROM `sky_phone_skypic_friendships` friendship
                WHERE friendship.`status` = 'accepted'
                    AND (friendship.`profile_a_id` = profile.`id` OR friendship.`profile_b_id` = profile.`id`)) AS `friend_count`
        FROM `sky_phone_skypic_profiles` profile
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = profile.`avatar_media_id`
        WHERE profile.`account_id` = ? AND profile.`status` = 'active'
        LIMIT 1
    ]], { account.id })
    return rows[1], account
end

local function friendship_status(actor_id, requested_by_id, status)
    if status == "accepted" then
        return "friends"
    end
    if status == "pending" then
        return requested_by_id == actor_id and "outgoing" or "incoming"
    end
    return "none"
end

local function active_friendship(profile_id, friendship_id)
    local rows = Bridge.Database.Query([[
        SELECT friendship.*,
            CASE WHEN friendship.`profile_a_id` = ? THEN friendship.`profile_b_id` ELSE friendship.`profile_a_id` END AS `peer_id`
        FROM `sky_phone_skypic_friendships` friendship
        WHERE friendship.`id` = ? AND friendship.`status` = 'accepted'
            AND (friendship.`profile_a_id` = ? OR friendship.`profile_b_id` = ?)
            AND NOT EXISTS (
                SELECT 1 FROM `sky_phone_skypic_blocks` block
                WHERE (block.`blocker_profile_id` = friendship.`profile_a_id` AND block.`blocked_profile_id` = friendship.`profile_b_id`)
                    OR (block.`blocker_profile_id` = friendship.`profile_b_id` AND block.`blocked_profile_id` = friendship.`profile_a_id`)
            )
        LIMIT 1
    ]], { profile_id, friendship_id, profile_id, profile_id })
    return rows[1]
end

local function friendship_with_target(profile_id, target_id, accepted_only)
    local profile_a_id, profile_b_id = normalized_pair(profile_id, target_id)
    local query = [[
        SELECT * FROM `sky_phone_skypic_friendships`
        WHERE `profile_a_id` = ? AND `profile_b_id` = ?
    ]]
    if accepted_only then
        query = query .. " AND `status` = 'accepted'"
    end
    query = query .. " LIMIT 1"
    local rows = Bridge.Database.Query(query, { profile_a_id, profile_b_id })
    return rows[1]
end

local function are_blocked(first_id, second_id)
    local rows = Bridge.Database.Query([[
        SELECT 1 AS `blocked` FROM `sky_phone_skypic_blocks`
        WHERE (`blocker_profile_id` = ? AND `blocked_profile_id` = ?)
            OR (`blocker_profile_id` = ? AND `blocked_profile_id` = ?)
        LIMIT 1
    ]], { first_id, second_id, second_id, first_id })
    return rows[1] ~= nil
end

local function load_summary(profile_id, viewer_id)
    local rows = Bridge.Database.Query([[
        SELECT profile.`id` AS `profile_id`, profile.`handle`, profile.`display_name`, profile.`avatar_seed`,
            profile.`snap_score`, avatar.`url` AS `avatar_url`, friendship.`id` AS `friendship_id`,
            friendship.`status`, friendship.`requested_by_id`
        FROM `sky_phone_skypic_profiles` profile
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = profile.`avatar_media_id`
        LEFT JOIN `sky_phone_skypic_friendships` friendship
            ON friendship.`profile_a_id` = LEAST(?, profile.`id`)
            AND friendship.`profile_b_id` = GREATEST(?, profile.`id`)
        WHERE profile.`id` = ? AND profile.`status` = 'active'
        LIMIT 1
    ]], { viewer_id, viewer_id, profile_id })
    if not rows[1] then
        return nil
    end
    return summary_from_row(
        rows[1],
        friendship_status(viewer_id, rows[1].requested_by_id, rows[1].status),
        rows[1].friendship_id
    )
end

local function notify_profile(recipient_profile_id, actor, kind, snap_id)
    if recipient_profile_id == actor.profile_id then
        return
    end
    local rows = Bridge.Database.Query([[
        SELECT `account_id` FROM `sky_phone_skypic_profiles`
        WHERE `id` = ? AND `status` = 'active' LIMIT 1
    ]], { recipient_profile_id })
    local account_id = tonumber(rows[1] and rows[1].account_id)
    if not account_id then
        return
    end
    SkyPhone.NotifyAccountDevices(account_id, "sky_phone:skypic:new", {
        kind = kind,
        actor = actor.display_name,
        profileId = actor.profile_id,
        snapId = snap_id,
    }, 'skypic')
end

local function safe_snap_from_row(row, viewer_id)
    return {
        id = row.id,
        friendshipId = row.friendship_id,
        type = row.message_type,
        direction = row.sender_profile_id == viewer_id and "sent" or "received",
        durationSeconds = tonumber(row.view_seconds) or limit("MinimumViewSeconds", 1),
        allowReplay = is_true(row.allow_replay),
        openedAt = nullable(row.opened_at),
        replayedAt = nullable(row.replayed_at),
        expiresAt = row.expires_at,
        createdAt = row.created_at,
        sender = summary_from_row({
            profile_id = row.sender_profile_id,
            handle = row.sender_handle,
            display_name = row.sender_display_name,
            avatar_seed = row.sender_avatar_seed,
            avatar_url = row.sender_avatar_url,
            snap_score = row.sender_snap_score,
            friendship_status = "friends",
            friendship_id = row.friendship_id,
        }, row.sender_profile_id == viewer_id and "none" or "friends",
            row.sender_profile_id == viewer_id and nil or row.friendship_id),
    }
end

local function text_message_from_row(row, viewer_id)
    return {
        id = row.id,
        friendshipId = row.friendship_id,
        type = "text",
        direction = row.sender_profile_id == viewer_id and "sent" or "received",
        body = row.body or "",
        readAt = nullable(row.read_at),
        savedAt = nullable(row.saved_at),
        createdAt = row.created_at,
    }
end

local function empty_bootstrap()
    return {
        profile = json_null,
        blockedProfiles = {},
        friends = {},
        requests = {},
        conversations = {},
        inbox = {},
        stories = {},
        suggestions = {},
        unreadCount = 0,
    }
end

local function list_friends(profile_id)
    local rows = Bridge.Database.Query([[
        SELECT friendship.`id` AS `friendship_id`, friendship.`streak_count`, friendship.`best_streak`,
            friendship.`accepted_at`, friendship.`created_at`, peer.`id` AS `profile_id`, peer.`handle`,
            peer.`display_name`, peer.`avatar_seed`, peer.`snap_score`, avatar.`url` AS `avatar_url`
        FROM `sky_phone_skypic_friendships` friendship
        JOIN `sky_phone_skypic_profiles` peer
            ON peer.`id` = CASE WHEN friendship.`profile_a_id` = ?
                THEN friendship.`profile_b_id` ELSE friendship.`profile_a_id` END
            AND peer.`status` = 'active'
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = peer.`avatar_media_id`
        WHERE friendship.`status` = 'accepted'
            AND (friendship.`profile_a_id` = ? OR friendship.`profile_b_id` = ?)
            AND NOT EXISTS (
                SELECT 1 FROM `sky_phone_skypic_blocks` block
                WHERE (block.`blocker_profile_id` = ? AND block.`blocked_profile_id` = peer.`id`)
                    OR (block.`blocker_profile_id` = peer.`id` AND block.`blocked_profile_id` = ?)
            )
        ORDER BY peer.`display_name`, peer.`handle`
        LIMIT ?
    ]], { profile_id, profile_id, profile_id, profile_id, profile_id, limit("MaximumFriends", 500) })
    local friends = {}
    for _, row in ipairs(rows) do
        friends[#friends + 1] = {
            friendshipId = row.friendship_id,
            profile = summary_from_row(row, "friends", row.friendship_id),
            streakCount = tonumber(row.streak_count) or 0,
            bestStreak = tonumber(row.best_streak) or 0,
            createdAt = row.accepted_at or row.created_at,
        }
    end
    return friends
end

local function list_requests(profile_id)
    local rows = Bridge.Database.Query([[
        SELECT friendship.`id` AS `friendship_id`, friendship.`requested_by_id`, friendship.`created_at`,
            peer.`id` AS `profile_id`, peer.`handle`, peer.`display_name`, peer.`avatar_seed`,
            peer.`snap_score`, avatar.`url` AS `avatar_url`
        FROM `sky_phone_skypic_friendships` friendship
        JOIN `sky_phone_skypic_profiles` peer
            ON peer.`id` = CASE WHEN friendship.`profile_a_id` = ?
                THEN friendship.`profile_b_id` ELSE friendship.`profile_a_id` END
            AND peer.`status` = 'active'
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = peer.`avatar_media_id`
        WHERE friendship.`status` = 'pending'
            AND (friendship.`profile_a_id` = ? OR friendship.`profile_b_id` = ?)
            AND NOT EXISTS (
                SELECT 1 FROM `sky_phone_skypic_blocks` block
                WHERE (block.`blocker_profile_id` = ? AND block.`blocked_profile_id` = peer.`id`)
                    OR (block.`blocker_profile_id` = peer.`id` AND block.`blocked_profile_id` = ?)
            )
        ORDER BY friendship.`created_at` DESC
        LIMIT ?
    ]], { profile_id, profile_id, profile_id, profile_id, profile_id, limit("MaximumPendingRequests", 100) * 2 })
    local requests = {}
    for _, row in ipairs(rows) do
        local direction = row.requested_by_id == profile_id and "outgoing" or "incoming"
        requests[#requests + 1] = {
            friendshipId = row.friendship_id,
            direction = direction,
            profile = summary_from_row(row, direction, row.friendship_id),
            createdAt = row.created_at,
        }
    end
    return requests
end

local function list_blocked_profiles(profile_id)
    local rows = Bridge.Database.Query([[
        SELECT blocked.`id` AS `profile_id`, blocked.`handle`,
            blocked.`display_name`, blocked.`avatar_seed`,
            blocked.`snap_score`, avatar.`url` AS `avatar_url`
        FROM `sky_phone_skypic_blocks` block
        JOIN `sky_phone_skypic_profiles` blocked
            ON blocked.`id` = block.`blocked_profile_id`
            AND blocked.`status` = 'active'
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = blocked.`avatar_media_id`
        WHERE block.`blocker_profile_id` = ?
        ORDER BY block.`created_at` DESC
    ]], { profile_id })
    local profiles = {}
    for _, row in ipairs(rows) do
        profiles[#profiles + 1] = summary_from_row(row, "none", nil)
    end
    return profiles
end

local function list_profiles(profile_id, search, suggestions_only)
    local params = { profile_id, profile_id, profile_id, profile_id, profile_id }
    local filters = {}
    if suggestions_only then
        filters[#filters + 1] = "profile.`quick_add` = 1"
        filters[#filters + 1] = "friendship.`id` IS NULL"
    else
        filters[#filters + 1] = "(profile.`handle` LIKE ? OR profile.`display_name` LIKE ?)"
        local term = "%" .. search .. "%"
        params[#params + 1] = term
        params[#params + 1] = term
    end
    params[#params + 1] = suggestions_only and limit("SuggestionLimit", 20) or limit("SearchLimit", 30)
    local rows = Bridge.Database.Query(([[
        SELECT profile.`id` AS `profile_id`, profile.`handle`, profile.`display_name`, profile.`avatar_seed`,
            profile.`snap_score`, avatar.`url` AS `avatar_url`, friendship.`id` AS `friendship_id`,
            friendship.`status`, friendship.`requested_by_id`
        FROM `sky_phone_skypic_profiles` profile
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = profile.`avatar_media_id`
        LEFT JOIN `sky_phone_skypic_friendships` friendship
            ON friendship.`profile_a_id` = LEAST(?, profile.`id`)
            AND friendship.`profile_b_id` = GREATEST(?, profile.`id`)
        WHERE profile.`status` = 'active' AND profile.`id` <> ?
            AND NOT EXISTS (
                SELECT 1 FROM `sky_phone_skypic_blocks` block
                WHERE (block.`blocker_profile_id` = ? AND block.`blocked_profile_id` = profile.`id`)
                    OR (block.`blocker_profile_id` = profile.`id` AND block.`blocked_profile_id` = ?)
            )
            AND %s
        ORDER BY %s
        LIMIT ?
    ]]):format(
        table.concat(filters, " AND "),
        suggestions_only and "profile.`updated_at` DESC" or "(profile.`handle` = ?) DESC, profile.`handle`"
    ), suggestions_only and params or {
        params[1], params[2], params[3], params[4], params[5], params[6], params[7], search, params[8]
    })
    local profiles = {}
    for _, row in ipairs(rows) do
        profiles[#profiles + 1] = summary_from_row(
            row,
            friendship_status(profile_id, row.requested_by_id, row.status),
            row.friendship_id
        )
    end
    return profiles
end

local function list_inbox(profile_id)
    local rows = Bridge.Database.Query([[
        SELECT message.`id`, message.`friendship_id`, message.`sender_profile_id`, message.`message_type`,
            message.`view_seconds`, message.`allow_replay`, message.`opened_at`, message.`replayed_at`,
            message.`expires_at`, message.`created_at`, sender.`handle` AS `sender_handle`,
            sender.`display_name` AS `sender_display_name`, sender.`avatar_seed` AS `sender_avatar_seed`,
            sender.`snap_score` AS `sender_snap_score`, avatar.`url` AS `sender_avatar_url`
        FROM `sky_phone_skypic_messages` message
        JOIN `sky_phone_skypic_friendships` friendship
            ON friendship.`id` = message.`friendship_id` AND friendship.`status` = 'accepted'
        JOIN `sky_phone_skypic_profiles` sender
            ON sender.`id` = message.`sender_profile_id` AND sender.`status` = 'active'
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = sender.`avatar_media_id`
        WHERE message.`recipient_profile_id` = ?
            AND message.`message_type` IN ('snap_photo', 'snap_video')
            AND message.`deleted_at` IS NULL AND message.`recipient_deleted_at` IS NULL
            AND message.`expires_at` > CURRENT_TIMESTAMP(6)
            AND NOT EXISTS (
                SELECT 1 FROM `sky_phone_skypic_blocks` block
                WHERE (block.`blocker_profile_id` = ? AND block.`blocked_profile_id` = message.`sender_profile_id`)
                    OR (block.`blocker_profile_id` = message.`sender_profile_id` AND block.`blocked_profile_id` = ?)
            )
        ORDER BY message.`created_at` DESC
        LIMIT ?
    ]], { profile_id, profile_id, profile_id, limit("InboxPageSize", 100) })
    local inbox = {}
    for _, row in ipairs(rows) do
        inbox[#inbox + 1] = safe_snap_from_row(row, profile_id)
    end
    return inbox
end

local function list_stories(profile_id, offset)
    local rows = Bridge.Database.Query([[
        SELECT story.`id`, story.`profile_id`, story.`view_seconds`, story.`expires_at`, story.`created_at`,
            author.`handle`, author.`display_name`, author.`avatar_seed`, author.`snap_score`,
            avatar.`url` AS `avatar_url`,
            EXISTS(SELECT 1 FROM `sky_phone_skypic_story_views` view
                WHERE view.`story_id` = story.`id` AND view.`viewer_profile_id` = ?) AS `seen`,
            (SELECT COUNT(*) FROM `sky_phone_skypic_story_views` view
                WHERE view.`story_id` = story.`id`) AS `view_count`,
            friendship.`id` AS `friendship_id`
        FROM `sky_phone_skypic_stories` story
        JOIN `sky_phone_skypic_profiles` author
            ON author.`id` = story.`profile_id` AND author.`status` = 'active'
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = author.`avatar_media_id`
        LEFT JOIN `sky_phone_skypic_friendships` friendship
            ON friendship.`profile_a_id` = LEAST(?, story.`profile_id`)
            AND friendship.`profile_b_id` = GREATEST(?, story.`profile_id`)
            AND friendship.`status` = 'accepted'
        WHERE story.`status` = 'active' AND story.`expires_at` > CURRENT_TIMESTAMP(6)
            AND NOT EXISTS (
                SELECT 1 FROM `sky_phone_skypic_blocks` block
                WHERE (block.`blocker_profile_id` = ? AND block.`blocked_profile_id` = story.`profile_id`)
                    OR (block.`blocker_profile_id` = story.`profile_id` AND block.`blocked_profile_id` = ?)
            )
            AND (story.`profile_id` = ? OR story.`privacy` = 'everyone' OR friendship.`id` IS NOT NULL)
        ORDER BY (story.`profile_id` = ?) DESC, story.`created_at` DESC, story.`id` DESC
        LIMIT ? OFFSET ?
    ]], {
        profile_id, profile_id, profile_id, profile_id, profile_id, profile_id, profile_id,
        limit("PageSize", 30), offset or 0,
    })
    local stories = {}
    for _, row in ipairs(rows) do
        stories[#stories + 1] = {
            id = row.id,
            author = summary_from_row(
                row,
                row.profile_id == profile_id and "none" or (row.friendship_id and "friends" or "none"),
                row.friendship_id
            ),
            durationSeconds = tonumber(row.view_seconds) or limit("MinimumViewSeconds", 1),
            expiresAt = row.expires_at,
            createdAt = row.created_at,
            isOwner = row.profile_id == profile_id,
            seen = is_true(row.seen),
            viewCount = tonumber(row.view_count) or 0,
        }
    end
    return stories
end

local function list_conversations(profile_id)
    local rows = Bridge.Database.Query([[
        SELECT friendship.`id` AS `friendship_id`, friendship.`streak_count`, friendship.`best_streak`,
            peer.`id` AS `profile_id`, peer.`handle`, peer.`display_name`, peer.`avatar_seed`,
            peer.`snap_score`, avatar.`url` AS `avatar_url`, message.`id` AS `last_id`,
            message.`message_type` AS `last_type`,
            CASE WHEN message.`message_type` = 'text' THEN message.`body` ELSE NULL END AS `last_body`,
            message.`sender_profile_id` AS `last_sender_id`, message.`opened_at` AS `last_opened_at`,
            message.`created_at` AS `last_created_at`,
            (SELECT COUNT(*) FROM `sky_phone_skypic_messages` unread
                WHERE unread.`friendship_id` = friendship.`id`
                    AND unread.`recipient_profile_id` = ? AND unread.`deleted_at` IS NULL
                    AND unread.`recipient_deleted_at` IS NULL
                    AND (unread.`expires_at` IS NULL OR unread.`expires_at` > CURRENT_TIMESTAMP(6))
                    AND ((unread.`message_type` = 'text' AND unread.`read_at` IS NULL)
                        OR (unread.`message_type` IN ('snap_photo','snap_video') AND unread.`opened_at` IS NULL))) AS `unread_count`
        FROM `sky_phone_skypic_friendships` friendship
        JOIN `sky_phone_skypic_profiles` peer
            ON peer.`id` = CASE WHEN friendship.`profile_a_id` = ?
                THEN friendship.`profile_b_id` ELSE friendship.`profile_a_id` END
            AND peer.`status` = 'active'
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = peer.`avatar_media_id`
        LEFT JOIN `sky_phone_skypic_messages` message ON message.`id` = (
            SELECT candidate.`id` FROM `sky_phone_skypic_messages` candidate
            WHERE candidate.`friendship_id` = friendship.`id` AND candidate.`deleted_at` IS NULL
                AND ((candidate.`sender_profile_id` = ? AND candidate.`sender_deleted_at` IS NULL)
                    OR (candidate.`recipient_profile_id` = ? AND candidate.`recipient_deleted_at` IS NULL))
                AND (candidate.`expires_at` IS NULL OR candidate.`expires_at` > CURRENT_TIMESTAMP(6))
            ORDER BY candidate.`created_at` DESC, candidate.`id` DESC LIMIT 1
        )
        WHERE friendship.`status` = 'accepted'
            AND (friendship.`profile_a_id` = ? OR friendship.`profile_b_id` = ?)
            AND NOT EXISTS (
                SELECT 1 FROM `sky_phone_skypic_blocks` block
                WHERE (block.`blocker_profile_id` = ? AND block.`blocked_profile_id` = peer.`id`)
                    OR (block.`blocker_profile_id` = peer.`id` AND block.`blocked_profile_id` = ?)
            )
        ORDER BY message.`created_at` DESC, peer.`display_name`
        LIMIT ?
    ]], {
        profile_id, profile_id, profile_id, profile_id, profile_id, profile_id,
        profile_id, profile_id, limit("MaximumFriends", 500),
    })
    local conversations = {}
    for _, row in ipairs(rows) do
        local last_item = nil
        if row.last_id then
            last_item = {
                id = row.last_id,
                type = row.last_type,
                direction = row.last_sender_id == profile_id and "sent" or "received",
                openedAt = nullable(row.last_opened_at),
                createdAt = row.last_created_at,
            }
            if row.last_type == "text" then
                last_item.body = row.last_body or ""
            end
        end
        conversations[#conversations + 1] = {
            friendshipId = row.friendship_id,
            profile = summary_from_row(row, "friends", row.friendship_id),
            streakCount = tonumber(row.streak_count) or 0,
            bestStreak = tonumber(row.best_streak) or 0,
            unreadCount = tonumber(row.unread_count) or 0,
            lastItem = nullable(last_item),
        }
    end
    return conversations
end

Bridge.Callbacks.Register("sky_phone:skypic:bootstrap", function(source)
    if not SkyPhone.AllowOperation(source, "skypic_read", limit("ReadActionsPerMinute", 120), 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = optional_profile(source)
    if error_response then
        return error_response
    end
    if not profile then
        return { success = true, data = empty_bootstrap() }
    end
    local profile_id = profile.profile_id
    local conversations = list_conversations(profile_id)
    local unread_count = 0
    for _, conversation in ipairs(conversations) do
        unread_count = unread_count + conversation.unreadCount
    end
    return {
        success = true,
        data = {
            profile = profile_from_row(profile),
            blockedProfiles = list_blocked_profiles(profile_id),
            friends = list_friends(profile_id),
            requests = list_requests(profile_id),
            conversations = conversations,
            inbox = list_inbox(profile_id),
            stories = list_stories(profile_id, 0),
            suggestions = list_profiles(profile_id, "", true),
            unreadCount = unread_count,
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:skypic:create-profile", function(source, data)
    if not SkyPhone.AllowOperation(source, "skypic_profile", limit("ProfileActionsPerMinute", 10), 60) then
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
    if not valid_text(display_name, 1, limit("DisplayNameMaxLength", 40)) then
        return { success = false, error = "invalid_display_name" }
    end
    local avatar_seed = data.avatarSeed == nil and math.random(1, 2147483647)
        or valid_integer(data.avatarSeed, 1, 2147483647)
    if not avatar_seed then
        return { success = false, error = "invalid_avatar_seed" }
    end
    local avatar_media_id = nil
    if data.avatarMediaId ~= nil then
        avatar_media_id = valid_integer(data.avatarMediaId, 1, 9007199254740991)
        if not avatar_media_id or not SkyPhoneMedia.ResolveOwnedMedia(source, avatar_media_id, "photo") then
            return { success = false, error = "invalid_avatar" }
        end
    end
    if Bridge.Database.Query(
        "SELECT `id` FROM `sky_phone_skypic_profiles` WHERE `account_id` = ? LIMIT 1",
        { account.id }
    )[1] then
        return { success = false, error = "profile_exists" }
    end
    if Bridge.Database.Query(
        "SELECT `id` FROM `sky_phone_skypic_profiles` WHERE `handle` = ? LIMIT 1",
        { handle }
    )[1] then
        return { success = false, error = "handle_taken" }
    end
    local profile_id = new_id()
    local result = Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_skypic_profiles`
            (`id`, `account_id`, `handle`, `display_name`, `avatar_media_id`, `avatar_seed`)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { profile_id, account.id, handle, display_name, avatar_media_id, avatar_seed })
    if affected_rows(result) ~= 1 then
        return { success = false, error = "handle_taken" }
    end
    local created = require_profile(source)
    return { success = true, data = profile_from_row(created) }
end)

Bridge.Callbacks.Register("sky_phone:skypic:delete-account", function(source, data)
    if not SkyPhone.AllowOperation(source, "skypic_profile_delete", 3, 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, account, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    if type(data) ~= "table" or data.confirmed ~= true then
        return { success = false, error = "confirmation_required" }
    end
    local affected_accounts = Bridge.Database.Query([[
        SELECT DISTINCT affected.`account_id`
        FROM (
            SELECT peer.`account_id`
            FROM `sky_phone_skypic_friendships` friendship
            JOIN `sky_phone_skypic_profiles` peer
                ON peer.`id` = CASE
                    WHEN friendship.`profile_a_id` = ? THEN friendship.`profile_b_id`
                    ELSE friendship.`profile_a_id`
                END
                AND peer.`status` = 'active'
            WHERE friendship.`profile_a_id` = ? OR friendship.`profile_b_id` = ?
            UNION ALL
            SELECT peer.`account_id`
            FROM `sky_phone_skypic_blocks` block
            JOIN `sky_phone_skypic_profiles` peer
                ON peer.`id` = CASE
                    WHEN block.`blocker_profile_id` = ? THEN block.`blocked_profile_id`
                    ELSE block.`blocker_profile_id`
                END
                AND peer.`status` = 'active'
            WHERE block.`blocker_profile_id` = ? OR block.`blocked_profile_id` = ?
        ) affected
    ]], {
        profile.profile_id, profile.profile_id, profile.profile_id,
        profile.profile_id, profile.profile_id, profile.profile_id,
    })

    local ok = Bridge.Database.Transaction({
        {
            -- Keep the peers' denormalized limit counter correct before the
            -- friendship rows disappear through the profile cascade.
            query = [[
                UPDATE `sky_phone_skypic_profiles` peer
                JOIN `sky_phone_skypic_friendships` friendship
                    ON friendship.`status` = 'accepted'
                    AND (
                        (friendship.`profile_a_id` = ? AND peer.`id` = friendship.`profile_b_id`)
                        OR (friendship.`profile_b_id` = ? AND peer.`id` = friendship.`profile_a_id`)
                    )
                SET peer.`friend_count` = IF(
                    peer.`friend_count` > 0, peer.`friend_count` - 1, 0
                )
                WHERE peer.`id` <> ?
            ]],
            params = { profile.profile_id, profile.profile_id, profile.profile_id },
        },
        {
            query = [[
                DELETE FROM `sky_phone_skypic_profiles`
                WHERE `id` = ? AND `account_id` = ? AND `status` = 'active'
            ]],
            params = { profile.profile_id, account.id },
        },
    })
    if not ok then
        return { success = false, error = "request_failed" }
    end
    if Bridge.Database.Query(
        "SELECT `id` FROM `sky_phone_skypic_profiles` WHERE `id` = ? LIMIT 1",
        { profile.profile_id }
    )[1] then
        return { success = false, error = "request_failed" }
    end

    -- The generic media library belongs to the Sky account, not SkyPic. The
    -- cascading profile delete intentionally removes only SkyPic rows.
    SkyPhone.NotifyAccountDevices(account.id, "sky_phone:skypic:changed", {
        reason = "account_deleted",
        profileId = profile.profile_id,
    }, 'skypic')
    for _, affected in ipairs(affected_accounts) do
        local affected_account_id = tonumber(affected.account_id)
        if affected_account_id and affected_account_id ~= tonumber(account.id) then
            SkyPhone.NotifyAccountDevices(affected_account_id, "sky_phone:skypic:changed", {
                reason = "account_deleted",
                profileId = profile.profile_id,
            }, 'skypic')
        end
    end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:skypic:update-profile", function(source, data)
    if not SkyPhone.AllowOperation(source, "skypic_profile", limit("ProfileActionsPerMinute", 10), 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    if type(data) ~= "table" then
        return { success = false, error = "invalid_request" }
    end
    local handle = normalize_handle(data.handle)
    local display_name = trim(data.displayName)
    local bio = trim(data.bio)
    if not handle then
        return { success = false, error = "invalid_handle" }
    end
    if not valid_text(display_name, 1, limit("DisplayNameMaxLength", 40)) then
        return { success = false, error = "invalid_display_name" }
    end
    if not valid_text(bio, 0, limit("BioMaxLength", 160)) then
        return { success = false, error = "invalid_bio" }
    end
    if data.storyPrivacy ~= "friends" and data.storyPrivacy ~= "everyone" then
        return { success = false, error = "invalid_privacy" }
    end
    if type(data.showInQuickAdd) ~= "boolean" or type(data.allowStoryReplies) ~= "boolean" then
        return { success = false, error = "invalid_request" }
    end
    local avatar_seed = data.avatarSeed == nil and tonumber(profile.avatar_seed)
        or valid_integer(data.avatarSeed, 1, 2147483647)
    if not avatar_seed then
        return { success = false, error = "invalid_avatar_seed" }
    end
    local avatar_media_id = tonumber(profile.avatar_media_id)
    local avatar_value = rawget(data, "avatarMediaId")
    if avatar_value ~= nil then
        local is_null = type(json) == "table" and json.null ~= nil and avatar_value == json.null
        if is_null or avatar_value == false or avatar_value == 0 then
            avatar_media_id = nil
        else
            avatar_media_id = valid_integer(avatar_value, 1, 9007199254740991)
            if not avatar_media_id or not SkyPhoneMedia.ResolveOwnedMedia(source, avatar_media_id, "photo") then
                return { success = false, error = "invalid_avatar" }
            end
        end
    end
    if Bridge.Database.Query([[
        SELECT `id` FROM `sky_phone_skypic_profiles`
        WHERE `handle` = ? AND `id` <> ? LIMIT 1
    ]], { handle, profile.profile_id })[1] then
        return { success = false, error = "handle_taken" }
    end
    local result = Bridge.Database.Query([[
        UPDATE IGNORE `sky_phone_skypic_profiles`
        SET `handle` = ?, `display_name` = ?, `bio` = ?, `avatar_media_id` = ?, `avatar_seed` = ?,
            `story_privacy` = ?, `quick_add` = ?, `allow_story_replies` = ?
        WHERE `id` = ? AND `status` = 'active'
    ]], {
        handle, display_name, bio, avatar_media_id, avatar_seed, data.storyPrivacy,
        data.showInQuickAdd and 1 or 0, data.allowStoryReplies and 1 or 0, profile.profile_id,
    })
    if affected_rows(result) == 0 and handle ~= profile.handle then
        return { success = false, error = "handle_taken" }
    end
    local updated = require_profile(source)
    return { success = true, data = profile_from_row(updated) }
end)

Bridge.Callbacks.Register("sky_phone:skypic:search", function(source, data)
    if not SkyPhone.AllowOperation(source, "skypic_search", limit("SearchActionsPerMinute", 30), 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local query = trim(type(data) == "table" and data.query or nil)
    if not valid_text(query, 1, 64) then
        return { success = false, error = "invalid_request" }
    end
    return { success = true, data = list_profiles(profile.profile_id, query, false) }
end)

Bridge.Callbacks.Register("sky_phone:skypic:add-friend", function(source, data)
    if not SkyPhone.AllowOperation(source, "skypic_friend", limit("FriendActionsPerMinute", 30), 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local target_id = type(data) == "table" and data.profileId or nil
    if not valid_id(target_id) or target_id == profile.profile_id then
        return { success = false, error = "invalid_request" }
    end
    local target = load_summary(target_id, profile.profile_id)
    if not target then
        return { success = false, error = "profile_not_found" }
    end
    if are_blocked(profile.profile_id, target_id) then
        return { success = false, error = "blocked" }
    end
    local existing = friendship_with_target(profile.profile_id, target_id, false)
    if existing then
        return { success = false, error = "friend_request_exists" }
    end
    local own_friends = Bridge.Database.Query([[
        SELECT COUNT(*) AS `count` FROM `sky_phone_skypic_friendships`
        WHERE `status` = 'accepted' AND (`profile_a_id` = ? OR `profile_b_id` = ?)
    ]], { profile.profile_id, profile.profile_id })
    local target_friends = Bridge.Database.Query([[
        SELECT COUNT(*) AS `count` FROM `sky_phone_skypic_friendships`
        WHERE `status` = 'accepted' AND (`profile_a_id` = ? OR `profile_b_id` = ?)
    ]], { target_id, target_id })
    if (tonumber(own_friends[1] and own_friends[1].count) or 0) >= limit("MaximumFriends", 500)
        or (tonumber(target_friends[1] and target_friends[1].count) or 0) >= limit("MaximumFriends", 500)
    then
        return { success = false, error = "friend_limit_reached" }
    end
    local maximum_pending_requests = limit("MaximumPendingRequests", 100)
    local own_pending = Bridge.Database.Query([[
        SELECT COUNT(*) AS `count` FROM `sky_phone_skypic_friendships`
        WHERE `status` = 'pending' AND (`profile_a_id` = ? OR `profile_b_id` = ?)
    ]], { profile.profile_id, profile.profile_id })
    local target_pending = Bridge.Database.Query([[
        SELECT COUNT(*) AS `count` FROM `sky_phone_skypic_friendships`
        WHERE `status` = 'pending' AND (`profile_a_id` = ? OR `profile_b_id` = ?)
    ]], { target_id, target_id })
    if (tonumber(own_pending[1] and own_pending[1].count) or 0) >= maximum_pending_requests
        or (tonumber(target_pending[1] and target_pending[1].count) or 0) >= maximum_pending_requests
    then
        return { success = false, error = "request_limit_reached" }
    end
    local friendship_id = new_id()
    local profile_a_id, profile_b_id = normalized_pair(profile.profile_id, target_id)
    local ok = Bridge.Database.Transaction({
        {
            -- Serialize all cap-changing operations that involve either
            -- profile. InnoDB keeps these row locks until the transaction ends.
            query = [[
                UPDATE `sky_phone_skypic_profiles`
                SET `friend_count` = `friend_count`
                WHERE `id` IN (?, ?)
                ORDER BY `id`
            ]],
            params = { profile_a_id, profile_b_id },
        },
        {
            query = [[
                INSERT IGNORE INTO `sky_phone_skypic_friendships`
                    (`id`, `profile_a_id`, `profile_b_id`, `requested_by_id`, `status`)
                SELECT ?, ?, ?, ?, 'pending'
                WHERE NOT EXISTS (
                    SELECT 1 FROM `sky_phone_skypic_blocks`
                    WHERE (`blocker_profile_id` = ? AND `blocked_profile_id` = ?)
                        OR (`blocker_profile_id` = ? AND `blocked_profile_id` = ?)
                )
                    AND (
                        SELECT COUNT(*) FROM `sky_phone_skypic_friendships`
                        WHERE `status` = 'pending'
                            AND (`profile_a_id` = ? OR `profile_b_id` = ?)
                    ) < ?
                    AND (
                        SELECT COUNT(*) FROM `sky_phone_skypic_friendships`
                        WHERE `status` = 'pending'
                            AND (`profile_a_id` = ? OR `profile_b_id` = ?)
                    ) < ?
            ]],
            params = {
                friendship_id, profile_a_id, profile_b_id, profile.profile_id,
                profile.profile_id, target_id, target_id, profile.profile_id,
                profile.profile_id, profile.profile_id, maximum_pending_requests,
                target_id, target_id, maximum_pending_requests,
            },
        },
    })
    if not ok then
        return { success = false, error = "request_failed" }
    end
    local created_rows = Bridge.Database.Query([[
        SELECT `created_at` FROM `sky_phone_skypic_friendships` WHERE `id` = ? LIMIT 1
    ]], { friendship_id })
    if not created_rows[1] then
        local pending_counts = Bridge.Database.Query([[
            SELECT
                (SELECT COUNT(*) FROM `sky_phone_skypic_friendships`
                    WHERE `status` = 'pending'
                        AND (`profile_a_id` = ? OR `profile_b_id` = ?)) AS `own_count`,
                (SELECT COUNT(*) FROM `sky_phone_skypic_friendships`
                    WHERE `status` = 'pending'
                        AND (`profile_a_id` = ? OR `profile_b_id` = ?)) AS `target_count`
        ]], { profile.profile_id, profile.profile_id, target_id, target_id })
        if (tonumber(pending_counts[1] and pending_counts[1].own_count) or 0) >= maximum_pending_requests
            or (tonumber(pending_counts[1] and pending_counts[1].target_count) or 0) >= maximum_pending_requests
        then
            return { success = false, error = "request_limit_reached" }
        end
        if are_blocked(profile.profile_id, target_id) then
            return { success = false, error = "blocked" }
        end
        if friendship_with_target(profile.profile_id, target_id, false) then
            return { success = false, error = "friend_request_exists" }
        end
        return { success = false, error = "request_failed" }
    end
    notify_profile(target_id, profile, "friend_request", nil)
    target.friendshipId = friendship_id
    target.friendshipStatus = "outgoing"
    return {
        success = true,
        data = {
            friendshipId = friendship_id,
            createdAt = created_rows[1].created_at,
            direction = "outgoing",
            profile = target,
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:skypic:respond-friend", function(source, data)
    if not SkyPhone.AllowOperation(source, "skypic_friend", limit("FriendActionsPerMinute", 30), 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local friendship_id = type(data) == "table" and data.friendshipId or nil
    if not valid_id(friendship_id) or type(data.accept) ~= "boolean" then
        return { success = false, error = "invalid_request" }
    end
    if not data.accept then
        local result = Bridge.Database.Query([[
            DELETE FROM `sky_phone_skypic_friendships`
            WHERE `id` = ? AND `status` = 'pending' AND `requested_by_id` <> ?
                AND (`profile_a_id` = ? OR `profile_b_id` = ?)
        ]], { friendship_id, profile.profile_id, profile.profile_id, profile.profile_id })
        return affected_rows(result) == 1 and { success = true }
            or { success = false, error = "friendship_not_found" }
    end
    local maximum_friends = limit("MaximumFriends", 500)
    local result = Bridge.Database.Query([[
        UPDATE `sky_phone_skypic_friendships` friendship
        JOIN `sky_phone_skypic_profiles` profile_a
            ON profile_a.`id` = friendship.`profile_a_id`
        JOIN `sky_phone_skypic_profiles` profile_b
            ON profile_b.`id` = friendship.`profile_b_id`
        SET friendship.`status` = 'accepted',
            friendship.`accepted_at` = CURRENT_TIMESTAMP,
            profile_a.`friend_count` = profile_a.`friend_count` + 1,
            profile_b.`friend_count` = profile_b.`friend_count` + 1
        WHERE friendship.`id` = ? AND friendship.`status` = 'pending'
            AND friendship.`requested_by_id` <> ?
            AND (friendship.`profile_a_id` = ? OR friendship.`profile_b_id` = ?)
            AND profile_a.`friend_count` < ?
            AND profile_b.`friend_count` < ?
            AND NOT EXISTS (
                SELECT 1 FROM `sky_phone_skypic_blocks` block
                WHERE (block.`blocker_profile_id` = friendship.`profile_a_id` AND block.`blocked_profile_id` = friendship.`profile_b_id`)
                    OR (block.`blocker_profile_id` = friendship.`profile_b_id` AND block.`blocked_profile_id` = friendship.`profile_a_id`)
            )
    ]], {
        friendship_id, profile.profile_id, profile.profile_id, profile.profile_id,
        maximum_friends, maximum_friends,
    })
    if affected_rows(result) == 0 then
        local pending = Bridge.Database.Query([[
            SELECT profile_a.`friend_count` AS `profile_a_friend_count`,
                profile_b.`friend_count` AS `profile_b_friend_count`
            FROM `sky_phone_skypic_friendships` friendship
            JOIN `sky_phone_skypic_profiles` profile_a
                ON profile_a.`id` = friendship.`profile_a_id`
            JOIN `sky_phone_skypic_profiles` profile_b
                ON profile_b.`id` = friendship.`profile_b_id`
            WHERE friendship.`id` = ? AND friendship.`status` = 'pending'
                AND friendship.`requested_by_id` <> ?
                AND (friendship.`profile_a_id` = ? OR friendship.`profile_b_id` = ?)
            LIMIT 1
        ]], { friendship_id, profile.profile_id, profile.profile_id, profile.profile_id })
        if pending[1]
            and ((tonumber(pending[1].profile_a_friend_count) or 0) >= maximum_friends
                or (tonumber(pending[1].profile_b_friend_count) or 0) >= maximum_friends)
        then
            return { success = false, error = "friend_limit_reached" }
        end
        return { success = false, error = "friendship_not_found" }
    end
    local friendship = active_friendship(profile.profile_id, friendship_id)
    if not friendship then
        return { success = false, error = "request_failed" }
    end
    local peer = load_summary(friendship.peer_id, profile.profile_id)
    notify_profile(friendship.peer_id, profile, "friend_accepted", nil)
    return {
        success = true,
        data = {
            friendshipId = friendship.id,
            profile = peer,
            streakCount = tonumber(friendship.streak_count) or 0,
            bestStreak = tonumber(friendship.best_streak) or 0,
            createdAt = friendship.accepted_at or friendship.created_at,
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:skypic:remove-friend", function(source, data)
    if not SkyPhone.AllowOperation(source, "skypic_friend", limit("FriendActionsPerMinute", 30), 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local friendship_id = type(data) == "table" and data.friendshipId or nil
    if not valid_id(friendship_id) then
        return { success = false, error = "invalid_request" }
    end
    if not Bridge.Database.Query([[
        SELECT `id` FROM `sky_phone_skypic_friendships`
        WHERE `id` = ? AND (`profile_a_id` = ? OR `profile_b_id` = ?)
        LIMIT 1
    ]], { friendship_id, profile.profile_id, profile.profile_id })[1] then
        return { success = false, error = "friendship_not_found" }
    end
    local ok = Bridge.Database.Transaction({
        {
            query = [[
                UPDATE `sky_phone_skypic_profiles` profile
                JOIN `sky_phone_skypic_friendships` friendship
                    ON friendship.`id` = ? AND friendship.`status` = 'accepted'
                    AND (profile.`id` = friendship.`profile_a_id`
                        OR profile.`id` = friendship.`profile_b_id`)
                SET profile.`friend_count` = IF(
                    profile.`friend_count` > 0,
                    profile.`friend_count` - 1,
                    0
                )
                WHERE friendship.`profile_a_id` = ? OR friendship.`profile_b_id` = ?
            ]],
            params = { friendship_id, profile.profile_id, profile.profile_id },
        },
        {
            query = [[
                DELETE FROM `sky_phone_skypic_friendships`
                WHERE `id` = ? AND (`profile_a_id` = ? OR `profile_b_id` = ?)
            ]],
            params = { friendship_id, profile.profile_id, profile.profile_id },
        },
    })
    return ok and { success = true } or { success = false, error = "request_failed" }
end)

Bridge.Callbacks.Register("sky_phone:skypic:block", function(source, data)
    if not SkyPhone.AllowOperation(source, "skypic_friend", limit("FriendActionsPerMinute", 30), 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local target_id = type(data) == "table" and data.profileId or nil
    if not valid_id(target_id) or target_id == profile.profile_id or type(data.blocked) ~= "boolean" then
        return { success = false, error = "invalid_request" }
    end
    if not load_summary(target_id, profile.profile_id) then
        return { success = false, error = "profile_not_found" }
    end
    if not data.blocked then
        Bridge.Database.Query([[
            DELETE FROM `sky_phone_skypic_blocks`
            WHERE `blocker_profile_id` = ? AND `blocked_profile_id` = ?
        ]], { profile.profile_id, target_id })
        return { success = true }
    end
    local profile_a_id, profile_b_id = normalized_pair(profile.profile_id, target_id)
    local ok = Bridge.Database.Transaction({
        {
            query = [[
                INSERT IGNORE INTO `sky_phone_skypic_blocks`
                    (`blocker_profile_id`, `blocked_profile_id`) VALUES (?, ?)
            ]],
            params = { profile.profile_id, target_id },
        },
        {
            query = [[
                UPDATE `sky_phone_skypic_profiles` profile
                JOIN `sky_phone_skypic_friendships` friendship
                    ON friendship.`profile_a_id` = ? AND friendship.`profile_b_id` = ?
                    AND friendship.`status` = 'accepted'
                    AND (profile.`id` = friendship.`profile_a_id`
                        OR profile.`id` = friendship.`profile_b_id`)
                SET profile.`friend_count` = IF(
                    profile.`friend_count` > 0,
                    profile.`friend_count` - 1,
                    0
                )
            ]],
            params = { profile_a_id, profile_b_id },
        },
        {
            query = [[
                DELETE FROM `sky_phone_skypic_friendships`
                WHERE `profile_a_id` = ? AND `profile_b_id` = ?
            ]],
            params = { profile_a_id, profile_b_id },
        },
    })
    return ok and { success = true } or { success = false, error = "request_failed" }
end)

local function list_thread(profile_id, friendship_id)
    local rows = Bridge.Database.Query([[
        SELECT message.`id`, message.`friendship_id`, message.`sender_profile_id`, message.`message_type`,
            message.`body`, message.`view_seconds`, message.`allow_replay`, message.`read_at`,
            message.`opened_at`, message.`replayed_at`, message.`saved_at`, message.`expires_at`,
            message.`created_at`, sender.`handle` AS `sender_handle`,
            sender.`display_name` AS `sender_display_name`, sender.`avatar_seed` AS `sender_avatar_seed`,
            sender.`snap_score` AS `sender_snap_score`, avatar.`url` AS `sender_avatar_url`
        FROM `sky_phone_skypic_messages` message
        JOIN `sky_phone_skypic_profiles` sender ON sender.`id` = message.`sender_profile_id`
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = sender.`avatar_media_id`
        WHERE message.`friendship_id` = ? AND message.`deleted_at` IS NULL
            AND ((message.`sender_profile_id` = ? AND message.`sender_deleted_at` IS NULL)
                OR (message.`recipient_profile_id` = ? AND message.`recipient_deleted_at` IS NULL))
            AND (message.`expires_at` IS NULL OR message.`expires_at` > CURRENT_TIMESTAMP(6))
        ORDER BY message.`created_at` DESC, message.`id` DESC
        LIMIT ?
    ]], { friendship_id, profile_id, profile_id, limit("ThreadPageSize", 200) })
    local messages = {}
    local snaps = {}
    for index = #rows, 1, -1 do
        local row = rows[index]
        if row.message_type == "text" then
            messages[#messages + 1] = text_message_from_row(row, profile_id)
        else
            snaps[#snaps + 1] = safe_snap_from_row(row, profile_id)
        end
    end
    return { messages = messages, snaps = snaps }
end

local function editor_payload(source, data, allow_replay)
    if type(data) ~= "table" then
        return nil, "invalid_request"
    end
    if data.mediaType ~= "photo" and data.mediaType ~= "video" then
        return nil, "invalid_media_type"
    end
    local media_id = valid_integer(data.mediaId, 1, 9007199254740991)
    if not media_id then
        return nil, "invalid_media"
    end
    local duration = valid_integer(
        data.durationSeconds,
        limit("MinimumViewSeconds", 1),
        limit("MaximumViewSeconds", 10)
    )
    if not duration then
        return nil, "invalid_duration"
    end
    local caption = trim(data.caption)
    if not valid_text(caption, 0, limit("CaptionMaxLength", 160)) then
        return nil, "invalid_caption"
    end
    local overlay_text = trim(data.textOverlay)
    if not valid_text(overlay_text, 0, limit("OverlayTextMaxLength", 160)) then
        return nil, "invalid_overlay"
    end
    local overlay_color = normalize_color(data.overlayColor)
    if not overlay_color then
        return nil, "invalid_color"
    end
    if allow_replay and type(data.allowReplay) ~= "boolean" then
        return nil, "invalid_request"
    end
    local url, _, mime_type = SkyPhoneMedia.ResolveOwnedMedia(source, media_id, data.mediaType)
    if not url then
        return nil, "invalid_media"
    end
    return {
        mediaId = media_id,
        mediaType = data.mediaType,
        messageType = data.mediaType == "photo" and "snap_photo" or "snap_video",
        durationSeconds = duration,
        caption = caption,
        textOverlay = overlay_text,
        overlayColor = overlay_color,
        allowReplay = allow_replay and data.allowReplay or false,
        mimeType = mime_type,
    }
end

local function snap_editor_payloads(source, data)
    if type(data) ~= "table" then
        return nil, "invalid_request"
    end
    if data.mediaIds == nil then
        local editor, editor_error = editor_payload(source, data, true)
        return editor and { editor } or nil, editor_error
    end
    if data.mediaId ~= nil or (data.mediaType ~= nil and data.mediaType ~= "photo") then
        return nil, "invalid_media"
    end
    if type(data.mediaIds) ~= "table" then
        return nil, "invalid_media"
    end

    local count = #data.mediaIds
    if count < 1 or count > limit("MaximumMediaPerSend", 10) then
        return nil, "invalid_media"
    end
    local key_count = 0
    for key in pairs(data.mediaIds) do
        if type(key) ~= "number" or key ~= math.floor(key) or key < 1 or key > count then
            return nil, "invalid_media"
        end
        key_count = key_count + 1
    end
    if key_count ~= count then
        return nil, "invalid_media"
    end

    local seen = {}
    local editors = {}
    for index = 1, count do
        local media_id = valid_integer(data.mediaIds[index], 1, 9007199254740991)
        if not media_id or seen[media_id] then
            return nil, "invalid_media"
        end
        seen[media_id] = true
        local editor, editor_error = editor_payload(source, {
            mediaId = media_id,
            mediaType = "photo",
            durationSeconds = data.durationSeconds,
            caption = data.caption,
            textOverlay = data.textOverlay,
            overlayColor = data.overlayColor,
            allowReplay = data.allowReplay,
        }, true)
        if not editor then
            return nil, editor_error
        end
        editors[#editors + 1] = editor
    end
    return editors
end

Bridge.Callbacks.Register("sky_phone:skypic:thread", function(source, data)
    if not SkyPhone.AllowOperation(source, "skypic_read", limit("ReadActionsPerMinute", 120), 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local friendship_id = type(data) == "table" and data.friendshipId or nil
    if not valid_id(friendship_id) then
        return { success = false, error = "invalid_request" }
    end
    if not active_friendship(profile.profile_id, friendship_id) then
        return { success = false, error = "friendship_not_found" }
    end
    return { success = true, data = list_thread(profile.profile_id, friendship_id) }
end)

Bridge.Callbacks.Register("sky_phone:skypic:send-message", function(source, data)
    if not SkyPhone.AllowOperation(source, "skypic_message", limit("MessagesPerMinute", 30), 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local friendship_id = type(data) == "table" and data.friendshipId or nil
    local body = trim(type(data) == "table" and data.body or nil)
    local story_id = type(data) == "table" and data.storyId or nil
    if not valid_id(friendship_id) then
        return { success = false, error = "invalid_request" }
    end
    if story_id ~= nil and not valid_id(story_id) then
        return { success = false, error = "invalid_request" }
    end
    local body_length = text_length(body)
    if not body_length or body_length < 1 then
        return { success = false, error = "message_empty" }
    end
    if body_length > limit("MessageMaxLength", 2000) then
        return { success = false, error = "message_too_long" }
    end
    local friendship = active_friendship(profile.profile_id, friendship_id)
    if not friendship then
        return { success = false, error = "friendship_not_found" }
    end
    local message_id = new_id()
    local insert_query = [[
        INSERT INTO `sky_phone_skypic_messages`
            (`id`, `friendship_id`, `sender_profile_id`, `recipient_profile_id`, `message_type`, `body`)
        SELECT ?, friendship.`id`, ?, ?, 'text', ?
        FROM `sky_phone_skypic_friendships` friendship
        WHERE friendship.`id` = ? AND friendship.`status` = 'accepted'
            AND NOT EXISTS (
                SELECT 1 FROM `sky_phone_skypic_blocks` block
                WHERE (block.`blocker_profile_id` = ? AND block.`blocked_profile_id` = ?)
                    OR (block.`blocker_profile_id` = ? AND block.`blocked_profile_id` = ?)
            )
    ]]
    local insert_params = {
        message_id, profile.profile_id, friendship.peer_id, body, friendship_id,
        profile.profile_id, friendship.peer_id, friendship.peer_id, profile.profile_id,
    }
    if story_id ~= nil then
        insert_query = [[
            INSERT INTO `sky_phone_skypic_messages`
                (`id`, `friendship_id`, `sender_profile_id`, `recipient_profile_id`, `message_type`, `body`)
            SELECT ?, friendship.`id`, ?, ?, 'text', ?
            FROM `sky_phone_skypic_friendships` friendship
            JOIN `sky_phone_skypic_stories` story
                ON story.`id` = ? AND story.`profile_id` = ?
                AND story.`status` = 'active' AND story.`expires_at` > CURRENT_TIMESTAMP(6)
            JOIN `sky_phone_skypic_profiles` author
                ON author.`id` = story.`profile_id` AND author.`status` = 'active'
                AND author.`allow_story_replies` = 1
            WHERE friendship.`id` = ? AND friendship.`status` = 'accepted'
                AND ((friendship.`profile_a_id` = ? AND friendship.`profile_b_id` = ?)
                    OR (friendship.`profile_a_id` = ? AND friendship.`profile_b_id` = ?))
                AND NOT EXISTS (
                    SELECT 1 FROM `sky_phone_skypic_blocks` block
                    WHERE (block.`blocker_profile_id` = ? AND block.`blocked_profile_id` = ?)
                        OR (block.`blocker_profile_id` = ? AND block.`blocked_profile_id` = ?)
                )
        ]]
        insert_params = {
            message_id, profile.profile_id, friendship.peer_id, body, story_id, friendship.peer_id,
            friendship_id, profile.profile_id, friendship.peer_id, friendship.peer_id, profile.profile_id,
            profile.profile_id, friendship.peer_id, friendship.peer_id, profile.profile_id,
        }
    end
    local result = Bridge.Database.Query(insert_query, insert_params)
    if affected_rows(result) ~= 1 then
        return { success = false, error = story_id and "story_unavailable" or "blocked" }
    end
    local rows = Bridge.Database.Query([[
        SELECT `id`, `friendship_id`, `sender_profile_id`, `body`, `read_at`, `saved_at`, `created_at`
        FROM `sky_phone_skypic_messages` WHERE `id` = ? LIMIT 1
    ]], { message_id })
    if not rows[1] then
        return { success = false, error = "request_failed" }
    end
    notify_profile(friendship.peer_id, profile, story_id and "story_reply" or "message", nil)
    return { success = true, data = text_message_from_row(rows[1], profile.profile_id) }
end)

Bridge.Callbacks.Register("sky_phone:skypic:mark-thread", function(source, data)
    if not SkyPhone.AllowOperation(source, "skypic_open", limit("OpensPerMinute", 120), 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local friendship_id = type(data) == "table" and data.friendshipId or nil
    if not valid_id(friendship_id) then
        return { success = false, error = "invalid_request" }
    end
    if not active_friendship(profile.profile_id, friendship_id) then
        return { success = false, error = "friendship_not_found" }
    end
    Bridge.Database.Query([[
        UPDATE `sky_phone_skypic_messages`
        SET `read_at` = CURRENT_TIMESTAMP(6),
            `expires_at` = CASE WHEN `saved_at` IS NULL
                THEN DATE_ADD(CURRENT_TIMESTAMP(6), INTERVAL ? SECOND) ELSE NULL END
        WHERE `friendship_id` = ? AND `recipient_profile_id` = ? AND `message_type` = 'text'
            AND `read_at` IS NULL AND `deleted_at` IS NULL AND `recipient_deleted_at` IS NULL
    ]], { limit("TextAfterReadLifetimeSeconds", 86400), friendship_id, profile.profile_id })
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:skypic:save-message", function(source, data)
    if not SkyPhone.AllowOperation(source, "skypic_message", limit("MessagesPerMinute", 30), 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local message_id = type(data) == "table" and data.messageId or nil
    if not valid_id(message_id) or type(data.saved) ~= "boolean" then
        return { success = false, error = "invalid_request" }
    end
    local result = Bridge.Database.Query([[
        UPDATE `sky_phone_skypic_messages` message
        JOIN `sky_phone_skypic_friendships` friendship
            ON friendship.`id` = message.`friendship_id` AND friendship.`status` = 'accepted'
        SET message.`saved_at` = CASE WHEN ? = 1 THEN CURRENT_TIMESTAMP(6) ELSE NULL END,
            message.`expires_at` = CASE
                WHEN ? = 1 THEN NULL
                WHEN message.`read_at` IS NOT NULL THEN DATE_ADD(CURRENT_TIMESTAMP(6), INTERVAL ? SECOND)
                ELSE NULL
            END
        WHERE message.`id` = ? AND message.`message_type` = 'text' AND message.`deleted_at` IS NULL
            AND ((message.`sender_profile_id` = ? AND message.`sender_deleted_at` IS NULL)
                OR (message.`recipient_profile_id` = ? AND message.`recipient_deleted_at` IS NULL))
            AND NOT EXISTS (
                SELECT 1 FROM `sky_phone_skypic_blocks` block
                WHERE (block.`blocker_profile_id` = message.`sender_profile_id` AND block.`blocked_profile_id` = message.`recipient_profile_id`)
                    OR (block.`blocker_profile_id` = message.`recipient_profile_id` AND block.`blocked_profile_id` = message.`sender_profile_id`)
            )
    ]], {
        data.saved and 1 or 0, data.saved and 1 or 0, limit("TextAfterReadLifetimeSeconds", 86400),
        message_id, profile.profile_id, profile.profile_id,
    })
    if affected_rows(result) ~= 1 then
        return { success = false, error = "message_not_found" }
    end
    local rows = Bridge.Database.Query([[
        SELECT `id`, `friendship_id`, `sender_profile_id`, `body`, `read_at`, `saved_at`, `created_at`
        FROM `sky_phone_skypic_messages` WHERE `id` = ? LIMIT 1
    ]], { message_id })
    return rows[1] and { success = true, data = text_message_from_row(rows[1], profile.profile_id) }
        or { success = false, error = "message_not_found" }
end)

Bridge.Callbacks.Register("sky_phone:skypic:delete-message", function(source, data)
    if not SkyPhone.AllowOperation(source, "skypic_message", limit("MessagesPerMinute", 30), 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local message_id = type(data) == "table" and data.messageId or nil
    if not valid_id(message_id) or type(data.forEveryone) ~= "boolean" then
        return { success = false, error = "invalid_request" }
    end
    local result
    if data.forEveryone then
        result = Bridge.Database.Query([[
            UPDATE `sky_phone_skypic_messages`
            SET `deleted_at` = CURRENT_TIMESTAMP(6)
            WHERE `id` = ? AND `sender_profile_id` = ? AND `deleted_at` IS NULL
        ]], { message_id, profile.profile_id })
    else
        result = Bridge.Database.Query([[
            UPDATE `sky_phone_skypic_messages`
            SET `sender_deleted_at` = CASE WHEN `sender_profile_id` = ? THEN CURRENT_TIMESTAMP(6) ELSE `sender_deleted_at` END,
                `recipient_deleted_at` = CASE WHEN `recipient_profile_id` = ? THEN CURRENT_TIMESTAMP(6) ELSE `recipient_deleted_at` END
            WHERE `id` = ? AND `deleted_at` IS NULL
                AND ((`sender_profile_id` = ? AND `sender_deleted_at` IS NULL)
                    OR (`recipient_profile_id` = ? AND `recipient_deleted_at` IS NULL))
        ]], {
            profile.profile_id, profile.profile_id, message_id, profile.profile_id, profile.profile_id,
        })
    end
    return affected_rows(result) == 1 and { success = true }
        or { success = false, error = "message_not_found" }
end)

local function recipient_ids(value)
    if type(value) ~= "table" then
        return nil
    end
    local count = #value
    if count < 1 or count > limit("MaximumSnapRecipients", 20) then
        return nil
    end
    local key_count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key ~= math.floor(key) or key < 1 or key > count then
            return nil
        end
        key_count = key_count + 1
    end
    if key_count ~= count then
        return nil
    end
    local seen = {}
    local ids = {}
    for index = 1, count do
        local profile_id = value[index]
        if not valid_id(profile_id) or seen[profile_id] then
            return nil
        end
        seen[profile_id] = true
        ids[#ids + 1] = profile_id
    end
    return ids
end

local function load_snap_metadata(message_ids, viewer_id)
    if #message_ids == 0 then
        return {}
    end
    local placeholders = {}
    local params = {}
    for _, message_id in ipairs(message_ids) do
        placeholders[#placeholders + 1] = "?"
        params[#params + 1] = message_id
    end
    local rows = Bridge.Database.Query(([[
        SELECT message.`id`, message.`friendship_id`, message.`sender_profile_id`, message.`recipient_profile_id`,
            message.`message_type`, message.`view_seconds`, message.`allow_replay`, message.`opened_at`,
            message.`replayed_at`, message.`expires_at`, message.`created_at`, sender.`handle` AS `sender_handle`,
            sender.`display_name` AS `sender_display_name`, sender.`avatar_seed` AS `sender_avatar_seed`,
            sender.`snap_score` AS `sender_snap_score`, avatar.`url` AS `sender_avatar_url`
        FROM `sky_phone_skypic_messages` message
        JOIN `sky_phone_skypic_profiles` sender ON sender.`id` = message.`sender_profile_id`
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = sender.`avatar_media_id`
        WHERE message.`id` IN (%s) AND message.`message_type` IN ('snap_photo','snap_video')
        ORDER BY message.`created_at`, message.`id`
    ]]):format(table.concat(placeholders, ",")), params)
    local snaps_by_id = {}
    for _, row in ipairs(rows) do
        local snap = safe_snap_from_row(row, viewer_id)
        snap.recipientProfileId = row.recipient_profile_id
        snaps_by_id[row.id] = snap
    end
    local snaps = {}
    for _, message_id in ipairs(message_ids) do
        if snaps_by_id[message_id] then
            snaps[#snaps + 1] = snaps_by_id[message_id]
        end
    end
    return snaps
end

local function opened_snap_from_row(row)
    return {
        id = row.id,
        url = row.url,
        mediaType = row.message_type == "snap_photo" and "photo" or "video",
        mimeType = nullable(row.mime_type),
        caption = row.caption or "",
        textOverlay = row.overlay_text or "",
        overlayColor = row.overlay_color,
        durationSeconds = tonumber(row.view_seconds) or limit("MinimumViewSeconds", 1),
        allowReplay = is_true(row.allow_replay),
        openedAt = row.opened_at,
        replayedAt = nullable(row.replayed_at),
        expiresAt = row.expires_at,
    }
end

local function released_snap(message_id, recipient_profile_id)
    local rows = Bridge.Database.Query([[
        SELECT message.`id`, message.`sender_profile_id`, message.`message_type`, message.`caption`,
            message.`overlay_text`, message.`overlay_color`, message.`view_seconds`, message.`allow_replay`,
            message.`opened_at`, message.`replayed_at`, message.`expires_at`, media.`url`, media.`mime_type`
        FROM `sky_phone_skypic_messages` message
        JOIN `sky_phone_skypic_friendships` friendship
            ON friendship.`id` = message.`friendship_id` AND friendship.`status` = 'accepted'
        JOIN `sky_phone_media` media ON media.`id` = message.`media_id`
        WHERE message.`id` = ? AND message.`recipient_profile_id` = ?
            AND message.`message_type` IN ('snap_photo','snap_video')
            AND message.`opened_at` IS NOT NULL AND message.`deleted_at` IS NULL
            AND message.`recipient_deleted_at` IS NULL AND message.`expires_at` > CURRENT_TIMESTAMP(6)
            AND NOT EXISTS (
                SELECT 1 FROM `sky_phone_skypic_blocks` block
                WHERE (block.`blocker_profile_id` = message.`sender_profile_id` AND block.`blocked_profile_id` = message.`recipient_profile_id`)
                    OR (block.`blocker_profile_id` = message.`recipient_profile_id` AND block.`blocked_profile_id` = message.`sender_profile_id`)
            )
        LIMIT 1
    ]], { message_id, recipient_profile_id })
    return rows[1]
end

Bridge.Callbacks.Register("sky_phone:skypic:send-snap", function(source, data)
    if not SkyPhone.AllowOperation(source, "skypic_snap", limit("SnapsPerMinute", 20), 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local recipients = recipient_ids(type(data) == "table" and data.recipientIds or nil)
    if not recipients then
        return { success = false, error = "invalid_recipients" }
    end
    if type(data) == "table" and data.mediaIds ~= nil then
        local raw_media_count = type(data.mediaIds) == "table" and #data.mediaIds or 0
        if raw_media_count < 1 or raw_media_count > limit("MaximumMediaPerSend", 10) then
            return { success = false, error = "invalid_media" }
        end
    end
    local requested_media_count = type(data) == "table"
        and type(data.mediaIds) == "table" and #data.mediaIds or 1
    if requested_media_count * #recipients > limit("MaximumSnapMessagesPerSend", 40) then
        return { success = false, error = "too_many_snaps" }
    end
    local editors, editor_error = snap_editor_payloads(source, data)
    if not editors then
        return { success = false, error = editor_error }
    end
    local message_count = #editors * #recipients
    if message_count > limit("MaximumSnapMessagesPerSend", 40) then
        return { success = false, error = "too_many_snaps" }
    end
    for _ = 2, #editors do
        if not SkyPhone.AllowOperation(source, "skypic_snap", limit("SnapsPerMinute", 20), 60) then
            return { success = false, error = "rate_limited" }
        end
    end
    for _ = 1, message_count do
        if not SkyPhone.AllowOperation(
            source,
            "skypic_snap_recipient",
            limit("SnapRecipientsPerMinute", 120),
            60
        ) then
            return { success = false, error = "rate_limited" }
        end
    end
    local entries = {}
    for _, target_id in ipairs(recipients) do
        if target_id == profile.profile_id then
            return { success = false, error = "invalid_recipients" }
        end
        local friendship = friendship_with_target(profile.profile_id, target_id, true)
        if not friendship then
            return { success = false, error = "friendship_not_found" }
        end
        if are_blocked(profile.profile_id, target_id) then
            return { success = false, error = "blocked" }
        end
        for _, editor in ipairs(editors) do
            entries[#entries + 1] = {
                id = new_id(),
                targetId = target_id,
                friendship = friendship,
                editor = editor,
            }
        end
    end
    local statements = {}
    for _, entry in ipairs(entries) do
        local editor = entry.editor
        statements[#statements + 1] = {
            query = [[
                INSERT INTO `sky_phone_skypic_messages`
                    (`id`, `friendship_id`, `sender_profile_id`, `recipient_profile_id`, `message_type`,
                        `caption`, `overlay_text`, `overlay_color`, `media_id`, `view_seconds`, `allow_replay`, `expires_at`)
                SELECT ?, friendship.`id`, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                    DATE_ADD(CURRENT_TIMESTAMP(6), INTERVAL ? SECOND)
                FROM `sky_phone_skypic_friendships` friendship
                WHERE friendship.`id` = ? AND friendship.`status` = 'accepted'
                    AND ((friendship.`profile_a_id` = ? AND friendship.`profile_b_id` = ?)
                        OR (friendship.`profile_a_id` = ? AND friendship.`profile_b_id` = ?))
                    AND NOT EXISTS (
                        SELECT 1 FROM `sky_phone_skypic_blocks` block
                        WHERE (block.`blocker_profile_id` = ? AND block.`blocked_profile_id` = ?)
                            OR (block.`blocker_profile_id` = ? AND block.`blocked_profile_id` = ?)
                    )
            ]],
            params = {
                entry.id, profile.profile_id, entry.targetId, editor.messageType, editor.caption,
                editor.textOverlay, editor.overlayColor, editor.mediaId, editor.durationSeconds,
                editor.allowReplay and 1 or 0, limit("UnopenedSnapLifetimeSeconds", 2592000),
                entry.friendship.id, profile.profile_id, entry.targetId, entry.targetId, profile.profile_id,
                profile.profile_id, entry.targetId, entry.targetId, profile.profile_id,
            },
        }
        local directional_column = entry.friendship.profile_a_id == profile.profile_id
            and "`profile_a_last_snap_on`" or "`profile_b_last_snap_on`"
        statements[#statements + 1] = {
            query = ([=[
                UPDATE `sky_phone_skypic_friendships`
                SET %s = UTC_DATE()
                WHERE `id` = ? AND EXISTS (
                    SELECT 1 FROM `sky_phone_skypic_messages` message WHERE message.`id` = ?
                )
            ]=]):format(directional_column),
            params = { entry.friendship.id, entry.id },
        }
        statements[#statements + 1] = {
            query = [[
                UPDATE `sky_phone_skypic_friendships`
                SET `best_streak` = GREATEST(`best_streak`,
                        CASE WHEN `streak_updated_on` = DATE_SUB(UTC_DATE(), INTERVAL 1 DAY)
                            THEN `streak_count` + 1 ELSE 1 END),
                    `streak_count` = CASE WHEN `streak_updated_on` = DATE_SUB(UTC_DATE(), INTERVAL 1 DAY)
                        THEN `streak_count` + 1 ELSE 1 END,
                    `streak_updated_on` = UTC_DATE()
                WHERE `id` = ? AND `profile_a_last_snap_on` = UTC_DATE()
                    AND `profile_b_last_snap_on` = UTC_DATE()
                    AND (`streak_updated_on` IS NULL OR `streak_updated_on` < UTC_DATE())
            ]],
            params = { entry.friendship.id },
        }
    end
    local assertion_placeholders = {}
    local assertion_params = { profile.profile_id }
    for _, entry in ipairs(entries) do
        assertion_placeholders[#assertion_placeholders + 1] = "?"
        assertion_params[#assertion_params + 1] = entry.id
    end
    assertion_params[#assertion_params + 1] = #entries
    statements[#statements + 1] = {
        -- A mismatch deliberately attempts to duplicate the sender profile.
        -- The primary-key error makes oxmysql roll the whole transaction back,
        -- including earlier inserts and streak mutations.
        query = (([[
            INSERT INTO `sky_phone_skypic_profiles`
                (`id`, `account_id`, `handle`, `display_name`, `avatar_seed`)
            SELECT profile.`id`, profile.`account_id`, profile.`handle`,
                profile.`display_name`, profile.`avatar_seed`
            FROM `sky_phone_skypic_profiles` profile
            WHERE profile.`id` = ?
                AND (
                    SELECT COUNT(*) FROM `sky_phone_skypic_messages`
                    WHERE `id` IN (%s)
                ) <> ?
        ]]):format(table.concat(assertion_placeholders, ", "))),
        params = assertion_params,
    }
    if not Bridge.Database.Transaction(statements) then
        return { success = false, error = "request_failed" }
    end
    local message_ids = {}
    for _, entry in ipairs(entries) do
        message_ids[#message_ids + 1] = entry.id
    end
    local sent = load_snap_metadata(message_ids, profile.profile_id)
    if #sent ~= #entries then
        return { success = false, error = "request_failed" }
    end
    Bridge.Database.Query([[
        UPDATE `sky_phone_skypic_profiles` SET `snap_score` = `snap_score` + ? WHERE `id` = ?
    ]], { #sent, profile.profile_id })
    local sender_score = (tonumber(profile.snap_score) or 0) + #sent
    local notified_targets = {}
    for _, snap in ipairs(sent) do
        local target_id = snap.recipientProfileId
        snap.recipientProfileId = nil
        snap.sender.snapScore = sender_score
        if not notified_targets[target_id] then
            notified_targets[target_id] = true
            notify_profile(target_id, profile, "snap", snap.id)
        end
    end
    return { success = true, data = sent }
end)

Bridge.Callbacks.Register("sky_phone:skypic:open-snap", function(source, data)
    if not SkyPhone.AllowOperation(source, "skypic_open", limit("OpensPerMinute", 120), 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local snap_id = type(data) == "table" and data.snapId or nil
    if not valid_id(snap_id) then
        return { success = false, error = "invalid_request" }
    end
    local result = Bridge.Database.Query([[
        UPDATE `sky_phone_skypic_messages` message
        JOIN `sky_phone_skypic_friendships` friendship
            ON friendship.`id` = message.`friendship_id` AND friendship.`status` = 'accepted'
        SET message.`opened_at` = CURRENT_TIMESTAMP(6), message.`read_at` = CURRENT_TIMESTAMP(6),
            message.`expires_at` = TIMESTAMPADD(
                SECOND,
                IF(message.`allow_replay` = 1, ?, message.`view_seconds`),
                CURRENT_TIMESTAMP(6)
            )
        WHERE message.`id` = ? AND message.`recipient_profile_id` = ?
            AND message.`message_type` IN ('snap_photo','snap_video')
            AND message.`opened_at` IS NULL AND message.`deleted_at` IS NULL
            AND message.`recipient_deleted_at` IS NULL AND message.`expires_at` > CURRENT_TIMESTAMP(6)
            AND NOT EXISTS (
                SELECT 1 FROM `sky_phone_skypic_blocks` block
                WHERE (block.`blocker_profile_id` = message.`sender_profile_id` AND block.`blocked_profile_id` = message.`recipient_profile_id`)
                    OR (block.`blocker_profile_id` = message.`recipient_profile_id` AND block.`blocked_profile_id` = message.`sender_profile_id`)
            )
    ]], { limit("ReplayWindowSeconds", 300), snap_id, profile.profile_id })
    if affected_rows(result) ~= 1 then
        return { success = false, error = "snap_unavailable" }
    end
    local row = released_snap(snap_id, profile.profile_id)
    if not row then
        return { success = false, error = "snap_unavailable" }
    end
    Bridge.Database.Query([[
        UPDATE `sky_phone_skypic_profiles` SET `snap_score` = `snap_score` + 1 WHERE `id` = ?
    ]], { profile.profile_id })
    notify_profile(row.sender_profile_id, profile, "snap_opened", snap_id)
    return { success = true, data = opened_snap_from_row(row) }
end)

Bridge.Callbacks.Register("sky_phone:skypic:replay-snap", function(source, data)
    if not SkyPhone.AllowOperation(source, "skypic_open", limit("OpensPerMinute", 120), 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local snap_id = type(data) == "table" and data.snapId or nil
    if not valid_id(snap_id) then
        return { success = false, error = "invalid_request" }
    end
    local result = Bridge.Database.Query([[
        UPDATE `sky_phone_skypic_messages` message
        JOIN `sky_phone_skypic_friendships` friendship
            ON friendship.`id` = message.`friendship_id` AND friendship.`status` = 'accepted'
        SET message.`replayed_at` = CURRENT_TIMESTAMP(6),
            message.`expires_at` = DATE_ADD(CURRENT_TIMESTAMP(6), INTERVAL message.`view_seconds` SECOND)
        WHERE message.`id` = ? AND message.`recipient_profile_id` = ?
            AND message.`message_type` IN ('snap_photo','snap_video') AND message.`allow_replay` = 1
            AND message.`opened_at` IS NOT NULL AND message.`replayed_at` IS NULL
            AND message.`deleted_at` IS NULL AND message.`recipient_deleted_at` IS NULL
            AND message.`expires_at` > CURRENT_TIMESTAMP(6)
            AND NOT EXISTS (
                SELECT 1 FROM `sky_phone_skypic_blocks` block
                WHERE (block.`blocker_profile_id` = message.`sender_profile_id` AND block.`blocked_profile_id` = message.`recipient_profile_id`)
                    OR (block.`blocker_profile_id` = message.`recipient_profile_id` AND block.`blocked_profile_id` = message.`sender_profile_id`)
            )
    ]], { snap_id, profile.profile_id })
    if affected_rows(result) ~= 1 then
        return { success = false, error = "replay_unavailable" }
    end
    local row = released_snap(snap_id, profile.profile_id)
    return row and { success = true, data = opened_snap_from_row(row) }
        or { success = false, error = "replay_unavailable" }
end)

local function own_story_metadata(story_id, profile_id)
    local rows = Bridge.Database.Query([[
        SELECT story.`id`, story.`profile_id`, story.`view_seconds`, story.`expires_at`, story.`created_at`,
            author.`handle`, author.`display_name`, author.`avatar_seed`, author.`snap_score`,
            avatar.`url` AS `avatar_url`,
            EXISTS(SELECT 1 FROM `sky_phone_skypic_story_views` view
                WHERE view.`story_id` = story.`id` AND view.`viewer_profile_id` = ?) AS `seen`,
            (SELECT COUNT(*) FROM `sky_phone_skypic_story_views` view
                WHERE view.`story_id` = story.`id`) AS `view_count`
        FROM `sky_phone_skypic_stories` story
        JOIN `sky_phone_skypic_profiles` author ON author.`id` = story.`profile_id`
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = author.`avatar_media_id`
        WHERE story.`id` = ? AND story.`profile_id` = ? AND story.`status` = 'active'
            AND story.`expires_at` > CURRENT_TIMESTAMP(6)
        LIMIT 1
    ]], { profile_id, story_id, profile_id })
    local row = rows[1]
    if not row then
        return nil
    end
    return {
        id = row.id,
        author = summary_from_row(row, "none", nil),
        durationSeconds = tonumber(row.view_seconds) or limit("MinimumViewSeconds", 1),
        expiresAt = row.expires_at,
        createdAt = row.created_at,
        isOwner = true,
        seen = is_true(row.seen),
        viewCount = tonumber(row.view_count) or 0,
    }
end

Bridge.Callbacks.Register("sky_phone:skypic:publish-story", function(source, data)
    if not SkyPhone.AllowOperation(source, "skypic_story", limit("StoriesPerMinute", 6), 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local editor, editor_error = editor_payload(source, data, false)
    if not editor then
        return { success = false, error = editor_error }
    end
    local maximum_active_stories = limit("MaximumActiveStories", 50)
    local counts = Bridge.Database.Query([[
        SELECT COUNT(*) AS `count` FROM `sky_phone_skypic_stories`
        WHERE `profile_id` = ? AND `status` = 'active' AND `expires_at` > CURRENT_TIMESTAMP(6)
    ]], { profile.profile_id })
    if (tonumber(counts[1] and counts[1].count) or 0) >= maximum_active_stories then
        return { success = false, error = "story_limit_reached" }
    end
    local story_id = new_id()
    local ok = Bridge.Database.Transaction({
        {
            query = [[
                UPDATE `sky_phone_skypic_profiles`
                SET `friend_count` = `friend_count`
                WHERE `id` = ?
            ]],
            params = { profile.profile_id },
        },
        {
            query = [[
                INSERT INTO `sky_phone_skypic_stories`
                    (`id`, `profile_id`, `media_id`, `caption`, `overlay_text`, `overlay_color`,
                        `view_seconds`, `privacy`, `expires_at`)
                SELECT ?, profile.`id`, ?, ?, ?, ?, ?, profile.`story_privacy`,
                    DATE_ADD(CURRENT_TIMESTAMP(6), INTERVAL ? SECOND)
                FROM `sky_phone_skypic_profiles` profile
                WHERE profile.`id` = ? AND profile.`status` = 'active'
                    AND (
                        SELECT COUNT(*) FROM `sky_phone_skypic_stories`
                        WHERE `profile_id` = profile.`id`
                            AND `status` = 'active'
                            AND `expires_at` > CURRENT_TIMESTAMP(6)
                    ) < ?
            ]],
            params = {
                story_id, editor.mediaId, editor.caption, editor.textOverlay, editor.overlayColor,
                editor.durationSeconds, limit("StoryLifetimeSeconds", 86400), profile.profile_id,
                maximum_active_stories,
            },
        },
        {
            query = [[
                UPDATE `sky_phone_skypic_profiles`
                SET `snap_score` = `snap_score` + 1
                WHERE `id` = ? AND EXISTS (
                    SELECT 1 FROM `sky_phone_skypic_stories` WHERE `id` = ?
                )
            ]],
            params = { profile.profile_id, story_id },
        },
    })
    if not ok then
        return { success = false, error = "request_failed" }
    end
    local story = own_story_metadata(story_id, profile.profile_id)
    if not story then
        local current_count = Bridge.Database.Query([[
            SELECT COUNT(*) AS `count` FROM `sky_phone_skypic_stories`
            WHERE `profile_id` = ? AND `status` = 'active'
                AND `expires_at` > CURRENT_TIMESTAMP(6)
        ]], { profile.profile_id })
        if (tonumber(current_count[1] and current_count[1].count) or 0) >= maximum_active_stories then
            return { success = false, error = "story_limit_reached" }
        end
        return { success = false, error = "request_failed" }
    end
    return { success = true, data = story }
end)

Bridge.Callbacks.Register("sky_phone:skypic:stories", function(source, data)
    if not SkyPhone.AllowOperation(source, "skypic_read", limit("ReadActionsPerMinute", 120), 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local offset = type(data) == "table" and data.offset or 0
    offset = valid_integer(offset, 0, 100000)
    if not offset then
        return { success = false, error = "invalid_request" }
    end
    return { success = true, data = list_stories(profile.profile_id, offset) }
end)

Bridge.Callbacks.Register("sky_phone:skypic:view-story", function(source, data)
    if not SkyPhone.AllowOperation(source, "skypic_story_view", limit("StoryViewsPerMinute", 120), 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local story_id = type(data) == "table" and data.storyId or nil
    if not valid_id(story_id) then
        return { success = false, error = "invalid_request" }
    end
    Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_skypic_story_views` (`story_id`, `viewer_profile_id`)
        SELECT story.`id`, ?
        FROM `sky_phone_skypic_stories` story
        LEFT JOIN `sky_phone_skypic_friendships` friendship
            ON friendship.`profile_a_id` = LEAST(?, story.`profile_id`)
            AND friendship.`profile_b_id` = GREATEST(?, story.`profile_id`)
            AND friendship.`status` = 'accepted'
        WHERE story.`id` = ? AND story.`profile_id` <> ? AND story.`status` = 'active'
            AND story.`expires_at` > CURRENT_TIMESTAMP(6)
            AND NOT EXISTS (
                SELECT 1 FROM `sky_phone_skypic_blocks` block
                WHERE (block.`blocker_profile_id` = ? AND block.`blocked_profile_id` = story.`profile_id`)
                    OR (block.`blocker_profile_id` = story.`profile_id` AND block.`blocked_profile_id` = ?)
            )
            AND (story.`privacy` = 'everyone' OR friendship.`id` IS NOT NULL)
    ]], {
        profile.profile_id, profile.profile_id, profile.profile_id, story_id, profile.profile_id,
        profile.profile_id, profile.profile_id,
    })
    local rows = Bridge.Database.Query([[
        SELECT story.`id`, story.`profile_id`, story.`caption`, story.`overlay_text`, story.`overlay_color`,
            story.`view_seconds`, story.`expires_at`, media.`url`, media.`media_type`, media.`mime_type`,
            author.`handle`, author.`display_name`, author.`avatar_seed`, author.`snap_score`,
            author.`allow_story_replies`, friendship.`id` AS `friendship_id`,
            avatar.`url` AS `avatar_url`, COALESCE(view.`viewed_at`, CURRENT_TIMESTAMP(6)) AS `viewed_at`
        FROM `sky_phone_skypic_stories` story
        JOIN `sky_phone_media` media ON media.`id` = story.`media_id`
        JOIN `sky_phone_skypic_profiles` author
            ON author.`id` = story.`profile_id` AND author.`status` = 'active'
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = author.`avatar_media_id`
        LEFT JOIN `sky_phone_skypic_story_views` view
            ON view.`story_id` = story.`id` AND view.`viewer_profile_id` = ?
        LEFT JOIN `sky_phone_skypic_friendships` friendship
            ON friendship.`profile_a_id` = LEAST(?, story.`profile_id`)
            AND friendship.`profile_b_id` = GREATEST(?, story.`profile_id`)
            AND friendship.`status` = 'accepted'
        WHERE story.`id` = ? AND story.`status` = 'active' AND story.`expires_at` > CURRENT_TIMESTAMP(6)
            AND NOT EXISTS (
                SELECT 1 FROM `sky_phone_skypic_blocks` block
                WHERE (block.`blocker_profile_id` = ? AND block.`blocked_profile_id` = story.`profile_id`)
                    OR (block.`blocker_profile_id` = story.`profile_id` AND block.`blocked_profile_id` = ?)
            )
            AND (story.`profile_id` = ? OR story.`privacy` = 'everyone' OR friendship.`id` IS NOT NULL)
        LIMIT 1
    ]], {
        profile.profile_id, profile.profile_id, profile.profile_id, story_id,
        profile.profile_id, profile.profile_id, profile.profile_id,
    })
    local row = rows[1]
    if not row then
        return { success = false, error = "story_unavailable" }
    end
    return {
        success = true,
        data = {
            id = row.id,
            author = summary_from_row(
                row,
                row.profile_id == profile.profile_id and "none" or (row.friendship_id and "friends" or "none"),
                row.friendship_id
            ),
            url = row.url,
            mediaType = row.media_type,
            mimeType = nullable(row.mime_type),
            caption = row.caption or "",
            textOverlay = row.overlay_text or "",
            overlayColor = row.overlay_color,
            durationSeconds = tonumber(row.view_seconds) or limit("MinimumViewSeconds", 1),
            expiresAt = row.expires_at,
            viewedAt = row.viewed_at,
            canReply = row.profile_id ~= profile.profile_id
                and row.friendship_id ~= nil
                and is_true(row.allow_story_replies),
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:skypic:story-viewers", function(source, data)
    if not SkyPhone.AllowOperation(source, "skypic_read", limit("ReadActionsPerMinute", 120), 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local story_id = type(data) == "table" and data.storyId or nil
    local offset = type(data) == "table" and (data.offset or 0) or 0
    offset = valid_integer(offset, 0, 100000)
    if not valid_id(story_id) or not offset then
        return { success = false, error = "invalid_request" }
    end
    if not Bridge.Database.Query([[
        SELECT `id` FROM `sky_phone_skypic_stories` WHERE `id` = ? AND `profile_id` = ? LIMIT 1
    ]], { story_id, profile.profile_id })[1] then
        return { success = false, error = "not_authorized" }
    end
    local rows = Bridge.Database.Query([[
        SELECT viewer.`id` AS `profile_id`, viewer.`handle`, viewer.`display_name`, viewer.`avatar_seed`,
            viewer.`snap_score`, avatar.`url` AS `avatar_url`, story_view.`viewed_at`,
            friendship.`id` AS `friendship_id`, friendship.`status`, friendship.`requested_by_id`
        FROM `sky_phone_skypic_story_views` story_view
        JOIN `sky_phone_skypic_profiles` viewer
            ON viewer.`id` = story_view.`viewer_profile_id` AND viewer.`status` = 'active'
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = viewer.`avatar_media_id`
        LEFT JOIN `sky_phone_skypic_friendships` friendship
            ON friendship.`profile_a_id` = LEAST(?, viewer.`id`)
            AND friendship.`profile_b_id` = GREATEST(?, viewer.`id`)
        WHERE story_view.`story_id` = ?
        ORDER BY story_view.`viewed_at` DESC
        LIMIT ? OFFSET ?
    ]], {
        profile.profile_id, profile.profile_id, story_id,
        limit("PageSize", 30), offset,
    })
    local viewers = {}
    for _, row in ipairs(rows) do
        local viewer = summary_from_row(
            row,
            friendship_status(profile.profile_id, row.requested_by_id, row.status),
            row.friendship_id
        )
        viewer.viewedAt = row.viewed_at
        viewers[#viewers + 1] = viewer
    end
    return { success = true, data = viewers }
end)

Bridge.Callbacks.Register("sky_phone:skypic:remove-story", function(source, data)
    if not SkyPhone.AllowOperation(source, "skypic_story", limit("StoriesPerMinute", 6), 60) then
        return { success = false, error = "rate_limited" }
    end
    local profile, _, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local story_id = type(data) == "table" and data.storyId or nil
    if not valid_id(story_id) then
        return { success = false, error = "invalid_request" }
    end
    local result = Bridge.Database.Query([[
        UPDATE `sky_phone_skypic_stories` SET `status` = 'removed'
        WHERE `id` = ? AND `profile_id` = ? AND `status` = 'active'
    ]], { story_id, profile.profile_id })
    return affected_rows(result) == 1 and { success = true }
        or { success = false, error = "story_unavailable" }
end)

CreateThread(function()
    while true do
        Wait(limit("CleanupIntervalSeconds", 45) * 1000)
        Bridge.Database.Query([[
            DELETE FROM `sky_phone_skypic_messages`
            WHERE `deleted_at` IS NOT NULL
                OR (`sender_deleted_at` IS NOT NULL AND `recipient_deleted_at` IS NOT NULL)
                OR (`message_type` IN ('snap_photo','snap_video')
                    AND `expires_at` IS NOT NULL AND `expires_at` <= CURRENT_TIMESTAMP(6))
                OR (`message_type` = 'text' AND `saved_at` IS NULL
                    AND `expires_at` IS NOT NULL AND `expires_at` <= CURRENT_TIMESTAMP(6))
        ]], {})
        Bridge.Database.Query([[
            DELETE FROM `sky_phone_skypic_stories`
            WHERE `status` = 'removed' OR `expires_at` <= CURRENT_TIMESTAMP(6)
        ]], {})
        Bridge.Database.Query([[
            UPDATE `sky_phone_skypic_friendships`
            SET `streak_count` = 0
            WHERE `status` = 'accepted' AND `streak_count` > 0
                AND (`streak_updated_on` IS NULL
                    OR `streak_updated_on` < DATE_SUB(UTC_DATE(), INTERVAL 1 DAY))
        ]], {})
    end
end)

end)
