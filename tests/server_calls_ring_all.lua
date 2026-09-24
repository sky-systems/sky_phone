-- Run from the repository root with Lua 5.4. Loads the complete calls module.
local function fixture(routing)
    local state = {
        callbacks = {}, handlers = {}, timers = {}, events = {}, devices = {},
        ready = {}, owned = {}, flight = {}, hidden = {}, rows = {}, entries = {},
        voice_starts = {}, voice_stops = {}, hooks = {}, threads = {},
    }
    local noop = function() end
    local function hook(name, ...)
        if state.hooks[name] then return state.hooks[name](...) end
    end
    local env = setmetatable({
        Config = {
            Calls = { RingSeconds = 30, RecentPageSize = 50 },
            Companies = { CallRouting = { MaxAttempts = 3, RingSeconds = 10 } },
            Sim = { Enabled = true, NumberLength = 7, NumberPrefix = "" },
            Payphones = {
                Enabled = true, Props = { "test-booth" }, PricePerSecond = 0, CallerNumber = "5559999",
                Animation = { HangupDurationMs = 2000 }, MaximumCallDistance = 5,
            },
        },
        json = { decode = function(value) return value end },
        SkyPhone = {}, SkyPhoneCompanies = {},
        SkyPhoneSimNumber = { Normalize = function(value) return value end },
        SkyPhonePayphones = { ValidateDetected = function()
            return { coords = { x = 0, y = 0, z = 0 }, model = "test-booth" }
        end },
        Bridge = { Callbacks = {}, Calls = {}, Database = {}, Framework = {}, Speaker = {} },
        AddEventHandler = function(name, callback) state.handlers[name] = callback end,
        CreateThread = function(callback) state.threads[#state.threads + 1] = callback end,
        SetTimeout = function(delay, callback) state.timers[#state.timers + 1] = { delay, callback } end,
        Wait = function() coroutine.yield() end,
        TriggerClientEvent = function(name, source, payload)
            state.events[#state.events + 1] = { name = name, source = source, payload = payload }
        end,
        GetCurrentResourceName = function() return "sky_phone" end,
        GetPlayerPed = function(source) return source end,
        GetPlayerRoutingBucket = function() return 0 end,
        GetEntityCoords = function() return { x = 0, y = 0, z = 0 } end,
        vector3 = function(x, y, z) return { x = x, y = y, z = z } end,
    }, { __index = _G })
    state.env = env
    for source = 1, 6 do
        state.devices[source] = {
            imei = "device-" .. source, sim_id = "sim-" .. source,
            phone_number = "555000" .. source, device_name = "Phone", account_id = source,
            sim_type = "registered", registered_at = 1,
        }
        state.owned[source] = true
        state.ready[source] = source >= 2 and source <= 4
    end
    local service = { number = "911", companyId = "police", canCall = true, routing = routing or "ring_all" }
    function env.SkyPhoneCompanies.GetServiceLine(number) return number == "911" and service or nil end
    function env.SkyPhoneCompanies.GetServiceLineForCompany() return service end
    function env.SkyPhoneCompanies.IsServiceNumber(number) return number == "911" end
    function env.SkyPhoneCompanies.CanUseServiceDevice(device)
        return device.sim_id ~= nil and (env.Config.Sim.Enabled == false
            or (device.sim_type == "registered" and device.registered_at ~= nil))
    end
    function env.SkyPhoneCompanies.CanAnswerCompanyCall(source, company, imei, sim)
        hook("permission", source)
        local device = state.devices[source]
        return state.ready[source] and device and device.imei == imei and device.sim_id == sim
            and company == "police"
    end
    function env.SkyPhoneCompanies.GetCallTargets()
        local targets = {}
        for source = 2, 4 do
            local device = state.devices[source]
            if state.ready[source] then
                targets[#targets + 1] = { source = source, imei = device.imei, simId = device.sim_id }
            end
        end
        return targets
    end
    function env.SkyPhone.RequireSession(source) return { imei = state.devices[source].imei } end
    function env.SkyPhone.LoadDevice(imei)
        for _, device in pairs(state.devices) do if device.imei == imei then return device end end
    end
    function env.SkyPhone.FindDeviceSlots(source, imei)
        hook("inventory", source)
        return state.owned[source] and state.devices[source].imei == imei and { 1 } or {}
    end
    function env.SkyPhone.OpenDeviceForCall(source)
        local opened = hook("open", source)
        return opened ~= false
    end
    env.SkyPhone.AllowOperation = function() return true end
    env.SkyPhone.NotifyAccount = noop
    env.Bridge.Debug = noop
    env.Bridge.Framework.GetPlayers = function() return { 1, 2, 3, 4, 5, 6 } end
    env.Bridge.Framework.GetMoney = function() return 1000 end
    env.Bridge.Framework.RemoveMoney = function() return true end
    env.Bridge.Speaker.IsEnabled = function() return false end
    env.Bridge.Calls.SupportsSpeaker = function() return false end
    env.Bridge.Calls.SupportsMute = function() return false end
    env.Bridge.Calls.IsAvailable = function() return true end
    function env.Bridge.Calls.Start(id, sources, channel)
        assert(type(channel) == "number" and channel > 0, "Reserve a numeric PMA channel before provider startup")
        state.voice_starts[#state.voice_starts + 1] = { id = id, sources = sources }
        hook("voice")
        return not state.fail_voice, "yaca"
    end
    function env.Bridge.Calls.Stop(id, sources)
        state.voice_stops[#state.voice_stops + 1] = { id = id, sources = sources }
    end
    env.Bridge.Calls.SetSpeaker = noop
    function env.Bridge.Callbacks.Register(name, callback) state.callbacks[name] = callback end
    function env.Bridge.Database.AfterMigration(_, callback) callback() end
    local next_uuid = 0
    function env.Bridge.Database.Query(sql, params)
        params = params or {}
        hook("query", sql, params)
        if sql:find("SELECT UUID()", 1, true) then
            next_uuid = next_uuid + 1
            return { { id = ("550e8400-e29b-41d4-a716-%012d"):format(next_uuid) } }
        end
        if sql:find("FROM `sky_phone_device_data`", 1, true) then
            return { { payload = { settings = {
                airplaneMode = state.flight[params[1]] == true,
                hideCallerId = state.hidden[params[1]],
            } } } }
        end
        if sql:find("INSERT INTO `sky_phone_calls`", 1, true) then
            state.rows[params[1]] = { status = "ringing", callee_sim_id = params[3], caller_number = params[4] }
            return { insertId = 1 }
        end
        if sql:find("INSERT INTO `sky_phone_call_entries`", 1, true) then
            local rerouted = sql:find("SELECT `id`, ?, ?", 1, true)
            local entry = {
                id = #state.entries + 1,
                call_id = rerouted and params[4] or params[1],
                account = rerouted and params[1] or params[2],
                direction = rerouted and "incoming" or params[4],
                status = rerouted and "ringing" or params[5],
                other_number = rerouted and params[3] or params[6],
            }
            state.entries[entry.id] = entry
            return { insertId = entry.id }
        end
        if sql:find("UPDATE `sky_phone_calls`", 1, true) then
            if sql:find("'connected'", 1, true) then
                local row = assert(state.rows[params[2]])
                if row.status == "ringing" then row.status, row.callee_sim_id = "connected", params[1] end
            elseif sql:find("`ended_at`", 1, true) then
                assert(state.rows[params[3]]).status = params[1]
            else
                assert(state.rows[params[2]]).callee_sim_id = params[1]
            end
            return { affectedRows = 1 }
        end
        if sql:find("UPDATE `sky_phone_call_entries`", 1, true) then
            local connected = sql:find("SET `status` = 'connected'", 1, true)
            local entry_id = sql:find("WHERE `id` = ?", 1, true) and params[2] or nil
            local call_id = entry_id and params[3] or params[connected and 1 or 2]
            for _, entry in ipairs(state.entries) do
                local eligible = entry.call_id == call_id and (not entry_id or entry.id == entry_id)
                if sql:find("`direction` = 'outgoing'", 1, true) then eligible = eligible and entry.direction == "outgoing" end
                if sql:find("`direction` = 'incoming'", 1, true) then eligible = eligible and entry.direction == "incoming" end
                if sql:find("AND `status` = 'ringing'", 1, true) then eligible = eligible and entry.status == "ringing" end
                if sql:find("IN ('ringing', 'connected')", 1, true) then
                    eligible = eligible and (entry.status == "ringing" or entry.status == "connected")
                end
                if eligible then entry.status = connected and "connected" or params[1] end
            end
            return { affectedRows = 1 }
        end
        if sql:find("FROM `sky_phone_call_entries` e", 1, true) then
            assert(sql:find("e.`other_number`", 1, true), "Recents must use the recipient's history")
            local rows = {}
            for _, entry in ipairs(state.entries) do
                if entry.account == params[1] then rows[#rows + 1] = entry end
            end
            return rows
        end
        if sql:find("FROM `sky_phone_sims`", 1, true) then
            for _, device in pairs(state.devices) do
                if device.phone_number == params[1] then
                    return { { id = device.sim_id, imei = device.imei, account_id = device.account_id,
                        device_name = device.device_name, phone_number = device.phone_number } }
                end
            end
            return {}
        end
        if sql:find("sky_phone_call_blocks", 1, true) then return state.blocked and { { blocked = 1 } } or {} end
        error("Unhandled SQL: " .. sql)
    end
    function env.Bridge.Database.Transaction(statements)
        hook("transaction", statements)
        if state.fail_transaction then return false end
        for _, statement in ipairs(statements) do env.Bridge.Database.Query(statement.query, statement.params) end
        return true
    end
    assert(loadfile("sky_phone/source/server/calls.lua", "t", env))()
    function state.action(action, source, id)
        return state.callbacks["sky_phone:calls:" .. action](source, { id = id })
    end
    function state.dial(source, number, payphone)
        local result = state.callbacks[payphone and "sky_phone:payphone:dial" or "sky_phone:calls:dial"](
            source or 1, { phoneNumber = number or "911" }
        )
        assert(result.success, result.error)
        return result.data
    end
    function state.active(source) return env.SkyPhoneCalls.IsActiveForSource(source) end
    function state.event_count(name, source, status)
        local count = 0
        for _, event in ipairs(state.events) do
            if event.name == name and (not source or event.source == source)
                and (not status or event.payload.state == status) then count = count + 1 end
        end
        return count
    end
    function state.tick()
        local thread = coroutine.create(state.threads[1])
        assert(coroutine.resume(thread))
        local ok, err = coroutine.resume(thread)
        assert(ok, err)
    end
    return state
end

local function test(name, callback)
    callback()
    print("PASS ring_all: " .. name)
end

test("cancelled device opening cannot trigger an incoming call overlay", function()
    for _, number in ipairs({ "911", "5550006" }) do
        local state = fixture()
        state.hooks.open = function() return false end
        state.dial(1, number)
        assert(state.event_count("sky_phone:call:incoming") == 0, number)
    end
    local state = fixture()
    state.hooks.open = function(source) return source ~= 2 end
    state.dial()
    assert(state.event_count("sky_phone:call:incoming", 2) == 0)
    assert(state.event_count("sky_phone:call:incoming", 3) == 1)
    assert(state.event_count("sky_phone:call:incoming", 4) == 1)
end)

test("all eligible phones ring; only the first answer connects and histories stay separate", function()
    local state = fixture()
    state.devices[3].account_id = 2 -- Two phones can share an account; identify each history row by its ID.
    local call = state.dial()
    assert(state.event_count("sky_phone:call:incoming") == 3)
    assert(state.rows[call.id].callee_sim_id == nil)
    for source = 1, 4 do assert(state.active(source)) end
    for source = 2, 4 do assert(state.env.SkyPhoneCalls.GetForSource(source).callee.source == source) end
    assert(type(state.env.SkyPhoneCalls.GetById(call.id).callee.source) == "number")
    assert(not state.action("answer", 6, call.id).success)
    assert(state.action("answer", 3, call.id).success)
    assert(#state.voice_starts == 1 and state.voice_starts[1].sources[2] == 3)
    assert(state.event_count("sky_phone:call:state", 2, "cancelled") == 1)
    assert(state.event_count("sky_phone:call:state", 4, "cancelled") == 1)
    assert(not state.active(2) and not state.active(4) and state.active(3))
    assert(not state.action("answer", 2, call.id).success)
    assert(not state.action("hangup", 4, call.id).success)
    local connected, cancelled = 0, 0
    for _, entry in ipairs(state.entries) do
        if entry.status == "connected" then connected = connected + 1 end
        if entry.status == "cancelled" then cancelled = cancelled + 1 end
    end
    assert(connected == 2 and cancelled == 2)
    assert(state.rows[call.id].callee_sim_id == "sim-3")
    assert(state.env.SkyPhoneCalls.GetForSource(3).callee.source == 3)
    assert(state.action("hangup", 1, call.id).success)
    assert(#state.voice_stops == 1)
    for source = 1, 4 do assert(not state.active(source)) end
end)

test("competing answers during yielding permission, inventory, voice and SQL calls", function()
    for _, phase in ipairs({ "permission", "inventory", "voice", "transaction" }) do
        local state = fixture()
        local call = state.dial()
        state.hooks[phase] = function()
            state.hooks[phase] = nil
            coroutine.yield()
        end
        local result
        local answer = coroutine.create(function() result = state.action("answer", 3, call.id) end)
        assert(coroutine.resume(answer))
        assert(coroutine.status(answer) == "suspended", phase)
        assert(not state.action("answer", 2, call.id).success, phase)
        assert(not state.action("answer", 3, call.id).success, phase)
        local ok, err = coroutine.resume(answer)
        assert(ok, err)
        assert(result.success and #state.voice_starts == 1, phase)
    end
end)

test("caller cancellation during answer never revives the call or leaves voice running", function()
    for _, phase in ipairs({ "permission", "inventory", "voice", "transaction" }) do
        local state = fixture()
        local call = state.dial()
        state.hooks[phase] = function() state.hooks[phase] = nil; coroutine.yield() end
        local result
        local answer = coroutine.create(function() result = state.action("answer", 2, call.id) end)
        assert(coroutine.resume(answer))
        assert(state.action("hangup", 1, call.id).success)
        local ok, err = coroutine.resume(answer)
        assert(ok, err)
        assert(not result.success, phase)
        assert(state.event_count("sky_phone:call:state", nil, "connected") == 0, phase)
        assert(#state.voice_starts == #state.voice_stops, phase)
        for source = 1, 4 do assert(not state.active(source), phase) end
    end
end)

test("declines, readiness loss, missing phones, SIM removal and disconnect affect one recipient", function()
    for _, reason in ipairs({ "decline", "hangup", "readiness", "phone", "sim", "drop", "tick" }) do
        local state = fixture()
        local call = state.dial()
        if reason == "decline" or reason == "hangup" then assert(state.action(reason, 2, call.id).success) end
        if reason == "readiness" then state.ready[2] = false; assert(not state.action("answer", 2, call.id).success) end
        if reason == "phone" then state.owned[2] = false; assert(not state.action("answer", 2, call.id).success) end
        if reason == "sim" then state.env.SkyPhoneCalls.EndForSim("sim-2") end
        if reason == "drop" then state.env.source = 2; state.handlers.playerDropped() end
        if reason == "tick" then state.owned[2] = false; state.tick() end
        assert(not state.active(2) and state.active(1) and state.active(3), reason)
        assert(state.action("answer", 3, call.id).success, reason)
    end
end)

test("timeouts and caller hangups release all recipients; MaxAttempts does not limit ring_all", function()
    for _, action in ipairs({ "timeout", "hangup", "decline_all", "stop" }) do
        local state = fixture()
        state.env.Config.Companies.CallRouting.MaxAttempts = 1
        local call = state.dial()
        assert(state.event_count("sky_phone:call:incoming") == 3)
        if action == "timeout" then
            assert(state.timers[1][1] == 10000)
            state.timers[1][2]()
            assert(state.rows[call.id].status == "no_answer")
        elseif action == "decline_all" then
            for source = 2, 4 do assert(state.action("decline", source, call.id).success) end
            assert(state.rows[call.id].status == "declined")
        elseif action == "stop" then state.handlers.onResourceStop("sky_phone")
        else assert(state.action("hangup", 1, call.id).success) end
        for source = 1, 4 do assert(not state.active(source), action) end
        assert(state.event_count("sky_phone:call:incoming") == 3)
        assert(state.dial().state == "ringing", "SIM locks must be released")
    end
end)

test("busy, unavailable and airplane-mode phones are skipped, with no duplicate call reservations", function()
    local state = fixture()
    state.dial(2, "5550006")
    state.flight["device-3"] = true
    local call = state.dial()
    assert(state.event_count("sky_phone:call:incoming", 2) == 0)
    assert(state.event_count("sky_phone:call:incoming", 3) == 0)
    assert(state.event_count("sky_phone:call:incoming", 4) == 1)
    local second = state.dial(5)
    assert(second.state == "busy")
    assert(state.action("answer", 4, call.id).success)
    state = fixture()
    for source = 2, 4 do state.ready[source] = false end
    assert(state.dial().state == "unavailable")
end)

test("failed voice startup releases the answer claim for another employee", function()
    local state = fixture()
    local call = state.dial()
    state.fail_voice = true
    assert(state.action("answer", 2, call.id).error == "voice_unavailable")
    state.fail_voice = false
    assert(state.action("answer", 3, call.id).success)
end)

test("SIM changes and airplane mode are revalidated before the first answer", function()
    for _, change in ipairs({ "sim", "registration", "type", "airplane" }) do
        local state = fixture()
        local call = state.dial()
        -- Readiness can still reference the original SIM while its inventory event is pending.
        state.env.SkyPhoneCompanies.CanAnswerCompanyCall = function() return true end
        if change == "sim" then state.devices[2].sim_id = "replacement-sim" end
        if change == "registration" then state.devices[2].registered_at = nil end
        if change == "type" then state.devices[2].sim_type = "burner" end
        if change == "airplane" then state.flight["device-2"] = true end
        assert(not state.action("answer", 2, call.id).success, change)
        assert(not state.active(2) and state.active(3), change)
        assert(state.action("answer", 3, call.id).success, change)
    end
end)

test("SQL failure after claiming a winner stops voice and frees every participant", function()
    local state = fixture()
    local call = state.dial()
    state.fail_transaction = true
    assert(not state.action("answer", 3, call.id).success)
    assert(#state.voice_starts == 1 and #state.voice_stops == 1)
    for source = 1, 4 do assert(not state.active(source)) end
end)

test("answering while another phone opens cannot restart ringing on a losing phone", function()
    local state = fixture()
    local first
    state.hooks.open = function(source)
        if not first then first = source; return end
        local call = assert(state.env.SkyPhoneCalls.GetForSource(first))
        assert(state.action("answer", first, call.id).success)
        state.hooks.open = nil
    end
    assert(state.dial().state == "connected", "late dial responses must preserve the answered state")
    assert(state.event_count("sky_phone:call:incoming") == 1)
    assert(#state.voice_starts == 1)
end)

test("caller cancellation while opening a phone is returned as cancelled, with no late incoming ring", function()
    local state = fixture()
    state.hooks.open = function(source)
        local call = assert(state.env.SkyPhoneCalls.GetForSource(source))
        assert(state.action("hangup", 1, call.id).success)
        state.hooks.open = nil
    end
    assert(state.dial().state == "cancelled")
    assert(state.event_count("sky_phone:call:incoming") == 0)
    for source = 1, 4 do assert(not state.active(source)) end
end)

test("payphones use the same ring-all winner and cleanup without phone history", function()
    local state = fixture()
    local call = state.dial(1, "911", true)
    assert(state.event_count("sky_phone:call:incoming") == 3)
    assert(state.action("answer", 4, call.id).success)
    assert(state.event_count("sky_phone:payphone:state", 1, "connected") == 1)
    assert(#state.entries == 0 and not state.active(2) and not state.active(3))
    state.env.SkyPhoneCalls.TerminateForSource(1)
    assert(not state.active(4) and #state.voice_stops == 1)
end)

test("round_robin still rings one employee and advances after rejection", function()
    local state = fixture("round_robin")
    local call = state.dial()
    assert(state.event_count("sky_phone:call:incoming") == 1)
    assert(state.action("decline", 2, call.id).success)
    assert(state.event_count("sky_phone:call:incoming", 3) == 1)
    assert(not state.active(2) and state.active(3))
    assert(state.action("answer", 3, call.id).success)
end)

test("automatic unregistered numbers can receive both routing modes when SIM cards are disabled", function()
    for _, routing in ipairs({ "ring_all", "round_robin" }) do
        local state = fixture(routing)
        state.env.Config.Sim.Enabled = false
        for _, device in pairs(state.devices) do
            device.sim_type, device.registered_at, device.sim_is_virtual = "anonymous", nil, 1
        end
        local call = state.dial()
        assert(state.event_count("sky_phone:call:incoming") == (routing == "ring_all" and 3 or 1))
        assert(state.action("answer", 2, call.id).success, routing)
        assert(state.action("hangup", 1, call.id).success)
        for source = 1, 4 do assert(not state.active(source), routing) end
    end
end)

-- Camera consent is chosen atomically while answering the initial invitation.
for _, video in ipairs({ true, false }) do
    local f = fixture()
    f.env.Config.Realtime = { Enabled = true, VideoCalls = true }
    local result = f.callbacks["sky_phone:calls:dial"](1, { phoneNumber = "911", video = true })
    assert(result.success)
    local answer = f.callbacks["sky_phone:calls:answer"](2, { id = result.data.id, video = video })
    assert(answer.success and answer.data.state == "connected")
    assert(answer.data.video == video, "Answer must respect the callee's explicit camera choice")
    assert(f.env.SkyPhoneCalls.GetForSource(1).video == video, "Caller must receive the chosen media mode")
end
local f = fixture()
f.env.Config.Realtime = { Enabled = true, VideoCalls = true }
local result = f.callbacks["sky_phone:calls:dial"](1, { phoneNumber = "911" })
assert(not f.callbacks["sky_phone:calls:answer"](2, { id = result.data.id, video = true }).success,
    "Audio invitations cannot enable cameras through an unsolicited video answer")
assert(not f.callbacks["sky_phone:calls:answer"](1, { id = result.data.id, video = false }).success,
    "Callers cannot accept their own invitation")
assert(not f.callbacks["sky_phone:calls:answer"](2, { id = result.data.id, video = "true" }).success,
    "Video consent must be a boolean")
assert(f.callbacks["sky_phone:calls:answer"](2, { id = result.data.id }).success,
    "Existing audio-only integrations can still answer without a video field")
print("Direct FaceTime answer tests passed")

for _, accepted_video in ipairs({ true, false }) do
    local f = fixture()
    f.env.Config.Realtime = { Enabled = true, VideoCalls = true }
    local response = f.callbacks["sky_phone:calls:dial"](1, { phoneNumber = "5550002", video = true })
    assert(response.success, response.error)
    assert(response.data.video, "Direct contact FaceTime must preserve the video flag")
    local incoming
    for _, event in ipairs(f.events) do
        if event.name == "sky_phone:call:incoming" and event.source == 2 then incoming = event.payload end
    end
    assert(incoming and incoming.video, "The actual incoming network event must carry the video invitation")
    assert(f.env.SkyPhoneCalls.GetForSource(2).video, "Direct recipient must see a video invitation")
    local answer = f.callbacks["sky_phone:calls:answer"](2, { id = response.data.id, video = accepted_video })
    assert(answer.success, answer.error)
    assert(answer.data.video == accepted_video)
    assert(f.env.SkyPhoneCalls.GetForSource(1).video == accepted_video)
end
print("PASS direct FaceTime: video invitation and explicit video/audio answers")

local company_fixture = fixture()
company_fixture.env.SkyPhoneCompanies.CanPlaceCompanyCall = function() return true end
local company_result = company_fixture.env.SkyPhoneCalls.StartCompanyCall(1, "police", "5550002")
assert(company_result.success and company_result.data.state == "ringing" and company_result.data.video == false,
    "Company calls without a UI request payload must remain valid audio calls")
print("PASS outbound company calls: no undefined video-request payload")

test("restrictions reject callers and direct callees, clear active calls and preserve other ring-all targets", function()
    local state = fixture()
    local blocked = { [2] = "player_cuffed" }
    state.env.Bridge.PlayerState = { GetBlockReason = function(src) return blocked[src] end }
    local denied = state.callbacks["sky_phone:calls:dial"](2, { phoneNumber = "5550001" })
    assert(not denied.success and denied.error == "player_cuffed")
    local unavailable = state.dial(1, "5550002")
    assert(unavailable.state == "unavailable" and state.event_count("sky_phone:call:incoming", 2) == 0)
    local call = state.dial()
    assert(not state.active(2) and state.active(3) and state.active(4))
    blocked[3] = "player_incapacitated"
    state.handlers["sky_phone:player:restricted"](3)
    assert(not state.active(3) and state.active(4) and state.active(1))
    assert(not state.action("answer", 3, call.id).success)
    assert(state.action("answer", 4, call.id).success)
    blocked[4] = "player_cuffed"
    state.tick()
    assert(not state.active(4) and not state.active(1) and #state.voice_stops == 1)
end)

test("becoming incapacitated while accepting cannot attach a late voice connection", function()
    for _, phase in ipairs({ "permission", "inventory", "voice", "transaction" }) do
        local state = fixture()
        local blocked = {}
        state.env.Bridge.PlayerState = { GetBlockReason = function(src) return blocked[src] end }
        local call = state.dial()
        state.hooks[phase] = function() state.hooks[phase] = nil; coroutine.yield() end
        local result
        local answer = coroutine.create(function() result = state.action("answer", 3, call.id) end)
        assert(coroutine.resume(answer))
        blocked[3] = "player_incapacitated"
        state.handlers["sky_phone:player:restricted"](3)
        local ok, err = coroutine.resume(answer); assert(ok, err)
        assert(not result.success, phase)
        if phase == "voice" or phase == "transaction" then assert(#state.voice_stops >= 1, phase) end
    end
end)
test("hidden caller IDs never reach direct recipients, snapshots or synced history", function()
    local state = fixture()
    state.hidden["device-1"] = true
    local call = state.dial(1, "5550006")
    local caller = state.env.SkyPhoneCalls.GetForSource(1)
    local recipient = state.env.SkyPhoneCalls.GetForSource(6)
    assert(caller.otherNumber == "5550006" and caller.caller.number == "5550001")
    assert(recipient.anonymous and recipient.otherNumber == "")
    assert(recipient.caller.number == "" and recipient.caller.source == nil)
    assert(state.rows[call.id].caller_number == "5550001", "Routing and server audit identity must remain intact")
    state.hidden["device-1"] = false -- An in-progress call keeps its original privacy.
    assert(state.action("answer", 6, call.id).success)
    assert(state.env.SkyPhoneCalls.GetForSource(6).otherNumber == "")
    assert(state.action("hangup", 1, call.id).success)
    for _, event in ipairs(state.events) do
        if event.source == 6 and (event.name == "sky_phone:call:incoming" or event.name == "sky_phone:call:state") then
            assert(event.payload.otherNumber == "" and event.payload.anonymous)
        end
    end
    local recents = state.callbacks["sky_phone:calls:recents"](6)
    assert(recents.success and #recents.data == 1 and recents.data[1].other_number == "")
    assert(state.entries[1].other_number == "5550006", "Outgoing history keeps the dialed number")
    state.dial(1, "5550006")
    assert(state.env.SkyPhoneCalls.GetForSource(6).otherNumber == "5550001", "Disabling privacy applies to the next call")
end)

test("caller ID privacy is read from the caller's stored boolean setting", function()
    for _, value in ipairs({ false, "true", 1 }) do
        local state = fixture()
        state.hidden["device-1"] = value
        state.hidden["device-6"] = true
        local result = state.callbacks["sky_phone:calls:dial"](1, {
            phoneNumber = "5550006", anonymous = true, hideCallerId = true,
        })
        assert(result.success)
        local recipient = state.env.SkyPhoneCalls.GetForSource(6)
        assert(not recipient.anonymous and recipient.otherNumber == "5550001")
    end
    local state = fixture()
    state.hidden["device-1"] = true
    assert(state.callbacks["sky_phone:calls:dial"](1, {
        phoneNumber = "5550006", anonymous = false, hideCallerId = false,
    }).success)
    assert(state.env.SkyPhoneCalls.GetForSource(6).anonymous)
end)

test("anonymous service calls stay hidden for every employee and after rerouting", function()
    for _, routing in ipairs({ "ring_all", "round_robin" }) do
        local state = fixture(routing)
        state.hidden["device-1"] = true
        local call = state.dial()
        state.hidden["device-1"] = false
        if routing == "round_robin" then
            assert(state.action("decline", 2, call.id).success)
        end
        local recipient = state.env.SkyPhoneCalls.GetForSource(3)
        assert(recipient.anonymous and recipient.caller.number == "" and recipient.caller.source == nil)
        assert(state.action("answer", 3, call.id).success)
        assert(state.action("hangup", 1, call.id).success)
        for _, event in ipairs(state.events) do
            if event.source ~= 1 and (event.name == "sky_phone:call:incoming" or event.name == "sky_phone:call:state") then
                assert(event.payload.anonymous and event.payload.otherNumber == "", routing)
            end
        end
        for _, entry in ipairs(state.entries) do
            if entry.direction == "incoming" then assert(entry.other_number == "", routing) end
        end
    end
end)

test("missed and declined anonymous calls never reveal the caller in history", function()
    for _, reason in ipairs({ "missed", "declined" }) do
        local state = fixture()
        state.hidden["device-1"] = true
        local call = state.dial(1, "5550006")
        if reason == "missed" then state.timers[1][2]()
        else assert(state.action("decline", 6, call.id).success) end
        local recents = state.callbacks["sky_phone:calls:recents"](6)
        assert(recents.data[1].status == reason and recents.data[1].other_number == "")
    end
end)

test("caller ID privacy does not bypass blocked SIMs or alter payphone identity", function()
    local state = fixture()
    state.hidden["device-1"] = true
    state.blocked = true
    local result = state.dial(1, "5550006")
    assert(result.state ~= "ringing" and state.event_count("sky_phone:call:incoming") == 0)
    state = fixture()
    state.hidden["device-1"] = true
    state.dial(1, "911", true)
    local recipient = state.env.SkyPhoneCalls.GetForSource(2)
    assert(not recipient.anonymous and recipient.otherNumber == "5559999")
end)
