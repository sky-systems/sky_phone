-- Execute the production request and call-availability callbacks with database/framework fixtures.
local file = assert(io.open("sky_phone/source/server/companies.lua", "r"))
local source = file:read("*a"):gsub("\r\n", "\n")
file:close()
local function block(first, following)
    local start = assert(source:find(first, 1, true))
    return source:sub(start, assert(source:find(following, start + #first, true)) - 1)
end
local code = block("local function uuid()", "local function iso_time(")
    .. block("function SkyPhoneCompanies.CanUseServiceDevice(device)", "local function membership(")
    .. block("local function request_access(", "local function can_handle_request(")
    .. block('Bridge.Callbacks.Register("sky_phone:companies:create-request"', 'Bridge.Callbacks.Register("sky_phone:companies:cancel-request"')
    .. block('Bridge.Callbacks.Register("sky_phone:companies:set-call-availability"', 'AddEventHandler("playerDropped"')
    .. "\nreturn { request_access = request_access, current_device = current_device }"

local function fixture(sim_enabled, registered)
    local device = {
        imei = "device-1", sim_id = "automatic-number-1", phone_number = "5550001",
        sim_type = registered and "registered" or "anonymous",
        registered_at = registered and 1 or nil, sim_is_virtual = sim_enabled and 0 or 1,
    }
    local callbacks, requests = {}, {}
    local next_id = 0
    local noop = function() end
    local member = { company_id = "police", grade = 0, definition = { ServiceLine = { CanCall = true } } }
    local env = setmetatable({
        Config = {
            Sim = { Enabled = sim_enabled },
            Companies = { SubjectMaxLength = 120, RequestBodyMaxLength = 2000, MaximumRequestMedia = 3, MaximumOpenRequestsPerSim = 5 },
        },
        SkyPhoneCompanies = {},
        SkyPhone = {
            RequireSession = function() return { imei = device.imei } end,
            LoadDevice = function() return device end,
        },
        definitions = { police = { Public = true } },
        call_availability = {},
        allow_mutation = function() return true end,
        call_member = function() return member end,
        membership = function() return nil end,
        request_row = function(id) return requests[id] end,
        emit_request_change = noop,
        notify_company = noop,
        notification_payload = noop,
        Bridge = { Database = {}, Framework = {}, Callbacks = { Register = function(name, callback) callbacks[name] = callback end } },
    }, { __index = _G })
    function env.work_context() return { callAvailable = env.call_availability[1] ~= nil } end
    function env.SkyPhoneCompanies.ClearCallAvailability(player) env.call_availability[player] = nil end
    function env.Bridge.Database.Query(sql)
        if sql:find("SELECT UUID()", 1, true) then next_id = next_id + 1; return { { id = "request-" .. next_id } } end
        if sql:find("`accepts_requests`", 1, true) then return { { accepts_requests = 1 } } end
        if sql:find("sky_phone_company_services", 1, true) then return { { id = "support" } } end
        if sql:find("COUNT(*)", 1, true) then return { { count = 0 } } end
        error("Unexpected query: " .. sql)
    end
    function env.Bridge.Database.Transaction(statements)
        local params = statements[2].params
        requests[params[1]] = { id = params[1], company_id = params[4], customer_sim_id = params[6] }
        return true
    end
    local runtime = assert(load(code, "@companies_service_device_callbacks", "t", env))()
    function env.mutation_request_payload(player, id)
        local access, err = runtime.request_access(player, id)
        if not access then return nil, err end
        return { request = { id = access.row.id, audience = access.audience } }
    end
    return {
        env = env, device = device, runtime = runtime, requests = requests,
        create = function()
            return callbacks["sky_phone:companies:create-request"](1, {
                companyId = "police", serviceId = "support", subject = "Help needed",
                description = "Please send an officer to assist.", mediaIds = {},
            })
        end,
        available = function(value)
            return callbacks["sky_phone:companies:set-call-availability"](1, { available = value })
        end,
    }
end

for _, sim_enabled in ipairs({ false, true }) do
    for _, registered in ipairs({ false, true }) do
        local state = fixture(sim_enabled, registered)
        local allowed = not sim_enabled or registered
        local request = state.create()
        local availability = state.available(true)
        assert(request.success == allowed and availability.success == allowed)
        if allowed then
            assert(request.data.request.audience == "customer")
            local id = request.data.request.id
            local access = assert(state.runtime.request_access(1, id))
            assert(access.audience == "customer" and access.row.customer_sim_id == state.device.sim_id)
            assert(availability.data.context.callAvailable)
            assert(state.env.call_availability[1].sim_id == state.device.sim_id)
            state.device.sim_id = "another-number"
            local other_access = state.runtime.request_access(1, id)
            assert(other_access == nil, "Disabling SIM cards must never grant access to another number's requests")
        else
            assert(request.error == "anonymous_sim" and availability.error == "anonymous_sim")
            assert(next(state.requests) == nil and next(state.env.call_availability) == nil)
        end
        assert(state.available(false).success)
    end
end

local state = fixture(false, false)
state.device.sim_id = nil
assert(state.create().error == "no_sim" and state.available(true).error == "no_sim",
    "A valid automatic number is still required for identity and routing")
print("companies_service_device_spec: PASS (requests, customer isolation and call availability in both SIM modes)")
