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

-- Public YACA v3.4.0 exports: apps/yaca-client/src/yaca/radio.ts.
-- The volume export takes (channel, volume); selecting the same secondary channel toggles it off.
local function yaca_bridge_fixture(allow_secondary)
    local state = {
        enabled = false,
        active = 1,
        secondary = -1,
        frequencies = { [1] = "0", [2] = "0" },
        muted = {},
        volumes = { [1] = 1, [2] = 1 },
    }
    local voice = {
        isEnabled = function() return true end,
        isRadioEnabled = function() return state.enabled end,
        enableRadio = function(_, enabled) state.enabled = enabled end,
        setActiveRadioChannel = function(_, channel) state.active = channel; return true end,
        getSecondaryRadioChannel = function() return state.secondary end,
        setSecondaryRadioChannel = function(_, channel)
            state.secondary = state.secondary == channel and -1 or channel
            return true
        end,
        changeRadioFrequency = function(_, frequency) state.frequencies[state.active] = frequency end,
        changeRadioFrequencyRaw = function(_, channel, frequency) state.frequencies[channel] = frequency end,
        muteRadioChannelRaw = function(_, channel, muted) state.muted[channel] = muted end,
        changeRadioChannelVolumeRaw = function(_, channel, volume)
            if state.volumes[channel] == nil then return false end
            state.volumes[channel] = math.max(0, math.min(1, volume))
            return true
        end,
    }
    local environment = setmetatable({
        Config = { Radio = { VoiceProvider = "yaca", AllowSecondary = allow_secondary } },
        Bridge = {
            Radio = {},
            PlayerState = { GetBlockReason = function() end },
            Debug = function() end,
        },
        exports = { ["yaca-voice"] = voice },
        GetResourceState = function(resource) return resource == "yaca-voice" and "started" or "missing" end,
        AddEventHandler = function() end,
        Wait = function() end,
    }, { __index = _G })
    assert(loadfile("sky_phone/source/bridge/client/radio.lua", "t", environment))()
    return environment.Bridge.Radio, state
end

local yaca_radio, yaca_state = yaca_bridge_fixture(true)
assert(yaca_radio.Join(150, 160) and yaca_state.enabled)
assert(yaca_state.frequencies[1] == "150" and yaca_state.frequencies[2] == "160")
for _, volume in ipairs({ 35, 0, 100 }) do
    yaca_radio.SetVolume(volume)
    assert(yaca_state.volumes[1] == volume / 100, "YACA primary volume must follow the phone slider")
    assert(yaca_state.volumes[2] == volume / 100, "YACA secondary volume must follow the phone slider")
end
assert(yaca_state.secondary == 2 and not yaca_state.muted[2])
assert(yaca_radio.Join(151, 161))
assert(yaca_state.secondary == 2, "reconnecting YACA must keep the secondary channel selected")
assert(yaca_state.frequencies[1] == "151" and yaca_state.frequencies[2] == "161")
yaca_radio.Leave()
assert(not yaca_state.enabled and yaca_state.frequencies[1] == "0" and yaca_state.frequencies[2] == "0")
assert(yaca_radio.Join(152, 162))
assert(yaca_state.secondary == 2, "rejoining after leaving YACA must restore secondary transmission")

local primary_radio, primary_state = yaca_bridge_fixture(false)
assert(primary_radio.Join(150, 160))
primary_radio.SetVolume(35)
assert(primary_state.volumes[1] == 0.35 and primary_state.volumes[2] == 1)
assert(primary_state.secondary == -1 and primary_state.frequencies[2] == "0" and primary_state.muted[2])
print("PASS YACA bridge: slider volume, secondary reconnect, leave/rejoin and primary-only configuration")
