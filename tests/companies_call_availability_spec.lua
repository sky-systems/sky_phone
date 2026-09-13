local source_file = assert(io.open("sky_phone/source/server/companies.lua", "r"))
local source_code = source_file:read("*a"):gsub("\r\n", "\n")
source_file:close()

local function block(first, following, content)
    content = content or source_code
    local start = assert(content:find(first, 1, true), first)
    local finish = assert(content:find(following, start + #first, true), following)
    return content:sub(start, finish - 1)
end

-- Execute the production membership, routing and periodic cleanup with a deterministic scheduler.
local code = block("function SkyPhoneCompanies.ClearCallAvailability(source)", "local function require_permission(")
    .. block("local function call_member(source)", "local function profile_row(")
    .. block("CreateThread(function()\n    while true do\n        Wait(1000)", "local function company_summary(")
    .. block("local function work_context(source)", "local function notify_sim(")
    .. block('Bridge.Callbacks.Register("sky_phone:companies:set-call-availability"', 'AddEventHandler("playerDropped"')

local function fixture()
    local jobs, devices, slots, sessions, callbacks = {}, {}, {}, {}, {}
    local job_reads, device_reads = 0, 0
    local thread
    local env = setmetatable({
        Config = { Companies = { Enabled = true } },
        SkyPhoneCompanies = {},
        definitions = {
            mechanic = { ServiceLine = { CanCall = true, MinimumGrade = 1 } },
            taxi = { ServiceLine = { CanCall = true, MinimumGrade = 0 } },
        },
        definitions_by_job = { mechanic = "mechanic", taxi = "taxi" },
        call_availability = {},
        round_robin_positions = {},
        Bridge = {
            Framework = {},
            Database = { Query = function() return {} end },
            Callbacks = { Register = function(name, callback) callbacks[name] = callback end },
        },
        SkyPhone = {},
        permission_grade = function() return 0 end,
        company_payload = function(company_id) return { id = company_id } end,
        context_request_rows = function() return {} end,
        allow_mutation = function() return true end,
    }, { __index = _G })
    function env.Bridge.Framework.GetPlayers() error("Call readiness must not enumerate all online players") end
    function env.Bridge.Framework.GetJob(player)
        job_reads = job_reads + 1
        return jobs[player] or { name = "", grade = 0 }
    end
    function env.Bridge.Framework.GetIdentifier(player) return "employee-" .. player end
    function env.SkyPhone.RequireSession(player)
        return sessions[player], { success = false, error = "no_session" }
    end
    function env.SkyPhone.LoadDevice(imei)
        device_reads = device_reads + 1
        return devices[imei]
    end
    function env.SkyPhone.FindDeviceSlots(player, imei)
        return slots[player] and slots[player][imei] or {}
    end
    function env.Wait(milliseconds)
        assert(milliseconds == 1000)
        coroutine.yield()
    end
    function env.CreateThread(callback)
        thread = coroutine.create(callback)
        assert(coroutine.resume(thread))
    end
    assert(load(code, "@companies_call_availability", "t", env))()
    local state = { env = env, jobs = jobs, devices = devices, slots = slots, sessions = sessions }
    state.set_availability = callbacks["sky_phone:companies:set-call-availability"]
    function state.tick()
        local ok, err = coroutine.resume(thread)
        assert(ok, err)
    end
    function state.reads() return job_reads, device_reads end
    function state.ready(player, company, dispatcher)
        company = company or "mechanic"
        local imei, sim = "device-" .. player, "sim-" .. player
        jobs[player] = { name = company, grade = 2 }
        devices[imei] = { imei = imei, sim_id = sim, sim_type = "registered", registered_at = 1, phone_number = "555" .. player }
        slots[player] = { [imei] = { 1 } }
        sessions[player] = { imei = imei }
        env.call_availability[player] = { company_id = company, imei = imei, sim_id = sim, dispatcher = dispatcher }
    end
    return state
end

local state = fixture()
for player = 1, 1000 do state.jobs[player] = { name = "mechanic", grade = 2 } end
for _ = 1, 10 do state.tick() end
assert(state.reads() == 0, "Empty readiness must perform zero framework reads")
assert(#state.env.SkyPhoneCompanies.GetCallTargets("mechanic") == 0 and state.reads() == 0)
state.ready(17)
state.tick()
assert(state.reads() == 1 and state.env.call_availability[17], "Cleanup must visit only ready employees")

for _, change in ipairs({ "offline", "job", "grade", "disabled", "removed" }) do
    state = fixture()
    state.ready(1)
    if change == "offline" then state.jobs[1] = nil end
    if change == "job" then state.jobs[1].name = "taxi" end
    if change == "grade" then state.jobs[1].grade = 0 end
    if change == "disabled" then state.env.definitions.mechanic.ServiceLine.CanCall = false end
    if change == "removed" then state.env.definitions_by_job.mechanic = nil end
    state.tick()
    assert(state.env.call_availability[1] == nil, "Stale readiness must be removed after " .. change)
    state.tick()
    assert(state.reads() == 1, "Removed readiness must stop generating framework work")
end

for _, change in ipairs({ "offline", "job", "grade", "device", "slot", "sim", "type", "registration" }) do
    state = fixture()
    state.ready(1)
    local device = state.devices["device-1"]
    if change == "offline" then state.jobs[1] = nil end
    if change == "job" then state.jobs[1].name = "taxi" end
    if change == "grade" then state.jobs[1].grade = 0 end
    if change == "device" then state.devices["device-1"] = nil end
    if change == "slot" then state.slots[1] = nil end
    if change == "sim" then device.sim_id = "replacement" end
    if change == "type" then device.sim_type = "burner" end
    if change == "registration" then device.registered_at = nil end
    assert(#state.env.SkyPhoneCompanies.GetCallTargets("mechanic") == 0, "Invalid target after " .. change)
    assert(state.env.call_availability[1] == nil)
end

state = fixture()
state.ready(2)
state.ready(1)
state.ready(3, "taxi")
local targets = state.env.SkyPhoneCompanies.GetCallTargets("mechanic")
assert(#targets == 2 and targets[1].source == 1 and targets[2].source == 2)
assert(targets[1].imei == "device-1" and targets[1].simId == "sim-1")
targets = state.env.SkyPhoneCompanies.GetCallTargets("mechanic")
assert(#targets == 2 and targets[1].source == 2 and targets[2].source == 1)
assert(state.env.call_availability[3], "Routing another company must preserve its readiness")
state.env.Config.Companies.Enabled = false
local before = state.reads()
assert(#state.env.SkyPhoneCompanies.GetCallTargets("mechanic") == 0 and state.reads() == before)

state = fixture()
state.ready(1)
state.ready(2)
state.ready(8, "mechanic", true)
state.ready(9, "mechanic", true)
state.ready(10, "taxi", true)
for iteration = 1, 4 do
    targets = state.env.SkyPhoneCompanies.GetCallTargets("mechanic")
    local expected = iteration % 2 == 1 and { 8, 9, 1, 2 } or { 9, 8, 2, 1 }
    assert(#targets == #expected)
    for index, player in ipairs(expected) do
        assert(targets[index].source == player, "Dispatchers must rotate before regular employees")
    end
end
assert(state.env.SkyPhoneCompanies.GetCallTargets("taxi")[1].source == 10,
    "Dispatch priority must stay inside the employee's company")

for _, change in ipairs({ "job", "grade", "sim", "slot" }) do
    state = fixture()
    state.ready(1)
    state.ready(8, "mechanic", true)
    if change == "job" then state.jobs[8].name = "taxi" end
    if change == "grade" then state.jobs[8].grade = 0 end
    if change == "sim" then state.devices["device-8"].sim_id = "replacement" end
    if change == "slot" then state.slots[8] = nil end
    targets = state.env.SkyPhoneCompanies.GetCallTargets("mechanic")
    assert(#targets == 1 and targets[1].source == 1, "Invalid dispatcher must be skipped after " .. change)
    assert(state.env.call_availability[8] == nil)
end

state = fixture()
state.ready(8)
state.env.SkyPhoneCompanies.ClearCallAvailability(8)
local response = state.set_availability(8, {
    available = true, dispatcher = true, companyId = "taxi", source = 10, imei = "forged", simId = "forged",
})
assert(response.success and response.data.context.callAvailable and response.data.context.callDispatcher,
    "Taking dispatch duty must enable calls and return the authoritative role")
local readiness = state.env.call_availability[8]
assert(readiness.company_id == "mechanic" and readiness.imei == "device-8" and readiness.sim_id == "sim-8",
    "The server must derive company, source, phone and SIM instead of trusting supplied identity")
assert(state.env.call_availability[10] == nil)
assert(state.env.SkyPhoneCompanies.CanAnswerCompanyCall(8, "mechanic", "device-8", "sim-8"))
assert(not state.env.SkyPhoneCompanies.CanAnswerCompanyCall(8, "taxi", "device-8", "sim-8"))

response = state.set_availability(8, { available = true, dispatcher = false })
assert(response.success and response.data.context.callAvailable and not response.data.context.callDispatcher,
    "Leaving dispatch duty must preserve ordinary call readiness")
assert(state.set_availability(8, { available = true, dispatcher = true }).success)
response = state.set_availability(8, { available = false })
assert(response.success and not response.data.context.callAvailable and not response.data.context.callDispatcher)
assert(state.env.call_availability[8] == nil, "Disabling calls must also remove dispatch duty")
response = state.set_availability(8, { available = true })
assert(response.success and not response.data.context.callDispatcher, "Existing clients must remain ordinary recipients")

for _, invalid in ipairs({
    false, {}, { available = "true", dispatcher = true }, { available = true, dispatcher = "true" },
    { available = false, dispatcher = true },
}) do
    response = state.set_availability(8, invalid)
    assert(not response.success and response.error == "invalid_request")
    assert(not state.env.call_availability[8].dispatcher, "Malformed requests must not acquire dispatch priority")
end

for _, change in ipairs({ "job", "grade", "disabled", "session", "sim", "type", "registration" }) do
    state = fixture()
    state.ready(8)
    state.env.SkyPhoneCompanies.ClearCallAvailability(8)
    if change == "job" then state.jobs[8].name = "unemployed" end
    if change == "grade" then state.jobs[8].grade = 0 end
    if change == "disabled" then state.env.definitions.mechanic.ServiceLine.CanCall = false end
    if change == "session" then state.sessions[8] = nil end
    if change == "sim" then state.devices["device-8"].sim_id = nil end
    if change == "type" then state.devices["device-8"].sim_type = "burner" end
    if change == "registration" then state.devices["device-8"].registered_at = nil end
    response = state.set_availability(8, { available = true, dispatcher = true })
    assert(not response.success and state.env.call_availability[8] == nil,
        "Dispatch enrollment must reject invalid " .. change)
end
state = fixture()
state.ready(8)
state.env.SkyPhoneCompanies.ClearCallAvailability(8)
state.env.allow_mutation = function() return false, { success = false, error = "rate_limited" } end
assert(state.set_availability(8, { available = true, dispatcher = true }).error == "rate_limited")
assert(state.env.call_availability[8] == nil)

-- Exercise the actual call selector and rerouting with prioritized company targets.
local calls_file = assert(io.open("sky_phone/source/server/calls.lua", "r"))
local calls_source = calls_file:read("*a"):gsub("\r\n", "\n")
calls_file:close()
state = fixture()
state.ready(1)
state.ready(2)
state.ready(8, "mechanic", true)
state.ready(9, "mechanic", true)
local env = state.env
local airplane, rings, saved_statuses = {}, {}, {}
env.calls, env.active_by_source, env.active_by_sim, env.dialing_by_sim = {}, {}, {}, {}
env.SkyPhoneCompanies.IsServiceNumber = function() return false end
env.find_device_holder = function(imei)
    for player, owned in pairs(state.slots) do
        if owned[imei] and owned[imei][1] then return player end
    end
end
env.airplane_mode = function(imei) return airplane[imei] end
env.scope_for_device = function(device) return nil, device.imei end
env.Bridge.Database.Transaction = function(statements)
    saved_statuses[#saved_statuses + 1] = statements[2].params[1]
    return true
end
env.send_state = function() end
env.notify_recents = function() end
env.ring_callee = function(call) rings[#rings + 1] = call.callee_source end
env.schedule_no_answer = function() end
local routing = assert(load(
    "local reroute_company_call\n"
        .. block("local function company_call_target(", "local function ring_callee(", calls_source)
        .. block("reroute_company_call = function(", "handle_no_answer = function(", calls_source)
        .. "return { target = company_call_target, reroute = reroute_company_call }",
    "@company_dispatch_call_routing", "t", env
))()

env.active_by_source[8] = "busy-call"
local target = assert(routing.target("mechanic", 99, "caller-sim"))
assert(target.source == 9, "Busy dispatchers must be skipped without bypassing another dispatcher")
env.dialing_by_sim[target.sim_id] = nil
airplane["device-9"] = true
target = assert(routing.target("mechanic", 99, "caller-sim"))
assert(target.source == 1 or target.source == 2, "Unreachable dispatchers must fall through to ordinary employees")
env.dialing_by_sim[target.sim_id] = nil
env.active_by_source[8] = nil
airplane["device-9"] = nil

target = assert(routing.target("mechanic", 99, "caller-sim"))
local call = {
    id = "dispatch-call", company_id = "mechanic", company_service_call = true,
    caller_source = 99, caller_sim_id = "caller-sim", caller_number = "5550099",
    callee_source = target.source, callee_sim_id = target.sim_id, callee_device = target.device,
    company_attempted_sims = { [target.sim_id] = true }, company_attempts_remaining = 2,
}
env.dialing_by_sim[target.sim_id] = nil
env.calls[call.id] = call
env.active_by_source[target.source] = call.id
env.active_by_sim[target.sim_id] = call.id
assert(routing.reroute(call, "declined"))
assert(call.callee_source >= 8 and call.callee_source ~= target.source,
    "A declined dispatcher call must try the other dispatcher first")
assert(env.active_by_source[target.source] == nil and env.active_by_sim[target.sim_id] == nil,
    "Rerouting must release the previous dispatcher")
assert(routing.reroute(call, "missed"))
assert(call.callee_source == 1 or call.callee_source == 2,
    "Once dispatchers were attempted, an unanswered call must reach an ordinary employee")
assert(saved_statuses[1] == "declined" and saved_statuses[2] == "missed")
assert(call.company_attempts_remaining == 0 and #rings == 2)
assert(not routing.reroute(call, "missed") and #rings == 2,
    "Dispatch priority must preserve the configured total attempt limit")

print("companies_call_availability_spec: PASS (authority, priority, rotation, cleanup, busy/unreachable fallback and rerouting)")
