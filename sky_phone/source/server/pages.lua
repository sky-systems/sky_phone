Bridge.Database.AfterMigration("sky_phone", function()
local categories = {}
local districts = {}
local photo_gradients = {}
for _, value in ipairs(Config.LocalPages.Categories) do categories[value] = true end
for _, value in ipairs(Config.Marketplace.Districts) do districts[value] = true end
for _, value in ipairs(Config.Marketplace.PhotoGradients) do photo_gradients[value] = true end

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
        error("[sky_phone] Database did not generate a Local Pages id.")
    end
    return rows[1].id
end

local function load_images(post_id)
    return Bridge.Database.Query([[
        SELECT `media_id`, `gradient`, `sort_order`
        FROM `sky_phone_pages_images`
        WHERE `post_id` = ?
        ORDER BY `sort_order`
    ]], { post_id })
end

local function validate_images(source, imei, images)
    if type(images) ~= "table" or #images > Config.LocalPages.MaxImages then return nil end
    if #images == 0 then return {} end

    local owned_media = {
        ["sunset-drive"] = Config.Marketplace.PhotoGradients[1],
        ["ocean-air"] = Config.Marketplace.PhotoGradients[2],
        ["city-lights"] = Config.Marketplace.PhotoGradients[3],
        ["desert-road"] = Config.Marketplace.PhotoGradients[4],
    }
    local rows = Bridge.Database.Query([[
        SELECT `payload` FROM `sky_phone_device_data`
        WHERE `device_imei` = ? AND `namespace` = 'media'
        LIMIT 1
    ]], { imei })
    local media = rows[1] and json.decode(rows[1].payload) or nil
    for _, capture in ipairs(type(media) == "table" and media.captures or {}) do
        if type(capture) == "table" and type(capture.id) == "string" and photo_gradients[capture.gradient] then
            owned_media[capture.id] = capture.gradient
        end
    end

    local normalized = {}
    local seen = {}
    for index, image in ipairs(images) do
        local media_id = type(image) == "table" and image.id or nil
        local gradient = media_id and owned_media[media_id] or nil
        if type(media_id) ~= "string" or #media_id > 64 or not gradient or seen[media_id] then
            Bridge.Debug("warn", "[sky_phone] Rejected unowned Local Pages image from source %s.", tostring(source))
            return nil
        end
        seen[media_id] = true
        normalized[index] = { id = media_id, gradient = gradient }
    end
    return normalized
end

local function hydrate_posts(rows)
    for _, post in ipairs(rows) do
        post.images = load_images(post.id)
        post.like_count = tonumber(post.like_count) or 0
        post.is_liked = tonumber(post.is_liked) or 0
        post.is_saved = tonumber(post.is_saved) or 0
        post.is_owner = tonumber(post.is_owner) or 0
    end
    return rows
end

local function list_posts(account_id, where_clause, values, limit, offset)
    local parameters = { account_id or 0, account_id or 0, account_id or 0 }
    for _, value in ipairs(values) do parameters[#parameters + 1] = value end
    parameters[#parameters + 1] = limit
    parameters[#parameters + 1] = offset
    return hydrate_posts(Bridge.Database.Query(([[
        SELECT p.`id`, p.`title`, p.`body`, p.`category`, p.`district`, p.`source_type`,
            p.`citymarkt_listing_id`, p.`created_at`,
            SUBSTRING_INDEX(a.`email`, '@', 1) AS `author_name`,
            (p.`account_id` = ?) AS `is_owner`,
            EXISTS(SELECT 1 FROM `sky_phone_pages_reactions` r WHERE r.`post_id` = p.`id`
                AND r.`account_id` = ? AND r.`kind` = 'like') AS `is_liked`,
            EXISTS(SELECT 1 FROM `sky_phone_pages_reactions` r WHERE r.`post_id` = p.`id`
                AND r.`account_id` = ? AND r.`kind` = 'save') AS `is_saved`,
            (SELECT COUNT(*) FROM `sky_phone_pages_reactions` r
                WHERE r.`post_id` = p.`id` AND r.`kind` = 'like') AS `like_count`,
            (SELECT i.`gradient` FROM `sky_phone_pages_images` i
                WHERE i.`post_id` = p.`id` ORDER BY i.`sort_order` LIMIT 1) AS `image`,
            m.`price` AS `citymarkt_price`
        FROM `sky_phone_pages_posts` p
        JOIN `sky_phone_accounts` a ON a.`id` = p.`account_id`
        LEFT JOIN `sky_phone_marketplace_listings` m ON m.`id` = p.`citymarkt_listing_id`
        WHERE %s
        ORDER BY p.`created_at` DESC
        LIMIT ? OFFSET ?
    ]]):format(where_clause), parameters))
end

local function optional_account(source)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then return nil, error_response end
    local rows = Bridge.Database.Query("SELECT `account_id` FROM `sky_phone_devices` WHERE `imei` = ? LIMIT 1", { session.imei })
    return rows[1] and tonumber(rows[1].account_id) or nil, nil
end

Bridge.Callbacks.Register("sky_phone:pages:list", function(source, data)
    if type(data) ~= "table" then return { success = false, error = "invalid_request" } end
    local account_id, error_response = optional_account(source)
    if error_response then return error_response end
    local limit = Config.LocalPages.PageSize
    local offset = math.max(0, math.floor(tonumber(data.offset) or 0))
    local where = { "1 = 1" }
    local values = {}
    if data.category and data.category ~= "all" then
        if data.category ~= "citymarkt" and not categories[data.category] then
            return { success = false, error = "invalid_request" }
        end
        where[#where + 1] = "p.`category` = ?"
        values[#values + 1] = data.category
    end
    local search = trim(data.search)
    if search and search ~= "" then
        if utf8.len(search) > 80 then return { success = false, error = "invalid_request" } end
        where[#where + 1] = "(p.`title` LIKE ? OR p.`body` LIKE ?)"
        values[#values + 1] = "%" .. search .. "%"
        values[#values + 1] = "%" .. search .. "%"
    end
    if data.saved == true then
        if not account_id then return { success = false, error = "not_authenticated" } end
        where[#where + 1] = "EXISTS(SELECT 1 FROM `sky_phone_pages_reactions` sr WHERE sr.`post_id` = p.`id` AND sr.`account_id` = ? AND sr.`kind` = 'save')"
        values[#values + 1] = account_id
    end
    local rows = list_posts(account_id, table.concat(where, " AND "), values, limit + 1, offset)
    local has_more = #rows > limit
    if has_more then rows[#rows] = nil end
    return { success = true, data = { items = rows, offset = offset, hasMore = has_more } }
end)

Bridge.Callbacks.Register("sky_phone:pages:list-own", function(source)
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then return error_response end
    local rows = list_posts(account.id, "p.`account_id` = ?", { account.id }, Config.LocalPages.PageSize, 0)
    return { success = true, data = { items = rows, offset = 0, hasMore = false } }
end)

Bridge.Callbacks.Register("sky_phone:pages:get", function(source, data)
    if type(data) ~= "table" or type(data.id) ~= "string" then
        return { success = false, error = "post_not_found" }
    end
    local account_id, error_response = optional_account(source)
    if error_response then return error_response end
    local rows = list_posts(account_id, "p.`id` = ?", { data.id }, 1, 0)
    return rows[1] and { success = true, data = rows[1] } or { success = false, error = "post_not_found" }
end)

Bridge.Callbacks.Register("sky_phone:pages:create", function(source, data)
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then return error_response end
    if not SkyPhone.AllowOperation(source, "pages:create", 6, 60) then
        return { success = false, error = "rate_limited" }
    end
    if type(data) ~= "table" then return { success = false, error = "invalid_post" } end
    local title = trim(data.title)
    local body = trim(data.body)
    local district = data.district == "" and nil or data.district
    if not valid_text(title, Config.LocalPages.TitleMinLength, Config.LocalPages.TitleMaxLength)
        or not valid_text(body, Config.LocalPages.BodyMinLength, Config.LocalPages.BodyMaxLength)
        or not categories[data.category]
        or (district and not districts[district])
    then
        return { success = false, error = "invalid_post" }
    end
    local images = validate_images(source, account.imei, data.images)
    if not images then return { success = false, error = "invalid_images" } end
    local id = new_id()
    local statements = {{
        query = [[INSERT INTO `sky_phone_pages_posts`
            (`id`, `account_id`, `source_type`, `title`, `body`, `category`, `district`)
            VALUES (?, ?, 'personal', ?, ?, ?, ?)]],
        params = { id, account.id, title, body, data.category, district },
    }}
    for index, image in ipairs(images) do
        statements[#statements + 1] = {
            query = "INSERT INTO `sky_phone_pages_images` (`post_id`, `media_id`, `gradient`, `sort_order`) VALUES (?, ?, ?, ?)",
            params = { id, image.id, image.gradient, index },
        }
    end
    if not Bridge.Database.Transaction(statements) then
        return { success = false, error = "request_failed" }
    end
    return { success = true, data = { id = id } }
end)

Bridge.Callbacks.Register("sky_phone:pages:share-citymarkt", function(source, data)
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then return error_response end
    if not SkyPhone.AllowOperation(source, "pages:share-citymarkt", 3, 60) then
        return { success = false, error = "rate_limited" }
    end
    if type(data) ~= "table" or type(data.listingId) ~= "string" then
        return { success = false, error = "citymarkt_not_found" }
    end
    local listings = Bridge.Database.Query([[
        SELECT `id`, `title`, `description`, `district`
        FROM `sky_phone_marketplace_listings`
        WHERE `id` = ? AND `seller_account_id` = ? AND `status` IN ('active', 'reserved')
        LIMIT 1
    ]], { data.listingId, account.id })
    local listing = listings[1]
    if not listing then return { success = false, error = "citymarkt_not_found" } end
    local existing = Bridge.Database.Query("SELECT `id` FROM `sky_phone_pages_posts` WHERE `citymarkt_listing_id` = ? LIMIT 1", { listing.id })
    if existing[1] then return { success = false, error = "citymarkt_already_shared" } end
    local daily = Bridge.Database.Query([[
        SELECT COUNT(*) AS `count` FROM `sky_phone_pages_posts`
        WHERE `account_id` = ? AND `source_type` = 'citymarkt' AND `share_date` = CURRENT_DATE
    ]], { account.id })
    if (tonumber(daily[1] and daily[1].count) or 0) >= Config.LocalPages.CityMarktSharesPerDay then
        return { success = false, error = "citymarkt_daily_limit" }
    end
    local id = new_id()
    local statements = {{
        query = [[INSERT INTO `sky_phone_pages_posts`
            (`id`, `account_id`, `source_type`, `share_date`, `citymarkt_listing_id`, `title`, `body`, `category`, `district`)
            VALUES (?, ?, 'citymarkt', CURRENT_DATE, ?, ?, ?, 'citymarkt', ?)]],
        params = { id, account.id, listing.id, listing.title, listing.description, listing.district },
    }}
    local images = Bridge.Database.Query([[
        SELECT `media_id`, `gradient`, `sort_order` FROM `sky_phone_marketplace_images`
        WHERE `listing_id` = ? ORDER BY `sort_order` LIMIT ?
    ]], { listing.id, Config.LocalPages.MaxImages })
    for _, image in ipairs(images) do
        statements[#statements + 1] = {
            query = "INSERT INTO `sky_phone_pages_images` (`post_id`, `media_id`, `gradient`, `sort_order`) VALUES (?, ?, ?, ?)",
            params = { id, image.media_id, image.gradient, image.sort_order },
        }
    end
    if not Bridge.Database.Transaction(statements) then
        return { success = false, error = "citymarkt_daily_limit" }
    end
    return { success = true, data = { id = id } }
end)

Bridge.Callbacks.Register("sky_phone:pages:react", function(source, data)
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then return error_response end
    if not SkyPhone.AllowOperation(source, "pages:react", 30, 60) then
        return { success = false, error = "rate_limited" }
    end
    if type(data) ~= "table" or type(data.id) ~= "string" or (data.kind ~= "like" and data.kind ~= "save") or type(data.active) ~= "boolean" then
        return { success = false, error = "invalid_request" }
    end
    local posts = Bridge.Database.Query("SELECT `id` FROM `sky_phone_pages_posts` WHERE `id` = ? LIMIT 1", { data.id })
    if not posts[1] then return { success = false, error = "post_not_found" } end
    if data.active then
        Bridge.Database.Query("INSERT IGNORE INTO `sky_phone_pages_reactions` (`post_id`, `account_id`, `kind`) VALUES (?, ?, ?)", { data.id, account.id, data.kind })
    else
        Bridge.Database.Query("DELETE FROM `sky_phone_pages_reactions` WHERE `post_id` = ? AND `account_id` = ? AND `kind` = ?", { data.id, account.id, data.kind })
    end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:pages:delete", function(source, data)
    local account, error_response = SkyPhone.RequireAccount(source)
    if not account then return error_response end
    if type(data) ~= "table" or type(data.id) ~= "string" then
        return { success = false, error = "post_not_found" }
    end
    local result = Bridge.Database.Query("DELETE FROM `sky_phone_pages_posts` WHERE `id` = ? AND `account_id` = ?", { data.id, account.id })
    local affected = type(result) == "number" and result or type(result) == "table" and tonumber(result.affectedRows) or 0
    return affected > 0 and { success = true } or { success = false, error = "post_not_found" }
end)
end)
