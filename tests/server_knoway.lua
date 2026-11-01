-- Exercise the production ride/payment state machine, including yields at its
-- database boundary. All identifiers, entities and balances below are synthetic.
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local function fixture(options)
    options = options or {}
    local s = { now = 1000, rows = options.rows or {}, payloads = options.payloads or {},
        entities = options.entities or {}, global = options.global or {}, callbacks = {}, events = {}, threads = {},
        queries = {}, messages = {}, players = {}, next_entity = 100, next_uuid = 0,
        debits = 0, refunds = 0, deleted = {}, logs = {}, encoded = 0 }
    local e = setmetatable({}, { __index = _G })
    e.Config = { Apps = { knoway = options.enabled ~= false }, Knoway = {
        VehicleModel = "knoway_car", DriverModel = "driver", PaymentAccount = "bank", Currency = "$",
        BaseFare = 12, PricePerKilometer = 18, MinimumFare = 15, RouteDistanceMultiplier = 1.25,
        AverageSpeedMetersPerSecond = 12, QuoteLifetimeSeconds = 120, MaximumDistanceMeters = 40000,
        MinimumDistanceMeters = 250, MaxActiveRides = 10, RequestCooldownSeconds = 60,
        BoardingTimeoutSeconds = 120, ApproachTimeoutSeconds = 180, MaximumRideSeconds = 1800,
        MaxSpeedKmh = 80, DrivingStyle = 786603, ArrivalRadius = 20, SpawnMinimumDistance = 100,
        SpawnMaximumDistance = 150, RoadSnapDistance = 100, StuckTimeoutSeconds = 45, MaximumReplans = 2,
        RefundBeforeStart = true, RefundAfterStart = false, RefundTechnicalFailure = true,
    } }
    e.GlobalState = s.global
    e.os = setmetatable({ time = function() return s.now end }, { __index = os })
    e.json = {
        encode = function(value)
            s.encoded = s.encoded + 1
            local key = "fixture-payload-" .. s.encoded .. "-" .. tostring(s)
            s.payloads[key] = copy(value)
            return key
        end,
        decode = function(key) return copy(assert(s.payloads[key], "unknown fixture payload")) end,
    }
    function s.player(source, owner)
        s.players[source] = { owner = owner or "owner-" .. source, balance = 1000, bucket = 0 }
        s.entities[source] = { position = { x = 0, y = 0, z = 0 }, health = 200, vehicle = 0 }
    end
    s.player(7); s.player(8)
    e.joaat = function(value)
        if type(value) == "number" then return value end
        local hash = 0
        for index = 1, #value do hash = (hash * 31 + value:byte(index)) % 4294967296 end
        return hash
    end
    e.GetConvar = function() return options.no_onesync and "off" or "on" end
    e.GetCurrentResourceName = function() return "sky_phone" end
    e.GetPlayerName = function(source) return s.players[source] and "Fixture player" end
    e.GetPlayers = function()
        local result = {}
        for source in pairs(s.players) do result[#result + 1] = tostring(source) end
        return result
    end
    e.GetPlayerPed = function(source) return s.players[source] and source or 0 end
    e.GetPlayerRoutingBucket = function(source) return s.players[source] and s.players[source].bucket or 0 end
    e.GetEntityCoords = function(entity) return copy(assert(s.entities[entity], "unknown entity").position) end
    e.GetEntityHealth = function(entity) return s.entities[entity] and s.entities[entity].health or 0 end
    e.GetEntitySpeed = function(entity) return s.entities[entity] and (s.entities[entity].speed or 0) or 0 end
    e.GetVehiclePedIsIn = function(ped) return s.entities[ped] and s.entities[ped].vehicle or 0 end
    e.GetPedInVehicleSeat = function(vehicle) return s.entities[vehicle] and s.entities[vehicle].driver or 0 end
    e.GetEntityModel = function(entity) return s.entities[entity] and s.entities[entity].model or 0 end
    e.GetVehicleNumberPlateText = function(entity) return s.entities[entity].plate or "" end
    e.DoesEntityExist = function(entity) return s.entities[entity] ~= nil end
    e.GetAllVehicles = function()
        local result = {}
        for entity, value in pairs(s.entities) do if value.kind == "vehicle" then result[#result + 1] = entity end end
        return result
    end
    e.NetworkGetNetworkIdFromEntity = function(entity) return entity end
    e.NetworkGetEntityFromNetworkId = function(id) return s.entities[id] and id or 0 end
    e.SetEntityOrphanMode = function() end
    e.SetEntityRoutingBucket = function(entity, bucket) s.entities[entity].bucket = bucket end
    e.SetVehicleNumberPlateText = function(entity, plate) s.entities[entity].plate = plate end
    e.CreateVehicleServerSetter = function(model, kind, x, y, z, heading)
        assert(kind == "automobile" and type(x) == "number" and type(y) == "number" and type(z) == "number")
        if s.fail_spawn then return 0 end
        s.next_entity = s.next_entity + 1
        s.entities[s.next_entity] = { model = model, kind = "vehicle", health = 1000,
            position = { x = x, y = y, z = z }, heading = heading, states = {} }
        return s.next_entity
    end
    e.CreatePed = function(_, model, x, y, z)
        if s.fail_driver then return 0 end
        s.next_entity = s.next_entity + 1
        s.entities[s.next_entity] = { model = model, kind = "ped", health = 200,
            position = { x = x, y = y, z = z }, states = {} }
        return s.next_entity
    end
    e.Entity = function(entity)
        local states = s.entities[entity].states or {}
        s.entities[entity].states = states
        return { state = setmetatable({ set = function(_, name, value) states[name] = copy(value) end }, { __index = states }) }
    end
    e.DeleteEntity = function(entity) s.deleted[entity] = true; s.entities[entity] = nil end
    e.AddEventHandler = function(name, fn) s.events[name] = fn end
    e.RegisterNetEvent = e.AddEventHandler
    e.TriggerClientEvent = function(name, source, data) s.messages[#s.messages + 1] = { name = name, source = source, data = copy(data) } end
    e.CreateThread = function(fn) s.threads[#s.threads + 1] = coroutine.create(fn) end
    e.Wait = function(ms) coroutine.yield(ms) end
    e.SkyPhone = {
        AllowOperation = function() return not s.rate_limited end,
        RequireSession = function()
            if s.session_denied then return nil, { success = false, error = "phone_not_owned" } end
            return { imei = "fixture-device" }
        end,
    }
    local function query(sql, params)
        s.queries[#s.queries + 1] = { sql = sql, params = copy(params) }
        if s.query_hook then s.query_hook(sql, params) end
        if sql:find("SELECT UUID()", 1, true) then
            s.next_uuid = s.next_uuid + 1
            return { { id = ("550e8400-e29b-41d4-a716-%012d"):format(s.next_uuid) } }
        end
        if sql:find("SELECT `id`", 1, true) then
            for _, row in pairs(s.rows) do if row.active_owner == params[1] then return { { id = row.id } } end end
            return {}
        end
        if sql:find("SELECT *", 1, true) then
            local result = {}
            for _, row in pairs(s.rows) do
                if sql:find("'refund_pending'", 1, true) and row.payment_status == "refund_pending"
                    or not sql:find("'refund_pending'", 1, true) and row.payment_status == "charged"
                        and (row.status == "preparing" or row.status == "approaching" or row.status == "waiting" or row.status == "driving") then
                    result[#result + 1] = copy(row)
                end
            end
            return result
        end
        if sql:find("INSERT INTO", 1, true) then
            assert(not s.rows[params[1]], "duplicate ride journal")
            for _, row in pairs(s.rows) do assert(row.active_owner ~= params[3], "duplicate active owner") end
            s.rows[params[1]] = { id = params[1], owner_identifier = params[2], active_owner = params[3],
                status = "preparing", payment_status = "debit_processing", price = params[4],
                payment_account = params[5], currency = params[6], payload = params[7], created_epoch = params[8], updated_epoch = params[9] }
            return { affectedRows = 1 }
        end
        if sql:find("SET `status` = ?, `payload`", 1, true) then
            local row = s.rows[params[4]]
            if s.fail_save then s.fail_save = false; return 0 end
            assert(row)
            row.status, row.payload, row.updated_epoch = params[1], params[2], params[3]
            return 1
        end
        if sql:find("SET `status` = ?, `reason`", 1, true) then
            local row = s.rows[params[5]]
            if not row or row.payment_status ~= "charged"
                or not (row.status == "preparing" or row.status == "approaching" or row.status == "waiting" or row.status == "driving") then return 0 end
            row.status, row.reason, row.payment_status, row.active_owner = params[1], params[2], params[3], nil
            return 1
        end
        if sql:find("SET `status` = 'failed'", 1, true) then
            local row = s.rows[params[3]]
            if not row or row.payment_status ~= "charged" then return 0 end
            row.status, row.reason, row.payment_status, row.active_owner = "failed", "resource_restarted", params[1], nil
            return 1
        end
        if sql:find("SET `payment_status` = 'review'", 1, true) then
            if params[1] then s.rows[params[1]].payment_status = "review"; return 1 end
            for _, row in pairs(s.rows) do
                if row.payment_status == "debit_processing" or row.payment_status == "refund_processing" then row.payment_status = "review" end
            end
            return 1
        end
        if sql:find("SET `payment_status` = 'not_charged'", 1, true) then
            local row = s.rows[params[1]]
            if row.payment_status ~= "debit_processing" then return 0 end
            row.payment_status, row.status, row.active_owner = "not_charged", "cancelled", nil
            return 1
        end
        for _, change in ipairs({ { "charged", "debit_processing", 2 }, { "refund_processing", "refund_pending", 2 },
            { "refund_pending", "refund_processing", 1 } }) do
            if sql:find("SET `payment_status` = '" .. change[1] .. "'", 1, true) then
                local row = s.rows[params[change[3]]]
                if not row or row.payment_status ~= change[2] then return 0 end
                row.payment_status = change[1]
                return 1
            end
        end
        if sql:find("SET `payment_status` = ?", 1, true) then
            local row = s.rows[params[3]]
            if not row or row.payment_status ~= "refund_processing" then return 0 end
            row.payment_status = params[1]
            return 1
        end
        error("Unexpected KnoWay SQL: " .. sql)
    end
    e.Bridge = {
        Debug = function(_, message) s.logs[#s.logs + 1] = message end,
        Database = { Query = query, AfterMigration = function(_, fn) fn() end },
        Callbacks = {
            RegisterDeferred = function() end,
            Register = function(name, fn) s.callbacks[name] = fn end,
        },
        Framework = {
            GetPlayers = function() local result = {}; for source in pairs(s.players) do result[#result + 1] = source end; return result end,
            GetIdentifier = function(source) return s.players[source] and s.players[source].owner end,
            GetMoney = function(source, account) assert(account == "bank"); return s.players[source] and s.players[source].balance end,
            RemoveMoney = function(source, account, amount)
                assert(account == "bank")
                s.debits = s.debits + 1
                if s.debit_fail then return false end
                s.players[source].balance = s.players[source].balance - amount
                if s.debit_throws then error("ambiguous fixture debit") end
                return true
            end,
            AddMoney = function(source, account, amount)
                assert(account == "bank")
                s.refunds = s.refunds + 1
                if s.refund_fail then return false end
                s.players[source].balance = s.players[source].balance + amount
                if s.refund_throws then error("ambiguous fixture refund") end
                return true
            end,
        },
    }
    s.env = e
    function s.invoke(action, data, source)
        return s.callbacks["sky_phone:knoway:" .. action](source or 7, data or {})
    end
    function s.work(seconds)
        s.now = s.now + (seconds or 1)
        for _, co in ipairs(s.threads) do local ok, delay = coroutine.resume(co); assert(ok, delay) end
    end
    function s.quote(source, target_z)
        local result = s.invoke("quote", {
            pickupNode = { x = 0, y = 0, z = 0, heading = 0, label = "Pickup Street" },
            destinationNode = { x = 1000, y = 0, z = target_z or 0, heading = 90 },
            destination = { coords = { x = 1000, y = 0, z = 0 }, label = "Destination Street" },
            spawnNode = { x = 125, y = 0, z = 0, heading = 0 },
        }, source)
        assert(result.success, result.error)
        return result.data
    end
    function s.book(source)
        local quote = s.quote(source)
        local response = s.invoke("request", { quoteId = quote.id }, source)
        assert(response.success, response.error)
        return response.data.activeRide, quote
    end
    function s.move(entity, position) s.entities[entity].position = copy(position) end
    function s.waiting(ride)
        s.move(ride.vehicle.netId, ride.pickup.coords)
        s.work(1)
        assert(s.invoke("bootstrap").data.activeRide.status == "waiting")
    end
    function s.board(ride, source, driver)
        s.entities[source or 7].vehicle = ride.vehicle.netId
        s.entities[ride.vehicle.netId].driver = driver and (source or 7) or ride.vehicle.driverNetId
    end
    assert(loadfile("sky_phone/source/server/knoway.lua", "t", e))()
    for _, co in ipairs(s.threads) do local ok, delay = coroutine.resume(co); assert(ok, delay) end
    return s
end

local s = fixture()
local quote = s.quote()
assert(quote.price == 35 and quote.distanceMeters == 1250 and quote.durationSeconds == 105)
assert(quote.pickup.label == "Pickup Street" and quote.expiresAt == 1120)
assert(s.quote(7, 220).destination.coords.z == 220, "map z=0 must still resolve a road in the hills")
quote = s.quote()
s.env.Config.Knoway.BaseFare = 999
s.env.Config.Knoway.MaxSpeedKmh = 30
s.env.Config.Knoway.RefundBeforeStart = false
local booked = s.invoke("request", { quoteId = quote.id })
assert(booked.success and booked.data.activeRide.price == 35 and s.players[7].balance == 965)
local ride = booked.data.activeRide
assert(s.entities[ride.vehicle.netId].states.skyPhoneKnoway.speedKmh == 80, "accepted quotes keep their config snapshot")
assert(s.invoke("request", { quoteId = quote.id }).success and s.debits == 1, "duplicate request must return the existing ride")
assert(s.invoke("cancel", { rideId = ride.id }, 8).error == "not_ride_owner")
assert(s.invoke("start", { rideId = ride.id }, 8).error == "not_ride_owner")
assert(s.invoke("cancel", { rideId = ride.id }).success and s.players[7].balance == 1000)
assert(s.rows[ride.id].payment_status == "refunded" and s.refunds == 1, "the quoted before-start policy remains binding")
assert(s.invoke("cancel", { rideId = ride.id }).success and s.refunds == 1)
s.work(16); assert(s.refunds == 1 and s.deleted[ride.vehicle.netId])

local driving = fixture()
local d = driving.book()
driving.waiting(d)
assert(driving.invoke("start", { rideId = d.id }).error == "not_in_taxi")
driving.board(d, 7, true)
assert(driving.invoke("start", { rideId = d.id }).error == "not_in_taxi", "driver-seat users cannot start a passenger ride")
driving.board(d)
local boarding_expiry = driving.invoke("bootstrap").data.activeRide.expiresAt
driving.fail_save = true
assert(driving.invoke("start", { rideId = d.id }).error == "request_failed")
assert(driving.invoke("bootstrap").data.activeRide.expiresAt == boarding_expiry, "failed start preserves the boarding deadline")
assert(driving.invoke("start", { rideId = d.id }).data.activeRide.status == "driving")
assert(driving.invoke("start", { rideId = d.id }).success, "start is idempotent")
assert(driving.invoke("cancel", { rideId = d.id }).success)
assert(driving.refunds == 0 and driving.players[7].balance == 965, "own cancellation after starting retains the fare")
driving.work(1)
assert(not driving.deleted[d.vehicle.netId], "an occupied taxi must not disappear")
driving.entities[7].vehicle = 0; driving.work(1)
assert(driving.deleted[d.vehicle.netId])

local arrived = fixture()
local a = arrived.book(); arrived.waiting(a); arrived.board(a)
assert(arrived.invoke("start", { rideId = a.id }).success)
arrived.move(a.vehicle.netId, a.destination.coords); arrived.work(1)
assert(arrived.rows[a.id].status == "arrived" and arrived.rows[a.id].payment_status == "settled")
assert(arrived.refunds == 0 and not arrived.deleted[a.vehicle.netId])

local blocked = fixture()
local b = blocked.book()
blocked.work(45); blocked.work(45); blocked.work(45)
assert(blocked.rows[b.id].status == "failed" and blocked.rows[b.id].reason == "route_blocked")
assert(blocked.refunds == 1 and blocked.players[7].balance == 1000)
local dispatch = fixture(); dispatch.fail_spawn = true
local failed_ride = dispatch.book()
assert(failed_ride.status == "failed" and dispatch.debits == 1 and dispatch.refunds == 1)
local retry = fixture(); local retry_ride = retry.book()
retry.refund_fail = true
assert(retry.invoke("cancel", { rideId = retry_ride.id }).success)
assert(retry.rows[retry_ride.id].payment_status == "refund_pending" and retry.players[7].balance == 965)
retry.env.Config.Apps.knoway = false; retry.refund_fail = false; retry.work(16)
assert(retry.rows[retry_ride.id].payment_status == "refunded" and retry.players[7].balance == 1000)
local refund_attempts = retry.refunds; retry.work(16)
assert(retry.refunds == refund_attempts, "a failed refund can retry while disabled but a successful refund cannot repeat")

local disabled = fixture({ enabled = false })
assert(disabled.invoke("quote").error == "app_disabled" and disabled.invoke("request").error == "app_disabled")
local insufficient = fixture(); local iq = insufficient.quote(); insufficient.players[7].balance = 0
assert(insufficient.invoke("request", { quoteId = iq.id }).error == "insufficient_funds" and insufficient.debits == 0)
local expired = fixture(); local eq = expired.quote(); expired.now = eq.expiresAt
assert(expired.invoke("request", { quoteId = eq.id }).error == "quote_expired")

local reuse = fixture(); local rq = reuse.quote()
reuse.query_hook = function(sql)
    if sql:find("INSERT INTO", 1, true) then reuse.players[7].owner = "replacement-owner" end
end
assert(reuse.invoke("request", { quoteId = rq.id }).error == "not_authenticated")
assert(reuse.debits == 0 and reuse.players[7].balance == 1000, "source reuse must never debit a replacement character")
local refund_reuse = fixture(); local rr = refund_reuse.book()
refund_reuse.query_hook = function(sql)
    if sql:find("SET `payment_status` = 'refund_processing'", 1, true) then refund_reuse.players[7].owner = "replacement-owner" end
end
assert(refund_reuse.invoke("cancel", { rideId = rr.id }).success)
assert(refund_reuse.refunds == 0 and refund_reuse.rows[rr.id].payment_status == "refund_pending")
refund_reuse.query_hook = nil; refund_reuse.players[7].owner = "owner-7"; refund_reuse.work(16)
assert(refund_reuse.refunds == 1 and refund_reuse.rows[rr.id].payment_status == "refunded")

local pending = fixture(); pending.env.Config.Knoway.MaxActiveRides = 1
local first, second = pending.quote(7), pending.quote(8)
pending.query_hook = function(sql)
    if sql:find("SELECT `id`", 1, true) then pending.query_hook = nil; coroutine.yield("pending-database") end
end
local response
local order = coroutine.create(function() response = pending.invoke("request", { quoteId = first.id }, 7) end)
local ok, pause = coroutine.resume(order); assert(ok and pause == "pending-database")
assert(pending.invoke("request", { quoteId = second.id }, 8).error == "fleet_busy", "pending dispatches consume fleet capacity before database awaits")
ok, pause = coroutine.resume(order); assert(ok, pause); assert(response.success)
local p = response.data.activeRide
pending.board(p, 8)
assert(pending.invoke("cancel", { rideId = p.id }, 7).success)
pending.env.Config.Knoway.RequestCooldownSeconds = 0; pending.now = pending.now + 61
local later = pending.quote(7)
assert(pending.invoke("request", { quoteId = later.id }, 7).error == "fleet_busy", "retiring occupied taxis still consume fleet capacity")
pending.entities[8].vehicle = 0; pending.work(1)
assert(pending.invoke("request", { quoteId = later.id }, 7).success)

for _, ambiguous in ipairs({ "debit", "refund" }) do
    local ambiguous_state = fixture()
    local aq = ambiguous_state.quote()
    ambiguous_state.debit_throws = ambiguous == "debit"
    local ar = ambiguous_state.invoke("request", { quoteId = aq.id })
    if ambiguous == "refund" then
        ambiguous_state.refund_throws = true
        assert(ambiguous_state.invoke("cancel", { rideId = ar.data.activeRide.id }).success)
    else
        assert(ar.error == "payment_review")
    end
    assert(ambiguous_state.rows[aq.id].payment_status == "review")
    local before = ambiguous_state.refunds
    ambiguous_state.work(16); assert(ambiguous_state.refunds == before, "ambiguous framework operations must not replay")
end

local stopped = fixture(); local sr = stopped.book(); stopped.board(sr)
local before_stop = #stopped.queries
stopped.events.onResourceStop("sky_phone")
assert(#stopped.queries == before_stop and not stopped.deleted[sr.vehicle.netId], "resource stop only performs native safety work")
local cold = fixture({ enabled = false, rows = stopped.rows, payloads = stopped.payloads, entities = stopped.entities, global = stopped.global })
assert(cold.rows[sr.id].status == "failed" and cold.rows[sr.id].payment_status == "refund_pending")
cold.work(16)
assert(cold.rows[sr.id].payment_status == "refunded" and cold.refunds == 1, "disabled cold start settles an interrupted paid ride")
cold.work(16); assert(cold.refunds == 1)
local ambiguous_rows = { review = { id = "review", status = "preparing", payment_status = "debit_processing", active_owner = "owner-7" } }
local cold_review = fixture({ enabled = false, rows = ambiguous_rows })
assert(cold_review.rows.review.payment_status == "review" and cold_review.refunds == 0)
local cold_refund_review = fixture({ enabled = false, rows = {
    review = { id = "review", status = "cancelled", payment_status = "refund_processing" },
} })
cold_refund_review.work(16)
assert(cold_refund_review.rows.review.payment_status == "review" and cold_refund_review.refunds == 0)

local hostile = fixture({ entities = { [999] = { kind = "vehicle", health = 1000,
    position = { x = 0, y = 0, z = 0 }, states = { skyPhoneKnoway = true } } } })
hostile.work(1)
assert(hostile.entities[999] and not hostile.deleted[999], "client-writable tags alone never authorize orphan cleanup")
local stale = fixture(); local stale_ride = stale.book()
assert(stale.invoke("cancel", { rideId = stale_ride.id }).success)
stale.entities[stale_ride.vehicle.netId] = { kind = "vehicle", model = 1234, plate = "UNRELATED",
    health = 1000, position = { x = 0, y = 0, z = 0 }, states = {} }
stale.work(1)
assert(not stale.deleted[stale_ride.vehicle.netId], "a reused native handle must not delete somebody else's car")

print("KnoWay server fare, ownership, state, concurrency and payment recovery tests passed")
