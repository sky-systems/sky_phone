-- Persisted content complements accepted request fields. All table/column names
-- below are server-owned constants. Only IDs are supplied as SQL parameters.
local entities = {}
local function entity(name, table_name, media_column, attachment_table, attachment_key)
    local select = "record.*"
    local joins = ""
    if media_column then
        select = select .. ", media.`url` AS `media_url`, media.`media_type` AS `media_type`"
        joins = (" LEFT JOIN `sky_phone_media` media ON media.`id` = record.`%s`"):format(media_column)
    end
    entities[name] = {
        query = ("SELECT %s FROM `%s` record%s WHERE record.`id` IN (%%s) LIMIT 101"):format(select, table_name, joins),
        attachments = attachment_table and ("SELECT attachment.*, media.`url`, media.`media_type` FROM `%s` attachment "
            .. "LEFT JOIN `sky_phone_media` media ON media.`id` = attachment.`media_id` "
            .. "WHERE attachment.`%s` IN (%%s) LIMIT 101"):format(attachment_table, attachment_key) or nil,
    }
end

entity("feather-post", "sky_phone_feather_posts", nil, "sky_phone_feather_post_media", "post_id")
entity("picstagram-post", "sky_phone_picstagram_posts", nil, "sky_phone_picstagram_post_media", "post_id")
entity("picstagram-comment", "sky_phone_picstagram_comments")
entity("picstagram-story", "sky_phone_picstagram_stories", "media_id")
entity("fliptok-video", "sky_phone_fliptok_videos", nil, "sky_phone_fliptok_video_media", "video_id")
entity("fliptok-comment", "sky_phone_fliptok_comments")
entity("pages-post", "sky_phone_pages_posts", nil, "sky_phone_pages_images", "post_id")
entity("marketplace-listing", "sky_phone_marketplace_listings", nil, "sky_phone_marketplace_images", "listing_id")
entity("sms", "sky_phone_sms_messages")
entity("darkchat-message", "sky_phone_darkchat_messages")
entity("flare-message", "sky_phone_flare_messages")
entity("memo", "sky_phone_voice_memos", "media_id")
entity("note", "sky_phone_notes")
entity("calendar-event", "sky_phone_calendar_events")
entity("contact", "sky_phone_contacts", "avatar_media_id")
entities.contact.query = entities.contact.query:gsub("record%.`id` IN", "record.`contact_id` IN")
entity("mail-draft", "sky_phone_mail_drafts")
entity("weazel-article", "sky_phone_weazel_articles", nil, "sky_phone_weazel_article_media", "article_id")
entity("skypic-message", "sky_phone_skypic_messages", "media_id")
entity("skypic-story", "sky_phone_skypic_stories", "media_id")
entity("skypic-spotlight", "sky_phone_skypic_spotlights", "media_id")
entity("skypic-comment", "sky_phone_skypic_spotlight_comments")
entities["mail-entry"] = {
    query = [[SELECT entry.*, message.`subject`, message.`body`, message.`recipients`, message.`sender_account_id`
        FROM `sky_phone_mail_entries` entry
        JOIN `sky_phone_mail_messages` message ON message.`id` = entry.`message_id`
        WHERE entry.`id` IN (%s) LIMIT 101]],
}

local function ids_for(value)
    local values = type(value) == "table" and value or { value }
    local ids, placeholders = {}, {}
    for _, item in ipairs(values) do
        local id = type(item) == "table" and item.id or item
        if (type(id) == "string" and #id > 0 and #id <= 64)
            or (type(id) == "number" and id > 0 and id < 2 ^ 53 and id == math.floor(id)) then
            ids[#ids + 1] = id
            placeholders[#placeholders + 1] = "?"
        end
        if #ids >= 100 then break end
    end
    return ids, table.concat(placeholders, ", ")
end

local function read_content(name, value, actor)
    local definition = assert(entities[name], "Unknown audit content entity")
    local ids, placeholders = ids_for(value)
    if #ids == 0 then return nil end
    local rows = Bridge.Database.Query(definition.query:format(placeholders), ids)
    if actor and (name == "note" or name == "calendar-event" or name == "contact"
        or name == "mail-entry" or name == "mail-draft") then
        local owned = {}
        for _, row in ipairs(rows) do
            if (actor.accountId and tonumber(row.account_id) == tonumber(actor.accountId))
                or (row.account_id == nil and row.device_imei == actor.imei) then
                owned[#owned + 1] = row
            end
        end
        rows = owned
    end
    for _, row in ipairs(rows) do
        -- Voice data is binary and is never sent to Discord. Other attachments
        -- are structured metadata (URL, contact or shared post), kept as JSON.
        if type(row.media_payload) == "string" and row.message_type ~= "voice" then
            local ok, attachment = pcall(json.decode, row.media_payload)
            if ok and type(attachment) == "table" then row.attachment = attachment end
        end
    end
    local content = { records = rows }
    if definition.attachments then
        content.media = Bridge.Database.Query(definition.attachments:format(placeholders), ids)
    end
    if #rows >= 101 or (content.media and #content.media >= 101) then
        content.logLimit = "First 101 rows shown; additional content omitted"
    end
    return content
end

local function attach(action_names, name, input_field, before, output_id)
    for action in action_names:gmatch("%S+") do
        local spec = assert(SkyPhoneLog.Actions[action], "Missing audit action " .. action)
        if before then
            spec.before = function(_, data, actor)
                return read_content(name, data[input_field or "id"], actor)
            end
        end
        spec.enrich = function(source, data, response, details)
            local id = data[input_field or "id"]
            if output_id then
                local output = response.data
                id = type(output) == "table" and (output.id or output) or output
            end
            local actor = SkyPhone and SkyPhone.GetLogIdentity and SkyPhone.GetLogIdentity(source)
            details.content = read_content(name, id, actor)
        end
    end
end

attach("feather:create-post", "feather-post", nil, false, true)
attach("feather:delete", "feather-post", "id", true)
attach("picstagram:publish-post", "picstagram-post", nil, false, true)
attach("picstagram:update-post picstagram:set-post-status", "picstagram-post", "id", true)
attach("picstagram:comment", "picstagram-comment", nil, false, true)
attach("picstagram:remove-comment", "picstagram-comment", "id", true)
attach("picstagram:publish-story", "picstagram-story", nil, false, true)
attach("picstagram:remove-story", "picstagram-story", "id", true)
attach("fliptok:publish", "fliptok-video", nil, false, true)
attach("fliptok:delete", "fliptok-video", "id", true)
attach("fliptok:comment", "fliptok-comment", nil, false, true)
attach("pages:create pages:share-citymarkt", "pages-post", nil, false, true)
attach("pages:delete", "pages-post", "id", true)
attach("marketplace:create", "marketplace-listing", nil, false, true)
attach("marketplace:update marketplace:set-status", "marketplace-listing", "id", true)
attach("messages:send", "sms", nil, false, true)
attach("darkchat:send", "darkchat-message", nil, false, true)
attach("darkchat:message-action", "darkchat-message", "messageId", true)
attach("flare:send", "flare-message", nil, false, true)
attach("memos:update memos:delete", "memo", "id", true)
attach("notes:update notes:delete", "note", "id", true)
attach("calendar:create", "calendar-event", nil, false, true)
attach("calendar:update calendar:delete", "calendar-event", "id", true)
attach("contacts:save contacts:delete", "contact", "id", true)
attach("mail:save-draft mail:delete-draft", "mail-draft", "id", true)
attach("mail:trash mail:restore mail:move mail:delete-forever", "mail-entry", "id", true)
attach("weazel-news:create", "weazel-article", nil, false, true)
attach("weazel-news:update weazel-news:delete", "weazel-article", "id", true)

attach("skypic:send-message skypic:send-snap", "skypic-message", nil, false, true)
attach("skypic:save-message skypic:delete-message", "skypic-message", "messageId", true)
attach("skypic:open-snap skypic:replay-snap", "skypic-message", "snapId")
attach("skypic:publish-story", "skypic-story", nil, false, true)
attach("skypic:remove-story", "skypic-story", "storyId", true)
attach("skypic:publish-spotlight", "skypic-spotlight", nil, false, true)
attach("skypic:remove-spotlight", "skypic-spotlight", "spotlightId", true)
attach("skypic:comment-spotlight", "skypic-comment", nil, false, true)
attach("skypic:delete-spotlight-comment", "skypic-comment", "commentId", true)

-- Bulk deletes have no individual content IDs in the response. Capture only
-- the authenticated account/SIM's rows, with an explicit finite preview limit.
SkyPhoneLog.Actions["mail:delete-many"].before = function(_, data, actor)
    if data.folder == "drafts" then return read_content("mail-draft", data.ids, actor) end
    local content = read_content("mail-entry", data.ids)
    if content then
        local owned = {}
        for _, row in ipairs(content.records) do
            if tonumber(row.account_id) == tonumber(actor.accountId) then owned[#owned + 1] = row end
        end
        content.records = owned
    end
    return content
end
SkyPhoneLog.Actions["mail:empty-trash"].before = function(_, _, actor)
    if not actor.accountId then return nil end
    local rows = Bridge.Database.Query([[
        SELECT entry.`id`, entry.`message_id`, message.`subject`, message.`body`, message.`recipients`
        FROM `sky_phone_mail_entries` entry
        JOIN `sky_phone_mail_messages` message ON message.`id` = entry.`message_id`
        WHERE entry.`account_id` = ? AND entry.`trashed_at` IS NOT NULL
        ORDER BY entry.`id` LIMIT 101
    ]], { actor.accountId })
    return { records = rows, logLimit = #rows >= 101 and "First 101 rows shown; additional content may be omitted" or nil }
end
SkyPhoneLog.Actions["skypic:delete-account"].before = function(_, _, actor)
    if not actor.accountId then return nil end
    return Bridge.Database.Query("SELECT * FROM `sky_phone_skypic_profiles` WHERE `account_id` = ? LIMIT 1", { actor.accountId })
end

-- Do not repeat entire lists/bootstrap responses for small mutations.
for _, action in ipairs({ "notes:create", "notes:update", "notes:delete", "calendar:delete",
    "memos:delete", "darkchat:create-profile", "darkchat:update-profile", "darkchat:start" }) do
    SkyPhoneLog.Actions[action].result = false
end
