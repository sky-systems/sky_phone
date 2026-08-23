SkyPhoneMediaImport = {}

local adapters = {}
local websites = {}
local import_candidates = {}
local initialized = false
local media_types_by_mime = {
    ["image/gif"] = "photo",
    ["image/jpeg"] = "photo",
    ["image/png"] = "photo",
    ["image/webp"] = "photo",
    ["video/mp4"] = "video",
    ["video/quicktime"] = "video",
    ["video/webm"] = "video",
}

local function session_owner(source)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return nil, error_response
    end

    local device = SkyPhone.LoadDevice(session.imei)
    if not device then
        return nil, { success = false, error = "device_not_found" }
    end

    return {
        account_id = device.account_id and tonumber(device.account_id) or nil,
        imei = session.imei,
    }
end

local function owner_condition(owner)
    if owner.account_id then
        return "`account_id` = ?", { owner.account_id }
    end

    return "`account_id` IS NULL AND `device_imei` = ?", { owner.imei }
end

local function valid_source_id(value)
    return type(value) == "string"
        and #value >= 1
        and #value <= 64
        and value:match("^[a-z0-9_%-]+$") ~= nil
end

local function valid_external_id(value)
    return type(value) == "string"
        and #value >= 1
        and #value <= 128
        and value:match("^[%w_.:%-]+$") ~= nil
end

local function website_accessible(source, website)
    return not website.RequiredAce or website.RequiredAce == "" or IsPlayerAceAllowed(source, website.RequiredAce)
end

local function media_type_set(values)
    local allowed = {}
    if type(values) ~= "table" then
        return allowed
    end

    for _, value in ipairs(values) do
        if value == "photo" or value == "video" then
            allowed[value] = true
        end
    end
    return allowed
end

local function url_host(value)
    if type(value) ~= "string" or #value > Config.Media.UrlMaxLength or value:find("%c") then
        return nil
    end

    local authority = value:match("^https://([^/%?#]+)")
    if not authority or authority:find("@", 1, true) then
        return nil
    end

    local host = authority:match("^([^:]+)")
    return host and host:lower() or nil
end

function SkyPhoneMediaImport.ResponseHeader(headers, name)
    if type(headers) ~= "table" then
        return nil
    end
    local requested_name = name:lower()
    for header_name, value in pairs(headers) do
        if type(header_name) == "string" and header_name:lower() == requested_name then
            if type(value) == "table" then
                return value[1]
            end
            return value
        end
    end
    return nil
end

local function allowed_host(website, host)
    for _, configured_host in ipairs(website.AllowedMediaHosts) do
        local candidate = type(configured_host) == "string" and configured_host:lower():gsub("^%.", "") or ""
        if candidate ~= "" and (host == candidate or host:sub(-#candidate - 1) == "." .. candidate) then
            return true
        end
    end
    return false
end

local function normalize_media(website, item)
    if type(item) ~= "table" or not valid_external_id(item.externalId) then
        return nil, "invalid_import_media"
    end

    local media_type = item.mediaType
    if not website._media_types[media_type] then
        return nil, "import_media_not_allowed"
    end

    local mime_type = type(item.mimeType) == "string"
        and item.mimeType:lower():match("^%s*([^;%s]+)") or nil
    if not mime_type or media_types_by_mime[mime_type] ~= media_type then
        local path = type(item.url) == "string" and item.url:match("^https://[^/]+(/[^?#]*)") or nil
        local extension = path and path:match("%.([%w]+)$") or nil
        local mime_by_extension = {
            gif = "image/gif",
            jpeg = "image/jpeg",
            jpg = "image/jpeg",
            mov = "video/quicktime",
            mp4 = "video/mp4",
            png = "image/png",
            webm = "video/webm",
            webp = "image/webp",
        }
        mime_type = extension and mime_by_extension[extension:lower()] or nil
    end

    local size = tonumber(item.size)
    if not size or size <= 0 or size ~= math.floor(size) then
        return nil, "invalid_import_media"
    end

    local size_limit = media_type == "photo"
        and tonumber(Config.Media.Import.MaxPhotoBytes)
        or tonumber(Config.Media.Import.MaxVideoBytes)
    if not size_limit or size > size_limit then
        return nil, "import_media_too_large"
    end

    local host = url_host(item.url)
    if not host or not allowed_host(website, host) then
        return nil, "import_media_not_allowed"
    end

    local filename = type(item.filename) == "string" and item.filename:match("^%s*(.-)%s*$") or ""
    if filename == "" then
        filename = item.externalId
    elseif #filename > 160 then
        filename = filename:sub(1, 160)
    end

    return {
        externalId = item.externalId,
        filename = filename,
        mediaType = media_type,
        mimeType = mime_type,
        size = size,
        sourceId = website.Id,
        url = item.url,
    }
end

local function remember_candidate(source, media)
    local expires_at = os.time() + math.max(
        30,
        math.floor(tonumber(Config.Media.Import.CandidateTtlSeconds) or 300)
    )
    import_candidates[source] = import_candidates[source] or {}
    import_candidates[source][media.sourceId] = import_candidates[source][media.sourceId] or {}
    import_candidates[source][media.sourceId][media.externalId] = expires_at
end

local function candidate_allowed(source, source_id, external_id)
    local by_source = import_candidates[source] and import_candidates[source][source_id]
    local expires_at = by_source and by_source[external_id]
    if not expires_at or expires_at < os.time() then
        if by_source then
            by_source[external_id] = nil
        end
        return false
    end
    return true
end

local function validate_website(definition)
    if type(definition) ~= "table"
        or definition.Enabled == false
        or not valid_source_id(definition.Id)
        or type(definition.Label) ~= "string"
        or definition.Label == ""
        or #definition.Label > 64
        or type(definition.Adapter) ~= "string"
    then
        return nil, "invalid_definition"
    end

    local adapter = adapters[definition.Adapter]
    if not adapter then
        return nil, "unknown_adapter"
    end

    if type(definition.AllowedMediaHosts) ~= "table" or #definition.AllowedMediaHosts < 1 then
        return nil, "missing_allowed_hosts"
    end

    local allowed_media_types = media_type_set(definition.MediaTypes)
    if not allowed_media_types.photo and not allowed_media_types.video then
        return nil, "missing_media_types"
    end

    if definition.RequiredAce ~= nil and type(definition.RequiredAce) ~= "string" then
        return nil, "invalid_required_ace"
    end

    local website = {}
    for key, value in pairs(definition) do
        website[key] = value
    end
    website._adapter = adapter
    website._media_types = allowed_media_types
    local valid, validation_error = adapter.Validate(website)
    if not valid then
        return nil, validation_error
    end

    return website
end

local function build_registry()
    websites = {}
    local config = Config.Media.Import
    if not config.Enabled then
        return
    end

    for index, definition in ipairs(config.Websites or {}) do
        local website, website_error = validate_website(definition)
        if website then
            if websites[website.Id] then
                error(("[sky_phone] Duplicate media import website id '%s'."):format(website.Id))
            end
            websites[website.Id] = website
        else
            local source_name = type(definition) == "table" and definition.Id or nil
            if website_error == "missing_api_key" then
                Bridge.Debug(
                    "warn",
                    "[sky_phone] Media import source '%s' at index %s is disabled because Config.Media.FiveManage.ApiKey is empty. Add a FiveManage V3 token with Media access in the Phone Configurator and save it.",
                    tostring(source_name or "unknown"),
                    tostring(index)
                )
            else
                Bridge.Debug(
                    "warn",
                    "[sky_phone] Media import source '%s' at index %s is disabled because its configuration is invalid: %s.",
                    tostring(source_name or "unknown"),
                    tostring(index),
                    tostring(website_error)
                )
            end
        end
    end
end

local function find_imported(owner, source_id, items)
    if #items == 0 then
        return
    end

    local condition, params = owner_condition(owner)
    params[#params + 1] = source_id
    local placeholders = {}
    for index, item in ipairs(items) do
        placeholders[index] = "?"
        params[#params + 1] = item.externalId
    end

    local rows = Bridge.Database.Query(([[
        SELECT `remote_id` FROM `sky_phone_media`
        WHERE %s AND `origin` = 'website_import' AND `source_id` = ?
            AND `remote_id` IN (%s)
    ]]):format(condition, table.concat(placeholders, ", ")), params)
    local imported = {}
    for _, row in ipairs(rows) do
        imported[row.remote_id] = true
    end
    for _, item in ipairs(items) do
        item.imported = imported[item.externalId] or false
    end
end

local function select_owned_import(owner, source_id, remote_id)
    local condition, params = owner_condition(owner)
    params[#params + 1] = source_id
    params[#params + 1] = remote_id
    local rows = Bridge.Database.Query(([[
        SELECT `id`, `url`, `media_type` AS `mediaType`, `mime_type` AS `mimeType`,
            UNIX_TIMESTAMP(`created_at`) * 1000 AS `createdAt`
        FROM `sky_phone_media`
        WHERE %s AND `origin` = 'website_import'
            AND `source_id` = ? AND `remote_id` = ?
        LIMIT 1
    ]]):format(condition), params)
    local row = rows[1]
    if row then
        row.id = tonumber(row.id)
        row.createdAt = tonumber(row.createdAt) or 0
    end
    return row
end

local function store_import(owner, media)
    local existing = select_owned_import(owner, media.sourceId, media.externalId)
    if existing then
        Bridge.Database.Query([[
            UPDATE `sky_phone_media`
            SET `url` = ?, `media_type` = ?, `mime_type` = ?, `verified_at` = CURRENT_TIMESTAMP
            WHERE `id` = ?
        ]], { media.url, media.mediaType, media.mimeType, existing.id })
        existing.url = media.url
        existing.mediaType = media.mediaType
        existing.mimeType = media.mimeType
        return existing
    end

    local result
    if owner.account_id then
        result = Bridge.Database.Query([[
            INSERT IGNORE INTO `sky_phone_media`
                (`account_id`, `device_imei`, `url`, `remote_id`, `media_type`, `mime_type`, `origin`, `source_id`, `verified_at`)
            VALUES (?, NULL, ?, ?, ?, ?, 'website_import', ?, CURRENT_TIMESTAMP)
        ]], { owner.account_id, media.url, media.externalId, media.mediaType, media.mimeType, media.sourceId })
    else
        result = Bridge.Database.Query([[
            INSERT IGNORE INTO `sky_phone_media`
                (`account_id`, `device_imei`, `url`, `remote_id`, `media_type`, `mime_type`, `origin`, `source_id`, `verified_at`)
            VALUES (NULL, ?, ?, ?, ?, ?, 'website_import', ?, CURRENT_TIMESTAMP)
        ]], { owner.imei, media.url, media.externalId, media.mediaType, media.mimeType, media.sourceId })
    end

    local media_id = type(result) == "number" and result or (type(result) == "table" and tonumber(result.insertId))
    if media_id and media_id < 1 then
        media_id = nil
    end
    if not media_id then
        local concurrent = select_owned_import(owner, media.sourceId, media.externalId)
        if concurrent then
            return concurrent
        end
        return nil, "request_failed"
    end

    return {
        createdAt = os.time() * 1000,
        favorite = false,
        id = media_id,
        mediaType = media.mediaType,
        url = media.url,
    }
end

function SkyPhoneMediaImport.RegisterAdapter(name, adapter)
    assert(type(name) == "string" and name ~= "", "Media import adapter name must be a string")
    assert(type(adapter) == "table", "Media import adapter must be a table")
    assert(type(adapter.Validate) == "function", "Media import adapter requires Validate")
    assert(type(adapter.List) == "function", "Media import adapter requires List")
    assert(type(adapter.Resolve) == "function", "Media import adapter requires Resolve")
    assert(not adapters[name], ("Media import adapter '%s' is already registered"):format(name))
    adapters[name] = adapter
end

function SkyPhoneMediaImport.HttpRequest(url, headers, timeout_ms, method)
    local request = promise.new()
    local settled = false
    local request_method = method or "GET"
    local request_host = url_host(url) or "invalid-host"
    PerformHttpRequest(url, function(status, response_body, response_headers, error_data)
        if settled then
            return
        end
        settled = true
        local response_status = tonumber(status) or 0
        if response_status == 0 then
            Bridge.Debug(
                "warn",
                "[sky_phone] Media import HTTP %s request to '%s' failed: %s.",
                request_method,
                request_host,
                tostring(error_data or "unknown transport error"),
                { always = true }
            )
        elseif response_status >= 400 then
            Bridge.Debug(
                "debug",
                "[sky_phone] Media import HTTP %s request to '%s' returned status %s.",
                request_method,
                request_host,
                tostring(response_status)
            )
        end
        request:resolve({
            body = response_body or "",
            error = error_data,
            headers = response_headers or {},
            status = response_status,
        })
    end, request_method, "", headers or {}, { followLocation = false })
    SetTimeout(timeout_ms, function()
        if settled then
            return
        end
        settled = true
        Bridge.Debug(
            "warn",
            "[sky_phone] Media import HTTP %s request to '%s' timed out after %s ms.",
            request_method,
            request_host,
            tostring(timeout_ms),
            { always = true }
        )
        request:resolve({ body = "", error = "request timeout", headers = {}, status = 0 })
    end)
    return Citizen.Await(request)
end

function SkyPhoneMediaImport.ResolveUrl(source_id, url)
    if not initialized or not valid_source_id(source_id) or type(url) ~= "string" then
        return nil, "invalid_import_url"
    end

    local website = websites[source_id]
    local trimmed_url = url:match("^%s*(.-)%s*$")
    local host = website and url_host(trimmed_url) or nil
    if not website or not host or not allowed_host(website, host) then
        return nil, "import_url_not_allowed"
    end

    if type(website._adapter.ResolveUrl) == "function" then
        local item, resolve_error = website._adapter.ResolveUrl(website, trimmed_url)
        if not item then
            return nil, resolve_error
        end
        return normalize_media(website, item)
    end

    local response = SkyPhoneMediaImport.HttpRequest(
        trimmed_url,
        {},
        tonumber(website.RequestTimeoutMs or Config.Media.FiveManage.RequestTimeoutMs) or 10000,
        "HEAD"
    )
    if response.status == 0 then
        return nil, "import_source_unavailable"
    end
    if response.status < 200 or response.status >= 300 then
        return nil, "import_url_unavailable"
    end

    local content_type = SkyPhoneMediaImport.ResponseHeader(response.headers, "content-type")
    content_type = type(content_type) == "string" and content_type:lower():match("^%s*([^;%s]+)") or nil
    local media_type = content_type and media_types_by_mime[content_type] or nil
    if not media_type or not website._media_types[media_type] then
        return nil, "import_media_not_allowed"
    end

    local content_length = tonumber(SkyPhoneMediaImport.ResponseHeader(response.headers, "content-length"))
    if not content_length or content_length <= 0 or content_length ~= math.floor(content_length) then
        return nil, "import_size_unavailable"
    end

    local external_id = ("url:%08x%08x"):format(
        joaat(trimmed_url) & 0xffffffff,
        joaat("sky_phone:" .. trimmed_url) & 0xffffffff
    )
    local url_path = trimmed_url:match("^https://[^/]+(/[^?#]*)") or ""
    return normalize_media(website, {
        externalId = external_id,
        filename = url_path:match("/([^/]+)$") or external_id,
        mediaType = media_type,
        mimeType = content_type,
        size = content_length,
        url = trimmed_url,
    })
end

function SkyPhoneMediaImport.UrlEncode(value)
    return tostring(value):gsub("\n", "\r\n"):gsub("([^%w%-_%.~])", function(character)
        return ("%%%02X"):format(character:byte())
    end)
end

function SkyPhoneMediaImport.Resolve(source_id, external_id)
    if not initialized or not valid_source_id(source_id) or not valid_external_id(external_id) then
        return nil, "import_source_unavailable"
    end

    local website = websites[source_id]
    if not website then
        return nil, "import_source_unavailable"
    end

    local item, resolve_error = website._adapter.Resolve(website, external_id)
    if not item then
        return nil, resolve_error
    end

    return normalize_media(website, item)
end

function SkyPhoneMediaImport.Initialize()
    assert(not initialized, "Media import was initialized more than once")
    build_registry()
    initialized = true

    Bridge.Callbacks.Register("sky_phone:media:import:sources", function(source)
        local owner, error_response = session_owner(source)
        if not owner then
            return error_response
        end

        local sources = {}
        for _, website in pairs(websites) do
            if website_accessible(source, website) then
                local media_types = {}
                if website._media_types.photo then
                    media_types[#media_types + 1] = "photo"
                end
                if website._media_types.video then
                    media_types[#media_types + 1] = "video"
                end
                sources[#sources + 1] = {
                    id = website.Id,
                    label = website.Label,
                    mediaTypes = media_types,
                }
            end
        end
        table.sort(sources, function(left, right)
            return left.label:lower() < right.label:lower()
        end)
        return {
            success = true,
            data = {
                maxSelection = math.max(1, math.floor(tonumber(Config.Media.Import.MaxSelection) or 1)),
                sources = sources,
            },
        }
    end)

    Bridge.Callbacks.Register("sky_phone:media:import:list", function(source, data)
        local owner, error_response = session_owner(source)
        if not owner then
            return error_response
        end
        if not SkyPhone.AllowOperation(
            source,
            "media_import_list",
            tonumber(Config.Media.Import.ListActionsPerMinute) or 60,
            60
        ) then
            return { success = false, error = "rate_limited" }
        end

        data = type(data) == "table" and data or {}
        local website = valid_source_id(data.sourceId) and websites[data.sourceId] or nil
        local media_type = data.mediaType
        local page = math.floor(tonumber(data.page) or 1)
        if not website or not website_accessible(source, website) then
            return { success = false, error = "import_source_not_found" }
        end
        if not website._media_types[media_type] or page < 1 or page > 10000 then
            return { success = false, error = "invalid_import_request" }
        end

        local limit = math.max(1, math.min(math.floor(tonumber(Config.Media.Import.PageSize) or 30), 100))
        local result, list_error = website._adapter.List(website, media_type, page, limit)
        if not result then
            return { success = false, error = list_error }
        end
        if type(result) ~= "table" or type(result.items) ~= "table" then
            Bridge.Debug(
                "warn",
                "[sky_phone] Import source '%s' returned an invalid list response.",
                website.Id
            )
            return { success = false, error = "import_provider_failed" }
        end

        local items = {}
        for _, item in ipairs(result.items) do
            local normalized, normalize_error = normalize_media(website, item)
            if normalized then
                items[#items + 1] = normalized
                remember_candidate(source, normalized)
            else
                Bridge.Debug(
                    "warn",
                    "[sky_phone] Rejected media '%s' from import source '%s': %s.",
                    tostring(item.externalId),
                    website.Id,
                    tostring(normalize_error)
                )
            end
        end
        find_imported(owner, website.Id, items)
        return {
            success = true,
            data = {
                hasMore = result.hasMore == true,
                items = items,
                page = page,
                total = math.max(0, math.floor(tonumber(result.total) or #items)),
            },
        }
    end)

    Bridge.Callbacks.Register("sky_phone:media:import:commit", function(source, data)
        local owner, error_response = session_owner(source)
        if not owner then
            return error_response
        end
        if not SkyPhone.AllowOperation(
            source,
            "media_import_commit",
            tonumber(Config.Media.Import.ImportActionsPerMinute) or 20,
            60
        ) then
            return { success = false, error = "rate_limited" }
        end

        data = type(data) == "table" and data or {}
        local website = valid_source_id(data.sourceId) and websites[data.sourceId] or nil
        if not website or not website_accessible(source, website) then
            return { success = false, error = "import_source_not_found" }
        end
        if type(data.externalIds) ~= "table" then
            return { success = false, error = "invalid_import_request" }
        end

        local maximum = math.max(1, math.floor(tonumber(Config.Media.Import.MaxSelection) or 1))
        if #data.externalIds < 1 or #data.externalIds > maximum then
            return { success = false, error = "invalid_import_request" }
        end

        local unique_ids = {}
        local requested_ids = {}
        for _, external_id in ipairs(data.externalIds) do
            if not valid_external_id(external_id) or unique_ids[external_id] then
                return { success = false, error = "invalid_import_request" }
            end
            if not candidate_allowed(source, website.Id, external_id) then
                return { success = false, error = "invalid_import_request" }
            end
            unique_ids[external_id] = true
            requested_ids[#requested_ids + 1] = external_id
        end

        local imported = {}
        local failed = {}
        for _, external_id in ipairs(requested_ids) do
            local item, resolve_error = website._adapter.Resolve(website, external_id)
            local normalized, normalize_error
            if item then
                normalized, normalize_error = normalize_media(website, item)
            end
            if not normalized then
                failed[#failed + 1] = {
                    error = resolve_error or normalize_error or "import_provider_failed",
                    externalId = external_id,
                }
            else
                local stored, store_error = store_import(owner, normalized)
                if stored then
                    imported[#imported + 1] = stored
                else
                    failed[#failed + 1] = {
                        error = store_error or "request_failed",
                        externalId = external_id,
                    }
                end
            end
        end

        return {
            success = true,
            data = {
                failed = failed,
                imported = imported,
            },
        }
    end)

    Bridge.Callbacks.Register("sky_phone:media:import:url", function(source, data)
        local owner, error_response = session_owner(source)
        if not owner then
            return error_response
        end
        if not SkyPhone.AllowOperation(
            source,
            "media_import_url",
            tonumber(Config.Media.Import.ImportActionsPerMinute) or 20,
            60
        ) then
            return { success = false, error = "rate_limited" }
        end

        data = type(data) == "table" and data or {}
        local website = valid_source_id(data.sourceId) and websites[data.sourceId] or nil
        if not website or not website_accessible(source, website) then
            return { success = false, error = "import_source_not_found" }
        end
        if type(data.url) ~= "string" or #data.url < 1 or #data.url > Config.Media.UrlMaxLength then
            return { success = false, error = "invalid_import_url" }
        end

        local normalized, resolve_error = SkyPhoneMediaImport.ResolveUrl(website.Id, data.url)
        if not normalized then
            Bridge.Debug(
                "warn",
                "[sky_phone] Media URL import failed for player %s, source '%s', host '%s': %s.",
                tostring(source),
                website.Id,
                tostring(url_host(data.url) or "invalid-host"),
                tostring(resolve_error),
                { always = true }
            )
            return { success = false, error = resolve_error }
        end
        Bridge.Debug(
            "debug",
            "[sky_phone] Media URL import resolved for player %s via source '%s' as %s '%s' (%s bytes).",
            tostring(source),
            website.Id,
            normalized.mediaType,
            normalized.externalId,
            tostring(normalized.size)
        )
        local stored, store_error = store_import(owner, normalized)
        if not stored then
            return { success = false, error = store_error or "request_failed" }
        end
        return { success = true, data = stored }
    end)

    AddEventHandler("playerDropped", function()
        import_candidates[source] = nil
    end)
end

AddEventHandler("sky_phone:configurator:serverUpdated", function()
    if initialized then
        build_registry()
    end
end)
