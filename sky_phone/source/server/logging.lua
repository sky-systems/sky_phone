-- Audit records are server-owned. Only authorized Phonepanel callbacks may edit settings.
SkyPhoneLog = {}

local contexts = setmetatable({}, { __mode = "k" })
local queues = {}
local queued = 0
local global_retry_at = 0
local warned = {}
local max_record_bytes = 64000
local max_nodes = 2000
local max_parts = 24

local function diagnostic(key, message)
    local now = os.time()
    if warned[key] and now - warned[key] < 60 then return end
    warned[key] = now
    -- Never print HTTP responses, exception strings or webhook URLs/tokens.
    Bridge.Debug("warn", "[sky_phone] Discord logging: %s", message)
end

local function limit(name, fallback, maximum)
    local value = tonumber(WebHooks and WebHooks[name])
    if not value or value ~= value then return fallback end
    return math.max(1, math.min(maximum, math.floor(value)))
end

function SkyPhoneLog.IsValidWebhook(url)
    if type(url) ~= "string" or #url > 512 then return false end
    local host, path = url:match("^https://([^/]+)(/.*)$")
    return (host == "discord.com" or host == "discordapp.com"
        or host == "canary.discord.com" or host == "ptb.discord.com")
        and (path:match("^/api/webhooks/%d+/[%w_-]+$")
            or path:match("^/api/v%d+/webhooks/%d+/[%w_-]+$")) ~= nil
end

local function webhook(category, action, audience)
    if type(WebHooks) ~= "table" or WebHooks.Enabled == false then return nil end
    local routes = WebHooks
    -- An absent public configuration must never fall back to admin routes.
    if audience == "public" then routes = WebHooks.Public end
    if type(routes) ~= "table" then return nil end
    local url
    if type(routes.Actions) == "table" then url = routes.Actions[action] end
    if url == nil or url == "" then url = routes[category] end
    if url == nil or url == "" then url = routes.Default end
    if url == nil or url == "" or url == false then return nil end
    if SkyPhoneLog.IsValidWebhook(url) then return url .. "?wait=true" end
    diagnostic("url:" .. category, "Invalid webhook configured for " .. category .. ".")
end

function SkyPhoneLog.IsEnabled(category, action)
    return webhook(category, action) ~= nil
end

function SkyPhoneLog.IsPublicEnabled(action)
    local spec = SkyPhoneLog.PublicActions and SkyPhoneLog.PublicActions[action]
    return spec ~= nil and webhook(spec.category, action, "public") ~= nil
end

local function clean_string(value)
    if not utf8.len(value) then value = value:gsub("[\128-\255]", "?") end
    value = value:gsub("https://[%w.%-]*discord[%w.%-]*/api/[%w/_%-]+", "[redacted webhook]")
    value = value:gsub("```", "'''"):gsub("[\0-\8\11\12\14-\31]", "")
    return value
end

local function truncate_utf8(value, maximum)
    if #value <= maximum then return value end
    local last = maximum
    while last > 0 and value:byte(last + 1) >= 128 and value:byte(last + 1) < 192 do last = last - 1 end
    return value:sub(1, last)
end

local function secret_key(key)
    local normalized = tostring(key):lower():gsub("[^a-z0-9]", "")
    return normalized:find("password", 1, true) or normalized:find("passcode", 1, true)
        or normalized:find("token", 1, true) or normalized:find("secret", 1, true)
        or normalized:find("pepper", 1, true) or normalized:find("webhook", 1, true)
        or normalized:find("apikey", 1, true) or normalized:find("presigned", 1, true)
        or normalized == "authorization" or normalized == "salt" or normalized == "hash"
        or normalized == "ip" or normalized == "ipaddress" or normalized == "license" or normalized == "license2"
        or normalized == "session" or normalized == "sessionid" or normalized == "credentials"
        or normalized == "mediapayload" or normalized == "waveform" or normalized == "mediawaveform"
        or normalized == "base64" or normalized == "chunk" or normalized == "payload"
end

local function sanitize(value, budget, seen, depth)
    if budget.nodes <= 0 or budget.bytes <= 0 or depth > 10 then
        return "[log content limit reached]"
    end
    budget.nodes = budget.nodes - 1
    local kind = type(value)
    if kind == "string" then
        local cleaned = clean_string(value)
        if #cleaned > budget.bytes then
            local last = budget.bytes
            while last > 0 and cleaned:byte(last + 1) and cleaned:byte(last + 1) >= 128
                and cleaned:byte(last + 1) < 192 do last = last - 1 end
            cleaned = cleaned:sub(1, last) .. " [log content limit reached]"
        end
        budget.bytes = budget.bytes - #cleaned
        return cleaned
    elseif kind == "boolean" then return value
    elseif kind == "number" then
        return value == value and value ~= math.huge and value ~= -math.huge and value or nil
    elseif kind ~= "table" then return nil end
    if seen[value] then return "[circular value]" end
    seen[value] = true
    local result = {}
    for key, item in pairs(value) do
        if (type(key) == "string" or type(key) == "number") and not secret_key(key) then
            local safe_key = type(key) == "string" and truncate_utf8(clean_string(key), 100) or key
            result[safe_key] = sanitize(item, budget, seen, depth + 1)
            if budget.nodes <= 0 or budget.bytes <= 0 then
                result.logLimit = "Additional content omitted"
                break
            end
        end
    end
    seen[value] = nil
    return result
end

local function safe_value(value)
    return sanitize(value, { bytes = max_record_bytes, nodes = max_nodes }, {}, 0)
end

local function identity(source)
    local actor = { source = source or 0 }
    if source and source > 0 then
        actor.name = GetPlayerName(source)
        if SkyPhone and SkyPhone.GetLogIdentity then
            local session = SkyPhone.GetLogIdentity(source)
            if session then
                actor.accountId = session.accountId
                actor.imei = session.imei
                actor.phoneNumber = session.phoneNumber
            end
        end
    end
    return actor
end

local function header(headers, name)
    for key, value in pairs(type(headers) == "table" and headers or {}) do
        if type(key) == "string" and key:lower() == name then return tonumber(value) end
    end
end

local deliver
local function schedule(url, queue, delay)
    queue.ready_at = math.max(queue.ready_at or 0, GetGameTimer() + math.ceil(delay or 1))
    SetTimeout(math.max(1, math.ceil(delay or 1)), function()
        if queues[url] == queue then deliver(url, queue) end
    end)
end

deliver = function(url, queue)
    if queue.inflight then return end
    local item = queue.items[queue.first]
    if not item then queues[url] = nil return end
    local remaining = math.max(global_retry_at, queue.ready_at or 0) - GetGameTimer()
    if remaining > 0 then schedule(url, queue, remaining) return end
    queue.inflight = true
    local release_media = function() end
    local function complete(status, body, headers)
        release_media()
        queue.inflight = false
        local delay = 400
        local retry = status == 429 or status == 0 or status < 0 or status >= 500
        if status == 429 then
            local ok, response = pcall(json.decode, body or "")
            local seconds = ok and type(response) == "table" and tonumber(response.retry_after) or nil
            seconds = seconds or header(headers, "retry-after") or 1
            if seconds ~= seconds then seconds = 1 end
            delay = math.max(1000, math.min(3600000, math.ceil(seconds * 1000)))
            if ok and type(response) == "table" and response.global then
                global_retry_at = GetGameTimer() + delay
            end
        elseif retry then
            delay = math.min(60000, 1000 * 2 ^ (item.attempts - 1))
        elseif header(headers, "x-ratelimit-remaining") == 0 then
            delay = math.max(400, (header(headers, "x-ratelimit-reset-after") or 1) * 1000)
        end
        if (status == 413 or status == 400) and item.videos and #item.videos > 0 and not item.skipVideos then
            item.skipVideos = true
            diagnostic("video-size", "Discord rejected the video attachment; retrying with media links.")
            schedule(url, queue, delay)
            return
        end
        if retry and item.attempts < limit("MaxAttempts", 5, 10) then
            schedule(url, queue, delay)
            return
        end
        if status < 200 or status >= 300 then
            diagnostic("http:" .. item.category, "Delivery failed for " .. item.category
                .. " (HTTP " .. tostring(status) .. "); record dropped after " .. item.attempts .. " attempt(s).")
        end
        queue.items[queue.first] = nil
        queue.first = queue.first + 1
        queued = queued - 1
        -- Retain the queue until its cooldown ends, including when it is empty.
        queue.inflight = true
        SetTimeout(math.ceil(delay), function()
            queue.inflight = false
            if queues[url] == queue then deliver(url, queue) end
        end)
    end
    local function send(body, content_type, release)
        local remaining = math.max(global_retry_at, queue.ready_at or 0) - GetGameTimer()
        if remaining > 0 then
            SetTimeout(math.ceil(remaining), function() send(body, content_type, release) end)
            return
        end
        release_media = release
        item.attempts = item.attempts + 1
        local completed = false
        local function receive(...)
            if completed then return end
            completed = true
            complete(...)
        end
        SetTimeout(30000, function() receive(0, "", {}) end)
        local ok = pcall(PerformHttpRequest, url, receive, "POST", body,
            { ["Content-Type"] = content_type }, { followLocation = false })
        if not ok then receive(0, "", {}) end
    end
    if not SkyPhoneLog.PrepareMedia(item, send) then
        queue.inflight = false
        schedule(url, queue, 1000)
    end
end

local function queue_pending(category, url, pending)
    if queued + #pending > limit("QueueLimit", 1000, 10000) then
        diagnostic("overflow", "Queue is full; new record dropped. Check channel traffic and webhook delivery.")
        return false
    end
    local queue = queues[url]
    if not queue then
        queue = { items = {}, first = 1, last = 0, inflight = false }
        queues[url] = queue
    end
    for _, item in ipairs(pending) do
        queue.last = queue.last + 1
        queue.items[queue.last] = item
        queued = queued + 1
    end
    schedule(url, queue, 1)
    return true
end

local function enqueue(category, action, status, actor, details)
    local url = webhook(category, action)
    if not url then return false end
    local record = safe_value({ actor = actor, details = details })
    local timestamp = os.time()
    local heading, content = SkyPhoneLog.FormatAudit(category, action, status, record, timestamp)
    local parts = {}
    local first = 1
    while first <= #content and #parts < max_parts do
        local last = math.min(#content, first + 3499)
        while last < #content and content:byte(last + 1) >= 128 and content:byte(last + 1) < 192 do
            last = last - 1
        end
        parts[#parts + 1] = content:sub(first, last)
        first = last + 1
    end
    if first <= #content then
        local labels = SkyPhoneLog.Labels("DiscordAudit").values or {}
        parts[#parts] = parts[#parts] .. "\n" .. (labels.limitReached or "[log content limit reached]")
    end
    if queued + #parts > limit("QueueLimit", 1000, 10000) then
        diagnostic("overflow", "Queue is full; new record dropped. Check channel traffic and webhook delivery.")
        return false
    end
    local pending = {}
    for index, part in ipairs(parts) do
        local title = truncate_utf8(clean_string(heading), 230)
        local payload = {
            username = truncate_utf8(clean_string(tostring(WebHooks.Username or "Sky Phone")), 80),
            avatar_url = type(WebHooks.AvatarUrl) == "string"
                and WebHooks.AvatarUrl:match("^https://%S+$") and WebHooks.AvatarUrl or nil,
            -- Explicit array keeps mentions disabled with FiveM's JSON encoder.
            allowed_mentions = { parse = json.decode("[]") },
            embeds = {{
                title = title,
                description = part,
                color = status == "deleted" and 15158332 or status == "edited" and 16705372 or 3447003,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                footer = { text = "Sky Phone" .. (#parts > 1 and (" · " .. index .. "/" .. #parts) or ""),
                    icon_url = WebHooks.FooterIconUrl ~= "" and WebHooks.FooterIconUrl or nil },
            }},
        }
        pending[#pending + 1] = { body = json.encode(payload), category = category, attempts = 0 }
    end
    return queue_pending(category, url, pending)
end

-- Only logging_public.lua supplies these server-verified, public fields. Never
-- use the audit record, callback request/result or identity as public content.
function SkyPhoneLog.Publish(action, post)
    local spec = SkyPhoneLog.PublicActions and SkyPhoneLog.PublicActions[action]
    if not spec then return false end
    local url = webhook(spec.category, action, "public")
    if not url then return false end
    local ok, result = pcall(function()
        local function text(value, maximum)
            return truncate_utf8(clean_string(tostring(value or "")), maximum)
        end
        local locale = Config and Config.Bridge and Config.Bridge.Locale or "en"
        local labels = Locales and (Locales[locale] or Locales.en)
        labels = labels and labels.DiscordPublic or {}
        local status = post.status or "published"
        local embed = {
            title = text(labels[status] or status, 240),
            description = text(post.body, 3000),
            color = spec.color,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            footer = { text = "Sky Phone", icon_url = WebHooks.FooterIconUrl ~= "" and WebHooks.FooterIconUrl or nil },
        }
        local author = text(post.author_handle or post.author_name, 120):gsub("^@", "")
        if author ~= "" then
            author = "@" .. author
            embed.author = { name = author, icon_url = type(post.author_avatar) == "string"
                and post.author_avatar:match("^https://[^/@%s]+/%S+$") and post.author_avatar or nil }
        end
        local fields = {}
        -- Count bytes conservatively so all text fits Discord's 6000-character
        -- aggregate embed limit, including non-BMP characters and media links.
        local remaining = 5900 - #embed.title - #embed.description - #embed.footer.text - #author
        local function field(name, value)
            if value ~= nil and tostring(value) ~= "" then
                local label = text(labels[name] or name, 80)
                local content = text(SkyPhoneLog.ContentLabel(spec.category, name, value), math.max(0, math.min(250, remaining - #label)))
                if content == "" then return end
                fields[#fields + 1] = { name = label, value = content, inline = true }
                remaining = remaining - #label - #content
            end
        end
        field("title", post.title)
        field("category", post.category)
        field("district", post.district)
        field("location", post.location)
        field("price", post.price)
        local videos = {}
        for index, media in ipairs(post.media or {}) do
            if index > 4 then break end
            local media_url = type(media.url) == "string" and media.url
            if media_url and #media_url <= 900 and media_url:match("^https://[^/@%s]+/%S+$")
                and not media_url:find("/webhooks/", 1, true) then
                if media.media_type == "photo" and not embed.image then
                    embed.image = { url = media_url }
                elseif media.media_type == "video" then
                    videos[#videos + 1] = { url = media_url, mime_type = media.mime_type }
                else
                    local label = text(labels.media or "Media", 80) .. " " .. index
                    if #label + #media_url <= remaining then
                        fields[#fields + 1] = { name = label, value = media_url }
                        remaining = remaining - #label - #media_url
                    end
                end
            end
        end
        if #fields > 0 then embed.fields = fields end
        local payload = {
            username = text(spec.label, 80),
            avatar_url = WebHooks[spec.category .. "IconUrl"] ~= "" and WebHooks[spec.category .. "IconUrl"] or nil,
            allowed_mentions = { parse = json.decode("[]") },
            embeds = { embed },
        }
        return queue_pending("Public." .. spec.category, url, {{
            body = json.encode(payload), category = "Public." .. spec.category, attempts = 0, videos = videos,
        }})
    end)
    if not ok then diagnostic("public", "Could not prepare a public announcement.") end
    return ok and result or false
end

function SkyPhoneLog.Record(category, action, status, source, details, actor)
    if not SkyPhoneLog.IsEnabled(category, action) then return false end
    local ok, result = pcall(function()
        return enqueue(category, action, status, actor or identity(source), details)
    end)
    if not ok then diagnostic("record", "Could not prepare an audit record.") end
    return ok and result or false
end

-- Capture an authorized row before a destructive edit. It is published only if
-- the enclosing callback succeeds; independent callbacks use separate coroutines.
function SkyPhoneLog.Capture(label, value)
    local context = contexts[coroutine.running()]
    if not context then return end
    local ok, captured = pcall(safe_value, value)
    if ok then context.snapshots[label] = captured
    else diagnostic("capture", "Could not capture audit content.") end
end

function SkyPhoneLog.CaptureQuery(label, query, params)
    if not contexts[coroutine.running()] then return end
    local ok, rows = pcall(Bridge.Database.Query, query, params)
    if ok then
        SkyPhoneLog.Capture(label, rows)
        if type(rows) == "table" and #rows >= 101 then
            SkyPhoneLog.Capture(label .. "Limit", "First 101 rows shown; additional content may be omitted")
        end
    else diagnostic("snapshot", "Could not read audit content.") end
end

function SkyPhoneLog.WrapCallback(name, callback)
    local action = name:match("^sky_phone:(.+)$")
    local spec = action and SkyPhoneLog.Actions and SkyPhoneLog.Actions[action]
    if not spec then return callback end
    return function(source, data, ...)
        local audit_enabled = SkyPhoneLog.IsEnabled(spec.category, action)
        local public_enabled = SkyPhoneLog.IsPublicEnabled(action)
        if not audit_enabled and not public_enabled then return callback(source, data, ...) end
        local thread = coroutine.running()
        local previous = contexts[thread]
        local context = { snapshots = {} }
        contexts[thread] = context
        local actor_ok, actor = pcall(identity, source)
        local request = {}
        for field in (spec.fields or ""):gmatch("%S+") do
            if type(data) == "table" then request[field] = data[field] end
        end
        local sanitized, saved_request = pcall(safe_value, request)
        if audit_enabled and spec.before and actor_ok and actor.imei then
            local ok, content = pcall(spec.before, source, data or {}, actor)
            if ok then SkyPhoneLog.Capture("before", content)
            else diagnostic("before:" .. action, "Could not read previous content for " .. action .. ".") end
        end
        local result = table.pack(pcall(callback, source, data, ...))
        contexts[thread] = previous
        if not result[1] then error(result[2], 0) end
        local response = result[2]
        if audit_enabled and type(response) == "table" and response.success == true then
            local ok = pcall(function()
                local status = type(spec.status) == "function" and spec.status(data or {}, response) or spec.status
                local details = {
                    request = sanitized and saved_request or nil,
                    result = spec.result ~= false and response.data or nil,
                    snapshots = next(context.snapshots) and context.snapshots or nil,
                }
                local after_ok, actor_after = pcall(identity, source)
                if after_ok and actor_ok and (actor_after.accountId ~= actor.accountId or actor_after.imei ~= actor.imei) then
                    details.actorAfter = actor_after
                end
                if spec.enrich then
                    local enriched = pcall(spec.enrich, source, data or {}, response, details)
                    if not enriched then
                        details.contentError = "Content lookup failed; request and result retained"
                        diagnostic("enrich:" .. action, "Could not read content for " .. action .. ".")
                    end
                end
                SkyPhoneLog.Record(spec.category, action, status or "completed", source, details, actor_ok and actor or nil)
            end)
            if not ok then diagnostic("callback", "Could not prepare callback audit content for " .. action .. ".") end
        end
        if public_enabled and type(response) == "table" and response.success == true then
            local ok = pcall(SkyPhoneLog.AnnouncePublic, action, data or {}, response)
            if not ok then diagnostic("public:" .. action, "Could not read public content for " .. action .. ".") end
        end
        return table.unpack(result, 2, result.n)
    end
end
