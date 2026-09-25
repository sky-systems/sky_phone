SkyPhoneCellular = { RequiresSignal = function() return false end }
local function new_network(server)
    local sent, events, timers, logs = {}, {}, {}, {}
    local packed_arguments, pack_count, forced_size, pack_failure, send_failure
    local env = setmetatable({ Config = { Bridge = { CallbackTimeout = 15000 } } }, { __index = _G })
    env.Bridge = { Callbacks = {}, Debug = function(level, message, ...)
        logs[#logs + 1] = { level = level, message = message:format(...) }
    end }
    env.IsDuplicityVersion = function() return server end
    env.msgpack = { pack_args = function(...)
        if pack_failure then error("test pack failure") end
        pack_count = (pack_count or 0) + 1
        packed_arguments = table.pack(...)
        return string.rep("x", forced_size or 20)
    end }
    local function send(kind, ...)
        if send_failure then error("test native failure") end
        sent[#sent + 1] = { kind = kind, arguments = table.pack(...), payload = packed_arguments }
    end
    env.TriggerClientEventInternal = function(...) send("client", ...) end
    env.TriggerLatentClientEventInternal = function(...) send("latent-client", ...) end
    env.TriggerServerEventInternal = function(...) send("server", ...) end
    env.TriggerLatentServerEventInternal = function(...) send("latent-server", ...) end
    env.RegisterCommand = function() end
    env.RegisterNetEvent = function(name, callback) events[name] = callback end
    env.AddEventHandler = env.RegisterNetEvent
    env.SetTimeout = function(_, callback) timers[#timers + 1] = callback end
    env.GetCurrentResourceName = function() return "sky_phone" end
    env.promise = { new = function()
        return { resolve = function(self, value) self.done = true; self.value = value end }
    end }
    env.Citizen = { Await = function(request)
        if not request.done then coroutine.yield("pending") end
        assert(request.done)
        return request.value
    end }
    assert(loadfile("sky_phone/source/bridge/network.lua", "t", env))()
    return {
        env = env, sent = sent, events = events, timers = timers, logs = logs,
        size = function(value) forced_size = value end,
        fail_pack = function(value) pack_failure = value end,
        fail_send = function(value) send_failure = value end,
        pack_count = function() return pack_count end,
    }
end

for _, server in ipairs({ true, false }) do
    local net = new_network(server)
    local function send(...)
        if server then return net.env.Bridge.Network.SendClient("sky_phone:test", -1, ...) end
        return net.env.Bridge.Network.SendServer("sky_phone:test", ...)
    end
    for _, size in ipairs({ 4095, 4096, 7913, 2 * 1024 * 1024 }) do
        net.size(size)
        local count = #net.sent
        assert(send("start", nil, { items = { 1, 2 } }, nil))
        assert(#net.sent == count + 1 and net.pack_count() == #net.sent, "pack exactly once per send")
        local entry = net.sent[#net.sent]
        assert(entry.kind == (size >= 4096 and "latent-" or "") .. (server and "client" or "server"))
        assert(entry.payload.n == 4 and entry.payload[2] == nil and entry.payload[3].items[2] == 2)
        local offset = server and 1 or 0
        assert(entry.arguments[1] == "sky_phone:test")
        if server then assert(entry.arguments[2] == "-1", "OAL target must be a string") end
        assert(#entry.arguments[2 + offset] == size and entry.arguments[3 + offset] == size)
        if size >= 4096 then assert(entry.arguments[4 + offset] == 1000000) end
    end
    net.fail_pack(true)
    assert(not send({}) and #net.sent == 4 and #net.logs == 1)
    net.fail_pack(false)
    net.fail_send(true)
    assert(not send({}) and #net.sent == 4 and #net.logs == 2)
end

local client = new_network(false)
assert(loadfile("sky_phone/source/bridge/client/callbacks.lua", "t", client.env))()
local function request(name)
    local result, completed
    local thread = coroutine.create(function()
        result = client.env.Bridge.Callbacks.Trigger(name, {})
        completed = true
    end)
    assert(coroutine.resume(thread))
    return function()
        if coroutine.status(thread) ~= "dead" then assert(coroutine.resume(thread)) end
        return result, completed
    end
end
client.size(7913)
local first, second = request("sky_phone:first"), request("sky_phone:second")
client.events["sky_phone:bridge:callback:response"](2, { value = "second" })
assert(second().value == "second", "responses must follow IDs, not delivery order")
client.events["sky_phone:bridge:callback:response"](1, { value = "first" })
assert(first().value == "first")
for _, timer in ipairs(client.timers) do timer() end
assert(#client.logs == 0, "completed requests must not later time out")
local timed = request("sky_phone:timeout")
client.timers[#client.timers]()
assert(timed() == nil)
client.events["sky_phone:bridge:callback:response"](3, { stale = true })
client.fail_pack(true)
local failed = request("sky_phone:pack-failure")
local result, completed = failed()
assert(result == nil and completed, "pack failures must resolve immediately")
client.fail_pack(false)
local stopped = request("sky_phone:stop")
client.events.onResourceStop("sky_phone")
assert(stopped() == nil)

local server = new_network(true)
assert(loadfile("sky_phone/source/bridge/server/callbacks.lua", "t", server.env))()
server.env.source = 71
server.env.Bridge.Callbacks.Register("sky_phone:large", function() return { body = "large result" } end)
server.size(100000)
server.events["sky_phone:bridge:callback:request"]("sky_phone:large", 19, {})
assert(server.sent[1].kind == "latent-client" and server.sent[1].arguments[2] == "71")
assert(server.sent[1].payload[1] == 19 and server.sent[1].payload[2].body == "large result")
print("Network transport and callback lifecycle tests passed")
