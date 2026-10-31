-- Match real manifest ordering: register Notes while migration is pending,
-- complete migration, then load the local sink and dispatch through the bridge.
local events, queries, diagnostics, responses = {}, {}, {}, {}
local encoded = {}
local env = setmetatable({
    Config = { AdminPanel = { Enabled = true } },
    WebHooks = { Enabled = false },
    GetPlayerName = function(source) return "Test Player " .. tostring(source) end,
    RegisterNetEvent = function(name, handler) events[name] = handler end,
    GetGameTimer = function() return 1000 end,
    SetTimeout = function() error("Local logging must not start webhook timers") end,
    SkyPhoneCellular = { RequiresSignal = function() return false end },
    json = {
        encode = function(value)
            local key = "json_" .. tostring(#encoded + 1)
            encoded[#encoded + 1] = value
            return key
        end,
        decode = function() error("Dispatch test does not need JSON decoding") end,
    },
}, { __index = _G })
env.SkyPhone = {
    AllowOperation = function() return true end,
    RequireSession = function() return { imei = "123456789012345" } end,
    RequireAccount = function() return { id = 1 } end,
    RefreshAccount = function() end,
    GetLogIdentity = function() return { imei = "123456789012345", accountId = 1, phoneNumber = "5550100" } end,
}
env.Bridge = {
    Callbacks = {},
    Framework = { GetIdentifier = function() return "test-owner" end },
    Debug = function(_, message, ...) diagnostics[#diagnostics + 1] = message:format(...) end,
    Network = { SendClient = function(event, target, request_id, response)
        assert(event == "sky_phone:bridge:callback:response" and target == 8)
        responses[request_id] = response
        return true
    end },
    Database = { Query = function(sql, params)
        queries[#queries + 1] = { sql = sql, params = params }
        if sql:find("INSERT", 1, true) then return { affectedRows = 1 } end
        return {}
    end },
}
local function load_script(path)
    assert(loadfile("sky_phone/" .. path, "t", env))()
end
load_script("source/bridge/server/migrations.lua")
load_script("source/server/logging.lua")
load_script("source/server/logging_actions.lua")
load_script("source/bridge/server/callbacks.lua")
load_script("source/server/notes.lua")
env.Bridge.Database.CompleteMigration("sky_phone")
load_script("source/server/logging_activity.lua")
assert(env.SkyPhoneLog.ActivityEnabled(), "A sink loaded after completed migration must become ready")
env.source = 8
events["sky_phone:bridge:callback:request"]("sky_phone:notes:create", 1, {
    id = "test-dispatch-note", title = "Test activity", body = "Only synthetic text", pinned = false,
})
assert(responses[1] and responses[1].success)
events["sky_phone:bridge:callback:request"]("sky_phone:notes:delete", 2, { id = "test-dispatch-note" })
assert(responses[2] and responses[2].success)
local inserts = 0
for _, query in ipairs(queries) do
    if query.sql:find("INSERT INTO `sky_phone_activity_log`", 1, true) then
        inserts = inserts + 1
        assert(query.params[1] == "test-owner" and query.params[6] == "Notes")
    end
end
assert(inserts == 2, "Actual bridge-dispatched Notes create/delete must each persist one activity")
assert(#diagnostics == 1, "Only the normal migration-completed diagnostic is expected")
print("Real bridge dispatch and post-migration local activity sink integration passed")
