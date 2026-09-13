local function new_server(failing_module, yielding_module)
    local events, logs, timers = {}, {}, {}
    local queries = 0
    local response
    local env = setmetatable({ Config = {} }, { __index = _G })
    env.IsDuplicityVersion = function() return true end
    env.vector3 = function(x, y, z) return { x = x, y = y, z = z } end
    env.GetGameTimer = function() return 0 end
    env.RegisterNetEvent = function(name, callback) events[name] = callback end
    env.AddEventHandler = env.RegisterNetEvent
    env.SetTimeout = function(delay, callback)
        assert(delay == 30000)
        timers[#timers + 1] = callback
    end
    env.TriggerClientEvent = function(name, player, request_id, result)
        assert(name == "sky_phone:bridge:callback:response" and player == 7 and request_id == 1)
        response = result
    end
    env.Bridge = {
        Callbacks = {},
        Database = { Query = function()
            queries = queries + 1
            return {}
        end },
        Debug = function(level, message, ...)
            logs[#logs + 1] = { level = level, message = message:format(...) }
        end,
    }
    local function load_script(path)
        assert(loadfile("sky_phone/" .. path, "t", env))()
    end
    load_script("config/config.lua")
    load_script("source/bridge/server/migrations.lua")
    load_script("source/bridge/server/callbacks.lua")
    env.Bridge.Database.AfterMigration("sky_phone", function()
        env.SkyPhone = { AllowOperation = function() return true end }
    end)
    if yielding_module then
        env.Bridge.Database.AfterMigration("sky_phone", function()
            coroutine.yield("waiting_for_module")
        end)
    end
    if failing_module then
        env.Bridge.Database.AfterMigration("sky_phone", function()
            error("simulated unrelated initialization failure")
        end)
    end
    load_script("source/server/custom_tones.lua")
    load_script("source/server/citywarn.lua")

    local server = { env = env, logs = logs }
    function server.request(name)
        env.source = 7
        response = nil
        events["sky_phone:bridge:callback:request"](name, 1, {})
        return response
    end
    function server.complete()
        return pcall(env.Bridge.Database.CompleteMigration, "sky_phone")
    end
    function server.watchdog()
        for _, callback in ipairs(timers) do callback() end
    end
    function server.queries() return queries end
    return server
end

local endpoints = { "sky_phone:tones:list", "sky_phone:citywarn:blips" }
local server = new_server()
for _, name in ipairs(endpoints) do
    assert(server.request(name).error == "server_initializing",
        "known public reads must be declared before migrations finish")
end
assert(server.queries() == 0 and #server.logs == 0,
    "early reads must not touch incomplete tables or report missing callbacks")
assert(server.complete())
for _, name in ipairs(endpoints) do
    assert(server.request(name).success, "registration must recover after a delayed migration")
end
assert(server.queries() == 2)
local log_count = #server.logs
server.watchdog()
assert(#server.logs == log_count, "registered callbacks must cancel the startup warning")
assert(not server.complete(), "completion must not initialize modules twice")
assert(not pcall(server.env.Bridge.Callbacks.Register, endpoints[1], function() end),
    "deferred registration must preserve duplicate-handler protection")
assert(server.request("sky_phone:missing") == nil)
assert(server.logs[#server.logs].level == "error", "unknown callback failures must remain visible")

server = new_server()
server.watchdog()
assert(#server.logs == 2 and server.logs[1].level == "warn" and server.logs[2].level == "warn",
    "stalled initialization must be reported even when bridge debugging is off")
assert(server.queries() == 0, "a stall must not bypass database initialization")
assert(server.complete())
assert(server.request(endpoints[1]).success and server.request(endpoints[2]).success,
    "a startup exceeding the watchdog interval must still recover")

server = new_server(false, true)
local initialization = coroutine.create(server.complete)
local resumed, state = coroutine.resume(initialization)
assert(resumed and state == "waiting_for_module", "initialization callbacks must remain yieldable")
assert(server.request(endpoints[1]).error == "server_initializing" and server.queries() == 0,
    "public reads must stay pending while an earlier initialization callback yields")
resumed, state = coroutine.resume(initialization)
assert(resumed and state == true)
assert(server.request(endpoints[1]).success and server.request(endpoints[2]).success,
    "initializers must resume in order after asynchronous database work")

server = new_server(true)
local success, reason = server.complete()
assert(not success and reason:find("module initialization callback", 1, true),
    "initialization errors must still fail completion and retain their diagnostics")
local found_error = false
for _, log in ipairs(server.logs) do
    if log.level == "error" and log.message:find("simulated unrelated initialization failure", 1, true) then
        found_error = true
    end
end
assert(found_error, "the original initialization error and traceback must be logged")
for _, name in ipairs(endpoints) do
    assert(server.request(name).success, "an unrelated module failure must not discard queued public callbacks")
end

print("Server callback startup and recovery tests passed")
