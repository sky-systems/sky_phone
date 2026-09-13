-- Download only persisted media from the phone's configured media hosts.
-- Files are fetched at delivery time, never retained throughout the log queue.
local active, sequence = 0, 0
local warned_at = {}
local function warn(reason)
    if warned_at[reason] and os.time() - warned_at[reason] < 60 then return end
    warned_at[reason] = os.time()
    Bridge.Debug("warn", "[sky_phone] Discord video attachment unavailable (%s); retaining media link.", reason)
end
local function allowed_url(url)
    if type(url) ~= "string" or #url > 2048 or url:find("[%c]") then return false end
    local host = url:match("^https://([%w%.%-]+)/[^%s]+$")
    if not host or host:find("%.%.") or host:match("^[%d%.]+$") then return false end
    host = host:lower()
    if host == "r2.fivemanage.com" then return true end
    local imports = Config and Config.Media and Config.Media.Import
    for _, website in ipairs(imports and imports.Enabled and imports.Websites or {}) do
        if website.Enabled then
            for _, allowed in ipairs(website.AllowedMediaHosts or {}) do
                allowed = type(allowed) == "string" and allowed:lower() or ""
                if allowed ~= "" and (host == allowed or host:sub(-#allowed - 1) == "." .. allowed) then return true end
            end
        end
    end
    return false
end

function SkyPhoneLog.PrepareMedia(item, callback)
    if not item.videos or #item.videos == 0 then callback(item.body, "application/json", function() end); return true end
    if active >= 2 then return false end
    active = active + 1
    local released = false
    local function release()
        if not released then released = true; active = active - 1 end
    end
    local files, fallbacks, total = {}, {}, 0
    local maximum = math.max(1, math.min(20 * 1024 * 1024, tonumber(WebHooks.VideoMaxBytes) or 20 * 1024 * 1024))
    local function finish()
        local ok, body, content_type = pcall(function()
            local payload = json.decode(item.body)
            -- Failed/oversized videos stay visible as links; successful uploads
            -- are actual Discord attachments, playable without an embed-field URL.
            local links = table.concat(fallbacks, "\n")
            if #links <= 2000 and links ~= "" then payload.content = links
            elseif links ~= "" then
                local embed = payload.embeds[1]
                local used = #links + #(embed.title or "") + #(embed.author and embed.author.name or "")
                    + #(embed.footer and embed.footer.text or "") + 80
                for _, field in ipairs(embed.fields or {}) do used = used + #field.name + #field.value end
                local budget = math.max(0, 5900 - used)
                local description = embed.description or ""
                if #description > budget then
                    while budget > 0 and description:byte(budget + 1) >= 128 and description:byte(budget + 1) < 192 do budget = budget - 1 end
                    embed.description = description:sub(1, budget)
                end
                payload.embeds[#payload.embeds + 1] = { description = links }
            end
            if #files == 0 then return json.encode(payload), "application/json" end
            sequence = sequence + 1
            local boundary = "sky_phone_" .. os.time() .. "_" .. sequence
            -- A delimiter must not occur in any binary attachment.
            for _, file in ipairs(files) do
                while file.body:find(boundary, 1, true) do boundary = boundary .. "x" end
            end
            local parts = {}
            payload.attachments = {}
            for index, file in ipairs(files) do
                local filename = "video-" .. index .. file.extension
                payload.attachments[index] = { id = index - 1, filename = filename }
                parts[#parts + 1] = "--" .. boundary .. '\r\nContent-Disposition: form-data; name="files['
                    .. (index - 1) .. ']"; filename="' .. filename .. '"\r\nContent-Type: '
                    .. file.mime .. "\r\n\r\n" .. file.body .. "\r\n"
            end
            parts[#parts + 1] = "--" .. boundary .. '\r\nContent-Disposition: form-data; name="payload_json"'
                .. "\r\nContent-Type: application/json\r\n\r\n" .. json.encode(payload) .. "\r\n--" .. boundary .. "--\r\n"
            return table.concat(parts), "multipart/form-data; boundary=" .. boundary
        end)
        files = {}
        if not ok then warn("serialization"); release(); callback(item.body, "application/json", function() end); return end
        callback(body, content_type, release)
    end
    local fetch
    fetch = function(index)
        local media = item.videos[index]
        if not media then finish(); return end
        local size
        local mime = media.mime_type
        local extension = mime == "video/webm" and ".webm" or mime == "video/mp4" and ".mp4" or nil
        local function fallback(reason)
            fallbacks[#fallbacks + 1] = media.url
            warn(reason)
            fetch(index + 1)
        end
        if item.skipVideos or not allowed_url(media.url) then
            fallback(item.skipVideos and "Discord rejected upload" or "host not allowed"); return
        end
        local completed = false
        local function receive(status, body, headers)
            if completed then return end
            completed = true
            local response_type
            for key, value in pairs(type(headers) == "table" and headers or {}) do
                if tostring(key):lower() == "content-type" then response_type = tostring(value):lower():match("^[^;]+") end
            end
            if (status ~= 200 and status ~= 206) or type(body) ~= "string" or #body == 0
                or #body ~= size or #body + total > maximum
                or (response_type and response_type ~= mime and response_type ~= "application/octet-stream") then
                fallback("download failed, incomplete or unsupported"); return
            end
            total = total + #body
            files[#files + 1] = { body = body, mime = mime, extension = extension }
            fetch(index + 1)
        end
        local inspected = false
        local function inspect(status, _, headers)
            if inspected then return end
            inspected = true
            for key, value in pairs(type(headers) == "table" and headers or {}) do
                key = tostring(key):lower()
                if key == "content-length" then size = tonumber(value) end
                if key == "content-type" and not extension then
                    mime = tostring(value):lower():match("^[^;]+")
                    extension = mime == "video/webm" and ".webm" or mime == "video/mp4" and ".mp4" or nil
                end
            end
            if status ~= 200 or not extension or not size or size <= 0 then fallback("metadata unavailable or unsupported"); return end
            if size + total > maximum then fallback("configured size limit exceeded"); return end
            SetTimeout(30000, function() receive(0) end)
            local ok = pcall(PerformHttpRequest, media.url, receive, "GET", "",
                { Range = "bytes=0-" .. (maximum - total) }, { followLocation = false })
            if not ok then receive(0) end
        end
        SetTimeout(30000, function() inspect(0) end)
        local ok = pcall(PerformHttpRequest, media.url, inspect, "HEAD", "", {}, { followLocation = false })
        if not ok then inspect(0) end
    end
    fetch(1)
    return true
end
