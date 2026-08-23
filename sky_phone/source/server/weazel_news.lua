Bridge.Database.AfterMigration("sky_phone", function()
local config = Config.WeazelNews

if type(config) ~= "table" then
    error("[sky_phone] Config.WeazelNews must be configured.")
end

local function require_integer_config(name, minimum, maximum)
    local value = config[name]
    if type(value) ~= "number" or value ~= math.floor(value) or value < minimum or value > maximum then
        error(("[sky_phone] Config.WeazelNews.%s must be an integer between %d and %d."):format(name, minimum, maximum))
    end
end

if type(config.Enabled) ~= "boolean" then
    error("[sky_phone] Config.WeazelNews.Enabled must be true or false.")
end
require_integer_config("PageSize", 1, 100)
require_integer_config("MaximumOffset", 0, 1000000)
require_integer_config("MaximumImages", 1, 6)
require_integer_config("SearchMaxLength", 1, 256)
require_integer_config("DraftTitleMinLength", 1, 160)
require_integer_config("DraftBodyMinLength", 1, 12000)
require_integer_config("TitleMinLength", 1, 160)
require_integer_config("TitleMaxLength", 1, 160)
require_integer_config("BodyMinLength", 1, 12000)
require_integer_config("BodyMaxLength", 1, 12000)
require_integer_config("ExcerptMaxLength", 1, 240)
if config.DraftTitleMinLength > config.TitleMaxLength
    or config.DraftBodyMinLength > config.BodyMaxLength
    or config.TitleMinLength > config.TitleMaxLength
    or config.BodyMinLength > config.BodyMaxLength
then
    error("[sky_phone] Weazel News minimum text lengths cannot exceed their maximums.")
end
if type(config.RateLimits) ~= "table" then
    error("[sky_phone] Config.WeazelNews.RateLimits must be a table.")
end
for _, name in ipairs({ "Read", "Write" }) do
    local value = config.RateLimits[name]
    if type(value) ~= "number" or value ~= math.floor(value) or value < 1 or value > 10000 then
        error(("[sky_phone] Config.WeazelNews.RateLimits.%s must be an integer between 1 and 10000."):format(name))
    end
end

local supported_categories = {
    official = true,
    events = true,
    jobs = true,
    news = true,
    business = true,
}
if type(config.Categories) ~= "table" then
    error("[sky_phone] Config.WeazelNews.Categories must be a table.")
end

local categories = {}

local function refresh_categories()
    local next_categories = {}
    for _, category in ipairs(config.Categories or {}) do
        if type(category) ~= "string" or #category < 1 or #category > 32
            or not category:match("^[%l_]+$") or next_categories[category]
        then
            error(("[sky_phone] Invalid Weazel News category '%s'."):format(tostring(category)))
        end
        next_categories[category] = true
    end
    for category in pairs(supported_categories) do
        if not next_categories[category] then
            error(("[sky_phone] Config.WeazelNews.Categories is missing supported category '%s'."):format(category))
        end
    end
    for category in pairs(next_categories) do
        if not supported_categories[category] then
            error(("[sky_phone] Config.WeazelNews.Categories contains unsupported category '%s'."):format(category))
        end
    end
    categories = next_categories
end

refresh_categories()

AddEventHandler("sky_phone:configurator:serverUpdated", function()
    refresh_categories()
end)

if type(config.AllowedJobs) ~= "table" then
    error("[sky_phone] Config.WeazelNews.AllowedJobs must be a table.")
end

for job_name, minimum_grade in pairs(config.AllowedJobs or {}) do
    if type(job_name) ~= "string" or #job_name < 1 or #job_name > 64
        or not job_name:match("^[%w_-]+$")
        or type(minimum_grade) ~= "number" or minimum_grade < 0
        or minimum_grade ~= math.floor(minimum_grade)
    then
        error(("[sky_phone] Invalid Weazel News AllowedJobs entry '%s'."):format(tostring(job_name)))
    end
end

local article_summary_columns = [[
    article.`id`, article.`title`, article.`excerpt`, article.`category`,
    article.`image_media_id`, media.`url` AS `image_url`, article.`author_name`,
    article.`status`, article.`revision`,
    UNIX_TIMESTAMP(article.`created_at`) AS `created_at_unix`,
    UNIX_TIMESTAMP(article.`updated_at`) AS `updated_at_unix`,
    UNIX_TIMESTAMP(article.`published_at`) AS `published_at_unix`
]]
local article_detail_columns = article_summary_columns .. ", article.`body`"

local function trim(value)
    if type(value) ~= "string" then
        return nil
    end
    return value:match("^%s*(.-)%s*$")
end

local function text_length(value)
    if type(value) ~= "string" then
        return nil
    end
    local success, length = pcall(utf8.len, value)
    return success and length or nil
end

local function truncate_text(value, maximum)
    local length = text_length(value)
    if not length or length <= maximum then
        return value
    end
    local next_character = utf8.offset(value, maximum + 1)
    return next_character and value:sub(1, next_character - 1) or value
end

local function make_excerpt(body)
    return truncate_text(body:gsub("%s+", " "), config.ExcerptMaxLength)
end

local function valid_integer(value, minimum, maximum)
    local number = type(value) == "number" and value or nil
    if not number or number ~= math.floor(number) or number < minimum or number > maximum then
        return nil
    end
    return number
end

local function valid_uuid(value)
    return type(value) == "string"
        and value:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

local function affected_rows(result)
    if type(result) == "number" then
        return result
    end
    return type(result) == "table" and tonumber(result.affectedRows) or 0
end

local function require_phone(source, operation, maximum)
    if not config.Enabled then
        return nil, { success = false, error = "feature_disabled" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return nil, error_response
    end
    if not SkyPhone.AllowOperation(source, "weazel_" .. operation, maximum, 60) then
        return nil, { success = false, error = "rate_limited" }
    end
    return session
end

local function management_access(source)
    local job = Bridge.Framework.GetJob(source)
    local minimum_grade = (config.AllowedJobs or {})[job.name]
    local grade = tonumber(job.grade) or 0
    if minimum_grade == nil or grade < minimum_grade then
        return nil
    end
    return {
        job_label = type(job.label) == "string" and job.label or "",
        grade_label = type(job.gradeLabel) == "string" and job.gradeLabel or "",
    }
end

local function require_manager(source)
    local access = management_access(source)
    if not access then
        return nil, { success = false, error = "not_authorized" }
    end
    return access
end

local function actor_identity(source)
    local identifier = Bridge.Framework.GetIdentifier(source)
    if type(identifier) ~= "string" or #identifier < 1 or #identifier > 80 then
        Bridge.Debug("error", "[sky_phone] Could not resolve a valid Weazel News actor for source %s.", tostring(source))
        return nil
    end

    local first_name = trim(Bridge.Framework.GetFirstname(source)) or ""
    local last_name = trim(Bridge.Framework.GetLastname(source)) or ""
    local name = trim((first_name .. " " .. last_name))
    if not name or name == "" then
        name = trim(GetPlayerName(source)) or "Weazel News"
    end
    if not text_length(name) then
        name = "Weazel News"
    end
    return {
        identifier = identifier,
        name = truncate_text(name, 120),
    }
end

local function article_dto(row)
    if not row then
        return nil
    end
    local created_at = tonumber(row.created_at_unix)
    local updated_at = tonumber(row.updated_at_unix)
    if not created_at or not updated_at then
        error(("[sky_phone] Weazel News article '%s' has invalid timestamps."):format(tostring(row.id)))
    end
    return {
        id = row.id,
        title = row.title,
        body = row.body,
        excerpt = row.excerpt,
        category = row.category,
        imageUrl = row.image_url,
        imageMediaId = row.image_media_id and tonumber(row.image_media_id) or nil,
        images = {},
        authorName = row.author_name,
        createdAt = created_at * 1000,
        updatedAt = updated_at * 1000,
        publishedAt = row.published_at_unix and tonumber(row.published_at_unix) * 1000 or nil,
        status = row.status,
        revision = tonumber(row.revision) or 1,
    }
end

local function attach_article_images(articles)
    if #articles < 1 then
        return articles
    end

    local placeholders = {}
    local article_ids = {}
    local articles_by_id = {}
    for index, article in ipairs(articles) do
        placeholders[index] = "?"
        article_ids[index] = article.id
        article.images = {}
        articles_by_id[article.id] = article
    end

    local rows = Bridge.Database.Query(([[
        SELECT relation.`article_id`, relation.`media_id`, relation.`position`, media.`url`
        FROM `sky_phone_weazel_article_media` relation
        JOIN `sky_phone_media` media
            ON media.`id` = relation.`media_id` AND media.`media_type` = 'photo'
        WHERE relation.`article_id` IN (%s)
        ORDER BY relation.`article_id`, relation.`position`, relation.`id`
    ]]):format(table.concat(placeholders, ", ")), article_ids)
    for _, row in ipairs(rows) do
        local article = articles_by_id[row.article_id]
        local media_id = tonumber(row.media_id)
        if article and media_id and type(row.url) == "string" then
            article.images[#article.images + 1] = {
                mediaId = media_id,
                url = row.url,
            }
        end
    end

    for _, article in ipairs(articles) do
        if #article.images < 1 and article.imageMediaId and article.imageUrl then
            article.images[1] = {
                mediaId = article.imageMediaId,
                url = article.imageUrl,
            }
        end
        local cover = article.images[1]
        article.imageMediaId = cover and cover.mediaId or nil
        article.imageUrl = cover and cover.url or nil
    end
    return articles
end

local function load_article(id, include_drafts)
    local visibility = include_drafts and "" or " AND article.`status` = 'published'"
    local rows = Bridge.Database.Query(([[
        SELECT %s
        FROM `sky_phone_weazel_articles` article
        LEFT JOIN `sky_phone_media` media ON media.`id` = article.`image_media_id`
        WHERE article.`id` = ? AND article.`deleted_at` IS NULL%s
        LIMIT 1
    ]]):format(article_detail_columns, visibility), { id })
    local article = article_dto(rows[1])
    return article and attach_article_images({ article })[1] or nil
end

local function query_articles(where_clause, parameters, order_clause, offset)
    local query_parameters = {}
    for _, value in ipairs(parameters) do
        query_parameters[#query_parameters + 1] = value
    end
    query_parameters[#query_parameters + 1] = config.PageSize + 1
    query_parameters[#query_parameters + 1] = offset

    local rows = Bridge.Database.Query(([[
        SELECT %s
        FROM `sky_phone_weazel_articles` article
        LEFT JOIN `sky_phone_media` media ON media.`id` = article.`image_media_id`
        WHERE %s
        ORDER BY %s
        LIMIT ? OFFSET ?
    ]]):format(article_summary_columns, where_clause, order_clause), query_parameters)
    local has_more = #rows > config.PageSize
    if has_more then
        rows[#rows] = nil
    end
    local articles = {}
    for _, row in ipairs(rows) do
        articles[#articles + 1] = article_dto(row)
    end
    return attach_article_images(articles), has_more
end

local function validate_article_media(source, data, retained_media_ids)
    local values = data.imageMediaIds
    if values == nil then
        values = data.imageMediaId ~= nil and { data.imageMediaId } or {}
    end
    if type(values) ~= "table" or #values > config.MaximumImages then
        return nil
    end
    for key in pairs(values) do
        if type(key) ~= "number" or key < 1 or key > #values or key ~= math.floor(key) then
            return nil
        end
    end

    local media_ids = {}
    local seen = {}
    for index, value in ipairs(values) do
        local media_id = valid_integer(value, 1, 9007199254740991)
        if not media_id or seen[media_id] then
            return nil
        end
        if not retained_media_ids[media_id]
            and not SkyPhoneMedia.ResolveOwnedMedia(source, tostring(media_id), "photo")
        then
            return nil
        end
        seen[media_id] = true
        media_ids[index] = media_id
    end
    return media_ids
end

local function validate_article(source, data, retained_media_ids)
    if type(data) ~= "table" then
        return nil, "invalid_article"
    end
    local title = trim(data.title)
    local body = trim(data.body)
    local title_length = text_length(title)
    local body_length = text_length(body)
    local status = data.status
    local minimum_title_length = status == "draft" and config.DraftTitleMinLength or config.TitleMinLength
    local minimum_body_length = status == "draft" and config.DraftBodyMinLength or config.BodyMinLength
    if not title_length or title:find("%z") or title_length < minimum_title_length or title_length > config.TitleMaxLength
        or not body_length or body:find("%z")
        or body_length < minimum_body_length or body_length > config.BodyMaxLength
        or not categories[data.category]
        or (status ~= "draft" and status ~= "published")
    then
        return nil, status == "draft" and "invalid_draft" or "invalid_publish"
    end

    local media_ids = validate_article_media(source, data, retained_media_ids or {})
    if not media_ids then
        return nil, "invalid_attachment"
    end
    return {
        title = title,
        body = body,
        excerpt = make_excerpt(body),
        category = data.category,
        image_media_id = media_ids[1],
        image_media_ids = media_ids,
        status = status,
    }
end

local function article_matches(article, expected, revision)
    if not article or article.revision ~= revision
        or article.title ~= expected.title
        or article.body ~= expected.body
        or article.excerpt ~= expected.excerpt
        or article.category ~= expected.category
        or article.status ~= expected.status
        or #article.images ~= #expected.image_media_ids
    then
        return false
    end
    for index, media_id in ipairs(expected.image_media_ids) do
        if article.images[index].mediaId ~= media_id then
            return false
        end
    end
    return true
end

Bridge.Callbacks.Register("sky_phone:weazel-news:context", function(source)
    local _, error_response = require_phone(source, "read", config.RateLimits.Read)
    if error_response then
        return error_response
    end
    local access = management_access(source)
    local counts = Bridge.Database.Query([[
        SELECT `category`, COUNT(*) AS `count`
        FROM `sky_phone_weazel_articles`
        WHERE `status` = 'published' AND `deleted_at` IS NULL
        GROUP BY `category`
    ]], {})
    local counts_by_category = {}
    for _, row in ipairs(counts) do
        counts_by_category[row.category] = tonumber(row.count) or 0
    end
    local category_context = {}
    for _, category in ipairs(config.Categories) do
        category_context[#category_context + 1] = {
            id = category,
            count = counts_by_category[category] or 0,
        }
    end
    return {
        success = true,
        data = {
            canManage = access ~= nil,
            jobLabel = access and access.job_label or nil,
            jobGradeLabel = access and access.grade_label or nil,
            categories = category_context,
            maximumImages = config.MaximumImages,
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:weazel-news:list", function(source, data)
    local _, error_response = require_phone(source, "read", config.RateLimits.Read)
    if error_response then
        return error_response
    end
    if type(data) ~= "table" then
        return { success = false, error = "invalid_request" }
    end
    local offset = valid_integer(data.offset or 0, 0, config.MaximumOffset)
    local search = trim(data.search or "")
    local search_length = text_length(search)
    if not offset or not search_length or search_length > config.SearchMaxLength
        or (data.category ~= nil and not categories[data.category])
    then
        return { success = false, error = "invalid_request" }
    end

    local where = { "article.`status` = 'published'", "article.`deleted_at` IS NULL" }
    local parameters = {}
    if data.category then
        where[#where + 1] = "article.`category` = ?"
        parameters[#parameters + 1] = data.category
    end
    if search ~= "" then
        where[#where + 1] = "(article.`title` LIKE CONCAT('%', ?, '%') OR article.`body` LIKE CONCAT('%', ?, '%'))"
        parameters[#parameters + 1] = search
        parameters[#parameters + 1] = search
    end
    local items, has_more = query_articles(
        table.concat(where, " AND "),
        parameters,
        "article.`published_at` DESC, article.`id` DESC",
        offset
    )
    return { success = true, data = { items = items, hasMore = has_more } }
end)

Bridge.Callbacks.Register("sky_phone:weazel-news:get", function(source, data)
    local _, error_response = require_phone(source, "read", config.RateLimits.Read)
    if error_response then
        return error_response
    end
    if type(data) ~= "table" or not valid_uuid(data.id) then
        return { success = false, error = "invalid_request" }
    end
    local include_drafts = data.manage == true
    if include_drafts then
        local _, manager_error = require_manager(source)
        if manager_error then
            return manager_error
        end
    end
    local article = load_article(data.id, include_drafts)
    if not article then
        return { success = false, error = "not_found" }
    end
    return { success = true, data = { article = article } }
end)

Bridge.Callbacks.Register("sky_phone:weazel-news:manage-list", function(source, data)
    local _, error_response = require_phone(source, "read", config.RateLimits.Read)
    if error_response then
        return error_response
    end
    local _, manager_error = require_manager(source)
    if manager_error then
        return manager_error
    end
    if type(data) ~= "table" then
        return { success = false, error = "invalid_request" }
    end
    local status = data.status or "all"
    local offset = valid_integer(data.offset or 0, 0, config.MaximumOffset)
    local search = trim(data.search or "")
    local search_length = text_length(search)
    if (status ~= "all" and status ~= "published" and status ~= "draft") or not offset
        or not search_length or search_length > config.SearchMaxLength
    then
        return { success = false, error = "invalid_request" }
    end
    local where = { "article.`deleted_at` IS NULL" }
    local parameters = {}
    if status ~= "all" then
        where[#where + 1] = "article.`status` = ?"
        parameters[#parameters + 1] = status
    end
    if search ~= "" then
        where[#where + 1] = "(article.`title` LIKE CONCAT('%', ?, '%') OR article.`body` LIKE CONCAT('%', ?, '%'))"
        parameters[#parameters + 1] = search
        parameters[#parameters + 1] = search
    end
    local items, has_more = query_articles(
        table.concat(where, " AND "),
        parameters,
        "article.`updated_at` DESC, article.`id` DESC",
        offset
    )
    return { success = true, data = { items = items, hasMore = has_more } }
end)

Bridge.Callbacks.Register("sky_phone:weazel-news:create", function(source, data)
    local _, error_response = require_phone(source, "write", config.RateLimits.Write)
    if error_response then
        return error_response
    end
    local _, manager_error = require_manager(source)
    if manager_error then
        return manager_error
    end
    local article, validation_error = validate_article(source, data)
    if not article then
        return { success = false, error = validation_error }
    end
    local actor = actor_identity(source)
    if not actor then
        return { success = false, error = "request_failed" }
    end
    local ids = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    local id = ids[1] and ids[1].id
    if not valid_uuid(id) then
        error("[sky_phone] Database did not generate a Weazel News article id.")
    end
    local statements = {{
        query = [[
            INSERT INTO `sky_phone_weazel_articles`
                (`id`, `title`, `body`, `excerpt`, `category`, `image_media_id`, `author_identifier`,
                    `author_name`, `updated_by_identifier`, `status`, `published_at`)
            VALUES (?, ?, ?, ?, ?, NULLIF(?, 0), ?, ?, ?, ?, IF(? = 'published', CURRENT_TIMESTAMP, NULL))
        ]],
        params = {
            id,
            article.title,
            article.body,
            article.excerpt,
            article.category,
            article.image_media_id or 0,
            actor.identifier,
            actor.name,
            actor.identifier,
            article.status,
            article.status,
        },
    }}
    for position, media_id in ipairs(article.image_media_ids) do
        statements[#statements + 1] = {
            query = [[
                INSERT INTO `sky_phone_weazel_article_media` (`article_id`, `media_id`, `position`)
                VALUES (?, ?, ?)
            ]],
            params = { id, media_id, position },
        }
    end
    if not Bridge.Database.Transaction(statements) then
        return { success = false, error = "request_failed" }
    end
    local created = load_article(id, true)
    if not created then
        error(("[sky_phone] Could not reload created Weazel News article '%s'."):format(id))
    end
    return { success = true, data = { article = created } }
end)

Bridge.Callbacks.Register("sky_phone:weazel-news:update", function(source, data)
    local _, error_response = require_phone(source, "write", config.RateLimits.Write)
    if error_response then
        return error_response
    end
    local _, manager_error = require_manager(source)
    if manager_error then
        return manager_error
    end
    local revision = type(data) == "table" and valid_integer(data.revision, 1, 4294967295) or nil
    if not revision or not valid_uuid(data.id) then
        return { success = false, error = "invalid_request" }
    end
    local current_rows = Bridge.Database.Query([[
        SELECT `image_media_id`, `revision`
        FROM `sky_phone_weazel_articles`
        WHERE `id` = ? AND `deleted_at` IS NULL
        LIMIT 1
    ]], { data.id })
    local current = current_rows[1]
    if not current then
        return { success = false, error = "not_found" }
    end
    if tonumber(current.revision) ~= revision then
        return { success = false, error = "revision_conflict" }
    end
    local retained_media_ids = {}
    local retained_cover_id = current.image_media_id and tonumber(current.image_media_id) or nil
    if retained_cover_id then
        retained_media_ids[retained_cover_id] = true
    end
    local retained_rows = Bridge.Database.Query([[
        SELECT `media_id`
        FROM `sky_phone_weazel_article_media`
        WHERE `article_id` = ?
    ]], { data.id })
    for _, row in ipairs(retained_rows) do
        local media_id = tonumber(row.media_id)
        if media_id then
            retained_media_ids[media_id] = true
        end
    end
    local article, validation_error = validate_article(source, data, retained_media_ids)
    if not article then
        return { success = false, error = validation_error }
    end
    local actor = actor_identity(source)
    if not actor then
        return { success = false, error = "request_failed" }
    end
    local mutation_rows = Bridge.Database.Query("SELECT UUID() AS `id`", {})
    local mutation_id = mutation_rows[1] and mutation_rows[1].id
    if not valid_uuid(mutation_id) then
        error("[sky_phone] Database did not generate a Weazel News mutation id.")
    end
    local mutation_token = "weazel:" .. mutation_id
    local next_revision = revision + 1
    local statements = {
        {
            query = [[
                UPDATE `sky_phone_weazel_articles`
                SET `title` = ?, `body` = ?, `excerpt` = ?, `category` = ?,
                    `image_media_id` = NULLIF(?, 0),
                    `published_at` = CASE
                        WHEN ? = 'draft' THEN NULL
                        WHEN `status` = 'draft' THEN CURRENT_TIMESTAMP
                        ELSE `published_at`
                    END,
                    `status` = ?, `updated_by_identifier` = ?, `revision` = `revision` + 1
                WHERE `id` = ? AND `revision` = ? AND `deleted_at` IS NULL
            ]],
            params = {
                article.title,
                article.body,
                article.excerpt,
                article.category,
                article.image_media_id or 0,
                article.status,
                article.status,
                mutation_token,
                data.id,
                revision,
            },
        },
        {
            query = [[
                DELETE relation
                FROM `sky_phone_weazel_article_media` relation
                JOIN `sky_phone_weazel_articles` article ON article.`id` = relation.`article_id`
                WHERE article.`id` = ? AND article.`revision` = ?
                    AND article.`updated_by_identifier` = ?
            ]],
            params = { data.id, next_revision, mutation_token },
        },
    }
    for position, media_id in ipairs(article.image_media_ids) do
        statements[#statements + 1] = {
            query = [[
                INSERT INTO `sky_phone_weazel_article_media` (`article_id`, `media_id`, `position`)
                SELECT article.`id`, ?, ?
                FROM `sky_phone_weazel_articles` article
                WHERE article.`id` = ? AND article.`revision` = ?
                    AND article.`updated_by_identifier` = ? AND article.`deleted_at` IS NULL
            ]],
            params = { media_id, position, data.id, next_revision, mutation_token },
        }
    end
    statements[#statements + 1] = {
        query = [[
            UPDATE `sky_phone_weazel_articles`
            SET `updated_by_identifier` = ?
            WHERE `id` = ? AND `revision` = ? AND `updated_by_identifier` = ?
        ]],
        params = { actor.identifier, data.id, next_revision, mutation_token },
    }
    if not Bridge.Database.Transaction(statements) then
        return { success = false, error = "request_failed" }
    end
    local updated = load_article(data.id, true)
    if not updated then
        return { success = false, error = "not_found" }
    end
    if not article_matches(updated, article, next_revision) then
        return { success = false, error = "revision_conflict" }
    end
    return { success = true, data = { article = updated } }
end)

Bridge.Callbacks.Register("sky_phone:weazel-news:delete", function(source, data)
    local _, error_response = require_phone(source, "write", config.RateLimits.Write)
    if error_response then
        return error_response
    end
    local _, manager_error = require_manager(source)
    if manager_error then
        return manager_error
    end
    local revision = type(data) == "table" and valid_integer(data.revision, 1, 4294967295) or nil
    if not revision or not valid_uuid(data.id) then
        return { success = false, error = "invalid_request" }
    end
    local actor = actor_identity(source)
    if not actor then
        return { success = false, error = "request_failed" }
    end
    local result = Bridge.Database.Query([[
        UPDATE `sky_phone_weazel_articles`
        SET `deleted_at` = CURRENT_TIMESTAMP, `deleted_by_identifier` = ?, `revision` = `revision` + 1
        WHERE `id` = ? AND `revision` = ? AND `deleted_at` IS NULL
    ]], { actor.identifier, data.id, revision })
    if affected_rows(result) ~= 1 then
        local rows = Bridge.Database.Query([[
            SELECT `revision`, `deleted_at`
            FROM `sky_phone_weazel_articles`
            WHERE `id` = ?
            LIMIT 1
        ]], { data.id })
        if not rows[1] or rows[1].deleted_at then
            return { success = false, error = "not_found" }
        end
        return { success = false, error = "revision_conflict" }
    end
    return { success = true }
end)
end)
