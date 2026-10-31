-- Local activity history must work without Discord and must not turn panel reads
-- into writes or repeat the catalog's expensive Discord content lookups.
local queries, diagnostics, callbacks, encoded = {}, {}, {}, {}
local migration_ready, authorized, allowed = nil, true, true
local owner, now, insert_affected = "test-owner", 2000, 1
local rows = {}
local real_time = os.time
os.time = function() return now end
local function encode(value)
    if type(value) == "string" then
        return '"' .. value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
    end
    if type(value) == "number" or type(value) == "boolean" then return tostring(value) end
    if type(value) ~= "table" then return "null" end
    local parts = {}
    for key, item in pairs(value) do parts[#parts + 1] = encode(tostring(key)) .. ":" .. encode(item) end
    return "{" .. table.concat(parts, ",") .. "}"
end
json = {
    encode = function(value)
        local body = encode(value)
        encoded[body] = value
        return body
    end,
    decode = function(value) return assert(encoded[value], "Invalid test JSON") end,
}
Config = { AdminPanel = {
    Enabled = true, Command = "phonepanel", ActivityLimit = 2,
    ReadRequestsPerMinute = 60, ActionRequestsPerMinute = 30,
} }
WebHooks = { Enabled = false }
Bridge = {
    Debug = function(_, message, ...) diagnostics[#diagnostics + 1] = message:format(...) end,
    Framework = {
        GetIdentifier = function(source) return source ~= 99 and owner or nil end,
        HasPermission = function() return authorized end,
    },
    Database = {
        AfterMigration = function(_, callback) migration_ready = callback end,
        Query = function(sql, params)
            queries[#queries + 1] = { sql = sql, params = params }
            if sql:find("INSERT", 1, true) then return { affectedRows = insert_affected } end
            if sql:find("SELECT", 1, true) then return rows end
            return { affectedRows = 0 }
        end,
    },
    Callbacks = { Register = function(name, callback) callbacks[name] = callback end },
}
SkyPhone = {
    AllowOperation = function() return allowed end,
    GetLogIdentity = function() return { imei = "123456789012345", phoneNumber = "5550100", accountId = 1 } end,
}
SkyPhoneImei = { IsValid = function(value) return type(value) == "string" and value:match("^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$") ~= nil end }
function GetPlayerName(source) return "Test Player " .. source end
function RegisterCommand() end
function AddEventHandler() end
function SetTimeout() error("Local activity must not start webhook timers") end
function PerformHttpRequest() error("Local activity must not contact Discord") end

dofile("sky_phone/source/server/logging.lua")
dofile("sky_phone/source/server/logging_actions.lua")
dofile("sky_phone/source/server/logging_activity.lua")
local function send(source, data)
    return { success = true, data = { body = data.body, password = "never-store", token = "never-store",
        nested = { api_key = "never-store", text = "retained" } } }
end
local wrapped = SkyPhoneLog.WrapCallback("sky_phone:messages:send", send)
wrapped(1, { body = "Before schema" })
assert(#queries == 0, "Activity logging must wait for its schema")
migration_ready()
local spec = SkyPhoneLog.Actions["messages:send"]
spec.before = function() error("Local history must not perform Discord pre-image reads") end
spec.enrich = function() error("Local history must not perform Discord enrichment reads") end
local result = wrapped(1, { body = "A real message", password = "never-store", source = 99 })
assert(result.success and result.data.password == "never-store", "Logging must preserve the callback response")
assert(#queries == 2 and queries[1].sql:find("INSERT", 1, true) and queries[2].sql:find("DELETE", 1, true))
local params = queries[1].params
assert(params[1] == "test-owner" and params[2] == 1 and params[4] == "123456789012345")
assert(params[6] == "Messages" and params[7] == "messages:send" and params[8] == "sent")
assert(not params[9]:find("never-store", 1, true), "Secrets must be removed recursively")
assert(encoded[params[9]].request.body == "A real message" and encoded[params[9]].request.source == nil)
assert(encoded[params[9]].result.nested.text == "retained")
wrapped(1, { body = "Second" })
assert(#queries == 3, "Retention must not add a query to every mutation")
assert(SkyPhoneLog.WrapCallback("sky_phone:feather:feed", send) == send, "Uncatalogued reads must not be wrapped")
local rejected = SkyPhoneLog.WrapCallback("sky_phone:messages:send", function() return { success = false } end)
local crashed = SkyPhoneLog.WrapCallback("sky_phone:messages:send", function() error("failure") end)
rejected(1, {})
assert(not pcall(crashed, 1, {}) and #queries == 3, "Failed mutations must not create success records")

-- A callback can yield while its source disconnects. Bind history to the actor
-- who began the mutation, not a character who later receives the same source ID.
local reassigned = SkyPhoneLog.WrapCallback("sky_phone:messages:send", function()
    owner = "successor-owner"
    return { success = true }
end)
reassigned(1, { body = "Original actor" })
assert(queries[#queries].params[1] == "test-owner")
owner = "test-owner"

local interleaved = SkyPhoneLog.WrapCallback("sky_phone:messages:send", function(source)
    SkyPhoneLog.Capture("owned", { source = source })
    coroutine.yield()
    return { success = true }
end)
local first = coroutine.create(function() interleaved(1, {}) end)
local second = coroutine.create(function() interleaved(2, {}) end)
assert(coroutine.resume(first) and coroutine.resume(second))
assert(coroutine.resume(second) and coroutine.resume(first))
assert(encoded[queries[#queries].params[9]].snapshots.owned.source == 1)
assert(encoded[queries[#queries - 1].params[9]].snapshots.owned.source == 2)

SkyPhoneLog.Record("Messages", "messages:send", "sent", 1, { body = string.rep("\n", 12000) },
    { name = string.rep("ä", 130), imei = "123456789012345" })
assert(#queries[#queries].params[9] <= 16384, "Encoded details need a byte limit too")
assert(utf8.len(queries[#queries].params[3]) == 120, "Actor names must retain valid UTF-8")
assert(encoded[queries[#queries].params[9]].logLimit, "Omitted oversized content must be explicit")
insert_affected = 0
local query_count = #queries
assert(not SkyPhoneLog.Record("Messages", "messages:send", "sent", 1, {}))
assert(#queries == query_count + 1 and #diagnostics == 1, "Failed persistence must be visible")
insert_affected = 1
Config.AdminPanel.Enabled = false
wrapped(1, {})
assert(#queries == query_count + 1, "Disabling the AdminPanel must disable local recording")
Config.AdminPanel.Enabled = true
now = now + 601
wrapped(1, {})
assert(queries[#queries].sql:find("LIMIT 1000", 1, true), "Retention deletion must be bounded")

-- Exercise the real authorized reader. No ownership identifier comes from NUI,
-- BIGINT IDs remain strings, and keyset pagination ignores newer inserts.
Bridge.Database.AfterMigration = function(_, callback) callback() end
dofile("sky_phone/source/server/admin.lua")
local list = assert(callbacks["sky_phone:admin:phone-activity"])
queries = {}
authorized = false
assert(list(1, {}).error == "not_authorized" and #queries == 0)
authorized, allowed = true, false
assert(list(1, {}).error == "rate_limited" and #queries == 0)
allowed = true
local activity_enabled = SkyPhoneLog.ActivityEnabled
SkyPhoneLog.ActivityEnabled = function() return false end
assert(list(1, {}).error == "server_initializing" and #queries == 0,
    "Unavailable recording must be shown as initialization failure, not empty history")
SkyPhoneLog.ActivityEnabled = activity_enabled
for _, cursor in ipairs({ "0", "-1", "1.5", "1 OR 1", "18446744073709551616", 10 }) do
    assert(list(1, { beforeId = cursor }).error == "invalid_request")
end
assert(list(1, { source = 99 }).error == "player_unavailable")
assert(list(1, { imei = "invalid" }).error == "invalid_request")
assert(list(1, { category = "'); DROP" }).error == "invalid_request")
assert(#queries == 0)
local detail_json = json.encode({ request = { body = "Visible" } })
for index, id in ipairs({ "9007199254740995", "9007199254740994", "9007199254740993" }) do
    rows[index] = { id = id, actor_source = 1, actor_name = "Test Player", device_imei = "123456789012345",
        phone_number = "5550100", category = "Messages", action = "messages:send", status = "sent",
        details = detail_json, created_at = "2026-01-01 12:00:00" }
end
local page = list(1, { source = 1, owner_identifier = "attacker-controlled", imei = "123456789012345",
    category = "Messages", beforeId = "9007199254740996" })
assert(page.success and #page.data.items == 2 and page.data.hasMore)
assert(page.data.nextBeforeId == "9007199254740994" and page.data.items[1].id == "9007199254740995")
assert(page.data.items[1].ownerIdentifier == nil and page.data.items[1].details.request.body == "Visible")
assert(#queries == 1 and queries[1].sql:find("ORDER BY activity.`id` DESC LIMIT 3", 1, true))
assert(queries[1].sql:find("CAST(activity.`id` AS CHAR) AS `id`", 1, true)
    and queries[1].sql:find("activity.`id` < ?", 1, true),
    "String output IDs must not change the numeric ordering/cursor column")
assert(not queries[1].sql:find("ORDER BY `id`", 1, true),
    "MySQL resolves an unqualified ORDER BY id to the CAST string alias, causing page overlap")
assert(queries[1].params[1] == "test-owner" and queries[1].params[4] == "9007199254740996")
rows = {}
page = list(1, {})
assert(page.success and #page.data.items == 0 and not page.data.hasMore and page.data.nextBeforeId == nil)
for _, query in ipairs(queries) do
    assert(not query.sql:find("INSERT", 1, true) and not query.sql:find("UPDATE", 1, true)
        and not query.sql:find("DELETE", 1, true), "Panel reads must remain read-only")
end
os.time = real_time
for _, path in ipairs({ "sky_phone/source/server/db_migrate.lua", "sky_phone/sql/install.sql" }) do
    local file = assert(io.open(path, "rb"))
    local schema = file:read("*a")
    file:close()
    local index = assert(schema:find("idx_sky_phone_activity_category", 1, true),
        "Both migration and fresh-install schema must index the global category filter")
    assert(schema:sub(index, index + 120):find("(`category`, `id`)", 1, true),
        "The category index must preserve the numeric activity cursor as its second column")
end
print("Local phone activity persistence, redaction, retention, permissions and cursor tests passed")
dofile("tests/server_activity_dispatch.lua")
