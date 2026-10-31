Bridge.Database.AfterMigration("sky_phone", function()
local BUILTIN_APPS = {
    banking = true,
    billing = true,
    calculator = true,
    calendar = true,
    camera = true,
    citymarkt = true,
    citywarn = true,
    clock = true,
    companies = true,
    crewlink = true,
    crypto = true,
    darkchat = true,
    feather = true,
    flare = true,
    fliptok = true,
    garage = true,
    health = true,
    house = true,
    ["app-store"] = true,
    ["local-pages"] = true,
    mail = true,
    map = true,
    memos = true,
    memory = true,
    messages = true,
    minesweeper = true,
    music = true,
    ["neon-drop"] = true,
    notes = true,
    ["number-merge"] = true,
    phone = true,
    photos = true,
    picstagram = true,
    radio = true,
    settings = true,
    ["sky-flappy"] = true,
    skyride = true,
    snake = true,
    ["tower-stack"] = true,
    weather = true,
    ["weazel-news"] = true,
}

local DEFAULT_INSTALLED_APPS = {
    ["app-store"] = true,
    calculator = true,
    calendar = true,
    camera = true,
    citywarn = true,
    clock = true,
    health = true,
    mail = true,
    map = true,
    memos = true,
    messages = true,
    notes = true,
    phone = true,
    photos = true,
    settings = true,
    weather = true,
}

local PROTECTED_APPS = {
    ["app-store"] = true,
    camera = true,
    citywarn = true,
    health = true,
    mail = true,
    messages = true,
    phone = true,
    photos = true,
    settings = true,
}

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end

    return type(result) == "table" and tonumber(result.affectedRows) or 0
end

local function trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return value:match("^%s*(.-)%s*$")
end

local function player_name(source)
    local first_name = trim(Bridge.Framework.GetFirstname(source))
    local last_name = trim(Bridge.Framework.GetLastname(source))
    local character_name = trim((first_name .. " " .. last_name))
    return character_name ~= "" and character_name or GetPlayerName(source) or ("Player %s"):format(source)
end

local function require_admin(source, operation, maximum)
    if not Config.AdminPanel.Enabled
        or not Bridge.Framework.HasPermission(source, "phonepanel")
    then
        Bridge.Debug("warn", "[sky_phone] Rejected admin panel access from source %s.", tostring(source))
        return nil, { success = false, error = "not_authorized" }
    end
    if not SkyPhone.AllowOperation(source, "admin_" .. operation, maximum, 60) then
        return nil, { success = false, error = "rate_limited" }
    end
    return true
end

local active_admin_command

local function run_admin_command(command_source)
    local player_source = tonumber(command_source)
    if not player_source or player_source < 1 then
        Bridge.Debug("warn", "[sky_phone] The admin panel command can only be used by a player.")
        return
    end
    if not Config.AdminPanel.Enabled then
        TriggerClientEvent("sky_phone:admin:command-error", player_source, "disabled")
        return
    end
    if not Bridge.Framework.HasPermission(player_source, "phonepanel") then
        Bridge.Debug(
            "warn",
            "[sky_phone] Rejected admin panel command from source %s.",
            tostring(player_source)
        )
        TriggerClientEvent("sky_phone:admin:command-error", player_source, "not_authorized")
        return
    end

    TriggerClientEvent("sky_phone:admin:launch", player_source)
end

local function register_admin_command()
    local command_name = Config.AdminPanel.Command
    if type(command_name) ~= "string" or command_name == "" then
        error("[sky_phone] Config.AdminPanel.Command must be a non-empty command name.")
    end
    if command_name == active_admin_command then
        return
    end
    active_admin_command = command_name
    RegisterCommand(command_name, function(command_source)
        if active_admin_command == command_name then
            run_admin_command(command_source)
        end
    end, false)
end

register_admin_command()

AddEventHandler("sky_phone:configurator:serverUpdated", function()
    register_admin_command()
end)

local function normalize_source(value)
    local player_source = tonumber(value)
    if not player_source or player_source < 1 or player_source ~= math.floor(player_source) then
        return nil
    end
    if not Bridge.Framework.GetIdentifier(player_source) then
        return nil
    end
    return player_source
end

local function collect_device_imeis(source, identifier)
    local imeis = {}
    local seen = {}
    local function add_imei(imei)
        if SkyPhoneImei.IsValid(imei) and not seen[imei] then
            seen[imei] = true
            imeis[#imeis + 1] = imei
        end
    end

    for _, item in ipairs(Bridge.Inventory.GetSlotsWithItem(source, Config.Phone.Item)) do
        add_imei(item.metadata and item.metadata.imei)
    end

    local rows = Bridge.Database.Query([[
        SELECT `device_imei` AS `imei`
        FROM `sky_phone_character_devices`
        WHERE `owner_identifier` = ?
        UNION
        SELECT device.`imei`
        FROM `sky_phone_devices` device
        JOIN `sky_phone_sims` sim ON sim.`id` = device.`sim_id`
        WHERE sim.`owner_identifier` = ?
    ]], { identifier, identifier })
    for _, row in ipairs(rows) do
        add_imei(row.imei)
    end

    table.sort(imeis)
    return imeis
end

local function normalize_app_ids(value)
    local normalized = {}
    local seen = {}
    if type(value) ~= "table" then
        return normalized
    end

    for index = 1, #value do
        local app_id = value[index]
        if type(app_id) == "string"
            and #app_id > 0
            and #app_id <= 64
            and not seen[app_id]
        then
            seen[app_id] = true
            normalized[#normalized + 1] = app_id
        end
    end
    return normalized
end

local function load_app_payload(encoded)
    if type(encoded) ~= "string" or encoded == "" then
        return {}, {}, {}
    end
    local payload = json.decode(encoded)
    if type(payload) ~= "table" then
        error("[sky_phone] Stored admin target app payload is not a JSON object.")
    end
    return payload, normalize_app_ids(payload.claimedApps), normalize_app_ids(payload.uninstalledApps)
end

local function load_player_devices(source, identifier)
    local imeis = collect_device_imeis(source, identifier)
    if #imeis == 0 then
        return {}
    end

    local placeholders = {}
    for index = 1, #imeis do
        placeholders[index] = "?"
    end
    local rows = Bridge.Database.Query(([[
        SELECT device.`imei`, device.`device_name`, device.`created_at`, device.`updated_at`,
            sim.`phone_number`, sim.`sim_type`, sim.`registered_at`,
            account.`id` AS `account_id`, account.`email` AS `account_email`,
            security.`passcode_length`, security.`failed_attempts`, security.`locked_until`,
            app_data.`payload` AS `apps_payload`, app_data.`revision` AS `apps_revision`
        FROM `sky_phone_devices` device
        LEFT JOIN `sky_phone_sims` sim ON sim.`id` = device.`sim_id`
        LEFT JOIN `sky_phone_accounts` account ON account.`id` = device.`account_id`
        LEFT JOIN `sky_phone_device_security` security ON security.`device_imei` = device.`imei`
        LEFT JOIN `sky_phone_device_data` app_data
            ON app_data.`device_imei` = device.`imei` AND app_data.`namespace` = 'apps'
        WHERE device.`imei` IN (%s)
        ORDER BY device.`updated_at` DESC, device.`imei` ASC
    ]]):format(table.concat(placeholders, ", ")), imeis)

    local devices = {}
    for _, row in ipairs(rows) do
        local _, claimed_apps, uninstalled_apps = load_app_payload(row.apps_payload)
        devices[#devices + 1] = {
            imei = row.imei,
            name = row.device_name,
            createdAt = row.created_at,
            updatedAt = row.updated_at,
            number = row.phone_number,
            simType = row.sim_type,
            simRegistered = row.registered_at ~= nil,
            account = row.account_id and {
                id = tonumber(row.account_id),
                email = row.account_email,
                passwordAvailable = true,
            } or nil,
            security = {
                enabled = row.passcode_length ~= nil,
                length = row.passcode_length and tonumber(row.passcode_length) or nil,
                failedAttempts = tonumber(row.failed_attempts) or 0,
                lockedUntil = tonumber(row.locked_until) or 0,
            },
            apps = {
                claimed = claimed_apps,
                uninstalled = uninstalled_apps,
                revision = tonumber(row.apps_revision) or 0,
            },
        }
    end
    return devices
end

local function list_players()
    local sources = Bridge.Framework.GetPlayers()
    table.sort(sources, function(left, right)
        return tonumber(left) < tonumber(right)
    end)

    local players, identifiers, owner_devices = {}, {}, {}
    local maximum = math.max(1, math.floor(tonumber(Config.AdminPanel.MaximumPlayers) or 128))
    for index = 1, math.min(#sources, maximum) do
        local player_source = tonumber(sources[index])
        local identifier = player_source and Bridge.Framework.GetIdentifier(player_source)
        if identifier then
            local job = Bridge.Framework.GetJob(player_source)
            players[#players + 1] = {
                source = player_source,
                identifier = identifier,
                name = player_name(player_source),
                serverName = GetPlayerName(player_source) or "",
                job = job.label ~= "" and job.label or job.name,
                grade = job.grade,
                onDuty = job.onDuty,
                deviceCount = 0,
            }
            if not owner_devices[identifier] then
                identifiers[#identifiers + 1] = identifier
                owner_devices[identifier] = {}
            end
            for _, item in ipairs(Bridge.Inventory.GetSlotsWithItem(player_source, Config.Phone.Item)) do
                local imei = item.metadata and item.metadata.imei
                if SkyPhoneImei.IsValid(imei) then owner_devices[identifier][imei] = true end
            end
        end
    end
    if #identifiers == 0 then return players end

    -- The sidebar needs counts and the latest number, not every device's app JSON,
    -- account and security data. Resolve ownership once for the whole player list.
    local placeholders, parameters = {}, {}
    for index, identifier in ipairs(identifiers) do
        placeholders[index] = "?"
        parameters[#parameters + 1] = identifier
    end
    for _, identifier in ipairs(identifiers) do parameters[#parameters + 1] = identifier end
    local owners = Bridge.Database.Query(([[
        SELECT `owner_identifier`, `device_imei` AS `imei`
        FROM `sky_phone_character_devices` WHERE `owner_identifier` IN (%s)
        UNION
        SELECT sim.`owner_identifier`, device.`imei`
        FROM `sky_phone_devices` device
        JOIN `sky_phone_sims` sim ON sim.`id` = device.`sim_id`
        WHERE sim.`owner_identifier` IN (%s)
    ]]):format(table.concat(placeholders, ", "), table.concat(placeholders, ", ")), parameters)
    for _, row in ipairs(owners) do
        if owner_devices[row.owner_identifier] and SkyPhoneImei.IsValid(row.imei) then
            owner_devices[row.owner_identifier][row.imei] = true
        end
    end
    local imeis, seen = {}, {}
    for _, devices in pairs(owner_devices) do
        for imei in pairs(devices) do
            if not seen[imei] then
                seen[imei] = true
                imeis[#imeis + 1] = imei
            end
        end
    end
    if #imeis == 0 then return players end
    placeholders = {}
    for index = 1, #imeis do placeholders[index] = "?" end
    local rows = Bridge.Database.Query(([[
        SELECT device.`imei`, sim.`phone_number`
        FROM `sky_phone_devices` device
        LEFT JOIN `sky_phone_sims` sim ON sim.`id` = device.`sim_id`
        WHERE device.`imei` IN (%s)
        ORDER BY device.`updated_at` DESC, device.`imei` ASC
    ]]):format(table.concat(placeholders, ", ")), imeis)
    local devices_by_imei = {}
    for rank, row in ipairs(rows) do devices_by_imei[row.imei] = { rank = rank, number = row.phone_number } end
    for _, player in ipairs(players) do
        local latest
        for imei in pairs(owner_devices[player.identifier]) do
            local device = devices_by_imei[imei]
            if device then
                player.deviceCount = player.deviceCount + 1
                if not latest or device.rank < latest.rank then latest = device end
            end
        end
        player.phoneNumber = latest and latest.number or nil
    end
    return players
end

local function load_player_detail(source)
    local identifier = Bridge.Framework.GetIdentifier(source)
    local job = Bridge.Framework.GetJob(source)
    return {
        source = source,
        identifier = identifier,
        name = player_name(source),
        serverName = GetPlayerName(source) or "",
        firstName = trim(Bridge.Framework.GetFirstname(source)),
        lastName = trim(Bridge.Framework.GetLastname(source)),
        birthdate = trim(Bridge.Framework.GetBirthdate(source)),
        job = {
            name = job.name,
            label = job.label,
            grade = job.grade,
            gradeLabel = job.gradeLabel,
            onDuty = job.onDuty,
        },
        money = {
            bank = tonumber(Bridge.Framework.GetMoney(source, "bank")) or 0,
            cash = tonumber(Bridge.Framework.GetMoney(source, "cash")) or 0,
            currency = Config.Banking.Currency,
        },
        devices = load_player_devices(source, identifier),
    }
end

local function find_owned_device(source, imei)
    local identifier = Bridge.Framework.GetIdentifier(source)
    for _, device in ipairs(load_player_devices(source, identifier)) do
        if device.imei == imei then
            return device, identifier
        end
    end
    return nil, identifier
end

local function load_device_sim(imei)
    local rows = Bridge.Database.Query([[
        SELECT sim.`id`, sim.`phone_number`
        FROM `sky_phone_devices` device
        JOIN `sky_phone_sims` sim ON sim.`id` = device.`sim_id`
        WHERE device.`imei` = ?
        LIMIT 1
    ]], { imei })
    return rows[1]
end

local function app_metadata(app_id)
    if BUILTIN_APPS[app_id] then
        if not SkyPhone.IsAppEnabled(app_id) then
            return nil
        end
        return {
            defaultInstalled = DEFAULT_INSTALLED_APPS[app_id] == true,
            removable = PROTECTED_APPS[app_id] ~= true,
        }
    end
    if SkyPhoneApps.GetPolicy(app_id) then
        return { defaultInstalled = false, removable = true }
    end
    return nil
end

local function remove_app_id(values, app_id)
    local next_values = {}
    for index = 1, #values do
        if values[index] ~= app_id then
            next_values[#next_values + 1] = values[index]
        end
    end
    return next_values
end

local function add_app_id(values, app_id)
    for index = 1, #values do
        if values[index] == app_id then
            return values
        end
    end
    values[#values + 1] = app_id
    return values
end

local function write_audit(actor_source, target_source, target_identifier, imei, action, details)
    local actor_identifier = Bridge.Framework.GetIdentifier(actor_source)
    local result = Bridge.Database.Query([[
        INSERT INTO `sky_phone_admin_audit`
            (`actor_identifier`, `actor_name`, `target_identifier`, `target_source`, `device_imei`, `action`, `details`)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        actor_identifier,
        player_name(actor_source),
        target_identifier,
        target_source,
        imei,
        action,
        json.encode(details or {}),
    })
    if affected_rows(result) ~= 1 then
        error("[sky_phone] Admin audit insert did not affect exactly one row.")
    end
end


-- Table/column names come only from this server-owned allowlist.
local SOCIAL_CONTENT = {
    feather = {
        posts = "sky_phone_feather_posts", profiles = "sky_phone_feather_profiles", body = "body",
        media = "sky_phone_feather_post_media", mediaKey = "post_id", mediaOrder = "sort_order",
    },
    fliptok = {
        posts = "sky_phone_fliptok_videos", profiles = "sky_phone_fliptok_profiles", body = "caption",
        sessions = "sky_phone_fliptok_sessions", media = "sky_phone_fliptok_video_media",
        mediaKey = "video_id", mediaOrder = "sort_order",
    },
    picstagram = {
        posts = "sky_phone_picstagram_posts", profiles = "sky_phone_picstagram_profiles", body = "caption",
        sessions = "sky_phone_picstagram_sessions", media = "sky_phone_picstagram_post_media",
        mediaKey = "post_id", mediaOrder = "position",
    },
    skypic = {
        posts = "sky_phone_skypic_spotlights", profiles = "sky_phone_skypic_profiles",
        bodySql = "CONCAT_WS(CHAR(10), NULLIF(post.`caption`, ''), NULLIF(post.`overlay_text`, ''))",
        directMedia = "media_id", publishedStatus = "active", expires = true, headline = "ad_headline",
    },
    ["skypic-stories"] = {
        app = "skypic",
        posts = "sky_phone_skypic_stories", profiles = "sky_phone_skypic_profiles",
        bodySql = "CONCAT_WS(CHAR(10), NULLIF(post.`caption`, ''), NULLIF(post.`overlay_text`, ''))",
        directMedia = "media_id", publishedStatus = "active", expires = true, publicCondition = " AND post.`privacy` = 'everyone'",
    },
    ["weazel-news"] = {
        posts = "sky_phone_weazel_articles", media = "sky_phone_weazel_article_media",
        mediaKey = "article_id", mediaOrder = "position",
    },
}

local function sql_placeholders(values)
    local placeholders = {}
    for index = 1, #values do placeholders[index] = "?" end
    return table.concat(placeholders, ", ")
end

local function resolve_social_scope(data, platform)
    if data.targetSource == nil then return {} end
    local target_source = normalize_source(data.targetSource)
    if not target_source then return nil, { success = false, error = "player_unavailable" } end
    local identifier = Bridge.Framework.GetIdentifier(target_source)
    local scope = { source = target_source, identifier = identifier, accounts = {}, profileIds = {} }
    if not platform.profiles then return scope end

    local imeis = collect_device_imeis(target_source, identifier)
    if #imeis == 0 then return scope end
    local parameters = {}
    for _, imei in ipairs(imeis) do parameters[#parameters + 1] = imei end
    local profile_columns = [[profile.`id`, profile.`account_id` AS `accountId`, profile.`handle`,
        profile.`display_name` AS `displayName`]]
    local queries = { ([[
        SELECT DISTINCT %s FROM `sky_phone_devices` device
        JOIN `%s` profile ON profile.`account_id` = device.`account_id`
        WHERE device.`imei` IN (%s)
    ]]):format(profile_columns, platform.profiles, sql_placeholders(imeis)) }
    if platform.sessions then
        queries[#queries + 1] = ([[
            SELECT %s FROM `%s` session
            JOIN `%s` profile ON profile.`id` = session.`profile_id`
            WHERE session.`device_imei` IN (%s)
        ]]):format(profile_columns, platform.sessions, platform.profiles, sql_placeholders(imeis))
        for _, imei in ipairs(imeis) do parameters[#parameters + 1] = imei end
    end
    -- Begin with the target's indexed device/session keys instead of scanning
    -- every platform profile. UNION deduplicates accounts linked in both ways.
    local profiles = Bridge.Database.Query(table.concat(queries, " UNION ") .. " ORDER BY `handle` ASC", parameters)
    for _, profile in ipairs(profiles) do
        scope.accounts[#scope.accounts + 1] = {
            id = tostring(profile.id), accountId = tonumber(profile.accountId),
            handle = profile.handle, displayName = profile.displayName,
        }
        scope.profileIds[#scope.profileIds + 1] = profile.id
    end
    return scope
end

local function social_target_condition(scope, platform, parameters)
    if not scope.source then return "" end
    if not platform.profiles then
        parameters[#parameters + 1] = scope.identifier
        return " AND post.`author_identifier` = ?"
    end
    if #scope.profileIds == 0 then return " AND 1 = 0" end
    for _, profile_id in ipairs(scope.profileIds) do parameters[#parameters + 1] = profile_id end
    return (" AND post.`profile_id` IN (%s)"):format(sql_placeholders(scope.profileIds))
end

local function public_social_condition(platform)
    local condition = (" AND post.`status` = '%s'"):format(platform.publishedStatus or "published")
    if platform.expires then condition = condition .. " AND post.`expires_at` > CURRENT_TIMESTAMP(6)" end
    return condition .. (platform.publicCondition or "")
end

local function hydrate_admin_social_media(rows, platform, platform_id)
    local ids, posts = {}, {}
    for _, row in ipairs(rows) do
        row.profileId = row.profileId and tostring(row.profileId) or nil
        row.media = {}
        ids[#ids + 1] = row.id
        posts[row.id] = row
    end
    if #ids == 0 then return end
    if platform.directMedia then
        local media_rows = Bridge.Database.Query(([[
            SELECT post.`id` AS `postId`, media.`url`, media.`media_type` AS `type`
            FROM `%s` post JOIN `sky_phone_media` media ON media.`id` = post.`%s`
            WHERE post.`id` IN (%s)
        ]]):format(platform.posts, platform.directMedia, sql_placeholders(ids)), ids)
        for _, media in ipairs(media_rows) do
            local post = posts[media.postId]
            if post then post.media[1] = { url = media.url, type = media.type } end
        end
        return
    end
    local media_rows = Bridge.Database.Query(([[
        SELECT relation.`%s` AS `postId`, media.`url`, media.`media_type` AS `type`
        FROM `%s` relation JOIN `sky_phone_media` media ON media.`id` = relation.`media_id`
        WHERE relation.`%s` IN (%s)
        ORDER BY relation.`%s`, relation.`%s`
    ]]):format(platform.mediaKey, platform.media, platform.mediaKey, sql_placeholders(ids),
        platform.mediaKey, platform.mediaOrder), ids)
    for _, media in ipairs(media_rows) do
        local post = posts[media.postId]
        if post then post.media[#post.media + 1] = { url = media.url, type = media.type } end
    end
    -- Earlier FlipTok videos and Weazel articles can predate their attachment tables.
    if platform_id == "fliptok" or platform_id == "weazel-news" then
        local media_column = platform_id == "fliptok" and "media_id" or "image_media_id"
        local fallback_rows = Bridge.Database.Query(([[
            SELECT post.`id` AS `postId`, media.`url`, media.`media_type` AS `type`
            FROM `%s` post JOIN `sky_phone_media` media ON media.`id` = post.`%s`
            WHERE post.`id` IN (%s)
        ]]):format(platform.posts, media_column, sql_placeholders(ids)), ids)
        for _, media in ipairs(fallback_rows) do
            local post = posts[media.postId]
            if post and #post.media == 0 then post.media[1] = { url = media.url, type = media.type } end
        end
    end
end

Bridge.Callbacks.Register("sky_phone:admin:social-posts", function(source, data)
    local allowed, error_response = require_admin(source, "social_read", Config.AdminPanel.ReadRequestsPerMinute)
    if not allowed then return error_response end
    local platform = type(data) == "table" and SOCIAL_CONTENT[data.platform] or nil
    local page = type(data) == "table" and data.page or nil
    local query = type(data) == "table" and data.query or nil
    if not platform or type(page) ~= "number" or page % 1 ~= 0 or page < 0 or page > 2000
        or type(query) ~= "string" or #query > 100 then
        return { success = false, error = "invalid_request" }
    end
    if SkyPhoneAppDatabase and not SkyPhoneAppDatabase.Enabled(platform.app or data.platform) then
        return { success = false, error = "app_disabled" }
    end
    local scope, scope_error = resolve_social_scope(data, platform)
    if not scope then return scope_error end
    local search = "%" .. trim(query) .. "%"
    local parameters = { search, search, search }
    local target_condition = social_target_condition(scope, platform, parameters)
    parameters[#parameters + 1] = page * 50
    local rows
    if data.platform == "weazel-news" then
        rows = Bridge.Database.Query(([[
            SELECT post.`id`, post.`title`, post.`%s` AS `body`, post.`status`,
                post.`author_name` AS `author`, post.`created_at` AS `createdAt`,
                post.`deleted_at` AS `deletedAt`
            FROM `sky_phone_weazel_articles` post
            WHERE (post.`title` LIKE ? OR post.`author_name` LIKE ? OR post.`id` LIKE ?)%s%s
            ORDER BY post.`created_at` DESC, post.`id` DESC LIMIT 51 OFFSET ?
        ]]):format(scope.source and "body" or "excerpt", target_condition,
            scope.source and "" or " AND post.`deleted_at` IS NULL AND post.`status` = 'published'"), parameters)
    else
        local status_columns = platform.expires and [[
            CASE WHEN post.`status` = 'active' AND post.`expires_at` <= CURRENT_TIMESTAMP(6)
                THEN 'expired' ELSE post.`status` END AS `status`,
            UNIX_TIMESTAMP(post.`expires_at`) * 1000 AS `expiresAt`
        ]] or "post.`status`"
        local title_column = platform.headline and (", post.`%s` AS `title`"):format(platform.headline) or ""
        rows = Bridge.Database.Query(([[
            SELECT post.`id`, %s AS `body`, profile.`handle` AS `author`,
                profile.`id` AS `profileId`, profile.`display_name` AS `displayName`,
                %s, post.`created_at` AS `createdAt`%s
            FROM `%s` post JOIN `%s` profile ON profile.`id` = post.`profile_id`
            WHERE (%s LIKE ? OR profile.`handle` LIKE ? OR post.`id` LIKE ?)%s%s
            ORDER BY post.`created_at` DESC, post.`id` DESC LIMIT 51 OFFSET ?
        ]]):format(platform.bodySql or ("post.`%s`"):format(platform.body), status_columns, title_column,
            platform.posts, platform.profiles, platform.bodySql or ("post.`%s`"):format(platform.body), target_condition,
            scope.source and "" or public_social_condition(platform)), parameters)
    end
    local has_more = #rows > 50
    if has_more then rows[51] = nil end
    for _, row in ipairs(rows) do
        if row.deletedAt then row.status = "removed" end
        row.deletedAt = nil
        row.expiresAt = row.expiresAt and tonumber(row.expiresAt) or nil
    end
    hydrate_admin_social_media(rows, platform, data.platform)
    if scope.source then
        write_audit(source, scope.source, scope.identifier, nil, "view_social_posts", {
            platform = data.platform, page = page,
        })
    end
    return { success = true, data = { items = rows, hasMore = has_more, accounts = scope.accounts or {} } }
end)

Bridge.Callbacks.Register("sky_phone:admin:delete-social-post", function(source, data)
    local allowed, error_response = require_admin(source, "social_delete", Config.AdminPanel.ActionRequestsPerMinute)
    if not allowed then return error_response end
    local platform = type(data) == "table" and SOCIAL_CONTENT[data.platform] or nil
    local id = type(data) == "table" and data.id or nil
    if not platform or type(id) ~= "string" or #id ~= 36
        or not id:match("^%x+%-%x+%-%x+%-%x+%-%x+$") then
        return { success = false, error = "invalid_request" }
    end
    if SkyPhoneAppDatabase and not SkyPhoneAppDatabase.Enabled(platform.app or data.platform) then
        return { success = false, error = "app_disabled" }
    end
    local scope, scope_error = resolve_social_scope(data, platform)
    if not scope then return scope_error end
    local parameters = data.platform == "weazel-news"
        and { Bridge.Framework.GetIdentifier(source), id } or { id }
    local target_condition = social_target_condition(scope, platform, parameters)
    local result
    if data.platform == "weazel-news" then
        result = Bridge.Database.Query(([[
            UPDATE `sky_phone_weazel_articles` post
            SET `deleted_at` = CURRENT_TIMESTAMP, `deleted_by_identifier` = ?, `revision` = `revision` + 1
            WHERE post.`id` = ? AND post.`deleted_at` IS NULL%s%s
        ]]):format(target_condition, scope.source and "" or " AND post.`status` = 'published'"), parameters)
    else
        result = Bridge.Database.Query(
            ("UPDATE `%s` post SET `status` = 'removed' WHERE post.`id` = ?%s%s")
                :format(platform.posts, target_condition,
                    scope.source and " AND post.`status` <> 'removed'" or public_social_condition(platform)),
            parameters
        )
    end
    if affected_rows(result) ~= 1 then return { success = false, error = "not_found" } end
    write_audit(source, scope.source, scope.identifier or "", nil, "delete_social_post", {
        platform = data.platform, postId = id,
    })
    return { success = true }
end)

local function load_audit()
    local limit = math.max(1, math.min(100, math.floor(tonumber(Config.AdminPanel.AuditLimit) or 40)))
    local rows = Bridge.Database.Query(([[
        SELECT `id`, `actor_name`, `target_identifier`, `target_source`, `device_imei`,
            `action`, `details`, `created_at`
        FROM `sky_phone_admin_audit`
        ORDER BY `id` DESC
        LIMIT %s
    ]]):format(limit), {})
    local audit = {}
    for _, row in ipairs(rows) do
        audit[#audit + 1] = {
            id = tonumber(row.id),
            actorName = row.actor_name,
            targetIdentifier = row.target_identifier,
            targetSource = row.target_source and tonumber(row.target_source) or nil,
            deviceImei = row.device_imei,
            action = row.action,
            details = json.decode(row.details),
            createdAt = row.created_at,
        }
    end
    return audit
end

local function load_statistics(online)
    local totals = Bridge.Database.Query([[
        SELECT COUNT(*) AS `devices`,
            COALESCE(SUM(device.`account_id` IS NOT NULL), 0) AS `linked_devices`,
            COALESCE(SUM(device.`sim_id` IS NOT NULL), 0) AS `sim_devices`,
            COALESCE(SUM(device.`updated_at` >= DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 24 HOUR)), 0) AS `active_devices`,
            (SELECT COUNT(*) FROM `sky_phone_accounts`) AS `accounts`,
            (SELECT COUNT(*) FROM `sky_phone_sms_messages`
                WHERE `created_at` >= CURRENT_DATE) AS `messages_today`,
            (SELECT COUNT(*) FROM `sky_phone_calls`
                WHERE `started_at` >= CURRENT_DATE) AS `calls_today`,
            (SELECT COUNT(*) FROM `sky_phone_admin_audit`) AS `audit_entries`,
            (SELECT COUNT(*) FROM `sky_phone_admin_audit`
                WHERE `created_at` >= CURRENT_DATE) AS `audit_today`
        FROM `sky_phone_devices` device
    ]], {})
    local stats = totals[1] or {}
    return {
        online = online,
        devices = tonumber(stats.devices) or 0,
        accounts = tonumber(stats.accounts) or 0,
        linkedDevices = tonumber(stats.linked_devices) or 0,
        simDevices = tonumber(stats.sim_devices) or 0,
        activeDevices = tonumber(stats.active_devices) or 0,
        messagesToday = tonumber(stats.messages_today) or 0,
        callsToday = tonumber(stats.calls_today) or 0,
        auditEntries = tonumber(stats.audit_entries) or 0,
        auditToday = tonumber(stats.audit_today) or 0,
    }
end

Bridge.Callbacks.Register("sky_phone:admin:statistics", function(source)
    local authorized, error_response = require_admin(source, "bootstrap", Config.AdminPanel.ReadRequestsPerMinute)
    if not authorized then return error_response end
    local online = 0
    local sources = Bridge.Framework.GetPlayers()
    table.sort(sources, function(left, right) return tonumber(left) < tonumber(right) end)
    local maximum = math.max(1, math.floor(tonumber(Config.AdminPanel.MaximumPlayers) or 128))
    for index = 1, math.min(#sources, maximum) do
        if Bridge.Framework.GetIdentifier(tonumber(sources[index])) then online = online + 1 end
    end
    return { success = true, data = load_statistics(online) }
end)

Bridge.Callbacks.Register("sky_phone:admin:bootstrap", function(source)
    local authorized, error_response = require_admin(
        source,
        "bootstrap",
        Config.AdminPanel.ReadRequestsPerMinute
    )
    if not authorized then
        return error_response
    end

    local players = list_players()
    return {
        success = true,
        data = {
            players = players,
            disabledApps = SkyPhone.GetDisabledApps(),
            stats = load_statistics(#players),
            audit = load_audit(),
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:admin:player", function(source, data)
    local authorized, error_response = require_admin(
        source,
        "player",
        Config.AdminPanel.ReadRequestsPerMinute
    )
    if not authorized then
        return error_response
    end
    local target_source = normalize_source(data and data.source)
    if not target_source then
        return { success = false, error = "player_unavailable" }
    end
    return { success = true, data = load_player_detail(target_source) }
end)

Bridge.Callbacks.Register("sky_phone:admin:save-apps", function(source, data)
    local authorized, error_response = require_admin(
        source,
        "save_apps",
        Config.AdminPanel.ActionRequestsPerMinute
    )
    if not authorized then
        return error_response
    end
    if type(data) ~= "table"
        or not SkyPhoneImei.IsValid(data.imei)
        or type(data.revision) ~= "number"
        or data.revision < 0
        or data.revision ~= math.floor(data.revision)
        or type(data.changes) ~= "table"
        or #data.changes < 1
        or #data.changes > 128
    then
        return { success = false, error = "invalid_request" }
    end

    local target_source = normalize_source(data.source)
    if not target_source then
        return { success = false, error = "player_unavailable" }
    end
    local target_device, target_identifier = find_owned_device(target_source, data.imei)
    if not target_device then
        return { success = false, error = "device_not_owned" }
    end
    local normalized_changes = {}
    local seen_apps = {}
    for index = 1, #data.changes do
        local change = data.changes[index]
        if type(change) ~= "table"
            or type(change.appId) ~= "string"
            or #change.appId < 1
            or #change.appId > 64
            or type(change.installed) ~= "boolean"
            or seen_apps[change.appId]
        then
            return { success = false, error = "invalid_request" }
        end
        local metadata = app_metadata(change.appId)
        if not metadata then
            return { success = false, error = "invalid_app" }
        end
        if not change.installed and not metadata.removable then
            return { success = false, error = "app_protected" }
        end
        seen_apps[change.appId] = true
        normalized_changes[#normalized_changes + 1] = {
            appId = change.appId,
            installed = change.installed,
            metadata = metadata,
        }
    end

    local rows = Bridge.Database.Query([[
        SELECT `payload`, `revision`
        FROM `sky_phone_device_data`
        WHERE `device_imei` = ? AND `namespace` = 'apps'
        LIMIT 1
    ]], { data.imei })
    local current_revision = tonumber(rows[1] and rows[1].revision) or 0
    if current_revision ~= data.revision then
        return { success = false, error = "revision_conflict" }
    end

    local payload, claimed_apps, uninstalled_apps = load_app_payload(rows[1] and rows[1].payload)
    for index = 1, #normalized_changes do
        local change = normalized_changes[index]
        if change.installed then
            uninstalled_apps = remove_app_id(uninstalled_apps, change.appId)
            if not change.metadata.defaultInstalled then
                claimed_apps = add_app_id(claimed_apps, change.appId)
            end
        else
            claimed_apps = remove_app_id(claimed_apps, change.appId)
            uninstalled_apps = add_app_id(uninstalled_apps, change.appId)
        end
    end
    payload.claimedApps = claimed_apps
    payload.uninstalledApps = #uninstalled_apps > 0 and uninstalled_apps or nil

    local encoded = json.encode(payload)
    if #encoded > 100000 then
        return { success = false, error = "payload_too_large" }
    end

    if rows[1] then
        local result = Bridge.Database.Query([[
            UPDATE `sky_phone_device_data`
            SET `payload` = ?, `revision` = `revision` + 1
            WHERE `device_imei` = ? AND `namespace` = 'apps' AND `revision` = ?
        ]], { encoded, data.imei, data.revision })
        if affected_rows(result) ~= 1 then
            return { success = false, error = "revision_conflict" }
        end
    else
        local result = Bridge.Database.Query([[
            INSERT IGNORE INTO `sky_phone_device_data` (`device_imei`, `namespace`, `payload`)
            VALUES (?, 'apps', ?)
        ]], { data.imei, encoded })
        if affected_rows(result) ~= 1 then
            return { success = false, error = "revision_conflict" }
        end
    end

    for index = 1, #normalized_changes do
        local change = normalized_changes[index]
        write_audit(
            source,
            target_source,
            target_identifier,
            data.imei,
            change.installed and "grant_app" or "revoke_app",
            { appId = change.appId }
        )
    end
    SkyPhone.RefreshDevice(data.imei)
    return { success = true, data = load_player_detail(target_source) }
end)

Bridge.Callbacks.Register("sky_phone:admin:reveal-password", function(source, data)
    local authorized, error_response = require_admin(
        source,
        "reveal_password",
        Config.AdminPanel.CredentialRevealsPerMinute
    )
    if not authorized then
        return error_response
    end
    if type(data) ~= "table" or not SkyPhoneImei.IsValid(data.imei) then
        return { success = false, error = "invalid_request" }
    end

    local target_source = normalize_source(data.source)
    if not target_source then
        return { success = false, error = "player_unavailable" }
    end
    local device, target_identifier = find_owned_device(target_source, data.imei)
    if not device then
        return { success = false, error = "device_not_owned" }
    end

    local accounts = Bridge.Database.Query([[
        SELECT account.`email`, account.`password`
        FROM `sky_phone_devices` device
        JOIN `sky_phone_accounts` account ON account.`id` = device.`account_id`
        WHERE device.`imei` = ?
        LIMIT 1
    ]], { data.imei })
    if not accounts[1] then
        return { success = false, error = "account_not_found" }
    end

    write_audit(
        source,
        target_source,
        target_identifier,
        data.imei,
        "reveal_account_password",
        { email = accounts[1].email }
    )
    return {
        success = true,
        data = {
            email = accounts[1].email,
            password = accounts[1].password,
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:admin:activity", function(source, data)
    local authorized, error_response = require_admin(
        source,
        "activity",
        Config.AdminPanel.ReadRequestsPerMinute
    )
    if not authorized then
        return error_response
    end
    if type(data) ~= "table"
        or not SkyPhoneImei.IsValid(data.imei)
        or (data.kind ~= "messages" and data.kind ~= "calls")
    then
        return { success = false, error = "invalid_request" }
    end

    local target_source = normalize_source(data.source)
    if not target_source then
        return { success = false, error = "player_unavailable" }
    end
    local device, target_identifier = find_owned_device(target_source, data.imei)
    if not device then
        return { success = false, error = "device_not_owned" }
    end
    local audit_action = data.kind == "messages" and "view_messages" or "view_calls"
    local sim = load_device_sim(data.imei)
    if not sim then
        write_audit(
            source,
            target_source,
            target_identifier,
            data.imei,
            audit_action,
            { count = 0 }
        )
        return { success = true, data = { kind = data.kind, entries = {} } }
    end

    local limit = math.max(1, math.min(100, math.floor(tonumber(Config.AdminPanel.ActivityLimit) or 40)))
    local entries = {}
    if data.kind == "messages" then
        local rows = Bridge.Database.Query(([[
            SELECT `id`, `sender_sim_id`, `sender_number`, `recipient_number`, `message_type`,
                `body`, `read_at`, `created_at`
            FROM `sky_phone_sms_messages`
            WHERE `sender_sim_id` = ? OR `recipient_sim_id` = ?
            ORDER BY `created_at` DESC
            LIMIT %s
        ]]):format(limit), { sim.id, sim.id })
        for _, row in ipairs(rows) do
            local outgoing = row.sender_sim_id == sim.id
            entries[#entries + 1] = {
                id = row.id,
                direction = outgoing and "outgoing" or "incoming",
                otherNumber = outgoing and row.recipient_number or row.sender_number,
                messageType = row.message_type,
                body = row.body,
                readAt = row.read_at,
                createdAt = row.created_at,
            }
        end
    else
        local rows = Bridge.Database.Query(([[
            SELECT `id`, `caller_sim_id`, `caller_number`, `callee_number`, `status`,
                `started_at`, `answered_at`, `ended_at`, `duration_seconds`
            FROM `sky_phone_calls`
            WHERE `caller_sim_id` = ? OR `callee_sim_id` = ?
            ORDER BY `started_at` DESC
            LIMIT %s
        ]]):format(limit), { sim.id, sim.id })
        for _, row in ipairs(rows) do
            local outgoing = row.caller_sim_id == sim.id
            entries[#entries + 1] = {
                id = row.id,
                direction = outgoing and "outgoing" or "incoming",
                otherNumber = outgoing and row.callee_number or row.caller_number,
                status = row.status,
                startedAt = row.started_at,
                answeredAt = row.answered_at,
                endedAt = row.ended_at,
                durationSeconds = tonumber(row.duration_seconds) or 0,
            }
        end
    end

    write_audit(
        source,
        target_source,
        target_identifier,
        data.imei,
        audit_action,
        { count = #entries }
    )
    return { success = true, data = { kind = data.kind, entries = entries } }
end)

Bridge.Callbacks.Register("sky_phone:admin:reset-passcode", function(source, data)
    local authorized, error_response = require_admin(
        source,
        "reset_passcode",
        Config.AdminPanel.ActionRequestsPerMinute
    )
    if not authorized then
        return error_response
    end
    if type(data) ~= "table" or not SkyPhoneImei.IsValid(data.imei) then
        return { success = false, error = "invalid_request" }
    end

    local target_source = normalize_source(data.source)
    if not target_source then
        return { success = false, error = "player_unavailable" }
    end
    local device, target_identifier = find_owned_device(target_source, data.imei)
    if not device then
        return { success = false, error = "device_not_owned" }
    end
    local result = Bridge.Database.Query(
        "DELETE FROM `sky_phone_device_security` WHERE `device_imei` = ?",
        { data.imei }
    )
    if affected_rows(result) ~= 1 then
        return { success = false, error = "passcode_not_set" }
    end

    write_audit(source, target_source, target_identifier, data.imei, "reset_passcode", {})
    SkyPhone.RefreshDevice(data.imei)
    return { success = true, data = load_player_detail(target_source) }
end)

Bridge.Callbacks.Register("sky_phone:admin:change-number", function(source, data)
    local authorized, error_response = require_admin(
        source,
        "change_number",
        Config.AdminPanel.ActionRequestsPerMinute
    )
    if not authorized then
        return error_response
    end
    if type(data) ~= "table"
        or not SkyPhoneImei.IsValid(data.imei)
        or (type(data.phoneNumber) ~= "string" and type(data.phoneNumber) ~= "number")
    then
        return { success = false, error = "invalid_request" }
    end

    local target_source = normalize_source(data.source)
    if not target_source then
        return { success = false, error = "player_unavailable" }
    end
    local device, target_identifier = find_owned_device(target_source, data.imei)
    if not device then
        return { success = false, error = "device_not_owned" }
    end
    local sim = load_device_sim(data.imei)
    if not sim then
        return { success = false, error = "no_sim" }
    end

    local changed, number_or_error = SkyPhoneSim.ChangeNumber(
        target_source,
        data.imei,
        sim.id,
        data.phoneNumber
    )
    if not changed then
        return { success = false, error = number_or_error }
    end

    SkyPhoneCompanies.ClearCallAvailability(target_source)
    SkyPhoneCalls.EndForSim(sim.id, "number_changed")
    write_audit(source, target_source, target_identifier, data.imei, "change_number", {
        previousNumber = sim.phone_number,
        phoneNumber = number_or_error,
    })
    SkyPhone.RefreshDevice(data.imei)
    return { success = true, data = load_player_detail(target_source) }
end)

Bridge.Callbacks.Register("sky_phone:admin:factory-reset", function(source, data)
    local authorized, error_response = require_admin(
        source,
        "factory_reset",
        Config.AdminPanel.ActionRequestsPerMinute
    )
    if not authorized then
        return error_response
    end
    if type(data) ~= "table" or not SkyPhoneImei.IsValid(data.imei) then
        return { success = false, error = "invalid_request" }
    end

    local target_source = normalize_source(data.source)
    if not target_source then
        return { success = false, error = "player_unavailable" }
    end
    local device, target_identifier = find_owned_device(target_source, data.imei)
    if not device then
        return { success = false, error = "device_not_owned" }
    end

    local reset, phone_number_or_error = SkyPhonePersistence.FactoryReset(data.imei)
    if not reset then
        return { success = false, error = phone_number_or_error }
    end

    write_audit(source, target_source, target_identifier, data.imei, "factory_reset", {})
    if phone_number_or_error then
        TriggerEvent("sky_phone:server:factoryReset", target_source, phone_number_or_error)
    end
    SkyPhone.RefreshDevice(data.imei)
    return { success = true, data = load_player_detail(target_source) }
end)

Bridge.Callbacks.Register("sky_phone:admin:configurator", function(source)
    local authorized, error_response = require_admin(
        source,
        "configurator_read",
        Config.AdminPanel.ReadRequestsPerMinute
    )
    if not authorized then
        return error_response
    end

    return { success = true, data = SkyPhoneConfigurator.GetAdminData() }
end)

Bridge.Callbacks.Register("sky_phone:admin:save-configurator", function(source, data)
    local authorized, error_response = require_admin(
        source,
        "configurator_save",
        Config.AdminPanel.ActionRequestsPerMinute
    )
    if not authorized then
        return error_response
    end
    if type(data) ~= "table" or type(data.changes) ~= "table" then
        return { success = false, error = "invalid_request" }
    end

    local actor_identifier = Bridge.Framework.GetIdentifier(source)
    if not actor_identifier then
        return { success = false, error = "player_unavailable" }
    end
    local actor_name = player_name(source)
    local response = SkyPhoneConfigurator.Save(
        data.revision,
        data.changes,
        actor_identifier,
        actor_name
    )
    if response.success then
        write_audit(source, source, actor_identifier, nil, "save_configuration", {
            changeCount = #data.changes,
            revision = response.data.revision,
        })
    end
    return response
end)

Bridge.Callbacks.Register("sky_phone:admin:webhooks", function(source)
    local authorized, error_response = require_admin(source, "webhooks_read", Config.AdminPanel.ReadRequestsPerMinute)
    if not authorized then return error_response end
    local data = SkyPhoneWebhookSettings.GetAdminData()
    if not data then return { success = false, error = "request_failed" } end
    return { success = true, data = data }
end)

Bridge.Callbacks.Register("sky_phone:admin:save-webhooks", function(source, data)
    local authorized, error_response = require_admin(source, "webhooks_save", Config.AdminPanel.ActionRequestsPerMinute)
    if not authorized then return error_response end
    if type(data) ~= "table" then return { success = false, error = "invalid_request" } end
    local actor_identifier = Bridge.Framework.GetIdentifier(source)
    if not actor_identifier then return { success = false, error = "player_unavailable" } end
    local response, changed_paths = SkyPhoneWebhookSettings.Save(data.revision, data.changes)
    if response.success then
        write_audit(source, source, actor_identifier, nil, "save_webhooks", {
            changedPaths = changed_paths,
            changeCount = #changed_paths,
            revision = response.data.revision,
        })
        SkyPhoneLog.Record("Admin", "admin:save-webhooks", "edited", source, {
            changedPaths = changed_paths, revision = response.data.revision,
        })
    end
    return response
end)

Bridge.Callbacks.Register("sky_phone:admin:tones", function(source)
    local authorized, error_response = require_admin(
        source,
        "tones_read",
        Config.AdminPanel.ReadRequestsPerMinute
    )
    if not authorized then
        return error_response
    end
    return { success = true, data = SkyPhoneTones.GetAdminList() }
end)

Bridge.Callbacks.Register("sky_phone:admin:tone-upload-start", function(source, data)
    local authorized, error_response = require_admin(
        source,
        "tone_upload_start",
        Config.AdminPanel.ActionRequestsPerMinute
    )
    if not authorized then
        return error_response
    end

    local actor_identifier = Bridge.Framework.GetIdentifier(source)
    if not actor_identifier then
        return { success = false, error = "player_unavailable" }
    end
    local actor_name = player_name(source)
    return SkyPhoneTones.BeginUpload(source, data, actor_identifier, actor_name)
end)

Bridge.Callbacks.Register("sky_phone:admin:tone-upload-chunk", function(source, data)
    local authorized, error_response = require_admin(
        source,
        "tone_upload_chunk",
        math.max(400, tonumber(Config.AdminPanel.ActionRequestsPerMinute) or 0)
    )
    if not authorized then
        return error_response
    end
    return SkyPhoneTones.AppendUploadChunk(source, data)
end)

Bridge.Callbacks.Register("sky_phone:admin:tone-upload-finish", function(source, data)
    local authorized, error_response = require_admin(
        source,
        "tone_upload_finish",
        Config.AdminPanel.ActionRequestsPerMinute
    )
    if not authorized then
        return error_response
    end

    local actor_identifier = Bridge.Framework.GetIdentifier(source)
    if not actor_identifier then
        return { success = false, error = "player_unavailable" }
    end
    local response = SkyPhoneTones.CompleteUpload(source, data)
    if response.success then
        local upload = response.upload or {}
        write_audit(source, source, actor_identifier, nil, "create_custom_tone", {
            durationMs = tonumber(upload.durationMs),
            label = trim(upload.label),
            toneId = response.toneId,
            toneType = upload.toneType,
        })
    end
    response.upload = nil
    return response
end)

Bridge.Callbacks.Register("sky_phone:admin:tone-upload-cancel", function(source, data)
    local authorized, error_response = require_admin(
        source,
        "tone_upload_cancel",
        Config.AdminPanel.ActionRequestsPerMinute
    )
    if not authorized then
        return error_response
    end
    return SkyPhoneTones.CancelUpload(source, data)
end)

Bridge.Callbacks.Register("sky_phone:admin:delete-tone", function(source, data)
    local authorized, error_response = require_admin(
        source,
        "tone_delete",
        Config.AdminPanel.ActionRequestsPerMinute
    )
    if not authorized then
        return error_response
    end
    if type(data) ~= "table" then
        return { success = false, error = "invalid_request" }
    end

    local actor_identifier = Bridge.Framework.GetIdentifier(source)
    if not actor_identifier then
        return { success = false, error = "player_unavailable" }
    end
    local response = SkyPhoneTones.Delete(data.id)
    if response.success then
        write_audit(source, source, actor_identifier, nil, "delete_custom_tone", {
            label = response.tone.label,
            toneId = response.tone.id,
            toneType = response.tone.tone_type,
        })
    end
    return response
end)

Bridge.Callbacks.Register("sky_phone:admin:phone-activity", function(source, data)
    local authorized, error_response = require_admin(source, "phone_activity", Config.AdminPanel.ReadRequestsPerMinute)
    if not authorized then return error_response end
    if not SkyPhoneLog.ActivityEnabled() then
        Bridge.Debug("error", "[sky_phone] Phone activity recorder is unavailable after database initialization.")
        return { success = false, error = "server_initializing" }
    end
    if type(data) ~= "table" then return { success = false, error = "invalid_request" } end

    local target_source, target_identifier
    if data.source ~= nil then
        target_source = normalize_source(data.source)
        if not target_source then return { success = false, error = "player_unavailable" } end
        target_identifier = Bridge.Framework.GetIdentifier(target_source)
    end
    if data.imei ~= nil and not SkyPhoneImei.IsValid(data.imei) then
        return { success = false, error = "invalid_request" }
    end
    if data.category ~= nil and (type(data.category) ~= "string"
        or not data.category:match("^[%w]+$") or #data.category > 32) then
        return { success = false, error = "invalid_request" }
    end
    if data.beforeId ~= nil and (type(data.beforeId) ~= "string"
        or not data.beforeId:match("^[1-9]%d*$") or #data.beforeId > 20
        or (#data.beforeId == 20 and data.beforeId > "18446744073709551615")) then
        return { success = false, error = "invalid_request" }
    end

    local filters, parameters = {}, {}
    for _, filter in ipairs({
        { "activity.`owner_identifier` = ?", target_identifier },
        { "activity.`device_imei` = ?", data.imei },
        { "activity.`category` = ?", data.category },
        { "activity.`id` < ?", data.beforeId },
    }) do
        if filter[2] ~= nil then
            filters[#filters + 1] = filter[1]
            parameters[#parameters + 1] = filter[2]
        end
    end
    local limit = math.max(1, math.min(100, math.floor(tonumber(Config.AdminPanel.ActivityLimit) or 40)))
    local where = #filters > 0 and ("WHERE " .. table.concat(filters, " AND ")) or ""
    local rows = Bridge.Database.Query(([[
        SELECT CAST(activity.`id` AS CHAR) AS `id`, activity.`actor_source`, activity.`actor_name`,
            activity.`device_imei`, activity.`phone_number`, activity.`category`, activity.`action`,
            activity.`status`, activity.`details`, activity.`created_at`
        FROM `sky_phone_activity_log` activity
        %s ORDER BY activity.`id` DESC LIMIT %s
    ]]):format(where, limit + 1), parameters)
    local items = {}
    for index = 1, math.min(#rows, limit) do
        local row = rows[index]
        local details = json.decode(row.details)
        if type(details) ~= "table" then error("[sky_phone] Stored phone activity details are not a JSON object.") end
        items[#items + 1] = {
            id = row.id,
            actorSource = tonumber(row.actor_source) or 0,
            actorName = row.actor_name,
            imei = row.device_imei,
            phoneNumber = row.phone_number,
            category = row.category,
            action = row.action,
            status = row.status,
            details = details,
            createdAt = row.created_at,
        }
    end
    local has_more = #rows > limit
    return { success = true, data = {
        items = items, hasMore = has_more,
        nextBeforeId = has_more and items[#items].id or nil,
    } }
end)
end)
