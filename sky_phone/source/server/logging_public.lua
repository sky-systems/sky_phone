-- Public announcements are built from persisted public content, independently
-- of administrative snapshots. Nothing from a raw request/response is forwarded.
SkyPhoneLog.PublicActions = {}
SkyPhoneLog.PublicCategories = { "Feather", "Pages", "Marketplace", "Picstagram", "FlipTok", "SkyPic", "WeazelNews" }
local entities = {}

local function entity(key, table_name, columns, joins, visible, media_table, media_key, media_order)
    if joins:find("p%.`") then
        columns = columns .. ", avatar.`url` AS `author_avatar`"
        joins = joins .. " LEFT JOIN `sky_phone_media` avatar ON avatar.`id` = p.`avatar_media_id` "
    end
    entities[key] = {
        query = "SELECT r.`id`, " .. columns .. " FROM `" .. table_name .. "` r " .. joins .. " WHERE r.`id` = ? LIMIT 1",
        visible = visible,
        media = media_table and ("SELECT m.`url`, m.`media_type`, m.`mime_type` FROM `%s` a JOIN `sky_phone_media` m "
            .. "ON m.`id` = a.`media_id` WHERE a.`%s` = ? ORDER BY a.`%s` LIMIT 4"):format(media_table, media_key, media_order or "sort_order"),
    }
end
local function published(row) return row.status == "published" end
local function public_profile(row)
    return row.profile_status == "active" and tonumber(row.private) == 0
end
local function active_story(row)
    return row.status == "active" and (tonumber(row.expires_at) or 0) > os.time()
end
local author = "p.`display_name` AS `author_name`, p.`handle` AS `author_handle`"
local media_join = " LEFT JOIN `sky_phone_media` m ON m.`id` = r.`media_id` "
local media_columns = ", m.`url` AS `media_url`, m.`media_type`, m.`mime_type`"

entity("feather", "sky_phone_feather_posts", "r.`body`, r.`status`, " .. author,
    "JOIN `sky_phone_feather_profiles` p ON p.`id` = r.`profile_id`", published,
    "sky_phone_feather_post_media", "post_id")
entity("pages", "sky_phone_pages_posts", "r.`title`, r.`body`, r.`category`, r.`district`, p.`handle` AS `author_handle`",
    "LEFT JOIN `sky_phone_pages_profiles` p ON p.`account_id` = r.`account_id`", function() return true end,
    "sky_phone_pages_images", "post_id")
entity("marketplace", "sky_phone_marketplace_listings",
    "r.`title`, r.`description` AS `body`, r.`category`, r.`district`, r.`price`, r.`price_type`, r.`status`, "
        .. "p.`display_name` AS `author_name`",
    "LEFT JOIN `sky_phone_marketplace_profiles` p ON p.`account_id` = r.`seller_account_id`",
    function(row) return row.status == "active" or row.status == "reserved" or row.status == "sold" end,
    "sky_phone_marketplace_images", "listing_id")
entity("picstagram-post", "sky_phone_picstagram_posts",
    "r.`caption` AS `body`, r.`location`, r.`status`, p.`private`, p.`status` AS `profile_status`, " .. author,
    "JOIN `sky_phone_picstagram_profiles` p ON p.`id` = r.`profile_id`",
    function(row) return published(row) and public_profile(row) end,
    "sky_phone_picstagram_post_media", "post_id", "position")
entity("picstagram-story", "sky_phone_picstagram_stories",
    "r.`body`, r.`status`, UNIX_TIMESTAMP(r.`expires_at`) AS `expires_at`, p.`private`, p.`status` AS `profile_status`, "
        .. author .. media_columns,
    "JOIN `sky_phone_picstagram_profiles` p ON p.`id` = r.`profile_id`" .. media_join,
    function(row) return active_story(row) and public_profile(row) end)
entity("fliptok", "sky_phone_fliptok_videos", "r.`caption` AS `body`, r.`location`, r.`status`, r.`visibility`, " .. author,
    "JOIN `sky_phone_fliptok_profiles` p ON p.`id` = r.`profile_id`",
    function(row) return published(row) and row.visibility == "public" end,
    "sky_phone_fliptok_video_media", "video_id")
entity("skypic-story", "sky_phone_skypic_stories",
    "r.`caption` AS `body`, r.`status`, r.`privacy`, UNIX_TIMESTAMP(r.`expires_at`) AS `expires_at`, "
        .. "p.`status` AS `profile_status`, " .. author .. media_columns,
    "JOIN `sky_phone_skypic_profiles` p ON p.`id` = r.`profile_id`" .. media_join,
    function(row) return active_story(row) and row.profile_status == "active" and row.privacy == "everyone" end)
entity("skypic-spotlight", "sky_phone_skypic_spotlights",
    "r.`caption` AS `body`, r.`ad_headline` AS `title`, r.`status`, UNIX_TIMESTAMP(r.`expires_at`) AS `expires_at`, "
        .. "p.`status` AS `profile_status`, " .. author .. media_columns,
    "JOIN `sky_phone_skypic_profiles` p ON p.`id` = r.`profile_id`" .. media_join,
    function(row) return active_story(row) and row.profile_status == "active" end)
entity("weazel", "sky_phone_weazel_articles",
    "r.`title`, r.`excerpt` AS `body`, r.`category`, r.`author_name`, r.`status`, r.`deleted_at`",
    "", function(row) return published(row) and row.deleted_at == nil end,
    "sky_phone_weazel_article_media", "article_id", "position")

local function add(category, label, color, names, entity_key, status)
    for name in names:gmatch("%S+") do
        assert(SkyPhoneLog.Actions[name], "Public announcement needs an audited mutation: " .. name)
        SkyPhoneLog.PublicActions[name] = { category = category, label = label, color = color,
            entity = entities[entity_key], status = status or "published" }
    end
end
add("Feather", "Feather", 1942002, "feather:create-post", "feather")
add("Pages", "Local Pages", 3447003, "pages:create pages:share-citymarkt", "pages")
add("Marketplace", "CityMarkt", 3066993, "marketplace:create", "marketplace")
add("Marketplace", "CityMarkt", 3066993, "marketplace:update", "marketplace", "updated")
add("Marketplace", "CityMarkt", 3066993, "marketplace:set-status", "marketplace", "availability")
add("Picstagram", "Picstagram", 15277667, "picstagram:publish-post picstagram:set-post-status", "picstagram-post")
add("Picstagram", "Picstagram", 15277667, "picstagram:update-post", "picstagram-post", "updated")
add("Picstagram", "Picstagram", 15277667, "picstagram:publish-story", "picstagram-story", "story")
add("FlipTok", "FlipTok", 1752220, "fliptok:publish", "fliptok")
add("SkyPic", "SkyPic", 16705372, "skypic:publish-story", "skypic-story", "story")
add("SkyPic", "SkyPic", 16705372, "skypic:publish-spotlight", "skypic-spotlight")
add("WeazelNews", "Weazel News", 15158332, "weazel-news:create", "weazel")
add("WeazelNews", "Weazel News", 15158332, "weazel-news:update", "weazel", "updated")

function SkyPhoneLog.AnnouncePublic(action, data, response)
    local spec = SkyPhoneLog.PublicActions[action]
    if not spec or not SkyPhoneLog.IsPublicEnabled(action) then return false end
    local output = type(response.data) == "table" and response.data or {}
    local article = type(output.article) == "table" and output.article or {}
    local id = output.id or article.id or data.id
    if type(id) ~= "string" or #id < 1 or #id > 64 then return false end
    local rows = Bridge.Database.Query(spec.entity.query, { id })
    local row = type(rows) == "table" and rows[1]
    if not row or not spec.entity.visible(row) then return false end
    -- Explicit projection: even an extra column in a future query cannot expose
    -- account IDs, IMEIs, private snapshots, reports or direct messages.
    local post = { id = row.id, status = spec.status }
    for key in ("title body author_name author_handle author_avatar category district location"):gmatch("%S+") do post[key] = row[key] end
    if spec.status == "availability" then post.status = row.status end
    if spec.category == "Marketplace" then
        local currency = Config and Config.Marketplace and Config.Marketplace.Currency or "$"
        local locale = Config and Config.Bridge and Config.Bridge.Locale or "en"
        local labels = Locales and (Locales[locale] or Locales.en)
        labels = labels and labels.DiscordPublic or {}
        post.price = row.price_type == "free" and (labels.free or "Free")
            or currency .. tostring(tonumber(row.price) or 0)
                .. (row.price_type == "negotiable" and (" (" .. (labels.negotiable or "Negotiable") .. ")") or "")
    end
    if spec.entity.media then post.media = Bridge.Database.Query(spec.entity.media, { id })
    elseif row.media_url then post.media = {{ url = row.media_url, media_type = row.media_type,
        mime_type = row.mime_type }} end
    return SkyPhoneLog.Publish(action, post)
end
