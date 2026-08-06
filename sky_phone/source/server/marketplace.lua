Bridge.Database.AfterMigration("sky_phone", function()
local categories = {}
local districts = {}
local photo_gradients = {}
local item_conditions = { new = true, very_good = true, used = true, defective = true }
local price_types = { fixed = true, negotiable = true, free = true }
local report_reasons = { prohibited = true, fraud = true, spam = true, offensive = true, other = true }
local offer_responses = { accepted = true, rejected = true }
local public_statuses = { active = true, reserved = true }
local seller_statuses = { active = true, reserved = true, sold = true, removed = true }

for _, category in ipairs(Config.Marketplace.Categories) do
    categories[category] = true
end
for _, district in ipairs(Config.Marketplace.Districts) do
    districts[district] = true
end
for _, gradient in ipairs(Config.Marketplace.PhotoGradients) do
    photo_gradients[gradient] = true
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

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end
    return type(result) == "table" and tonumber(result.affectedRows) or 0
end

local function insert_id(result)
    if type(result) == "number" then
        return result
    end
    return type(result) == "table" and tonumber(result.insertId) or nil
end

local function new_id()
    local rows = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    if not rows[1] or type(rows[1].id) ~= "string" then
        error("[sky_phone] Database did not generate a marketplace id.")
    end
    return rows[1].id
end

local function require_payload(source, operation, data)
    if type(data) == "table" then
        return data
    end
    Bridge.Debug(
        "warn",
        "[sky_phone] Invalid marketplace payload for %s from source %s.",
        operation,
        tostring(source)
    )
    return nil
end

local function optional_account(source)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return nil, nil, error_response
    end
    local device = SkyPhone.LoadDevice(session.imei)
    return device and tonumber(device.account_id) or nil, device, nil
end

local function require_account(source)
    return SkyPhone.RequireAccount(source)
end

local function expire_listings()
    Bridge.Database.Query([[
        UPDATE `sky_phone_marketplace_listings`
        SET `status` = 'expired', `reserved_account_id` = NULL, `revision` = `revision` + 1
        WHERE `status` IN ('active', 'reserved') AND `expires_at` <= CURRENT_TIMESTAMP
    ]], {})
end

local function load_images(listing_id)
    return Bridge.Database.Query([[
        SELECT `media_id`, `gradient`, `sort_order`
        FROM `sky_phone_marketplace_images`
        WHERE `listing_id` = ?
        ORDER BY `sort_order`
    ]], { listing_id })
end

local function validate_images(source, imei, images)
    if type(images) ~= "table" or #images < 1 or #images > Config.Marketplace.MaxImages then
        return nil
    end

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
            Bridge.Debug(
                "warn",
                "[sky_phone] Rejected unowned marketplace image from source %s.",
                tostring(source)
            )
            return nil
        end
        seen[media_id] = true
        normalized[index] = { id = media_id, gradient = gradient }
    end
    return normalized
end

local function validate_listing(source, account, data)
    local title = trim(data.title)
    local description = trim(data.description)
    local price_type = data.priceType
    local price = tonumber(data.price)
    local district = data.district == "" and nil or data.district
    local show_phone = data.showPhone == true
    local device = SkyPhone.LoadDevice(account.imei)

    if not valid_text(title, Config.Marketplace.TitleMinLength, Config.Marketplace.TitleMaxLength)
        or not valid_text(description, Config.Marketplace.DescriptionMinLength, Config.Marketplace.DescriptionMaxLength)
        or not categories[data.category]
        or not item_conditions[data.condition]
        or not price_types[price_type]
        or (district and not districts[district])
    then
        return nil, "invalid_listing"
    end
    if price_type == "free" then
        price = nil
    elseif not price or price ~= math.floor(price) or price < 1 or price > Config.Marketplace.MaximumPrice then
        return nil, "invalid_price"
    end
    if show_phone and (not device or not device.phone_number) then
        return nil, "phone_unavailable"
    end

    local images = validate_images(source, account.imei, data.images)
    if not images then
        return nil, "invalid_images"
    end
    return {
        title = title,
        description = description,
        category = data.category,
        condition = data.condition,
        price_type = price_type,
        price = price,
        district = district,
        show_phone = show_phone,
        phone_number = show_phone and device.phone_number or nil,
        images = images,
    }
end

local function listing_summary_query(account_id, where_clause, order_clause, values, limit, offset)
    local query_values = { account_id or 0 }
    for _, value in ipairs(values) do
        query_values[#query_values + 1] = value
    end
    query_values[#query_values + 1] = limit
    query_values[#query_values + 1] = offset
    return Bridge.Database.Query(([[
        SELECT l.`id`, l.`title`, l.`category`, l.`item_condition`, l.`price_type`, l.`price`,
            l.`district`, l.`status`, l.`created_at`, l.`updated_at`, l.`expires_at`,
            SUBSTRING_INDEX(a.`email`, '@', 1) AS `seller_name`,
            (SELECT i.`gradient` FROM `sky_phone_marketplace_images` i
                WHERE i.`listing_id` = l.`id` ORDER BY i.`sort_order` LIMIT 1) AS `image`,
            EXISTS(SELECT 1 FROM `sky_phone_marketplace_favorites` f
                WHERE f.`listing_id` = l.`id` AND f.`account_id` = ?) AS `is_favorite`
        FROM `sky_phone_marketplace_listings` l
        JOIN `sky_phone_accounts` a ON a.`id` = l.`seller_account_id`
        WHERE %s
        ORDER BY %s
        LIMIT ? OFFSET ?
    ]]):format(where_clause, order_clause), query_values)
end

local function marketplace_counts(account_id)
    local rows = Bridge.Database.Query([[
        SELECT
            ((SELECT COUNT(*) FROM `sky_phone_marketplace_messages` m
                JOIN `sky_phone_marketplace_inquiries` q ON q.`id` = m.`inquiry_id`
                WHERE (q.`seller_account_id` = ? OR q.`buyer_account_id` = ?)
                    AND m.`sender_account_id` <> ? AND m.`read_at` IS NULL)
            + (SELECT COUNT(*) FROM `sky_phone_marketplace_offers` o
                JOIN `sky_phone_marketplace_inquiries` q ON q.`id` = o.`inquiry_id`
                WHERE (q.`seller_account_id` = ? OR q.`buyer_account_id` = ?)
                    AND ((o.`proposer_account_id` <> ? AND o.`read_at` IS NULL)
                        OR (o.`proposer_account_id` = ? AND o.`status` IN ('accepted', 'rejected')
                            AND o.`response_read_at` IS NULL)))) AS `unread`,
            (SELECT COUNT(*) FROM `sky_phone_marketplace_listings`
                WHERE `seller_account_id` = ? AND `status` IN ('active', 'reserved')) AS `active`
    ]], {
        account_id, account_id, account_id,
        account_id, account_id, account_id, account_id,
        account_id,
    })
    return {
        unread = tonumber(rows[1] and rows[1].unread) or 0,
        active = tonumber(rows[1] and rows[1].active) or 0,
    }
end

local function notify_changed(account_id)
    SkyPhone.NotifyAccount(account_id, "sky_phone:marketplace:changed", {
        counts = marketplace_counts(account_id),
    })
end

Bridge.Callbacks.Register("sky_phone:marketplace:list", function(source, data)
    local account_id, _, error_response = optional_account(source)
    if error_response then
        return error_response
    end
    data = require_payload(source, "list", data)
    if not data then
        return { success = false, error = "invalid_request" }
    end
    expire_listings()

    local values = {}
    local conditions = { "l.`status` IN ('active', 'reserved')" }
    local search = trim(data.search) or ""
    if not valid_text(search, 0, 100) then
        return { success = false, error = "invalid_search" }
    end
    if search ~= "" then
        local pattern = "%" .. search .. "%"
        conditions[#conditions + 1] = "(l.`title` LIKE ? OR l.`description` LIKE ?)"
        values[#values + 1] = pattern
        values[#values + 1] = pattern
    end
    if data.category and data.category ~= "all" then
        if not categories[data.category] then
            return { success = false, error = "invalid_filter" }
        end
        conditions[#conditions + 1] = "l.`category` = ?"
        values[#values + 1] = data.category
    end
    if data.district and data.district ~= "all" then
        if not districts[data.district] then
            return { success = false, error = "invalid_filter" }
        end
        conditions[#conditions + 1] = "l.`district` = ?"
        values[#values + 1] = data.district
    end
    if data.favorites == true then
        if not account_id then
            return { success = false, error = "not_authenticated" }
        end
        conditions[#conditions + 1] = [[EXISTS(SELECT 1 FROM `sky_phone_marketplace_favorites` favorite_filter
            WHERE favorite_filter.`listing_id` = l.`id` AND favorite_filter.`account_id` = ?)]]
        values[#values + 1] = account_id
    end
    if account_id then
        conditions[#conditions + 1] = [[NOT EXISTS(SELECT 1 FROM `sky_phone_marketplace_blocks` b
            WHERE (b.`blocker_account_id` = ? AND b.`blocked_account_id` = l.`seller_account_id`)
                OR (b.`blocker_account_id` = l.`seller_account_id` AND b.`blocked_account_id` = ?))]]
        values[#values + 1] = account_id
        values[#values + 1] = account_id
    end

    local sort_orders = {
        newest = "l.`created_at` DESC, l.`id` DESC",
        price_asc = "l.`price` IS NULL DESC, l.`price` ASC, l.`created_at` DESC",
        price_desc = "l.`price` IS NULL, l.`price` DESC, l.`created_at` DESC",
    }
    local order_clause = sort_orders[data.sort] or sort_orders.newest
    local offset = math.max(0, math.min(100000, math.floor(tonumber(data.offset) or 0)))
    local rows = listing_summary_query(
        account_id,
        table.concat(conditions, " AND "),
        order_clause,
        values,
        Config.Marketplace.PageSize + 1,
        offset
    )
    local has_more = #rows > Config.Marketplace.PageSize
    if has_more then
        rows[#rows] = nil
    end
    return { success = true, data = { items = rows, hasMore = has_more, offset = offset } }
end)

Bridge.Callbacks.Register("sky_phone:marketplace:get", function(source, data)
    local account_id, _, error_response = optional_account(source)
    if error_response then
        return error_response
    end
    data = require_payload(source, "get", data)
    local id = data and data.id
    if type(id) ~= "string" or #id ~= 36 then
        return { success = false, error = "invalid_listing" }
    end
    expire_listings()

    local rows = Bridge.Database.Query([[
        SELECT l.*, SUBSTRING_INDEX(a.`email`, '@', 1) AS `seller_name`, a.`created_at` AS `seller_since`,
            (SELECT COUNT(*) FROM `sky_phone_marketplace_listings` own
                WHERE own.`seller_account_id` = l.`seller_account_id` AND own.`status` IN ('active', 'reserved')) AS `seller_active`,
            EXISTS(SELECT 1 FROM `sky_phone_marketplace_favorites` f
                WHERE f.`listing_id` = l.`id` AND f.`account_id` = ?) AS `is_favorite`
        FROM `sky_phone_marketplace_listings` l
        JOIN `sky_phone_accounts` a ON a.`id` = l.`seller_account_id`
        WHERE l.`id` = ?
        LIMIT 1
    ]], { account_id or 0, id })
    local listing = rows[1]
    if not listing or (not public_statuses[listing.status] and tonumber(listing.seller_account_id) ~= account_id) then
        return { success = false, error = "listing_not_found" }
    end
    if account_id then
        local blocks = Bridge.Database.Query([[
            SELECT 1 FROM `sky_phone_marketplace_blocks`
            WHERE (`blocker_account_id` = ? AND `blocked_account_id` = ?)
                OR (`blocker_account_id` = ? AND `blocked_account_id` = ?)
            LIMIT 1
        ]], { account_id, listing.seller_account_id, listing.seller_account_id, account_id })
        if blocks[1] then
            return { success = false, error = "listing_not_found" }
        end
    end
    listing.images = load_images(id)
    listing.is_owner = account_id and tonumber(listing.seller_account_id) == account_id or false
    listing.phone_number = listing.show_phone == 1 and listing.phone_number or nil
    listing.reserved_account_id = listing.is_owner and listing.reserved_account_id or nil
    return { success = true, data = listing }
end)

Bridge.Callbacks.Register("sky_phone:marketplace:list-own", function(source, data)
    local account, error_response = require_account(source)
    if not account then
        return error_response
    end
    data = require_payload(source, "list-own", data) or {}
    expire_listings()
    local offset = math.max(0, math.min(100000, math.floor(tonumber(data.offset) or 0)))
    local rows = listing_summary_query(
        account.id,
        "l.`seller_account_id` = ?",
        "l.`updated_at` DESC, l.`id` DESC",
        { account.id },
        Config.Marketplace.PageSize + 1,
        offset
    )
    local has_more = #rows > Config.Marketplace.PageSize
    if has_more then rows[#rows] = nil end
    return { success = true, data = { items = rows, hasMore = has_more, offset = offset } }
end)

Bridge.Callbacks.Register("sky_phone:marketplace:create", function(source, data)
    local account, error_response = require_account(source)
    if not account then return error_response end
    if not SkyPhone.AllowOperation(source, "marketplace:create", 5, 60) then
        return { success = false, error = "rate_limited" }
    end
    data = require_payload(source, "create", data)
    if not data then return { success = false, error = "invalid_request" } end
    local listing, validation_error = validate_listing(source, account, data)
    if not listing then return { success = false, error = validation_error } end

    local counts = marketplace_counts(account.id)
    if counts.active >= Config.Marketplace.MaxActiveListings then
        return { success = false, error = "listing_limit" }
    end
    local id = new_id()
    local statements = {{
        query = [[
            INSERT INTO `sky_phone_marketplace_listings`
                (`id`, `seller_account_id`, `title`, `description`, `category`, `item_condition`,
                 `price_type`, `price`, `district`, `show_phone`, `phone_number`, `expires_at`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL ? DAY))
        ]],
        params = {
            id, account.id, listing.title, listing.description, listing.category, listing.condition,
            listing.price_type, listing.price, listing.district, listing.show_phone and 1 or 0,
            listing.phone_number, Config.Marketplace.ListingLifetimeDays,
        },
    }}
    for index, image in ipairs(listing.images) do
        statements[#statements + 1] = {
            query = [[INSERT INTO `sky_phone_marketplace_images`
                (`listing_id`, `media_id`, `gradient`, `sort_order`) VALUES (?, ?, ?, ?)]],
            params = { id, image.id, image.gradient, index },
        }
    end
    if not Bridge.Database.Transaction(statements) then
        return { success = false, error = "request_failed" }
    end
    notify_changed(account.id)
    return { success = true, data = { id = id } }
end)

Bridge.Callbacks.Register("sky_phone:marketplace:update", function(source, data)
    local account, error_response = require_account(source)
    if not account then return error_response end
    data = require_payload(source, "update", data)
    local id = data and data.id
    local revision = data and tonumber(data.revision)
    if type(id) ~= "string" or #id ~= 36 or not revision then
        return { success = false, error = "invalid_listing" }
    end
    local listing, validation_error = validate_listing(source, account, data)
    if not listing then return { success = false, error = validation_error } end

    local current_rows = Bridge.Database.Query([[
        SELECT `revision` FROM `sky_phone_marketplace_listings`
        WHERE `id` = ? AND `seller_account_id` = ? AND `status` IN ('active', 'reserved', 'expired')
        LIMIT 1
    ]], { id, account.id })
    if not current_rows[1] then
        return { success = false, error = "listing_not_found" }
    end
    if tonumber(current_rows[1].revision) ~= revision then
        return { success = false, error = "conflict" }
    end

    local statements = {
        {
            query = [[
                UPDATE `sky_phone_marketplace_listings`
                SET `title` = ?, `description` = ?, `category` = ?, `item_condition` = ?,
                    `price_type` = ?, `price` = ?, `district` = ?, `show_phone` = ?, `phone_number` = ?,
                    `revision` = `revision` + 1
                WHERE `id` = ? AND `seller_account_id` = ? AND `status` IN ('active', 'reserved', 'expired')
            ]],
            params = {
                listing.title, listing.description, listing.category, listing.condition,
                listing.price_type, listing.price, listing.district, listing.show_phone and 1 or 0,
                listing.phone_number, id, account.id,
            },
        },
        { query = "DELETE FROM `sky_phone_marketplace_images` WHERE `listing_id` = ?", params = { id } },
    }
    for index, image in ipairs(listing.images) do
        statements[#statements + 1] = {
            query = [[INSERT INTO `sky_phone_marketplace_images`
                (`listing_id`, `media_id`, `gradient`, `sort_order`) VALUES (?, ?, ?, ?)]],
            params = { id, image.id, image.gradient, index },
        }
    end
    if not Bridge.Database.Transaction(statements) then
        return { success = false, error = "request_failed" }
    end
    local rows = Bridge.Database.Query(
        "SELECT `revision` FROM `sky_phone_marketplace_listings` WHERE `id` = ? AND `seller_account_id` = ?",
        { id, account.id }
    )
    if not rows[1] then return { success = false, error = "listing_not_found" } end
    notify_changed(account.id)
    return { success = true, data = { revision = tonumber(rows[1].revision) } }
end)

Bridge.Callbacks.Register("sky_phone:marketplace:set-status", function(source, data)
    local account, error_response = require_account(source)
    if not account then return error_response end
    data = require_payload(source, "set-status", data)
    if not data or type(data.id) ~= "string" or #data.id ~= 36 or not seller_statuses[data.status] then
        return { success = false, error = "invalid_status" }
    end
    local listings = Bridge.Database.Query([[
        SELECT `status`, `reserved_account_id` FROM `sky_phone_marketplace_listings`
        WHERE `id` = ? AND `seller_account_id` = ? LIMIT 1
    ]], { data.id, account.id })
    local current = listings[1]
    if not current then return { success = false, error = "listing_not_found" } end

    local reserved_account_id
    if data.status == "reserved" then
        if current.status ~= "active" or type(data.inquiryId) ~= "string" then
            return { success = false, error = "invalid_status" }
        end
        local inquiries = Bridge.Database.Query([[
            SELECT `buyer_account_id` FROM `sky_phone_marketplace_inquiries`
            WHERE `id` = ? AND `listing_id` = ? AND `seller_account_id` = ? LIMIT 1
        ]], { data.inquiryId, data.id, account.id })
        if not inquiries[1] then return { success = false, error = "inquiry_not_found" } end
        reserved_account_id = inquiries[1].buyer_account_id
    elseif data.status == "active" then
        if current.status ~= "reserved" and current.status ~= "expired" then
            return { success = false, error = "invalid_status" }
        end
    elseif data.status == "sold" then
        if current.status ~= "active" and current.status ~= "reserved" then
            return { success = false, error = "invalid_status" }
        end
        reserved_account_id = current.reserved_account_id
    elseif data.status == "removed" and current.status == "sold" then
        return { success = false, error = "invalid_status" }
    end

    local expiry = data.status == "active" and ", `expires_at` = DATE_ADD(CURRENT_TIMESTAMP, INTERVAL ? DAY)" or ""
    local params = { data.status, reserved_account_id }
    if data.status == "active" then params[#params + 1] = Config.Marketplace.ListingLifetimeDays end
    params[#params + 1] = data.id
    params[#params + 1] = account.id
    Bridge.Database.Query(([[
        UPDATE `sky_phone_marketplace_listings`
        SET `status` = ?, `reserved_account_id` = ?, `revision` = `revision` + 1%s
        WHERE `id` = ? AND `seller_account_id` = ?
    ]]):format(expiry), params)
    notify_changed(account.id)
    if reserved_account_id then
        notify_changed(reserved_account_id)
    end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:marketplace:favorite", function(source, data)
    local account, error_response = require_account(source)
    if not account then return error_response end
    data = require_payload(source, "favorite", data)
    if not data or type(data.id) ~= "string" or #data.id ~= 36 or type(data.favorite) ~= "boolean" then
        return { success = false, error = "invalid_listing" }
    end
    if data.favorite then
        Bridge.Database.Query([[
            INSERT IGNORE INTO `sky_phone_marketplace_favorites` (`account_id`, `listing_id`)
            SELECT ?, `id` FROM `sky_phone_marketplace_listings`
            WHERE `id` = ? AND `status` IN ('active', 'reserved')
        ]], { account.id, data.id })
    else
        Bridge.Database.Query(
            "DELETE FROM `sky_phone_marketplace_favorites` WHERE `account_id` = ? AND `listing_id` = ?",
            { account.id, data.id }
        )
    end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:marketplace:counts", function(source)
    local account, error_response = require_account(source)
    if not account then return error_response end
    return { success = true, data = marketplace_counts(account.id) }
end)

Bridge.Callbacks.Register("sky_phone:marketplace:list-inquiries", function(source)
    local account, error_response = require_account(source)
    if not account then return error_response end
    local rows = Bridge.Database.Query([[
        SELECT q.`id`, q.`listing_id`, q.`seller_account_id`, q.`buyer_account_id`, q.`updated_at`,
            l.`title`, l.`price`, l.`price_type`, l.`status`,
            (SELECT image.`gradient` FROM `sky_phone_marketplace_images` image
                WHERE image.`listing_id` = l.`id` ORDER BY image.`sort_order` LIMIT 1) AS `image`,
            SUBSTRING_INDEX(other_account.`email`, '@', 1) AS `other_name`,
            (SELECT message.`body` FROM `sky_phone_marketplace_messages` message
                WHERE message.`inquiry_id` = q.`id` ORDER BY message.`id` DESC LIMIT 1) AS `last_message`,
            ((SELECT COUNT(*) FROM `sky_phone_marketplace_messages` unread
                WHERE unread.`inquiry_id` = q.`id` AND unread.`sender_account_id` <> ?
                    AND unread.`read_at` IS NULL)
            + (SELECT COUNT(*) FROM `sky_phone_marketplace_offers` unread_offer
                WHERE unread_offer.`inquiry_id` = q.`id`
                    AND ((unread_offer.`proposer_account_id` <> ? AND unread_offer.`read_at` IS NULL)
                        OR (unread_offer.`proposer_account_id` = ?
                            AND unread_offer.`status` IN ('accepted', 'rejected')
                            AND unread_offer.`response_read_at` IS NULL)))) AS `unread`
        FROM `sky_phone_marketplace_inquiries` q
        JOIN `sky_phone_marketplace_listings` l ON l.`id` = q.`listing_id`
        JOIN `sky_phone_accounts` other_account ON other_account.`id` =
            CASE WHEN q.`seller_account_id` = ? THEN q.`buyer_account_id` ELSE q.`seller_account_id` END
        WHERE q.`seller_account_id` = ? OR q.`buyer_account_id` = ?
        ORDER BY q.`updated_at` DESC
        LIMIT 100
    ]], { account.id, account.id, account.id, account.id, account.id, account.id })
    return { success = true, data = rows }
end)

Bridge.Callbacks.Register("sky_phone:marketplace:get-inquiry", function(source, data)
    local account, error_response = require_account(source)
    if not account then return error_response end
    data = require_payload(source, "get-inquiry", data)
    if not data or type(data.id) ~= "string" or #data.id ~= 36 then
        return { success = false, error = "invalid_inquiry" }
    end
    local inquiries = Bridge.Database.Query([[
        SELECT q.*, l.`title`, l.`price`, l.`price_type`, l.`status`, l.`reserved_account_id`,
            SUBSTRING_INDEX(seller.`email`, '@', 1) AS `seller_name`,
            SUBSTRING_INDEX(buyer.`email`, '@', 1) AS `buyer_name`
        FROM `sky_phone_marketplace_inquiries` q
        JOIN `sky_phone_marketplace_listings` l ON l.`id` = q.`listing_id`
        JOIN `sky_phone_accounts` seller ON seller.`id` = q.`seller_account_id`
        JOIN `sky_phone_accounts` buyer ON buyer.`id` = q.`buyer_account_id`
        WHERE q.`id` = ? AND (q.`seller_account_id` = ? OR q.`buyer_account_id` = ?)
        LIMIT 1
    ]], { data.id, account.id, account.id })
    if not inquiries[1] then return { success = false, error = "inquiry_not_found" } end

    Bridge.Database.Query([[
        UPDATE `sky_phone_marketplace_messages`
        SET `read_at` = CURRENT_TIMESTAMP
        WHERE `inquiry_id` = ? AND `sender_account_id` <> ? AND `read_at` IS NULL
    ]], { data.id, account.id })
    Bridge.Database.Query([[
        UPDATE `sky_phone_marketplace_offers`
        SET `read_at` = CURRENT_TIMESTAMP
        WHERE `inquiry_id` = ? AND `proposer_account_id` <> ? AND `read_at` IS NULL
    ]], { data.id, account.id })
    Bridge.Database.Query([[
        UPDATE `sky_phone_marketplace_offers`
        SET `response_read_at` = CURRENT_TIMESTAMP
        WHERE `inquiry_id` = ? AND `proposer_account_id` = ?
            AND `status` IN ('accepted', 'rejected') AND `response_read_at` IS NULL
    ]], { data.id, account.id })
    local messages = Bridge.Database.Query([[
        SELECT `id`, `sender_account_id`, `body`, `created_at`, `read_at`
        FROM `sky_phone_marketplace_messages`
        WHERE `inquiry_id` = ?
        ORDER BY `id` ASC
        LIMIT ?
    ]], { data.id, Config.Marketplace.MessagePageSize })
    local offers = Bridge.Database.Query([[
        SELECT `id`, `proposer_account_id`, `amount`, `status`, `read_at`, `response_read_at`,
            `created_at`, `updated_at`
        FROM `sky_phone_marketplace_offers`
        WHERE `inquiry_id` = ?
        ORDER BY `id` ASC
        LIMIT ?
    ]], { data.id, Config.Marketplace.OfferHistorySize })
    notify_changed(account.id)
    return {
        success = true,
        data = { inquiry = inquiries[1], messages = messages, offers = offers, accountId = account.id },
    }
end)

Bridge.Callbacks.Register("sky_phone:marketplace:send-message", function(source, data)
    local account, error_response = require_account(source)
    if not account then return error_response end
    if not SkyPhone.AllowOperation(source, "marketplace:message", 20, 60) then
        return { success = false, error = "rate_limited" }
    end
    data = require_payload(source, "send-message", data)
    local body = data and trim(data.body)
    if not valid_text(body, 1, Config.Marketplace.MessageMaxLength) then
        return { success = false, error = "invalid_message" }
    end

    local inquiry
    if type(data.inquiryId) == "string" and #data.inquiryId == 36 then
        local rows = Bridge.Database.Query([[
            SELECT q.*, l.`status` FROM `sky_phone_marketplace_inquiries` q
            JOIN `sky_phone_marketplace_listings` l ON l.`id` = q.`listing_id`
            WHERE q.`id` = ? AND (q.`seller_account_id` = ? OR q.`buyer_account_id` = ?)
            LIMIT 1
        ]], { data.inquiryId, account.id, account.id })
        inquiry = rows[1]
    elseif type(data.listingId) == "string" and #data.listingId == 36 then
        local listings = Bridge.Database.Query([[
            SELECT `id`, `seller_account_id`, `status` FROM `sky_phone_marketplace_listings`
            WHERE `id` = ? AND `status` IN ('active', 'reserved') LIMIT 1
        ]], { data.listingId })
        local listing = listings[1]
        if listing and tonumber(listing.seller_account_id) ~= account.id then
            local blocked = Bridge.Database.Query([[
                SELECT 1 FROM `sky_phone_marketplace_blocks`
                WHERE (`blocker_account_id` = ? AND `blocked_account_id` = ?)
                    OR (`blocker_account_id` = ? AND `blocked_account_id` = ?)
                LIMIT 1
            ]], { account.id, listing.seller_account_id, listing.seller_account_id, account.id })
            if blocked[1] then return { success = false, error = "blocked" } end
            local existing = Bridge.Database.Query([[
                SELECT * FROM `sky_phone_marketplace_inquiries`
                WHERE `listing_id` = ? AND `buyer_account_id` = ? LIMIT 1
            ]], { listing.id, account.id })
            inquiry = existing[1]
            if not inquiry then
                inquiry = {
                    id = new_id(),
                    listing_id = listing.id,
                    seller_account_id = listing.seller_account_id,
                    buyer_account_id = account.id,
                    status = listing.status,
                }
                Bridge.Database.Query([[
                    INSERT INTO `sky_phone_marketplace_inquiries`
                        (`id`, `listing_id`, `seller_account_id`, `buyer_account_id`)
                    VALUES (?, ?, ?, ?)
                ]], { inquiry.id, inquiry.listing_id, inquiry.seller_account_id, inquiry.buyer_account_id })
            end
        end
    end
    if not inquiry then return { success = false, error = "inquiry_not_found" } end

    local other_account_id = tonumber(inquiry.seller_account_id) == account.id
        and tonumber(inquiry.buyer_account_id) or tonumber(inquiry.seller_account_id)
    local blocked = Bridge.Database.Query([[
        SELECT 1 FROM `sky_phone_marketplace_blocks`
        WHERE (`blocker_account_id` = ? AND `blocked_account_id` = ?)
            OR (`blocker_account_id` = ? AND `blocked_account_id` = ?)
        LIMIT 1
    ]], { account.id, other_account_id, other_account_id, account.id })
    if blocked[1] then return { success = false, error = "blocked" } end

    Bridge.Database.Query([[
        INSERT INTO `sky_phone_marketplace_messages` (`inquiry_id`, `sender_account_id`, `body`)
        VALUES (?, ?, ?)
    ]], { inquiry.id, account.id, body })
    Bridge.Database.Query(
        "UPDATE `sky_phone_marketplace_inquiries` SET `updated_at` = CURRENT_TIMESTAMP WHERE `id` = ?",
        { inquiry.id }
    )
    notify_changed(account.id)
    SkyPhone.NotifyAccountDevices(other_account_id, "sky_phone:marketplace:new-message", {
        inquiryId = inquiry.id,
        listingId = inquiry.listing_id,
        sender = account.email:match("^([^@]+)") or account.email,
        text = body,
    })
    notify_changed(other_account_id)
    return { success = true, data = { id = inquiry.id } }
end)

Bridge.Callbacks.Register("sky_phone:marketplace:make-offer", function(source, data)
    local account, error_response = require_account(source)
    if not account then return error_response end
    if not SkyPhone.AllowOperation(source, "marketplace:offer", 10, 60) then
        return { success = false, error = "rate_limited" }
    end
    data = require_payload(source, "make-offer", data)
    local amount = data and tonumber(data.amount) or nil
    if not data or type(data.inquiryId) ~= "string" or #data.inquiryId ~= 36
        or not amount or amount ~= math.floor(amount) or amount < 1
        or amount > Config.Marketplace.MaximumPrice
    then
        return { success = false, error = "invalid_offer" }
    end

    local rows = Bridge.Database.Query([[
        SELECT q.*, l.`status` AS `listing_status`, l.`reserved_account_id`
        FROM `sky_phone_marketplace_inquiries` q
        JOIN `sky_phone_marketplace_listings` l ON l.`id` = q.`listing_id`
        WHERE q.`id` = ? AND (q.`seller_account_id` = ? OR q.`buyer_account_id` = ?)
        LIMIT 1
    ]], { data.inquiryId, account.id, account.id })
    local inquiry = rows[1]
    if not inquiry then return { success = false, error = "inquiry_not_found" } end

    local buyer_account_id = tonumber(inquiry.buyer_account_id)
    local seller_account_id = tonumber(inquiry.seller_account_id)
    local reserved_account_id = tonumber(inquiry.reserved_account_id)
    if inquiry.listing_status ~= "active"
        and (inquiry.listing_status ~= "reserved" or reserved_account_id ~= buyer_account_id)
    then
        return { success = false, error = "offer_listing_unavailable" }
    end
    if inquiry.offer_status == "accepted" then
        return { success = false, error = "offer_closed" }
    end

    local current_proposer_account_id = tonumber(inquiry.offer_proposer_account_id)
    if inquiry.offer_status == "pending" and current_proposer_account_id == account.id then
        return { success = false, error = "offer_waiting" }
    end
    if inquiry.offer_status ~= "pending" and account.id ~= buyer_account_id then
        return { success = false, error = "offer_not_allowed" }
    end

    local other_account_id = account.id == seller_account_id and buyer_account_id or seller_account_id
    local blocked = Bridge.Database.Query([[
        SELECT 1 FROM `sky_phone_marketplace_blocks`
        WHERE (`blocker_account_id` = ? AND `blocked_account_id` = ?)
            OR (`blocker_account_id` = ? AND `blocked_account_id` = ?)
        LIMIT 1
    ]], { account.id, other_account_id, other_account_id, account.id })
    if blocked[1] then return { success = false, error = "blocked" } end

    local offer_result = Bridge.Database.Query([[
        INSERT INTO `sky_phone_marketplace_offers` (`inquiry_id`, `proposer_account_id`, `amount`)
        VALUES (?, ?, ?)
    ]], { inquiry.id, account.id, amount })
    local offer_id = insert_id(offer_result)
    if not offer_id then
        error("[sky_phone] Database did not return a marketplace offer id.")
    end

    local revision = tonumber(inquiry.offer_revision) or 0
    local update_result = Bridge.Database.Query([[
        UPDATE `sky_phone_marketplace_inquiries`
        SET `offer_id` = ?, `offer_amount` = ?, `offer_proposer_account_id` = ?,
            `offer_status` = 'pending', `offer_revision` = `offer_revision` + 1,
            `updated_at` = CURRENT_TIMESTAMP
        WHERE `id` = ? AND `offer_revision` = ?
    ]], { offer_id, amount, account.id, inquiry.id, revision })
    if affected_rows(update_result) == 0 then
        Bridge.Database.Query(
            "UPDATE `sky_phone_marketplace_offers` SET `status` = 'countered' WHERE `id` = ?",
            { offer_id }
        )
        return { success = false, error = "offer_conflict" }
    end

    local previous_offer_id = tonumber(inquiry.offer_id)
    if previous_offer_id then
        Bridge.Database.Query([[
            UPDATE `sky_phone_marketplace_offers`
            SET `status` = 'countered'
            WHERE `id` = ? AND `status` = 'pending'
        ]], { previous_offer_id })
    end

    notify_changed(account.id)
    SkyPhone.NotifyAccountDevices(other_account_id, "sky_phone:marketplace:new-message", {
        amount = amount,
        inquiryId = inquiry.id,
        kind = "offer",
        listingId = inquiry.listing_id,
        sender = account.email:match("^([^@]+)") or account.email,
    })
    notify_changed(other_account_id)
    return { success = true, data = { id = offer_id } }
end)

Bridge.Callbacks.Register("sky_phone:marketplace:respond-offer", function(source, data)
    local account, error_response = require_account(source)
    if not account then return error_response end
    if not SkyPhone.AllowOperation(source, "marketplace:offer-response", 10, 60) then
        return { success = false, error = "rate_limited" }
    end
    data = require_payload(source, "respond-offer", data)
    if not data or type(data.inquiryId) ~= "string" or #data.inquiryId ~= 36
        or not offer_responses[data.action]
    then
        return { success = false, error = "invalid_offer_response" }
    end

    local rows = Bridge.Database.Query([[
        SELECT q.*, l.`status` AS `listing_status`, l.`reserved_account_id`
        FROM `sky_phone_marketplace_inquiries` q
        JOIN `sky_phone_marketplace_listings` l ON l.`id` = q.`listing_id`
        WHERE q.`id` = ? AND (q.`seller_account_id` = ? OR q.`buyer_account_id` = ?)
        LIMIT 1
    ]], { data.inquiryId, account.id, account.id })
    local inquiry = rows[1]
    if not inquiry then return { success = false, error = "inquiry_not_found" } end

    local offer_id = tonumber(inquiry.offer_id)
    local proposer_account_id = tonumber(inquiry.offer_proposer_account_id)
    if inquiry.offer_status ~= "pending" or not offer_id or proposer_account_id == account.id then
        return { success = false, error = "offer_not_actionable" }
    end

    local buyer_account_id = tonumber(inquiry.buyer_account_id)
    if data.action == "accepted" then
        local reservation_result = Bridge.Database.Query([[
            UPDATE `sky_phone_marketplace_listings`
            SET `status` = 'reserved', `reserved_account_id` = ?, `revision` = `revision` + 1
            WHERE `id` = ? AND (`status` = 'active'
                OR (`status` = 'reserved' AND `reserved_account_id` = ?))
        ]], { buyer_account_id, inquiry.listing_id, buyer_account_id })
        if affected_rows(reservation_result) == 0 then
            return { success = false, error = "offer_listing_unavailable" }
        end
    end

    local revision = tonumber(inquiry.offer_revision) or 0
    local update_result = Bridge.Database.Query([[
        UPDATE `sky_phone_marketplace_inquiries`
        SET `offer_status` = ?, `offer_revision` = `offer_revision` + 1,
            `updated_at` = CURRENT_TIMESTAMP
        WHERE `id` = ? AND `offer_id` = ? AND `offer_revision` = ? AND `offer_status` = 'pending'
    ]], { data.action, inquiry.id, offer_id, revision })
    if affected_rows(update_result) == 0 then
        return { success = false, error = "offer_conflict" }
    end
    Bridge.Database.Query([[
        UPDATE `sky_phone_marketplace_offers`
        SET `status` = ?
        WHERE `id` = ? AND `status` = 'pending'
    ]], { data.action, offer_id })

    notify_changed(account.id)
    SkyPhone.NotifyAccountDevices(proposer_account_id, "sky_phone:marketplace:new-message", {
        action = data.action,
        amount = tonumber(inquiry.offer_amount),
        inquiryId = inquiry.id,
        kind = "offer-response",
        listingId = inquiry.listing_id,
        sender = account.email:match("^([^@]+)") or account.email,
    })
    notify_changed(proposer_account_id)
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:marketplace:report", function(source, data)
    local account, error_response = require_account(source)
    if not account then return error_response end
    if not SkyPhone.AllowOperation(source, "marketplace:report", 5, 60) then
        return { success = false, error = "rate_limited" }
    end
    data = require_payload(source, "report", data)
    local details = data and trim(data.details) or ""
    if not data or type(data.id) ~= "string" or #data.id ~= 36 or not report_reasons[data.reason]
        or not valid_text(details, 0, 500)
    then
        return { success = false, error = "invalid_report" }
    end
    local result = Bridge.Database.Query([[
        INSERT IGNORE INTO `sky_phone_marketplace_reports`
            (`id`, `reporter_account_id`, `listing_id`, `reason`, `details`)
        SELECT ?, ?, `id`, ?, ? FROM `sky_phone_marketplace_listings`
        WHERE `id` = ? AND `seller_account_id` <> ?
    ]], { new_id(), account.id, data.reason, details, data.id, account.id })
    if affected_rows(result) == 0 then
        return { success = false, error = "already_reported" }
    end
    return { success = true }
end)

Bridge.Callbacks.Register("sky_phone:marketplace:block", function(source, data)
    local account, error_response = require_account(source)
    if not account then return error_response end
    data = require_payload(source, "block", data)
    if not data or type(data.listingId) ~= "string" or #data.listingId ~= 36 then
        return { success = false, error = "invalid_listing" }
    end
    local listings = Bridge.Database.Query(
        "SELECT `seller_account_id` FROM `sky_phone_marketplace_listings` WHERE `id` = ? LIMIT 1",
        { data.listingId }
    )
    local blocked_id = listings[1] and tonumber(listings[1].seller_account_id)
    if not blocked_id or blocked_id == account.id then
        return { success = false, error = "invalid_listing" }
    end
    if data.blocked == false then
        Bridge.Database.Query([[
            DELETE FROM `sky_phone_marketplace_blocks`
            WHERE `blocker_account_id` = ? AND `blocked_account_id` = ?
        ]], { account.id, blocked_id })
    else
        Bridge.Database.Query([[
            INSERT IGNORE INTO `sky_phone_marketplace_blocks` (`blocker_account_id`, `blocked_account_id`)
            VALUES (?, ?)
        ]], { account.id, blocked_id })
    end
    return { success = true }
end)
end)
