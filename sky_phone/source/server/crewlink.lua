Bridge.Database.AfterMigration("sky_phone", function()
local password_pepper = tostring(Config.Server.CrewLinkPasswordPepper or "")
local role_levels = {
    guest = 1,
    member = 2,
    moderator = 3,
    coordinator = 4,
    owner = 5,
}
local member_roles = {
    guest = true,
    member = true,
    moderator = true,
    coordinator = true,
}
local group_colours = {
    cyan = true,
    blue = true,
    violet = true,
    orange = true,
    green = true,
    rose = true,
}
local ping_types = {
    meeting = true,
    danger = true,
    help = true,
    target = true,
    info = true,
}
local live_sources_cache = {
    expires_at = 0,
    sources = {},
}

if password_pepper == "" then
    Bridge.Debug(
        "warn",
        "[sky_phone] Config.Server.CrewLinkPasswordPepper is empty. CrewLink passwords still work, but their hashes lack the required server-side secret. Set a stable random value in config/config.lua before production; changing it later invalidates existing CrewLink passwords.",
        { always = true }
    )
end

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end
    return type(result) == "table" and tonumber(result.affectedRows) or 0
end

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

local function new_id()
    local rows = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    if not rows[1] or type(rows[1].id) ~= "string" then
        error("[sky_phone] Database did not generate a CrewLink id.")
    end
    return rows[1].id
end

local function new_invite_code()
    for _ = 1, 5 do
        local rows = Bridge.Database.Query([[
            SELECT UPPER(SUBSTRING(REPLACE(UUID(), '-', ''), 1, ?)) AS `code`
        ]], { Config.CrewLink.InviteCodeLength })
        local code = rows[1] and rows[1].code
        if type(code) == "string" then
            local existing = Bridge.Database.Query(
                "SELECT 1 FROM `sky_phone_crewlink_groups` WHERE `invite_code` = ? LIMIT 1",
                { code }
            )
            if not existing[1] then
                return code
            end
        end
    end
    error("[sky_phone] Could not generate a unique CrewLink invite code.")
end

local function profile_dto(row)
    return {
        id = row.id,
        username = row.username,
        avatarMediaId = row.avatar_media_id and tonumber(row.avatar_media_id) or nil,
        avatarUrl = row.avatar_url,
        activeGroupId = row.active_group_id,
        mapVisible = tonumber(row.map_visible) == 1,
        overheadVisible = tonumber(row.overhead_visible) == 1,
    }
end

local function profile_for_session(source)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return nil, error_response
    end
    local rows = Bridge.Database.Query([[
        SELECT p.`id`, p.`account_id`, p.`username`, p.`avatar_media_id`, p.`active_group_id`,
            p.`map_visible`, p.`overhead_visible`, avatar.`url` AS `avatar_url`
        FROM `sky_phone_crewlink_sessions` crew_session
        JOIN `sky_phone_crewlink_profiles` p ON p.`id` = crew_session.`profile_id`
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = p.`avatar_media_id`
        WHERE crew_session.`device_imei` = ?
        LIMIT 1
    ]], { session.imei })
    if not rows[1] then
        return nil, { success = false, error = "not_authenticated" }
    end
    rows[1].account_id = tonumber(rows[1].account_id)
    return rows[1]
end

local function require_profile(source)
    return profile_for_session(source)
end

local function membership(profile_id, group_id)
    local rows = Bridge.Database.Query([[
        SELECT m.`group_id`, m.`profile_id`, m.`role`, m.`joined_at`,
            g.`name` AS `group_name`, g.`colour`, g.`allow_member_pings`,
            g.`overhead_allowed`, g.`invite_code`, g.`owner_profile_id`
        FROM `sky_phone_crewlink_memberships` m
        JOIN `sky_phone_crewlink_groups` g ON g.`id` = m.`group_id`
        WHERE m.`profile_id` = ? AND m.`group_id` = ?
        LIMIT 1
    ]], { profile_id, group_id })
    return rows[1]
end

local function group_count(group_id)
    local rows = Bridge.Database.Query([[
        SELECT COUNT(*) AS `count`
        FROM `sky_phone_crewlink_memberships`
        WHERE `group_id` = ?
    ]], { group_id })
    return tonumber(rows[1] and rows[1].count) or 0
end

local function member_dtos(group_id)
    local rows = Bridge.Database.Query([[
        SELECT p.`id`, p.`account_id`, p.`username`, p.`map_visible`, p.`overhead_visible`,
            avatar.`url` AS `avatar_url`, m.`role`, UNIX_TIMESTAMP(m.`joined_at`) AS `joined_at`
        FROM `sky_phone_crewlink_memberships` m
        JOIN `sky_phone_crewlink_profiles` p ON p.`id` = m.`profile_id`
        LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = p.`avatar_media_id`
        WHERE m.`group_id` = ?
        ORDER BY FIELD(m.`role`, 'owner', 'coordinator', 'moderator', 'member', 'guest'), m.`joined_at`
    ]], { group_id })
    for _, row in ipairs(rows) do
        row.account_id = tonumber(row.account_id)
        row.mapVisible = tonumber(row.map_visible) == 1
        row.overheadVisible = tonumber(row.overhead_visible) == 1
        row.avatarUrl = row.avatar_url
        row.map_visible = nil
        row.overhead_visible = nil
        row.avatar_url = nil
        row.joinedAt = (tonumber(row.joined_at) or 0) * 1000
        row.joined_at = nil
    end
    return rows
end

local function group_dto(row, profile_id)
    local role = row.role
    return {
        id = row.id or row.group_id,
        name = row.name or row.group_name,
        colour = row.colour,
        role = role,
        inviteCode = role_levels[role] >= role_levels.coordinator and row.invite_code or nil,
        allowMemberPings = tonumber(row.allow_member_pings) == 1,
        overheadAllowed = tonumber(row.overhead_allowed) == 1,
        memberCount = tonumber(row.member_count) or group_count(row.id or row.group_id),
        isOwner = row.owner_profile_id == profile_id,
    }
end

local function list_groups(profile)
    local rows = Bridge.Database.Query([[
        SELECT g.`id`, g.`name`, g.`colour`, g.`invite_code`, g.`owner_profile_id`,
            g.`allow_member_pings`, g.`overhead_allowed`, m.`role`,
            (SELECT COUNT(*) FROM `sky_phone_crewlink_memberships` gm
                WHERE gm.`group_id` = g.`id`) AS `member_count`
        FROM `sky_phone_crewlink_memberships` m
        JOIN `sky_phone_crewlink_groups` g ON g.`id` = m.`group_id`
        WHERE m.`profile_id` = ?
        ORDER BY (g.`id` = ?) DESC, g.`name`
    ]], { profile.id, profile.active_group_id or "" })
    local groups = {}
    for index, row in ipairs(rows) do
        groups[index] = group_dto(row, profile.id)
    end
    return groups
end

local function active_pings(group_id)
    local rows = Bridge.Database.Query([[
        SELECT pg.`id`, pg.`type`, pg.`label`, pg.`position_x`, pg.`position_y`,
            pg.`position_z`, pg.`creator_profile_id`, pg.`source_resource`,
            cp.`username` AS `creator_username`,
            UNIX_TIMESTAMP(pg.`created_at`) AS `created_at`,
            UNIX_TIMESTAMP(pg.`expires_at`) AS `expires_at`
        FROM `sky_phone_crewlink_pings` pg
        LEFT JOIN `sky_phone_crewlink_profiles` cp ON cp.`id` = pg.`creator_profile_id`
        WHERE pg.`group_id` = ? AND pg.`expires_at` > CURRENT_TIMESTAMP
        ORDER BY pg.`created_at` DESC
        LIMIT ?
    ]], { group_id, Config.CrewLink.MaximumActivePings })
    for _, row in ipairs(rows) do
        row.coords = {
            x = tonumber(row.position_x) or 0.0,
            y = tonumber(row.position_y) or 0.0,
            z = tonumber(row.position_z) or 0.0,
        }
        row.position_x = nil
        row.position_y = nil
        row.position_z = nil
        row.creatorProfileId = row.creator_profile_id
        row.creatorUsername = row.creator_username or row.source_resource or "CrewLink"
        row.sourceResource = row.source_resource
        row.creator_profile_id = nil
        row.creator_username = nil
        row.source_resource = nil
        row.createdAt = (tonumber(row.created_at) or 0) * 1000
        row.expiresAt = (tonumber(row.expires_at) or 0) * 1000
        row.created_at = nil
        row.expires_at = nil
    end
    return rows
end

local function pending_invitations(profile_id)
    local rows = Bridge.Database.Query([[
        SELECT i.`id`, i.`group_id`, g.`name` AS `group_name`, g.`colour`,
            p.`username` AS `inviter_username`,
            UNIX_TIMESTAMP(i.`expires_at`) AS `expires_at`
        FROM `sky_phone_crewlink_invitations` i
        JOIN `sky_phone_crewlink_groups` g ON g.`id` = i.`group_id`
        JOIN `sky_phone_crewlink_profiles` p ON p.`id` = i.`inviter_profile_id`
        WHERE i.`invitee_profile_id` = ? AND i.`status` = 'pending'
            AND i.`expires_at` > CURRENT_TIMESTAMP
        ORDER BY i.`created_at` DESC
    ]], { profile_id })
    for _, row in ipairs(rows) do
        row.groupId = row.group_id
        row.groupName = row.group_name
        row.inviterUsername = row.inviter_username
        row.expiresAt = (tonumber(row.expires_at) or 0) * 1000
        row.group_id = nil
        row.group_name = nil
        row.inviter_username = nil
        row.expires_at = nil
    end
    return rows
end

local function live_sources_by_account()
    local now = os.time()
    if live_sources_cache.expires_at >= now then
        return live_sources_cache.sources
    end
    local live = {}
    for _, player_source in ipairs(Bridge.Framework.GetPlayers()) do
        local source = tonumber(player_source) or player_source
        local account = SkyPhone.RequireAccount(source)
        if account and not live[account.id] then
            live[account.id] = source
        end
    end
    live_sources_cache.expires_at = now + 1
    live_sources_cache.sources = live
    return live
end

local function live_group(group_id)
    local members = member_dtos(group_id)
    local live_sources = live_sources_by_account()
    for _, member in ipairs(members) do
        local source = live_sources[member.account_id]
        member.online = source ~= nil
        member.source = source
        if source and member.mapVisible then
            local ped = GetPlayerPed(source)
            local coords = GetEntityCoords(ped)
            member.coords = { x = coords.x, y = coords.y, z = coords.z }
        end
        member.account_id = nil
    end
    return members
end

local function group_account_ids(group_id)
    local rows = Bridge.Database.Query([[
        SELECT p.`account_id`
        FROM `sky_phone_crewlink_memberships` m
        JOIN `sky_phone_crewlink_profiles` p ON p.`id` = m.`profile_id`
        WHERE m.`group_id` = ?
    ]], { group_id })
    local account_ids = {}
    for _, row in ipairs(rows) do
        account_ids[#account_ids + 1] = tonumber(row.account_id)
    end
    return account_ids
end

local function profile_account_id(profile_id)
    local rows = Bridge.Database.Query(
        "SELECT `account_id` FROM `sky_phone_crewlink_profiles` WHERE `id` = ? LIMIT 1",
        { profile_id }
    )
    return rows[1] and tonumber(rows[1].account_id) or nil
end

local function notify_group(group_id, kind, actor, extra)
    for _, account_id in ipairs(group_account_ids(group_id)) do
        local payload = { kind = kind, actor = actor }
        for key, value in pairs(extra or {}) do
            payload[key] = value
        end
        SkyPhone.NotifyAccountDevices(account_id, "sky_phone:crewlink:notification", payload)
    end
end

local function refresh_group(group_id)
    for _, account_id in ipairs(group_account_ids(group_id)) do
        SkyPhone.NotifyAccount(account_id, "sky_phone:crewlink:changed", { groupId = group_id })
    end
end

local function bootstrap(profile)
    local groups = list_groups(profile)
    local active_group = nil
    if profile.active_group_id then
        local active_membership = membership(profile.id, profile.active_group_id)
        if active_membership then
            active_group = group_dto(active_membership, profile.id)
            active_group.members = live_group(profile.active_group_id)
            active_group.pings = active_pings(profile.active_group_id)
        end
    end
    return {
        profile = profile_dto(profile),
        groups = groups,
        activeGroup = active_group,
        invitations = pending_invitations(profile.id),
        limits = {
            maximumGroups = Config.CrewLink.MaximumGroupsPerProfile,
            maximumMembers = Config.CrewLink.MaximumMembersPerGroup,
            nearbyDistance = Config.CrewLink.NearbyInviteDistance,
            pingLifetimeSeconds = Config.CrewLink.PingLifetimeSeconds,
            overheadDistance = Config.CrewLink.OverheadDistance,
        },
    }
end

local function valid_username(value)
    local username = trim(value)
    if not valid_text(username, Config.CrewLink.UsernameMinLength, Config.CrewLink.UsernameMaxLength)
        or not username:match("^[A-Za-z0-9][A-Za-z0-9._]*[A-Za-z0-9]$")
    then
        return nil
    end
    return username
end

local function valid_password(value)
    local length = type(value) == "string" and utf8.len(value) or nil
    return length
        and length >= Config.CrewLink.PasswordMinLength
        and length <= Config.CrewLink.PasswordMaxLength
end

local function valid_group_name(value)
    local name = trim(value)
    return valid_text(name, Config.CrewLink.GroupNameMinLength, Config.CrewLink.GroupNameMaxLength)
        and name or nil
end

local function validate_coords(value)
    if type(value) ~= "table" then
        return nil
    end
    local x = tonumber(value.x)
    local y = tonumber(value.y)
    local z = tonumber(value.z) or 0.0
    if not x or not y or x ~= x or y ~= y or z ~= z
        or math.abs(x) > 10000.0 or math.abs(y) > 10000.0
        or z < -1000.0 or z > 3000.0
    then
        return nil
    end
    return { x = x, y = y, z = z }
end

local function allow(source, operation)
    return SkyPhone.AllowOperation(
        source,
        "crewlink:" .. operation,
        Config.CrewLink.ActionsPerMinute,
        60
    )
end

Bridge.Callbacks.Register("sky_phone:crewlink:bootstrap", function(source)
    if not SkyPhone.AllowOperation(
        source,
        "crewlink:bootstrap",
        Config.CrewLink.LiveRequestsPerMinute,
        60
    ) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = profile_for_session(source)
    if not profile then
        if error_response and error_response.error ~= "not_authenticated" then
            return error_response
        end
        return {
            success = true,
            data = { authenticated = false, profile = nil, groups = {}, invitations = {} },
        }
    end
    local data = bootstrap(profile)
    data.authenticated = true
    return { success = true, data = data }
end)

Bridge.Callbacks.Register("sky_phone:crewlink:register", function(source, data)
    if not SkyPhone.AllowOperation(source, "crewlink:register", 5, 60) then
        return { success = false, error = "rate_limited" }
    end
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then
        return error_response
    end
    data = type(data) == "table" and data or {}
    local username = valid_username(data.username)
    if not username then
        return { success = false, error = "invalid_username" }
    end
    if not valid_password(data.password) then
        return { success = false, error = "invalid_password" }
    end
    local avatar_media_id = tonumber(data.avatarMediaId) or 0
    if avatar_media_id < 0 or avatar_media_id ~= math.floor(avatar_media_id) then
        return { success = false, error = "invalid_profile_image" }
    end
    if avatar_media_id > 0 and not SkyPhoneMedia.ResolveOwnedMedia(source, avatar_media_id, "photo") then
        return { success = false, error = "invalid_profile_image" }
    end
    local existing = Bridge.Database.Query([[
        SELECT p.`id`, c.`profile_id` AS `credential_profile_id`
        FROM `sky_phone_crewlink_profiles` p
        LEFT JOIN `sky_phone_crewlink_credentials` c ON c.`profile_id` = p.`id`
        WHERE p.`account_id` = ? LIMIT 1
    ]], { account.id })[1]
    if existing and existing.credential_profile_id then
        return { success = false, error = "profile_exists" }
    end
    local duplicate = Bridge.Database.Query([[
        SELECT `id` FROM `sky_phone_crewlink_profiles`
        WHERE `username` = ? AND `account_id` <> ? LIMIT 1
    ]], { username, account.id })
    if duplicate[1] then
        return { success = false, error = "username_taken" }
    end
    local entropy = Bridge.Database.Query(
        "SELECT UUID() AS `id`, REPLACE(UUID(), '-', '') AS `salt`",
        {}
    )[1]
    if not entropy or type(entropy.id) ~= "string" or type(entropy.salt) ~= "string" then
        error("[sky_phone] Database did not generate CrewLink registration entropy.")
    end
    local profile_id = existing and existing.id or entropy.id
    local queries = {}
    if existing then
        queries[#queries + 1] = {
            query = [[UPDATE `sky_phone_crewlink_profiles`
                SET `username` = ?, `avatar_media_id` = NULLIF(?, 0) WHERE `id` = ?]],
            params = { username, avatar_media_id, profile_id },
        }
    else
        queries[#queries + 1] = {
            query = [[INSERT INTO `sky_phone_crewlink_profiles`
                (`id`, `account_id`, `username`, `avatar_media_id`) VALUES (?, ?, ?, NULLIF(?, 0))]],
            params = { profile_id, account.id, username, avatar_media_id },
        }
    end
    queries[#queries + 1] = {
        query = [[INSERT INTO `sky_phone_crewlink_credentials`
            (`profile_id`, `password_hash`, `password_salt`)
            VALUES (?, UNHEX(SHA2(CONCAT(?, ?, ?), 256)), ?)]],
        params = { profile_id, password_pepper, entropy.salt, data.password, entropy.salt },
    }
    queries[#queries + 1] = {
        query = [[INSERT INTO `sky_phone_crewlink_sessions` (`device_imei`, `profile_id`)
            VALUES (?, ?) ON DUPLICATE KEY UPDATE `profile_id` = VALUES(`profile_id`),
                `updated_at` = CURRENT_TIMESTAMP]],
        params = { account.imei, profile_id },
    }
    if not Bridge.Database.Transaction(queries) then
        return { success = false, error = "request_failed" }
    end
    local profile = require_profile(source)
    local response = bootstrap(profile)
    response.authenticated = true
    return { success = true, data = response }
end)

Bridge.Callbacks.Register("sky_phone:crewlink:login", function(source, data)
    if not SkyPhone.AllowOperation(source, "crewlink:login", 10, 60) then
        return { success = false, error = "rate_limited" }
    end
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then
        return error_response
    end
    if type(data) ~= "table" or not valid_password(data.password) then
        return { success = false, error = "invalid_credentials" }
    end
    local profiles = Bridge.Database.Query([[
        SELECT p.`id` FROM `sky_phone_crewlink_profiles` p
        JOIN `sky_phone_crewlink_credentials` c ON c.`profile_id` = p.`id`
        WHERE p.`account_id` = ?
            AND c.`password_hash` = UNHEX(SHA2(CONCAT(?, c.`password_salt`, ?), 256))
        LIMIT 1
    ]], { account.id, password_pepper, data.password })
    if not profiles[1] then
        return { success = false, error = "invalid_credentials" }
    end
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_crewlink_sessions` (`device_imei`, `profile_id`)
        VALUES (?, ?) ON DUPLICATE KEY UPDATE `profile_id` = VALUES(`profile_id`),
            `updated_at` = CURRENT_TIMESTAMP
    ]], { account.imei, profiles[1].id })
    local profile = require_profile(source)
    local response = bootstrap(profile)
    response.authenticated = true
    return { success = true, data = response }
end)

Bridge.Callbacks.Register("sky_phone:crewlink:logout", function(source)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return error_response
    end
    Bridge.Database.Query(
        "DELETE FROM `sky_phone_crewlink_sessions` WHERE `device_imei` = ?",
        { session.imei }
    )
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:crewlink:update-profile", function(source, data)
    if not allow(source, "profile") then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local username = valid_username(data and data.username)
    if not username or type(data.mapVisible) ~= "boolean" or type(data.overheadVisible) ~= "boolean" then
        return { success = false, error = "invalid_profile" }
    end
    local avatar_media_id = profile.avatar_media_id and tonumber(profile.avatar_media_id) or nil
    if data.avatarMediaId ~= nil then
        local submitted_avatar_id = tonumber(data.avatarMediaId)
        if not submitted_avatar_id or submitted_avatar_id < 0
            or submitted_avatar_id ~= math.floor(submitted_avatar_id)
        then
            return { success = false, error = "invalid_profile_image" }
        end
        if submitted_avatar_id > 0
            and not SkyPhoneMedia.ResolveOwnedMedia(source, submitted_avatar_id, "photo")
        then
            return { success = false, error = "invalid_profile_image" }
        end
        avatar_media_id = submitted_avatar_id > 0 and submitted_avatar_id or nil
    end
    local result = Bridge.Database.Query([[
        UPDATE IGNORE `sky_phone_crewlink_profiles`
        SET `username` = ?, `map_visible` = ?, `overhead_visible` = ?, `avatar_media_id` = ?
        WHERE `id` = ?
    ]], { username, data.mapVisible and 1 or 0, data.overheadVisible and 1 or 0, avatar_media_id, profile.id })
    if affected_rows(result) ~= 1 and username:lower() ~= tostring(profile.username):lower() then
        return { success = false, error = "username_taken" }
    end
    if profile.active_group_id then
        refresh_group(profile.active_group_id)
    end
    local updated = require_profile(source)
    return { success = true, data = bootstrap(updated) }
end)

Bridge.Callbacks.Register("sky_phone:crewlink:create-group", function(source, data)
    if not allow(source, "group") then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local name = valid_group_name(data and data.name)
    local colour = data and data.colour
    if not name or not group_colours[colour] then
        return { success = false, error = "invalid_group" }
    end
    local groups = list_groups(profile)
    if #groups >= Config.CrewLink.MaximumGroupsPerProfile then
        return { success = false, error = "group_limit" }
    end
    local group_id = new_id()
    local success = Bridge.Database.Transaction({
        {
            query = [[INSERT INTO `sky_phone_crewlink_groups`
                (`id`, `name`, `colour`, `owner_profile_id`, `invite_code`)
                VALUES (?, ?, ?, ?, ?)]],
            params = { group_id, name, colour, profile.id, new_invite_code() },
        },
        {
            query = [[INSERT INTO `sky_phone_crewlink_memberships`
                (`group_id`, `profile_id`, `role`) VALUES (?, ?, 'owner')]],
            params = { group_id, profile.id },
        },
        {
            query = "UPDATE `sky_phone_crewlink_profiles` SET `active_group_id` = ? WHERE `id` = ?",
            params = { group_id, profile.id },
        },
    })
    if not success then
        return { success = false, error = "request_failed" }
    end
    TriggerEvent("sky_phone:crewlink:memberJoined", group_id, profile.id)
    TriggerEvent("sky_phone:crewlink:activeChanged", profile.id, group_id)
    local updated = require_profile(source)
    return { success = true, data = bootstrap(updated) }
end)

Bridge.Callbacks.Register("sky_phone:crewlink:update-group", function(source, data)
    if not allow(source, "group") then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local member = type(data) == "table" and membership(profile.id, data.groupId) or nil
    if not member or role_levels[member.role] < role_levels.coordinator then
        return { success = false, error = "forbidden" }
    end
    local name = valid_group_name(data.name)
    if not name or not group_colours[data.colour]
        or type(data.allowMemberPings) ~= "boolean" or type(data.overheadAllowed) ~= "boolean"
    then
        return { success = false, error = "invalid_group" }
    end
    Bridge.Database.Query([[
        UPDATE `sky_phone_crewlink_groups`
        SET `name` = ?, `colour` = ?, `allow_member_pings` = ?, `overhead_allowed` = ?
        WHERE `id` = ?
    ]], { name, data.colour, data.allowMemberPings and 1 or 0, data.overheadAllowed and 1 or 0, data.groupId })
    refresh_group(data.groupId)
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:crewlink:delete-group", function(source, data)
    if not allow(source, "group") then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local member = type(data) == "table" and membership(profile.id, data.groupId) or nil
    if not member or member.role ~= "owner" then
        return { success = false, error = "forbidden" }
    end
    local affected_accounts = group_account_ids(data.groupId)
    local success = Bridge.Database.Transaction({
        {
            query = "UPDATE `sky_phone_crewlink_profiles` SET `active_group_id` = NULL WHERE `active_group_id` = ?",
            params = { data.groupId },
        },
        {
            query = "DELETE FROM `sky_phone_crewlink_groups` WHERE `id` = ? AND `owner_profile_id` = ?",
            params = { data.groupId, profile.id },
        },
    })
    if not success then
        return { success = false, error = "request_failed" }
    end
    for _, account_id in ipairs(affected_accounts) do
        SkyPhone.NotifyAccount(account_id, "sky_phone:crewlink:changed", { groupId = data.groupId })
    end
    TriggerEvent("sky_phone:crewlink:memberLeft", data.groupId, profile.id)
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:crewlink:set-active", function(source, data)
    if not allow(source, "group") then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    if type(data) ~= "table" or type(data.groupId) ~= "string" or not membership(profile.id, data.groupId) then
        return { success = false, error = "group_not_found" }
    end
    Bridge.Database.Query(
        "UPDATE `sky_phone_crewlink_profiles` SET `active_group_id` = ? WHERE `id` = ?",
        { data.groupId, profile.id }
    )
    TriggerEvent("sky_phone:crewlink:activeChanged", profile.id, data.groupId)
    local updated = require_profile(source)
    return { success = true, data = bootstrap(updated) }
end)

Bridge.Callbacks.Register("sky_phone:crewlink:join-code", function(source, data)
    if not allow(source, "invite") then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local code = type(data) == "table" and trim(data.code) or nil
    if not code or #code ~= Config.CrewLink.InviteCodeLength then
        return { success = false, error = "invalid_code" }
    end
    local rows = Bridge.Database.Query([[
        SELECT `id`, `name` FROM `sky_phone_crewlink_groups`
        WHERE `invite_code` = ? LIMIT 1
    ]], { code:upper() })
    local group = rows[1]
    if not group then
        return { success = false, error = "invalid_code" }
    end
    if membership(profile.id, group.id) then
        return { success = false, error = "already_member" }
    end
    if #list_groups(profile) >= Config.CrewLink.MaximumGroupsPerProfile then
        return { success = false, error = "group_limit" }
    end
    if group_count(group.id) >= Config.CrewLink.MaximumMembersPerGroup then
        return { success = false, error = "member_limit" }
    end
    local success = Bridge.Database.Transaction({
        {
            query = [[INSERT INTO `sky_phone_crewlink_memberships`
                (`group_id`, `profile_id`, `role`) VALUES (?, ?, 'member')]],
            params = { group.id, profile.id },
        },
        {
            query = "UPDATE `sky_phone_crewlink_profiles` SET `active_group_id` = ? WHERE `id` = ?",
            params = { group.id, profile.id },
        },
    })
    if not success then
        return { success = false, error = "request_failed" }
    end
    notify_group(group.id, "member_joined", profile.username, { groupName = group.name })
    refresh_group(group.id)
    TriggerEvent("sky_phone:crewlink:memberJoined", group.id, profile.id)
    local updated = require_profile(source)
    return { success = true, data = bootstrap(updated) }
end)

Bridge.Callbacks.Register("sky_phone:crewlink:rotate-code", function(source, data)
    if not allow(source, "invite") then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local member = type(data) == "table" and membership(profile.id, data.groupId) or nil
    if not member or role_levels[member.role] < role_levels.coordinator then
        return { success = false, error = "forbidden" }
    end
    local code = new_invite_code()
    Bridge.Database.Query("UPDATE `sky_phone_crewlink_groups` SET `invite_code` = ? WHERE `id` = ?", {
        code,
        data.groupId,
    })
    refresh_group(data.groupId)
    return { success = true, data = { inviteCode = code } }
end)

Bridge.Callbacks.Register("sky_phone:crewlink:nearby", function(source)
    if not allow(source, "nearby") then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local member = profile.active_group_id and membership(profile.id, profile.active_group_id) or nil
    if not member or role_levels[member.role] < role_levels.moderator then
        return { success = false, error = "forbidden" }
    end
    local player_ped = GetPlayerPed(source)
    local player_coords = GetEntityCoords(player_ped)
    local player_bucket = GetPlayerRoutingBucket(source)
    local candidates = {}
    for _, target_value in ipairs(Bridge.Framework.GetPlayers()) do
        local target = tonumber(target_value) or target_value
        if target ~= source and GetPlayerRoutingBucket(target) == player_bucket then
            local target_coords = GetEntityCoords(GetPlayerPed(target))
            local distance = #(player_coords - target_coords)
            if distance <= Config.CrewLink.NearbyInviteDistance then
                local target_account = SkyPhone.RequireAccount(target)
                if target_account then
                    local rows = Bridge.Database.Query([[
                        SELECT `id`, `username` FROM `sky_phone_crewlink_profiles`
                        WHERE `account_id` = ? LIMIT 1
                    ]], { target_account.id })
                    local target_profile = rows[1]
                    if target_profile and not membership(target_profile.id, profile.active_group_id) then
                        candidates[#candidates + 1] = {
                            source = target,
                            username = target_profile.username,
                            distance = math.floor(distance * 10 + 0.5) / 10,
                        }
                        if #candidates >= Config.CrewLink.NearbyScanLimit then
                            break
                        end
                    end
                end
            end
        end
    end
    return { success = true, data = candidates }
end)

Bridge.Callbacks.Register("sky_phone:crewlink:invite-nearby", function(source, data)
    if not allow(source, "invite") then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local member = profile.active_group_id and membership(profile.id, profile.active_group_id) or nil
    if not member or role_levels[member.role] < role_levels.moderator then
        return { success = false, error = "forbidden" }
    end
    local target = type(data) == "table" and math.floor(tonumber(data.targetSource) or 0) or 0
    if target <= 0 or GetPlayerRoutingBucket(target) ~= GetPlayerRoutingBucket(source) then
        return { success = false, error = "player_not_nearby" }
    end
    local distance = #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(GetPlayerPed(target)))
    if distance > Config.CrewLink.NearbyInviteDistance then
        return { success = false, error = "player_not_nearby" }
    end
    local target_account = SkyPhone.RequireAccount(target)
    if not target_account then
        return { success = false, error = "player_unavailable" }
    end
    local rows = Bridge.Database.Query([[
        SELECT `id`, `username` FROM `sky_phone_crewlink_profiles`
        WHERE `account_id` = ? LIMIT 1
    ]], { target_account.id })
    local target_profile = rows[1]
    if not target_profile or membership(target_profile.id, profile.active_group_id) then
        return { success = false, error = "player_unavailable" }
    end
    local invitation_id = new_id()
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_crewlink_invitations`
            (`id`, `group_id`, `inviter_profile_id`, `invitee_profile_id`, `expires_at`)
        VALUES (?, ?, ?, ?, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL ? SECOND))
        ON DUPLICATE KEY UPDATE `inviter_profile_id` = VALUES(`inviter_profile_id`),
            `status` = 'pending', `expires_at` = VALUES(`expires_at`), `created_at` = CURRENT_TIMESTAMP
    ]], {
        invitation_id,
        profile.active_group_id,
        profile.id,
        target_profile.id,
        Config.CrewLink.InviteLifetimeSeconds,
    })
    SkyPhone.NotifyAccountDevices(target_account.id, "sky_phone:crewlink:notification", {
        kind = "invite",
        actor = profile.username,
        groupName = member.group_name,
    })
    TriggerClientEvent("sky_phone:crewlink:changed", target, { groupId = profile.active_group_id })
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:crewlink:respond-invite", function(source, data)
    if not allow(source, "invite") then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local accepted = type(data) == "table" and data.accepted
    if type(accepted) ~= "boolean" or type(data.invitationId) ~= "string" then
        return { success = false, error = "invalid_invitation" }
    end
    local rows = Bridge.Database.Query([[
        SELECT i.`id`, i.`group_id`, g.`name` AS `group_name`
        FROM `sky_phone_crewlink_invitations` i
        JOIN `sky_phone_crewlink_groups` g ON g.`id` = i.`group_id`
        WHERE i.`id` = ? AND i.`invitee_profile_id` = ? AND i.`status` = 'pending'
            AND i.`expires_at` > CURRENT_TIMESTAMP
        LIMIT 1
    ]], { data.invitationId, profile.id })
    local invitation = rows[1]
    if not invitation then
        return { success = false, error = "invitation_expired" }
    end
    if not accepted then
        Bridge.Database.Query(
            "UPDATE `sky_phone_crewlink_invitations` SET `status` = 'declined' WHERE `id` = ?",
            { invitation.id }
        )
        return { success = true }
    end
    if #list_groups(profile) >= Config.CrewLink.MaximumGroupsPerProfile then
        return { success = false, error = "group_limit" }
    end
    if group_count(invitation.group_id) >= Config.CrewLink.MaximumMembersPerGroup then
        return { success = false, error = "member_limit" }
    end
    local success = Bridge.Database.Transaction({
        {
            query = [[INSERT INTO `sky_phone_crewlink_memberships`
                (`group_id`, `profile_id`, `role`) VALUES (?, ?, 'member')]],
            params = { invitation.group_id, profile.id },
        },
        {
            query = "UPDATE `sky_phone_crewlink_invitations` SET `status` = 'accepted' WHERE `id` = ? AND `status` = 'pending'",
            params = { invitation.id },
        },
        {
            query = "UPDATE `sky_phone_crewlink_profiles` SET `active_group_id` = ? WHERE `id` = ?",
            params = { invitation.group_id, profile.id },
        },
    })
    if not success then
        return { success = false, error = "request_failed" }
    end
    notify_group(invitation.group_id, "member_joined", profile.username, { groupName = invitation.group_name })
    refresh_group(invitation.group_id)
    TriggerEvent("sky_phone:crewlink:memberJoined", invitation.group_id, profile.id)
    local updated = require_profile(source)
    return { success = true, data = bootstrap(updated) }
end)

Bridge.Callbacks.Register("sky_phone:crewlink:update-member", function(source, data)
    if not allow(source, "group") then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    if type(data) ~= "table" or not member_roles[data.role] or type(data.profileId) ~= "string" then
        return { success = false, error = "invalid_role" }
    end
    local actor = membership(profile.id, data.groupId)
    local target = membership(data.profileId, data.groupId)
    if not actor or not target or role_levels[actor.role] < role_levels.coordinator
        or role_levels[target.role] >= role_levels[actor.role]
        or (actor.role ~= "owner" and role_levels[data.role] >= role_levels[actor.role])
    then
        return { success = false, error = "forbidden" }
    end
    Bridge.Database.Query([[
        UPDATE `sky_phone_crewlink_memberships` SET `role` = ?
        WHERE `group_id` = ? AND `profile_id` = ?
    ]], { data.role, data.groupId, data.profileId })
    local target_account_id = profile_account_id(data.profileId)
    if target_account_id then
        SkyPhone.NotifyAccountDevices(target_account_id, "sky_phone:crewlink:notification", {
            kind = "role",
            actor = profile.username,
            groupName = target.group_name,
        })
    end
    refresh_group(data.groupId)
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:crewlink:transfer-owner", function(source, data)
    if not allow(source, "group") then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local actor = type(data) == "table" and membership(profile.id, data.groupId) or nil
    local target = type(data) == "table" and membership(data.profileId, data.groupId) or nil
    if not actor or actor.role ~= "owner" or not target or target.profile_id == profile.id then
        return { success = false, error = "forbidden" }
    end
    local success = Bridge.Database.Transaction({
        {
            query = "UPDATE `sky_phone_crewlink_groups` SET `owner_profile_id` = ? WHERE `id` = ? AND `owner_profile_id` = ?",
            params = { data.profileId, data.groupId, profile.id },
        },
        {
            query = "UPDATE `sky_phone_crewlink_memberships` SET `role` = 'coordinator' WHERE `group_id` = ? AND `profile_id` = ?",
            params = { data.groupId, profile.id },
        },
        {
            query = "UPDATE `sky_phone_crewlink_memberships` SET `role` = 'owner' WHERE `group_id` = ? AND `profile_id` = ?",
            params = { data.groupId, data.profileId },
        },
    })
    if not success then
        return { success = false, error = "request_failed" }
    end
    refresh_group(data.groupId)
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:crewlink:remove-member", function(source, data)
    if not allow(source, "group") then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local actor = type(data) == "table" and membership(profile.id, data.groupId) or nil
    local target = type(data) == "table" and membership(data.profileId, data.groupId) or nil
    if not actor or not target or role_levels[actor.role] < role_levels.moderator
        or role_levels[target.role] >= role_levels[actor.role]
    then
        return { success = false, error = "forbidden" }
    end
    local target_account_id = profile_account_id(data.profileId)
    local success = Bridge.Database.Transaction({
        {
            query = "DELETE FROM `sky_phone_crewlink_memberships` WHERE `group_id` = ? AND `profile_id` = ?",
            params = { data.groupId, data.profileId },
        },
        {
            query = "UPDATE `sky_phone_crewlink_profiles` SET `active_group_id` = NULL WHERE `id` = ? AND `active_group_id` = ?",
            params = { data.profileId, data.groupId },
        },
    })
    if not success then
        return { success = false, error = "request_failed" }
    end
    if target_account_id then
        SkyPhone.NotifyAccount(target_account_id, "sky_phone:crewlink:changed", { groupId = data.groupId })
        SkyPhone.NotifyAccountDevices(target_account_id, "sky_phone:crewlink:notification", {
            kind = "removed",
            actor = profile.username,
            groupName = target.group_name,
        })
    end
    TriggerEvent("sky_phone:crewlink:memberLeft", data.groupId, data.profileId)
    refresh_group(data.groupId)
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:crewlink:leave", function(source, data)
    if not allow(source, "group") then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local member = type(data) == "table" and membership(profile.id, data.groupId) or nil
    if not member then
        return { success = false, error = "group_not_found" }
    end
    if member.role == "owner" then
        return { success = false, error = "owner_must_transfer" }
    end
    local success = Bridge.Database.Transaction({
        {
            query = "DELETE FROM `sky_phone_crewlink_memberships` WHERE `group_id` = ? AND `profile_id` = ?",
            params = { data.groupId, profile.id },
        },
        {
            query = "UPDATE `sky_phone_crewlink_profiles` SET `active_group_id` = NULL WHERE `id` = ? AND `active_group_id` = ?",
            params = { profile.id, data.groupId },
        },
    })
    if not success then
        return { success = false, error = "request_failed" }
    end
    TriggerEvent("sky_phone:crewlink:memberLeft", data.groupId, profile.id)
    refresh_group(data.groupId)
    local updated = require_profile(source)
    return { success = true, data = bootstrap(updated) }
end)

local function create_ping(group_id, creator_profile_id, source_resource, data)
    local label = trim(data and data.label)
    local coords = validate_coords(data and data.coords)
    if not ping_types[data and data.type] or not coords
        or not valid_text(label, 1, Config.CrewLink.PingLabelMaxLength)
    then
        return nil, "invalid_ping"
    end
    local count_rows = Bridge.Database.Query([[
        SELECT COUNT(*) AS `count` FROM `sky_phone_crewlink_pings`
        WHERE `group_id` = ? AND `expires_at` > CURRENT_TIMESTAMP
    ]], { group_id })
    if (tonumber(count_rows[1] and count_rows[1].count) or 0) >= Config.CrewLink.MaximumActivePings then
        return nil, "ping_limit"
    end
    local lifetime = math.max(15, math.min(
        Config.CrewLink.PingLifetimeSeconds,
        math.floor(tonumber(data.lifetimeSeconds) or Config.CrewLink.PingLifetimeSeconds)
    ))
    local id = new_id()
    Bridge.Database.Query([[
        INSERT INTO `sky_phone_crewlink_pings`
            (`id`, `group_id`, `creator_profile_id`, `source_resource`, `type`, `label`,
                `position_x`, `position_y`, `position_z`, `expires_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL ? SECOND))
    ]], {
        id,
        group_id,
        creator_profile_id,
        source_resource,
        data.type,
        label,
        coords.x,
        coords.y,
        coords.z,
        lifetime,
    })
    local ping = {
        id = id,
        type = data.type,
        label = label,
        coords = coords,
        creatorProfileId = creator_profile_id,
        sourceResource = source_resource,
        createdAt = os.time() * 1000,
        expiresAt = (os.time() + lifetime) * 1000,
    }
    TriggerEvent("sky_phone:crewlink:pingCreated", group_id, ping)
    return ping
end

Bridge.Callbacks.Register("sky_phone:crewlink:create-ping", function(source, data)
    if not allow(source, "ping") then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local group_id = profile.active_group_id
    local member = group_id and membership(profile.id, group_id) or nil
    if not member or (role_levels[member.role] < role_levels.moderator and tonumber(member.allow_member_pings) ~= 1) then
        return { success = false, error = "forbidden" }
    end
    local ping_data = data or {}
    if data and data.useCurrent then
        local coords = GetEntityCoords(GetPlayerPed(source))
        ping_data = {
            type = data.type,
            label = data.label,
            coords = { x = coords.x, y = coords.y, z = coords.z },
        }
    end
    local ping, error_code = create_ping(group_id, profile.id, nil, ping_data)
    if not ping then
        return { success = false, error = error_code }
    end
    notify_group(group_id, "ping", profile.username, {
        groupName = member.group_name,
        pingType = ping.type,
        pingLabel = ping.label,
    })
    refresh_group(group_id)
    return { success = true, data = ping }
end)

Bridge.Callbacks.Register("sky_phone:crewlink:remove-ping", function(source, data)
    if not allow(source, "ping") then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    local group_id = profile.active_group_id
    local member = group_id and membership(profile.id, group_id) or nil
    if not member or type(data) ~= "table" or type(data.pingId) ~= "string" then
        return { success = false, error = "ping_not_found" }
    end
    local rows = Bridge.Database.Query([[
        SELECT `creator_profile_id` FROM `sky_phone_crewlink_pings`
        WHERE `id` = ? AND `group_id` = ? LIMIT 1
    ]], { data.pingId, group_id })
    local ping = rows[1]
    if not ping or (ping.creator_profile_id ~= profile.id and role_levels[member.role] < role_levels.moderator) then
        return { success = false, error = "forbidden" }
    end
    Bridge.Database.Query("DELETE FROM `sky_phone_crewlink_pings` WHERE `id` = ? AND `group_id` = ?", {
        data.pingId,
        group_id,
    })
    TriggerEvent("sky_phone:crewlink:pingRemoved", group_id, data.pingId)
    refresh_group(group_id)
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:crewlink:live", function(source)
    if not SkyPhone.AllowOperation(
        source,
        "crewlink:live",
        Config.CrewLink.LiveRequestsPerMinute,
        60
    ) then
        return { success = false, error = "rate_limited" }
    end
    local profile, error_response = require_profile(source)
    if not profile then
        return error_response
    end
    if not profile.active_group_id then
        return { success = true, data = { members = {}, overheadMembers = {}, pings = {} } }
    end
    local active_membership = membership(profile.id, profile.active_group_id)
    if not active_membership then
        return { success = true, data = { members = {}, overheadMembers = {}, pings = {} } }
    end
    local members = live_group(profile.active_group_id)
    local overhead_members = {}
    if tonumber(profile.overhead_visible) == 1
        and tonumber(active_membership.overhead_allowed) == 1
    then
        for _, member in ipairs(members) do
            if member.source and member.source ~= source and member.overheadVisible then
                overhead_members[#overhead_members + 1] = {
                    source = member.source,
                    username = member.username,
                    role = member.role,
                    roleLabel = member.role:sub(1, 1):upper() .. member.role:sub(2),
                }
            end
        end
    end
    return {
        success = true,
        data = {
            members = members,
            overheadMembers = overhead_members,
            pings = active_pings(profile.active_group_id),
        },
    }
end)

exports("GetCrewLinkActiveGroup", function(source)
    local profile = require_profile(source)
    if not profile or not profile.active_group_id then
        return nil
    end
    local member = membership(profile.id, profile.active_group_id)
    return member and group_dto(member, profile.id) or nil
end)

exports("GetCrewLinkGroupMembers", function(group_id)
    if type(group_id) ~= "string" then
        return {}
    end
    local members = {}
    for _, member in ipairs(member_dtos(group_id)) do
        members[#members + 1] = {
            id = member.id,
            username = member.username,
            role = member.role,
            joinedAt = member.joinedAt,
        }
    end
    return members
end)

exports("IsCrewLinkGroupMember", function(source, group_id)
    local profile = require_profile(source)
    return profile and type(group_id) == "string" and membership(profile.id, group_id) ~= nil or false
end)

exports("GetCrewLinkGroupRole", function(source, group_id)
    local profile = require_profile(source)
    local member = profile and type(group_id) == "string" and membership(profile.id, group_id) or nil
    return member and member.role or nil
end)

exports("CreateCrewLinkPing", function(group_id, data)
    local invoking_resource = GetInvokingResource()
    if not invoking_resource or not Config.CrewLink.ExternalPingResources[invoking_resource] then
        return nil, "resource_not_allowed"
    end
    local groups = Bridge.Database.Query(
        "SELECT `id`, `name` FROM `sky_phone_crewlink_groups` WHERE `id` = ? LIMIT 1",
        { group_id }
    )
    if not groups[1] then
        return nil, "group_not_found"
    end
    local ping, error_code = create_ping(group_id, nil, invoking_resource, data)
    if ping then
        notify_group(group_id, "ping", invoking_resource, {
            groupName = groups[1].name,
            pingType = ping.type,
            pingLabel = ping.label,
        })
        refresh_group(group_id)
    end
    return ping, error_code
end)

exports("RemoveCrewLinkPing", function(group_id, ping_id)
    local invoking_resource = GetInvokingResource()
    if not invoking_resource or not Config.CrewLink.ExternalPingResources[invoking_resource] then
        return false
    end
    local result = Bridge.Database.Query([[
        DELETE FROM `sky_phone_crewlink_pings`
        WHERE `id` = ? AND `group_id` = ? AND `source_resource` = ?
    ]], { ping_id, group_id, invoking_resource })
    if affected_rows(result) ~= 1 then
        return false
    end
    TriggerEvent("sky_phone:crewlink:pingRemoved", group_id, ping_id)
    refresh_group(group_id)
    return true
end)
end)
