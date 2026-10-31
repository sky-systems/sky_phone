-- Run real SkyRide callbacks through the real app-gated dispatcher. Fixture rows
-- represent a persisted fare already debited before the app was disabled.
local function fixture(enabled, status, refund_status)
    local state = { balance = 900, refunds = 0, queries = 0, fail_refund = false,
        row = { id = "550e8400-e29b-41d4-a716-446655440001", passenger_profile_id = "passenger-profile",
            passenger_identifier = "passenger-owner", passenger_profile_name = "Passenger", price = 100,
            status = status, refund_status = refund_status, currency = "$", service_class = "taxi" } }
    local environment = setmetatable({}, { __index = _G })
    local events, threads, responses = {}, {}, {}
    local function copy(row)
        local result = {}
        for key, value in pairs(row) do result[key] = value end
        return result
    end
    environment.Config = { Apps = { skyride = enabled }, SkyRide = {
        DistanceUnit = "kilometer", Services = {}, DriverJobs = {}, ActionsPerMinute = 30,
        HistoryLimit = 20, Currency = "$", PaymentAccount = "bank", RecoveryIntervalSeconds = 10,
        PaymentPendingRecoverySeconds = 30,
    } }
    environment.AddEventHandler = function() end
    environment.RegisterNetEvent = function(name, callback) events[name] = callback end
    environment.GetPlayerName = function(source) return source == 7 and "Passenger" or "Other" end
    environment.CreateThread = function(callback) threads[#threads + 1] = coroutine.create(callback) end
    environment.Wait = function(delay) return coroutine.yield(delay) end
    environment.SetTimeout = function() end
    environment.TriggerClientEvent = function() end
    environment.SkyPhoneCellular = { RequiresSignal = function() return false end }
    environment.SkyPhone = { AllowOperation = function() return true end,
        RequireSession = function() return { imei = "490154203237518" } end,
        LoadDevice = function() return {} end }
    environment.Bridge = {
        Debug = function() end,
        Callbacks = {},
        Network = { SendClient = function(_, _, request_id, response) responses[request_id] = response return true end },
        Framework = {
            GetPlayers = function() return { 7 } end,
            GetIdentifier = function(source) return source == 7 and "passenger-owner" or "other-owner" end,
            GetFirstname = function() return "Passenger" end, GetLastname = function() return "Test" end,
            GetJob = function() return { name = "civilian", grade = 0 } end,
            AddMoney = function(source, account, amount)
                assert(source == 7 and account == "bank" and amount == 100)
                state.refunds = state.refunds + 1
                if state.fail_refund then return false end
                state.balance = state.balance + amount
                return true
            end,
        },
        Database = {
            AfterMigration = function(_, callback) callback() end,
            Query = function(sql, params)
                state.queries = state.queries + 1
                local row = state.row
                if sql:find("INSERT IGNORE INTO `sky_phone_skyride_profiles`", 1, true) then return 1 end
                if sql:find("WHERE profile.`owner_identifier` = ?", 1, true) then
                    return { { id = params[1] == "passenger-owner" and "passenger-profile" or "other-profile",
                        owner_identifier = params[1], display_name = "Test Profile" } }
                end
                if sql:find("SET `status` = 'cancelled'", 1, true) then
                    if row and row.id == params[3] and row.refund_status == "none"
                        and (row.status == "searching" or row.status == "accepted" or row.status == "arrived" or row.status == "in_progress") then
                        row.status, row.refund_status = "cancelled", "pending"
                        return 1
                    end
                    return 0
                end
                for _, transition in ipairs({ { "processing", "pending" }, { "pending", "processing" }, { "completed", "processing" } }) do
                    if sql:find("SET `refund_status` = '" .. transition[1] .. "'", 1, true) then
                        if row and row.id == params[1] and row.refund_status == transition[2] then
                            row.refund_status = transition[1]
                            return 1
                        end
                        return 0
                    end
                end
                if sql:find("DELETE FROM `sky_phone_skyride_rides`", 1, true) then
                    assert(row and row.id == params[1] and row.status == "payment_pending" and row.refund_status == "completed")
                    state.row = nil
                    return 1
                end
                if sql:find("ORDER BY r.`updated_at` ASC", 1, true) then
                    return row and (row.status == "cancelled" or row.status == "payment_pending")
                        and (row.refund_status == "pending" or row.status == "payment_pending" and row.refund_status == "completed")
                        and { copy(row) } or {}
                end
                if sql:find("SELECT r.*", 1, true) then
                    if not row then return {} end
                    if sql:find("WHERE r.`id` = ?", 1, true) then return params[1] == row.id and { copy(row) } or {} end
                    if sql:find("IN ('completed','cancelled')", 1, true) then
                        return (row.status == "completed" or row.status == "cancelled") and { copy(row) } or {}
                    end
                    if sql:find("IN ('searching','accepted','arrived','in_progress','completing')", 1, true) then
                        return row.status == "searching" and { copy(row) } or {}
                    end
                    return {}
                end
                if sql:find("SELECT", 1, true) then return {} end
                error("Unexpected SkyRide lifecycle SQL: " .. sql)
            end,
        },
    }
    assert(loadfile("sky_phone/source/server/app_database.lua", "t", environment))()
    assert(loadfile("sky_phone/source/bridge/server/callbacks.lua", "t", environment))()
    assert(loadfile("sky_phone/source/server/skyride.lua", "t", environment))()
    local request_id = 0
    local function invoke(name, data, source)
        request_id = request_id + 1
        environment.source = source or 7
        events["sky_phone:bridge:callback:request"]("sky_phone:skyride:" .. name, request_id, data or {})
        return assert(responses[request_id], "SkyRide callback did not respond")
    end
    local function recovery_tick()
        assert(#threads == 2, "SkyRide recovery must start even on a cold start with the app disabled")
        local ok, delay = coroutine.resume(threads[2])
        assert(ok, delay)
        assert(delay == environment.Config.SkyRide.RecoveryIntervalSeconds * 1000)
    end
    return state, environment, invoke, recovery_tick
end

local state, environment, invoke, tick = fixture(true, "searching", "none")
environment.Config.Apps.skyride = false
local before = state.queries
assert(invoke("quote").error == "app_disabled" and invoke("request").error == "app_disabled")
assert(state.queries == before and state.balance == 900, "Disabled SkyRide must reject new rides before SQL or money changes")
local id = state.row.id
assert(invoke("cancel", { rideId = id }, 8).error == "not_ride_participant")
assert(state.balance == 900 and state.row.status == "searching", "Terminal exceptions must retain original ownership checks")
state.fail_refund = true
assert(invoke("cancel", { rideId = id, reason = "changed_mind" }).success)
assert(state.row.status == "cancelled" and state.row.refund_status == "pending" and state.balance == 900)
state.fail_refund = false
tick()
assert(state.balance == 1000 and state.row.refund_status == "completed", "Pending refunds must retry while the app remains disabled")
local refund_calls = state.refunds
tick()
assert(state.balance == 1000 and state.refunds == refund_calls, "Completed refunds must not be paid twice")

for _, status in ipairs({ "cancelled", "payment_pending" }) do
    local cold, _, cold_invoke, cold_tick = fixture(false, status, "pending")
    assert(cold_invoke("request").error == "app_disabled")
    cold_tick()
    assert(cold.balance == 1000 and cold.refunds == 1, "Cold-start disabled SkyRide must recover persisted fares")
    assert(status == "payment_pending" and cold.row == nil or cold.row and cold.row.refund_status == "completed")
    cold_tick()
    assert(cold.refunds == 1, "Cold-start recovery must not duplicate payment")
end
print("SkyRide disabled-app cancellation, ownership, refund retry and cold-start settlement tests passed")
