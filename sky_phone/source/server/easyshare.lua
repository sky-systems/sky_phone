SkyPhoneEasyShare = {}

Bridge.Database.AfterMigration("sky_phone", function()
local active_transfers = {}
local valid_kinds = {
    contact = true,
    document = true,
    link = true,
    location = true,
    media = true,
    note = true,
    photo = true,
    playlist = true,
    post = true,
    profile = true,
    text = true,
    track = true,
    video = true,
}
local valid_apps = {
    calendar = true,
    camera = true,
    citymarkt = true,
    companies = true,
    crewlink = true,
    darkchat = true,
    feather = true,
    flare = true,
    fliptok = true,
    house = true,
    ["local-pages"] = true,
    mail = true,
    map = true,
    messages = true,
    music = true,
    notes = true,
    phone = true,
    photos = true,
    picstagram = true,
    skypic = true,
}
local valid_visibilities = { contacts = true, everyone = true, hidden = true }

Bridge.Database.Query([[
    UPDATE `sky_phone_easyshare_transfers`
    SET `status` = 'expired', `updated_at` = CURRENT_TIMESTAMP, `completed_at` = CURRENT_TIMESTAMP
    WHERE `status` IN ('pending', 'transferring')
]], {})

local function uuid()
    local rows = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    local id = rows[1] and rows[1].id
    if type(id) ~= "string" then
        error("[sky_phone] Database did not generate an EasyShare id.")
    end
    return id
end

local rich_note_prefix = "sky-note-html-v1:"

local function plain_note_body(body)
    if body:sub(1, #rich_note_prefix) ~= rich_note_prefix then
        return body
    end

    return body:sub(#rich_note_prefix + 1)
        :gsub("<[bB][rR]%s*/?>", "\n")
        :gsub("</[pP]%s*>", "\n")
        :gsub("</[hH][1-6]%s*>", "\n")
        :gsub("<[lL][iI][^>]*>", "- ")
        :gsub("</[lL][iI]%s*>", "\n")
        :gsub("</[bB][lL][oO][cC][kK][qQ][uU][oO][tT][eE]%s*>", "\n")
        :gsub("<[^>]*>", "")
        :gsub("&nbsp;", " ")
        :gsub("&lt;", "<")
        :gsub("&gt;", ">")
        :gsub("&quot;", '"')
        :gsub("&#39;", "'")
        :gsub("&amp;", "&")
        :gsub("[ \t]+\n", "\n")
        :gsub("\n\n\n+", "\n\n")
        :match("^%s*(.-)%s*$")
end

local function trim(value, maximum)
    if type(value) ~= "string" then
        return nil
    end
    local result = value:match("^%s*(.-)%s*$")
    if result == "" or #result > maximum then
        return nil
    end
    return result
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
    return device
end

local function owner_condition(device, alias)
    local prefix = alias and ("`" .. alias .. "`.") or ""
    if device.account_id then
        return prefix .. "`account_id` = ?", { tonumber(device.account_id) }
    end
    return prefix .. "`account_id` IS NULL AND " .. prefix .. "`device_imei` = ?", { device.imei }
end

local function append_params(target, values)
    for _, value in ipairs(values) do
        target[#target + 1] = value
    end
end

local function first_row(query, params)
    local rows = Bridge.Database.Query(query, params)
    return rows[1]
end

local function canonical_profile(device, app_id, id)
    if app_id == "picstagram" then
        local profile = first_row([[
            SELECT p.`display_name`, p.`handle`, p.`bio`, media.`url` AS `image_url`
            FROM `sky_phone_picstagram_profiles` p
            LEFT JOIN `sky_phone_media` media ON media.`id` = p.`avatar_media_id`
            WHERE p.`id` = ? AND p.`status` = 'active'
                AND (p.`private` = 0 OR EXISTS(
                    SELECT 1 FROM `sky_phone_picstagram_sessions` session
                    WHERE session.`device_imei` = ? AND session.`profile_id` = p.`id`
                ) OR EXISTS(
                    SELECT 1 FROM `sky_phone_picstagram_follows` follow
                    WHERE follow.`following_id` = p.`id` AND follow.`status` = 'accepted'
                        AND follow.`follower_id` = (
                            SELECT session.`profile_id` FROM `sky_phone_picstagram_sessions` session
                            WHERE session.`device_imei` = ? LIMIT 1
                        )
                )) LIMIT 1
        ]], { id, device.imei, device.imei })
        if profile then
            return {
                title = profile.display_name,
                subtitle = "@" .. profile.handle,
                copyText = "@" .. profile.handle,
                imageUrl = profile.image_url,
                link = "skyphone://picstagram/profile/" .. id,
            }
        end
    elseif app_id == "feather" then
        local profile = first_row([[
            SELECT p.`display_name`, p.`handle`, media.`url` AS `image_url`
            FROM `sky_phone_feather_profiles` p
            LEFT JOIN `sky_phone_media` media ON media.`id` = p.`avatar_media_id`
            WHERE p.`id` = ? LIMIT 1
        ]], { id })
        if profile then
            return {
                title = profile.display_name,
                subtitle = "@" .. profile.handle,
                copyText = "@" .. profile.handle,
                imageUrl = profile.image_url,
                link = "skyphone://feather/profile/" .. id,
            }
        end
    elseif app_id == "fliptok" then
        local profile = first_row("SELECT `display_name`, `handle` FROM `sky_phone_fliptok_profiles` WHERE `id` = ? LIMIT 1", { id })
        if profile then
            return {
                title = profile.display_name,
                subtitle = "@" .. profile.handle,
                copyText = "@" .. profile.handle,
                link = "skyphone://fliptok/profile/" .. id,
            }
        end
    elseif app_id == "flare" and device.account_id then
        local profile = first_row([[
            SELECT p.`name`, p.`age`, p.`bio`, media.`url` AS `image_url`
            FROM `sky_phone_flare_profiles` p
            LEFT JOIN `sky_phone_flare_profile_photos` photo ON photo.`profile_id` = p.`id` AND photo.`sort_order` = 1
            LEFT JOIN `sky_phone_media` media ON media.`id` = photo.`media_id`
            WHERE p.`id` = ? AND p.`account_id` = ? LIMIT 1
        ]], { id, tonumber(device.account_id) })
        if profile then
            local title = ("%s, %s"):format(profile.name, profile.age)
            return {
                title = title,
                copyText = title .. "\n" .. profile.bio,
                imageUrl = profile.image_url,
                link = "skyphone://flare/profile/" .. id,
            }
        end
    elseif app_id == "crewlink" and device.account_id then
        local profile = first_row([[
            SELECT p.`username`, g.`name` AS `group_name`
            FROM `sky_phone_crewlink_profiles` p
            LEFT JOIN `sky_phone_crewlink_groups` g ON g.`id` = p.`active_group_id`
            WHERE p.`id` = ? AND p.`account_id` = ? LIMIT 1
        ]], { id, tonumber(device.account_id) })
        if profile then
            return {
                title = "@" .. profile.username,
                subtitle = profile.group_name,
                copyText = "@" .. profile.username,
                link = "skyphone://crewlink/profile/" .. id,
            }
        end
    elseif app_id == "darkchat" and device.account_id then
        local profile = first_row([[
            SELECT `alias`, `dark_id`, `invite_code` FROM `sky_phone_darkchat_profiles`
            WHERE `id` = ? AND `account_id` = ? LIMIT 1
        ]], { id, tonumber(device.account_id) })
        if profile then
            return {
                title = profile.alias,
                subtitle = profile.dark_id,
                copyText = profile.alias .. "\n" .. profile.dark_id .. "\n" .. profile.invite_code,
                link = "skyphone://darkchat/invite/" .. profile.invite_code,
            }
        end
    elseif app_id == "companies" then
        local definition = Config.Companies.Enabled and Config.Companies.Definitions[id] or nil
        if definition and definition.Public then
            local profile = first_row([[
                SELECT profile.`description`, media.`url` AS `image_url`
                FROM `sky_phone_company_profiles` profile
                LEFT JOIN `sky_phone_media` media ON media.`id` = profile.`logo_media_id`
                WHERE profile.`company_id` = ? LIMIT 1
            ]], { id })
            return {
                title = definition.Name,
                subtitle = definition.ServiceLine.Number,
                copyText = definition.Name .. "\n" .. (profile and profile.description or definition.Description),
                imageUrl = profile and profile.image_url or nil,
                link = "skyphone://companies/profile/" .. id,
            }
        end
    end
    return nil
end

local function canonical_crewlink_invite(device, invite_code)
    if not device.account_id
        or type(invite_code) ~= "string"
        or #invite_code ~= 8
        or invite_code:find("[^A-Z0-9]")
    then
        return nil
    end
    local group = first_row([[
        SELECT g.`name`, g.`invite_code`
        FROM `sky_phone_crewlink_profiles` p
        JOIN `sky_phone_crewlink_memberships` m ON m.`profile_id` = p.`id`
        JOIN `sky_phone_crewlink_groups` g ON g.`id` = m.`group_id`
        WHERE p.`account_id` = ? AND g.`invite_code` = ?
            AND m.`role` IN ('owner', 'coordinator')
        LIMIT 1
    ]], { tonumber(device.account_id), invite_code })
    if not group then
        return nil
    end
    local locale = SkyPhoneLocales.Resolve(Config.Bridge.Locale).Nui.Apps.crewlink
    local title = locale.shareInviteTitle:gsub("{group}", function() return group.name end)
    local copy_text = locale.shareInviteBody
        :gsub("{code}", function() return group.invite_code end)
        :gsub("{group}", function() return group.name end)
    return {
        title = title,
        subtitle = group.invite_code,
        copyText = copy_text,
        link = "skyphone://crewlink/invite/" .. group.invite_code,
    }
end

local function canonical_post(device, app_id, id)
    if app_id == "picstagram" then
        local post = first_row([[
            SELECT post.`caption`, profile.`display_name`, profile.`handle`, media.`url` AS `image_url`
            FROM `sky_phone_picstagram_posts` post
            JOIN `sky_phone_picstagram_profiles` profile ON profile.`id` = post.`profile_id`
            LEFT JOIN `sky_phone_picstagram_post_media` post_media
                ON post_media.`post_id` = post.`id` AND post_media.`position` = 1
            LEFT JOIN `sky_phone_media` media ON media.`id` = post_media.`media_id`
            WHERE post.`id` = ? AND post.`status` = 'published' AND profile.`status` = 'active'
                AND (profile.`private` = 0 OR EXISTS(
                    SELECT 1 FROM `sky_phone_picstagram_sessions` session
                    WHERE session.`device_imei` = ? AND session.`profile_id` = profile.`id`
                ) OR EXISTS(
                    SELECT 1 FROM `sky_phone_picstagram_follows` follow
                    WHERE follow.`following_id` = profile.`id` AND follow.`status` = 'accepted'
                        AND follow.`follower_id` = (
                            SELECT session.`profile_id` FROM `sky_phone_picstagram_sessions` session
                            WHERE session.`device_imei` = ? LIMIT 1
                        )
                )) LIMIT 1
        ]], { id, device.imei, device.imei })
        if post then
            local title = post.caption ~= "" and post.caption or post.display_name
            return {
                title = title,
                subtitle = "@" .. post.handle,
                copyText = "@" .. post.handle .. ": " .. post.caption,
                imageUrl = post.image_url,
                link = "skyphone://picstagram/post/" .. id,
            }
        end
    elseif app_id == "feather" then
        local post = first_row([[
            SELECT post.`body`, profile.`handle`, media.`url` AS `image_url`
            FROM `sky_phone_feather_posts` post
            JOIN `sky_phone_feather_profiles` profile ON profile.`id` = post.`profile_id`
            LEFT JOIN `sky_phone_feather_post_media` post_media
                ON post_media.`post_id` = post.`id` AND post_media.`sort_order` = 0
            LEFT JOIN `sky_phone_media` media ON media.`id` = post_media.`media_id`
            WHERE post.`id` = ? AND post.`status` = 'published' LIMIT 1
        ]], { id })
        if post then
            return {
                title = post.body,
                subtitle = "@" .. post.handle,
                copyText = "@" .. post.handle .. ": " .. post.body,
                imageUrl = post.image_url,
                link = "skyphone://feather/post/" .. id,
            }
        end
    elseif app_id == "fliptok" then
        local post = first_row([[
            SELECT video.`caption`, profile.`display_name`, profile.`handle`, media.`url` AS `image_url`
            FROM `sky_phone_fliptok_videos` video
            JOIN `sky_phone_fliptok_profiles` profile ON profile.`id` = video.`profile_id`
            JOIN `sky_phone_media` media ON media.`id` = video.`media_id`
            WHERE video.`id` = ? AND video.`status` = 'published' AND (
                video.`visibility` = 'public' OR EXISTS(
                    SELECT 1 FROM `sky_phone_fliptok_sessions` session
                    WHERE session.`device_imei` = ? AND session.`profile_id` = profile.`id`
                ) OR (video.`visibility` = 'followers' AND EXISTS(
                    SELECT 1 FROM `sky_phone_fliptok_follows` follow
                    WHERE follow.`following_id` = profile.`id` AND follow.`follower_id` = (
                        SELECT session.`profile_id` FROM `sky_phone_fliptok_sessions` session
                        WHERE session.`device_imei` = ? LIMIT 1
                    )
                ))
            ) LIMIT 1
        ]], { id, device.imei, device.imei })
        if post then
            local title = post.caption ~= "" and post.caption or post.display_name
            return {
                title = title,
                subtitle = "@" .. post.handle,
                copyText = "@" .. post.handle .. ": " .. post.caption,
                imageUrl = post.image_url,
                link = "skyphone://fliptok/video/" .. id,
            }
        end
    elseif app_id == "local-pages" then
        local post = first_row([[
            SELECT post.`title`, post.`body`, SUBSTRING_INDEX(account.`email`, '@', 1) AS `author_name`,
                media.`url` AS `image_url`
            FROM `sky_phone_pages_posts` post
            JOIN `sky_phone_accounts` account ON account.`id` = post.`account_id`
            LEFT JOIN `sky_phone_pages_images` image ON image.`post_id` = post.`id` AND image.`sort_order` = 1
            LEFT JOIN `sky_phone_media` media ON media.`id` = image.`media_id`
            WHERE post.`id` = ? LIMIT 1
        ]], { id })
        if post then
            return {
                title = post.title,
                subtitle = post.author_name,
                copyText = post.title .. "\n" .. post.body,
                imageUrl = post.image_url,
                link = "skyphone://local-pages/post/" .. id,
            }
        end
    elseif app_id == "citymarkt" then
        local post = first_row([[
            SELECT listing.`title`, listing.`description`, listing.`price`, listing.`price_type`, media.`url` AS `image_url`
            FROM `sky_phone_marketplace_listings` listing
            LEFT JOIN `sky_phone_marketplace_images` image
                ON image.`listing_id` = listing.`id` AND image.`sort_order` = 1
            LEFT JOIN `sky_phone_media` media ON media.`id` = image.`media_id`
            WHERE listing.`id` = ? AND listing.`status` IN ('active', 'reserved') LIMIT 1
        ]], { id })
        if post then
            local price = post.price_type == "fixed" and tostring(post.price) or post.price_type
            return {
                title = post.title,
                subtitle = price,
                copyText = post.title .. "\n" .. post.description,
                imageUrl = post.image_url,
                link = "skyphone://citymarkt/listing/" .. id,
            }
        end
    end
    return nil
end

local function canonical_music(device, data)
    if data.kind == "track" and type(data.meta) == "table" and data.meta.source == "server" then
        for _, track in ipairs(Config.Music.Tracks) do
            if track.Id == data.id then
                return {
                    title = track.Title,
                    subtitle = track.Artist,
                    copyText = track.Title .. " — " .. track.Artist,
                    link = "skyphone://music/server/" .. track.Id,
                    meta = { source = "server" },
                }
            end
        end
    elseif data.kind == "track" and type(data.meta) == "table" and data.meta.source == "youtube" then
        local condition, params = owner_condition(device, "song")
        local query_params = { data.id }
        append_params(query_params, params)
        local track = first_row(([=[
            SELECT song.`title`, song.`artist`, song.`video_id`
            FROM `sky_phone_music_youtube_songs` song
            WHERE song.`id` = ? AND %s LIMIT 1
        ]=]):format(condition), query_params)
        if track then
            return {
                title = track.title,
                subtitle = track.artist,
                copyText = track.title .. " — " .. track.artist,
                imageUrl = "https://i.ytimg.com/vi/" .. track.video_id .. "/hqdefault.jpg",
                link = "skyphone://music/youtube/" .. data.id,
                meta = { source = "youtube" },
            }
        end
    elseif data.kind == "playlist" then
        local condition, params = owner_condition(device, "playlist")
        local query_params = { data.id }
        append_params(query_params, params)
        local playlist = first_row(([=[
            SELECT playlist.`name`, COUNT(item.`id`) AS `song_count`
            FROM `sky_phone_music_playlists` playlist
            LEFT JOIN `sky_phone_music_playlist_items` item ON item.`playlist_id` = playlist.`id`
            WHERE playlist.`id` = ? AND %s
            GROUP BY playlist.`id`, playlist.`name` LIMIT 1
        ]=]):format(condition), query_params)
        if playlist then
            return {
                title = playlist.name,
                subtitle = tostring(playlist.song_count) .. " tracks",
                copyText = playlist.name .. " · " .. tostring(playlist.song_count),
                link = "skyphone://music/playlist/" .. data.id,
            }
        end
    end
    return nil
end

local function canonical_document(source, device, app_id, id)
    if app_id == "calendar" and device.account_id then
        local event = first_row([[
            SELECT `title`, `note`, `starts_at`, `ends_at` FROM `sky_phone_calendar_events`
            WHERE `id` = ? AND `account_id` = ? LIMIT 1
        ]], { id, tonumber(device.account_id) })
        if event then
            return {
                title = event.title,
                subtitle = tostring(event.starts_at),
                copyText = event.title .. "\n" .. event.note,
                link = "skyphone://calendar/event/" .. id,
                meta = { startAt = tostring(event.starts_at), endAt = tostring(event.ends_at) },
            }
        end
    elseif app_id == "mail" and device.account_id then
        local message = first_row([[
            SELECT message.`subject`, message.`body`, sender.`email` AS `sender_email`
            FROM `sky_phone_mail_entries` entry
            JOIN `sky_phone_mail_messages` message ON message.`id` = entry.`message_id`
            LEFT JOIN `sky_phone_accounts` sender ON sender.`id` = message.`sender_account_id`
            WHERE entry.`id` = ? AND entry.`account_id` = ? AND entry.`trashed_at` IS NULL LIMIT 1
        ]], { id, tonumber(device.account_id) })
        if message then
            return {
                title = message.subject,
                subtitle = message.sender_email,
                copyText = message.subject .. "\n" .. message.body,
                link = "skyphone://mail/message/" .. id,
            }
        end
    elseif app_id == "house" then
        return SkyPhoneHousing.ResolveShare(source, id)
    end
    return nil
end

local function canonical_text(device, app_id, id)
    if app_id ~= "darkchat" or not device.account_id then
        return nil
    end
    local message = first_row([[
        SELECT message.`body`, message.`message_type`, sender.`alias` AS `sender_alias`
        FROM `sky_phone_darkchat_messages` message
        JOIN `sky_phone_darkchat_members` member ON member.`conversation_id` = message.`conversation_id`
        JOIN `sky_phone_darkchat_profiles` viewer ON viewer.`id` = member.`profile_id`
        LEFT JOIN `sky_phone_darkchat_profiles` sender ON sender.`id` = message.`sender_profile_id`
        WHERE message.`id` = ? AND viewer.`account_id` = ? AND message.`deleted_for_everyone` = 0
            AND message.`message_type` IN ('text', 'emoji') LIMIT 1
    ]], { id, tonumber(device.account_id) })
    if not message then
        return nil
    end
    return {
        title = message.body,
        subtitle = message.sender_alias,
        copyText = message.body,
    }
end

local function display_name(source)
    local first = trim(Bridge.Framework.GetFirstname(source), 80)
    local last = trim(Bridge.Framework.GetLastname(source), 80)
    local name = table.concat({ first or "", last or "" }, " "):match("^%s*(.-)%s*$")
    return name ~= "" and name or GetPlayerName(source) or ("Player %s"):format(source)
end

local function visibility_for(imei)
    local rows = Bridge.Database.Query([[ 
        SELECT `visibility` FROM `sky_phone_easyshare_preferences`
        WHERE `device_imei` = ? LIMIT 1
    ]], { imei })
    local visibility = rows[1] and rows[1].visibility or Config.EasyShare.DefaultVisibility
    return valid_visibilities[visibility] and visibility or "hidden"
end

local function distance_between(left_source, right_source)
    if GetPlayerRoutingBucket(left_source) ~= GetPlayerRoutingBucket(right_source) then
        return nil
    end
    local left_ped = GetPlayerPed(left_source)
    local right_ped = GetPlayerPed(right_source)
    if left_ped == 0 or right_ped == 0 then
        return nil
    end
    return #(GetEntityCoords(left_ped) - GetEntityCoords(right_ped))
end

local function visible_to(target_device, sender_device, visibility)
    if visibility == "everyone" then
        return true
    end
    if visibility ~= "contacts" or not sender_device.phone_number then
        return false
    end
    local condition, owner_params = owner_condition(target_device)
    local params = { sender_device.phone_number }
    append_params(params, owner_params)
    local rows = Bridge.Database.Query(([[
        SELECT `id` FROM `sky_phone_contacts`
        WHERE `phone_number` = ? AND %s LIMIT 1
    ]]):format(condition), params)
    return rows[1] ~= nil
end

local function target_state(sender_source, target_source, sender_device)
    if target_source == sender_source then
        return nil
    end
    local target_device = current_device(target_source)
    if not target_device then
        return nil
    end
    local visibility = visibility_for(target_device.imei)
    if not visible_to(target_device, sender_device, visibility) then
        return nil
    end
    local distance = distance_between(sender_source, target_source)
    if not distance or distance > Config.EasyShare.MaximumDistance then
        return nil
    end
    return { device = target_device, distance = distance }
end

local function nearby_targets(source, device)
    local targets = {}
    for _, target in ipairs(Bridge.Framework.GetPlayers()) do
        local target_source = tonumber(target)
        if target_source then
            local state = target_state(source, target_source, device)
            if state then
                targets[#targets + 1] = {
                    id = target_source,
                    name = display_name(target_source),
                    distance = math.floor(state.distance * 10 + 0.5) / 10,
                }
            end
        end
    end
    table.sort(targets, function(left, right)
        return left.distance < right.distance
    end)
    return targets
end

local function canonical_own_contact(source, device)
    if not device.phone_number then
        return nil
    end
    local name = display_name(source)
    return {
        appId = "phone",
        kind = "contact",
        id = "self",
        title = name,
        subtitle = device.phone_number,
        copyText = ("%s\n%s"):format(name, device.phone_number),
        meta = {
            name = name,
            phoneNumber = device.phone_number,
        },
    }
end

local function sanitize_payload(source, device, data)
    if type(data) ~= "table" or not valid_kinds[data.kind] then
        return nil, "invalid_payload"
    end
    local title = trim(data.title, 160)
    local copy_text = trim(data.copyText, 4000)
    local app_id = trim(data.appId, 48)
    if not title or not copy_text or not app_id or not valid_apps[app_id] then
        return nil, "invalid_payload"
    end
    local payload = {
        appId = app_id,
        kind = data.kind,
        title = title,
        copyText = copy_text,
    }
    if type(data.id) == "string" and #data.id <= 128 then
        payload.id = data.id
    elseif type(data.id) == "number" and data.id > 0 and data.id == math.floor(data.id) then
        payload.id = data.id
    end
    if type(data.subtitle) == "string" and #data.subtitle <= 240 then
        payload.subtitle = data.subtitle
    end
    if type(data.link) == "string" and #data.link <= 500 and data.link:match("^[%w_%-]+://") then
        payload.link = data.link
    end

    local condition, owner_params = owner_condition(device)
    if data.kind == "contact" and type(payload.id) == "string" then
        if app_id == "phone" and payload.id == "self" then
            local contact = canonical_own_contact(source, device)
            if not contact then
                return nil, "sim_required"
            end
            payload.title = contact.title
            payload.subtitle = contact.subtitle
            payload.copyText = contact.copyText
            payload.meta = contact.meta
        else
            local params = { payload.id }
            append_params(params, owner_params)
            local rows = Bridge.Database.Query(([[
                SELECT `name`, `phone_number`, `organization`, `notes`
                FROM `sky_phone_contacts` WHERE `contact_id` = ? AND %s LIMIT 1
            ]]):format(condition), params)
            local contact = rows[1]
            if not contact then
                return nil, "not_owned"
            end
            payload.title = contact.name
            payload.subtitle = contact.phone_number
            payload.copyText = ("%s\n%s"):format(contact.name, contact.phone_number)
            payload.meta = {
                name = contact.name,
                notes = contact.notes,
                organization = contact.organization,
                phoneNumber = contact.phone_number,
            }
        end
    elseif data.kind == "note" and type(payload.id) == "string" then
        local params = { payload.id }
        append_params(params, owner_params)
        local rows = Bridge.Database.Query(([[
            SELECT `title`, `body` FROM `sky_phone_notes`
            WHERE `id` = ? AND %s LIMIT 1
        ]]):format(condition), params)
        local note = rows[1]
        if not note then
            return nil, "not_owned"
        end
        payload.title = note.title ~= "" and note.title or title
        payload.copyText = plain_note_body(note.body)
        payload.meta = { body = note.body, title = note.title }
    elseif data.kind == "media" and app_id == "photos" and type(data.meta) == "table" and type(data.meta.mediaIds) == "table" then
        local media_ids = {}
        local seen_ids = {}
        for _, value in ipairs(data.meta.mediaIds) do
            local media_id = tonumber(value)
            if media_id and media_id > 0 and media_id == math.floor(media_id) and not seen_ids[media_id] then
                seen_ids[media_id] = true
                media_ids[#media_ids + 1] = media_id
            end
        end
        if #media_ids < 1 or #media_ids > 50 then
            return nil, "invalid_payload"
        end
        local placeholders = {}
        local media_params = {}
        for _, media_id in ipairs(media_ids) do
            placeholders[#placeholders + 1] = "?"
            media_params[#media_params + 1] = media_id
        end
        append_params(media_params, owner_params)
        local media_rows = Bridge.Database.Query(([[
            SELECT `id`, `url`, `media_type` AS `mediaType`
            FROM `sky_phone_media`
            WHERE `id` IN (%s) AND %s AND `media_type` IN ('photo', 'video')
            ORDER BY `created_at` ASC, `id` ASC
        ]]):format(table.concat(placeholders, ", "), condition), media_params)
        if #media_rows ~= #media_ids then
            return nil, "not_owned"
        end
        local items = {}
        for _, row in ipairs(media_rows) do
            items[#items + 1] = {
                id = tonumber(row.id),
                mediaType = row.mediaType,
                url = row.url,
            }
        end
        payload.imageUrl = items[1].url
        payload.meta = { items = items }
    elseif data.kind == "photo" or data.kind == "video" then
        local url, media_error = SkyPhoneMedia.ResolveOwnedMedia(source, payload.id, data.kind)
        if not url then
            return nil, media_error or "not_owned"
        end
        local media_params = { tonumber(payload.id) }
        append_params(media_params, owner_params)
        local media_rows = Bridge.Database.Query(([[
            SELECT `remote_id` FROM `sky_phone_media`
            WHERE `id` = ? AND %s LIMIT 1
        ]]):format(condition), media_params)
        if not media_rows[1] then
            return nil, "not_owned"
        end
        payload.imageUrl = url
        payload.meta = { remoteId = media_rows[1].remote_id, url = url }
    elseif data.kind == "location" then
        local ped = GetPlayerPed(source)
        if ped == 0 then
            return nil, "location_unavailable"
        end
        local coords = GetEntityCoords(ped)
        payload.meta = { x = coords.x, y = coords.y, z = coords.z }
    else
        local canonical
        if data.kind == "profile" and payload.id then
            canonical = canonical_profile(device, app_id, payload.id)
        elseif data.kind == "post" and payload.id then
            canonical = canonical_post(device, app_id, payload.id)
        elseif (data.kind == "track" or data.kind == "playlist") and app_id == "music" and payload.id then
            canonical = canonical_music(device, data)
        elseif data.kind == "document" and payload.id then
            canonical = canonical_document(source, device, app_id, payload.id)
        elseif data.kind == "text" and payload.id then
            canonical = canonical_text(device, app_id, payload.id)
        elseif data.kind == "link" and payload.id then
            if app_id == "citymarkt" or app_id == "local-pages" then
                canonical = canonical_post(device, app_id, payload.id)
            elseif app_id == "crewlink" then
                canonical = canonical_crewlink_invite(device, payload.id)
            end
        end
        if not canonical then
            return nil, "unsupported_payload"
        end
        payload.title = canonical.title
        payload.copyText = canonical.copyText
        payload.subtitle = canonical.subtitle
        payload.imageUrl = canonical.imageUrl
        payload.link = canonical.link
        payload.meta = canonical.meta
    end

    local encoded = json.encode(payload)
    if #encoded > Config.EasyShare.PayloadMaxBytes then
        return nil, "payload_too_large"
    end
    return payload, nil, encoded
end

function SkyPhoneEasyShare.SanitizeChatPayload(source, data)
    if not Config.EasyShare.Enabled then
        return nil, "disabled"
    end
    local device, error_response = current_device(source)
    if not device then
        return nil, error_response.error
    end
    return sanitize_payload(source, device, data)
end

local function transfer_for_source(transfer, source)
    local incoming = transfer.recipient_source == source
    return {
        id = transfer.id,
        direction = incoming and "incoming" or "outgoing",
        otherName = incoming and transfer.sender_name or transfer.recipient_name,
        payload = transfer.payload,
        progress = transfer.progress,
        status = transfer.status,
        createdAt = transfer.created_at,
    }
end

local function notify_transfer(transfer)
    TriggerClientEvent("sky_phone:easyshare:changed", transfer.sender_source, {
        transfer = transfer_for_source(transfer, transfer.sender_source),
    })
    TriggerClientEvent("sky_phone:easyshare:changed", transfer.recipient_source, {
        transfer = transfer_for_source(transfer, transfer.recipient_source),
    })
end

local function persist_state(transfer)
    Bridge.Database.Query([[ 
        UPDATE `sky_phone_easyshare_transfers`
        SET `status` = ?, `progress` = ?, `updated_at` = CURRENT_TIMESTAMP,
            `completed_at` = IF(? IN ('completed','declined','cancelled','expired','failed'), CURRENT_TIMESTAMP, `completed_at`)
        WHERE `id` = ?
    ]], { transfer.status, transfer.progress, transfer.status, transfer.id })
end

local function finish_transfer(transfer, status)
    if transfer.status ~= "pending" and transfer.status ~= "transferring" then
        return
    end
    transfer.status = status
    transfer.progress = status == "completed" and 100 or transfer.progress
    persist_state(transfer)
    notify_transfer(transfer)
    active_transfers[transfer.id] = nil
end

local function apply_received_payload(transfer)
    local device = SkyPhone.LoadDevice(transfer.recipient_imei)
    if not device then
        return false
    end
    local account_id = device.account_id and tonumber(device.account_id) or nil
    local meta = transfer.payload.meta or {}
    if transfer.payload.kind == "contact" then
        Bridge.Database.Query([[ 
            INSERT INTO `sky_phone_contacts`
                (`id`, `contact_id`, `account_id`, `device_imei`, `name`, `notes`, `organization`, `phone_number`)
            VALUES (?, ?, ?, ?, ?, NULLIF(?, ''), NULLIF(?, ''), ?)
        ]], {
            uuid(), uuid(), account_id, account_id and nil or device.imei,
            meta.name, meta.notes or "", meta.organization or "", meta.phoneNumber,
        })
        TriggerClientEvent("sky_phone:contacts:changed", transfer.recipient_source, {})
    elseif transfer.payload.kind == "note" or transfer.payload.kind == "text" or transfer.payload.kind == "document" then
        Bridge.Database.Query([[ 
            INSERT INTO `sky_phone_notes`
                (`id`, `account_id`, `device_imei`, `title`, `body`, `pinned`)
            VALUES (?, ?, ?, ?, ?, 0)
        ]], {
            uuid(), account_id, account_id and nil or device.imei,
            meta.title or transfer.payload.title, meta.body or transfer.payload.copyText,
        })
        if account_id then
            SkyPhone.RefreshAccount(account_id)
        else
            SkyPhone.RefreshDevice(device.imei)
        end
    elseif transfer.payload.kind == "location" then
        Bridge.Database.Query([[ 
            INSERT INTO `sky_phone_map_markers`
                (`id`, `device_imei`, `label`, `color`, `position_x`, `position_y`, `position_z`)
            VALUES (?, ?, ?, 'blue', ?, ?, ?)
        ]], { uuid(), device.imei, transfer.payload.title:sub(1, 40), meta.x, meta.y, meta.z })
    elseif transfer.payload.kind == "photo" or transfer.payload.kind == "video" then
        Bridge.Database.Query([[ 
            INSERT INTO `sky_phone_media` (`account_id`, `device_imei`, `url`, `remote_id`, `media_type`)
            VALUES (?, ?, ?, ?, ?)
        ]], {
            account_id, account_id and nil or device.imei, meta.url, meta.remoteId, transfer.payload.kind,
        })
        TriggerClientEvent("sky_phone:gallery:changed", transfer.recipient_source, {})
    elseif transfer.payload.kind == "post"
        or transfer.payload.kind == "profile"
        or transfer.payload.kind == "track"
        or transfer.payload.kind == "playlist"
        or transfer.payload.kind == "link"
    then
        return type(transfer.payload.link) == "string"
    else
        return false
    end
    return true
end

local function advance_transfer(id)
    local transfer = active_transfers[id]
    if not transfer or transfer.status ~= "transferring" then
        return
    end
    local distance = distance_between(transfer.sender_source, transfer.recipient_source)
    if not distance or distance > Config.EasyShare.MaximumDistance then
        finish_transfer(transfer, "failed")
        return
    end
    transfer.progress = math.min(100, transfer.progress + 10)
    persist_state(transfer)
    notify_transfer(transfer)
    if transfer.progress >= 100 then
        if apply_received_payload(transfer) then
            finish_transfer(transfer, "completed")
        else
            finish_transfer(transfer, "failed")
        end
        return
    end
    SetTimeout(math.max(100, math.floor(Config.EasyShare.TransferDurationMs / 10)), function()
        advance_transfer(id)
    end)
end

local function row_transfer(row, current_imei)
    local decoded = json.decode(row.payload)
    return {
        id = row.id,
        direction = row.recipient_imei == current_imei and "incoming" or "outgoing",
        otherName = row.recipient_imei == current_imei and row.sender_name or row.recipient_name,
        payload = decoded,
        progress = tonumber(row.progress) or 0,
        status = row.status,
        createdAt = (tonumber(row.created_at_unix) or 0) * 1000,
    }
end

local function history(device)
    local rows = Bridge.Database.Query([[ 
        SELECT `id`, `sender_imei`, `recipient_imei`, `sender_name`, `recipient_name`,
            `payload`, `status`, `progress`, UNIX_TIMESTAMP(`created_at`) AS `created_at_unix`
        FROM `sky_phone_easyshare_transfers`
        WHERE `sender_imei` = ? OR `recipient_imei` = ?
        ORDER BY `created_at` DESC LIMIT ?
    ]], { device.imei, device.imei, Config.EasyShare.HistoryLimit })
    local result = {}
    for index, row in ipairs(rows) do
        result[index] = row_transfer(row, device.imei)
    end
    return result
end

Bridge.Callbacks.Register("sky_phone:easyshare:bootstrap", function(source)
    if not Config.EasyShare.Enabled then
        return { success = false, error = "disabled" }
    end
    if not SkyPhone.AllowOperation(source, "easyshare_bootstrap", Config.EasyShare.BootstrapRequestsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local device, error_response = current_device(source)
    if not device then
        return error_response
    end
    local pending = {}
    for _, transfer in pairs(active_transfers) do
        if transfer.sender_source == source or transfer.recipient_source == source then
            pending[#pending + 1] = transfer_for_source(transfer, source)
        end
    end
    return {
        success = true,
        data = {
            history = history(device),
            pending = pending,
            targets = nearby_targets(source, device),
            visibility = visibility_for(device.imei),
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:easyshare:own-contact", function(source)
    if not Config.EasyShare.Enabled then
        return { success = false, error = "disabled" }
    end
    if not SkyPhone.AllowOperation(source, "easyshare_own_contact", Config.EasyShare.BootstrapRequestsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local device, error_response = current_device(source)
    if not device then
        return error_response
    end
    local payload = canonical_own_contact(source, device)
    if not payload then
        return { success = false, error = "sim_required" }
    end
    return { success = true, data = payload }
end)

Bridge.Callbacks.Register("sky_phone:easyshare:set-visibility", function(source, data)
    if not Config.EasyShare.Enabled then
        return { success = false, error = "disabled" }
    end
    if not SkyPhone.AllowOperation(source, "easyshare_visibility", Config.EasyShare.VisibilityUpdatesPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local device, error_response = current_device(source)
    if not device then
        return error_response
    end
    local visibility = type(data) == "table" and data.visibility or nil
    if not valid_visibilities[visibility] then
        return { success = false, error = "invalid_visibility" }
    end
    Bridge.Database.Query([[ 
        INSERT INTO `sky_phone_easyshare_preferences` (`device_imei`, `visibility`)
        VALUES (?, ?) ON DUPLICATE KEY UPDATE `visibility` = VALUES(`visibility`)
    ]], { device.imei, visibility })
    return { success = true, data = { visibility = visibility } }
end)

Bridge.Callbacks.Register("sky_phone:easyshare:request", function(source, data)
    if not Config.EasyShare.Enabled then
        return { success = false, error = "disabled" }
    end
    if not SkyPhone.AllowOperation(source, "easyshare_request", Config.EasyShare.RequestsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local sender_device, error_response = current_device(source)
    if not sender_device then
        return error_response
    end
    local target_source = type(data) == "table" and tonumber(data.targetId) or nil
    if not target_source or target_source ~= math.floor(target_source) then
        return { success = false, error = "invalid_target" }
    end
    local target = target_state(source, target_source, sender_device)
    if not target then
        return { success = false, error = "target_unavailable" }
    end
    local payload, payload_error, encoded = sanitize_payload(source, sender_device, data.payload)
    if not payload then
        return { success = false, error = payload_error }
    end
    local id = uuid()
    local transfer = {
        id = id,
        sender_source = source,
        recipient_source = target_source,
        sender_imei = sender_device.imei,
        recipient_imei = target.device.imei,
        sender_name = display_name(source),
        recipient_name = display_name(target_source),
        payload = payload,
        progress = 0,
        status = "pending",
        created_at = os.time() * 1000,
    }
    Bridge.Database.Query([[ 
        INSERT INTO `sky_phone_easyshare_transfers`
            (`id`, `sender_imei`, `recipient_imei`, `sender_name`, `recipient_name`, `content_type`, `payload`, `status`, `progress`)
        VALUES (?, ?, ?, ?, ?, ?, ?, 'pending', 0)
    ]], { id, sender_device.imei, target.device.imei, transfer.sender_name, transfer.recipient_name, payload.kind, encoded })
    active_transfers[id] = transfer
    notify_transfer(transfer)
    SetTimeout(Config.EasyShare.PendingSeconds * 1000, function()
        local current = active_transfers[id]
        if current and current.status == "pending" then
            finish_transfer(current, "expired")
        end
    end)
    return { success = true, data = transfer_for_source(transfer, source) }
end)

Bridge.Callbacks.Register("sky_phone:easyshare:respond", function(source, data)
    if not Config.EasyShare.Enabled then
        return { success = false, error = "disabled" }
    end
    if not SkyPhone.AllowOperation(source, "easyshare_action", Config.EasyShare.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local id = type(data) == "table" and data.id or nil
    local transfer = type(id) == "string" and active_transfers[id] or nil
    if not transfer or transfer.recipient_source ~= source or transfer.status ~= "pending" or type(data.accepted) ~= "boolean" then
        return { success = false, error = "transfer_not_found" }
    end
    if not data.accepted then
        finish_transfer(transfer, "declined")
        return { success = true, data = transfer_for_source(transfer, source) }
    end
    local distance = distance_between(transfer.sender_source, transfer.recipient_source)
    if not distance or distance > Config.EasyShare.MaximumDistance then
        finish_transfer(transfer, "failed")
        return { success = false, error = "too_far" }
    end
    transfer.status = "transferring"
    persist_state(transfer)
    notify_transfer(transfer)
    SetTimeout(math.max(100, math.floor(Config.EasyShare.TransferDurationMs / 10)), function()
        advance_transfer(id)
    end)
    return { success = true, data = transfer_for_source(transfer, source) }
end)

Bridge.Callbacks.Register("sky_phone:easyshare:cancel", function(source, data)
    if not Config.EasyShare.Enabled then
        return { success = false, error = "disabled" }
    end
    if not SkyPhone.AllowOperation(source, "easyshare_action", Config.EasyShare.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local id = type(data) == "table" and data.id or nil
    local transfer = type(id) == "string" and active_transfers[id] or nil
    if not transfer or (transfer.sender_source ~= source and transfer.recipient_source ~= source) then
        return { success = false, error = "transfer_not_found" }
    end
    finish_transfer(transfer, "cancelled")
    return { success = true, data = transfer_for_source(transfer, source) }
end)

AddEventHandler("playerDropped", function()
    local dropped_source = source
    for _, transfer in pairs(active_transfers) do
        if transfer.sender_source == dropped_source or transfer.recipient_source == dropped_source then
            finish_transfer(transfer, "failed")
        end
    end
end)
end)
