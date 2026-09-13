-- Run from the repository root with Lua 5.4. HTTP and timers are local doubles;
-- this test never contacts Discord or requires a configured webhook.
local now, timers, requests, diagnostics, responses, encoded, queries, formatted, downloads, download_requests
local function encode(value)
    if type(value) == "string" then
        return '"' .. value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t") .. '"'
    end
    if type(value) == "boolean" or type(value) == "number" then return tostring(value) end
    if type(value) ~= "table" then return "null" end
    local parts, keys = {}, {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    if #value > 0 and #keys == #value then
        for _, item in ipairs(value) do parts[#parts + 1] = encode(item) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    for _, key in ipairs(keys) do parts[#parts + 1] = encode(tostring(key)) .. ":" .. encode(value[key]) end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function reset()
    now, timers, requests, diagnostics, responses, encoded, queries = 0, {}, {}, {}, {}, {}, {}
    formatted = {}
    downloads, download_requests = {}, {}
    Config = { Bridge = { Locale = "en" } }
    Locales = {}
    dofile("sky_phone/config/locales/en.lua")
    dofile("sky_phone/config/locales/de.lua")
    dofile("sky_phone/config/locales/es.lua")
    json = {
        encode = function(value)
            local body = encode(value)
            encoded[body] = value
            return body
        end,
        decode = function(value)
            if value == "[]" then return {} end
            if encoded[value] then return encoded[value] end
            error("Invalid test JSON")
        end,
    }
    Bridge = {
        Debug = function(_, format, ...) diagnostics[#diagnostics + 1] = format:format(...) end,
        Database = { Query = function(query, params)
            queries[#queries + 1] = { query = query, params = params }
            return {}
        end },
        Callbacks = {},
    }
    SkyPhone = { GetLogIdentity = function(source)
        return { accountId = source + 100, imei = "test-device-" .. source, phoneNumber = "5550100" }
    end }
    function GetPlayerName(source) return "Test Player " .. source end
    function GetGameTimer() return now end
    function SetTimeout(delay, callback) timers[#timers + 1] = { at = now + delay, callback = callback } end
    function PerformHttpRequest(url, callback, method, body, headers, options)
        assert(options.followLocation == false, "Webhook requests must not follow redirects")
        if method == "HEAD" or method == "GET" then
            download_requests[#download_requests + 1] = { url = url, method = method }
            local media = assert(downloads[url], "Unexpected media fetch: " .. url)
            if media.hang == method then return end
            if method == "HEAD" then
                callback(media.head_status or 200, "", { ["Content-Length"] = media.head_size or #media.body,
                    ["Content-Type"] = media.mime or "video/webm" })
            else
                assert(headers.Range, "Downloads must request a bounded byte range")
                callback(media.status or 200, media.body, { ["Content-Type"] = media.mime or "video/webm" })
            end
            return
        end
        assert(method == "POST")
        local payload = encoded[body]
        if headers["Content-Type"]:find("multipart/form-data", 1, true) then
            local content = assert(body:match('name="payload_json"\r\nContent%-Type: application/json\r\n\r\n(.-)\r\n%-%-'))
            payload = assert(encoded[content])
        else assert(headers["Content-Type"] == "application/json") end
        requests[#requests + 1] = { at = now, url = url, body = body, payload = payload, content_type = headers["Content-Type"] }
        local response = table.remove(responses, 1) or { status = 200 }
        callback(response.status, response.body, response.headers)
    end
    dofile("sky_phone/config/WebHooks.lua")
    dofile("sky_phone/source/server/logging.lua")
    dofile("sky_phone/source/server/logging_format.lua")
    dofile("sky_phone/source/server/logging_media.lua")
    local format = SkyPhoneLog.FormatAudit
    SkyPhoneLog.FormatAudit = function(category, action, status, audit, timestamp)
        local title, description = format(category, action, status, audit, timestamp)
        formatted[description] = audit
        return title, description
    end
    dofile("sky_phone/source/server/logging_actions.lua")
    dofile("sky_phone/source/server/logging_content.lua")
    dofile("sky_phone/source/server/logging_public.lua")
end

local function advance(until_time)
    local count = 0
    while #timers > 0 do
        table.sort(timers, function(a, b) return a.at < b.at end)
        if until_time and timers[1].at > until_time then break end
        local timer = table.remove(timers, 1)
        now = timer.at
        timer.callback()
        count = count + 1
        assert(count < 10000, "Timer loop did not settle")
    end
    if until_time then now = until_time end
end

local function record(request)
    local description = request.payload.embeds[1].description
    assert(not description:find("```", 1, true), "Admin logs must be readable without a JSON code block")
    return assert(formatted[description], "Expected a complete formatted audit record")
end

local calls_url = "https://discord.com/api/webhooks/1/test-calls"
local messages_url = "https://discord.com/api/webhooks/2/test-messages"
local fallback_url = "https://discord.com/api/webhooks/3/test-default"

reset()
assert(not SkyPhoneLog.Record("Calls", "calls:created", "ringing", 1, {}))
assert(#timers == 0 and #queries == 0, "Unconfigured logging must be inert")
WebHooks.Calls, WebHooks.Messages = calls_url, messages_url
WebHooks.AvatarUrl = "https://example.invalid/phone-avatar.png"
assert(SkyPhoneLog.Record("Calls", "calls:created", "ringing", 1, { id = "call" }))
assert(SkyPhoneLog.Record("Messages", "messages:send", "sent", 2, { body = "hello" }))
assert(#requests == 0, "HTTP must not run inline in gameplay callbacks")
advance()
assert(#requests == 2 and requests[1].url ~= requests[2].url, "Categories need independent webhooks")
for _, request in ipairs(requests) do
    assert(request.url:sub(-10) == "?wait=true", "Delivery must request Discord confirmation")
    assert(next(request.payload.allowed_mentions.parse) == nil, "Mentions must be disabled")
    assert(request.payload.avatar_url == WebHooks.AvatarUrl, "Configured avatar must reach each webhook message")
end

reset()
WebHooks.Default, WebHooks.Calls = fallback_url, false
assert(not SkyPhoneLog.Record("Calls", "calls:created", "ringing", 1, {}))
WebHooks.Actions["calls:answered"] = calls_url
assert(SkyPhoneLog.Record("Calls", "calls:answered", "connected", 1, {}))
WebHooks.Actions["messages:send"] = false
assert(not SkyPhoneLog.Record("Messages", "messages:send", "sent", 1, {}))
assert(SkyPhoneLog.Record("SkyPic", "skypic:publish-story", "created", 1, {}))
advance()
assert(#requests == 2)
assert(requests[1].payload.avatar_url == nil, "An empty avatar setting must preserve the webhook's default avatar")
WebHooks.Actions = nil
assert(SkyPhoneLog.IsEnabled("Messages", "messages:send"), "The optional action override table may be omitted")
assert(requests[1].url == calls_url .. "?wait=true" or requests[2].url == calls_url .. "?wait=true")
for _, url in ipairs({ "http://discord.com/api/webhooks/1/test", "https://evil.invalid/hook",
    "https://discord.com.evil.invalid/api/webhooks/1/test", "https://discord.com/api/webhooks/",
    "https://discord.com/api/webhooks/1/test?other=value" }) do
    WebHooks.Calls = url
    assert(not SkyPhoneLog.Record("Calls", "calls:created", "ringing", 1, {}))
end
for _, diagnostic in ipairs(diagnostics) do assert(not diagnostic:find("https://", 1, true)) end

reset()
WebHooks.Default = fallback_url
local sentinel = "NEVER-LOG-THIS"
SkyPhoneLog.Record("Messages", "messages:send", "sent", 42, {
    body = "Hello @everyone ``` " .. calls_url,
    password = sentinel, sessionToken = sentinel,
    nested = { newPassword = sentinel, APIKey = sentinel, passcode = sentinel,
        token = sentinel, media_payload = sentinel, PresignedUrl = sentinel, safe = "kept" },
})
advance()
assert(not requests[1].body:find(sentinel, 1, true), "Credentials must be stripped recursively")
assert(not requests[1].body:find("test-calls", 1, true), "Webhook URLs in content must be redacted")
local audit = record(requests[1])
assert(audit.actor.source == 42 and audit.actor.accountId == 142)
assert(audit.details.nested.safe == "kept" and audit.details.body:find("@everyone", 1, true))

reset()
WebHooks.Messages = messages_url
local success_response = { success = true, data = { id = "message-1", body = "server-normalized" } }
local callback = SkyPhoneLog.WrapCallback("sky_phone:messages:send", function(source, data)
    assert(source == 7 and data.password == sentinel, "Logging must preserve callback inputs")
    return success_response, nil, "extra-result"
end)
local response, empty, extra = callback(7, { body = "accepted input", password = sentinel, source = 999 })
assert(response == success_response and empty == nil and extra == "extra-result", "Return values changed")
advance()
audit = record(requests[1])
assert(audit.actor.source == 7 and audit.details.request.body == "accepted input")
assert(audit.details.request.source == nil and audit.details.result.body == "server-normalized")
local denied = SkyPhoneLog.WrapCallback("sky_phone:messages:send", function() return { success = false } end)
denied(7, { body = "REJECTED" })
local crashed = SkyPhoneLog.WrapCallback("sky_phone:messages:send", function() error("gameplay error") end)
assert(not pcall(crashed, 7, {}), "Gameplay exceptions must retain existing callback error behavior")
advance()
assert(#requests == 1, "Rejected or failed mutations must not be logged as successful")
local read = function() return { success = true } end
assert(SkyPhoneLog.WrapCallback("sky_phone:feather:feed", read) == read, "Feed polling must not generate logs")
assert(SkyPhoneLog.Actions["mail:delete-many"].status({ folder = "inbox" }) == "trashed")
assert(SkyPhoneLog.Actions["mail:delete-many"].status({ folder = "trash" }) == "deleted")

reset()
WebHooks.Picstagram = fallback_url
local persisted = { id = "post-1", profile_id = 1, caption = "before edit", status = "published" }
Bridge.Database.Query = function(query, params)
    queries[#queries + 1] = { query = query, params = params }
    if query:find("FROM `sky_phone_picstagram_posts`", 1, true) then
        return {{ id = persisted.id, caption = persisted.caption, status = persisted.status }}
    end
    return {}
end
local edit = SkyPhoneLog.WrapCallback("sky_phone:picstagram:update-post", function()
    persisted.caption = "after edit"
    return { success = true }
end)
edit(1, { id = "post-1", caption = "after edit" })
advance()
audit = record(requests[1])
assert(audit.details.snapshots.before.records[1].caption == "before edit", "Old content must survive edits")
assert(audit.details.content.records[1].caption == "after edit", "New content must reflect persisted state")
Bridge.Database.Query = function() error("DATABASE SECRET") end
edit(1, { id = "post-1", caption = "still succeeds" })
advance()
assert(#requests == 2 and record(requests[2]).details.contentError, "Content lookup failure must retain the audit")
assert(not table.concat(diagnostics):find("DATABASE SECRET", 1, true))

reset()
WebHooks.Messages = messages_url
local concurrent = SkyPhoneLog.WrapCallback("sky_phone:messages:send", function(source)
    SkyPhoneLog.Capture("before", { body = "source-" .. source })
    coroutine.yield()
    return { success = true, data = { body = "done-" .. source } }
end)
local first = coroutine.create(function() concurrent(1, {}) end)
local second = coroutine.create(function() concurrent(2, {}) end)
assert(coroutine.resume(first)); assert(coroutine.resume(second))
assert(coroutine.resume(second)); assert(coroutine.resume(first))
advance()
assert(#requests == 2)
for _, request in ipairs(requests) do
    audit = record(request)
    assert(audit.details.snapshots.before.body == "source-" .. audit.actor.source,
        "Concurrent callbacks must not mix actors or content")
end

reset()
WebHooks.Default = fallback_url
responses[1] = { status = 429, body = json.encode({ retry_after = 2 }) }
SkyPhoneLog.Record("Calls", "calls:created", "ringing", 1, { id = "first" })
advance(100)
SkyPhoneLog.Record("Messages", "messages:send", "sent", 2, { id = "second" })
advance(1999)
assert(#requests == 1, "New messages must not bypass a shared webhook's rate-limit cooldown")
advance()
assert(#requests == 3 and requests[2].at >= 2001)
assert(record(requests[2]).details.id == "first" and record(requests[3]).details.id == "second")

reset()
WebHooks.Calls, WebHooks.Messages = calls_url, messages_url
responses[1] = { status = 429, body = json.encode({ retry_after = 2, global = true }) }
SkyPhoneLog.Record("Calls", "calls:created", "ringing", 1, {})
advance(100)
SkyPhoneLog.Record("Messages", "messages:send", "sent", 2, {})
advance(1999)
assert(#requests == 1, "Global rate limits must delay other webhook queues")
advance()
assert(#requests == 3)

reset()
WebHooks.Default, WebHooks.MaxAttempts = fallback_url, 2
responses[1], responses[2] = { status = 503 }, { status = 503 }
SkyPhoneLog.Record("Calls", "calls:ended", "completed", 1, {})
advance()
assert(#requests == 2 and #diagnostics == 1, "Transient failures need bounded retries and a diagnostic")
responses[1] = { status = 404, body = calls_url }
SkyPhoneLog.Record("Calls", "calls:ended", "completed", 1, {})
advance()
assert(#requests == 3, "Permanent HTTP failures must not be retried")
assert(not table.concat(diagnostics):find("test-calls", 1, true))

reset()
WebHooks.Default, WebHooks.QueueLimit = fallback_url, 1
assert(SkyPhoneLog.Record("Calls", "calls:created", "ringing", 1, {}))
assert(not SkyPhoneLog.Record("Messages", "messages:send", "sent", 1, {}))
assert(#diagnostics == 1, "Queue overflow must be visible")
advance()
assert(SkyPhoneLog.Record("Messages", "messages:send", "sent", 1, {}), "Completed messages must free queue capacity")
advance()

reset()
WebHooks.Messages = messages_url
local long_body = string.rep("Grüße 🐾 ", 1500)
assert(SkyPhoneLog.Record("Messages", "messages:send", "sent", 1, { body = long_body }))
advance()
assert(#requests > 1, "Long content must use continuation messages")
local joined = {}
for _, request in ipairs(requests) do
    local embed = request.payload.embeds[1]
    assert(utf8.len(embed.description) and #embed.description <= 4096, "Embed limits and UTF-8 must be respected")
    joined[#joined + 1] = embed.description
end
assert(table.concat(joined):find(long_body, 1, true), "Ordinary long content must not be silently truncated")

reset()
WebHooks.Default, WebHooks.QueueLimit = fallback_url, 2
local original_encode, payload_count = json.encode, 0
json.encode = function(value)
    if value.embeds then
        payload_count = payload_count + 1
        if payload_count == 2 then error("serializer failure") end
    end
    return original_encode(value)
end
assert(not SkyPhoneLog.Record("Messages", "messages:send", "sent", 1, { body = string.rep("x", 4000) }))
json.encode = original_encode
assert(SkyPhoneLog.Record("Messages", "messages:send", "sent", 1, { body = "first" }))
assert(SkyPhoneLog.Record("Messages", "messages:send", "sent", 1, { body = "second" }),
    "A serialization failure must not partially fill or corrupt the delivery queue")
advance()
assert(#requests == 2)

reset()
WebHooks.Default = fallback_url
local event
function RegisterNetEvent(name, callback) event = { name = name, callback = callback } end
local client_results = {}
function TriggerClientEvent(...) client_results[#client_results + 1] = table.pack(...) end
dofile("sky_phone/source/bridge/server/callbacks.lua")
Bridge.Callbacks.Register("sky_phone:messages:send", function() return { success = true, data = { body = "bridge" } } end)
source = 8
event.callback("sky_phone:messages:send", 1, { body = "bridge", webhook = calls_url })
advance()
assert(#client_results == 1 and client_results[1][4].success == true)
assert(not encode(client_results):find("test-default", 1, true), "Webhook config must never reach callback responses")
assert(#requests == 1, "The real callback dispatcher must invoke the audit wrapper")

-- Public announcements and administrative audit records have independent
-- routes and payloads. Exercise every registered public action after success.
local public_url = "https://discord.com/api/webhooks/4/test-public"
local public_row = {
    id = "550e8400-e29b-41d4-a716-446655440002", body = "Persisted public content",
    author_name = "Public Author", author_handle = "author", title = "Public title",
    author_avatar = "https://example.invalid/profile.webp",
    category = "news", district = "downtown", location = "City", price = 125, price_type = "fixed",
    status = "published", private = 0, profile_status = "active", visibility = "public", privacy = "everyone",
    expires_at = os.time() + 3600, media_url = "https://example.invalid/photo.webp", media_type = "photo",
    account_id = "PRIVATE_ACCOUNT", phone_number = "PRIVATE_PHONE", imei = "PRIVATE_DEVICE",
    author_identifier = "PRIVATE_IDENTIFIER", password = "PRIVATE_PASSWORD",
}
local function public_storage(query, params)
    assert(type(params) == "table", "Queries must use bound parameters")
    if query:find("SELECT r.", 1, true) then
        assert(params[1] == public_row.id)
        return { public_row }
    elseif query:find("SELECT m.", 1, true) then
        return {{ url = public_row.media_url, media_type = "photo" }}
    end
    return {}
end
reset()
local public_actions = SkyPhoneLog.PublicActions
local function read_file(path)
    local file = io.open(path, "rb")
    if not file then return "" end
    local content = file:read("*a"); file:close()
    return content
end
local schema = read_file("sky_phone/sql/install.sql")
local migrations = read_file("sky_phone/source/server/db_migrate.lua")
local feature_path = os.getenv("SKY_PHONE_SKYPIC_SOURCE")
if feature_path then
    schema = schema .. read_file(feature_path:gsub("source/server/skypic.lua$", "sql/install.sql"))
    migrations = migrations .. read_file(feature_path:gsub("source/server/skypic.lua$", "source/server/db_migrate.lua"))
end
-- Validate projected SQL against actual owned schema, including attachment
-- ordering columns (Weazel uses position; other apps use sort_order).
for _, spec in pairs(public_actions) do
    for _, sql in ipairs({ spec.entity.query, spec.entity.media }) do
        local aliases = {}
        for table_name, alias in sql:gmatch("[FJ][RO][OI][MN]%s+`([^`]+)`%s+(%w+)") do aliases[alias] = table_name end
        for alias, column in sql:gmatch("(%w+)%.`([^`]+)`") do
            local table_name = assert(aliases[alias], "Unknown SQL alias: " .. alias)
            local definition = schema:match("CREATE TABLE IF NOT EXISTS `" .. table_name .. "`%s*%((.-)%) ENGINE")
                or migrations:match('name = "' .. table_name .. '",%s*columns = {(.-)primaryKey')
            if definition then
                assert(definition:find("`" .. column .. "`", 1, true) or definition:find('name = "' .. column .. '"', 1, true),
                    "Invalid public SQL column: " .. table_name .. "." .. column)
            else
                assert(table_name:find("sky_phone_skypic_", 1, true) and not feature_path, "Missing schema: " .. table_name)
            end
        end
    end
end
for action, spec in pairs(public_actions) do
    reset()
    WebHooks.Default, WebHooks.Public.Default = fallback_url, public_url
    Bridge.Database.Query = public_storage
    public_row.status = (spec.category == "Marketplace" or spec.category == "SkyPic" or spec.status == "story")
        and "active" or "published"
    local result = { success = true, data = { id = public_row.id, article = { id = public_row.id }, private = "PRIVATE_RESULT" } }
    assert(SkyPhoneLog.WrapCallback("sky_phone:" .. action, function() return result end)(1, {
        id = public_row.id, body = "UNTRUSTED_REQUEST", caption = "UNTRUSTED_REQUEST",
    }) == result, "Logging must preserve the callback result")
    advance()
    assert(#requests == 2, "Missing admin/public delivery for " .. action)
    local seen_admin, seen_public = false, false
    for _, request in ipairs(requests) do
        if request.url == public_url .. "?wait=true" then
            seen_public = true
            assert(request.payload.embeds[1].description == public_row.body)
            assert(request.payload.username == spec.label and request.payload.avatar_url == WebHooks[spec.category .. "IconUrl"])
            assert(request.payload.embeds[1].author.name == "@author")
            assert(request.payload.embeds[1].author.icon_url == public_row.author_avatar)
            assert(request.payload.embeds[1].footer.text == "Sky Phone")
            assert(request.payload.embeds[1].footer.icon_url == WebHooks.FooterIconUrl)
            assert(request.payload.embeds[1].timestamp:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"))
            assert(not request.payload.embeds[1].title:find(spec.label, 1, true))
            assert(request.payload.embeds[1].image.url == public_row.media_url)
            assert(not request.body:find("PRIVATE_", 1, true) and not request.body:find("UNTRUSTED_REQUEST", 1, true))
            assert(not request.body:find("test-device", 1, true) and not request.body:find("accountId", 1, true))
            assert(next(request.payload.allowed_mentions.parse) == nil)
        else
            seen_admin = request.url == fallback_url .. "?wait=true"
            assert(record(request).actor.accountId == 101)
        end
    end
    assert(seen_admin and seen_public, "Audiences must use distinct configured destinations")
end

for _, case in ipairs({
    { "picstagram:publish-post", "private", 1 },
    { "picstagram:publish-post", "profile_status", "suspended" },
    { "picstagram:publish-post", "status", "draft" },
    { "picstagram:publish-story", "private", 1 },
    { "picstagram:publish-story", "expires_at", os.time() - 1 },
    { "fliptok:publish", "visibility", "followers" },
    { "fliptok:publish", "visibility", "private" },
    { "fliptok:publish", "status", "draft" },
    { "skypic:publish-story", "privacy", "friends" },
    { "skypic:publish-spotlight", "profile_status", "removed" },
    { "skypic:publish-spotlight", "expires_at", os.time() - 1 },
    { "marketplace:update", "status", "removed" },
    { "marketplace:set-status", "status", "expired" },
    { "weazel-news:create", "status", "draft" },
    { "weazel-news:update", "deleted_at", "2026-01-01" },
}) do
    reset()
    WebHooks.Default, WebHooks.Public.Default = fallback_url, public_url
    Bridge.Database.Query = public_storage
    public_row.status = (case[1]:find("story", 1, true) or case[1]:find("spotlight", 1, true)
        or case[1]:find("marketplace", 1, true)) and "active" or "published"
    local original = public_row[case[2]]
    public_row[case[2]] = case[3]
    SkyPhoneLog.WrapCallback("sky_phone:" .. case[1], function()
        return { success = true, data = { id = public_row.id } }
    end)(1, { id = public_row.id })
    advance()
    assert(#requests == 1 and requests[1].url == fallback_url .. "?wait=true",
        "Private/unpublished content reached public Discord: " .. case[1] .. " / " .. case[2])
    public_row[case[2]] = original
end

reset()
WebHooks.Default = fallback_url
assert(not SkyPhoneLog.IsPublicEnabled("feather:create-post"), "Public must never inherit an admin default")
WebHooks.Public = nil
assert(not SkyPhoneLog.IsPublicEnabled("feather:create-post"), "Legacy files must keep public announcements disabled")
WebHooks.Public = { Default = public_url, Actions = { ["feather:create-post"] = false } }
assert(not SkyPhoneLog.IsPublicEnabled("feather:create-post"))
assert(not SkyPhoneLog.IsPublicEnabled("messages:send") and not SkyPhoneLog.IsPublicEnabled("skypic:send-snap"))
WebHooks.Public.Actions["feather:create-post"] = ""
assert(SkyPhoneLog.IsPublicEnabled("feather:create-post"))
WebHooks.Enabled = false
assert(not SkyPhoneLog.IsPublicEnabled("feather:create-post"))

-- Actual Feather mutation through the real dispatcher, including delayed
-- registration from dev's startup handling, with public logging alone enabled.
reset()
WebHooks.Public.Feather = public_url
Config = { Feather = { PostsPerMinute = 5, TextMaxLength = 500, MaxImages = 4 } }
local allowed, transaction_ok, persisted = true, true, nil
SkyPhone.AllowOperation = function() return true end
SkyPhone.RequireAccount = function()
    if allowed then return { id = 101 } end
    return nil, { success = false, error = "not_authenticated" }
end
Bridge.Database.AfterMigration = function(_, callback) callback() end
Bridge.Database.Transaction = function(statements)
    if transaction_ok then persisted = statements[1].params[3] end
    return transaction_ok
end
Bridge.Database.Query = function(query, params)
    if query:find("SELECT UUID()", 1, true) then return {{ id = public_row.id }} end
    if query:find("SELECT * FROM `sky_phone_feather_profiles`", 1, true) then return {{ id = 1 }} end
    if query:find("SELECT r.", 1, true) then
        assert(persisted, "Public lookup must happen after successful persistence")
        return {{ id = public_row.id, body = persisted, author_handle = "author", status = "published" }}
    end
    return {}
end
client_results = {}
dofile("sky_phone/source/bridge/server/callbacks.lua")
Bridge.Callbacks.RegisterDeferred("sky_phone:feather:create-post")
source = 1
event.callback("sky_phone:feather:create-post", 1, { body = "  Actual Feather text  " })
assert(client_results[1][4].error == "server_initializing")
dofile("sky_phone/source/server/feather.lua")
event.callback("sky_phone:feather:create-post", 2, { body = "  Actual Feather text  " })
advance()
assert(client_results[2][4].success and #requests == 1)
assert(requests[1].payload.embeds[1].description == "Actual Feather text")
allowed = false
event.callback("sky_phone:feather:create-post", 3, { body = "Rejected text" })
allowed, transaction_ok = true, false
event.callback("sky_phone:feather:create-post", 4, { body = "Uncommitted text" })
advance()
assert(#requests == 1, "Rejected/failed real mutations must not produce public announcements")
assert(client_results[3][4].error == "not_authenticated" and client_results[4][4].error == "request_failed")

reset()
WebHooks.Public.Default = public_url
local long_media = "https://example.invalid/" .. string.rep("x", 850)
assert(SkyPhoneLog.Publish("marketplace:create", {
    id = string.rep("i", 200), body = string.rep("😀", 2000), author_name = string.rep("a", 250),
    author_handle = string.rep("h", 250), title = string.rep("t", 400), category = string.rep("c", 400),
    district = string.rep("d", 400), location = string.rep("l", 400), price = string.rep("p", 400),
    media = {{ url = long_media }, { url = long_media }, { url = long_media }, { url = long_media }},
}))
advance()
local public_embed = requests[1].payload.embeds[1]
local total = #public_embed.title + #public_embed.description + #public_embed.footer.text + #public_embed.author.name
for _, field in ipairs(public_embed.fields) do total = total + #field.name + #field.value end
assert(total <= 6000 and utf8.len(requests[1].body), "Public embeds must fit Discord limits with valid UTF-8")

reset()
Config.Bridge.Locale = "de"
WebHooks.Default = fallback_url
SkyPhoneLog.Record("Feather", "feather:create-post", "created", 1, {
    content = { records = {{ author_handle = "dean", body = "Ein Homegym ist etwas Feines", created_at = 1789310000000 }} },
})
SkyPhoneLog.Record("Device", "device:save", "saved", 1, { request = { namespace = "settings", revision = 3 } })
advance()
assert(requests[1].payload.embeds[1].title == "Feather · Neuer Beitrag")
assert(requests[1].body:find("@dean", 1, true) and requests[1].body:find("Ein Homegym ist etwas Feines", 1, true))
assert(requests[1].body:find("**Von:** Test Player 1", 1, true))
assert(requests[1].body:find("<t:1789310000:f>", 1, true), "Database millisecond dates need readable Discord timestamps")
assert(requests[2].payload.embeds[1].title:find("Einstellungen geändert", 1, true))
assert(requests[2].body:find("Einstellungsbereich", 1, true) and not requests[2].body:find('"actor"', 1, true))

local video_url = "https://r2.fivemanage.com/phone-test-clip.webm"
local binary_video = "\26\69\223\163\0TEST_VIDEO_BYTES\255"
local function publish_video(url, mime)
    return SkyPhoneLog.Publish("fliptok:publish", { body = "Video post", author_handle = "dean",
        media = {{ url = url or video_url, media_type = "video", mime_type = mime or "video/webm" }} })
end
reset()
WebHooks.Public.FlipTok = public_url
downloads[video_url] = { body = binary_video }
assert(publish_video())
assert(#download_requests == 0, "Media downloads must not run inside gameplay callbacks")
advance()
assert(#requests == 1 and #download_requests == 2)
assert(requests[1].content_type:find("multipart/form-data", 1, true))
assert(requests[1].body:find(binary_video, 1, true), "Video bytes must actually be attached")
assert(requests[1].body:find('name="files[0]"; filename="video-1.webm"', 1, true))
assert(requests[1].payload.attachments[1].id == 0 and requests[1].payload.content == nil)
assert(requests[1].payload.embeds[1].author.name == "@dean")

for _, media in ipairs({
    { body = binary_video, head_size = 21 * 1024 * 1024 },
    { body = binary_video, head_status = 302 },
    { body = binary_video, status = 404 },
    { body = binary_video, hang = "GET" },
    { body = binary_video, hang = "HEAD" },
    { body = binary_video, head_size = 1 },
    { body = binary_video, mime = "text/html" },
}) do
    reset()
    WebHooks.Public.FlipTok = public_url
    downloads[video_url] = media
    assert(publish_video())
    advance()
    assert(#requests == 1 and requests[1].content_type == "application/json")
    assert(requests[1].payload.content == video_url, "Unavailable video must retain its visible link")
    assert(requests[1].payload.embeds[1].description == "Video post")
end
for _, url in ipairs({ "https://127.0.0.1/video.webm", "https://localhost/video.webm",
    "https://r2.fivemanage.com.evil.invalid/video.webm", "https://unconfigured.invalid/video.webm" }) do
    reset()
    WebHooks.Public.FlipTok = public_url
    assert(publish_video(url))
    advance()
    assert(#download_requests == 0 and #requests == 1, "Untrusted hosts must not trigger server downloads")
end
reset()
WebHooks.Public.FlipTok = public_url
downloads[video_url] = { body = binary_video }
responses[1] = { status = 429, body = json.encode({ retry_after = 2 }) }
responses[2] = { status = 413 }
assert(publish_video())
advance()
assert(#requests == 3 and requests[2].at >= 2001)
assert(requests[3].content_type == "application/json" and requests[3].payload.content == video_url,
    "Discord upload rejection must retry the post with a visible video link")

reset()
WebHooks.Public.FlipTok, WebHooks.Calls = public_url, fallback_url
downloads[video_url] = { body = binary_video }
local http = PerformHttpRequest
PerformHttpRequest = function(url, callback, method, body, headers, options)
    if method == "GET" then
        SetTimeout(100, function() http(url, callback, method, body, headers, options) end)
    else http(url, callback, method, body, headers, options) end
end
assert(publish_video())
advance(1)
responses[1] = { status = 429, body = json.encode({ retry_after = 2, global = true }) }
assert(SkyPhoneLog.Record("Calls", "calls:created", "ringing", 1, {}))
advance()
assert(#requests == 3, "The global cooldown must retain both the call retry and the video")
for _, request in ipairs(requests) do
    if request.url == public_url .. "?wait=true" then
        assert(request.at >= 2002, "Global Discord cooldown must be rechecked after downloading media")
    end
end

reset()
WebHooks.Public.FlipTok, WebHooks.Public.Feather, WebHooks.Public.Pages = public_url, calls_url, messages_url
WebHooks.Calls = fallback_url
downloads[video_url] = { body = binary_video }
http = PerformHttpRequest
local in_progress, peak = 0, 0
PerformHttpRequest = function(url, callback, method, body, headers, options)
    if method == "GET" then
        in_progress = in_progress + 1
        peak = math.max(peak, in_progress)
        SetTimeout(100, function()
            in_progress = in_progress - 1
            http(url, callback, method, body, headers, options)
        end)
    else http(url, callback, method, body, headers, options) end
end
for _, action in ipairs({ "fliptok:publish", "feather:create-post", "pages:create" }) do
    assert(SkyPhoneLog.Publish(action, { body = "Concurrent video", media = {{ url = video_url, media_type = "video", mime_type = "video/webm" }} }))
end
assert(SkyPhoneLog.Record("Calls", "calls:created", "ringing", 1, {}))
advance(50)
assert(#requests == 1 and requests[1].url == fallback_url .. "?wait=true", "Downloads must not block ordinary admin delivery")
advance()
assert(peak == 2 and #requests == 4, "Video downloads must respect the shared concurrency cap and release capacity")

reset()
WebHooks.Public.FlipTok = public_url
local mp4_url = "https://cdn.example.invalid/phone-test.mp4"
Config.Media = { Import = { Enabled = true, Websites = {{ Enabled = true, AllowedMediaHosts = { "example.invalid" } }} } }
downloads[mp4_url] = { body = "TEST_MP4_BYTES", mime = "video/mp4" }
assert(publish_video(mp4_url, "video/mp4"))
advance()
assert(requests[1].payload.attachments[1].filename == "video-1.mp4")
assert(requests[1].body:find("Content-Type: video/mp4", 1, true))

-- Exercise prepared SkyPic actions without requiring the feature's tables at
-- startup. The real feature source can also be checked with the optional suite.
reset()
WebHooks.SkyPic = fallback_url
Bridge.Database.Query = function(query)
    if query:find("sky_phone_skypic_messages", 1, true) then
        return {{ id = "snap-1", sender_profile_id = "sender", recipient_profile_id = "recipient",
            caption = "Snap caption", overlay_text = "overlay", media_url = "https://example.invalid/snap.webp" }}
    end
    return {}
end
SkyPhoneLog.WrapCallback("sky_phone:skypic:send-snap", function()
    return { success = true, data = {{ id = "snap-1" }} }
end)(1, { recipientIds = { "recipient" }, caption = "Snap caption", mediaId = 12 })
advance()
audit = record(requests[1])
assert(audit.details.content.records[1].recipient_profile_id == "recipient")
assert(audit.details.content.records[1].media_url == "https://example.invalid/snap.webp")

-- Optional integration against the actual feature checkout; after merging the
-- feature it runs automatically from the local resource file.
local skypic_path = os.getenv("SKY_PHONE_SKYPIC_SOURCE") or "sky_phone/source/server/skypic.lua"
local skypic_file = io.open(skypic_path, "rb")
if skypic_file then
    local skypic_source = skypic_file:read("*a"); skypic_file:close()
    reset()
    WebHooks.SkyPic = fallback_url
    Config = { SkyPic = {} }
    local feature_callbacks, authorized = {}, true
    local profile_id = "550e8400-e29b-41d4-a716-446655440001"
    local content_id = "550e8400-e29b-41d4-a716-446655440002"
    local removed = false
    SkyPhone.RequireAccount = function()
        if authorized then return { id = 101 } end
        return nil, { success = false, error = "not_authenticated" }
    end
    SkyPhone.AllowOperation = function() return true end
    function CreateThread() end
    Bridge.Database.AfterMigration = function(_, callback) callback() end
    Bridge.Callbacks.Register = function(name, callback)
        feature_callbacks[name] = SkyPhoneLog.WrapCallback(name, callback)
    end
    Bridge.Database.Query = function(query)
        if query:find("SELECT profile.`id` AS `profile_id`", 1, true) then
            return {{ profile_id = profile_id, handle = "test", display_name = "Test", snap_score = 0 }}
        elseif query:find("SELECT record.", 1, true) then
            return {{ id = content_id, profile_id = profile_id, body = "Feature text",
                caption = "Feature caption", status = removed and "removed" or "active",
                media_url = "https://example.invalid/feature.webp" }}
        elseif query:find("UPDATE `sky_phone_skypic_", 1, true) then
            removed = true
            return { affectedRows = 1 }
        end
        return {}
    end
    assert(load(skypic_source, skypic_path))()
    for _, case in ipairs({
        { "delete-message", { messageId = content_id, forEveryone = true }, "deleted_for_everyone" },
        { "remove-story", { storyId = content_id }, "deleted" },
        { "remove-spotlight", { spotlightId = content_id }, "deleted" },
        { "delete-spotlight-comment", { commentId = content_id }, "deleted" },
    }) do
        removed = false
        local action = "sky_phone:skypic:" .. case[1]
        assert(feature_callbacks[action](1, case[2]).success, "Actual SkyPic action failed: " .. action)
        advance()
        audit = record(requests[#requests])
        assert(audit.details.snapshots.before.records[1].status == "active")
        assert(audit.details.content.records[1].status == "removed")
        assert(requests[#requests].payload.embeds[1].title:lower():find(Locales.en.DiscordAudit.states[case[3]]:lower(), 1, true))
    end
    local delivered = #requests
    authorized = false
    assert(not feature_callbacks["sky_phone:skypic:remove-story"](1, { storyId = content_id }).success)
    advance()
    assert(#requests == delivered, "Actual SkyPic authentication failures must not emit successful logs")
    local read_only = {
        bootstrap = true, search = true, thread = true, stories = true,
        ["story-viewers"] = true, ["spotlight-feed"] = true, ["spotlight-comments"] = true,
    }
    for name in pairs(feature_callbacks) do
        local action = name:match("^sky_phone:(.+)$")
        local operation = name:match("^sky_phone:skypic:(.+)$")
        assert(read_only[operation] or SkyPhoneLog.Actions[action], "SkyPic mutation missing from audit catalog: " .. name)
    end
    print("Actual SkyPic branch logging integration passed")
end

-- Exercise actual output in each shipped language, including catalog fields
-- and status values that previously fell back to internal English names.
for _, case in ipairs({
    { "en", "Calls", "Microphone muted", "Story visibility", "Friends", "Property" },
    { "de", "Anrufe", "Mikrofon stummgeschaltet", "Story-Sichtbarkeit", "Freunde", "Immobilien" },
    { "es", "Llamadas", "Micrófono silenciado", "Visibilidad de las historias", "Amigos", "Inmuebles" },
}) do
    reset()
    Config.Bridge.Locale = case[1]
    local language = Locales[case[1]]
    local labels = language.DiscordAudit
    for name, spec in pairs(SkyPhoneLog.Actions) do
        assert(language.Nui.AdminPanel.webhooks.categoryLabels[spec.category], "Missing category: " .. case[1] .. ": " .. spec.category)
        for key in spec.fields:gmatch("%S+") do
            assert(labels.fields[key], "Missing audit field: " .. case[1] .. ": " .. key)
        end
        for _, data in ipairs({ {}, { enabled = true, active = true, saved = true, blocked = true,
            accepted = true, accept = true, id = 1, favorite = true, forEveryone = true, draft = true } }) do
            local state = type(spec.status) == "function" and spec.status(data) or spec.status
            assert(labels.states[state], "Missing audit state: " .. case[1] .. ": " .. name .. " / " .. state)
        end
    end
    local title, description = SkyPhoneLog.FormatAudit("Calls", "calls:set-muted", "muted", {
        actor = { name = "Sample user" }, details = { request = { enabled = true } },
    }, 1800000000)
    assert(title == case[2] .. " · " .. case[3], title)
    assert(description:find("<t:1800000000:F>", 1, true))
    assert(description:find("<t:1800000000:R>", 1, true))
    title, description = SkyPhoneLog.FormatAudit("SkyPic", "skypic:update-profile", "edited", {
        actor = { name = "Sample user" }, details = { request = { story_privacy = "friends", allowStoryReplies = true,
            body = "friends", mediaType = "video" } },
    }, 1800000000)
    assert(description:find("**" .. case[4] .. ":** " .. case[5], 1, true), description)
    assert(description:find("**" .. labels.fields.body .. ":** friends", 1, true), "Player text must not be translated")
    local _, limited = SkyPhoneLog.FormatAudit("Device", "device:save", "saved", {
        details = { logLimit = "Additional content omitted", contentError = "Content lookup failed; request and result retained" },
    }, 1800000000)
    assert(limited:find(labels.values.omitted, 1, true))
    assert(limited:find(labels.values.lookupFailed, 1, true))
    WebHooks.Public.Marketplace = fallback_url
    assert(SkyPhoneLog.Publish("marketplace:create", { status = "published", body = "Unchanged player text", category = "property" }))
    advance()
    local embed = requests[1].payload.embeds[1]
    assert(embed.title == language.DiscordPublic.published)
    assert(embed.fields[1].name == language.DiscordPublic.category)
    assert(embed.fields[1].value == case[6], embed.fields[1].value)
    assert(embed.description == "Unchanged player text")
    assert(SkyPhoneLog.ContentLabel("Marketplace", "category", "custom player category") == "custom player category")
end
reset()
Config.Bridge.Locale = "missing-locale"
assert(SkyPhoneLog.AppLabel("Calls") == "Calls", "Unknown languages must retain the English fallback")

local file = assert(io.open("sky_phone/fxmanifest.lua", "rb"))
local manifest = file:read("*a"); file:close()
local server = assert(manifest:match("server_scripts%s*{(.-)}"))
assert(server:find("'config/WebHooks.lua'", 1, true))
assert(server:find("'source/server/logging_actions.lua'", 1, true) < server:find("'source/bridge/server/callbacks.lua'", 1, true))
for _, section in ipairs({ "shared_scripts", "client_scripts", "files" }) do
    local content = assert(manifest:match(section .. "%s*{(.-)}"))
    assert(not content:find("WebHooks", 1, true) and not content:find("logging", 1, true))
    assert(not content:find("config/%*"), "A config glob could publish server secrets")
end
print("Server Discord logging tests passed")
