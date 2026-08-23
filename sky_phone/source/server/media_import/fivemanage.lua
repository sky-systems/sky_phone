local function api_key(website)
    return SkyPhoneMediaProviderConfig.FiveManageApiKey(website.ApiKey)
end

local function provider_error(response, not_found_error)
    if response.status == 0 then
        return "import_source_unavailable"
    end
    if response.status == 401 or response.status == 403 then
        return "import_provider_unauthorized"
    end
    if response.status == 404 and not_found_error then
        return not_found_error
    end
    return "import_provider_failed"
end

local function decode_response(response, not_found_error)
    if type(response) ~= "table" or response.status < 200 or response.status >= 300 then
        return nil, provider_error(response or { status = 0 }, not_found_error)
    end

    local success, decoded = pcall(json.decode, response.body or "")
    if not success or type(decoded) ~= "table" then
        return nil, "import_provider_failed"
    end
    return decoded
end

local function media_type(value)
    local normalized = type(value) == "string" and value:lower() or ""
    if normalized == "image" or normalized:find("image/", 1, true) == 1 then
        return "photo"
    end
    if normalized == "video" or normalized:find("video/", 1, true) == 1 then
        return "video"
    end
    return nil
end

local media_extensions = {
    gif = true,
    jpeg = true,
    jpg = true,
    mov = true,
    mp4 = true,
    png = true,
    webm = true,
    webp = true,
}

local function public_file_id(url)
    local path = type(url) == "string" and url:match("^https://[^/%?#]+(/[^?#]*)") or nil
    local segment = path and path:match("/([^/]+)$") or nil
    if not segment or segment == "" or segment:find("%", 1, true) then
        return nil
    end

    local extension = segment:match("%.([%w]+)$")
    if extension and media_extensions[extension:lower()] then
        segment = segment:sub(1, -#extension - 2)
    end
    if #segment < 1 or #segment > 128 or not segment:match("^[%w_%-]+$") then
        return nil
    end
    return segment
end

local function normalize_file(file)
    if type(file) ~= "table" then
        return {}
    end
    return {
        externalId = file.id,
        filename = file.filename,
        mediaType = media_type(file.type or file.mimeType),
        mimeType = file.mimeType or file.type,
        size = file.size,
        url = file.url,
    }
end

local function resolve_file(website, external_id)
    local provider_url = tostring(website.BaseUrl or Config.Media.FiveManage.BaseUrl):gsub("/+$", "")
    local response = SkyPhoneMediaImport.HttpRequest(
        ("%s/%s"):format(provider_url, SkyPhoneMediaImport.UrlEncode(external_id)),
        { ["Authorization"] = api_key(website) },
        tonumber(website.RequestTimeoutMs or Config.Media.FiveManage.RequestTimeoutMs) or 10000
    )
    local decoded, response_error = decode_response(response, "import_media_unavailable")
    if not decoded then
        return nil, response_error
    end

    local file = type(decoded.data) == "table" and decoded.data or decoded
    if file.id ~= external_id then
        return nil, "invalid_import_media"
    end
    return normalize_file(file)
end

local function probe_public_url(website, url)
    local timeout = tonumber(website.RequestTimeoutMs or Config.Media.FiveManage.RequestTimeoutMs) or 10000
    local response = SkyPhoneMediaImport.HttpRequest(url, {}, timeout, "HEAD")
    local content_type = SkyPhoneMediaImport.ResponseHeader(response.headers, "content-type")
    local content_length = tonumber(SkyPhoneMediaImport.ResponseHeader(response.headers, "content-length"))

    if response.status == 0 or (response.status >= 200 and response.status < 300
        and (not content_type or not content_length or content_length <= 0))
    then
        Bridge.Debug(
            "debug",
            "[sky_phone] FiveManage HEAD probe did not provide usable metadata; trying a one-byte range request."
        )
        response = SkyPhoneMediaImport.HttpRequest(url, { ["Range"] = "bytes=0-0" }, timeout)
        content_type = SkyPhoneMediaImport.ResponseHeader(response.headers, "content-type")
        local content_range = SkyPhoneMediaImport.ResponseHeader(response.headers, "content-range")
        content_length = type(content_range) == "string" and tonumber(content_range:match("/(%d+)$"))
            or tonumber(SkyPhoneMediaImport.ResponseHeader(response.headers, "content-length"))
    end

    if response.status == 0 then
        return nil, "import_source_unavailable"
    end
    if response.status < 200 or response.status >= 300 then
        Bridge.Debug(
            "warn",
            "[sky_phone] FiveManage public URL probe returned HTTP %s.",
            tostring(response.status),
            { always = true }
        )
        return nil, "import_url_unavailable"
    end

    local normalized_type = media_type(content_type)
    if not normalized_type then
        return nil, "import_media_not_allowed"
    end
    if not content_length or content_length <= 0 or content_length ~= math.floor(content_length) then
        return nil, "import_size_unavailable"
    end

    local url_path = url:match("^https://[^/]+(/[^?#]*)") or ""
    local external_id = ("url:%08x%08x"):format(
        joaat(url) & 0xffffffff,
        joaat("sky_phone:" .. url) & 0xffffffff
    )
    return {
        externalId = external_id,
        filename = url_path:match("/([^/]+)$") or external_id,
        mediaType = normalized_type,
        mimeType = type(content_type) == "string"
            and content_type:lower():match("^%s*([^;%s]+)") or nil,
        size = content_length,
        url = url,
    }
end

SkyPhoneMediaImport.RegisterAdapter("fivemanage", {
    Validate = function(website)
        local url = tostring(website.BaseUrl or Config.Media.FiveManage.BaseUrl):gsub("/+$", "")
        if not url:match("^https://") or #url > Config.Media.UrlMaxLength then
            return false, "invalid_base_url"
        end
        if type(website.Path) ~= "string" or website.Path == "" or #website.Path > 180 then
            return false, "missing_import_path"
        end
        if api_key(website) == "" then
            return false, "missing_api_key"
        end
        return true
    end,

    List = function(website, requested_type, page, limit)
        local provider_type = requested_type == "photo" and "image" or "video"
        local provider_url = tostring(website.BaseUrl or Config.Media.FiveManage.BaseUrl):gsub("/+$", "")
        local url = ("%s?page=%s&limit=%s&type=%s&path=%s"):format(
            provider_url,
            page,
            limit,
            provider_type,
            SkyPhoneMediaImport.UrlEncode(website.Path)
        )
        local response = SkyPhoneMediaImport.HttpRequest(
            url,
            { ["Authorization"] = api_key(website) },
            tonumber(website.RequestTimeoutMs or Config.Media.FiveManage.RequestTimeoutMs) or 10000
        )
        local decoded, response_error = decode_response(response)
        if not decoded then
            return nil, response_error
        end

        local files = type(decoded.data) == "table" and decoded.data or {}
        local items = {}
        for _, file in ipairs(files) do
            items[#items + 1] = normalize_file(file)
        end
        local pagination = type(decoded.pagination) == "table" and decoded.pagination or {}
        local total = math.max(0, math.floor(tonumber(pagination.total) or #items))
        local current_page = math.max(1, math.floor(tonumber(pagination.page) or page))
        local page_limit = math.max(1, math.floor(tonumber(pagination.limit) or limit))
        return {
            hasMore = current_page * page_limit < total,
            items = items,
            total = total,
        }
    end,

    Resolve = resolve_file,

    ResolveUrl = function(website, url)
        local external_id = public_file_id(url)
        if external_id then
            local file, resolve_error = resolve_file(website, external_id)
            if file then
                Bridge.Debug(
                    "debug",
                    "[sky_phone] FiveManage URL resolved through authenticated metadata for file '%s'.",
                    external_id
                )
                return file
            end
            if resolve_error == "import_provider_unauthorized" then
                return nil, resolve_error
            end
            Bridge.Debug(
                "debug",
                "[sky_phone] FiveManage metadata lookup for file '%s' failed with '%s'; probing the public URL.",
                external_id,
                tostring(resolve_error)
            )
        end
        return probe_public_url(website, url)
    end,
})
