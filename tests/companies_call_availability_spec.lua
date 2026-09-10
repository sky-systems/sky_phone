local source_file = assert(io.open("sky_phone/source/server/companies.lua", "r"))
local source_code = source_file:read("*a"):gsub("\r\n", "\n")
source_file:close()

local function block(first, following)
    local start = assert(source_code:find(first, 1, true), first)
    local finish = assert(source_code:find(following, start + #first, true), following)
    return source_code:sub(start, finish - 1)
end

-- Execute the production membership, routing and periodic cleanup with a deterministic scheduler.
local code = block("local function membership(source)", "local function require_permission(")
    .. block("local function call_member(source)", "function SkyPhoneCompanies.CanAnswerCompanyCall(")
    .. block("function SkyPhoneCompanies.GetCallTargets(company_id)", "local function profile_row(")
    .. block("CreateThread(function()\n    while true do\n        Wait(1000)", "local function company_summary(")

local function fixture()
    local jobs, devices, slots = {}, {}, {}
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
        Bridge = { Framework = {} },
        SkyPhone = {},
    }, { __index = _G })
    function env.Bridge.Framework.GetPlayers() error("Call readiness must not enumerate all online players") end
    function env.Bridge.Framework.GetJob(player)
        job_reads = job_reads + 1
        return jobs[player] or { name = "", grade = 0 }
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
    local state = { env = env, jobs = jobs, devices = devices, slots = slots }
    function state.tick()
        local ok, err = coroutine.resume(thread)
        assert(ok, err)
    end
    function state.reads() return job_reads, device_reads end
    function state.ready(player, company)
        company = company or "mechanic"
        local imei, sim = "device-" .. player, "sim-" .. player
        jobs[player] = { name = company, grade = 2 }
        devices[imei] = { imei = imei, sim_id = sim, sim_type = "registered", registered_at = 1, phone_number = "555" .. player }
        slots[player] = { [imei] = { 1 } }
        env.call_availability[player] = { company_id = company, imei = imei, sim_id = sim }
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

print("companies_call_availability_spec: PASS (idle cost, membership cleanup, device/SIM authority and round robin)")
