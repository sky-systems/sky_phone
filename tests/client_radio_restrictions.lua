local function fixture()
    local e = setmetatable({}, { __index = _G })
    local state = { nui = {}, net = {}, events = {}, messages = {}, joined = 0, left = 0, blocked = nil }
    e.Config = { Radio = { AutoRejoin = false, Notifications = false, DefaultVolume = 50 } }
    e.Bridge = { Debug = function() end, Radio = {}, Callbacks = {}, PlayerState = {} }
    e.Bridge.PlayerState.GetBlockReason = function() return state.blocked end
    local radio = e.Bridge.Radio
    radio.SupportsSecondary = function() return true end
    radio.SupportsSpeaker = function() return false end
    radio.GetProvider = function() return "yaca" end
    radio.GetSpeaker = function() return false end
    radio.Join = function() state.joined = state.joined + 1; if state.on_join then state.on_join() end; return true end
    radio.Leave = function() state.left = state.left + 1 end
    radio.SetVolume = function() end
    e.Bridge.Callbacks.Trigger = function(name)
        if state.on_request then state.on_request(name) end
        return { success = true, data = { frequency = 150, secondaryFrequency = 160, connected = true } }
    end
    e.RegisterNUICallback = function(name, fn) state.nui[name] = fn end
    e.RegisterNetEvent = function(name, fn) state.net[name] = fn end
    e.AddEventHandler = function(name, fn) state.events[name] = fn end
    e.SendNUIMessage = function(message) state.messages[#state.messages + 1] = message end
    e.SetTimeout = function() end
    assert(loadfile("sky_phone/source/client/radio.lua", "t", e))()
    return state
end
local function connect(state)
    local result
    state.nui["radio:connect"]({ frequency = 150, secondaryFrequency = 160 }, function(value) result = value end)
    return result
end
local s = fixture()
s.blocked = "player_cuffed"
assert(connect(s).error == "player_cuffed" and s.joined == 0)
s.blocked = nil; assert(connect(s).success and s.joined == 1)
s.events["sky_phone:client:restricted"]("player_incapacitated")
assert(s.left == 1 and s.messages[#s.messages].type == "radio:disconnected")
for _, phase in ipairs({ "on_request", "on_join" }) do
    local r = fixture()
    r[phase] = function() r[phase] = nil; coroutine.yield() end
    local result
    local task = coroutine.create(function() result = connect(r) end)
    local ok, err = coroutine.resume(task); assert(ok, err)
    r.net["sky_phone:radio:disconnected"]({ reason = "phone_not_owned" })
    ok, err = coroutine.resume(task); assert(ok, err)
    assert(not result.success, phase)
    if phase == "on_request" then assert(r.joined == 0) else assert(r.left >= 2) end
end
local g = fixture()
g.on_request = function() g.on_request = nil; coroutine.yield() end
local response
local task = coroutine.create(function() g.nui["radio:get"]({}, function(value) response = value end) end)
assert(coroutine.resume(task))
g.net["sky_phone:radio:disconnected"]({ reason = "phone_not_owned" })
local ok, err = coroutine.resume(task); assert(ok, err)
assert(not response.success, "Late radio:get must not restore channel state after forced leave")
print("PASS client radio: blocked joins, local cleanup, late server replies, yielding providers and stale loads")

local y = fixture()
local requests = 0
y.on_request = function() requests = requests + 1 end
y.on_join = function()
    y.net["yaca:external:setRadioFrequency"](1, "150")
    y.net["yaca:external:setRadioFrequency"](2, "160")
end
assert(connect(y).success)
y.net["yaca:external:setRadioFrequency"](1, "150")
y.net["yaca:external:setRadioFrequency"](2, "160")
assert(requests == 1 and y.left == 0, "Yaca frequency confirmations must not duplicate/rate-limit the approved join")
y.net["sky_phone:radio:disconnected"]({ reason = "phone_not_owned" })
y.net["yaca:external:setRadioFrequency"](1, "0")
y.net["yaca:external:setRadioFrequency"](2, "0")
assert(requests == 1, "Yaca leave confirmations must not start recursive disconnects")
print("PASS Yaca: frequency echoes are idempotent during join, after approval and after forced leave")
