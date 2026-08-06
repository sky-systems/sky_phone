local function current_device(source)
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

local function await_http(url, method, body, headers)
    local request = promise.new()
    PerformHttpRequest(url, function(status, response_body)
        request:resolve({
            body = response_body,
            status = status,
        })
    end, method, body or "", headers or {})
    return Citizen.Await(request)
end

local function parse_json(value)
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
    local device, error_response = current_device(source)
    if not device then
        return error_response
    end
    local query = type(data.query) == "string" and data.query:match("^%s*(.-)%s*$") or ""
    local offset = math.floor(tonumber(data.offset) or 0)
    if #query > 60 or offset < 0 or offset > 500 then
        return { success = false, error = "invalid_request" }
    end
    local api_key = GetConvar("sky_phone_giphy_api_key", "")
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
    local response = await_http(url, "GET")
    if response.status < 200 or response.status >= 300 then
        Bridge.Debug("error", "[sky_phone] GIPHY request failed with HTTP %s.", tostring(response.status))
        return { success = false, error = "gif_provider_failed" }
    end
    local payload = parse_json(response.body)
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
