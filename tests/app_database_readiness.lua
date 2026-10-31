local events, responses, config_events = {}, {}, {}
local env = setmetatable({ Config = { Apps = { picstagram = false } }, source = 7,
    AddEventHandler = function(name, callback) config_events[name] = callback end,
    RegisterNetEvent = function(name, callback) events[name] = callback end,
    SetTimeout = function() end,
    SkyPhoneCellular = { RequiresSignal = function() return false end },
    Bridge = {
        Debug = function() end,
        Callbacks = {},
        Network = { SendClient = function(_, _, id, response) responses[id] = response; return true end },
        Database = { AfterMigration = function(_, callback) callback() end,
            Migrate = function() coroutine.yield("schema_pending") end },
    },
}, { __index = _G })
assert(loadfile("sky_phone/source/server/app_database.lua", "t", env))()
env.SkyPhoneAppDatabase.Remember({ { name = "sky_phone_picstagram_posts" } })
assert(loadfile("sky_phone/source/bridge/server/callbacks.lua", "t", env))()
env.SkyPhoneAppDatabase.WhenEnabled("picstagram", function()
    env.Bridge.Callbacks.Register("sky_phone:picstagram:bootstrap", function() return { success = true } end)
end)
env.Config.Apps.picstagram = true
local startup = coroutine.create(config_events["sky_phone:configurator:serverUpdated"])
local ok, pending = coroutine.resume(startup)
assert(ok and pending == "schema_pending")
events["sky_phone:bridge:callback:request"]("sky_phone:picstagram:bootstrap", 1, {})
assert(responses[1].error == "server_initializing", "Newly enabled callbacks must remain initializing while DDL yields")
assert(coroutine.resume(startup))
events["sky_phone:bridge:callback:request"]("sky_phone:picstagram:bootstrap", 2, {})
assert(responses[2].success, "The same callback must become available after its module registers")
print("app database: callback readiness survives lazy schema initialization")
