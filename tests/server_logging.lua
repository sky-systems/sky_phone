-- Run from the repository root with Lua 5.4. HTTP and timers are local doubles;
-- this test never contacts Discord or requires a configured webhook.
local now, timers, requests, diagnostics, responses, encoded, queries
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
        assert(method == "POST" and headers["Content-Type"] == "application/json")
        assert(options.followLocation == false, "Webhook requests must not follow redirects")
        requests[#requests + 1] = { at = now, url = url, body = body, payload = encoded[body] }
        local response = table.remove(responses, 1) or { status = 200 }
        callback(response.status, response.body, response.headers)
    end
    dofile("sky_phone/config/WebHooks.lua")
    dofile("sky_phone/source/server/logging.lua")
    dofile("sky_phone/source/server/logging_actions.lua")
    dofile("sky_phone/source/server/logging_content.lua")
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
    return assert(encoded[description:sub(9, -5)], "Expected one-part audit JSON")
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
    joined[#joined + 1] = embed.description:sub(9, -5)
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
        assert(requests[#requests].payload.embeds[1].title:find(case[3], 1, true))
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
