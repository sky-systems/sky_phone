Bridge.Database.AfterMigration("sky_phone", function()
SkyPhoneMedia = {}
SkyPhoneMediaImport.Initialize()

local pending_uploads = {}
local pending_deletes = {}
local allowed_fivemanage_hosts = {
    ["api.fivemanage.com"] = true,
    ["fmapi.net"] = true,
}

local function diagnostic_text(value, maximum_length)
    return tostring(value or "unknown"):gsub("[\r\n]", " "):sub(1, maximum_length)
end

local function media_debug(message, ...)
    local arguments = { ... }
    arguments[#arguments + 1] = { notice = true }
    Bridge.Debug("debug", "[sky_phone][media-debug] " .. message, table.unpack(arguments))
end

local function http_request(url, method, body, headers, timeout_ms)
    local request = promise.new()
    local settled = false
    PerformHttpRequest(url, function(status, response_body, response_headers, error_data)
        if settled then
            return
        end
        settled = true
        request:resolve({
            body = response_body,
            error = error_data,
            headers = response_headers,
            status = status,
        })
    end, method, body or "", headers or {})
    SetTimeout(timeout_ms, function()
        if settled then
            return
        end
        settled = true
        request:resolve({ status = 0, body = "request_timeout" })
    end)
    return Citizen.Await(request)
end

local function response_error_message(response)
    if type(response) ~= "table" then
        return "invalid response"
    end
    if type(response.status) == "number" and response.status >= 200 and response.status < 300 then
        return "none"
    end
    if type(response.error) == "string" and response.error ~= "" then
        return response.error:sub(1, 240)
    end
    local success, payload = pcall(json.decode, response.body or "")
    if success and type(payload) == "table" then
        local message = payload.error or payload.message
        if type(message) == "string" and message ~= "" then
            return message:sub(1, 240)
        end
    end
    local response_body = tostring(response.body or ""):gsub("[\r\n]", " ")
    if response_body ~= "" then
        return response_body:sub(1, 240)
    end
    return "no provider error message"
end

local function decode_response(response)
    if type(response) ~= "table" or type(response.status) ~= "number" then
        return nil, "invalid_response"
    end
    if response.status == 0 then
        return nil, "request_timeout"
    end
    if response.status < 200 or response.status >= 300 then
        return nil, ("request_failed_%s"):format(response.status)
    end
    local success, decoded = pcall(json.decode, response.body or "")
    if not success or type(decoded) ~= "table" then
        return nil, "invalid_response"
    end
    return decoded.data or decoded
end

local function fivemanage_file_base(value)
    if type(value) ~= "string" then
        return nil
    end
    local host = value:match("^https://([^/%?#]+)")
    host = host and host:lower() or nil
    if not host or not allowed_fivemanage_hosts[host] then
        return nil
    end
    return ("https://%s/api/v3/file"):format(host), host
end

local function request_presigned_url()
    local api_key = SkyPhoneMediaProviderConfig.FiveManageApiKey()
    media_debug("Starting FiveManage presigned upload request (api-key=%s).", api_key ~= "" and "present" or "missing")
    if api_key == "" then
        Bridge.Debug(
            "error",
            "[sky_phone] FiveManage presigned upload request failed: Config.Media.FiveManage.ApiKey is empty or invalid.",
            { always = true }
        )
        return nil, "missing_config"
    end
    local config = Config.Media.FiveManage
    local response = http_request(
        tostring(config.BaseUrl):gsub("/+$", "") .. "/presigned-url",
        "GET",
        "",
        { ["Authorization"] = api_key },
        tonumber(config.RequestTimeoutMs) or 10000
    )
    media_debug("FiveManage presigned upload request returned HTTP %s.", tostring(response.status))
    if response.status == 401 or response.status == 403 then
        Bridge.Debug(
            "error",
            "[sky_phone] FiveManage presigned upload request was rejected with HTTP %s. Check Config.Media.FiveManage.ApiKey and its file permissions.",
            tostring(response.status),
            { always = true }
        )
        return nil, "media_provider_unauthorized"
    end
    if response.status == 429 then
        Bridge.Debug(
            "error",
            "[sky_phone] FiveManage presigned upload request was rate limited with HTTP 429.",
            { always = true }
        )
        return nil, "media_provider_rate_limited"
    end
    local data, response_error = decode_response(response)
    if not data then
        Bridge.Debug(
            "error",
            "[sky_phone] FiveManage presigned upload request failed with HTTP %s (%s): %s",
            tostring(response.status),
            tostring(response_error),
            response_error_message(response),
            { always = true }
        )
        return nil, response_error == "request_timeout" and "request_timeout" or "media_provider_failed"
    end
    local presigned_url = data.presignedUrl or data.presigned_url
    if type(presigned_url) ~= "string" or presigned_url == "" then
        Bridge.Debug(
            "error",
            "[sky_phone] FiveManage presigned upload response did not contain a presignedUrl.",
            { always = true }
        )
        return nil, "media_provider_failed"
    end
    local provider_base_url, provider_host = fivemanage_file_base(presigned_url)
    if not provider_base_url then
        Bridge.Debug(
            "error",
            "[sky_phone] FiveManage returned a presigned URL on an unexpected host.",
            { always = true }
        )
        return nil, "media_provider_failed"
    end
    media_debug("FiveManage returned a valid presigned upload URL (host=%s).", provider_host)
    return presigned_url
end

local function encode_remote_path(value)
    local segments = {}
    for segment in tostring(value):gmatch("[^/]+") do
        segments[#segments + 1] = SkyPhoneMediaImport.UrlEncode(segment)
    end
    return table.concat(segments, "/")
end

local function delete_remote_file(remote_id)
    local api_key = SkyPhoneMediaProviderConfig.FiveManageApiKey()
    if api_key == "" then
        return false, "missing_config"
    end
    local config = Config.Media.FiveManage
    local response = http_request(
        ("%s/%s"):format(
            tostring(config.BaseUrl):gsub("/+$", ""),
            encode_remote_path(remote_id)
        ),
        "DELETE",
        "",
        { ["Authorization"] = api_key },
        tonumber(config.RequestTimeoutMs) or 10000
    )
    if response.status < 200 or response.status >= 300 then
        return false, response.status == 0 and "request_timeout" or ("delete_failed_%s"):format(response.status)
    end
    return true
end

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
        phone_number = device.phone_number,
    }
end

local function owner_condition(owner)
    if owner.account_id then
        return "`account_id` = ?", { owner.account_id }
    end
    return "`account_id` IS NULL AND `device_imei` = ?", { owner.imei }
end

local function owners_match(left, right)
    return left.imei == right.imei and left.account_id == right.account_id
end

function SkyPhoneMedia.ResolveOwnedMedia(source, media_id, media_type)
    local id = tonumber(media_id)
    if not id or id < 1 or id ~= math.floor(id)
        or (media_type ~= "photo" and media_type ~= "video")
    then
        return nil, "invalid_attachment"
    end
    local owner, error_response = session_owner(source)
    if not owner then
        return nil, error_response.error
    end
    local condition, owner_params = owner_condition(owner)
    local params = { id }
    for _, value in ipairs(owner_params) do
        params[#params + 1] = value
    end
    local rows = Bridge.Database.Query(([[
        SELECT `url`, `media_type`, `mime_type`, `origin`, `source_id`, `remote_id`,
            UNIX_TIMESTAMP(`verified_at`) AS `verified_at`
        FROM `sky_phone_media`
        WHERE `id` = ? AND %s
        LIMIT 1
    ]]):format(condition), params)
    local media = rows[1]
    if not media or media.media_type ~= media_type
        or type(media.url) ~= "string"
        or #media.url > Config.Media.UrlMaxLength
        or not media.url:match("^https://")
    then
        Bridge.Debug(
            "warn",
            "[sky_phone] Rejected unowned %s media %s from source %s.",
            media_type,
            tostring(media_id),
            tostring(source)
        )
        return nil, "invalid_attachment"
    end
    if media.origin == "website_import" then
        local verified_at = tonumber(media.verified_at) or 0
        local revalidate_after = math.max(
            1,
            math.floor(tonumber(Config.Media.Import.RevalidateAfterSeconds) or 3600)
        )
        if os.time() - verified_at >= revalidate_after then
            local refreshed, refresh_error
            if type(media.remote_id) == "string" and media.remote_id:sub(1, 4) == "url:" then
                refreshed, refresh_error = SkyPhoneMediaImport.ResolveUrl(media.source_id, media.url)
            else
                refreshed, refresh_error = SkyPhoneMediaImport.Resolve(media.source_id, media.remote_id)
            end
            if not refreshed then
                return nil, refresh_error
            end
            if refreshed.mediaType ~= media_type then
                return nil, "import_media_not_allowed"
            end
            Bridge.Database.Query([[
                UPDATE `sky_phone_media`
                SET `url` = ?, `mime_type` = ?, `verified_at` = CURRENT_TIMESTAMP
                WHERE `id` = ? AND `origin` = 'website_import'
            ]], { refreshed.url, refreshed.mimeType, id })
            media.url = refreshed.url
            media.mime_type = refreshed.mimeType
        end
    end
    return media.url, nil, media.mime_type
end

local function upload_result(source, correlation_id, success, error_code, media)
    media_debug(
        "Sending upload result (source=%s, correlation=%s, success=%s, error=%s, media=%s).",
        tostring(source),
        diagnostic_text(correlation_id, 80),
        tostring(success),
        diagnostic_text(error_code, 80),
        type(media) == "table" and "present" or "missing"
    )
    TriggerClientEvent("sky_phone:media:upload-result", source, {
        correlationId = correlation_id,
        success = success,
        error = error_code,
        media = media,
    })
end

local function delete_result(source, correlation_id, success, error_code, media_id)
    TriggerClientEvent("sky_phone:media:delete-result", source, {
        correlationId = correlation_id,
        success = success,
        error = error_code,
        id = media_id,
    })
end

local function delete_many_result(source, correlation_id, success, error_code, deleted_ids)
    TriggerClientEvent("sky_phone:media:delete-many-result", source, {
        correlationId = correlation_id,
        success = success,
        error = error_code,
        deletedIds = deleted_ids,
    })
end

local function valid_remote_id(value)
    return type(value) == "string" and #value >= 4 and #value <= 128 and value:match("^[%w_%-]+$") ~= nil
end

local function verify_remote_upload(state, remote_id, uploaded_url)
    if not valid_remote_id(remote_id) or type(uploaded_url) ~= "string"
        or #uploaded_url > Config.Media.UrlMaxLength
        or not uploaded_url:match("^https://")
    then
        Bridge.Debug(
            "error",
            "[sky_phone][media-debug] Upload completion payload is invalid (remote-id=%s, url=%s).",
            valid_remote_id(remote_id) and "valid" or "invalid",
            type(uploaded_url) == "string" and uploaded_url:match("^https://") and "https" or "invalid"
        )
        return nil, "invalid_upload"
    end

    local uploaded_host = uploaded_url:match("^https://([^/%?#]+)")
    if not uploaded_host or uploaded_host:lower() ~= "r2.fivemanage.com" then
        Bridge.Debug(
            "error",
            "[sky_phone][media-debug] FiveManage upload returned an unexpected media host."
        )
        return nil, "invalid_upload"
    end
    media_debug(
        "Accepting the direct FiveManage upload response (type=%s, size=%s).",
        tostring(state.media_type),
        tostring(state.size_bytes)
    )
    return {
        mime_type = state.mime_type,
        remote_id = remote_id,
        size = state.size_bytes,
        url = uploaded_url,
    }, nil, true
end

SkyPhoneMedia.DeleteRemoteFile = delete_remote_file
SkyPhoneMedia.RequestPresignedUrl = request_presigned_url
SkyPhoneMedia.VerifyRemoteUpload = verify_remote_upload

local function expire_upload(request_id)
    local state = pending_uploads[request_id]
    if not state or state.completing then
        return
    end
    pending_uploads[request_id] = nil
    Bridge.Debug(
        "error",
        "[sky_phone][media-debug] Upload session expired before completion (source=%s, correlation=%s).",
        tostring(state.source),
        diagnostic_text(state.correlation_id, 80)
    )
    upload_result(state.source, state.correlation_id, false, "upload_timeout")
end

Bridge.Callbacks.Register("sky_phone:gallery:list", function(source, data)
    local owner, error_response = session_owner(source)
    if not owner then
        return error_response
    end
    data = type(data) == "table" and data or {}
    local limit = math.max(1, math.min(math.floor(tonumber(data.limit) or Config.Media.PageSize), 100))
    local offset = math.max(0, math.floor(tonumber(data.offset) or 0))
    local media_type = data.mediaType
    if media_type ~= "photo" and media_type ~= "video" then
        media_type = nil
    end
    local condition, params = owner_condition(owner)
    condition = condition .. " AND `media_type` IN ('photo', 'video')"
    if media_type then
        condition = condition .. " AND `media_type` = ?"
        params[#params + 1] = media_type
    end
    if data.favoriteOnly == true then
        condition = condition .. " AND `favorite` = 1"
    end
    params[#params + 1] = limit
    params[#params + 1] = offset
    local rows = Bridge.Database.Query(([[
        SELECT `id`, `url`, `media_type` AS `mediaType`, `favorite`,
            UNIX_TIMESTAMP(`created_at`) * 1000 AS `createdAt`
        FROM `sky_phone_media`
        WHERE %s
        ORDER BY `created_at` DESC, `id` DESC
        LIMIT ? OFFSET ?
    ]]):format(condition), params)
    for _, row in ipairs(rows) do
        row.id = tonumber(row.id)
        row.createdAt = tonumber(row.createdAt) or 0
        row.favorite = tonumber(row.favorite) == 1
    end
    return { success = true, data = rows }
end)

Bridge.Callbacks.Register("sky_phone:gallery:favorite", function(source, data)
    if not SkyPhone.AllowOperation(source, "media_favorite", 60, 60)
        or type(data) ~= "table"
        or type(data.favorite) ~= "boolean"
    then
        return { success = false, error = "invalid_request" }
    end
    local media_id = tonumber(data.id)
    if not media_id or media_id < 1 or media_id ~= math.floor(media_id) then
        return { success = false, error = "invalid_request" }
    end
    local owner, error_response = session_owner(source)
    if not owner then
        return error_response
    end
    local condition, owner_params = owner_condition(owner)
    local params = { media_id }
    for _, value in ipairs(owner_params) do
        params[#params + 1] = value
    end
    local rows = Bridge.Database.Query(([[
        SELECT `id`
        FROM `sky_phone_media`
        WHERE `id` = ? AND %s AND `media_type` IN ('photo', 'video')
        LIMIT 1
    ]]):format(condition), params)
    if not rows[1] then
        return { success = false, error = "media_not_found" }
    end
    local update_params = { data.favorite and 1 or 0, media_id }
    for _, value in ipairs(owner_params) do
        update_params[#update_params + 1] = value
    end
    Bridge.Database.Query(
        ("UPDATE `sky_phone_media` SET `favorite` = ? WHERE `id` = ? AND %s"):format(condition),
        update_params
    )
    return {
        success = true,
        data = { id = media_id, favorite = data.favorite },
    }
end)

Bridge.Callbacks.Register("sky_phone:gallery:counts", function(source)
    local owner, error_response = session_owner(source)
    if not owner then
        return error_response
    end
    local condition, params = owner_condition(owner)
    local rows = Bridge.Database.Query(([[
        SELECT
            COUNT(*) AS `all_count`,
            COUNT(CASE WHEN `favorite` = 1 THEN 1 END) AS `favorite_count`,
            COUNT(CASE WHEN `media_type` = 'photo' AND `favorite` = 1 THEN 1 END) AS `favorite_photo_count`,
            COUNT(CASE WHEN `media_type` = 'video' AND `favorite` = 1 THEN 1 END) AS `favorite_video_count`,
            COUNT(CASE WHEN `media_type` = 'photo' THEN 1 END) AS `photo_count`,
            COUNT(CASE WHEN `media_type` = 'video' THEN 1 END) AS `video_count`
        FROM `sky_phone_media`
        WHERE %s AND `media_type` IN ('photo', 'video')
    ]]):format(condition), params)
    local counts = rows[1] or {}
    return {
        success = true,
        data = {
            all = tonumber(counts.all_count) or 0,
            favoritePhotos = tonumber(counts.favorite_photo_count) or 0,
            favorites = tonumber(counts.favorite_count) or 0,
            favoriteVideos = tonumber(counts.favorite_video_count) or 0,
            photos = tonumber(counts.photo_count) or 0,
            videos = tonumber(counts.video_count) or 0,
        },
    }
end)

local function current_messaging_device(source)
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return nil, error_response
    end
    local device = SkyPhone.LoadDevice(session.imei)
    if not device then
        return nil, { success = false, error = "device_not_found" }
    end
    if not device.sim_id then
        return nil, { success = false, error = "no_sim" }
    end
    return device
end

local function await_giphy_http(url)
    local request = promise.new()
    PerformHttpRequest(url, function(status, response_body)
        request:resolve({
            body = response_body,
            status = status,
        })
    end, "GET", "", {})
    return Citizen.Await(request)
end

local function parse_giphy_json(value)
    if type(value) == "table" then
        return value
    end
    if type(value) ~= "string" or value == "" then
        return nil
    end
    return json.decode(value)
end

local function url_encode(value)
    return tostring(value):gsub("\n", "\r\n"):gsub("([^%w%-_%.~])", function(character)
        return ("%%%02X"):format(character:byte())
    end)
end

Bridge.Callbacks.Register("sky_phone:messages:gifs", function(source, data)
    if not SkyPhone.AllowOperation(source, "gif_search", 30, 60) then
        return { success = false, error = "rate_limited" }
    end
    if type(data) ~= "table" then
        return { success = false, error = "invalid_request" }
    end
    local device, error_response = current_messaging_device(source)
    if not device then
        return error_response
    end
    local query = type(data.query) == "string" and data.query:match("^%s*(.-)%s*$") or ""
    local offset = math.floor(tonumber(data.offset) or 0)
    if #query > 60 or offset < 0 or offset > 500 then
        return { success = false, error = "invalid_request" }
    end
    local api_key = type(Config.Media.GiphyApiKey) == "string"
        and Config.Media.GiphyApiKey:match("^%s*(.-)%s*$") or ""
    if api_key == "" then
        return { success = false, error = "gif_provider_unconfigured" }
    end
    local endpoint = query == "" and "trending" or "search"
    local url = ("https://api.giphy.com/v1/gifs/%s?api_key=%s&limit=%s&offset=%s&rating=%s"):format(
        endpoint,
        url_encode(api_key),
        Config.Media.GifPageSize,
        offset,
        url_encode(Config.Media.GifRating)
    )
    if query ~= "" then
        url = url .. "&q=" .. url_encode(query)
    end
    local response = await_giphy_http(url)
    if response.status == 401 or response.status == 403 then
        Bridge.Debug("error", "[sky_phone] GIPHY rejected the configured API key with HTTP %s.", tostring(response.status))
        return { success = false, error = "gif_provider_unauthorized" }
    end
    if response.status == 429 then
        Bridge.Debug("error", "[sky_phone] GIPHY rate limit reached.")
        return { success = false, error = "gif_provider_rate_limited" }
    end
    if response.status < 200 or response.status >= 300 then
        Bridge.Debug("error", "[sky_phone] GIPHY request failed with HTTP %s.", tostring(response.status))
        return { success = false, error = "gif_provider_failed" }
    end
    local payload = parse_giphy_json(response.body)
    if type(payload) ~= "table" or type(payload.data) ~= "table" then
        return { success = false, error = "gif_provider_failed" }
    end
    local results = {}
    for _, item in ipairs(payload.data) do
        local preview = item.images and (item.images.fixed_width or item.images.downsized)
        local original = item.images and item.images.original
        if type(item.id) == "string" and type(preview) == "table" and type(preview.url) == "string"
            and type(original) == "table" and type(original.url) == "string" then
            results[#results + 1] = {
                height = tonumber(preview.height) or 200,
                id = item.id,
                previewUrl = preview.url,
                title = type(item.title) == "string" and item.title or "GIF",
                url = original.url,
                width = tonumber(preview.width) or 200,
            }
        end
    end
    local pagination = type(payload.pagination) == "table" and payload.pagination or {}
    local page_offset = math.floor(tonumber(pagination.offset) or offset)
    local page_count = math.floor(tonumber(pagination.count) or #payload.data)
    local total_count = math.floor(tonumber(pagination.total_count) or (page_offset + page_count))
    local next_offset = page_offset + page_count
    return {
        success = true,
        data = {
            hasMore = page_count > 0 and next_offset < total_count,
            nextOffset = next_offset,
            results = results,
        },
    }
end)

Bridge.Callbacks.Register("sky_phone:media:config", function(source)
    local owner, error_response = session_owner(source)
    if not owner then
        return error_response
    end
    local wallpaper_config = type(Config.Media.Wallpaper) == "table" and Config.Media.Wallpaper or {}
    return {
        success = true,
        data = {
            customWallpaperUploadEnabled = wallpaper_config.CustomUploadEnabled == true
                and Config.Media.Import.Enabled == true,
            videoBitrateKbps = tonumber(Config.Media.Video.BitrateKbps) or 1500,
        },
    }
end)

RegisterNetEvent("sky_phone:media:request-upload", function(data)
    local src = source
    data = type(data) == "table" and data or {}
    local correlation_id = data.correlationId
    local media_type = data.mediaType
    media_debug(
        "Server received upload request (source=%s, correlation=%s, type=%s).",
        tostring(src),
        diagnostic_text(correlation_id, 80),
        diagnostic_text(media_type, 20)
    )
    if type(correlation_id) ~= "string" or #correlation_id > 80
        or (media_type ~= "photo" and media_type ~= "video")
    then
        Bridge.Debug(
            "error",
            "[sky_phone][media-debug] Upload request validation failed (source=%s, correlation-type=%s, correlation-length=%s, media-type=%s).",
            tostring(src),
            type(correlation_id),
            type(correlation_id) == "string" and tostring(#correlation_id) or "invalid",
            diagnostic_text(media_type, 20)
        )
        upload_result(src, correlation_id, false, "invalid_request")
        return
    end
    if not SkyPhone.AllowOperation(src, "media_write", 20, 60) then
        Bridge.Debug(
            "warn",
            "[sky_phone][media-debug] Upload request was rate limited (source=%s, correlation=%s).",
            tostring(src),
            diagnostic_text(correlation_id, 80)
        )
        upload_result(src, correlation_id, false, "rate_limited")
        return
    end
    local owner, error_response = session_owner(src)
    if not owner then
        Bridge.Debug(
            "error",
            "[sky_phone][media-debug] Upload request has no valid phone session (source=%s, correlation=%s, error=%s).",
            tostring(src),
            diagnostic_text(correlation_id, 80),
            diagnostic_text(error_response and error_response.error, 80)
        )
        upload_result(src, correlation_id, false, error_response.error)
        return
    end
    media_debug(
        "Upload request session resolved (source=%s, correlation=%s, owner=%s).",
        tostring(src),
        diagnostic_text(correlation_id, 80),
        owner.account_id and "account" or "device"
    )
    local presigned_url, presigned_error = request_presigned_url()
    if not presigned_url then
        Bridge.Debug(
            "error",
            "[sky_phone][media-debug] Presigned upload request failed (source=%s, correlation=%s, error=%s).",
            tostring(src),
            diagnostic_text(correlation_id, 80),
            diagnostic_text(presigned_error, 80)
        )
        upload_result(src, correlation_id, false, presigned_error)
        return
    end
    local ids = Bridge.Database.Query("SELECT UUID() AS `request_id`", {})
    local request_id = ids[1] and ids[1].request_id
    if type(request_id) ~= "string" then
        Bridge.Debug(
            "error",
            "[sky_phone][media-debug] Database did not generate an upload request ID (source=%s, correlation=%s, rows=%s, request-id=%s).",
            tostring(src),
            diagnostic_text(correlation_id, 80),
            tostring(type(ids) == "table" and #ids or 0),
            type(request_id)
        )
        upload_result(src, correlation_id, false, "request_failed")
        return
    end
    pending_uploads[request_id] = {
        correlation_id = correlation_id,
        media_type = media_type,
        mime_type = media_type == "video" and "video/webm"
            or ({ png = "image/png", webp = "image/webp" })[tostring(Config.Media.Photo.Encoding):lower()]
            or "image/jpeg",
        owner = owner,
        source = src,
    }
    SetTimeout(tonumber(Config.Media.UploadSessionTimeoutMs) or 60000, function()
        expire_upload(request_id)
    end)
    media_debug(
        "Sending upload-ready to client (source=%s, correlation=%s, type=%s).",
        tostring(src),
        diagnostic_text(correlation_id, 80),
        tostring(media_type)
    )
    TriggerClientEvent("sky_phone:media:upload-ready", src, {
        correlationId = correlation_id,
        mediaType = media_type,
        photo = Config.Media.Photo,
        presignedUrl = presigned_url,
        requestId = request_id,
        uploadTimeoutMs = Config.Media.FiveManage.UploadTimeoutMs,
        video = Config.Media.Video,
    })
end)

RegisterNetEvent("sky_phone:media:complete-upload", function(data)
    local src = source
    data = type(data) == "table" and data or {}
    local request_id = data.requestId
    local state = type(request_id) == "string" and pending_uploads[request_id] or nil
    if not state or state.source ~= src or state.completing then
        Bridge.Debug(
            "warn",
            "[sky_phone][media-debug] Rejected upload completion (source=%s, request-id=%s, session=%s, owner-match=%s, completing=%s).",
            tostring(src),
            type(request_id) == "string" and "present" or "invalid",
            state and "present" or "missing",
            tostring(state and state.source == src),
            tostring(state and state.completing)
        )
        return
    end
    media_debug(
        "Server received upload completion (source=%s, correlation=%s, remote-id=%s, url=%s).",
        tostring(src),
        diagnostic_text(state.correlation_id, 80),
        type(data.remoteId) == "string" and "present" or "missing",
        type(data.url) == "string" and "present" or "missing"
    )
    state.completing = true
    local owner, error_response = session_owner(src)
    if not owner or not owners_match(owner, state.owner) then
        pending_uploads[request_id] = nil
        Bridge.Debug(
            "error",
            "[sky_phone][media-debug] Upload owner changed before completion (source=%s, correlation=%s, session=%s, owner-match=%s, error=%s).",
            tostring(src),
            diagnostic_text(state.correlation_id, 80),
            owner and "present" or "missing",
            tostring(owner and owners_match(owner, state.owner)),
            diagnostic_text(error_response and error_response.error, 80)
        )
        upload_result(src, state.correlation_id, false, error_response and error_response.error or "owner_changed")
        return
    end
    local verified, verify_error, trusted_remote = verify_remote_upload(
        state,
        data.remoteId,
        data.url
    )
    if not verified then
        pending_uploads[request_id] = nil
        Bridge.Debug(
            "error",
            "[sky_phone][media-debug] Uploaded file verification failed (source=%s, correlation=%s, error=%s, trusted-remote=%s).",
            tostring(src),
            diagnostic_text(state.correlation_id, 80),
            diagnostic_text(verify_error, 80),
            tostring(trusted_remote)
        )
        if trusted_remote then
            local deleted, delete_error = delete_remote_file(data.remoteId)
            if not deleted then
                Bridge.Debug(
                    "warn",
                    "[sky_phone] Could not remove rejected media upload %s: %s.",
                    tostring(data.remoteId),
                    tostring(delete_error)
                )
            end
        end
        upload_result(src, state.correlation_id, false, verify_error)
        return
    end
    local result
    if owner.account_id then
        result = Bridge.Database.Query([[
            INSERT INTO `sky_phone_media` (`account_id`, `device_imei`, `url`, `remote_id`, `media_type`, `mime_type`)
            VALUES (?, NULL, ?, ?, ?, ?)
        ]], { owner.account_id, verified.url, verified.remote_id, state.media_type, verified.mime_type })
    else
        result = Bridge.Database.Query([[
            INSERT INTO `sky_phone_media` (`account_id`, `device_imei`, `url`, `remote_id`, `media_type`, `mime_type`)
            VALUES (NULL, ?, ?, ?, ?, ?)
        ]], { owner.imei, verified.url, verified.remote_id, state.media_type, verified.mime_type })
    end
    pending_uploads[request_id] = nil
    local media_id = type(result) == "number" and result or (type(result) == "table" and tonumber(result.insertId))
    if not media_id then
        delete_remote_file(verified.remote_id)
        Bridge.Debug(
            "error",
            "[sky_phone][media-debug] Database insert did not return a media ID (source=%s, correlation=%s, result-type=%s).",
            tostring(src),
            diagnostic_text(state.correlation_id, 80),
            type(result)
        )
        upload_result(src, state.correlation_id, false, "request_failed")
        return
    end
    media_debug(
        "Media upload completed successfully (source=%s, correlation=%s, media-id=%s).",
        tostring(src),
        diagnostic_text(state.correlation_id, 80),
        tostring(media_id)
    )
    upload_result(src, state.correlation_id, true, nil, {
        id = media_id,
        url = verified.url,
        mediaType = state.media_type,
        favorite = false,
        createdAt = os.time() * 1000,
    })
end)

RegisterNetEvent("sky_phone:media:cancel-upload", function(data)
    local src = source
    local request_id = type(data) == "table" and data.requestId or nil
    local state = type(request_id) == "string" and pending_uploads[request_id] or nil
    if state and state.source == src and not state.completing then
        pending_uploads[request_id] = nil
        upload_result(src, state.correlation_id, false, "cancelled")
    end
end)

RegisterNetEvent("sky_phone:media:fail-upload", function(data)
    local src = source
    local request_id = type(data) == "table" and data.requestId or nil
    local state = type(request_id) == "string" and pending_uploads[request_id] or nil
    if not state or state.source ~= src or state.completing then
        Bridge.Debug(
            "warn",
            "[sky_phone][media-debug] Rejected client upload failure report (source=%s, request-id=%s, session=%s, owner-match=%s, completing=%s).",
            tostring(src),
            type(request_id) == "string" and "present" or "invalid",
            state and "present" or "missing",
            tostring(state and state.source == src),
            tostring(state and state.completing)
        )
        return
    end
    local allowed_errors = {
        capture_failed = true,
        unsupported = true,
        upload_failed = true,
        upload_timeout = true,
    }
    pending_uploads[request_id] = nil
    local error_code = allowed_errors[data.error] and data.error or "upload_failed"
    Bridge.Debug(
        "error",
        "[sky_phone][media-debug] Client-reported upload failure (source=%s, correlation=%s, error=%s, stage=%s, status=%s, detail=%s).",
        tostring(src),
        diagnostic_text(state.correlation_id, 80),
        diagnostic_text(error_code, 80),
        diagnostic_text(data.debugStage, 40),
        diagnostic_text(data.debugStatus, 20),
        diagnostic_text(data.debugMessage, 240)
    )
    upload_result(src, state.correlation_id, false, error_code)
end)

local function is_required_flare_profile_photo(media_id)
    local rows = Bridge.Database.Query([[
        SELECT photo.`profile_id`
        FROM `sky_phone_flare_profile_photos` photo
        JOIN `sky_phone_flare_profiles` profile ON profile.`id` = photo.`profile_id`
        WHERE photo.`media_id` = ?
            AND NOT EXISTS (
                SELECT 1
                FROM `sky_phone_flare_profile_photos` other_photo
                JOIN `sky_phone_media` other_media
                    ON other_media.`id` = other_photo.`media_id`
                    AND other_media.`account_id` = profile.`account_id`
                    AND other_media.`media_type` = 'photo'
                WHERE other_photo.`profile_id` = photo.`profile_id`
                    AND other_photo.`media_id` <> photo.`media_id`
                    AND other_media.`url` LIKE 'https://%'
            )
        LIMIT 1
    ]], { media_id })
    return rows[1] ~= nil
end

local function delete_owned_media(src, owner, media_id)
    local condition, params = owner_condition(owner)
    local query_params = { media_id }
    for _, value in ipairs(params) do
        query_params[#query_params + 1] = value
    end
    local rows = Bridge.Database.Query(([[
        SELECT `id`, `remote_id`, `origin`, `media_type`, `url` FROM `sky_phone_media`
        WHERE `id` = ? AND %s AND `media_type` IN ('photo', 'video') LIMIT 1
    ]]):format(condition), query_params)
    local row = rows[1]
    if not row then
        return false, "not_found"
    end
    if row.media_type == "photo" and is_required_flare_profile_photo(media_id) then
        return false, "profile_photo_required"
    end
    local delete_key = row.origin == "phone_upload" and row.remote_id or ("import:%s"):format(media_id)
    if pending_deletes[delete_key] then
        return false, "operation_in_progress"
    end
    pending_deletes[delete_key] = src
    if row.origin == "phone_upload" then
        local references = Bridge.Database.Query(
            "SELECT COUNT(*) AS `count` FROM `sky_phone_media` WHERE `remote_id` = ?",
            { row.remote_id }
        )
        if (tonumber(references[1] and references[1].count) or 0) <= 1 then
            local deleted, delete_error = delete_remote_file(row.remote_id)
            if not deleted then
                pending_deletes[delete_key] = nil
                return false, delete_error
            end
        end
    end
    Bridge.Database.Query(("DELETE FROM `sky_phone_media` WHERE `id` = ? AND %s"):format(condition), query_params)
    pending_deletes[delete_key] = nil
    return true, nil, row.url
end

RegisterNetEvent("sky_phone:media:delete", function(data)
    local src = source
    data = type(data) == "table" and data or {}
    local correlation_id = data.correlationId
    local media_id = tonumber(data.id)
    if type(correlation_id) ~= "string" or #correlation_id > 80 or not media_id then
        delete_result(src, correlation_id, false, "invalid_request", media_id)
        return
    end
    if not SkyPhone.AllowOperation(src, "media_delete", 30, 60) then
        delete_result(src, correlation_id, false, "rate_limited", media_id)
        return
    end
    local owner, error_response = session_owner(src)
    if not owner then
        delete_result(src, correlation_id, false, error_response.error, media_id)
        return
    end
    local deleted, delete_error, deleted_link = delete_owned_media(src, owner, media_id)
    if not deleted then
        delete_result(src, correlation_id, false, delete_error, media_id)
        return
    end
    local phone_number = owner.phone_number
    if phone_number and deleted_link then
        TriggerEvent("sky_phone:server:galleryMediaDeleted", src, phone_number, deleted_link)
    end
    delete_result(src, correlation_id, true, nil, media_id)
end)

RegisterNetEvent("sky_phone:media:delete-many", function(data)
    local src = source
    data = type(data) == "table" and data or {}
    local correlation_id = data.correlationId
    if type(correlation_id) ~= "string" or #correlation_id > 80 or type(data.ids) ~= "table" then
        delete_many_result(src, correlation_id, false, "invalid_request", {})
        return
    end
    local media_ids = {}
    local seen_ids = {}
    for _, value in ipairs(data.ids) do
        local media_id = tonumber(value)
        if media_id and media_id > 0 and media_id == math.floor(media_id) and not seen_ids[media_id] then
            seen_ids[media_id] = true
            media_ids[#media_ids + 1] = media_id
        end
    end
    if #media_ids < 1 or #media_ids > 50 then
        delete_many_result(src, correlation_id, false, "invalid_request", {})
        return
    end
    if not SkyPhone.AllowOperation(src, "media_delete_many", 10, 60) then
        delete_many_result(src, correlation_id, false, "rate_limited", {})
        return
    end
    local owner, error_response = session_owner(src)
    if not owner then
        delete_many_result(src, correlation_id, false, error_response.error, {})
        return
    end
    local deleted_ids = {}
    for _, media_id in ipairs(media_ids) do
        local deleted, delete_error, deleted_link = delete_owned_media(src, owner, media_id)
        if not deleted then
            delete_many_result(src, correlation_id, false, delete_error, deleted_ids)
            return
        end
        local phone_number = owner.phone_number
        if phone_number and deleted_link then
            TriggerEvent("sky_phone:server:galleryMediaDeleted", src, phone_number, deleted_link)
        end
        deleted_ids[#deleted_ids + 1] = media_id
    end
    delete_many_result(src, correlation_id, true, nil, deleted_ids)
end)

function SkyPhoneMedia.GetDeviceRemoteIds(imei)
    local rows = Bridge.Database.Query([[
        SELECT `id`, `remote_id` FROM `sky_phone_media`
        WHERE `account_id` IS NULL AND `device_imei` = ? AND `origin` = 'phone_upload'
    ]], { imei })
    return rows
end

function SkyPhoneMedia.CleanupRemoteFiles(rows)
    CreateThread(function()
        local checked = {}
        for _, row in ipairs(rows) do
            local references = checked[row.remote_id] and { { count = 1 } } or Bridge.Database.Query(
                "SELECT COUNT(*) AS `count` FROM `sky_phone_media` WHERE `remote_id` = ?",
                { row.remote_id }
            )
            checked[row.remote_id] = true
            local in_use = (tonumber(references[1] and references[1].count) or 0) > 0
            local deleted, delete_error = true, nil
            if not in_use then
                deleted, delete_error = delete_remote_file(row.remote_id)
            end
            if not deleted then
                Bridge.Debug(
                    "warn",
                    "[sky_phone] Could not delete remote media %s during factory reset: %s.",
                    tostring(row.id),
                    tostring(delete_error)
                )
            end
        end
    end)
end

AddEventHandler("playerDropped", function()
    local src = source
    for request_id, state in pairs(pending_uploads) do
        if state.source == src then
            pending_uploads[request_id] = nil
        end
    end
end)

if SkyPhoneMediaProviderConfig.FiveManageApiKey() == "" then
    Bridge.Debug(
        "warn",
        "[sky_phone] FiveManage media integration is disabled because Config.Media.FiveManage.ApiKey is empty in config/media.lua. Camera photo and video uploads, Voice Memo uploads, remote Gallery deletion, and FiveManage imports are unavailable. Add a FiveManage V3 token with Media access and restart sky_phone.",
        { always = true }
    )
end
end)
