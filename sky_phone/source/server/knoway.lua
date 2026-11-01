-- Accepted fares remain resource-owned even when KnoWay is hidden in the panel.
for _, action in ipairs({ "bootstrap", "quote", "request", "start", "cancel" }) do
    Bridge.Callbacks.RegisterDeferred("sky_phone:knoway:" .. action)
end
Bridge.Database.AfterMigration("sky_phone", function()
local rides, by_owner, quotes, cooldowns, locks, retiring = {}, {}, {}, {}, {}, {}
local terminal = { arrived = true, cancelled = true, failed = true }
-- GlobalState is written only by the server and survives a resource restart.
-- Client-owned Entity state bags are presentation data, never cleanup authority.
local registry = type(GlobalState.skyPhoneKnowayEntities) == "table" and GlobalState.skyPhoneKnowayEntities or {}

local function publish_registry()
    GlobalState.skyPhoneKnowayEntities = registry
end

local function fail(code)
    return { success = false, error = code }
end

local function affected(result)
    return type(result) == "table" and result.affectedRows or tonumber(result) or 0
end

local function point(value)
    if type(value) ~= "table" then return nil end
    local result = {}
    for _, key in ipairs({ "x", "y", "z" }) do
        local number = value[key]
        if type(number) ~= "number" or number ~= number or math.abs(number) > 20000 then return nil end
        result[key] = number
    end
    if result.z < -200 or result.z > 2000 then return nil end
    result.heading = type(value.heading) == "number" and value.heading == value.heading
        and math.abs(value.heading) < 10000 and value.heading % 360 or 0
    return result
end

local function distance(a, b)
    return math.sqrt((a.x - b.x)^2 + (a.y - b.y)^2 + (a.z - b.z)^2)
end

local function coords(entity)
    local value = GetEntityCoords(entity)
    return { x = value.x, y = value.y, z = value.z }
end

local function snapshot()
    local result = {}
    for key, value in pairs(Config.Knoway) do result[key] = value end
    return result
end

local function public_ride(ride)
    local value = {
        id = ride.id, status = ride.status, pickup = ride.pickup, destination = ride.destination,
        price = ride.price, currency = ride.currency, distanceMeters = ride.distanceMeters,
        durationSeconds = ride.durationSeconds, vehicle = ride.vehicle, createdAt = ride.createdAt,
        expiresAt = ride.expiresAt, reason = ride.reason, refundStatus = ride.payment,
        refundPolicy = { beforeStart = ride.config.RefundBeforeStart,
            afterStart = ride.config.RefundAfterStart, technical = ride.config.RefundTechnicalFailure },
    }
    if ride.entity and DoesEntityExist(ride.entity) then value.position = coords(ride.entity) end
    return value
end

local function state(source, ride)
    return { success = true, data = {
        activeRide = ride and public_ride(ride) or false,
        available = Config.Apps.knoway == true and Config.Knoway.VehicleModel ~= ""
            and GetConvar("onesync", "off") ~= "off",
        currency = ride and ride.currency or Config.Knoway.Currency,
        refundPolicy = { beforeStart = Config.Knoway.RefundBeforeStart,
            afterStart = Config.Knoway.RefundAfterStart, technical = Config.Knoway.RefundTechnicalFailure },
    } }
end

local function push(ride)
    if GetPlayerName(ride.source) and Bridge.Framework.GetIdentifier(ride.source) == ride.owner then
        TriggerClientEvent("sky_phone:knoway:changed", ride.source, state(ride.source, ride).data)
    end
end

local function persisted(ride)
    return json.encode({ ride = public_ride(ride), config = ride.config })
end

local function save(ride)
    local changed = Bridge.Database.Query([[
        UPDATE `sky_phone_knoway_rides` SET `status` = ?, `payload` = ?, `updated_epoch` = ?
        WHERE `id` = ?
    ]], { ride.status, persisted(ride), os.time(), ride.id })
    return affected(changed) == 1
end

local function locked(key, action)
    if locks[key] then return fail("ride_busy") end
    locks[key] = true
    local ok, result = pcall(action)
    locks[key] = nil
    if not ok then
        Bridge.Debug("error", "[sky_phone] KnoWay operation failed: %s", tostring(result))
        return fail("request_failed")
    end
    return result
end

local function refund(row, player)
    if row.payment_status ~= "refund_pending" then return end
    if not player or Bridge.Framework.GetIdentifier(player) ~= row.owner_identifier then return end
    local claim = Bridge.Database.Query([[
        UPDATE `sky_phone_knoway_rides` SET `payment_status` = 'refund_processing', `updated_epoch` = ?
        WHERE `id` = ? AND `payment_status` = 'refund_pending'
    ]], { os.time(), row.id })
    if affected(claim) ~= 1 then return end
    if Bridge.Framework.GetIdentifier(player) ~= row.owner_identifier then
        Bridge.Database.Query([[
            UPDATE `sky_phone_knoway_rides` SET `payment_status` = 'refund_pending'
            WHERE `id` = ? AND `payment_status` = 'refund_processing'
        ]], { row.id })
        return
    end
    local ok, paid = pcall(Bridge.Framework.AddMoney, player, row.payment_account, tonumber(row.price))
    -- A thrown call can have changed framework money already. Never retry it.
    local next_status = not ok and "review" or paid and "refunded" or "refund_pending"
    local result = Bridge.Database.Query([[
        UPDATE `sky_phone_knoway_rides` SET `payment_status` = ?, `updated_epoch` = ?
        WHERE `id` = ? AND `payment_status` = 'refund_processing'
    ]], { next_status, os.time(), row.id })
    if affected(result) ~= 1 or not ok then
        Bridge.Debug("error", "[sky_phone] KnoWay refund '%s' requires reconciliation; it will not be replayed.", row.id)
    end
    if ok and paid then TriggerClientEvent("sky_phone:banking:changed", player) end
    local ride = rides[row.id]
    if ride then ride.payment = next_status; push(ride) end
end

local function control_state(ride)
    if not ride.entity or not DoesEntityExist(ride.entity) then return end
    Entity(ride.entity).state:set("skyPhoneKnoway", {
        rideId = ride.id, driverNetId = ride.vehicle.driverNetId, status = ride.status,
        target = ride.status == "approaching" and ride.pickup.coords
            or ride.status == "driving" and ride.destination.coords or nil,
        speedKmh = ride.config.MaxSpeedKmh, drivingStyle = ride.config.DrivingStyle,
        arrivalRadius = ride.config.ArrivalRadius, replan = ride.replans or 0,
    }, true)
end

local function occupied(vehicle)
    for _, player in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(tonumber(player))
        if ped ~= 0 and GetVehiclePedIsIn(ped, false) == vehicle then return true end
    end
    return false
end

local function dispose(ride)
    if ride.entity and DoesEntityExist(ride.entity) then
        local expected_model = type(ride.config.VehicleModel) == "number" and ride.config.VehicleModel or joaat(ride.config.VehicleModel)
        local same_vehicle = GetEntityModel(ride.entity) % 4294967296 == expected_model % 4294967296
            and (not ride.vehicle.netId or ride.vehicle.netId == 0 or NetworkGetNetworkIdFromEntity(ride.entity) == ride.vehicle.netId)
            and (not ride.vehicle.plate or ride.vehicle.plate == ""
                or GetVehicleNumberPlateText(ride.entity):gsub("%s+$", "") == ride.vehicle.plate)
        if same_vehicle then
            if occupied(ride.entity) then return false end
            DeleteEntity(ride.entity)
        end
    end
    local expected_driver = type(ride.config.DriverModel) == "number" and ride.config.DriverModel or joaat(ride.config.DriverModel)
    if ride.driver and DoesEntityExist(ride.driver)
        and GetEntityModel(ride.driver) % 4294967296 == expected_driver % 4294967296
        and (not ride.vehicle.driverNetId or ride.vehicle.driverNetId == 0
            or NetworkGetNetworkIdFromEntity(ride.driver) == ride.vehicle.driverNetId) then DeleteEntity(ride.driver) end
    retiring[ride.id] = nil
    registry[ride.id] = nil
    publish_registry()
    return true
end

local function finish(ride, status, reason, technical)
    if terminal[ride.status] then return state(ride.source, ride) end
    local should_refund = status ~= "arrived" and (technical and ride.config.RefundTechnicalFailure
        or not technical and (ride.startedAt and ride.config.RefundAfterStart or not ride.startedAt and ride.config.RefundBeforeStart))
    local payment = should_refund and ride.price > 0 and "refund_pending" or "settled"
    -- Persist the terminal decision before releasing the one-active-order lease.
    local result = Bridge.Database.Query([[
        UPDATE `sky_phone_knoway_rides`
        SET `status` = ?, `reason` = ?, `payment_status` = ?, `active_owner` = NULL, `updated_epoch` = ?
        WHERE `id` = ? AND `payment_status` = 'charged'
            AND `status` IN ('preparing','approaching','waiting','driving')
    ]], { status, reason, payment, os.time(), ride.id })
    if affected(result) ~= 1 then return fail("request_failed") end
    ride.status, ride.reason, ride.payment = status, reason, payment
    if by_owner[ride.owner] == ride then by_owner[ride.owner] = nil end
    retiring[ride.id] = ride
    control_state(ride)
    save(ride)
    push(ride)
    if payment == "refund_pending" then
        refund({ id = ride.id, owner_identifier = ride.owner, payment_status = payment,
            price = ride.price, payment_account = ride.config.PaymentAccount }, ride.source)
    end
    return state(ride.source, ride)
end

local function owner_ride(source, data)
    if type(data) ~= "table" or type(data.rideId) ~= "string" then return nil end
    local ride = rides[data.rideId]
    if ride and ride.source == source and Bridge.Framework.GetIdentifier(source) == ride.owner then return ride end
end

local function road_request(source, data, cfg)
    local ped = GetPlayerPed(source)
    if ped == 0 or GetEntityHealth(ped) <= 0 or GetVehiclePedIsIn(ped, false) ~= 0 then return nil end
    local current = coords(ped)
    local pickup, target, spawn = point(data.pickupNode), point(data.destinationNode), point(data.spawnNode)
    local wanted = type(data.destination) == "table" and point(data.destination.coords)
    if not pickup or not target or not spawn or not wanted then return nil end
    local target_snap = math.sqrt((wanted.x - target.x)^2 + (wanted.y - target.y)^2)
    if distance(current, pickup) > cfg.RoadSnapDistance or target_snap > cfg.RoadSnapDistance
        or distance(pickup, spawn) < cfg.SpawnMinimumDistance * 0.5
        or distance(current, spawn) > cfg.SpawnMaximumDistance + cfg.RoadSnapDistance
        or math.abs(current.z - pickup.z) > 15 then return nil end
    local meters = math.ceil(distance(pickup, target) * cfg.RouteDistanceMultiplier)
    if meters < cfg.MinimumDistanceMeters or meters > cfg.MaximumDistanceMeters then return nil end
    local label = type(data.destination.label) == "string" and data.destination.label:sub(1, 80) or ""
    local pickup_label = type(data.pickupNode.label) == "string" and data.pickupNode.label:sub(1, 80) or ""
    return { pickup = { coords = pickup, label = pickup_label }, destination = { coords = target, label = label },
        spawn = spawn, distanceMeters = meters, bucket = GetPlayerRoutingBucket(source) }
end

Bridge.Callbacks.Register("sky_phone:knoway:bootstrap", function(source)
    local identifier = Bridge.Framework.GetIdentifier(source)
    if not identifier then return fail("not_authenticated") end
    local active = by_owner[identifier]
    if active then active.source = source end
    return state(source, active)
end)

Bridge.Callbacks.Register("sky_phone:knoway:quote", function(source, data)
    if not Config.Apps.knoway then return fail("app_disabled") end
    if Config.Knoway.VehicleModel == "" or GetConvar("onesync", "off") == "off" then return fail("service_unavailable") end
    if not SkyPhone.AllowOperation(source, "knoway_quote", 20, 60) then return fail("rate_limited") end
    local session, response = SkyPhone.RequireSession(source)
    if not session then return response end
    local identifier = Bridge.Framework.GetIdentifier(source)
    if not identifier then return fail("not_authenticated") end
    if by_owner[identifier] then return fail("ride_active") end
    local cfg = snapshot()
    local route = type(data) == "table" and road_request(source, data, cfg)
    if not route then return fail("invalid_route") end
    local id = Bridge.Database.Query("SELECT UUID() AS `id`", {})[1].id
    local price = math.max(cfg.MinimumFare, math.ceil(cfg.BaseFare + cfg.PricePerKilometer * route.distanceMeters / 1000))
    local quote = { id = id, expiresAt = os.time() + cfg.QuoteLifetimeSeconds,
        pickup = route.pickup, destination = route.destination, price = price, currency = cfg.Currency,
        distanceMeters = route.distanceMeters, durationSeconds = math.ceil(route.distanceMeters / cfg.AverageSpeedMetersPerSecond),
        refundPolicy = { beforeStart = cfg.RefundBeforeStart, afterStart = cfg.RefundAfterStart, technical = cfg.RefundTechnicalFailure } }
    quotes[identifier] = { public = quote, source = source, config = cfg, route = route }
    return { success = true, data = quote }
end)

Bridge.Callbacks.Register("sky_phone:knoway:request", function(source, data)
    if not Config.Apps.knoway then return fail("app_disabled") end
    local session, response = SkyPhone.RequireSession(source)
    if not session then return response end
    local identifier = Bridge.Framework.GetIdentifier(source)
    if not identifier then return fail("not_authenticated") end
    return locked(identifier, function()
        if by_owner[identifier] then
            local existing = by_owner[identifier]
            if data.quoteId == existing.quoteId then return state(source, existing) end
            return fail("ride_active")
        end
        local quote = quotes[identifier]
        if not quote or quote.source ~= source or type(data) ~= "table" or data.quoteId ~= quote.public.id
            or quote.public.expiresAt <= os.time() then return fail("quote_expired") end
        local now, count = os.time(), 0
        for _ in pairs(by_owner) do count = count + 1 end
        for _ in pairs(retiring) do count = count + 1 end
        -- Locks reserve dispatch capacity before database/framework calls yield.
        for owner in pairs(locks) do
            if owner ~= identifier and not by_owner[owner] then count = count + 1 end
        end
        if count >= Config.Knoway.MaxActiveRides then return fail("fleet_busy") end
        if (cooldowns[identifier] or 0) > now then return fail("ride_cooldown") end
        local ped = GetPlayerPed(source)
        if ped == 0 or GetEntityHealth(ped) <= 0 or GetVehiclePedIsIn(ped, false) ~= 0
            or GetPlayerRoutingBucket(source) ~= quote.route.bucket
            or distance(coords(ped), quote.public.pickup.coords) > quote.config.RoadSnapDistance then return fail("pickup_changed") end
        local balance = Bridge.Framework.GetMoney(source, quote.config.PaymentAccount)
        if not balance or balance < quote.public.price then return fail("insufficient_funds") end
        local pending = Bridge.Database.Query([[
            SELECT `id` FROM `sky_phone_knoway_rides` WHERE `active_owner` = ? LIMIT 1
        ]], { identifier })
        if pending[1] then return fail("payment_review") end
        local value = quote.public
        local ride = { id = value.id, quoteId = value.id, source = source, owner = identifier,
            status = "preparing", payment = "debit_processing", pickup = value.pickup, destination = value.destination,
            price = value.price, currency = value.currency, distanceMeters = value.distanceMeters,
            durationSeconds = value.durationSeconds, createdAt = now, config = quote.config,
            bucket = quote.route.bucket, vehicle = { model = quote.config.VehicleModel, plate = "", netId = 0, driverNetId = 0 } }
        Bridge.Database.Query([[
            INSERT INTO `sky_phone_knoway_rides`
            (`id`,`owner_identifier`,`active_owner`,`status`,`payment_status`,`price`,`payment_account`,`currency`,`payload`,`created_epoch`,`updated_epoch`)
            VALUES (?, ?, ?, 'preparing', 'debit_processing', ?, ?, ?, ?, ?, ?)
        ]], { ride.id, identifier, identifier, ride.price, ride.config.PaymentAccount, ride.currency, persisted(ride), now, now })
        quotes[identifier] = nil
        if Bridge.Framework.GetIdentifier(source) ~= identifier then
            Bridge.Database.Query([[
                UPDATE `sky_phone_knoway_rides` SET `payment_status` = 'not_charged', `status` = 'cancelled', `active_owner` = NULL
                WHERE `id` = ? AND `payment_status` = 'debit_processing'
            ]], { ride.id })
            return fail("not_authenticated")
        end
        local ok, charged = pcall(Bridge.Framework.RemoveMoney, source, ride.config.PaymentAccount, ride.price)
        if not ok then
            Bridge.Database.Query("UPDATE `sky_phone_knoway_rides` SET `payment_status` = 'review' WHERE `id` = ?", { ride.id })
            Bridge.Debug("error", "[sky_phone] KnoWay debit '%s' requires reconciliation; no automatic replay.", ride.id)
            return fail("payment_review")
        end
        if not charged then
            Bridge.Database.Query([[
                UPDATE `sky_phone_knoway_rides` SET `payment_status` = 'not_charged', `status` = 'cancelled', `active_owner` = NULL
                WHERE `id` = ? AND `payment_status` = 'debit_processing'
            ]], { ride.id })
            return fail("insufficient_funds")
        end
        local capture = Bridge.Database.Query([[
            UPDATE `sky_phone_knoway_rides` SET `payment_status` = 'charged', `updated_epoch` = ?
            WHERE `id` = ? AND `payment_status` = 'debit_processing'
        ]], { now, ride.id })
        if affected(capture) ~= 1 then return fail("payment_review") end
        ride.payment = "charged"
        rides[ride.id], by_owner[identifier] = ride, ride
        cooldowns[identifier] = now + ride.config.RequestCooldownSeconds
        TriggerClientEvent("sky_phone:banking:changed", source)
        -- Everything after the charge is recoverable from the persisted journal.
        local spawned, spawn_error = pcall(function()
            local spawn = quote.route.spawn
            ride.entity = CreateVehicleServerSetter(joaat(ride.config.VehicleModel), "automobile", spawn.x, spawn.y, spawn.z, spawn.heading)
            if not ride.entity or ride.entity == 0 or not DoesEntityExist(ride.entity) then error("Vehicle creation failed") end
            SetEntityOrphanMode(ride.entity, 2)
            SetEntityRoutingBucket(ride.entity, ride.bucket)
            ride.driver = CreatePed(4, joaat(ride.config.DriverModel), spawn.x, spawn.y, spawn.z, spawn.heading, true, true)
            if not ride.driver or ride.driver == 0 or not DoesEntityExist(ride.driver) then error("Driver creation failed") end
            SetEntityOrphanMode(ride.driver, 2)
            SetEntityRoutingBucket(ride.driver, ride.bucket)
            ride.vehicle.netId = NetworkGetNetworkIdFromEntity(ride.entity)
            ride.vehicle.driverNetId = NetworkGetNetworkIdFromEntity(ride.driver)
            ride.vehicle.plate = ("KN%06d"):format(math.random(0, 999999))
            SetVehicleNumberPlateText(ride.entity, ride.vehicle.plate)
            registry[ride.id] = { vehicle = ride.vehicle.netId, driver = ride.vehicle.driverNetId,
                model = joaat(ride.config.VehicleModel), driverModel = joaat(ride.config.DriverModel), plate = ride.vehicle.plate }
            publish_registry()
            Entity(ride.driver).state:set("skyPhoneKnowayDriver", true, true)
            ride.status, ride.expiresAt = "approaching", now + ride.config.ApproachTimeoutSeconds
            ride.lastPosition, ride.lastProgress = coords(ride.entity), now
            control_state(ride)
            if not save(ride) then error("Ride persistence failed") end
        end)
        if not spawned then
            Bridge.Debug("error", "[sky_phone] KnoWay dispatch failed: %s", tostring(spawn_error))
            return finish(ride, "failed", "dispatch_failed", true)
        end
        push(ride)
        return state(source, ride)
    end)
end)

Bridge.Callbacks.Register("sky_phone:knoway:start", function(source, data)
    local ride = owner_ride(source, data)
    if not ride then return fail("not_ride_owner") end
    return locked(ride.owner, function()
        if ride.status == "driving" then return state(source, ride) end
        if ride.status ~= "waiting" or ride.expiresAt <= os.time() then return fail("ride_not_ready") end
        local ped = GetPlayerPed(source)
        if ped == 0 or not DoesEntityExist(ride.entity) or GetEntityHealth(ped) <= 0
            or GetVehiclePedIsIn(ped, false) ~= ride.entity or GetPedInVehicleSeat(ride.entity, -1) == ped
            or GetPlayerRoutingBucket(source) ~= ride.bucket then return fail("not_in_taxi") end
        local previous_expiry, previous_position, previous_progress, previous_replans = ride.expiresAt, ride.lastPosition, ride.lastProgress, ride.replans
        ride.status, ride.startedAt = "driving", os.time()
        ride.expiresAt = ride.startedAt + ride.config.MaximumRideSeconds
        ride.lastPosition, ride.lastProgress, ride.replans = coords(ride.entity), os.time(), 0
        if not save(ride) then
            ride.status, ride.startedAt, ride.expiresAt = "waiting", nil, previous_expiry
            ride.lastPosition, ride.lastProgress, ride.replans = previous_position, previous_progress, previous_replans
            return fail("request_failed")
        end
        control_state(ride)
        push(ride)
        return state(source, ride)
    end)
end)

Bridge.Callbacks.Register("sky_phone:knoway:cancel", function(source, data)
    local ride = owner_ride(source, data)
    if not ride then return fail("not_ride_owner") end
    return locked(ride.owner, function() return finish(ride, "cancelled", "passenger_cancelled", false) end)
end)

local function tick(ride, now)
    if locks[ride.owner] or terminal[ride.status] then return end
    if not GetPlayerName(ride.source) or Bridge.Framework.GetIdentifier(ride.source) ~= ride.owner then
        finish(ride, "cancelled", "passenger_left", false); return
    end
    local ped = GetPlayerPed(ride.source)
    if ped == 0 or GetEntityHealth(ped) <= 0 or GetPlayerRoutingBucket(ride.source) ~= ride.bucket then
        finish(ride, "cancelled", "passenger_left", false); return
    end
    if not ride.entity or not DoesEntityExist(ride.entity) or not ride.driver or not DoesEntityExist(ride.driver)
        or GetEntityHealth(ride.entity) <= 0 or GetEntityHealth(ride.driver) <= 0 then
        finish(ride, "failed", "vehicle_lost", true); return
    end
    if ride.status == "driving" and GetVehiclePedIsIn(ped, false) ~= ride.entity then
        finish(ride, "cancelled", "passenger_left", false); return
    end
    if ride.expiresAt <= now then
        finish(ride, ride.status == "waiting" and "cancelled" or "failed", "ride_timeout", ride.status ~= "waiting"); return
    end
    if ride.status == "approaching" or ride.status == "driving" then
        local position = coords(ride.entity)
        local target = ride.status == "approaching" and ride.pickup.coords or ride.destination.coords
        if distance(position, target) <= ride.config.ArrivalRadius and GetEntitySpeed(ride.entity) < 2 then
            if ride.status == "driving" then finish(ride, "arrived", "destination_reached", false); return end
            ride.status, ride.expiresAt = "waiting", now + ride.config.BoardingTimeoutSeconds
            save(ride); control_state(ride); push(ride)
        elseif distance(position, ride.lastPosition) >= 4 then
            ride.lastPosition, ride.lastProgress = position, now
        elseif now - ride.lastProgress >= ride.config.StuckTimeoutSeconds then
            ride.replans = (ride.replans or 0) + 1
            if ride.replans > ride.config.MaximumReplans then finish(ride, "failed", "route_blocked", true); return end
            ride.lastProgress = now
            control_state(ride)
        end
    end
    push(ride)
end

local function recovery()
    local players, identifiers, placeholders = {}, {}, {}
    for _, player in ipairs(Bridge.Framework.GetPlayers()) do
        local identifier = Bridge.Framework.GetIdentifier(player)
        if identifier and not players[identifier] then
            players[identifier] = player
            identifiers[#identifiers + 1] = identifier
            placeholders[#placeholders + 1] = "?"
        end
    end
    if #identifiers == 0 then return end
    -- Offline claims must not fill the bounded batch ahead of payable refunds.
    -- Oldest attempts go first so rejected credits rotate through later batches.
    local rows = Bridge.Database.Query(([[
        SELECT * FROM `sky_phone_knoway_rides` WHERE `payment_status` = 'refund_pending'
            AND `owner_identifier` IN (%s)
        ORDER BY `updated_epoch`, `id` LIMIT 100
    ]]):format(table.concat(placeholders, ",")), identifiers)
    for _, row in ipairs(rows) do refund(row, players[row.owner_identifier]) end
end

-- A cold start never resumes an unattended journey or guesses an ambiguous debit.
Bridge.Database.Query([[
    UPDATE `sky_phone_knoway_rides` SET `payment_status` = 'review'
    WHERE `payment_status` IN ('debit_processing','refund_processing')
]], {})
local interrupted = Bridge.Database.Query([[
    SELECT * FROM `sky_phone_knoway_rides`
    WHERE `status` IN ('preparing','approaching','waiting','driving') AND `payment_status` = 'charged'
]], {})
for _, row in ipairs(interrupted) do
    local decoded = json.decode(row.payload)
    local cfg = decoded.config
    Bridge.Database.Query([[
        UPDATE `sky_phone_knoway_rides` SET `status` = 'failed', `reason` = 'resource_restarted',
            `active_owner` = NULL, `payment_status` = ?, `updated_epoch` = ?
        WHERE `id` = ? AND `payment_status` = 'charged'
    ]], { cfg.RefundTechnicalFailure and tonumber(row.price) > 0 and "refund_pending" or "settled", os.time(), row.id })
end

for id, record in pairs(registry) do
    local entity = NetworkGetEntityFromNetworkId(record.vehicle)
    local driver = NetworkGetEntityFromNetworkId(record.driver)
    if entity ~= 0 and driver ~= 0 and DoesEntityExist(entity) and DoesEntityExist(driver)
        and GetEntityModel(entity) % 4294967296 == record.model % 4294967296
        and GetEntityModel(driver) % 4294967296 == record.driverModel % 4294967296
        and GetVehicleNumberPlateText(entity):gsub("%s+$", "") == record.plate
        and (GetPedInVehicleSeat(entity, -1) == driver or distance(coords(entity), coords(driver)) < 10) then
        local orphan = { id = id, entity = entity, driver = driver,
            status = "failed", config = snapshot(), vehicle = { driverNetId = record.driver, netId = record.vehicle, plate = record.plate } }
        orphan.config.VehicleModel, orphan.config.DriverModel = record.model, record.driverModel
        retiring[id] = orphan
        control_state(orphan)
    else
        registry[id] = nil
    end
end
publish_registry()

AddEventHandler("playerDropped", function()
    local player = source
    for _, ride in pairs(by_owner) do
        if ride.source == player then locked(ride.owner, function() return finish(ride, "cancelled", "passenger_left", false) end) end
    end
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    -- Awaiting SQL is unsafe during shutdown. Charged rows are settled by the
    -- cold-start recovery above; only native safety/empty-entity cleanup runs here.
    for _, ride in pairs(by_owner) do
        ride.status = "failed"
        control_state(ride)
        retiring[ride.id] = ride
    end
    for _, ride in pairs(retiring) do dispose(ride) end
end)

CreateThread(function()
    local last_recovery = 0
    while true do
        Wait((next(by_owner) or next(retiring)) and 1000 or 5000)
        local now = os.time()
        for _, ride in pairs(by_owner) do
            local ok, err = pcall(tick, ride, now)
            if not ok then Bridge.Debug("error", "[sky_phone] KnoWay worker failed: %s", tostring(err)) end
        end
        for _, ride in pairs(retiring) do dispose(ride) end
        if now - last_recovery >= 15 then
            local ok, err = pcall(recovery)
            if not ok then Bridge.Debug("error", "[sky_phone] KnoWay payment recovery failed: %s", tostring(err)) end
            last_recovery = now
        end
        for owner, quote in pairs(quotes) do if quote.public.expiresAt <= now then quotes[owner] = nil end end
        for id, ride in pairs(rides) do
            if terminal[ride.status] and not retiring[id] and now - ride.createdAt > 3600 then rides[id] = nil end
        end
        for owner, expires in pairs(cooldowns) do if expires <= now then cooldowns[owner] = nil end end
    end
end)
end)
