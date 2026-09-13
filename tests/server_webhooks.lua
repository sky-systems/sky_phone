-- Lua 5.4; exercises actual settings/admin callbacks with an in-memory DB double.
-- No network request is made and all webhook tokens here are test placeholders.
local encoded, queries, callbacks, audit = {}, {}, {}, {}
local db = { payload = "{}", revision = 0 }
local authorized, allowed, fail_write, race, delay_write = true, true, false, false, false
local query_count = 0
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
json = {
    encode = function(value)
        local key = "json:" .. (#encoded + 1)
        encoded[#encoded + 1] = copy(value)
        return key
    end,
    decode = function(value)
        if value == "{}" or value == "[]" then return {} end
        return copy(assert(encoded[tonumber(value:match("^json:(%d+)$"))]))
    end,
}
Bridge = {
    Debug = function() end,
    Framework = {
        HasPermission = function(source, permission) assert(source == 1 and permission == "phonepanel") return authorized end,
        GetIdentifier = function() return "test-admin" end,
        GetFirstname = function() return "Test" end,
        GetLastname = function() return "Admin" end,
    },
    Callbacks = { Register = function(name, callback) callbacks[name] = callback end },
    Database = {
        AfterMigration = function(name, callback) assert(name == "sky_phone") callback() end,
        Query = function(sql, params)
            query_count = query_count + 1
            queries[#queries + 1] = { sql = sql, params = params }
            if sql:find("INSERT IGNORE", 1, true) then return { affectedRows = 0 } end
            if sql:find("SELECT", 1, true) then return { copy(db) } end
            if sql:find("sky_phone_admin_audit", 1, true) then
                audit[#audit + 1] = json.decode(params[7])
                return { affectedRows = 1 }
            end
            assert(sql:find("WHERE `id` = 1 AND `revision` = ?", 1, true), "Updates must be conditional")
            if fail_write then error("simulated DB error with secret detail") end
            if race then
                race = false
                db.revision = db.revision + 1
                db.payload = json.encode({ Username = "Concurrent admin" })
            end
            if params[2] ~= db.revision then return { affectedRows = 0 } end
            db.payload, db.revision = params[1], db.revision + 1
            if delay_write then delay_write = false coroutine.yield() end
            return { affectedRows = 1 }
        end,
    },
}
SkyPhone = { AllowOperation = function() return allowed end }
Config = { AdminPanel = { Enabled = true, Command = "phonepanel", ReadRequestsPerMinute = 60, ActionRequestsPerMinute = 20 } }
function RegisterCommand() end
function AddEventHandler() end
function GetPlayerName() return "Test Admin" end
function SetTimeout() end
function GetGameTimer() return 0 end
function PerformHttpRequest() error("Tests must not contact Discord") end
dofile("sky_phone/config/WebHooks.lua")
local file_url = "https://discord.com/api/webhooks/123/FILE_TEST_TOKEN"
local replacement_url = "https://discord.com/api/webhooks/456/REPLACEMENT_TEST_TOKEN"
WebHooks.Calls = file_url
dofile("sky_phone/source/server/logging.lua")
dofile("sky_phone/source/server/logging_actions.lua")
dofile("sky_phone/source/server/logging_settings.lua")
dofile("sky_phone/source/server/admin.lua")

local function no_secrets(value)
    if type(value) == "string" then
        assert(not value:find("TEST_TOKEN", 1, true), "Stored endpoint leaked to a response/audit")
    elseif type(value) == "table" then
        for key, item in pairs(value) do no_secrets(key) no_secrets(item) end
    end
end
local function get()
    local response = callbacks["sky_phone:admin:webhooks"](1)
    no_secrets(response)
    return response
end
local function save(changes, revision)
    local response = callbacks["sky_phone:admin:save-webhooks"](1, {
        revision = revision or get().data.revision, changes = changes,
    })
    no_secrets(response)
    for _, entry in ipairs(audit) do no_secrets(entry) end
    return response
end
local function row(data, path)
    for _, endpoint in ipairs(data.endpoints) do if endpoint.path == path then return endpoint end end
    error("Missing endpoint: " .. path)
end

assert(row(get().data, "Calls").configured and row(get().data, "Calls").mode == "file")
assert(row(get().data, "Actions.skypic:send-snap").category == "SkyPic")
authorized = false
local before = query_count
assert(get().error == "not_authorized")
assert(save({}, 0).error == "not_authorized")
assert(query_count == before, "Unauthorized requests must not touch storage")
authorized, allowed = true, false
assert(get().error == "rate_limited")
assert(save({}, 0).error == "rate_limited")
allowed = true
Config.AdminPanel.Enabled = false
assert(get().error == "not_authorized")
Config.AdminPanel.Enabled = true

local saved = save({
    { path = "Calls", mode = "custom", url = replacement_url },
    { path = "AvatarUrl", value = "https://example.invalid/avatar.png" },
    { path = "Username", value = "Phone Audit" },
    { path = "Actions.skypic:send-snap", mode = "disabled" },
})
assert(saved.success and saved.data.revision == 1)
assert(WebHooks.Calls == replacement_url and WebHooks.AvatarUrl == "https://example.invalid/avatar.png")
assert(WebHooks.Actions["skypic:send-snap"] == false)
assert(#audit == 1 and audit[1].changeCount == 4)
assert(save({ { path = "Calls", mode = "custom", url = "" } }).success)
assert(WebHooks.Calls == replacement_url, "Masked empty input must preserve stored URL")
assert(save({ { path = "Calls", mode = "inherit" } }).success and WebHooks.Calls == "")
assert(save({ { path = "Calls", mode = "custom", url = "" } }).error == "invalid_webhook")
assert(save({ { path = "Calls", mode = "file" } }).success and WebHooks.Calls == file_url)
assert(save({ { path = "Calls", mode = "disabled" } }).success and WebHooks.Calls == false)
assert(save({ { path = "Calls", mode = "disabled" } }, 0).error == "revision_conflict")

local unchanged_revision, unchanged_audit = db.revision, #audit
for _, changes in ipairs({
    { { path = "Default", mode = "custom", url = "https://evil.invalid/api/webhooks/123/fake" } },
    { { path = "Default", mode = "custom", url = "https://discord.com.evil.invalid/api/webhooks/123/fake" } },
    { { path = "Default", mode = "custom", url = file_url .. "?wait=true" } },
    { { path = "AvatarUrl", value = file_url } },
    { { path = "QueueLimit", value = 0 } },
    { { path = "MaxAttempts", value = 11 } },
    { { path = "Enabled", value = "false" } },
    { { path = "Username", value = string.rep("a", 81) } },
    { { path = "Actions.unknown:action", mode = "disabled" } },
    { { path = "Calls", mode = "inherit" }, { path = "Calls", mode = "disabled" } },
    { { path = "Calls", mode = "inherit" }, { path = "QueueLimit", value = 0 } },
}) do assert(not save(changes).success) end
assert(db.revision == unchanged_revision and #audit == unchanged_audit and WebHooks.Calls == false,
    "Invalid changes must be atomic and unaudited")

fail_write = true
assert(save({ { path = "Calls", mode = "file" } }).error == "request_failed")
assert(db.revision == unchanged_revision and WebHooks.Calls == false)
fail_write, race = false, true
assert(save({ { path = "Username", value = "Losing edit" } }).error == "revision_conflict")
assert(WebHooks.Username == "Concurrent admin", "Concurrent database writer must win")
assert(save({ { path = "Calls", mode = "custom", url = replacement_url }, { path = "Enabled", value = false } }).success)
local restart_revision = db.revision
dofile("sky_phone/config/WebHooks.lua")
WebHooks.Calls = file_url
dofile("sky_phone/source/server/logging_settings.lua")
assert(get().data.revision == restart_revision and WebHooks.Calls == replacement_url and WebHooks.Enabled == false,
    "SQL overrides must survive resource restart, including boolean false")
assert(save({ { path = "Enabled", mode = "file" }, { path = "Calls", mode = "file" } }).success)
assert(WebHooks.Enabled == true and WebHooks.Calls == file_url)
-- A SQL completion arriving late must not roll runtime configuration backward.
local initial_revision = get().data.revision
delay_write = true
local slow_save = coroutine.create(function()
    assert(save({ { path = "Username", value = "Earlier edit" } }, initial_revision).success)
end)
assert(coroutine.resume(slow_save))
assert(save({ { path = "Username", value = "Stale edit" } }, initial_revision).error == "revision_conflict")
assert(save({ { path = "Username", value = "Latest edit" } }).success)
assert(coroutine.resume(slow_save))
assert(WebHooks.Username == "Latest edit" and get().data.revision == initial_revision + 2)
no_secrets(get())
print("Server webhook settings and Phonepanel authorization tests passed")
