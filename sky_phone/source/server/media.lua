Bridge.Database.AfterMigration("sky_phone", function()
SkyPhoneMedia = {}

local pending_uploads = {}
local pending_deletes = {}

local function media_config()
    return Config.Media.FiveManage
end

local function api_configured()
    local api_key = media_config().ApiKey
    return type(api_key) == "string" and api_key ~= "" and api_key ~= "YOUR_API_TOKEN"
end

local function http_request(url, method, body, headers, timeout_ms)
    local request = promise.new()
    local settled = false
    PerformHttpRequest(url, function(status, response_body, response_headers)
        if settled then
            return
        end
        settled = true
        request:resolve({
            body = response_body,
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
    return Await(request)
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

local function request_presigned_url()
    if not api_configured() then
        return nil, "missing_config"
    end
    local config = media_config()
    local response = http_request(
        tostring(config.BaseUrl):gsub("/+$", "") .. "/presigned-url",
        "GET",
        "",
        { ["Authorization"] = config.ApiKey },
        tonumber(config.RequestTimeoutMs) or 10000
    )
    local data, response_error = decode_response(response)
    if not data then
        return nil, response_error
    end
    local presigned_url = data.presignedUrl or data.presigned_url
    if type(presigned_url) ~= "string" or presigned_url == "" then
        return nil, "missing_presigned_url"
    end
    return presigned_url
end

local function get_remote_file(remote_id)
    if not api_configured() then
        return nil, "missing_config"
    end
    local config = media_config()
    local response = http_request(
        ("%s/%s"):format(tostring(config.BaseUrl):gsub("/+$", ""), remote_id),
        "GET",
        "",
        { ["Authorization"] = config.ApiKey },
        tonumber(config.RequestTimeoutMs) or 10000
    )
    return decode_response(response)
end

local function delete_remote_file(remote_id)
    if not api_configured() then
        return false, "missing_config"
    end
    local config = media_config()
    local response = http_request(
        ("%s/%s"):format(tostring(config.BaseUrl):gsub("/+$", ""), remote_id),
        "DELETE",
        "",
        { ["Authorization"] = config.ApiKey },
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

local function upload_result(source, correlation_id, success, error_code, media)
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

local function parse_metadata(value)
    if type(value) == "table" then
        return value
    end
    if type(value) ~= "string" then
        return nil
    end
    local success, decoded = pcall(json.decode, value)
    return success and type(decoded) == "table" and decoded or nil
end

local function valid_remote_id(value)
    return type(value) == "string" and #value >= 4 and #value <= 128 and value:match("^[%w_%-]+$") ~= nil
end

local function verify_remote_upload(state, remote_id, uploaded_url)
    if not valid_remote_id(remote_id) or type(uploaded_url) ~= "string" or #uploaded_url > 2048
        or not uploaded_url:match("^https://")
    then
        return nil, "invalid_upload"
    end
    local remote, remote_error = get_remote_file(remote_id)
    if not remote then
        return nil, remote_error
    end
    if remote.id ~= remote_id then
        return nil, "invalid_upload"
    end
    if remote.url ~= uploaded_url and remote.originalUrl ~= uploaded_url then
        return nil, "invalid_upload"
    end
    local remote_type = tostring(remote.type or remote.mimeType or ""):lower()
    if state.media_type == "photo" and remote_type ~= "" and not remote_type:find("image", 1, true) then
        return nil, "invalid_media_type"
    end
    if state.media_type == "video" and remote_type ~= "" and not remote_type:find("video", 1, true) then
        return nil, "invalid_media_type"
    end
    local metadata = parse_metadata(remote.metadata)
    if not metadata or metadata.captureToken ~= state.capture_token then
        return nil, "invalid_upload_token"
    end
    return {
        remote_id = remote_id,
        url = remote.url or uploaded_url,
    }
end

local function expire_upload(request_id)
    local state = pending_uploads[request_id]
    if not state or state.completing then
        return
    end
    pending_uploads[request_id] = nil
    upload_result(state.source, state.correlation_id, false, "upload_timeout")
end

Bridge.Callbacks.Register("sky_phone:gallery:list", function(source, data)
    local owner, error_response = session_owner(source)
    if not owner then
        return error_response
    end
    data = data or {}
    local limit = math.max(1, math.min(math.floor(tonumber(data.limit) or Config.Media.PageSize), 100))
    local offset = math.max(0, math.floor(tonumber(data.offset) or 0))
    local media_type = data.mediaType
    if media_type ~= "photo" and media_type ~= "video" then
        media_type = nil
    end
    local condition, params = owner_condition(owner)
    if media_type then
        condition = condition .. " AND `media_type` = ?"
        params[#params + 1] = media_type
    end
    params[#params + 1] = limit
    params[#params + 1] = offset
    local rows = Bridge.Database.Query(([[
        SELECT `id`, `url`, `media_type` AS `mediaType`,
            UNIX_TIMESTAMP(`created_at`) * 1000 AS `createdAt`
        FROM `sky_phone_media`
        WHERE %s
        ORDER BY `created_at` DESC, `id` DESC
        LIMIT ? OFFSET ?
    ]]):format(condition), params)
    for _, row in ipairs(rows) do
        row.id = tonumber(row.id)
        row.createdAt = tonumber(row.createdAt) or 0
    end
    return { success = true, data = rows }
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
    return Await(request)
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
    local api_key = Config.Media.GiphyApiKey
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
    return {
        success = true,
        data = {
            videoBitrateKbps = tonumber(Config.Media.Video.BitrateKbps) or 1500,
        },
    }
end)

RegisterNetEvent("sky_phone:media:request-upload", function(data)
    local src = source
    data = data or {}
    local correlation_id = data.correlationId
    local media_type = data.mediaType
    if type(correlation_id) ~= "string" or #correlation_id > 80
        or (media_type ~= "photo" and media_type ~= "video")
    then
        upload_result(src, correlation_id, false, "invalid_request")
        return
    end
    if not SkyPhone.AllowOperation(src, "media_write", 20, 60) then
        upload_result(src, correlation_id, false, "rate_limited")
        return
    end
    local owner, error_response = session_owner(src)
    if not owner then
        upload_result(src, correlation_id, false, error_response.error)
        return
    end
    local presigned_url, presigned_error = request_presigned_url()
    if not presigned_url then
        upload_result(src, correlation_id, false, presigned_error)
        return
    end
    local ids = Bridge.Database.Query("SELECT UUID() AS `request_id`, UUID() AS `capture_token`", {})
    local request_id = ids[1] and ids[1].request_id
    local capture_token = ids[1] and ids[1].capture_token
    if type(request_id) ~= "string" or type(capture_token) ~= "string" then
        upload_result(src, correlation_id, false, "request_failed")
        return
    end
    pending_uploads[request_id] = {
        capture_token = capture_token,
        correlation_id = correlation_id,
        media_type = media_type,
        owner = owner,
        source = src,
    }
    SetTimeout(tonumber(Config.Media.UploadSessionTimeoutMs) or 60000, function()
        expire_upload(request_id)
    end)
    TriggerClientEvent("sky_phone:media:upload-ready", src, {
        captureToken = capture_token,
        correlationId = correlation_id,
        mediaType = media_type,
        photo = Config.Media.Photo,
        presignedUrl = presigned_url,
        requestId = request_id,
        uploadTimeoutMs = media_config().UploadTimeoutMs,
        video = Config.Media.Video,
    })
end)

RegisterNetEvent("sky_phone:media:complete-upload", function(data)
    local src = source
    data = data or {}
    local request_id = data.requestId
    local state = type(request_id) == "string" and pending_uploads[request_id] or nil
    if not state or state.source ~= src or state.completing then
        return
    end
    state.completing = true
    local owner, error_response = session_owner(src)
    if not owner or not owners_match(owner, state.owner) then
        pending_uploads[request_id] = nil
        upload_result(src, state.correlation_id, false, error_response and error_response.error or "owner_changed")
        return
    end
    local verified, verify_error = verify_remote_upload(state, data.remoteId, data.url)
    if not verified then
        pending_uploads[request_id] = nil
        upload_result(src, state.correlation_id, false, verify_error)
        return
    end
    local result
    if owner.account_id then
        result = Bridge.Database.Query([[
            INSERT INTO `sky_phone_media` (`account_id`, `device_imei`, `url`, `remote_id`, `media_type`)
            VALUES (?, NULL, ?, ?, ?)
        ]], { owner.account_id, verified.url, verified.remote_id, state.media_type })
    else
        result = Bridge.Database.Query([[
            INSERT INTO `sky_phone_media` (`account_id`, `device_imei`, `url`, `remote_id`, `media_type`)
            VALUES (NULL, ?, ?, ?, ?)
        ]], { owner.imei, verified.url, verified.remote_id, state.media_type })
    end
    pending_uploads[request_id] = nil
    local media_id = type(result) == "number" and result or (type(result) == "table" and tonumber(result.insertId))
    if not media_id then
        delete_remote_file(verified.remote_id)
        upload_result(src, state.correlation_id, false, "request_failed")
        return
    end
    upload_result(src, state.correlation_id, true, nil, {
        id = media_id,
        url = verified.url,
        mediaType = state.media_type,
        createdAt = os.time() * 1000,
    })
end)

RegisterNetEvent("sky_phone:media:cancel-upload", function(data)
    local src = source
    local request_id = data and data.requestId
    local state = type(request_id) == "string" and pending_uploads[request_id] or nil
    if state and state.source == src and not state.completing then
        pending_uploads[request_id] = nil
        upload_result(src, state.correlation_id, false, "cancelled")
    end
end)

RegisterNetEvent("sky_phone:media:fail-upload", function(data)
    local src = source
    local request_id = data and data.requestId
    local state = type(request_id) == "string" and pending_uploads[request_id] or nil
    if not state or state.source ~= src or state.completing then
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
    upload_result(src, state.correlation_id, false, error_code)
end)

RegisterNetEvent("sky_phone:media:delete", function(data)
    local src = source
    data = data or {}
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
    local condition, params = owner_condition(owner)
    local query_params = { media_id }
    for _, value in ipairs(params) do
        query_params[#query_params + 1] = value
    end
    local rows = Bridge.Database.Query(([[
        SELECT `id`, `remote_id` FROM `sky_phone_media`
        WHERE `id` = ? AND %s LIMIT 1
    ]]):format(condition), query_params)
    local row = rows[1]
    if not row then
        delete_result(src, correlation_id, false, "not_found", media_id)
        return
    end
    if pending_deletes[media_id] then
        delete_result(src, correlation_id, false, "operation_in_progress", media_id)
        return
    end
    pending_deletes[media_id] = src
    local deleted, delete_error = delete_remote_file(row.remote_id)
    if not deleted then
        pending_deletes[media_id] = nil
        delete_result(src, correlation_id, false, delete_error, media_id)
        return
    end
    Bridge.Database.Query(("DELETE FROM `sky_phone_media` WHERE `id` = ? AND %s"):format(condition), query_params)
    pending_deletes[media_id] = nil
    delete_result(src, correlation_id, true, nil, media_id)
end)

function SkyPhoneMedia.GetDeviceRemoteIds(imei)
    local rows = Bridge.Database.Query([[
        SELECT `id`, `remote_id` FROM `sky_phone_media`
        WHERE `account_id` IS NULL AND `device_imei` = ?
    ]], { imei })
    return rows
end

function SkyPhoneMedia.CleanupRemoteFiles(rows)
    CreateThread(function()
        for _, row in ipairs(rows) do
            local deleted, delete_error = delete_remote_file(row.remote_id)
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

if not api_configured() then
    print("^3[sky_phone] Camera and Gallery uploads are disabled until Config.Media.FiveManage.ApiKey is set in config/media.lua.^7")
end
end)
